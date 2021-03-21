module TestCron

using ZulipReminderBot
using ZulipReminderBot: cron_worker, heartbeat!, TimedMessage, Message, curts
using Test

function mockmessage(content; sender_id = 1, stream = "Stream1", topic = "Topic1", type = "stream")
    return Message(stream, topic, type, sender_id, content)
end

@testset "Two incoming messages after current time" begin
    tmsg1 = TimedMessage(1, 1, 100, mockmessage("Ping1"))
    tmsg2 = TimedMessage(2, 2, 200, mockmessage("Ping2"))

    cin = Channel{Tuple{TimedMessage, Int}}(Inf)
    cout = Channel{TimedMessage}(Inf)
    put!(cin, (tmsg1, 1))
    put!(cin, (tmsg2, 1))

    sched = TimedMessage[]
    heartbeat!(sched, 10, cin, cout)
    @test !isready(cin)
    @test !isready(cout)

    @test length(sched) == 2
    @test sched[1].id == 2
    @test sched[2].id == 1
end

@testset "Two message, one should be executed" begin
    tmsg1 = TimedMessage(1, 1, 100, mockmessage("Ping1"))
    tmsg2 = TimedMessage(2, 2, 200, mockmessage("Ping2"))

    cin = Channel{Tuple{TimedMessage, Int}}(Inf)
    cout = Channel{TimedMessage}(Inf)
    put!(cin, (tmsg1, 1))
    put!(cin, (tmsg2, 1))

    sched = TimedMessage[]
    heartbeat!(sched, 150, cin, cout)

    @test !isready(cin)

    @test length(sched) == 1
    @test sched[1].id == 2
    
    @test isready(cout)
    tmsg = take!(cout)
    @test !isready(cout)
    @test tmsg.id == 1
end

@testset "Message and remove, same sender" begin
    tmsg1 = TimedMessage(1, 1, 100, mockmessage("Ping1", sender_id = 1))
    tmsg2 = TimedMessage(1, 2, 0, mockmessage("Ping2", sender_id = 1))

    cin = Channel{Tuple{TimedMessage, Int}}(Inf)
    cout = Channel{TimedMessage}(Inf)
    put!(cin, (tmsg1, 1))

    sched = TimedMessage[]
    heartbeat!(sched, 50, cin, cout)
    
    put!(cin, (tmsg2, -1))
    heartbeat!(sched, 51, cin, cout)

    @test isempty(sched)
    @test !isready(cin)
    @test !isready(cout)
end

@testset "Message and remove, different senders" begin
    tmsg1 = TimedMessage(1, 1, 100, mockmessage("Ping1", sender_id = 1))
    tmsg2 = TimedMessage(1, 2, 0, mockmessage("Ping2", sender_id = 2))

    cin = Channel{Tuple{TimedMessage, Int}}(Inf)
    cout = Channel{TimedMessage}(Inf)
    put!(cin, (tmsg1, 1))

    sched = TimedMessage[]
    heartbeat!(sched, 50, cin, cout)
    
    put!(cin, (tmsg2, -1))
    heartbeat!(sched, 51, cin, cout)

    @test !isempty(sched)
    @test length(sched) == 1
    @test sched[1].id == 1
    @test !isready(cin)
    @test !isready(cout)
end

@testset "cronworker" begin
    ts = curts()
    tmsg1 = TimedMessage(1, 1, ts - 10_000, mockmessage("Ping1"))
    tmsg2 = TimedMessage(2, 2, ts + 10_000, mockmessage("Ping2"))

    cin = Channel{Tuple{TimedMessage, Int}}(Inf)
    cout = Channel{TimedMessage}(Inf)
    put!(cin, (tmsg1, 1))
    put!(cin, (tmsg2, 1))

    sched = TimedMessage[]
    # I can't quite get the logic of tasks, but ok...
    task = @async cron_worker(cin, cout, sched, 0.05)
    sleep(0.5)

    @test !isready(cin)
    @test isready(cout)
    tmsg = take!(cout)
    @test tmsg.id == 1
    @test length(sched) == 1
    @test sched[1].id == 2
end

end
