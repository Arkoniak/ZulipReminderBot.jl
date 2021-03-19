using ZulipReminderBot
using Documenter

DocMeta.setdocmeta!(ZulipReminderBot, :DocTestSetup, :(using ZulipReminderBot); recursive=true)

makedocs(;
    modules=[ZulipReminderBot],
    authors="Andrey Oskin",
    repo="https://github.com/Arkoniak/ZulipReminderBot.jl/blob/{commit}{path}#{line}",
    sitename="ZulipReminderBot.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://Arkoniak.github.io/ZulipReminderBot.jl",
        siteurl="https://github.com/Arkoniak/ZulipReminderBot.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/Arkoniak/ZulipReminderBot.jl",
)
