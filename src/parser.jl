function validate(obj::ZulipRequest, opts)
    obj.data = strip(obj.data)
    if obj.message.sender_id < 0 || isempty(obj.data) || isempty(obj.token)
        return false, "Wrong message, contact bot maintainer"
    end
    if obj.token != opts.token
        return false, "Incorrect token, verify ReminderBot server configuration"
    end

    if obj.message.type == "stream"
        if !startswith(obj.data, "@**")
            return false, ""
        end
    end
    if obj.data[1] == '@'
        m = match(r"^@\*\*[^\s]+\s+(.*)$"ms, obj.data)
        m === nothing && return false, "Wrong message. Refer to `help` on the usage of the Reminder Bot."
        obj.data = m[1]
    end

    return true, ""
end

########################################
# Parse time setup
########################################

function zparse_mehere(msg)
    rexp = r"^(me|here)\s+(.*)"ms
    m = match(rexp, msg)
    m === nothing && return :me, msg
    if m[1] == "me"
        return :me, m[2]
    else
        return :here, m[2]
    end
end

function zparse_relative(msg, exects)
    rexps = [
             r"^\s*([0-9]+)\s+(months?)\s*(.*)"ms,
             r"^\s*([0-9]+)\s+(weeks?)\s*(.*)"ms,
             r"^\s*([0-9]+)\s+(days?)\s*(.*)"ms,
             r"^\s*([0-9]+)\s+(hours?)\s*(.*)"ms,
             r"^\s*([0-9]+)\s+(minutes?|min)\s*(.*)"ms,
             r"^\s*([0-9]+)\s+(seconds?|sec)\s*(.*)"ms,
            ]
    matched = false
    while true
        ended = true
        for (i, r) in pairs(rexps)
            m = match(r, msg)
            m === nothing && continue
            matched = true
            ended = false
            msg = m[3]
            delta = parse(Int, m[1])
            if i == 1
                exects += Month(delta)
            elseif i == 2
                exects += Week(delta)
            elseif i == 3
                exects += Day(delta)
            elseif i == 4
                exects += Hour(delta)
            elseif i == 5
                exects += Minute(delta)
            else
                exects += Second(delta)
            end
        end
        ended && break
    end

    return matched, msg, exects
end

function zparse_absolute(msg, exects)
    rexpdt = r"^\s*([0-9]{4}-[0-9]{2}-[0-9]{2})[ T]?\s*(.*)"ms
    m = match(rexpdt, msg)
    m === nothing && return false, msg, exects
    msg = m[2]
    exects = DateTime(m[1])

    rexptm = r"^:?([0-9]{2}):?\s*(.*)"ms
    m = match(rexptm, msg)
    m === nothing && return true, msg, exects
    msg = m[2]
    exects += Hour(parse(Int, m[1]))

    m = match(rexptm, msg)
    m === nothing && return true, msg, exects
    msg = m[2]
    exects += Minute(parse(Int, m[1]))

    m = match(rexptm, msg)
    m === nothing && return true, msg, exects
    msg = m[2]
    exects += Second(parse(Int, m[1]))

    return true, msg, exects
end

function zparse(msg, exects = Dates.now())
    gde, msg = zparse_mehere(msg)
    matched, msg, exects = zparse_relative(msg, exects)
    matched && return gde, :relative, msg, exects
    matched, msg, exects = zparse_absolute(msg, exects)
    matched && return gde, :absolute, msg, exects

    return gde, :unknown, msg, exects
end

########################################
# Narrow
########################################

function narrow(msg)
    return ZulipOpts[].baseep * "/#narrow/stream/$(msg.stream_id)-$(HTTP.escape(msg.display_recipient))/topic/$(HTTP.escape(msg.subject))/near/$(msg.id)"
end

function startswithnarrow(txt)
    contains(txt, r"^https?://[^\s]+/#narrow/stream/[^\s]+/near/[0-9]+")
end
