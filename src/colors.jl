@with_kw  struct _color_types
    sequential::Dict{Symbol,ColorScheme} = filter(kv -> occursin("sequential", kv[2].notes), pairs(colorschemes))
    diverging::Dict{Symbol,ColorScheme} = filter(kv -> occursin("diver", kv[2].notes), pairs(colorschemes))
    cyclical::Dict{Symbol,ColorScheme} = filter(kv -> occursin("cycl", kv[2].notes), pairs(colorschemes))
    discrete::Dict{Symbol,ColorScheme} = filter(kv -> occursin("quali", kv[2].notes), pairs(colorschemes))
    all::Dict{Symbol,ColorScheme} = colorschemes
end

Base.getindex(ct::_color_types, k::Symbol) = ct.all[k]
Base.getproperty(ct::_color_types, k::Symbol) = hasfield(_color_types, k) ?  getfield(ct, :all) : ct[k]
Base.propertynames(ct::_color_types) = vcat(collect(fieldnames(typeof(ct))), collect(keys(ct.all)))

const colors = _color_types()
