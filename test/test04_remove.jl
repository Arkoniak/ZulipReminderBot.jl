module TestRemove

using ZulipReminderBot
using ZulipReminderBot: Adapter, ZulipRequest, process_remove, process
using ZulipReminderBot: heartbeat!, TimedMessage, Message, Opts
using Dates

using Test

import DBInterface

struct MockDB end
struct MockDBStmt 
    s::String
end

function ZulipReminderBot.prepare(db::Adapter{MockDB, MockDB}, query)
    MockDBStmt(query)
end
function DBInterface.execute(stmt::MockDBStmt, x)
    if stmt.s == "DELETE FROM messages WHERE id = ? AND msg_sender_id = ?" && x == (1, 1)
        return []
    elseif stmt.s == "DELETE FROM messages WHERE id = ? AND msg_sender_id = ?" && x == (2, 1)
        return []
    end
end

function DBInterface.close!(stmt::MockDBStmt) end

function mockmessage(content; sender_id = 1, stream = "Stream1", topic = "Topic1", type = "stream")
    return Message(stream, topic, type, sender_id, content)
end

@testset "test process_remove command from same sender" begin
    tmsg1 = TimedMessage(1, 1, 100, mockmessage("Ping1"))
    cin = Channel{Tuple{TimedMessage, Int}}(Inf)
    cout = Channel{TimedMessage}(Inf)
    put!(cin, (tmsg1, 1))

    sched = TimedMessage[]
    heartbeat!(sched, 50, cin, cout)

    zreq = ZulipRequest()
    zreq.message.sender_id = 1
    zreq.data = "remove 1, 2"
    db = Adapter(MockDB(), MockDB)

    res = process_remove(zreq, db, cin, Dates.now(), nothing)
    @test res == "Messages were removed from the schedule"
    heartbeat!(sched, 51, cin, cout)
    @test length(sched) == 0
    @test !isready(cin)
    @test !isready(cout)
end

@testset "test process_remove command from different senders" begin
    tmsg1 = TimedMessage(1, 1, 100, mockmessage("Ping1"))
    cin = Channel{Tuple{TimedMessage, Int}}(Inf)
    cout = Channel{TimedMessage}(Inf)
    put!(cin, (tmsg1, 1))

    sched = TimedMessage[]
    heartbeat!(sched, 50, cin, cout)

    zreq = ZulipRequest()
    zreq.message.sender_id = 2
    zreq.data = "remove 1, 2"
    db = Adapter(MockDB(), MockDB)

    res = process_remove(zreq, db, cin, Dates.now(), nothing)
    @test res == "Messages were removed from the schedule"
    heartbeat!(sched, 51, cin, cout)
    @test length(sched) == 1
    @test sched[1].id == 1 && sched[1].msg.sender_id == 1
    @test !isready(cin)
    @test !isready(cout)
end

@testset "test process from same sender" begin
    opts = Opts("abc123", "", 0)
    tmsg1 = TimedMessage(1, 1, 100, mockmessage("Ping1"; type = "private"))
    cin = Channel{Tuple{TimedMessage, Int}}(Inf)
    cout = Channel{TimedMessage}(Inf)
    put!(cin, (tmsg1, 1))

    sched = TimedMessage[]
    heartbeat!(sched, 50, cin, cout)

    zreq = ZulipRequest()
    zreq.message.sender_id = 1
    zreq.data = "remove 1, 2"
    zreq.token = "abc123"
    db = Adapter(MockDB(), MockDB)

    res = process(zreq, db, cin, Dates.now(), opts)
    @test res == "{\"content\":\"Messages were removed from the schedule\"}"
    heartbeat!(sched, 51, cin, cout)
    @test length(sched) == 0
    @test !isready(cin)
    @test !isready(cout)
end

@testset "test process from different senders" begin
    opts = Opts("abc123", "", 0)
    tmsg1 = TimedMessage(1, 1, 100, mockmessage("Ping1"; type = "private"))
    cin = Channel{Tuple{TimedMessage, Int}}(Inf)
    cout = Channel{TimedMessage}(Inf)
    put!(cin, (tmsg1, 1))

    sched = TimedMessage[]
    heartbeat!(sched, 50, cin, cout)

    zreq = ZulipRequest()
    zreq.message.sender_id = 2
    zreq.data = "remove 1, 2"
    zreq.token = "abc123"
    db = Adapter(MockDB(), MockDB)

    res = process(zreq, db, cin, Dates.now(), opts)
    @test res == "{\"content\":\"Messages were removed from the schedule\"}"
    heartbeat!(sched, 51, cin, cout)
    @test length(sched) == 1
    @test sched[1].id == 1 && sched[1].msg.sender_id == 1
    @test !isready(cin)
    @test !isready(cout)
end

end # module
