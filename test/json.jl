
gt = PlotlyBase.GenericTrace("scatter"; x=1:10, y=(1:10).^2)

using PlotlyBase.JSON

@testset "Convert to json" begin
    @test JSON.json(gt) == "{\"type\":\"scatter\",\"x\":[1,2,3,4,5,6,7,8,9,10],\"y\":[1,4,9,16,25,36,49,64,81,100]}"
end
