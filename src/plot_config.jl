using Parameters

@with_kw mutable struct PlotConfig
    scrollZoom::Union{Missing,Bool} = true
    editable::Union{Missing,Bool} = false
    staticPlot::Union{Missing,Bool} = false
    toImageButtonOptions::Union{Missing,Dict} = missing
    displayModeBar::Union{Missing,Bool} = missing
    modeBarButtonsToRemove::Union{Missing,Array} = missing
    modeBarButtonsToAdd::Union{Missing,Array} = missing
    showLink::Union{Missing,Bool} = false
    plotlyServerURL::Union{Missing,String} = missing
    linkText::Union{Missing,String} = missing
    showEditInChartStudio::Union{Missing,Bool} = missing
    locale::Union{Missing,String} = missing
    displaylogo::Union{Missing,Bool} = missing
    responsive::Union{Missing,Bool} = true
    doubleClickDelay::Union{Missing,Int} = missing
end

function JSON.lower(pc::PlotConfig)
    out = Dict{Symbol,Any}()
    for fn in fieldnames(PlotConfig)
        field = getfield(pc, fn)
        if !ismissing(field)
            out[fn] = field
        end
    end
    out
end

function Base.get(pc::PlotConfig, field::Symbol, default::Any)
    if hasfield(pc, field)
        val = getfield(pc, field)
        if !ismissing(val)
            return val
        end
    end
    return default
end
