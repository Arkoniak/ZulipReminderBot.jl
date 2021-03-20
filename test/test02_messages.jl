module TestMessages

using ZulipReminderBot
using ZulipReminderBot: Adapter, ZulipRequest
using ZulipReminderBot: process_list
import ZulipReminderBot
using Test
using Dates
using Base64

import DBInterface

struct MockDB end
struct MockDBStmt 
    s::String
end

function ZulipReminderBot.prepare(db::Adapter{MockDB, MockDB}, query)
    MockDBStmt(query)
end

function DBInterface.execute(stmt::MockDBStmt, x)
    if stmt.s == "SELECT * FROM senders WHERE id = ?" && x == (1, )
        return [(id = 1, v1 = "Europe/London")]
    elseif stmt.s == "SELECT * FROM senders WHERE id = ?" && x == (2, )
        return [(id = 1, v1 = "UTC+4")]
    elseif stmt.s == "SELECT * FROM messages WHERE msg_sender_id = ?" && x == (1, )
        return [(id = 123, cts = 0, ets = 1622571921000, s1 = "Stream1", t1 = "Topic1", tp = "private", sid = 1, cn = base64encode("Hello"))]
    elseif stmt.s == "SELECT * FROM messages WHERE msg_sender_id = ?" && x == (2, )
        return [(id = 123, cts = 0, ets = 1622571921000, s1 = "Stream1", t1 = "Topic1", tp = "private", sid = 1, cn = base64encode("Hello")),
               (id = 124, cts = 0, ets = 1622571931000, s1 = "Stream1", t1 = "Topic1", tp = "private", sid = 1, cn = base64encode("Hello2"))]
    elseif stmt.s == "SELECT * FROM messages WHERE msg_sender_id = ?" && x == (3, )
        return []
    end
end

function DBInterface.close!(stmt::MockDBStmt) end

@testset "test list command" begin
    zreq = ZulipRequest()
    zreq.message.sender_id = 1
    db = Adapter(MockDB(), MockDB)

    res = process_list(zreq, db, nothing)
    @test res == "**id:** 123\n**scheduled:** 2021-06-01 16:25:21 +01:00\nHello"

    zreq.message.sender_id = 2
    res = process_list(zreq, db, nothing)
    @test res == "**id:** 123\n**scheduled:** 2021-06-01 19:25:21 +04:00\nHello\n---\n**id:** 124\n**scheduled:** 2021-06-01 19:25:31 +04:00\nHello2"
    zreq.message.sender_id = 3
    res = process_list(zreq, db, nothing)
    @test res == "No messages scheduled"
end

end # module
