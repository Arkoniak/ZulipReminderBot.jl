module TestParser

using ZulipReminderBot
using ZulipReminderBot: zparse, Adapter, ZulipRequest, process, Opts, TimedMessage, toepoch
using Test
using Dates
using Base64
using TimeZones
using StableRNGs
using StatsBase

import DBInterface

struct MockDB end
struct MockDBStmt 
    s::String
end

function ZulipReminderBot.prepare(db::Adapter{MockDB, MockDB}, query)
    MockDBStmt(query)
end

function DBInterface.close!(stmt::MockDBStmt) end

function DBInterface.execute(stmt::MockDBStmt, x)
    if stmt.s == "SELECT * FROM senders WHERE id = ?" && x == (1, )
        return [(id = 1, v1 = "UTC+4")]
    elseif stmt.s == "INSERT INTO messages (createts, exects, msg_stream, msg_topic, msg_type, msg_sender_id, msg_content) VALUES (?,?,?,?,?,?,?) RETURNING id"
        return (;columns = 10)
    end
end

@testset "absolute time" begin
    gmsgs = [("2021-01-02 03:04:05", DateTime("2021-01-02T03:04:05")),
             ("2021-01-02 03:04", DateTime("2021-01-02T03:04:00")),
             ("2021-01-02 03", DateTime("2021-01-02T03:00:00")),
             ("2021-01-02", DateTime("2021-01-02T00:00:00")),
             ("2021-01-02  3", DateTime("2021-01-02T00:00:00"))]
    bmsgs = [["2021-01-02 25:04:05"],
             ["2021-13-12 01:02:03"],
             ["2021-01-13S01:02:02"],
            ]

    @testset "Prefix test for $prefix" for prefix in ["", "me ", "ME "]
        @testset "Good absolute message $(x[1])" for (i, x) in pairs(gmsgs)
            gde, tp, msg, exects = zparse(prefix*x[1]*"\nHello")
            @test gde == :me
            @test tp == :absolute
            @test msg == (i == 5 ? "3\nHello" : "Hello")
            @test exects == x[2]
        end
    end

    @testset "Prefix test for $prefix" for prefix in ["here ", "HERE "]
        @testset "Good absolute message $(x[1])" for (i, x) in pairs(gmsgs)
            gde, tp, msg, exects = zparse(prefix*x[1]*"\nHello")
            @test gde == :here
            @test tp == :absolute
            @test msg == (i == 5 ? "3\nHello" : "Hello")
            @test exects == x[2]
        end
    end
    
    @testset "Bad absolute message $x" for x in bmsgs
        gde, tp, msg, exects = zparse(x[1]*"\nHello")
        @test tp == :unknown
    end
end


@testset "relative time" begin
    ts = DateTime(Date("2021-02-03"))
    MS = (["1 month", "1 months", "1 Month"], Month(1))
    W = (["2 week", "2 weeks", "2 WEEK"], Week(2))
    D = (["3 day", "3 days", "3 DAY"], Day(3))
    H = (["4 hour", "4 hours", "4 HOURS"], Hour(4))
    M = (["5 minute", "5 min", "5 minutes", "5 MIN"], Minute(5))
    S = (["6 second", "6 sec", "6 seconds", "6 SEC"], Second(6))
    MSN = (["-1 month", "-1 months", "-1 Month"], Month(-1))
    WN = (["-2 week", "-2 weeks", "-2 WEEK"], Week(-2))
    DN = (["-3 day", "-3 days", "-3 DAY"], Day(-3))
    HN = (["-4 hour", "-4 hours", "-4 HOURS"], Hour(-4))
    MN = (["-5 minute", "-5 min", "-5 minutes", "-5 MIN"], Minute(-5))
    SN = (["-6 second", "-6 sec", "-6 seconds", "-6 SEC"], Second(-6))
    
    full = [MS, W, D, H, M, S, MSN, WN, DN, HN, MN, SN]
    @testset "Test for i=$i" for i in 1:length(full)
        @testset "Test for $x" for x in full[i][1]
            msg = "" * x * "\nHello"
            gde, tp, msg, exects = zparse(msg, ts)
            @test gde == :me
            @test tp == :relative
            @test msg == "Hello"
            @test exects == ts + full[i][2]

            msg = "me " * x * "\nHello"
            gde, tp, msg, exects = zparse(msg, ts)
            @test gde == :me
            @test tp == :relative
            @test msg == "Hello"
            @test exects == ts + full[i][2]

            msg = "ME " * x * "\nHello"
            gde, tp, msg, exects = zparse(msg, ts)
            @test gde == :me
            @test tp == :relative
            @test msg == "Hello"
            @test exects == ts + full[i][2]

            msg = "here " * x * "\nHello"
            gde, tp, msg, exects = zparse(msg, ts)
            @test gde == :here
            @test tp == :relative
            @test msg == "Hello"
            @test exects == ts + full[i][2]

            msg = "HERE " * x * "\nHello"
            gde, tp, msg, exects = zparse(msg, ts)
            @test gde == :here
            @test tp == :relative
            @test msg == "Hello"
            @test exects == ts + full[i][2]
        end
    end

    combs = [full[1:6], reverse(full[1:6]), full[7:12], reverse(full[7:12])]
    rng = StableRNG(2021)
    for _ in 1:100
        push!(combs, sample(rng, full, 6, replace = false))
    end

    for comb in combs
        msg = ""
        calcts = deepcopy(ts)
        for el in comb
            msg *= el[1][1]
            calcts += el[2]
        end
        msg *= "\nHello"
        gde, tp, msg, exects = zparse(msg, ts)
        @test gde == :me
        @test tp == :relative
        @test msg == "Hello"
        @test exects == calcts
    end
