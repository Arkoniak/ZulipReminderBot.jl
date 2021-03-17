module ZulipReminderBot

using Base64
using HTTP
using JSON3
using StructTypes
using Dates
using SQLite
using DBInterface
using Strapping
using TimeZones
using Setfield

include("structs.jl")
include("miniorm.jl")
include("db_utils.jl")
include("migrations.jl")
include("zulipclient.jl")
include("processors.jl")
export setupbot!

currentts() = Dates.format(Dates.now(), "yyyy-mm-ddTHH:MM:SS")

########################################
# Processing
########################################
function validate(obj::ZulipRequest, opts)
    obj.data = strip(obj.data)
    if obj.message.sender_id < 0 || isempty(obj.data) || isempty(obj.token)
        return false, "Wrong message, contact bot maintainer"
    end
    if obj.token != opts.token
        return false, "Incorrect token, verify ReminderBot server configuration"
    end

    if obj.data[1] == '@'
        m = match(r"^@[^\s]+\s+(.*)$"s, obj.data)
        isnothing(m) && return false, "Wrong message. Refer to `help` on the usage of the ReminderBot."
        obj.data = m[1]
    end

    return true, ""
end

curts() = Dates.value(now()) - Dates.UNIXEPOCH

function process(obj::ZulipRequest, db, channel, ts, opts = OPTS[])
    status, resp = validate(obj, opts)
    !status && return JSON3.write((; content = resp))
    
    # Time is in milliseconds
    exects = ts + 5_000
    content = ZulipOpts[].baseep * "/#narrow/stream/$(obj.message.stream_id)-$(HTTP.escape(obj.message.display_recipient))/topic/$(HTTP.escape(obj.message.subject))/near/$(obj.message.id)\n"
    content *= obj.data
    msg = Message(obj.message.display_recipient, obj.message.subject, content)
    tmsg = TimedMessage(ts, exects, msg)
    tmsg = insert(db, tmsg)
    @debug tmsg
    put!(channel, tmsg)
    resp = "Message is scheduled on $(unix2datetime(exects/1000.0))"

    # resp = if startswith(obj.data, "timezone")
    #     process_timezone(obj, db, opts)
    # elseif startswith(obj.data, "list")
    #     process_list(obj, db, opts)
    # elseif startswith(obj.data, "help")
    #     process_help(obj, db, opts)
    # else
    #     process_reminder(obj, db, opts)
    # end

    return JSON3.write((; content = resp))
end

########################################
# Server
########################################

function cron_worker(input, output, sched = TimedMessage[], sleepduration = 1)
    sorted = true
    while true
        sleep(sleepduration)
        lock(input)
        while isready(input)
            sorted = false
            datain = take!(input)
            push!(sched, datain)
        end
        unlock(input)
        if !sorted
            sort!(sched, by = x -> x.exects, rev = true)
        end
        isempty(sched) && continue
        ts = curts()

        while !isempty(sched)
            if ts >= sched[end].exects
                tmsg = pop!(sched)
                put!(output, tmsg)
            else
                break
            end
        end
    end
end

function populate(db, input)
    @info "populate"
    msgs = select(db, Vector{TimedMessage})
    for msg in msgs
        @info msg
        put!(input, msg)
    end
end

function msg_worker(db, input)
    while true
        try
            msg = take!(input)
            @debug msg
            resp = sendMessage(type = "stream", to = msg.msg.stream, topic = msg.msg.topic, content = msg.msg.content)
            delete(db, msg)
            @debug resp
        catch err
            @error err
        end
    end
end

function run(db, opts = OPTS[])
    inmsg_channel = Channel{TimedMessage}(1000)
    outmsg_channel = Channel{TimedMessage}(1000)
    @async cron_worker(inmsg_channel, outmsg_channel)
    @async msg_worker(db, outmsg_channel)
    
    host = opts.host
    port = opts.port
    @info "Starting Reminder Bot server on $host:$port"

    populate(db, inmsg_channel)

    HTTP.serve(opts.host, opts.port) do http
        ts = curts()
        obj = String(HTTP.payload(http))
        @debug obj
        obj = JSON3.read(obj, ZulipRequest)
        @info obj
        resp = process(obj, db, inmsg_channel, ts, opts)

        return HTTP.Response(resp)
    end
end

end # module
