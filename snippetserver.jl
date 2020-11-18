using HTTP
using JSON3
using StructTypes
using Dates

include("configuration.jl")
SYMBOLS = ('A':'Z'..., 'a':'z'..., '0':'9'...)
codeid() = rand(SYMBOLS, 10) |> join
currentts() = Dates.format(Dates.now(), "yyyy-mm-ddTHH:MM:SS")

########################################
# Incoming messages processing
########################################
mutable struct Message
    sender_id::Int
end
Message() = Message(-1)
StructTypes.StructType(::Type{Message}) = StructTypes.Mutable()

mutable struct ZulipRequest
    data::String
    token::String
    message::Message
end
ZulipRequest() = ("", "", Message())
StructTypes.StructType(::Type{ZulipRequest}) = StructTypes.Mutable()

########################################
# Database functionality
########################################
const db = SQLite.DB(DB)

function get_by_code(db, code_id)
    query = """
    SELECT snippet
    FROM snippets
    WHERE code = ?
    """

    stmt = SQLite.Stmt(db, query)
    DBInterface.execute(stmt, (code_id, ))
end

function store_snippet(db, user_id, code_id, snippet, tags)
    query = """
    INSERT INTO snippets(code, user_id, snippet, tags, created) 
    VALUES (?, ?, ?, ?, ?)
    """

    ts = currentts()
    stmt = SQLite.Stmt(db, query)
    DBInterface.execute(stmt, (code_id, user_id, snippet, tags, ts))
end

########################################
# Processing
########################################
function process(obj::ZulipRequest, db)
    if obj.message.sender_id < 0 || isempty(obj.data) || isempty(obj.token)
        return JSON3.write((; content = "Wrong message"))
    end

    resp = if startswith(obj.data, "show")
        process_show(obj, db)
    elseif startswith(obj.data, "list")
        process_list(obj, db)
    elseif startswith(obj.data, "save")
        process_save(obj, db)
    else
        "Unknown command"
    end

    return JSON3.write((; content = resp))
end

function process_show(obj::ZulipRequest, db)
    m = match(r"show\s+([A-Za-z0-9]+)$", obj.data)
    if isnothing(m)
        return "Unknown token in `show` command"
    end
    try
        r = map(x -> x.snippet, get_by_code(db, m[1]))
        if isempty(r)
            return "Code id $(m[1]) is not found"
        end
        return r[1]
    catch Exception
        return "Server error, please try one more time. Later. Sorry."
    end
end

function process_save(obj::ZulipRequest, db)
    hashtags = String[]
    state = "hashtags"
    length(obj.data) < 6 && return "Not enough arguments in `save` command"
    s = obj.data[6:end]

    while true
        m = match(r"\s*(#[^\s]+)\s+(.*)"s, s)
        isnothing(m) && break
        push!(hashtags, m[1])
        s = m[2]
    end
    
    hashtags = join(hashtags, ",")
    token = codeid()
    try
        store_snippet(db, obj.message.sender_id, token, s, hashtags)
        return "Snippet codeid: `$token`"
    catch Exception
        return "Server error, please try one more time. Later. Sorry."
    end
end

########################################
# Server
########################################
HTTP.serve("127.0.0.1", 9174) do http
    obj = JSON3.read(HTTP.payload(http), ZulipRequest)
    resp = process(obj)

    return HTTP.Response(resp)
end
