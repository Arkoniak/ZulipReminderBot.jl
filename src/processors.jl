function process_show(obj::ZulipRequest, db, opts)
    @info "show"
    m = match(r"^show\s+([A-Za-z0-9]+)$", obj.data)
    if isnothing(m)
        return "No codeid is given in `show` command"
    end
    try
        r = map(x -> x.snippet, get_by_code(db, m[1]))
        if isempty(r)
            return "Codeid $(m[1]) is not found"
        end
        return r[1]
    catch err
        @error exception=(err, catch_backtrace())
        return "Server error, please try one more time. Later. Sorry."
    end
end

function process_save(obj::ZulipRequest, db, opts)
    @info "save"
    hashtags = String[]
    length(obj.data) < 6 && return "Not enough arguments in `save` command"
    s = obj.data[6:end]

    while true
        m = match(r"^\s*(#[^\s]+)\s+(.*)"s, s)
        isnothing(m) && break
        push!(hashtags, m[1])
        s = m[2]
    end
    
    hashtags = join(hashtags, " ")
    token = codeid()
    try
        store_snippet(db, obj.message.sender_id, token, s, hashtags)
        return "Snippet codeid: `$token`"
    catch err
        @error "DB Error" exception=(err, catch_backtrace())
        return "Server error, please try one more time. Later. Sorry."
    end
end

function process_list(obj::ZulipRequest, db, opts)
    @info "list"
    snippets = load_snippets(db, obj.message.sender_id)
    snippets = map(x -> (; snippet = x.snippet, code = x.code, hashtags = x.tags, tags = split(x.tags, " ")), snippets)
    if length(obj.data) >= 6
        hashtags = String[]
        s = obj.data[6:end]

        while true
            m = match(r"^\s*(#[^\s]+)\s*(.*)"s, s)
            isnothing(m) && break
            push!(hashtags, m[1])
            s = m[2]
        end
        snippets = filter(x -> !isempty(intersect(hashtags, x.tags)), snippets)
    end
    
    isempty(snippets) && return "No snippets found"

    io = IOBuffer()
    for snippet in snippets
        println(io, "**codeid**: ", snippet.code, ", **tags**: ", snippet.hashtags)
        println(io, snippet.snippet, "\n")
    end
    res = strip(String(take!(io)))
    return res
end

function process_help(obj::ZulipRequest, db, opts)
    @info "help"
    return """
Currently following commands are supported

1. `list`: show all current reminders of a user
2. `<where> <when> <what>`: set a reminder. 
    - `where` is optional, should be either `me` or `#<topic_name>`. In latter case bot sends a message to a corresponding topic. If omitted reminder bot sends message to the same topic where it was called.
    - `when` can be either in form `X days Y hours Z minutes` or in a form `2020-10-01 23:15:00`
    - `what` is a message that should be shown by reminder bot.
3. `timezone <value>`: set timezone for current user
4. `help`: this message

Examples of usage:
- `me 2 days drink coffee`
- `2021-12-31 12:00:00 Happy New Year`
- `#cool_topic 1 hour Say something` - not implemented yet
    """
end


