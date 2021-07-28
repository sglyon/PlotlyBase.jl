# ----------------------- #
# Display-esque functions #
# ----------------------- #

const _WINDOW_PLOTLY_CONFIG = """
<script type="text/javascript">
window.PlotlyConfig = {MathJaxConfig: 'local'};
</script>"""

const _MATHJAX_CONFIG = """
<script type="text/javascript">
if (window.MathJax) {MathJax.Hub.Config({SVG: {font: "STIX-Web"}});}
</script>"""

const PLOTLYJS_VERSION = "2.3.0"

const CDN_URL = "https://cdn.plot.ly/plotly-$(PLOTLYJS_VERSION).min.js"


function _requirejs_config()
    """
    $(_WINDOW_PLOTLY_CONFIG)
    $(_MATHJAX_CONFIG)
    <script type="text/javascript">
        if (typeof require !== 'undefined') {
            require.undef("plotly");
            requirejs.config({
                paths: {
                    'plotly': ['$(rsplit(CDN_URL, '.', limit=2)[1])']
                }
            });
            require(['plotly'], function(Plotly) {
                window._Plotly = Plotly;
            });
        }
    </script>
    """
end

function to_html(
        io::IO,
        p::Plot;
        autoplay::Bool=true,
        include_plotlyjs::Union{String,Missing}="cdn",
        include_mathjax::Union{String,Missing}="cdn",
        post_script::Union{String,Missing}=missing,
        full_html::Bool=true,
        animation_opts::Union{Dict,Missing}=missing,
        default_width::String="100%",
        default_height::String="100%"
    )
    # get lowered form
    js = JSON.lower(p)
    jdata = js[:data]
    jlayout = js[:layout]
    jframes = js[:frames]
    jconfig = js[:config]
    get!(jconfig, :responsive, true)

    # extract width and height from layout
    div_width = get(p.layout, :width, default_width)
    div_height = get(p.layout, :height, default_height)

    # get platform url
    base_url_line = ""
    if p.config.showLink === true || p.config.showEditInChartStudio === true
        url = ismissing(p.config.plotlyServerURL) ? "https://plot.ly" : p.config.plotlyServerURL
        base_url_line = "window.PLOTLYENV.BASE_URL = '$url';\n"
    else
        pop!(jconfig, :plotlyServerURL, missing)
        pop!(jconfig, :linkText, missing)
        pop!(jconfig, :showLink, missing)
    end

    # build script body
    then_post_script = ""
    if !ismissing(post_script)
        then_post_script = ".then(function() {$(replace(post_script, plot_id => p.divid))})"
    end

    then_addframes = ""
    then_animate = ""
    if !isempty(jframes)
        then_addframes = """.then(function() {
            Plotly.addFrames('$(p.divid)', $(JSON.json(jframes)));
        })"""

        if autoplay
            animation_opts_arg = ""
            if !ismissing(animation_opts)
                animation_opts_arg = ", $(JSON.json(animation_opts))"
            end

            then_animate = """.then(function() {
                Plotly.animate('$(p.divid)', null$(animation_opts_arg));
            })"""
        end
    end  # jframes

    call_plotlyjs_script = """
    if (document.getElementById('$(p.divid)')) {
        Plotly.newPlot(
            '$(p.divid)',
            $(JSON.json(jdata)),
            $(JSON.json(jlayout)),
            $(JSON.json(jconfig)),
        )$(then_addframes)$(then_animate)$(then_post_script)
    }
    """

    # handle loading/initializing plotly.js
    # Start/end of requirejs block (if any)
    require_start = ""
    require_end = ""
    load_plotlyjs = ""  # Init and load

    if !ismissing(include_plotlyjs)
        including = lowercase(include_plotlyjs)
        if including == "require"
            load_plotlyjs = _requirejs_config()
            require_start = "require([\"plotly\"], function(Plotly) {"
            require_end = "});"
        elseif including == "require-loaded"
            require_start = "require([\"plotly\"], function(Plotly) {"
            require_end = "});"
        elseif including == "directory"
            load_plotlyjs = """
            $(_WINDOW_PLOTLY_CONFIG)
            <script src="plotly.min.js"></script>
            """
        elseif endswith(including, ".js")
            # check if this is a file
            if embed_plotlyjs
                if !isfile(including)
                    error("cannot embed $(including) file not found")
                end
                # if so, read it and insert inline
                load_plotlyjs = """
                <script type="text/javascript">
                $(read(including, String))
                </script>
                """
            else
                # assume it is a url that can be found
                load_plotlyjs = """
                $(_WINDOW_PLOTLY_CONFIG)
                <script src="$(including)"></script>
                """
            end
        else  # assume cdn
            load_plotlyjs = """
            $(_WINDOW_PLOTLY_CONFIG)
            <script src="$(CDN_URL)"></script>
            """
        end
    end

    # handle mathjax
    load_mathjax = ""
    if isa(include_mathjax, String)
        inmath = lowercase(include_mathjax)
        math_url = ""
        if endswith(inmath, ".js")
            math_url = inmath
        else
            # assume cdn
            math_url = "https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.5/MathJax.js"
        end
        load_mathjax = "<script src=\"$(math_url)?config=TeX-AMS-MML_SVG\"></script>"
    end

    html_div = """
    <div>
        $(load_mathjax)
        $(load_plotlyjs)
        <div
            id=$(p.divid)
            class="plotly-graph-div"
            style="height:$(div_height); width:$(div_width);">
        </div>
        <script type="text/javascript">
            $(require_start)
            window.PLOTLYENV = window.PLOTLYENV || {}
            $(base_url_line)
            $(call_plotlyjs_script)
            $(require_end)
        </script>
    </div>
    """

    if full_html
        return print(io, """<html>
        <head><meta chartset="utf-8" /></head>
        <body>
        $(html_div)
        </body>
        </html>""")
    end
    return print(io, html_div)
end  # function

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

Base.show(io::IO, ::MIME"text/html", p::Plot; kwargs...) = to_html(io, p; kwargs...)

# integration with vscode and Juno
function Base.show(io::IO, ::MIME"application/prs.juno.plotpane+html", p::Plot)
    show(io, MIME("text/html"), p; include_mathjax="cdn", include_plotlyjs="cdn")
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
        show(io, MIME("text/html"), p; include_mathjax="cdn", include_plotlyjs="cdn")
    end
    launch_browser(tmppath) # Open the browser
end
