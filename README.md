# Installation

1. Set necessary configuration options in `configuration.jl`. Template can be found in `conf_template.jl`. Following constants should be defined

* `DB`: path to the sqlite database
* `HOST`: host, by default "127.0.0.1"
* `PORT`: port, by default 9174
* `TOKEN`: bot token, which you should  receive from zulip server. To do it, run `julia extras/echo.jl` and send message from zulip. In the output you'll see token.

2. Initialize database with
```julia
julia --project=. migrations.jl
```

3. Run server with 
```julia
julia --project=. snippetserver.jl
```

4. Enjoy

# Commands
Currently following commands are supported

1. `show <codeid>` - show snippet with the required `codeid`
2. `list <#hashtag1> <#hashtag2>` - shows all snippets of the author with corresponding hashtags. If no hashtags is provided returns all snippets.
3. `save <#hashtag1> <#hashtag2> <snippet>` - saves snippet in database with provided hashtags. In response server returns code_id, that can be used for snippet search.
4. `help` - this message
