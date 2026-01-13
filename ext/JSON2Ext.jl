module JSON2Ext

isdefined(Base, :get_extension) ? (using JSON2) : (using ..JSON2)

import PlotlyBase: Plot, JSON

function JSON2.write(io::IO, p::Plot)
    print(io, JSON.json(p))
end

end