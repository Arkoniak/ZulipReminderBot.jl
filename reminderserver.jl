using ZulipReminderBot
using DotEnv

include("configuration.jl")
cfg = DotEnv.config()
setupbot!(token = cfg["REMINDER_BOT_TOKEN"],
          host = cfg["REMINDER_BOT_HOST"],
          port = cfg["REMINDER_BOT_PORT"],
          email = cfg["REMINDER_BOT_EMAIL"],
          apikey = cfg["REMINDER_BOT_API_KEY"],
          ep = cfg["REMINDER_BOT_ZULIPCHAT"])

# const db = SQLite.DB(cfg["REMINDER_BOT_DB"])

ZulipReminderBot.run(conn)
