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
function GenericTrace(df::DataFrames.AbstractDataFrame; group=missing, kind="scatter", kwargs...)
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
        if !ismissing(group)
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

lexographically sort obsvals to match orders, given keys into orders
"""
function _partial_val_sortperm(
        obsvals::Vector{<:Vector}, orders::Dict{Symbol}, order_keys::Vector{Symbol}
    )
    if length(obsvals[1]) !== length(order_keys)
        error("obsvals[i] and order_keys must be same length")
    end

    to_sort = deepcopy(obsvals)
    for trace_i in 1:length(obsvals)
        for (group_i, colname) in enumerate(order_keys)
            if haskey(orders, Symbol(colname))
                want_order = orders[Symbol(colname)]
                group_val = obsvals[trace_i][group_i]
                to_sort[trace_i][group_i] = findfirst(isequal(group_val), want_order)
            end
        end
    end
    return sortperm(to_sort)
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
function Plot(
        df::DataFrames.AbstractDataFrame,
        l::Layout=Layout();
        category_orders::_Maybe{Union{PlotlyAttribute,<:Dict{Symbol}}}=missing,
        labels::_Maybe{Union{PlotlyAttribute,<: Dict}}=missing,
        facet_row::_Maybe{Symbol}=missing,
        facet_col::_Maybe{Symbol}=missing,
        group::_Maybe{Union{Symbol,Vector{Symbol}}}=missing,
        symbol::_Maybe{Symbol}=missing,
        color::_Maybe{Symbol}=missing,
        line_dash::_Maybe{Symbol}=missing,
        style::Style=CURRENT_STYLE[],
        kw...
    )
    groupby_cols = Symbol[]
    facet_cols = Symbol[]
    kwargs = Dict(kw)
    kw_keys = keys(kwargs)

    # prep groupings (symbol, color)
    _group_args = (;symbol, color, line_dash)
    _group_maps = Dict{Symbol,Dict{Any,String}}()
    _group_cols = Dict{Symbol,Symbol}()
    for (_group_arg, _group_col) in pairs(_group_args)
        if !ismissing(_group_col)
            if !_has_group(df, _group_col)
                error("DataFrame is missing $(_group_col) column, cannot set as $(_group_arg)")
            else
                # mark that we have this group and add to list of groupby_cols
                push!(groupby_cols, _group_col)

                # make note of the column that we will use for the groupby
                _group_cols[_group_arg] = _group_col

                # prepare map from group observation in data to the value in trace
                _group_map = Dict{Any,String}()
                defaults = _get_default_seq(l, _group_arg)
                for (i, val) in enumerate(unique(df[!, _group_col]))
                    _group_map[val] = defaults[i]
                end
                _group_maps[_group_arg] = _group_map
            end
        end
    end
    group_attr_pairs = [(:symbol, :marker_symbol), (:color, :marker_color), (:line_dash, :line_dash)]

    if length(groupby_cols) > 0 && !ismissing(group)
        @warn "One of color or symbol present AND group -- group will be ignored"
    end

    # handle labels
    label_map = Dict{Symbol,Any}(pairs((;facet_row, facet_col, color, symbol, line_dash)))
    for v in values(label_map)
        !ismissing(v) && setindex!(label_map, v, v)
    end
    if !ismissing(labels)
        for (k, v) in pairs(_symbol_dict(labels))
            label_map[k] = v
        end
    end

    # axis titles
    for ax in [:x, :y, :z]
        if ax in kw_keys
            ax_val = kwargs[ax]
            # use `get` below because if something was passed into labels it
            # will already  be set in `label_map` and we should use the Given
            # label. Otherwise use hte value directly.
            # e.g.  in plot(x=:total_bill, labels=Dict(:total_bill=>"Total Bill"))
            # label_map[:total_bill] will be "Total Bill", so we should set
            # label_map[:x] = "Total Bill".
            label_map[ax] = get(label_map, ax_val, ax_val)
            label_map[ax_val] = ax_val
        end
    end

    # Handle category orders
    orders = Dict{Symbol,Any}()
    if !ismissing(category_orders)
        for (k, v) in pairs(category_orders)
            if !_has_group(df, k)
                @warn "Unknown category $k (dataframe has no column $k). Skipping"
                continue
            end
            unique_vals = unique(df[!, k])
            cat_order = deepcopy(v)
            for v in unique_vals
                if !(v in cat_order)
                    push!(cat_order, v)
                end
            end
            orders[k] = cat_order
        end
    end

    # handle facets
    rows = []
    cols = []
    if !ismissing(facet_row)
        if !_has_group(df, facet_row)
            error("DataFrame is missing $(facet_row), cannot set as facet_row")
        else
            rows = get(orders, facet_row, unique(df[:, facet_row]))
        end
    end

    if !ismissing(facet_col)
        if !_has_group(df, facet_col)
            error("DataFrame is missing $(facet_col), cannot set as facet_col")
        else
            cols = get(orders, facet_col, unique(df[:, facet_col]))
        end
    end

    Nrows = max(1, length(rows))
    Ncols = max(1, length(cols))

    out_layout = l
    if Nrows > 1 || Ncols > 1
        subplot_kw = Dict{Symbol,Any}()
        if Ncols > 1
            subplot_kw[:cols] = Ncols
            subplot_kw[:column_titles] = map(x -> "$(label_map[facet_col])=$(x)", cols)
            subplot_kw[:shared_yaxes] = true
            push!(facet_cols, facet_col)
        end

        if Nrows > 1
            subplot_kw[:rows] = Nrows
            subplot_kw[:row_titles] = map(x -> "$(label_map[facet_row])=$(x)", rows)
            subplot_kw[:shared_xaxes] = true
            push!(facet_cols, facet_row)
        end

        subplots = Subplots(; subplot_kw...)
        out_layout = Layout(subplots; out_layout.fields...)
    end

    out = Plot(out_layout)

    legend_order = Vector{<:Any}[]
    for dfg in collect(DataFrames.groupby(df, facet_cols))
        row_ix = Nrows == 1 ? 1 : findfirst(isequal(dfg[1, facet_row]), rows)
        col_ix = Ncols == 1 ? 1 : findfirst(isequal(dfg[1, facet_col]), cols)

        for sub_dfg in collect(DataFrames.groupby(dfg, groupby_cols))
            extra_kw = attr()
            group_obs = Any[sub_dfg[1, g] for g in groupby_cols]
            group_name = join(string.(group_obs), ",")
            if length(group_name) > 0
                extra_kw.name = group_name
                extra_kw.legendgroup = group_name
                extra_kw.showlegend = false
            end
            for (groupname, trace_attr) in group_attr_pairs
                if !ismissing(getfield(_group_args, groupname))
                    obs = sub_dfg[1, _group_cols[groupname]]
                    extra_kw[trace_attr] = _group_maps[groupname][obs]
                end
            end
            traces = GenericTrace(sub_dfg; group=group, kwargs..., extra_kw...,)

            traces_vec = traces isa GenericTrace ? [traces] : traces
            for trace in traces_vec
                push!(legend_order, group_obs)
                add_trace!(out, trace, row=row_ix, col=col_ix)
            end
        end
    end

    # turn on legend once for each
    if length(groupby_cols) > 0
        group_labels = getindex.(Ref(label_map), groupby_cols)
        out.layout[:legend_title_text] = join(string.(group_labels), ", ")
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

    # fix order of traces according to category_orders
    trace_order = _partial_val_sortperm(legend_order, orders, groupby_cols)
    out.data = out.data[trace_order]

    # add x axis title to bottom row of subplots and y axis title to left column
    for gr in out.layout.subplots.grid_ref[:, 1]
        yname = gr[1].layout_keys[2]
        if :y in keys(label_map)
            setifempty!(out.layout, Symbol("$(yname)_title_text"), label_map[:y])
        end

        if haskey(orders, kwargs[:y])
            # order the yticks
            setifempty!(out.layout, Symbol("$(yname)_categoryorder"), "array")
            setifempty!(out.layout, Symbol("$(yname)_categoryarray"), orders[kwargs[:y]])
        end
    end
    for gr in out.layout.subplots.grid_ref[end, :]
        xname = gr[1].layout_keys[1]
        if :x in keys(label_map)
            setifempty!(out.layout, Symbol("$(xname)_title_text"), label_map[:x])

            if haskey(orders, kwargs[:x])
                # order the xticks
                setifempty!(out.layout, Symbol("$(xname)_categoryorder"), "array")
                setifempty!(out.layout, Symbol("$(xname)_categoryarray"), orders[kwargs[:x]])
            end
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
