########################################
# Database functionality
########################################
tablename(::Type{TimedMessage}) = "messages"
idproperty(::Type{TimedMessage}) = :id
autoincrement(::Type{TimedMessage}) = :id

tablename(::Type{Sender}) = "senders"
idproperty(::Type{Sender}) = :id
