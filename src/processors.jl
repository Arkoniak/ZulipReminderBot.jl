########################################
# Timezone utilities
########################################

function isfixedtz(s)
    match(r"^UTC[+-][0-9]{1,2}$", s) !== nothing
end

function getsendertz(db, sender_id)
    sender = select(db, Vector{Sender}, (:id => sender_id, ))
    isempty(sender) ? "UTC+0" : sender[1].tz
end

function process_timezone(obj::ZulipRequest, db, opts)
    @info "timezone"
    
    m = match(r"timezone\s*(.*)", obj.data)
    if isempty(m[1])
        # Show stored value
        tz = getsendertz(db, obj.message.sender_id)
        return "Your timezone is $tz"
    else
        if m[1] in TZS || isfixedtz(m[1])
            upsert(db, Sender(obj.message.sender_id, m[1]), (:tz, ))
            return "New timezone saved"
        else
            return "Unknown timezone format. Please refer [TimeZones.jl documentation](https://juliatime.github.io/TimeZones.jl/stable/types/#TimeZone-1) for the list of available timezones"
        end
    end
end

function process_remove(obj::ZulipRequest, db, opts)
    @debug "remove"
    return "Not implemented yet"
end

function process_list(obj::ZulipRequest, db, opts)
    @debug "list"
    return "Not implemented yet"
end

function process_help(obj::ZulipRequest, db, opts)
    @debug "help"
    return """
Currently following commands are supported

1. `<where> <when> <what>`: set a reminder. 
    - `where` is optional, should be either `me` or `here`. In latter case bot sends a message to the topic where reminder was set. If `where` is omitted reminder bot sends message privately to the person who set the reminder.
    - `when` can be either in relative form `X days Y hours Z minutes` or in an absolute form `2020-10-01 23:15:00`. In relative forms single or plural form of `month`, `week`, `day`, `hour`, `minute`, `second` are allowed. In absolute form date is mandatory, but hours, minute or second part can be omitted.
    - `what` is a message that should be shown by reminder bot.
2. `list`: show all current reminders of a user.
3. `remove <id>`: remove your reminder with the id <id>.
4. `timezone <value>`: set timezone for current user. If <value> is omitted, then current setting is used. Value should be in a form `Europe/Amsterdam`, `America/New_York` and the like.
5. `help`: this message

Examples of usage:
- `me 2 days drink coffee` (send private message in two hours)
- `2021-12-31 12:00 Happy New Year` (send private message on the midnight of 31 December 2021)
- `here 1 hour Say something` (send message to the stream in 1 hour)
    """
end

function process_reminder(obj::ZulipRequest, db, channel, ts, opts)
    @debug "reminder"
    gde, status, msg, exects = zparse(obj.data, ts)
    status == :unknown && return "Unable to process message. Please refer to `help` for the list of possible commands."

    tz0 = getsendertz(db, obj.message.sender_id)
    tz = tz0 in TZS ? TimeZone(tz0) : FixedTimeZone(tz0)
    if status == :absolute
        exects0 = ZonedDateTime(exects, tz)
        exects = astimezone(exects0, localzone())
    else
        exects = ZonedDateTime(exects, localzone())
        exects0 = astimezone(exects, tz)
    end
    exects = DateTime(exects)

    content = ((gde == :here) & (obj.message.type == "stream")) ? "On behalf of @**$(obj.message.sender_full_name)**\n" : ""
    content *= if obj.message.type == "stream"
        startswithnarrow(msg) ? "" : (narrow(obj.message) * "\n")
    else
        ""
    end
    content *= msg

    content = base64encode(content)
    msg = if obj.message.type == "stream" && gde == :here
        stream = base64encode(obj.message.display_recipient)
        topic = base64encode(obj.message.subject)
        Message(stream, topic, "stream", obj.message.sender_id, content)
    else
        Message("", "", "private", obj.message.sender_id, content)
    end

    tmsg = TimedMessage(ts, exects, msg)
    tmsg = insert(db, tmsg)
    @debug tmsg
    put!(channel, tmsg)
    "Message is scheduled on $(Dates.format(exects0, "yyyy-mm-dd HH:MM:SS z"))"
end
