make_t1() = Template(data=attr(
    scatter=[attr(marker_color="red"), attr(marker_color="blue")]
))

make_t2() = Template(data=attr(
    scatter=[attr(marker_line_color="black")],
    bar=[attr(marker_color="cyan")]
))
make_t3() = merge(make_t1(), make_t2())

@testset "Templates" begin

    @testset "constructor with data::PlotlyAttribute" begin
        t1 = make_t1()
        @test t1 isa Template
        @test isempty(t1.layout)
        @test length(t1.data[:scatter]) == 2
    end

    @testset "merge templates" begin
        t1 = make_t1()
        t2 = make_t2()
        t3 = merge(t1, t2)

        # test that neither t1 nor t2 were modified
        @test length(t1.data[:scatter]) == 2
        @test length(t2.data[:scatter]) == 1
        @test !haskey(t1.data, :bar)

        # test that updates were applied
        @test length(t3.data[:scatter]) == 2
        @test t3.data[:scatter][1] == attr(marker=attr(color="red", line_color="black"))
        @test t3.data[:scatter][2] == attr(marker_color="blue", marker_line_color="black")
        @test t3.data[:bar][1] == attr(marker_color="cyan")
    end

    @testset "Can save Template to `templates` object" begin
        t1 = make_t1()
        templates.foobar = t1
        @test haskey(templates.templates, :foobar)

        # clean up
        pop!(templates.templates, :foobar)
    end

    @testset "Multiple templates via `+` syntax" begin
        t1 = make_t1()
        t2 = make_t2()
        templates.t1 = t1
        templates.t2 = t2

        @test templates["t1+t2"] == merge(t1, t2)
        # clean up
        pop!(templates.templates, :t1)
        pop!(templates.templates, :t2)
    end

    @testset "loading known templates from file" begin
        @test templates["ggplot2"] isa Template
        @test templates["plotly_dark"] isa Template

    end

end
