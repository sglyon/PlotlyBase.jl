# ----------------------- #
# Display-esque functions #
# ----------------------- #
function html_body(p::Plot)
    """
    <div id="$(p.divid)" class="plotly-graph-div"></div>

    <script>
        window.PLOTLYENV=window.PLOTLYENV || {};
        window.PLOTLYENV.BASE_URL="https://plot.ly";
        $(script_content(p))
     </script>
    """
end

function script_content(p::Plot)
    lowered = JSON.lower(p)
    """
    Plotly.newPlot('$(p.divid)', $(json(lowered[:data])),
                   $(json(lowered[:layout])), {showLink: false});
    """
end

# just declare here so we can overload elsewhere
function savefig end

function savejson(p::Plot, fn::AbstractString)
    ext = split(fn, ".")[end]
    if ext == "json"
        open(f -> print(f, json(p)), fn, "w")
        return p
    else
        msg = "PlotlyBase can only save figures as JSON. For all other"
        msg *= " file types, please use PlotlyJS.jl"
        throw(ArgumentError(msg))
    end
end


# jupyterlab/nteract integration
Base.Multimedia.istextmime(::MIME"application/vnd.plotly.v1+json") = true
function Base.show(io::IO, ::MIME"application/vnd.plotly.v1+json", p::Plot)
    JSON.print(io, p)
end

function Base.show(io::IO, ::MIME"text/plain", p::Plot)
    println(io, """
    data: $(json(map(_describe, p.data), 2))
    layout: "$(_describe(p.layout))"
    """)
end

Base.show(io::IO, p::Plot) = show(io, MIME("text/plain"), p)
