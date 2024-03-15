module ColorsExt

isdefined(Base, :get_extension) ? (using Colors) : (using ..Colors)
using PlotlyBase

PlotlyBase._json_lower(a::Colorant) = "#$(hex(a, :auto))"

end