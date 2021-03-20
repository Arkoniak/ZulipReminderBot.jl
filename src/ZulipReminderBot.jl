module ZulipReminderBot

using Base64
using HTTP
using JSON3
using StructTypes
using Dates
using DBInterface
using Strapping
using TimeZones
using Setfield

include("structs.jl")
include("miniorm.jl")
include("db_utils.jl")
include("migrations.jl")
include("zulipclient.jl")
include("parser.jl")
include("processors.jl")
export setupbot!

const TZS = Set(timezone_names())

currentts() = Dates.format(Dates.now(), "yyyy-mm-ddTHH:MM:SS")

########################################
# Processing
########################################

toepoch(ts) = Dates.value(ts) - Dates.UNIXEPOCH
curts() = toepoch(Dates.now())

function process(obj::ZulipRequest, db, channel, ts, opts = OPTS[])
    status, resp = validate(obj, opts)
    status || return isempty(resp) ? resp : JSON3.write((; content = resp))
    
    data = obj.data
    resp = if startswith(data, "help")
        process_help(obj, db, opts)
    elseif startswith(data, "list")
        process_list(obj, db, opts)
    elseif startswith(data, "remove")
        process_remove(obj, db, opts)
    elseif startswith(data, "timezone")
        process_timezone(obj, db, opts)
    else
        process_reminder(obj, db, channel, ts, opts)
    end

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
            tmsg = take!(input)
            @debug tmsg
            msg = tmsg.msg
            content = base64decode(msg.content) |> String
            if msg.type == "private"
                resp = sendMessage(type = "private", to = JSON3.write([msg.sender_id]), content = content)
            else
                stream = base64decode(msg.stream) |> String
                topic = base64decode(msg.topic) |> String
                resp = sendMessage(type = "stream", to = stream, topic = topic, content = content)
            end
            delete(db, tmsg)
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
        ts = Dates.now()
        obj = String(HTTP.payload(http))
        @debug obj
        obj = JSON3.read(obj, ZulipRequest)
        @info obj
        resp = process(obj, db, inmsg_channel, ts, opts)
        
        isempty(resp) || return HTTP.Response(resp)
        return nothing
    end
end

precompile(cron_worker, (Channel{TimedMessage}, Channel{TimedMessage}))
precompile(HTTP.Handlers.serve, (Function, String, Int64))
precompile(JSON3.read, (Vector{UInt8}, ))
precompile(JSON3.read, (JSON3.VectorString{Vector{UInt8}}, ))
precompile(HTTP.request, (String, String, Vector{Pair{String, String}}, String))
precompile(HTTP.request, (String, String, Vector{Pair{String, String}}, SubString{String}))
precompile(query, (ZulipClient, String, Dict{Symbol, String}))

end # module