end

@testset "process reminders" begin
    opts = Opts("abc123", "", 0)
    zreq = ZulipRequest()
    zreq.message.sender_id = 1
    zreq.token = "abc123"
    db = Adapter(MockDB(), MockDB)
    cin = Channel{Tuple{TimedMessage, Int}}(Inf)
    ts = DateTime("2021-03-01T01:02:03")

    @testset "Malformed message" begin
        zreq.data = "2021-14-01\nHello"
        res = process(zreq, db, cin, ts, opts)
        @test !isready(cin)
        @test startswith(res, "{\"content\":\"Unable to process message")
    end

    @testset "Absolute date message" begin
        zreq.data = "2021-10-01 12:15:13\nHello"
        zreq.message.type = "private"
        res = process(zreq, db, cin, ts, opts)
        @test isready(cin)
        tmsg = "" # placeholder to raise error
        if isready(cin)
            tmsg, flag = take!(cin)
            content = base64decode(tmsg.msg.content) |> String
            @test flag == 1
            @test tmsg.id == 10
            @test tmsg.exects == 1633076113000
            @test content == "**Reminder**: Hello"
        end
        @test res == "{\"content\":\"Message is scheduled on 2021-10-01 12:15:13 +04:00\"}"
    end

    @testset "Relative date message" begin
        intexects = toepoch(ts + Day(1) + Hour(2))
        zreq.data = "1 day 2 hours\nHello"
        zreq.message.type = "private"
        res = process(zreq, db, cin, ts, opts)
        @test isready(cin)
        tmsg = "" # placeholder to raise error
        if isready(cin)
            tmsg, flag = take!(cin)
            content = base64decode(tmsg.msg.content) |> String
            @test flag == 1
            @test tmsg.id == 10
            @test tmsg.exects == intexects
            @test content == "**Reminder**: Hello"
        end
    end

    @testset "Message send from a stream" begin
        zreq.data = "@**RemBot** 2021-10-01 12:15:13\nHello"
        zreq.message.type = "stream"
        zreq.message.stream_id = 100
        zreq.message.subject = "Topic1"
        zreq.message.display_recipient = "Stream1"

        cin = Channel{Tuple{TimedMessage, Int}}(Inf)
        res = process(zreq, db, cin, ts, opts)
        @test isready(cin)
        tmsg = "" # placeholder to raise error
        if isready(cin)
            tmsg, flag = take!(cin)
            content = base64decode(tmsg.msg.content) |> String
            @test flag == 1
            @test tmsg.id == 10
            @test tmsg.exects == 1633076113000
            @test content == "/#narrow/stream/100-Stream1/topic/Topic1/near/-1\n**Reminder**: Hello"
        end
        @test res == "{\"content\":\"Message is scheduled on 2021-10-01 12:15:13 +04:00\"}"
    end

    @testset "Message send to a stream" begin
        zreq.data = "@**RemBot** here 2021-10-01 12:15:13\nHello"
        zreq.message.type = "stream"
        zreq.message.stream_id = 100
        zreq.message.subject = "Topic1"
        zreq.message.sender_full_name = "Pupkin"
        zreq.message.display_recipient = "Stream1"

        cin = Channel{Tuple{TimedMessage, Int}}(Inf)
        res = process(zreq, db, cin, ts, opts)
        @test isready(cin)
        tmsg = "" # placeholder to raise error
        if isready(cin)
            tmsg, flag = take!(cin)
            content = base64decode(tmsg.msg.content) |> String
            @test flag == 1
            @test tmsg.id == 10
            @test tmsg.exects == 1633076113000
            @test content == "On behalf of @**Pupkin**\n/#narrow/stream/100-Stream1/topic/Topic1/near/-1\nHello"
        end
        @test res == "{\"content\":\"Message is scheduled on 2021-10-01 12:15:13 +04:00\"}"
    end
end

end # module
