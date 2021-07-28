# key template data structure
@with_kw struct Template
    data::Dict{Symbol,Vector{_ATTR}} = Dict()
    layout::PlotlyAttribute = attr()
end

==(t1::Template, t2::Template)=  t1.data == t2.data && t1.layout == t2.layout

# to allow Template(data = attr(...))
function Base.convert(T::Type{Dict{Symbol,Vector{_ATTR}}}, x::PlotlyAttribute)
    out = T()
    for (k, v) in pairs(x)
        if !(v isa Vector)
            @error "Could not convert to Template.data. Expected argument at $k to be Vector. Found $v"
        end
        want = _ATTR[]
        for item in v
            push!(want, item)
        end
        out[k] = want
    end
    out
end


function Template(data, layout::Layout)
    Template(data, attr(;layout.fields...))
end
_isempty(::Template) = false

Base.deepcopy(t::Template) = Template(deepcopy(t.data), deepcopy(t.layout))

Base.merge(t1::Template, _t2::Template) = merge!(deepcopy(t1), _t2)

function Base.merge!(out::Template, t2::Template)
    for k in keys(t2.data)
        t1_traces = Cycler(get(out.data, k, [attr()]))
        t2_traces = Cycler(t2.data[k])
        n_out = max(length(t1_traces), length(t2_traces))
        out.data[k]= [merge(t1_traces[ix], t2_traces[ix]) for ix in 1:n_out]
    end

    # now update layout
    merge!(out.layout, t2.layout)
    return out
end

# loading templates from disk
_template_dir() = template_dir = joinpath(artifact"plotly-base-artifacts", "templates")
_available_templates() = [replace(x, ".json" => "") for x in readdir(_template_dir())]
function _load_template(name::String)
    # first try to look it up
    name = Symbol(replace(name, ".json" => ""))
    if name in keys(templates) && !ismissing(templates.templates[name])
        return templates.templates[name]
    end

    # otherwise try to load
    template_dir = _template_dir()
    to_load = joinpath(template_dir, string(name, ".json"))

    # check if this template exists
    exists = isfile(to_load)
    if !exists
        @error "Unknown template $(name). Known values are $(_available_templates())"
    end

    # if it does, load and process it
    raw = _symbol_dict(open(JSON.parse, to_load))
    layout = attr(;_symbol_dict(get(raw, :layout, Dict()))...)
    data = Dict{Symbol,Vector{_ATTR}}()

    # data will be object of arrays. Each array has trace attributes
    for (trace_type, trace_val_array) in get(raw, :data, Dict())
        want = _ATTR[]
        for trace_data in trace_val_array
            push!(want, attr(;_symbol_dict(trace_data)...))
        end
        data[Symbol(trace_type)] = want
    end
    out = Template(data, layout)
    templates[name] = out
    return out
end

# Singleton object for handling templates
mutable struct _TemplatesConfig
    default::String
    templates::Dict{Symbol,_Maybe{Template}}
end

# custom set property to allow setting default with validation
Base.setproperty!(tc::_TemplatesConfig, k::Symbol, x) = setproperty!(tc, Val{k}(), x)
function Base.setproperty!(tc::_TemplatesConfig, ::Val{k}, x) where k
    if hasfield(_TemplatesConfig, k)
        return setfield!(tc, k, x)
    end
    return setindex!(tc, x, k)
end
function Base.setproperty!(tc::_TemplatesConfig, ::Val{:default}, x::String)
    # TODO: validation here
    setfield!(tc, :default, x)
end


# custom getproperty to add available
Base.getproperty(tc::_TemplatesConfig, k::Symbol) = getproperty(tc, Val{k}())
function Base.getproperty(tc::_TemplatesConfig, ::Val{k}) where k
    if hasfield(_TemplatesConfig, k)
        return getfield(tc, k)
    end
    return getindex(tc, k)
end
Base.getproperty(tc::_TemplatesConfig, ::Val{:available}) = collect(keys(tc.templates))
Base.propertynames(tc::_TemplatesConfig) = Symbol[fieldnames(_TemplatesConfig)...,  :available]

# setindex! and getindex, and keys work through the `.templates` dict
function Base.setindex!(tc::_TemplatesConfig, val::Template, k::Union{Symbol,String})
    setindex!(tc.templates, val, Symbol(k))
end
function Base.getindex(tc::_TemplatesConfig, k::Symbol)
    if haskey(tc.templates, k) && !ismissing(tc.templates[k])
        return tc.templates[k]
    end
    return _load_template(String(k))
end
function Base.getindex(tc::_TemplatesConfig, k::String)
    parts = strip.(split(k, "+"))
    reduce(merge, getindex.(Ref(tc), Symbol.(parts)))
end

Base.keys(tc::_TemplatesConfig) = keys(tc.templates)

function Base.show(io::IO, ::MIME"text/plain", tc::_TemplatesConfig)
    msg = """
    Templates configuration
    -----------------------
    Default template: $(tc.default)
    Available templates: $(tc.available)
    """
    println(io, msg)
end

const templates = _TemplatesConfig("plotly", Dict(Symbol(k) => missing for k in _available_templates()))
