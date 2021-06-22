# ----------------------- #
# Display-esque functions #
# ----------------------- #
function html_body(p::Plot)
    """
    <script>
        $(script_content(p))
     </script>
    """
end

function script_content(p::Plot)
    """
    gd = (function() {
      var WIDTH_IN_PERCENT_OF_PARENT = 100;
      var HEIGHT_IN_PERCENT_OF_PARENT = 100;
      var gd = Plotly.d3.select('body')
        .append('div').attr("id", "$(p.divid)")
        .style({
          width: WIDTH_IN_PERCENT_OF_PARENT + '%',
          'margin-left': (100 - WIDTH_IN_PERCENT_OF_PARENT) / 2 + '%',
          height: HEIGHT_IN_PERCENT_OF_PARENT + 'vh',
          'margin-top': (100 - HEIGHT_IN_PERCENT_OF_PARENT) / 2 + 'vh'
        })
        .node();
      var plot_json = $(json(p));
      Plotly.newPlot(gd, plot_json);
      window.onresize = function() {
        Plotly.Plots.resize(gd);
      };
      return gd;
    })();
    """
end


function savehtml(io::IO, p::Plot)
    print(io, """
    <html>
    <head>
    <script src="https://cdn.plot.ly/plotly-1.58.4.min.js"></script>
    </head>
    <body>
      $(html_body(p))
    </body>
    </html>
    """)
end

savehtml(p::Plot, fn::AbstractString) = open(f -> savehtml(f, p), fn, "w")

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

# integration with vscode and Juno
function Base.show(io::IO, ::MIME"application/prs.juno.plotpane+html", p::Plot)
    savehtml(io, p)
end

Base.show(io::IO, p::Plot) = show(io, MIME("text/plain"), p)

import REPL

"""
opens a browser tab with the given html file
"""
function launch_browser(tmppath::String)
    if Sys.isapple()
        run(`open $tmppath`)
    elseif Sys.iswindows()
    run(`cmd /c start $tmppath`)
  elseif Sys.islinux()
    run(`xdg-open $tmppath`)
    end
end

function Base.display(::REPL.REPLDisplay, p::Plot)
    tmppath = string(tempname(), ".plotlyjs-jl.html")
    open(tmppath, "w") do io
        savehtml(io, p)
    end
    launch_browser(tmppath) # Open the browser
end
