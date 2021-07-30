# const StructTypes = JSON3.StructTypes

# StructTypes.StructType(::Type{T}) where T <: HasFields = StructTypes.DictType()
# StructTypes.construct(::Type{T}, x::AbstractDict; kw...) where T <: HasFields = T(_symbol_dict(x); kw...)
# StructTypes.StructType(::Type{T}) where T <: Union{Template} = StructTypes.Struct()
# StructTypes.StructType(::Type{T}) where T <: Union{Plot,PlotConfig} = StructTypes.Mutable()
# StructTypes.omitempties(::Type{PlotConfig}) = fieldnames(PlotConfig)

# backdoor to apply things like templates
JSON3.write(io::IO, p::Plot) = JSON.print(io, p)
JSON3.write(p::Plot) = JSON.json(p)
