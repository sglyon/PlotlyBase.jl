module JSON3Ext

isdefined(Base, :get_extension) ? (using JSON3) : (using ..JSON3)

import PlotlyBase: Plot, HasFields, PlotConfig, JSON.json
const StructTypes = JSON3.StructTypes

StructTypes.StructType(::Type{<:Plot}) = JSON3.RawType()
StructTypes.StructType(::Type{<:HasFields}) = JSON3.RawType()
StructTypes.StructType(::Type{PlotConfig}) = JSON3.RawType()

JSON3.rawbytes(x::Union{Plot, HasFields, PlotConfig}) = codeunits(json(x))

end