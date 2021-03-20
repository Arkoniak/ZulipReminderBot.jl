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

struct TimedMessage
    id::Int
    createts::Int
    exects::Int
    msg::Message
end
StructTypes.StructType(::Type{TimedMessage}) = StructTypes.OrderedStruct()
TimedMessage(createts, exects, msg) = TimedMessage(-1, createts, exects, msg)
TimedMessage(createts::DateTime, exects::DateTime, msg) = TimedMessage(-1, toepoch(createts), toepoch(exects), msg)

tablename(::Type{TimedMessage}) = "messages"
idproperty(::Type{TimedMessage}) = :id
autoincrement(::Type{TimedMessage}) = :id

########################################
# TimeZone information
########################################

struct Sender
    id::Int
    tz::String
end
StructTypes.StructType(::Type{Sender}) = StructTypes.OrderedStruct()
tablename(::Type{Sender}) = "senders"
idproperty(::Type{Sender}) = :id
