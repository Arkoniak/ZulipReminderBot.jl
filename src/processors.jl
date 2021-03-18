function process_timezone(obj::ZulipRequest, db, opts)
    @info "timezone"
    return "Not implemented yet"
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
    - `when` can be either in relative form `X days Y hours Z minutes` or in an absolute form `2020-10-01 23:15:00`. In relative forms one can use single or plural form of `month`, `week`, `day`, `hour`, `minute`, `second`. In absolute form date is mandatory, but hours, minute or second part can be omitted.
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
    # TODO:
    if status == :absolute
        # Fix time taking into account user's timezone
    end

    content = ((gde == :here) & (obj.message.type == "stream")) ? "On behalf of @**$(obj.message.sender_full_name)**\n" : ""
    content *= if obj.message.type == "stream"
        startswithnarrow(msg) ? "" : (narrow(obj.message) * "\n")
    else
        ""
    end
    content *= msg

    msg = if obj.message.type == "stream" && gde == :here
        Message(obj.message.display_recipient, obj.message.subject, "stream", obj.message.sender_id, content)
    else
        Message("", "", "private", obj.message.sender_id, content)
    end
    tmsg = TimedMessage(ts, exects, msg)
    tmsg = insert(db, tmsg)
    @debug tmsg
    put!(channel, tmsg)
    "Message is scheduled on $exects"
end
