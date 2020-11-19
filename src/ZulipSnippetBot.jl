module ZulipSnippetBot

using HTTP
using JSON3
using StructTypes
using Dates
using SQLite
using DBInterface

include("migrations.jl")
export setupbot!

const SYMBOLS = ('A':'Z'..., 'a':'z'..., '0':'9'...)
codeid() = rand(SYMBOLS, 10) |> join
currentts() = Dates.format(Dates.now(), "yyyy-mm-ddTHH:MM:SS")

struct Opts
    token::String
    host::String
    port::Int
end
const OPTS = Ref(Opts("", "127.0.0.1", 9174))

function setupbot!(; token = OPTS[].token,
                     host = OPTS[].host, 
                     port = OPTS[].port)
    OPTS[] = Opts(token, host, port)
end

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
ZulipRequest() = ZulipRequest("", "", Message())
StructTypes.StructType(::Type{ZulipRequest}) = StructTypes.Mutable()

########################################
# Database functionality
########################################

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

function load_snippets(db, user_id)
    query = """
    SELECT code, snippet, tags
    FROM snippets
    WHERE user_id = ?
    """

    stmt = SQLite.Stmt(db, query)
    DBInterface.execute(stmt, (user_id, ))
end

########################################
# Processing
########################################
function process(obj::ZulipRequest, db, opts)
    obj.data = strip(obj.data)
    if obj.message.sender_id < 0 || isempty(obj.data) || isempty(obj.token)
        return JSON3.write((; content = "Wrong message"))
    end
    if obj.token != opts.token
        return JSON3.write((; content = "Incorrect token, verify SnippetBot server configuration"))
    end

    if obj.data[1] == '@'
        m = match(r"^@[^\s]+\s+(.*)$"s, obj.data)
        isnothing(m) && return JSON3.write((; content = "Wrong message"))
        obj.data = m[1]
    end

    resp = if startswith(obj.data, "show")
        process_show(obj, db, opts)
    elseif startswith(obj.data, "list")
        process_list(obj, db, opts)
    elseif startswith(obj.data, "save")
        process_save(obj, db, opts)
    elseif startswith(obj.data, "help")
        process_help(obj, db, opts)
    else
        "Unknown command"
    end

    return JSON3.write((; content = resp))
end

function process_show(obj::ZulipRequest, db, opts)
    @info "show"
    m = match(r"^show\s+([A-Za-z0-9]+)$", obj.data)
    if isnothing(m)
        return "No codeid is given in `show` command"
    end
    try
        r = map(x -> x.snippet, get_by_code(db, m[1]))
        if isempty(r)
            return "Codeid $(m[1]) is not found"
        end
        return r[1]
    catch err
        @error exception=(err, catch_backtrace())
        return "Server error, please try one more time. Later. Sorry."
    end
end

function process_save(obj::ZulipRequest, db, opts)
    @info "save"
    hashtags = String[]
    length(obj.data) < 6 && return "Not enough arguments in `save` command"
    s = obj.data[6:end]

    while true
        m = match(r"^\s*(#[^\s]+)\s+(.*)"s, s)
        isnothing(m) && break
        push!(hashtags, m[1])
        s = m[2]
    end
    
    hashtags = join(hashtags, " ")
    token = codeid()
    try
        store_snippet(db, obj.message.sender_id, token, s, hashtags)
        return "Snippet codeid: `$token`"
    catch err
        @error "DB Error" exception=(err, catch_backtrace())
        return "Server error, please try one more time. Later. Sorry."
    end
end

function process_list(obj::ZulipRequest, db, opts)
    @info "list"
    snippets = load_snippets(db, obj.message.sender_id)
    snippets = map(x -> (; snippet = x.snippet, code = x.code, hashtags = x.tags, tags = split(x.tags, " ")), snippets)
    if length(obj.data) >= 6
        hashtags = String[]
        s = obj.data[6:end]

        while true
            m = match(r"^\s*(#[^\s]+)\s*(.*)"s, s)
            isnothing(m) && break
            push!(hashtags, m[1])
            s = m[2]
        end
        snippets = filter(x -> !isempty(intersect(hashtags, x.tags)), snippets)
    end
    
    isempty(snippets) && return "No snippets found"

    io = IOBuffer()
    for snippet in snippets
        println(io, "**codeid**: ", snippet.code, ", **tags**: ", snippet.hashtags)
        println(io, snippet.snippet, "\n")
    end
    res = strip(String(take!(io)))
    return res
end

function process_help(obj::ZulipRequest, db, opts)
    @info "help"
    return """
Currently following commands are supported

1. `show <codeid>` - show snippet with the required `codeid`
2. `list <#hashtag1> <#hashtag2>` - shows all snippets of the author with corresponding hashtags. If no hashtags is provided returns all snippets.
3. `save <#hashtag1> <#hashtag2> <snippet>` - saves snippet in database with provided hashtags. In response server returns code_id, that can be used for snippet search.
4. `help` - this message
    """
end

########################################
# Server
########################################
function run(db, opts = OPTS[])
    HTTP.serve(opts.host, opts.port) do http
        obj = JSON3.read(HTTP.payload(http), ZulipRequest)
        resp = process(obj, db, opts)

        return HTTP.Response(resp)
    end
end

end # module
