using ZulipReminderBot

include("configuration.jl")

ZulipReminderBot.up(conn)

# There should be `down` function and some way to control db version...
