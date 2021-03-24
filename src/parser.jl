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
    rexp = r"^(me|here)\s+(.*)"msi
    m = match(rexp, msg)
    m === nothing && return :me, msg
    if lowercase(m[1]) == "me"
        return :me, m[2]
    else
        return :here, m[2]
    end
end

function zparse_relative(msg, exects)
    rexps = [
             r"^\s*([0-9]+)\s+(months?)\s*(.*)"msi,
             r"^\s*([0-9]+)\s+(weeks?)\s*(.*)"msi,
             r"^\s*([0-9]+)\s+(days?)\s*(.*)"msi,
             r"^\s*([0-9]+)\s+(hours?)\s*(.*)"msi,
             r"^\s*([0-9]+)\s+(minutes?|min)\s*(.*)"msi,
             r"^\s*([0-9]+)\s+(seconds?|sec)\s*(.*)"msi,
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
    rexpdt = r"^\s*([0-9]{4}-[0-9]{2}-[0-9]{2})(.*)"ms
    m = match(rexpdt, msg)
    m === nothing && return false, msg, exects
    msg = m[2]
    try
        exects = DateTime(m[1])
    catch
        return false, msg, exects
    end
    if msg[1] == '\n'
        msg = strip(msg)
        return true, msg, exects
    end
    if msg[1] == ' ' || msg[1] == 'T'
        msg = msg[2:end]
    else
        return false, msg, exects
    end

    rexptm = r"^([0-2][0-9]):([0-5][0-9]):([0-5][0-9])\s+(.*)"ms
    m = match(rexptm, msg)
    if m !== nothing
        hh = parse(Int, m[1])
        0 <= hh <= 23 || return false, msg, exects
        mm = parse(Int, m[2])
        0 <= mm <= 59 || return false, msg, exects
        ss = parse(Int, m[3])
        0 <= ss <= 59 || return false, msg, exects
        exects += Hour(hh) + Minute(mm) + Second(ss)
        return true, m[4], exects
    end

    rexptm = r"^([0-2][0-9]):([0-5][0-9])\s+(.*)"ms
    m = match(rexptm, msg)
    if m !== nothing
        hh = parse(Int, m[1])
        0 <= hh <= 23 || return false, msg, exects
        mm = parse(Int, m[2])
        0 <= mm <= 59 || return false, msg, exects
        exects += Hour(hh) + Minute(mm)
        return true, m[3], exects
    end

    rexptm = r"^([0-2][0-9])\s+(.*)"ms
    m = match(rexptm, msg)
    if m !== nothing
        hh = parse(Int, m[1])
        0 <= hh <= 23 || return false, msg, exects
        exects += Hour(hh)
        return true, m[2], exects
    end

    return true, strip(msg), exects
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
    return ZulipOpts[].baseep * "/#narrow/stream/$(msg.stream_id)-$(HTTP.escapeuri(msg.display_recipient))/topic/$(HTTP.escapeuri(msg.subject))/near/$(msg.id)"
end

function startswithnarrow(txt)
    contains(txt, r"^https?://[^\s]+/#narrow/stream/[^\s]+/near/[0-9]+")
end
