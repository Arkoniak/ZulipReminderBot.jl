########################################
# Adapters
########################################

abstract type Postgres end
struct PostgresODBC <: Postgres end

struct SQLite end

struct Adapter{AT, CT}
    conn::CT
    adapter::Type{AT}
end

########################################
# Table building functions
########################################

struct DBField
    name::Symbol
    type::Type
    nullable::Bool
end

struct DeconstructClosure{PT}
    fields::Vector{DBField}
    prefix::Symbol
    parenttype::Type{PT}
end

DeconstructClosure(PT; prefix = Symbol()) = DeconstructClosure(DBField[], prefix, PT)

function (f::DeconstructClosure)(i, nm, TT; kw...)
    nametypeindex!(StructTypes.StructType(TT), TT, i, nm, f)
    return
end

function deconstruct(PT)
    c = DeconstructClosure(PT)
    StructTypes.foreachfield(c, PT)
    return c
end

function nametypeindex!(ST, T, i, nm, c)
    dbfield = DBField(Symbol(c.prefix, nm), T, false)
    push!(c.fields, dbfield)
    return
end

function nametypeindex!(::Union{StructTypes.Struct, StructTypes.Mutable}, ::Type{Union{Nothing, T}}, i, nm, c) where T
    dbfield = DBField(Symbol(c.prefix, nm), T, true)
    push!(c.fields, dbfield)
    return
end

function nametypeindex!(::Union{StructTypes.Struct, StructTypes.Mutable}, ::Type{Union{Missing, T}}, i, nm, c) where T
    dbfield = DBField(Symbol(c.prefix, nm), T, true)
    push!(c.fields, dbfield)
    return
end

function nametypeindex!(::Union{StructTypes.Struct, StructTypes.Mutable}, T, i, nm, c)
    prefix = Symbol(c.prefix, StructTypes.fieldprefix(c.parenttype, nm))
    c2 = DeconstructClosure(c.fields, prefix, T)
    StructTypes.foreachfield(c2, T)
    return
end

function build_autoincrement_column!(iob, adapter::Adapter{DBT}, T, field) where {DBT <: Postgres}
    print(iob, field.name, " ", dbautoincrement(adapter, field.type), idproperty(T) == field.name ? " PRIMARY KEY" : "")
end

function build_column!(iob, adapter, T, field)
    if autoincrement(T) == field.name
        build_autoincrement_column!(iob, adapter, T, field)
        return nothing
    end

    print(iob, field.name, " ", dbtype(adapter, field.type), field.nullable ? "" : " NOT NUll", idproperty(T) == field.name ? " PRIMARY KEY" : "")

    return nothing
end

function build_create_table(adapter, T)
    iob = IOBuffer()
    print(iob, "CREATE TABLE ", tablename(T), " (\n")
    c = deconstruct(T)
    field, rest = Iterators.peel(c.fields)
    build_column!(iob, adapter, T, field)
    for field in rest
        print(iob, ",\n")
        build_column!(iob, adapter, T, field)
    end
    print(iob, "\n)")

    query = String(take!(iob))
end

function create_table(adapter, T)
    query = build_create_table(adapter, T)
    execute(adapter, query)
end

########################################
# Auxiliary table functions
########################################
tablename(T) = lowercase(string(Symbol(T))) * "s"

dbtype(::Adapter{DBT}, ::Type{Int}) where {DBT <: Postgres} = "BIGINT"
dbtype(::Adapter{DBT}, ::Type{String}) where {DBT <: Postgres} = "TEXT"
dbautoincrement(::Adapter{DBT}, ::Type{Int}) where {DBT <: Postgres} = "BIGSERIAL"

idproperty(::Type{T}) where T = :_
autoincrement(::Type{T}) where T = :_

########################################
# Interaction utils
########################################

function execute(adapter::Adapter, query, vals = nothing)
    if vals === nothing || isempty(vals)
        res = DBInterface.execute(adapter.conn, query)
    else
        stmt = prepare(adapter, query)
        res = DBInterface.execute(stmt, vals)
        # TODO: I do not like that I have hanging statements, but this is the only way
        # to ensure select results...
        # DBInterface.close!(stmt)
    end

    res
end

function execute(f, adapter::Adapter, query, vals = nothing)
    if vals === nothing || isempty(vals)
        res = f(DBInterface.execute(adapter.conn, query))
    else
        stmt = prepare(adapter, query)
        res = f(DBInterface.execute(stmt, vals))
        # TODO: I do not like that I have hanging statements, but this is the only way
        # to ensure select results...
        DBInterface.close!(stmt)
    end

    res
end

prepare(adapter::Adapter, query) = DBInterface.prepare(adapter.conn, query)

