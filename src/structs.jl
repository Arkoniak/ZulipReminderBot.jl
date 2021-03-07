struct Opts
    token::String
    host::String
    port::Int
end
const OPTS = Ref(Opts("", "127.0.0.1", 9174))

function setupbot!(; token = OPTS[].token,
                     host = OPTS[].host, 
                     port = OPTS[].port,
                     email = "",
                     apikey = "",
                     ep = "")
    OPTS[] = Opts(token, host, parse(Int, port))
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
    display_recepient::String
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
