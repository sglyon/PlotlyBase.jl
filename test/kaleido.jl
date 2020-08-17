function myplot(fn)
    x = 0:0.1:2π
    plt = Plot(scatter(x=x, y=sin.(x)))
    savefig(plt, fn)
end

@testset "kaleido" begin
    for ext in PlotlyBase.ALL_FORMATS
        if ext === "eps"
            continue
        end
        @show fn = tempname() * "." * ext
        myplot(fn) == fn
        @test isfile(fn)
    end
end
