using HTTP
using JSON3
using SQLite
using ZulipSnippetBot

include("configuration.jl")
setupbot!(token = TOKEN, host = HOST, port = PORT)
const db = SQLite.DB(DB)

ZulipSnippetBot.run(db)
