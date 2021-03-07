using HTTP
using JSON3
using SQLite
using ZulipReminderBot
using DotEnv

include("configuration.jl")
cfg = DotEnv.config()
setupbot!(token = cfg["REMINDER_BOT_TOKEN"],
          host = cfg["REMINDER_BOT_HOST"],
          port = cfg["REMINDER_BOT_PORT"])
const db = SQLite.DB(cfg["REMINDER_BOT_DB"])

ZulipReminderBot.run(db)
