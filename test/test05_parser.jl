module TestParser

using ZulipReminderBot
using ZulipReminderBot: zparse
using Test
using Dates

struct TestState
    msg::String
    ts::DateTime
    gde::Symbol
    state::Int
end

struct TestResult
    msg::String
    ts::DateTime
    gde::Symbol
end

function build_absolute_times()
    preprefix = [["", "me ", "here "], []]
    prefix = [["2021-05-06"], []]
    D = [[" ", "T", "  "], ["+", "-", ":"]]
    H = [["1", "01"], ["13", "100", "-15"]]
    M = [[":2", ":02"], [":60", ":-12", ":123"]]
    S = [[":3", ":03"], [":60", ":-12", ":123"]]
    
    infixes = [preprefix, prefix, D, H, M, S]

    postfix = "\nHello"
    state0 = TestState("", DateTime(0), :init, 0)
    states = [state0]
    results = TestResult[]
    while !isempty(states)
        state = pop!(states)
        state.state != 0 && push!(results, TestResult(state.msg * postfix, state.ts, state.state < 2 ? :unknown : state.gde))
        is = state.state + 1
        is > length(infixes) && continue
        elems = infixes[is]
        for (i, goodelem) in pairs(elems[1])
            gde = state.gde == :unknown ? :unknown : 
                    is == 1 && i == 1 ? :me :
                    is == 1 && i == 2 ? :me :
                    is == 1 && i == 3 ? :here : state.gde
            ts = if is == 1
                DateTime(0)
            elseif is == 2
                DateTime(Date(goodelem), Time(0))
            elseif is == 3
                state.ts
            elseif is == 4
                state.ts + Hour(1)
            elseif is == 5
                state.ts + Minute(2)
            elseif is == 6
                state.ts + Second(3)
            end
            tstate = TestState(state.msg*goodelem, ts, gde, is)
            push!(states, tstate)
        end

        for badelem in elems[2]
            tstate = TestState(state.msg*badelem, DateTime(0), :unknown, is)
            push!(states, tstate)
        end
    end

    return results
end


@testset "absolute time" begin
    results = build_absolute_times()
    ts = DateTime(2021, 1, 1, 0, 0, 0)
    for testcase in results
        gde, tp, msg, exects = zparse(testcase.msg, ts)
        if testcase.gde == :unknown
            @test tp == :unknown
        else
            @test gde == testcase.gde
            @test tp == :absolute
            @test msg == "Hello"
            @test exects == testcase.ts
        end
    end
end

@testset "relative time" begin
end

end # module
