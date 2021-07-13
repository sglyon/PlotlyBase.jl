@testset "Subplots" begin

    @testset "rows=1, cols=2" begin
        have1 = Layout(Subplots(rows=1, cols=2))

        # shared_xaxes does nothing with 1 column
        have2 = Layout(Subplots(rows=1, cols=2, shared_xaxes=false))

        for have in (have1, have2)
            @test have[:xaxis] == attr(anchor="y", domain=(0.0, 0.45)).fields
            @test have[:yaxis] == attr(anchor="x", domain=(0.0, 1.0)).fields
            @test have[:xaxis2] == attr(anchor="y2", domain=(0.55, 1.0)).fields
            @test have[:yaxis2] == attr(anchor="x2", domain=(0.0, 1.0)).fields
        end
    end

    @testset "rows=1, cols=2, shared_yaxes=true" begin
        have = Layout(Subplots(rows=1, cols=2, shared_yaxes=true))
        @test have[:xaxis] == attr(anchor="y", domain=(0.0, 0.45)).fields
        @test have[:yaxis] == attr(anchor="x", domain=(0.0, 1.0)).fields
        @test have[:xaxis2] == attr(anchor="y2", domain=(0.55, 1.0)).fields
        @test have[:yaxis2] == attr(anchor="x2", domain=(0.0, 1.0), matches="y", showticklabels=false).fields
    end

    @testset "rows=2, cols=1" begin
        have1 = Layout(Subplots(rows=2, cols=1))

        # shared_yaxes does nothing with 1 column
        have2 = Layout(Subplots(rows=2, cols=1, shared_yaxes=true))

        for have in (have1, have2)
            @test have[:xaxis] == attr(anchor="y", domain=(0.0, 1.0)).fields
            @test have[:yaxis] == attr(anchor="x", domain=(0.575, 1.0)).fields
            @test have[:xaxis2] == attr(anchor="y2", domain=(0.0, 1.0)).fields
            @test have[:yaxis2] == attr(anchor="x2", domain=(0.0, 0.425)).fields
        end
    end

    @testset "rows=2, cols=1, shared_yaxes=true" begin
        have = Layout(Subplots(rows=2, cols=1, shared_xaxes=true))
        @test have[:xaxis] == attr(anchor="y", domain=(0.0, 1.0), matches="x2", showticklabels=false).fields
        @test have[:yaxis] == attr(anchor="x", domain=(0.575, 1.0)).fields
        @test have[:xaxis2] == attr(anchor="y2", domain=(0.0, 1.0)).fields
        @test have[:yaxis2] == attr(anchor="x2", domain=(0.0, 0.425)).fields
    end

end
