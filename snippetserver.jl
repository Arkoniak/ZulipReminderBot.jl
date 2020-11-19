using HTTP
using JSON3
using ZulipSnipperBot

include("configuration.jl")
setupbot!(token = TOKEN, host = HOST, port = PORT)
const db = SQLite.DB(DB)

ZulipSnipperBot.run(db)
