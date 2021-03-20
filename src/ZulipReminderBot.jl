module ZulipReminderBot

using Base64
using HTTP
using JSON3
using StructTypes
using Dates
using DBInterface
using Strapping
using TimeZones
using Setfield

include("dotenv.jl")
include("miniorm.jl")
include("db_utils.jl")
include("migrations.jl")
include("zulipclient.jl")
include("parser.jl")
include("processors.jl")
include("server.jl")

export setupbot!
export DotEnv

precompile(cron_worker, (Channel{TimedMessage}, Channel{TimedMessage}))
precompile(HTTP.Handlers.serve, (Function, String, Int64))
precompile(JSON3.read, (Vector{UInt8}, ))
precompile(JSON3.read, (JSON3.VectorString{Vector{UInt8}}, ))
precompile(HTTP.request, (String, String, Vector{Pair{String, String}}, String))
precompile(HTTP.request, (String, String, Vector{Pair{String, String}}, SubString{String}))
precompile(query, (ZulipClient, String, Dict{Symbol, String}))

end # module
