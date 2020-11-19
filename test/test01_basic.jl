module TestBasic
using ZulipSnippetBot
using ZulipSnippetBot: ZulipRequest, process, OPTS, Message
using JSON3
using Test
using SQLite
using Logging

global_logger(ConsoleLogger(stderr, Logging.Warn))

f = readlines(joinpath(@__DIR__, "data", "requests.json"))
const PRIVATE_MSG = f[1]
const MENTION_MSG = f[2]
const WRONG_TOKEN = f[3]
const NO_TOKEN = f[4]
const NO_SENDER = f[5]
const NO_DATA = f[6]
const PRIVATE_HELP = f[7]
const MENTION_HELP = f[8]

content(x) = JSON3.read(x).content
extract_codeid(x) = match(r"Snippet codeid: `([^`]+)`", content(x))[1]

const TOKEN = "3xP6YwzEQr9dr2TCrzn28Yrvx4FtFgC0"
setupbot!(; token = TOKEN)

@testset "test input" begin
    msg = JSON3.read(PRIVATE_MSG, ZulipRequest)
    @test msg.data == "Hello"
    @test msg.token == "3xP6YwzEQr9dr2TCrzn28Yrvx4FtFgC0"
    @test msg.message.sender_id == 1234

    msg = JSON3.read(MENTION_MSG, ZulipRequest)
    @test msg.data == "@**SnippetBot** Bang"
    @test msg.token == "3xP6YwzEQr9dr2TCrzn28Yrvx4FtFgC0"
    @test msg.message.sender_id == 1234
end

@testset "Simple errors" begin
    msg = JSON3.read(WRONG_TOKEN, ZulipRequest)
    @test content(process(msg, nothing, OPTS[])) == "Incorrect token, verify SnippetBot server configuration"

    msg = JSON3.read(NO_TOKEN, ZulipRequest)
    @test content(process(msg, nothing, OPTS[])) == "Wrong message"

    msg = JSON3.read(NO_SENDER, ZulipRequest)
    @test content(process(msg, nothing, OPTS[])) == "Wrong message"

    msg = JSON3.read(NO_DATA, ZulipRequest)
    @test content(process(msg, nothing, OPTS[])) == "Wrong message"
end

@testset "help" begin
    msg = JSON3.read(PRIVATE_HELP, ZulipRequest)
    @test startswith(content(process(msg, nothing, OPTS[])), "Currently following")    

    msg = JSON3.read(MENTION_HELP, ZulipRequest)
    @test startswith(content(process(msg, nothing, OPTS[])), "Currently following")    
end

@testset "save/show" begin
    dbpath, _ = mktemp()
    db = SQLite.DB(dbpath)
    ZulipSnippetBot.up(db)

    msg = ZulipRequest("save #qwe abc", TOKEN, Message(1))
    res = content(process(msg, db, OPTS[]))
    @test startswith(res, "Snippet codeid: ")

    cid = match(r"Snippet codeid: `([^`]+)`", res)[1]
    msg = ZulipRequest("show $(cid)", TOKEN, Message(1))
    @test content(process(msg, db, OPTS[])) == "abc"

    msg = ZulipRequest("show xxx", TOKEN, Message(1))
    @test content(process(msg, db, OPTS[])) == "Codeid xxx is not found"
end

@testset "save/list" begin
    dbpath, _ = mktemp()
    db = SQLite.DB(dbpath)
    ZulipSnippetBot.up(db)

    msg = ZulipRequest("save #qwe abc", TOKEN, Message(1))
    cid1 = extract_codeid(process(msg, db, OPTS[])) 

    msg = ZulipRequest("save #qwe #zxc abc2", TOKEN, Message(1))
    cid2 = extract_codeid(process(msg, db, OPTS[]))

    msg = ZulipRequest("save #foo abc3", TOKEN, Message(1))
    cid3 = extract_codeid(process(msg, db, OPTS[]))

    msg = ZulipRequest("save #qwe foo", TOKEN, Message(2))
    cid4 = extract_codeid(process(msg, db, OPTS[]))

    msg = ZulipRequest("list #qwe", TOKEN, Message(1))
    # These are dangerous, because order is not determined... Maybe I can use mocks here...
    @test content(process(msg, db, OPTS[])) == "**codeid**: $cid1, **tags**: #qwe\nabc\n\n**codeid**: $cid2, **tags**: #qwe #zxc\nabc2"

    msg = ZulipRequest("list #zxc", TOKEN, Message(1))
    @test content(process(msg, db, OPTS[])) == "**codeid**: $cid2, **tags**: #qwe #zxc\nabc2"

    msg = ZulipRequest("list", TOKEN, Message(1))
    @test content(process(msg, db, OPTS[])) == "**codeid**: $cid1, **tags**: #qwe\nabc\n\n**codeid**: $cid2, **tags**: #qwe #zxc\nabc2\n\n**codeid**: $cid3, **tags**: #foo\nabc3"

    msg = ZulipRequest("list #qwe", TOKEN, Message(2))
    @test content(process(msg, db, OPTS[])) == "**codeid**: $cid4, **tags**: #qwe\nfoo"

    msg = ZulipRequest("list #foo", TOKEN, Message(2))
    @test content(process(msg, db, OPTS[])) == "No snippets found"

    msg = ZulipRequest("list", TOKEN, Message(3))
    @test content(process(msg, db, OPTS[])) == "No snippets found"
end

end # module
