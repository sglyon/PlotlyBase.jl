using Colors
using PlotlyBase.JSON
@testset "Colors" begin
    @test JSON.parse(json(Layout(colortest = RGBA(1, 0.8, 0.6, 0.2))))["colortest"] == "#FFCC9933"
    @test JSON.parse(json(Template(data = attr(scatter = [attr(marker_color = colorant"blue")]))))["data"]["scatter"][1]["marker"]["color"] == "#0000FF"
end