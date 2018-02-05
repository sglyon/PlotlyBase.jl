__precompile__()

module PlotlyBase

using Base.Iterators
using JSON
using DocStringExtensions
using Requires

import Base: ==

# import LaTeXStrings and export the handy macros
using LaTeXStrings
export @L_mstr, @L_str

# export some names from JSON
export json

_symbol_dict(x) = x
_symbol_dict(d::Associative) =
    Dict{Symbol,Any}([(Symbol(k), _symbol_dict(v)) for (k, v) in d])

# include these here because they are used below
include("traces_layouts.jl")
include("styles.jl")

# core plot object
mutable struct Plot{TT<:AbstractTrace}
    data::Vector{TT}
    layout::AbstractLayout
    divid::Base.Random.UUID
    style::Style
end

function Base.show(io::IO, ::MIME"text/plain", p::Plot)
    println(io, """
    data: $(json(map(_describe, p.data), 2))
    layout: "$(_describe(p.layout))"
    """)
end

Base.show(io::IO, p::Plot) = show(io, MIME("text/plain"), p)

function savefig(p::Plot, fn::AbstractString)
    ext = split(fn, ".")[end]
    if ext == "json"
        open(f -> print(f, json(p)), fn, "w")
        return p
    else
        msg = "PlotlyBase can only save figures as JSON. For all other"
        msg *= " file types, please use PlotlyJS.jl"
        throw(ArgumentError(msg))
    end
end

# include the rest of the core parts of the package
include("util.jl")
include("json.jl")
include("subplots.jl")
include("api.jl")
include("convenience_api.jl")
@require DataFrames include("dataframes_api.jl")
include("recession_bands.jl")

# Set some defaults for constructing `Plot`s
function Plot(;style::Style=CURRENT_STYLE[])
    Plot(GenericTrace{Dict{Symbol,Any}}[], Layout(), Base.Random.uuid4(), style)
end

function Plot{T<:AbstractTrace}(data::AbstractVector{T}, layout=Layout();
                                style::Style=CURRENT_STYLE[])
    Plot(data, layout, Base.Random.uuid4(), style)
end

function Plot(data::AbstractTrace, layout=Layout();
              style::Style=CURRENT_STYLE[])
    Plot([data], layout; style=style)
end


# NOTE: we export trace constructing types from inside api.jl
# NOTE: we export names of shapes from traces_layouts.jl
export

    # core types
    Plot, GenericTrace, Layout, Shape, AbstractTrace, AbstractLayout,

    # plotly.js api methods
    restyle!, relayout!, update!, addtraces!, deletetraces!, movetraces!,
    redraw!, extendtraces!, prependtraces!, purge!, to_image, download_image,

    # non-!-versions (forks, then applies, then returns fork)
    restyle, relayout, update, addtraces, deletetraces, movetraces, redraw,
    extendtraces, prependtraces,

    # helper methods
    plot, fork, vline, hline, attr,

    # new trace types
    stem,

    # convenience stuff
    add_recession_bands!,

    # frontend methods
    init_notebook,

    # styles
    use_style!, style, Style, Cycler,

    # other
    savefig

@init begin
    env_style = Symbol(get(ENV, "PLOTLYJS_STYLE", ""))
    if env_style in STYLES
        global DEFAULT_STYLE
        DEFAULT_STYLE[] = Style(env_style)
    end
end

# jupyterlab integration
@require IJulia begin
    function IJulia.display_dict(p::Plot)
        Dict(
            "application/vnd.plotly.v1+json" => JSON.lower(p),
            "text/plain" => sprint(show, "text/plain", p)
        )
    end
end


end # module
