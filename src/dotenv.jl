module DotEnv

# I have an issue with original DotEnv, so this have to be used instead.

import Base: getindex, get, isempty

struct EnvProxyDict
    dict::Dict{String, String}
end

getindex(ed::EnvProxyDict, key) = get(ed.dict, key, ENV[key])
get(ed::EnvProxyDict, key, default) = get(ed.dict, key, get(ENV, key, default))
isempty(ed::EnvProxyDict) = isempty(ed.dict)

"""
`DotEnv.parse` accepts a String or an IOBuffer (any value that
 can be converted into String), and it return a Dict with
 the parsed keys and values.
"""
function parse(src)
    res = Dict{String,String}()
    src = IOBuffer(src)
    for line in eachline(src)
        m = match(r"^\s*([\w.-]+)\s*=\s*(.*)?\s*$", line)
        if m !== nothing
            key = m.captures[1]
            value = string(m.captures[2])

            if (length(value) > 0 && value[1] === '"' && value[end] === '"')
                value = replace(value, r"\\n"m => "\n")
            end

            value = replace(value, r"(^['\u0022]|['\u0022]$)" => "")

            value = strip(value)

            push!(res, key => value)
        end
    end
    res
end


"""
    config(path, override = true)
    config(; path = ".env", override = true)
    load(path, override = true)
    load(; path = ".env", override = true)
`config` or `load` reads your `path` .env file, parse the content, stores it to `ENV`,
and finally return a `EnvProxyDict` with the content. By default if key already exists in 
`ENV` it is overriden with the values in .env file. This behaviour can be changed by 
setting `override` flag to `false`.
"""
function config(path, override = true)
    if (isfile(path))
        parsed = parse(read(path, String))

        for (k, v) in parsed
            if !haskey(ENV, k) || override
                ENV[k] = v
            end
        end

        return EnvProxyDict(parsed)
    else
        return EnvProxyDict(Dict{String, String}())
    end
end

config(;path=".env", override = true) = config(path, override)

const load = config

end
