module ZulipReminderBot

using Base64
using HTTP
using JSON3
using StructTypes
using Dates
using SQLite
using DBInterface
using TimeZones

include("structs.jl")
include("migrations.jl")
include("zulipclient.jl")
include("db_utils.jl")
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

function process(obj::ZulipRequest, channel, opts)
    status, resp = validate(obj, opts)
    !status && return JSON3.write((; content = resp))
    
    curts = Dates.value(now()) - Dates.UNIXEPOCH + 5
    msg = Message(obj.message.display_recepient, obj.message.subject, "Scheduled Hello $(obj.data)")
    put!(channel, TimedMessage(curts, msg))
    resp = "Message is scheduled on $(unix2datetime(curts))"

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
struct Message
    stream::String
    topic::String
    content::String
end


struct TimedMessage
    ts::Int
    msg::Message
end

function cron_worker(input, output, sleeptime = 1)
    sched = TimedMessage[]
    sorted = true
    while true
        sleep(sleeptime)
        while isready(input)
            sorted = false
            datain = take!(input)
            push!(sched, datain)
        end
        if !sorted
            sort!(sched, by = x -> x.ts, rev = true)
        end
        isempty(sched) && continue
        curts = Dates.value(now()) - Dates.UNIXEPOCH
        while !isempty(sched)
            if curts > sched[end].ts
                tmsg = pop!(sched)
                put!(output, tmsg.msg)
            end
        end
    end
end

function msg_worker(input)
    while true
        msg = take!(input)
        sendMessage(type = "stream", to = msg.stream, topic = msg.topic, content = msg.content)
    end
end

function run(db, opts = OPTS[])
    inmsg_channel = Channel{TimedMessage}(1000)
    outmsg_channel = Channel{RemMessage}(1000)
    @async cron_worker(inmsg_channel, outmsg_channel)
    @async msg_worker(outmsg_channel)
    
    println("Starting Reminder Bot server on $host:$port")

    HTTP.serve(opts.host, opts.port) do http
        obj = JSON3.read(HTTP.payload(http), ZulipRequest)
        resp = process(obj, inmsg_channel, opts)

        return HTTP.Response(resp)
    end
end

end # module
