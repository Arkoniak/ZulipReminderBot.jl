module TestBasic
using ZulipSnippetBot
using ZulipSnippetBot: ZulipRequest, process, OPTS
using JSON3
using Test

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

end # module
