struct Opts
    token::String
    host::String
    port::Int
end
const OPTS = Ref(Opts("", "127.0.0.1", 9174))
read_port(port::Integer) = port
read_port(port) = parse(Int, port)

function setupbot!(; token = OPTS[].token,
                     host = OPTS[].host, 
                     port = OPTS[].port,
                     email = "",
                     apikey = "",
                     ep = "")
    OPTS[] = Opts(token, host, read_port(port))
    ZulipClient(email = email, apikey = apikey, ep = ep)
end

########################################
# Incoming messages processing
########################################

struct Message
    stream::String
    topic::String
    type::String
    sender_id::Int
    content::String
end
StructTypes.StructType(::Type{Message}) = StructTypes.OrderedStruct()

toepoch(ts) = Dates.value(ts) - Dates.UNIXEPOCH
struct TimedMessage
    id::Int
    createts::Int
    exects::Int
    msg::Message
end
StructTypes.StructType(::Type{TimedMessage}) = StructTypes.OrderedStruct()
TimedMessage(createts, exects, msg) = TimedMessage(-1, createts, exects, msg)
TimedMessage(createts::DateTime, exects::DateTime, msg) = TimedMessage(-1, toepoch(createts), toepoch(exects), msg)
