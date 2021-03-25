# ZulipReminder Bot
|                                                                                                         **Documentation**                                                                                                         |                                                                                                                                           **Build Status**                                                                                                                                            |
|:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------:|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------:|
| [![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://Arkoniak.github.io/ZulipReminderBot.jl/stable)[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://Arkoniak.github.io/ZulipReminderBot.jl/dev) |    [![Build](https://github.com/Arkoniak/ZulipReminderBot.jl/workflows/CI/badge.svg)](https://github.com/Arkoniak/ZulipReminderBot.jl/actions)[![Coverage](https://codecov.io/gh/Arkoniak/ZulipReminderBot.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/Arkoniak/ZulipReminderBot.jl)     |

# Installation

1. Set necessary configuration options in `.env` file. Template can be found in `.env_template`

## Server variables
* `REMINDER_BOT_HOST`: host, by default "127.0.0.1"
* `REMINDER_BOT_PORT`: port, by default 9175

## Zulip config
* `REMINDER_BOT_ZULIPCHAT`: url of Zulip chat, e.g. `https://my-organization.zulipchat.com`
* `REMINDER_BOT_EMAIL`: email which was used to register in bot in Zulip chat
* `REMINDER_BOT_API_KEY`: api key of the bot, which can be found in bot settings of the corresponding Zulip chat.
* `REMINDER_BOT_TOKEN`: bot token, which you should  receive from zulip server. To do it, run `julia extras/echo.jl` and send message from zulip. In the output you'll see token.

2. Logging and database options should be set in `configuration.jl`. Example of configuration can be found in `conf_template.jl`. Currently only postgresql is supported.

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

1. `<where> <when> <what>`: set a reminder. 
    - `where` is optional, should be either `me` or `here`. In latter case bot sends a message to the topic where reminder was set. If `where` is omitted reminder bot sends message privately to the person who set the reminder.
    - `when` can be either in relative form `X days Y hours Z minutes` or in an absolute form `2020-10-01 23:15:00`. In relative forms single or plural form of `month`, `week`, `day`, `hour`, `minute`, `second` are allowed as well as positive and negative values of `X`, `Y`, `Z`. In absolute form date is mandatory, but hours, minute or second part can be omitted.
    - `what` is a message that should be shown by reminder bot.
2. `list`: show all current reminders of a user.
3. `remove <id>`: remove your reminder with the id `<id>`. Multiple `<id>` can be given comma separated.
4. `timezone <value>`: set timezone for current user. If `<value>` is omitted, then current setting is used. Value should be in a form `Europe/Amsterdam`, `America/New_York` and the like.
5. `help`: this message

Examples of usage:
- `me 2 days drink coffee` (send private message in two hours)
- `1 day -2 hour redo things` (send message tomorrow, two hours earlier than today's current time)
- `2021-12-31 12:00 Happy New Year` (send private message on the midnight of 31 December 2021)
- `here 1 hour Say something` (send message to the stream in 1 hour)
    """
