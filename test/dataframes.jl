@testset "DataFrame constructor" begin
    df = DataFrame(x=1:10, y=sin.(1:10))
    p = Plot(df, x=:x, y=:y)
    @test p isa Plot
    @test length(p.data) == 1
    @test p.layout.xaxis_title == Dict(:text => :x)
    @test p.layout.yaxis_title == Dict(:text => :y)
end


@testset "overriding yaxis_title" begin
    df = DataFrame(x=1:10, y=sin.(1:10))
    p = Plot(df, x=:x, y=:y, Layout(yaxis_title="sin(x)"));
    @test p.layout.xaxis_title == Dict(:text => :x)
    @test p.layout.yaxis_title == Dict(:text => "sin(x)")
end

@testset "overriding yaxis_title_text" begin
    df = DataFrame(x=1:10, y=sin.(1:10))
    p = Plot(df, x=:x, y=:y, Layout(yaxis_title_text="sin(x)"));
    @test p.layout.xaxis_title == Dict(:text => :x)
    @test p.layout.yaxis_title == Dict(:text => "sin(x)")
end

@testset "overriding yaxis_title with attr(text=, x=)" begin
    df = DataFrame(x=1:10, y=sin.(1:10))
    p = Plot(df, x=:x, y=:y, Layout(yaxis_title=attr(x=0.5, text="sin(x)")));
    @test p.layout.xaxis_title == Dict(:text => :x)
    @test p.layout.yaxis_title_text == "sin(x)"
    @test p.layout.yaxis_title == Dict(:text => "sin(x)", :x => 0.5)
end
