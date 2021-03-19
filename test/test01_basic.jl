module TestBasic
using ZulipReminderBot
using ZulipReminderBot: ZulipRequest, process, OPTS, Message
using ZulipReminderBot: isfixedtz
using JSON3
using Test
using Dates
using Logging

global_logger(ConsoleLogger(stderr, Logging.Warn))

f = readlines(joinpath(@__DIR__, "data", "requests.json"))
const MENTION_MSG = f[1]
# const PRIVATE_MSG = f[1]
# const WRONG_TOKEN = f[3]
# const NO_TOKEN = f[4]
# const NO_SENDER = f[5]
# const NO_DATA = f[6]
# const PRIVATE_HELP = f[7]
# const MENTION_HELP = f[8]

content(x) = JSON3.read(x).content

const TOKEN = "abc123"
setupbot!(; token = TOKEN, email = "foo@bar", apikey = "123")

@testset "test time" begin
    # msg = JSON3.read(MENTION_MSG, ZulipRequest)
    # c = Channel(1)
    # reply = process(msg, c)
    # @test startswith(content(reply), "Message is scheduled on 20")
end

@testset "test timezone parsing" begin
    @test isfixedtz("UTC+1")
    @test isfixedtz("UTC+12")
    @test isfixedtz("UTC-1")
    @test isfixedtz("UTC-12")
    @test !isfixedtz("UTC+123")
    @test !isfixedtz("GMT-1")
end

end # module
