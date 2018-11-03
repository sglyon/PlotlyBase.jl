module PlotlyBase

using Base.Iterators
using JSON
using DocStringExtensions
using Requires
using UUIDs
using Dates
using Logging

import Base: ==

using Statistics: mean
using DelimitedFiles: readdlm

# import LaTeXStrings and export the handy macros
using LaTeXStrings
export @L_mstr, @L_str

# export some names from JSON
export json

_symbol_dict(x) = x
_symbol_dict(d::AbstractDict) =
    Dict{Symbol,Any}([(Symbol(k), _symbol_dict(v)) for (k, v) in d])

# include these here because they are used below
include("traces_layouts.jl")
include("styles.jl")

# core plot object
mutable struct Plot{TT<:AbstractTrace}
    data::Vector{TT}
    layout::AbstractLayout
    divid::UUID
    style::Style
end

# Default `convert` fallback constructor
Plot(p::Plot) = p

# include the rest of the core parts of the package
include("util.jl")
include("json.jl")
include("subplots.jl")
include("api.jl")
include("convenience_api.jl")
include("recession_bands.jl")
include("output.jl")

# Set some defaults for constructing `Plot`s
function Plot(;style::Style=CURRENT_STYLE[])
    Plot(GenericTrace{Dict{Symbol,Any}}[], Layout(), uuid4(), style)
end

function Plot(data::AbstractVector{T}, layout=Layout();
              style::Style=CURRENT_STYLE[]) where T<:AbstractTrace
    Plot(data, layout, uuid4(), style)
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
    react!,

    # non-!-versions (forks, then applies, then returns fork)
    restyle, relayout, update, addtraces, deletetraces, movetraces, redraw,
    extendtraces, prependtraces, react,

    # helper methods
    plot, fork, vline, hline, attr,

    # new trace types
    stem,

    # convenience stuff
    add_recession_bands!,

    # styles
    use_style!, style, Style, Cycler, STYLES,

    # other
    savejson, savefig, html_body

function __init__()
    env_style = Symbol(get(ENV, "PLOTLYJS_STYLE", ""))
    if env_style in STYLES
        global DEFAULT_STYLE
        DEFAULT_STYLE[] = Style(env_style)
    end
    @require IJulia="7073ff75-c697-5162-941a-fcdaad2a7d2a" begin
        function IJulia.display_dict(p::Plot)
            Dict(
                "application/vnd.plotly.v1+json" => JSON.lower(p),
                "text/plain" => sprint(show, "text/plain", p)
            )
        end
    end
    @require DataFrames="a93c6f00-e57d-5684-b7b6-d8193f3e46c0" include("dataframes_api.jl")
    @require Distributions="31c24e10-a181-5473-b8eb-7969acd0382f" include("distributions.jl")
    @require Colors="5ae59095-9a9b-59fe-a467-6f913c188581" JSON.lower(a::Colors.Colorant) = string("#", Colors.hex(a))
end


end # module
