const TZS = Set(timezone_names())
const GMTTZ = TimeZone("GMT")

function toepoch(ts)
    fixedts = astimezone(ZonedDateTime(ts, localzone()), GMTTZ) |> DateTime
    Dates.value(fixedts) - Dates.UNIXEPOCH
end
curts() = toepoch(Dates.now())

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
# Processing
########################################

function process(obj::ZulipRequest, db, channel, ts, opts = OPTS[])
    status, resp = validate(obj, opts)
    status || return isempty(resp) ? resp : JSON3.write((; content = resp))
    
    data = obj.data
    resp = if startswith(data, "help")
        process_help(obj, db, opts)
    elseif startswith(data, "list")
        process_list(obj, db, opts)
    elseif startswith(data, "remove")
        process_remove(obj, db, channel, ts, opts)
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

function heartbeat!(sched, ts, input, output)
    sorted = true
    lock(input)
    while isready(input)
        sorted = false
        datain = take!(input)
        if datain[2] == 1
            push!(sched, datain[1])
        else
            idx = findfirst(x -> x.id == datain[1].id && x.msg.sender_id == datain[1].msg.sender_id, sched)
            idx === nothing && continue
            deleteat!(sched, idx)
        end
    end
    unlock(input)
    if !sorted
        sort!(sched, by = x -> x.exects, rev = true)
    end
    isempty(sched) && return nothing

    while !isempty(sched)
        if ts >= sched[end].exects
            tmsg = pop!(sched)
            put!(output, tmsg)
        else
            break
        end
    end

    nothing
end

function cron_worker(input, output, sched = TimedMessage[], sleepduration = 1)
    while true
        sleep(sleepduration)
        ts = curts()
        heartbeat!(sched, ts, input, output)
    end
end

function populate(db, input)
    msgs = select(db, Vector{TimedMessage})
    @info "populating $(length(msgs)) messages"
    for msg in msgs
        @debug msg
        put!(input, (msg, 1))
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
    inmsg_channel = Channel{Tuple{TimedMessage, Int}}(Inf)
    outmsg_channel = Channel{TimedMessage}(Inf)
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
        @debug obj
        resp = process(obj, db, inmsg_channel, ts, opts)
        
        isempty(resp) || return HTTP.Response(resp)
        return nothing
    end
end

