module PlotlyBase

using Base.Iterators
using JSON
using DocStringExtensions
using UUIDs
using Dates
using Logging
using ColorSchemes
using Parameters

if !isdefined(Base, :get_extension)
    using Requires
end

import Base: ==

using Statistics: mean
using DelimitedFiles: readdlm

# import LaTeXStrings and export the handy macros
using LaTeXStrings
export @L_str
using Pkg.Artifacts

# export some names from JSON
export json

_symbol_dict(x) = x
_symbol_dict(d::AbstractDict) =
    Dict{Symbol,Any}([(Symbol(k), _symbol_dict(v)) for (k, v) in d])

const _Maybe{T} = Union{Missing,T}

abstract type AbstractPlotlyAttribute end

mutable struct PlotlyAttribute{T <: AbstractDict{Symbol,Any}} <: AbstractPlotlyAttribute
    fields::T
end

const _ATTR = PlotlyAttribute{Dict{Symbol,Any}}

struct Cycler
    vals::Vector
end

Base.isempty(c::Cycler) = isempty(c.vals)
Base.length(c::Cycler) = length(c.vals)
Cycler(t::Tuple) = Cycler(collect(t))
Cycler(x::Union{String,Number,Date,Symbol}) = Cycler([x])

function Base.getindex(c::Cycler, ix::Integer)
    n = length(c.vals)
    @inbounds v = c.vals[mod1(ix, n)]
    v
end

function Base.getindex(c::Cycler, ixs::AbstractVector{<:Integer})
    [c[i] for i in ixs]
end

Base.iterate(c::Cycler, s::Int=1) = c[s], s + 1
Base.IteratorSize(::Cycler) = Base.IsInfinite()

# include these here because they are used below
include("plot_config.jl")
include("subplot_utils.jl")
include("traces_layouts.jl")

const PLOTSCHEMA = attr();

function get_plotschema()
    if _isempty(PLOTSCHEMA)
        out = JSON.parsefile(joinpath(artifact"plotly-base-artifacts", "plot-schema.json"))
        PLOTSCHEMA.fields = _symbol_dict(out)
    end
    return PLOTSCHEMA
end

# core plot object
mutable struct Plot{TT<:AbstractVector{<:AbstractTrace},TL<:AbstractLayout,TF<:AbstractVector{<:PlotlyFrame}}
    data::TT
    layout::TL
    frames::TF
    divid::UUID
    config::PlotConfig
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
include("templates.jl")
include("colors.jl")

# Set some defaults for constructing `Plot`s
function Plot(;config::PlotConfig=PlotConfig())
    Plot(GenericTrace{Dict{Symbol,Any}}[], Layout(), PlotlyFrame[], uuid4(), config)
end

function Plot(data::AbstractVector{<:AbstractTrace}, layout=Layout(), frames::AbstractVector{<:PlotlyFrame}=PlotlyFrame[];
              config::PlotConfig=PlotConfig())
    Plot(data, layout, frames, uuid4(), config)
end

function Plot(data::AbstractTrace, layout=Layout(), frames::AbstractVector{<:PlotlyFrame}=PlotlyFrame[];
              config::PlotConfig=PlotConfig())
    Plot([data], layout, frames; config=config)
end

# empty plot
function Plot(layout::Layout, frames::AbstractVector{<:PlotlyFrame}=PlotlyFrame[];
    config::PlotConfig=PlotConfig())
    Plot(GenericTrace[], layout, frames; config=config)
end


# NOTE: we export trace constructing types from inside api.jl
# NOTE: we export names of shapes from traces_layouts.jl
export

    # core types
    Plot, GenericTrace, PlotlyFrame, Layout, Shape, AbstractTrace, AbstractLayout,
    PlotConfig, Spec, Subplots, Inset,

    # plotly.js api methods
    restyle!, relayout!, update!, addtraces!, deletetraces!, movetraces!,
    redraw!, extendtraces!, prependtraces!, purge!, to_image, download_image,
    react!,

    # non-!-versions (forks, then applies, then returns fork)
    restyle, relayout, update, addtraces, deletetraces, movetraces, redraw,
    extendtraces, prependtraces, react,

    # helper methods
    fork, vline, hline, attr, frame, add_trace!,

    # templates
    templates, Template,

    # new trace types
    stem,

    # convenience stuff
    add_recession_bands!, Cycler,

    # other
    savejson, colors

@static if !isdefined(Base, :get_extension)
function __init__()
    @require IJulia="7073ff75-c697-5162-941a-fcdaad2a7d2a" include("../ext/IJuliaExt.jl")
    @require DataFrames="a93c6f00-e57d-5684-b7b6-d8193f3e46c0" include("../ext/DataFramesExt.jl")
    @require Distributions="31c24e10-a181-5473-b8eb-7969acd0382f" include("../ext/DistributionsExt.jl")
    @require Colors="5ae59095-9a9b-59fe-a467-6f913c188581" include("../ext/ColorsExt.jl")
    @require JSON3="0f8b85d8-7281-11e9-16c2-39a750bddbf1" include("../ext/JSON3Ext.jl")
end
end # @static

end # module
