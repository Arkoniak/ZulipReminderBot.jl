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
mutable struct ZulipMessage
    id::Int
    sender_id::Int
    type::String
    stream_id::Int
    subject::String
    display_recipient::String
end
ZulipMessage() = ZulipMessage(-1, -1, "", -1, "", "")
StructTypes.StructType(::Type{ZulipMessage}) = StructTypes.Mutable()

mutable struct ZulipRequest
    data::String
    token::String
    message::ZulipMessage
end
ZulipRequest() = ZulipRequest("", "", ZulipMessage())
StructTypes.StructType(::Type{ZulipRequest}) = StructTypes.Mutable()

struct Message
    stream::String
    topic::String
    content::String
end

struct TimedMessage
    id::Int
    createts::Int
    exects::Int
    msg::Message
end
