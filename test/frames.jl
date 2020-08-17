@testset "test frame constructors" begin
    f = M.frame(;name="test")
    @test isa(f, M.PlotlyFrame)
    f = M.PlotlyFrame{Dict{Symbol,Any}}(Dict{Symbol,Any}(:name=>"test"))
    @test isa(f, M.PlotlyFrame)
    @test_logs (:warn, "Frame should have a :name field for expected behavior") frame()
    @test_logs (:warn, "Frame should have a :name field for expected behavior") PlotlyFrame{Dict{Symbol,Any}}(Dict{Symbol,Any}())
end
@testset "_UNDERSCORE_ATTRS" begin
    f = M.frame(;name="test")
    # test setindex!
    f[:paper_bgcolor] = "grey"
    @test haskey(f.fields, :paper_bgcolor)
    @test f.fields[:paper_bgcolor] == "grey"

    # test getindex
    @test f[:paper_bgcolor] == "grey"
    @test f["paper_bgcolor"] == "grey"

    # now do it again with the string form of setindex!
    f = M.Layout()

    # test setindex!
    f["paper_bgcolor"] = "grey"
    @test haskey(f.fields, :paper_bgcolor)
    @test f.fields[:paper_bgcolor] == "grey"

    # test getindex
    @test f[:paper_bgcolor] == "grey"
    @test f["paper_bgcolor"] == "grey"
end

@testset "test setting nested attr" begin
    f = M.frame(;name="test")
    times20 = attr(name="Times", size=20)
    f[:xaxis_titlefont] = times20
    @test isa(f[:xaxis], Dict)
    @test f[:xaxis][:titlefont][:name] == "Times"
    @test f[:xaxis][:titlefont][:size] == 20
end

