module JSON2Ext

isdefined(Base, :get_extension) ? (using JSON2) : (using ..JSON2)

import PlotlyBase: Plot, JSON

function JSON2.write(io::IO, p::Plot)
    # data = PlotlyBase._json_lower(p)
    # pop!(data, :config, nothing)
    println("hi")
    print(io, json(p))
end

end