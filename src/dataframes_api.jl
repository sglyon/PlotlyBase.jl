using Base:Symbol
# utilities

_has_group(df::DataFrames.AbstractDataFrame, group::Any) = false
_has_group(df::DataFrames.AbstractDataFrame, group::Symbol) = hasproperty(df, group)
function _has_group(df::DataFrames.AbstractDataFrame, group::Vector{Symbol})
    all(x -> hasproperty(df, x), group)
end

_group_name(df::DataFrames.AbstractDataFrame, group::Symbol) = df[1, group]
function _group_name(df::DataFrames.AbstractDataFrame, groups::Vector{Symbol})
    join([df[1, g] for g in groups], ", ")
end

function _obtain_setindex_val(container::DataFrames.AbstractDataFrame, val::Symbol)
    hasproperty(container, val) ? container[!, val] : val
end

const _MARKER_SYMBOLS = Cycler([
    "circle"
    "diamond"
    "cross"
    "triangle"
    "square"
    "x"
    "pentagon"
    "hexagon"
    "hexagon2"
    "octagon"
    "star"
    "hexagram"
    "hourglass"
    "bowtie"
    "asterisk"
    "hash"
    "y"
    "line"
])

"""
$(SIGNATURES)
Build a trace of kind `kind`, using the columns of `df` where possible. In
particular for all keyword arguments, if the value of the keyword argument is a
Symbol and matches one of the column names of `df`, replace the value of the
keyword argument with the column of `df`

If `group` is passed and is a Symbol that is one of the column names of `df`,
then call `by(df, group)` and construct one trace per SubDataFrame, passing
all other keyword arguments. This means all keyword arguments are passed
applied to all traces

Also, when using this routine you can pass a function as a value for any
keyword argument. This function will be replaced by calling the function on the
DataFrame. For example, if I were to pass `name=(df) -> "Wage (average =
\$(mean(df[!, :X1])))"` then the `name` attribute on the trace would be replaced by
the  `Wage (average = XX)`, where `XX` is the average of the `X1` column in the
DataFrame.

The ability to pass functions as values for keyword arguments is particularly
useful when using the `group` keyword arugment, as the function will be applied
to each SubDataFrame. In the example above, the name attribute would set a
different mean for each group.
"""
function GenericTrace(df::DataFrames.AbstractDataFrame; group=nothing, kind="scatter", kwargs...)
    if _has_group(df, group)
        _traces = []
        for dfg in collect(DataFrames.groupby(df, group))
            trace = GenericTrace(
                dfg;
                kind=kind,
                name=_group_name(dfg, group),
                legendgroup=_group_name(dfg, group),
                kwargs...
            )
            push!(_traces,  trace)
        end
        return GenericTrace[t for t in _traces]
    else
        if (group !== nothing)
            @warn "Unknown group $(group), skipping"
        end
    end

    attrs = attr()
    for (key, value) in kwargs
        # use `df` as `container` in setindex! for each property
        attrs[df, key] = value
    end
    GenericTrace(kind; attrs...)
end


"""
$(SIGNATURES)
Pass the provided values of `x` and `y` as keyword arguments for constructing
the trace from `df`. See other method for more information
"""
function GenericTrace(df::DataFrames.AbstractDataFrame, x::Symbol, y::Symbol; kwargs...)
    GenericTrace(df; x=x, y=y, kwargs...)
end

"""
$(SIGNATURES)
Pass the provided value `y` as keyword argument for constructing the trace from
`df`. See other method for more information
"""
function GenericTrace(df::DataFrames.AbstractDataFrame, y::Symbol; kwargs...)
    GenericTrace(df; y=y, kwargs...)
end

