function GenericTrace(x::AbstractArray, y::AbstractArray;
                      kind="scatter", kwargs...)
    GenericTrace(kind; x=x, y=y, kwargs...)
end

"""
$(SIGNATURES)
Build a plot of with one trace of type `kind`and set `x` to x and `y` to y. All
keyword arguments are passed directly as keyword arguments to the constructed
trace.

**NOTE**: If `y` is a matrix, one trace is constructed for each column of `y`

**NOTE**: If `x` and `y` are both matrices, they must have the same number of
columns (say `N`). Then `N` traces are constructed, where the `i`th column of
`x` is paired with the `i`th column of `y`.
"""
function Plot(
        x::AbstractVector{T}, y::AbstractVector, l::Layout=Layout();
        kind="scatter",
        config::PlotConfig=PlotConfig(),
        kwargs...
    ) where T <: _Scalar
    Plot(GenericTrace(x, y; kind=kind, kwargs...), l, config=config)
end

function Plot(
        x::AbstractVector{T}, y::AbstractMatrix, l::Layout=Layout();
        config::PlotConfig=PlotConfig(),
        kwargs...
    ) where T <: _Scalar
    traces = GenericTrace[
        GenericTrace(x, getindex(y, :, i); kwargs...)
        for i in 1:size(y, 2)
    ]
    Plot(traces, l, config=config)
end

function Plot(
        x::AbstractVector{T}, y::AbstractMatrix, l::Layout=Layout();
        config::PlotConfig=PlotConfig(),
        kwargs...
    ) where T <: AbstractVector
    size(x, 1) == size(y, 2) || error("x and y must have same number of cols")

    traces = GenericTrace[
        GenericTrace(x[i], getindex(y, :, i); kwargs...)
        for i in 1:size(y, 2)
    ]
    Plot(traces, l; config=config)
end

function Plot(
        x::AbstractMatrix, y::AbstractMatrix, l::Layout=Layout();
        config::PlotConfig=PlotConfig(),
        kwargs...
    )
    if size(x, 2) == 1
        # use method above
        Plot(getindex(x, :, 1), y, l; config=config, kwargs...)
    end

    size(x, 2) == size(y, 2) || error("x and y must have same number of cols")

    traces = GenericTrace[
        GenericTrace(getindex(x, :, i), getindex(y, :, i); kwargs...)
        for i in 1:size(y, 2)
    ]
    Plot(traces, l; config=config)
end

# AbstractArray{T,N}
"""
$(SIGNATURES)
Build a scatter plot and set  `y` to y. All keyword arguments are passed directly
as keyword arguments to the constructed scatter.
"""
function Plot(y::AbstractArray{T}, l::Layout=Layout(); kwargs...) where T <: _Scalar
    # call methods above to get many traces if y is >1d
    Plot(1:size(y, 1), y, l; kwargs...)
end

"""
$(SIGNATURES)
Construct a plot of `f` from `x0` to `x1`, using the layout `l`. All
keyword arguments are applied to the constructed trace.
"""
function Plot(
        f::Function, x0::Number, x1::Number, l::Layout=Layout();
        config::PlotConfig=PlotConfig(),
        kwargs...
    )
    x = range(x0, stop=x1, length=50)
    y = [f(_) for _ in x]
    Plot(GenericTrace(x, y; name=Symbol(f), kwargs...), l, config=config)
end

"""
$(SIGNATURES)
For each function in `f` in `fs`, construct a scatter trace that plots `f` from
`x0` to `x1`, using the layout `l`. All keyword arguments are applied to all
constructed traces.
"""
function Plot(
        fs::AbstractVector{Function}, x0::Number, x1::Number, l::Layout=Layout();
        config::PlotConfig=PlotConfig(),
        kwargs...
    )
    x = range(x0, stop=x1, length=50)
    traces = GenericTrace[
        GenericTrace(x, map(f, x); name=Symbol(f), kwargs...)
        for f in fs
    ]
    Plot(traces, l; config=config)
end

_make_attrable(x::Union{Number,Symbol,String,Missing,Nothing}) = x
_make_attrable(x::AbstractArray) = _make_attrable.(x)
function _make_attrable(x::Union{NamedTuple,_LikeAssociative})
    out = attr()
    for (k, v) in pairs(x)
        out[k] = _make_attrable(v)
    end
    out
end


function attr(nt::NamedTuple)
    out = attr()
    for (k, v) in pairs(nt)
        out[k] = _make_attrable(v)
    end
    out
end

# for reading from a namedtuple that Dash.jl
# generates when using `dcc_graph` as state
function Plot(fig::NamedTuple{(:layout, :frames, :data)})
    traces = GenericTrace[]
    for tr in fig.data
        kind = hasproperty(tr, :kind) ? tr.kind : "scatter"
        push!(traces, GenericTrace(kind; attr(tr)...))
    end
    layout_attr = attr(fig.layout)
    if hasproperty(layout_attr, :template)
        t_layout = Layout()
        if hasproperty(layout_attr.template, :layout)
            t_layout = Layout(;attr(fig.layout.template.layout)...)
        end
        pop!(t_layout, :template)  # remove nested template

        # now translate traces into _ATTR[]
        t_data = Dict{Symbol,Vector{_ATTR}}()
        if hasproperty(layout_attr, :data)
            for (k, v) in pairs(fig.layout.template.data)
                attrs = _ATTR[]
                for trace_spec in v
                    push!(attrs, attr(trace_spec))
                end
                t_data[Symbol(k)] = attrs
            end
        end
        layout_attr.fields[:template] = Template(t_data, t_layout)
    end
    layout = Layout(layout_attr.fields)
    frames = PlotlyFrame[]
    for f in fig.frames
        push!(frames, frame(;f...))
    end
    Plot(traces, layout, frames)
end


Plot(fig::NamedTuple{(:layout, :data)}) = Plot((layout = fig.layout, frames = [], data = fig.data))
Plot(fig::NamedTuple{(:data, :layout)}) = Plot((layout = fig.layout, frames = [], data = fig.data))
for order in [(:data, :layout, :frames), (:data, :frames, :layout), (:frames, :data, :layout), (:frames, :layout, :data), (:layout, :data, :frames)]
    @eval Plot(fig::NamedTuple{$(order)}) = Plot((layout = fig.layout, frames = fig.frames, data = fig.data))
end


"""
$(SIGNATURES)
Creates a "stem" or "lollipop" trace. It is implemented using plotly.js's
`scatter` type, using the error bars to draw the stem.

## Keyword Arguments:
* All properties accepted by `scatter` except `error_y`, which is used to draw
    the stems
* stem_color - sets the color of the stems
* stem_thickness - sets the thickness of the stems
"""
function stem(;y=nothing, stem_color="grey", stem_thickness=1, kwargs...)
    line_up = -min.(y, 0)
    line_down = max.(y, 0)
    trace = scatter(; y=y, text=y, marker_size=10, mode="markers", hoverinfo="text", kwargs...)
    trace.fields[:error_y] = Dict(
        :type => "data",
        :symmetric => false,
        :array => line_up,
        :arrayminus => line_down,
        :visible => true,
        :color => stem_color,
        :width => 0,
        :thickness => stem_thickness)
    trace
end
