# Installation

1. Set necessary configuration options in `.env` file. Template can be found in `.env_template`

* `REMINDER_BOT_DB`: path to the sqlite database
* `REMINDER_BOT_HOST`: host, by default "127.0.0.1"
* `REMINDER_BOT_PORT`: port, by default 9175
* `REMINDER_BOT_TOKEN`: bot token, which you should  receive from zulip server. To do it, run `julia extras/echo.jl` and send message from zulip. In the output you'll see token.

2. Logging options can be setup in `configuration.jl`. Example of configuration can be found in `conf_template.jl`

3. Initialize database with
```julia
julia --project=. migrations.jl
```

4. Run server with 
```julia
julia --project=. reminderserver.jl
```

5. Enjoy

# Commands
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