"""
$(SIGNATURES)
Construct a plot using the columns of `df` if possible. For each keyword
argument, if the value of the argument is a Symbol and the `df` has a column
whose name matches the value, replace the value with the column of the `df`.

If `group` is passed and is a Symbol that is one of the column names of `df`,
then call `by(df, group)` and construct one trace per SubDataFrame, passing
all other keyword arguments. This means all keyword arguments are passed
applied to all traces
"""
function Plot(df::DataFrames.AbstractDataFrame, l::Layout=Layout();
              style::Style=CURRENT_STYLE[], kw...)
    groupby_cols = Symbol[]
    facet_cols = Symbol[]
    kwargs = Dict(kw)
    kw_keys = keys(kwargs)

    # check for special kwargs from plotly.express api
    cats = _symbol_dict(pop!(kwargs, :category_order, missing))
    label_rename = _symbol_dict(pop!(kwargs, :labels, missing))

    # prep groupings (symbol, color)
    symbol_col = pop!(kwargs, :symbol, missing)
    has_symbol = !ismissing(symbol_col)
    symbol_map = Dict{Any,String}()
    if has_symbol
        if !_has_group(df, symbol_col)
            error("DataFrame is missing $(symbol_col) column, cannot set as symbol")
        else
            push!(groupby_cols, symbol_col)
            for (i, val) in enumerate(unique(df[!, symbol_col]))
                symbol_map[val] = _MARKER_SYMBOLS[i]
            end
        end
    end

    color_col = pop!(kwargs, :color, missing)
    has_color = !ismissing(color_col)
    color_map = Dict{Any,String}()
    if has_color
        if !_has_group(df, color_col)
            error("DataFrame is missing $(color_col) column, cannot set as color")
        else
            colorway = _get_colorway(l)
            push!(groupby_cols, color_col)
            for (i, val) in enumerate(unique(df[!, color_col]))
                color_map[val] = colorway[i]
            end
        end
    end

    if length(groupby_cols) > 0 && (:group in kw_keys)
        @warn "One of color or symbol present AND group -- group will be ignored"
    end

    rows = []
    cols = []
    if :facet_row in kw_keys
        if !_has_group(df, Symbol(kwargs[:facet_row]))
            error("DataFrame is missing $(kwargs[:facet_row]), cannot set as facet_row")
        else
            rows = unique(df[:, Symbol(kwargs[:facet_row])])
        end
    end

    if :facet_col in kw_keys
        if !_has_group(df, Symbol(kwargs[:facet_col]))
            error("DataFrame is missing $(kwargs[:facet_col]), cannot set as facet_col")
        else
            cols = unique(df[:, Symbol(kwargs[:facet_col])])
        end
    end

    Nrows = max(1, length(rows))
    Ncols = max(1, length(cols))

    out_layout = l
    if Nrows > 1 || Ncols > 1
        subplot_kw = Dict{Symbol,Any}()
        if Ncols > 1
            facet_col = Symbol(kwargs[:facet_col])
            subplot_kw[:cols] = Ncols
            subplot_kw[:column_titles] = map(x -> "$(facet_col)=$(x)", cols)
            subplot_kw[:shared_yaxes] = true
            push!(facet_cols, facet_col)
        end

        if Nrows > 1
            facet_row = Symbol(kwargs[:facet_row])
            subplot_kw[:rows] = Nrows
            subplot_kw[:row_titles] = map(x -> "$(facet_row)=$(x)", rows)
            subplot_kw[:shared_xaxes] = true
            push!(facet_cols, facet_row)
        end

        subplots = Subplots(; subplot_kw...)
        out_layout = Layout(subplots; out_layout.fields...)
    end

    out = Plot(out_layout)

    for dfg in collect(DataFrames.groupby(df, facet_cols))
        row_ix = Nrows == 1 ? 1 : findfirst(isequal(dfg[1, kwargs[:facet_row]]), rows)
        col_ix = Ncols == 1 ? 1 : findfirst(isequal(dfg[1, kwargs[:facet_col]]), cols)

        for sub_dfg in collect(DataFrames.groupby(dfg, groupby_cols))
            extra_kw = attr()
            group_name = _group_name(sub_dfg, groupby_cols)
            if length(group_name) > 0
                extra_kw.name = group_name
                extra_kw.legendgroup = group_name
                extra_kw.showlegend = false
            end
            if has_symbol
                symbol_col_val = sub_dfg[1, symbol_col]
                extra_kw.marker_symbol = symbol_map[symbol_col_val]
            end
            if has_color
                color_col_val = sub_dfg[1, color_col]
                extra_kw.marker_color = color_map[color_col_val]
            end
            traces = GenericTrace(sub_dfg; kwargs..., extra_kw...,)

            traces_vec = traces isa GenericTrace ? [traces] : traces
            for trace in traces_vec
                add_trace!(out, trace, row=row_ix, col=col_ix)
            end
        end
    end

    # turn on legend once for each
    if length(groupby_cols) > 0
        out.layout[:legend_title_text] = join(String.(groupby_cols), ", ")
        seen = Set()
        for trace in out.data
            grp = trace.legendgroup
            if !(grp in seen)
                push!(seen, grp)
                trace.showlegend = true
            end
        end
    end

    out.layout.legend_tracegroupgap = 0

    # add subplot axis labels.
    ax_titles = Dict{Symbol,Any}()
    for ax in [:x, :y, :z]
        if ax in kw_keys
            ax_titles[ax] = kwargs[ax]
        end
    end

    # add x axis title to bottom row of subplots and y axis title to left column
    for gr in out.layout.subplots.grid_ref[:, 1]
        yname = gr[1].layout_keys[2]
        if :y in keys(ax_titles)
            setifempty!(out.layout, Symbol("$(yname)_title_text"), ax_titles[:y])
        end
    end
    for gr in out.layout.subplots.grid_ref[end, :]
        xname = gr[1].layout_keys[1]
        if :x in keys(ax_titles)
            setifempty!(out.layout, Symbol("$(xname)_title_text"), ax_titles[:x])
        end
    end

    return out
end

"""
$(SIGNATURES)
Construct a plot from `df`, passing the provided values of x and y as keyword
arguments. See docstring for other method for more information.
"""
function Plot(d::DataFrames.AbstractDataFrame, x::Symbol, y::Symbol, l::Layout=Layout();
              style::Style=CURRENT_STYLE[], kwargs...)
    Plot(d, l; x=x, y=y, style=style, kwargs...)
end

"""
$(SIGNATURES)
Construct a plot from `df`, passing the provided value y as a keyword argument.
See docstring for other method for more information.
"""
function Plot(d::DataFrames.AbstractDataFrame, y::Symbol, l::Layout=Layout();
              style::Style=CURRENT_STYLE[], kwargs...)
    Plot(d, l; y=y, style=style, kwargs...)
end


for t in _TRACE_TYPES
    str_t = string(t)
    @eval $t(df::DataFrames.AbstractDataFrame; kwargs...) = GenericTrace(df; kind=$(str_t), kwargs...)
end
