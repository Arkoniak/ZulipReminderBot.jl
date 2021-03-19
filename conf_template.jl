using Logging, MiniLoggers
global_logger(MiniLogger(level=Logging.Debug))

module Configuration

using ODBC

const conn1 = ODBC.Connection("Driver=/usr/lib/x86_64-linux-gnu/odbc/psqlodbcw.so;Server=127.0.0.1;Port=<db port>;Database=<db name>;Uid=<user name>;Pwd=<password>;")

precompile(ODBC.Connection, (String, ))

end # module

const conn = ZulipReminderBot.Adapter(Configuration.conn1, ZulipReminderBot.PostgresODBC)
