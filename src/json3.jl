const StructTypes = JSON3.StructTypes

# StructTypes.StructType(::Type{T}) where T <: HasFields = StructTypes.DictType()
# StructTypes.construct(::Type{T}, x::AbstractDict; kw...) where T <: HasFields = T(_symbol_dict(x); kw...)
# StructTypes.StructType(::Type{T}) where T <: Union{Template} = StructTypes.Struct()
# StructTypes.StructType(::Type{T}) where T <: Union{Plot,PlotConfig} = StructTypes.Mutable()
# StructTypes.omitempties(::Type{PlotConfig}) = fieldnames(PlotConfig)

StructTypes.StructType(::Type{<:PlotlyBase.Plot}) = JSON3.RawType()
StructTypes.StructType(::Type{<:HasFields}) = JSON3.RawType()
StructTypes.StructType(::Type{PlotConfig}) = JSON3.RawType()

JSON3.rawbytes(x::Union{PlotlyBase.Plot,HasFields,PlotConfig}) = codeunits(JSON.json(x))