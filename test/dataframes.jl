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

@testset "facet_row_wrap and facet_col_wrap" begin
    df = stack(DataFrame(x=1:10, one=1, two=2, three=3, four=4, five=5, six=6, seven=7), Not(:x))
    # _43 means 4 subplots in row 1 and 3 in row 2
    p_43 = Plot(df, x=:x, y=:value, facet_row=:variable, facet_row_wrap=2)
    @test size(p_43.layout.subplots.grid_ref) == (2, 4)

    p_2221 = Plot(df, x=:x, y=:value, facet_col=:variable, facet_col_wrap=2)
    @test size(p_2221.layout.subplots.grid_ref) == (4, 2)

    p_7x7 = @test_logs (:warn, "cannot set facet_row and facet_col_wrap -- setting facet_col_wrap to missing") Plot(df, x=:x, y=:value, facet_col=:variable, facet_col_wrap=2, facet_row=:value)
    @test size(p_7x7.layout.subplots.grid_ref) == (7, 7)

end
