# function create_tables(db)
#     create_snippets = """
#     CREATE TABLE IF NOT EXISTS snippets
#     (
#         code TEXT,
#         user_id INTEGER,
#         snippet TEXT,
#         tags TEXT,
#         created TEXT
#     )
#     """
#     DBInterface.execute(db, create_snippets)
#     SQLite.createindex!(db, "snippets", "code_index", "code"; unique = true, ifnotexists = true)
# end

function up(conn)
    create_table(conn, TimedMessage)
end