function build_insert(adapter::Adapter, x::T) where T
    c = deconstruct(T)
    iob = IOBuffer()
    
    aicol = autoincrement(T)

    print(iob, "INSERT INTO ", tablename(T), " (")
    isfirst = true
    isaicol = false
    cnt = 0
    for field in c.fields
        if field.name == aicol
            isaicol = true 
            continue
        end
        cnt += 1
        print(iob, isfirst ? "" : ", ", field.name)
        isfirst = false
    end

    print(iob, ") VALUES (")

    isfirst = true
    for i in 1:cnt
        print(iob, isfirst ? "?" : ",?")
        isfirst = false
    end
    print(iob, ")")

    if isaicol
        print(iob, " RETURNING ", aicol)
    end
    query = String(take!(iob))
end

function insert(adapter::Adapter, x::T) where T
    # TODO: All of this is so so so slow... Should be implemented better!
    # Currently it's just proof of concept
    query = build_insert(adapter, x)
    c = deconstruct(T)

    protovals = Strapping.deconstruct(x) |> only |> values
    vals = []
    aicol = autoincrement(T)
    isaicol = false
    for (i, v) in enumerate(protovals)
        if c.fields[i].name == aicol
            isaicol = true
            continue
        end
        push!(vals, v)
    end
    x = execute(adapter, query, vals) do res
        if isaicol
            l = Setfield.PropertyLens{aicol}()
            set(x, l, only(only(res.columns)))
        end
    end

    return x
end

function build_select(adapter::Adapter, ::Type{T}, filt = ()) where T
    iob = IOBuffer()
    print(iob, "SELECT * FROM ", tablename(T))
    
    if !isempty(filt)
        isfirst = true
        print(iob, " WHERE")
        for (k, _) in filt
            print(iob, isfirst ? " " : " AND ", k, " = ?")
        end
    end

    return String(take!(iob))
end

function select(adapter::Adapter, ::Type{T}, filt = ()) where T
    query = build_select(adapter, T, filt)
    vals = map(x -> x[2], filt)

    execute(adapter, query, vals) do dbres
        Strapping.construct(T, dbres)
    end
end

function select(adapter::Adapter, ::Type{Vector{T}}, filt = ()) where T
    query = build_select(adapter, T, filt)
    vals = map(x -> x[2], filt)

    execute(adapter, query, vals) do dbres
        Strapping.construct(Vector{T}, dbres)
    end
end

function build_delete(adapter::Adapter, ::Type{T}, filt) where T
    iob = IOBuffer()
    
    print(iob, "DELETE FROM ", tablename(T), " WHERE ")
    isfirst = true
    for (k, _) in filt
        print(iob, isfirst ? "" : " AND ", k, " = ?")
        isfirst = false
    end

    return String(take!(iob))
end

function delete(adapter::Adapter, ::Type{T}, filt) where T
    isempty(filt) && return nothing
    query = build_delete(adapter, T, filt)
    vals = map(x -> x[2], filt)
    execute(identity, adapter, query, vals)

    return nothing
end

function delete(adapter::Adapter, x::T, key = ()) where T
    if isempty(key)
        # Should delete over primary key
        id = getfield(x, idproperty(T))
        query = "DELETE FROM $(tablename(T)) WHERE $(idproperty(T)) = ?"
        execute(identity, adapter, query, (id, ))
    else
        # Not implemented
    end
end

function build_upsert(adapter::Adapter, x::T, onconflict = ()) where T
    c = deconstruct(T)
    iob = IOBuffer()
    
    pkcol = idproperty(T)

    print(iob, "INSERT INTO ", tablename(T), " (")
    isfirst = true
    cnt = 0
    for field in c.fields
        cnt += 1
        print(iob, isfirst ? "" : ", ", field.name)
        isfirst = false
    end

    print(iob, ") VALUES (")

    isfirst = true
    for i in 1:cnt
        print(iob, isfirst ? "?" : ",?")
        isfirst = false
    end
    print(iob, ")")

    print(iob, " ON CONFLICT")
    if isempty(onconflict)
        print(iob, " DO NOTHING")
    else
        print(iob, "(", pkcol, ")")
        print(iob, " DO UPDATE SET ")
        isfirst = true
        for key in onconflict
            print(iob, isfirst ? "" : ", ", key, " = EXCLUDED.", key)
            isfirst = false
        end
    end

    query = String(take!(iob))
end

function upsert(adapter::Adapter, x::T, onconflict = ()) where T
    # Yeah... I'll hardcode primary key upsert. Should be done better
    query = build_upsert(adapter, x, onconflict)
    c = deconstruct(T)

    vals = Strapping.deconstruct(x) |> only |> values
    res = execute(identity, adapter, query, vals)
    
    return nothing
end
