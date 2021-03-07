########################################
# Database functionality
########################################

function get_by_code(db, code_id)
    query = """
    SELECT snippet
    FROM snippets
    WHERE code = ?
    """

    stmt = SQLite.Stmt(db, query)
    DBInterface.execute(stmt, (code_id, ))
end

function store_snippet(db, user_id, code_id, snippet, tags)
    query = """
    INSERT INTO snippets(code, user_id, snippet, tags, created) 
    VALUES (?, ?, ?, ?, ?)
    """

    ts = currentts()
    stmt = SQLite.Stmt(db, query)
    DBInterface.execute(stmt, (code_id, user_id, snippet, tags, ts))
end

function load_snippets(db, user_id)
    query = """
    SELECT code, snippet, tags
    FROM snippets
    WHERE user_id = ?
    """

    stmt = SQLite.Stmt(db, query)
    DBInterface.execute(stmt, (user_id, ))
end

