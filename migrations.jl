using ZulipSnippetBot

include("configuration.jl")

db = SQLite.DB(DB)

ZulipSnippetBot.up(db)

# There should be `down` function and some way to control db version...
