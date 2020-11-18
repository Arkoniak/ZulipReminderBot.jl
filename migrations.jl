using SQLite
using DBInterface

include("configuration.jl")

db = SQLite.DB(DB)

function create_tables(db)
    create_snippets = """
    CREATE TABLE IF NOT EXISTS snippets
    (
        code TEXT,
        user_id INTEGER,
        snippet TEXT,
        tags TEXT,
        created TEXT
    )
    """
    DBInterface.execute(db, create_snippets)
    SQLite.createindex!(db, "snippets", "code_index", "code"; unique = true, ifnotexists = true)
end

function up(db)
    create_tables(db)
end

up(db)

# There should be `down` function and some way to control db version...
