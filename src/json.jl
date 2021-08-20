# -------------------------------- #
# Custom JSON output for our types #
# -------------------------------- #
_json_lower(x) = JSON.lower(x)
_json_lower(x::Union{Bool,String,Number,Nothing,Missing}) = x
_json_lower(x::Union{Tuple,AbstractArray}) = _json_lower.(x)
_json_lower(d::Dict) = Dict{Any,Any}(k => _json_lower(v) for (k, v) in pairs(d))
_json_lower(a::HasFields) = Dict{Any,Any}(k => _json_lower(v) for (k, v) in pairs(a.fields))
_json_lower(c::Cycler) = c.vals
function _json_lower(c::ColorScheme)::Vector{Tuple{Float64,String}}
    N = length(c.colors)
    map(ic -> ((ic[1] - 1) / (N - 1), _json_lower(ic[2])), enumerate(c.colors))
end

_maybe_set_attr!(hf::HasFields, k::Symbol, v::Any) =
    get(hf, k, nothing) == nothing && setindex!(hf, v, k)

# special case for associative to get nested application
function _maybe_set_attr!(hf::HasFields, k1::Symbol, v::AbstractDict)
    for (k2, v2) in v
        _maybe_set_attr!(hf, Symbol(k1, "_", k2), v2)
    end
end

function _maybe_set_attr!(p::Plot, k1::Symbol, v::AbstractDict)
    for (k2, v2) in v
        _maybe_set_attr!(p, Symbol(k1, "_", k2), v2)
    end
end

function _maybe_set_attr!(p::Plot, k::Symbol, v)
    foreach(t -> _maybe_set_attr!(t, k, v), p.data)
end

function _maybe_set_attr!(p::Plot, k::Symbol, v::Cycler)
    ix = 0
    for t in p.data
        if t[k] == Dict()  # was empty
            t[k] = v[ix += 1]
        end
    end
end

function JSON.lower(p::Plot)
    out = Dict(
        :data => _json_lower(p.data),
        :layout => _json_lower(p.layout),
        :frames => _json_lower(p.frames),
        :config => _json_lower(p.config)
    )

    if templates.default !== "none" && _isempty(get(out[:layout], :template, Dict()))
        out[:layout][:template] = _json_lower(templates[templates.default])
    end
    out
end

# Let string interpolation stringify to JSON format
Base.print(io::IO, a::Union{Shape,GenericTrace,PlotlyAttribute,Layout,Plot}) = print(io, JSON.json(a))
Base.print(io::IO, a::Vector{T}) where {T <: GenericTrace} = print(io, JSON.json(a))

GenericTrace(d::AbstractDict{Symbol}) = GenericTrace(pop!(d, :type, "scatter"), d)
GenericTrace(d::AbstractDict{T}) where {T <: AbstractString} = GenericTrace(_symbol_dict(d))
Layout(d::AbstractDict{T}) where {T <: AbstractString} = Layout(_symbol_dict(d))

function JSON.parse(::Type{Plot}, str::AbstractString)
    d = JSON.parse(str)
    data = GenericTrace[GenericTrace(tr) for tr in d["data"]]
    layout = Layout(d["layout"])
    Plot(data, layout)
end

JSON.parsefile(::Type{Plot}, fn) =
    open(fn, "r") do f; JSON.parse(Plot, String(read(f))) end
