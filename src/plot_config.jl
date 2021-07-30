using Parameters

"""
    PlotConfig(;kwargs...)

Configuration options to be sent to the frontend to control aspects of how the plot is rendered. The acceptable keyword arguments are:

- `scrollZoom`: Determines whether mouse wheel or two-finger scroll zooms is enable. Turned on by default for gl3d, geo and mapbox subplots (as these subplot types do not have zoombox via pan), but turned off by default for cartesian subplots. Set `scrollZoom` to *false* to disable scrolling for all subplots.
- `editable`: Determines whether the graph is editable or not. Sets all pieces of `edits` unless a separate `edits` config item overrides individual parts.
- `staticPlot`: Determines whether the graphs are interactive or not. If *false*, no interactivity, for export or image generation.
- `toImageButtonOptions`: Statically override options for toImage modebar button allowed keys are format, filename, width, height
- `displayModeBar`: Determines the mode bar display mode. If *true*, the mode bar is always visible. If *false*, the mode bar is always hidden. If *hover*, the mode bar is visible while the mouse cursor is on the graph container.
- `modeBarButtonsToRemove`: Remove mode bar buttons by name
- `modeBarButtonsToAdd`: Add mode bar button using config objects. To enable predefined modebar buttons e.g. shape drawing, hover and spikelines, simply provide their string name(s). This could include: *v1hovermode*, *hoverclosest*, *hovercompare*, *togglehover*, *togglespikelines*, *drawline*, *drawopenpath*, *drawclosedpath*, *drawcircle*, *drawrect* and *eraseshape*. Please note that these predefined buttons will only be shown if they are compatible with all trace types used in a graph.
- `modeBarButtons`: Define fully custom mode bar buttons as nested array where the outer arrays represents button groups, and the inner arrays have buttons config objects or names of default buttons.
- `showLink`: Determines whether a link to Chart Studio Cloud is displayed at the bottom right corner of resulting graphs. Use with `sendData` and `linkText`.
- `plotlyServerURL`: When set it determines base URL for the 'Edit in Chart Studio' `showEditInChartStudio`/`showSendToCloud` mode bar button and the showLink/sendData on-graph link. To enable sending your data to Chart Studio Cloud, you need to set both `plotlyServerURL` to 'https://chart-studio.plotly.com' and also set `showSendToCloud` to true.
- `linkText`: Sets the text appearing in the `showLink` link.
- `showEditInChartStudio`: Same as `showSendToCloud`, but use a pencil icon instead of a floppy-disk. Note that if both `showSendToCloud` and `showEditInChartStudio` are turned, only `showEditInChartStudio` will be honored.
- `locale`: Which localization should we use? Should be a string like 'en' or 'en-US'.
- `displaylogo`: Determines whether or not the plotly logo is displayed on the end of the mode bar.
- `responsive`: Determines whether to change the layout size when window is resized.
- `doubleClickDelay`: Sets the delay for registering a double-click in ms. This is the time interval (in ms) between first mousedown and 2nd mouseup to constitute a double-click. This setting propagates to all on-subplot double clicks (except for geo and mapbox) and on-legend double clicks.
"""
@with_kw mutable struct PlotConfig
    scrollZoom::Union{Nothing,Bool} = true
    editable::Union{Nothing,Bool} = false
    staticPlot::Union{Nothing,Bool} = false
    toImageButtonOptions::Union{Nothing,Dict} = nothing
    displayModeBar::Union{Nothing,Bool} = nothing
    modeBarButtonsToRemove::Union{Nothing,Array} = nothing
    modeBarButtonsToAdd::Union{Nothing,Array} = nothing
    modeBarButtons::Union{Nothing,Array} = nothing
    showLink::Union{Nothing,Bool} = false
    plotlyServerURL::Union{Nothing,String} = nothing
    linkText::Union{Nothing,String} = nothing
    showEditInChartStudio::Union{Nothing,Bool} = nothing
    locale::Union{Nothing,String} = nothing
    displaylogo::Union{Nothing,Bool} = nothing
    responsive::Union{Nothing,Bool} = true
    doubleClickDelay::Union{Nothing,Int} = nothing
end

function JSON.lower(pc::PlotConfig)
    out = Dict{Symbol,Any}()
    for fn in fieldnames(PlotConfig)
        field = getfield(pc, fn)
        if !isnothing(field)
            out[fn] = field
        end
    end
    out
end

function Base.get(pc::PlotConfig, field::Symbol, default::Any)
    if hasfield(pc, field)
        val = getfield(pc, field)
        if !isnothing(val)
            return val
        end
    end
    return default
end
