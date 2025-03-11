module IJuliaExt

isdefined(Base, :get_extension) ? (using IJulia) : (using ..IJulia)
using PlotlyBase

function IJulia.display_dict(p::Plot)
    Dict(
        "application/vnd.plotly.v1+json" => PlotlyBase.JSON.lower(p),
        "text/plain" => sprint(show, "text/plain", p),
        "text/html" => let
            buf = IOBuffer()
            show(buf, MIME("text/html"), p)
            String(take!(buf))
        end
    )
end

end
