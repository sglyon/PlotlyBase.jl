module ColorsExt

isdefined(Base, :get_extension) ? (using Colors) : (using ..Colors)
using PlotlyBase

_json_lower(a::Colors.Colorant) = string("#", Colors.hex(a))

end