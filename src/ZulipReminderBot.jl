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

function process(obj::ZulipRequest, channel, ts, opts = OPTS[])
    status, resp = validate(obj, opts)
    !status && return JSON3.write((; content = resp))
    
    # Time is in milliseconds
    exects = ts + 5_000
    msg = Message(obj.message.display_recipient, obj.message.subject, "Scheduled Hello $(obj.data)")
    tmsg = TimedMessage(ts, exects, msg)
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
        while isready(input)
            sorted = false
            datain = take!(input)
            push!(sched, datain)
        end
        if !sorted
            sort!(sched, by = x -> x.ts, rev = true)
        end
        curts = Dates.value(now()) - Dates.UNIXEPOCH
        isempty(sched) && continue
        curts = Dates.value(now()) - Dates.UNIXEPOCH

        while !isempty(sched)
            if curts > sched[end].ts
                tmsg = pop!(sched)
                put!(output, tmsg.msg)
            else
                break
            end
        end
    end
end

function msg_worker(input)
    while true
          msg = take!(input)
          resp = sendMessage(type = "stream", to = msg.stream, topic = msg.topic, content = msg.content)
          @info resp
    end
end

function run(db, opts = OPTS[])
    inmsg_channel = Channel{TimedMessage}(1000)
    outmsg_channel = Channel{Message}(1000)
    @async cron_worker(inmsg_channel, outmsg_channel)
    @async msg_worker(outmsg_channel)
    
    host = opts.host
    port = opts.port
    @info "Starting Reminder Bot server on $host:$port"

    HTTP.serve(opts.host, opts.port) do http
        ts = curts()
        obj = String(HTTP.payload(http))
        @debug obj
        obj = JSON3.read(obj, ZulipRequest)
        @info obj
        resp = process(obj, inmsg_channel, ts, opts)

        return HTTP.Response(resp)
    end
end

end # module
