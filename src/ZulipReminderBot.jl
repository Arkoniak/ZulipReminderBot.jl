module ZulipReminderBot

using HTTP
using JSON3
using StructTypes
using Dates
using SQLite
using DBInterface

include("migrations.jl")
include("db_utils.jl")
include("processors.jl")
export setupbot!

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
    OPTS[] = Opts(token, host, parse(Int, port))
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
# Processing
########################################
function process(obj::ZulipRequest, db, opts)
    obj.data = strip(obj.data)
    if obj.message.sender_id < 0 || isempty(obj.data) || isempty(obj.token)
        return JSON3.write((; content = "Wrong message"))
    end
    if obj.token != opts.token
        return JSON3.write((; content = "Incorrect token, verify ReminderBot server configuration"))
    end

    if obj.data[1] == '@'
        m = match(r"^@[^\s]+\s+(.*)$"s, obj.data)
        isnothing(m) && return JSON3.write((; content = "Wrong message. Refer to `help` on the usage of the ReminderBot."))
        obj.data = m[1]
    end

    resp = if startswith(obj.data, "timezone")
        process_timezone(obj, db, opts)
    elseif startswith(obj.data, "list")
        process_list(obj, db, opts)
    elseif startswith(obj.data, "help")
        process_help(obj, db, opts)
    else
        process_reminder(obj, db, opts)
    end

    return JSON3.write((; content = resp))
end

########################################
# Server
########################################
function worker(db)
    
end

function run(db, opts = OPTS[])
    @async worker(db)

    HTTP.serve(opts.host, opts.port) do http
        obj = JSON3.read(HTTP.payload(http), ZulipRequest)
        resp = process(obj, db, opts)

        return HTTP.Response(resp)
    end
end

end # module
