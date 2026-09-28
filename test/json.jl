
gt = PlotlyBase.GenericTrace("scatter"; x=1:10, y=(1:10).^2)
pplot = PlotlyBase.Plot(gt)
layout = PlotlyBase.Layout()

using PlotlyBase.JSON, JSON3

@testset "Convert to json" begin
    # The key order of the `JSON.json` output depends on the JSON version, so compare the parsed objects.
    @test JSON.parse(JSON.json(gt)) == JSON.parse("{\"y\":[1,4,9,16,25,36,49,64,81,100],\"type\":\"scatter\",\"x\":[1,2,3,4,5,6,7,8,9,10]}")
    @test JSON.json(gt) == JSON3.write(gt)
    @test JSON.json(pplot) == JSON3.write(pplot)    
    @test JSON.json(layout) == JSON3.write(layout)
    # `json` is the name that PlotlyBase exports
    @test json(pplot) == JSON.json(pplot)
end