@testset "test setindex!, getindex methods" begin
    f = M.frame(;name="test", x=1:5, y=1:5, visible=false)

    f[:visible] = true
    @test length(f.fields) == 4
    @test haskey(f.fields, :visible)
    @test f.fields[:visible] == true

    # now try with string. Make sure it updates inplace
    f["visible"] = false
    @test length(f.fields) == 4
    @test haskey(f.fields, :visible)
    @test f.fields[:visible] == false

    # -------- #
    # 2 levels #
    # -------- #
    f[:line, :color] = "red"
    @test length(f.fields) == 5
    @test haskey(f.fields, :line)
    @test isa(f.fields[:line], Dict)
    @test f.fields[:line][:color] == "red"
    @test f["line.color"] == "red"

    # now try string version
    f["line", "color"] = "blue"
    @test length(f.fields) == 5
    @test haskey(f.fields, :line)
    @test isa(f.fields[:line], Dict)
    @test f.fields[:line][:color] == "blue"
    @test f["line_color"] == "blue"

    # now try convenience string dot notation
    f["line.color"] = "green"
    @test length(f.fields) == 5
    @test haskey(f.fields, :line)
    @test isa(f.fields[:line], Dict)
    @test f.fields[:line][:color] == "green"
    @test f[:line_color] == "green"

    # now try symbol with underscore
    f[:(line_color)] = "orange"
    @test length(f.fields) == 5
    @test haskey(f.fields, :line)
    @test isa(f.fields[:line], Dict)
    @test f.fields[:line][:color] == "orange"
    @test f["line.color"] == "orange"

    # now try string with underscore
    f["line_color"] = "magenta"
    @test length(f.fields) == 5
    @test haskey(f.fields, :line)
    @test isa(f.fields[:line], Dict)
    @test f.fields[:line][:color] == "magenta"
    @test f["line.color"] == "magenta"

    # -------- #
    # 3 levels #
    # -------- #
    f[:marker, :line, :color] = "red"
    @test length(f.fields) == 6
    @test haskey(f.fields, :marker)
    @test isa(f.fields[:marker], Dict)
    @test haskey(f.fields[:marker], :line)
    @test isa(f.fields[:marker][:line], Dict)
    @test haskey(f.fields[:marker][:line], :color)
    @test f.fields[:marker][:line][:color] == "red"
    @test f["marker.line.color"] == "red"

    # now try string version
    f["marker", "line", "color"] = "blue"
    @test length(f.fields) == 6
    @test haskey(f.fields, :marker)
    @test isa(f.fields[:marker], Dict)
    @test haskey(f.fields[:marker], :line)
    @test isa(f.fields[:marker][:line], Dict)
    @test haskey(f.fields[:marker][:line], :color)
    @test f.fields[:marker][:line][:color] == "blue"
    @test f["marker.line.color"] == "blue"

    # now try convenience string dot notation
    f["marker.line.color"] = "green"
    @test length(f.fields) == 6
    @test haskey(f.fields, :marker)
    @test isa(f.fields[:marker], Dict)
    @test haskey(f.fields[:marker], :line)
    @test isa(f.fields[:marker][:line], Dict)
    @test haskey(f.fields[:marker][:line], :color)
    @test f.fields[:marker][:line][:color] == "green"
    @test f["marker.line.color"] == "green"

    # now string with underscore notation
    f["marker_line_color"] = "orange"
    @test length(f.fields) == 6
    @test haskey(f.fields, :marker)
    @test isa(f.fields[:marker], Dict)
    @test haskey(f.fields[:marker], :line)
    @test isa(f.fields[:marker][:line], Dict)
    @test haskey(f.fields[:marker][:line], :color)
    @test f.fields[:marker][:line][:color] == "orange"
    @test f["marker.line.color"] == "orange"

    # now symbol with underscore notation
    f[:(marker_line_color)] = "magenta"
    @test length(f.fields) == 6
    @test haskey(f.fields, :marker)
    @test isa(f.fields[:marker], Dict)
    @test haskey(f.fields[:marker], :line)
    @test isa(f.fields[:marker][:line], Dict)
    @test haskey(f.fields[:marker][:line], :color)
    @test f.fields[:marker][:line][:color] == "magenta"
    @test f["marker.line.color"] == "magenta"

    # -------- #
    # 4 levels #
    # -------- #
    f[:marker, :colorbar, :tickfont, :family] = "Hasklig-ExtraLight"
    @test length(f.fields) == 6  # notice we didn't add another top level key
    @test haskey(f.fields, :marker)
    @test isa(f.fields[:marker], Dict)
    @test length(f.fields[:marker]) == 2  # but we did add a key at this level
    @test haskey(f.fields[:marker], :colorbar)
    @test isa(f.fields[:marker][:colorbar], Dict)
    @test haskey(f.fields[:marker][:colorbar], :tickfont)
    @test isa(f.fields[:marker][:colorbar][:tickfont], Dict)
    @test haskey(f.fields[:marker][:colorbar][:tickfont], :family)
    @test f.fields[:marker][:colorbar][:tickfont][:family] == "Hasklig-ExtraLight"
    @test f["marker.colorbar.tickfont.family"] == "Hasklig-ExtraLight"

    # now try string version
    f["marker", "colorbar", "tickfont", "family"] = "Hasklig-Light"
    @test length(f.fields) == 6
    @test haskey(f.fields, :marker)
    @test isa(f.fields[:marker], Dict)
    @test length(f.fields[:marker]) == 2
    @test haskey(f.fields[:marker], :colorbar)
    @test isa(f.fields[:marker][:colorbar], Dict)
    @test haskey(f.fields[:marker][:colorbar], :tickfont)
    @test isa(f.fields[:marker][:colorbar][:tickfont], Dict)
    @test haskey(f.fields[:marker][:colorbar][:tickfont], :family)
    @test f.fields[:marker][:colorbar][:tickfont][:family] == "Hasklig-Light"
    @test f["marker.colorbar.tickfont.family"] == "Hasklig-Light"

    # now try convenience string dot notation
    f["marker.colorbar.tickfont.family"] = "Hasklig-Medium"
    @test length(f.fields) == 6  # notice we didn't add another top level key
    @test haskey(f.fields, :marker)
    @test isa(f.fields[:marker], Dict)
    @test length(f.fields[:marker]) == 2  # but we did add a key at this level
    @test haskey(f.fields[:marker], :colorbar)
    @test isa(f.fields[:marker][:colorbar], Dict)
    @test haskey(f.fields[:marker][:colorbar], :tickfont)
    @test isa(f.fields[:marker][:colorbar][:tickfont], Dict)
    @test haskey(f.fields[:marker][:colorbar][:tickfont], :family)
    @test f.fields[:marker][:colorbar][:tickfont][:family] == "Hasklig-Medium"
    @test f["marker.colorbar.tickfont.family"] == "Hasklig-Medium"

    # now string with underscore notation
    f["marker_colorbar_tickfont_family"] = "Webdings"
    @test length(f.fields) == 6  # notice we didn't add another top level key
    @test haskey(f.fields, :marker)
    @test isa(f.fields[:marker], Dict)
    @test length(f.fields[:marker]) == 2  # but we did add a key at this level
    @test haskey(f.fields[:marker], :colorbar)
    @test isa(f.fields[:marker][:colorbar], Dict)
    @test haskey(f.fields[:marker][:colorbar], :tickfont)
    @test isa(f.fields[:marker][:colorbar][:tickfont], Dict)
    @test haskey(f.fields[:marker][:colorbar][:tickfont], :family)
    @test f.fields[:marker][:colorbar][:tickfont][:family] == "Webdings"
    @test f["marker.colorbar.tickfont.family"] == "Webdings"

    # now symbol with underscore notation
    f[:marker_colorbar_tickfont_family] = "Webdings42"
    @test length(f.fields) == 6  # notice we didn't add another top level key
    @test haskey(f.fields, :marker)
    @test isa(f.fields[:marker], Dict)
    @test length(f.fields[:marker]) == 2  # but we did add a key at this level
    @test haskey(f.fields[:marker], :colorbar)
    @test isa(f.fields[:marker][:colorbar], Dict)
    @test haskey(f.fields[:marker][:colorbar], :tickfont)
    @test isa(f.fields[:marker][:colorbar][:tickfont], Dict)
    @test haskey(f.fields[:marker][:colorbar][:tickfont], :family)
    @test f.fields[:marker][:colorbar][:tickfont][:family] == "Webdings42"
    @test f["marker.colorbar.tickfont.family"] == "Webdings42"

    # error on 5 levels
    @test_throws MethodError f["marker.colorbar.tickfont.family.foo"] = :bar
end


@testset "create plot with frames" begin
    # https://plotly.com/python/animations/
    p = Plot(
        [scatter(x=0:1, y=0:1)],
        Layout(xaxis=attr(range=(0,5), autorange=false), yaxis=attr(range=(0,5), autorange=false), title="start title", updatemenus=[attr(type="buttons", buttons=[attr(label="Play", method="animate", args=[nothing])])]),
        [
            frame(name=:f1, data=[scatter(x=1:2, y=1:2)]),
            frame(name=:f2, data=[scatter(x=1:4, y=1:4)]),
            frame(name=:f3, data=[scatter(x=3:4, y=3:4)], layout=Layout(title_text="End Title")),
        ]
    )
    @test p isa Plot
end
