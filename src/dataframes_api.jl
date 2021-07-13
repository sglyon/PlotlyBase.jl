# utilities

_has_group(df::DataFrames.AbstractDataFrame, group::Any) = false
_has_group(df::DataFrames.AbstractDataFrame, group::Symbol) = hasproperty(df, group)
function _has_group(df::DataFrames.AbstractDataFrame, group::Vector{Symbol})
    all(x -> hasproperty(df, x), group)
end

_group_name(df::DataFrames.AbstractDataFrame, group::Symbol) = df[1, group]
function _group_name(df::DataFrames.AbstractDataFrame, groups::Vector{Symbol})
    string("(", join([df[1, g] for g in groups], ", "), ")")
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
function GenericTrace(df::DataFrames.AbstractDataFrame; group=nothing, kind="scatter", kwargs...)
    if _has_group(df, group)
        _traces = []
        for dfg in collect(DataFrames.groupby(df, group))
            push!(_traces,  GenericTrace(dfg; kind=kind, name=_group_name(dfg, group), kwargs...))
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
              style::Style=CURRENT_STYLE[], kwargs...)
    kw_keys = keys(kwargs)
    # set axis titles
    for ax in [:x, :y, :z]
        ax in kw_keys && setifempty!(l, Symbol(ax, "axis_title"), kwargs[ax])
    end

    # set legend title
    :group in kw_keys && setifempty!(l, :legend_title_text, kwargs[:group])

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

    if Nrows > 1 || Ncols > 1
        subplot_kw = Dict{Symbol,Any}()
        groupby_cols = Symbol[]
        if Ncols > 1
            subplot_kw[:cols] = Ncols
            subplot_kw[:column_titles] = cols
            subplot_kw[:shared_yaxes] = true
            push!(groupby_cols, Symbol(kwargs[:facet_col]))
        end

        if Nrows > 1
            subplot_kw[:rows] = Nrows
            subplot_kw[:row_titles] = rows
            subplot_kw[:shared_xaxes] = true
            push!(groupby_cols, Symbol(kwargs[:facet_row]))
        end

        subplots = Subplots(; subplot_kw...)
        subplot_layout = Layout(subplots; l.fields...)
        out = Plot(subplot_layout)

        for dfg in collect(DataFrames.groupby(df, groupby_cols))
            row_ix = Nrows == 1 ? 1 : findfirst(isequal(dfg[1, kwargs[:facet_row]]), rows)
            col_ix = Ncols == 1 ? 1 : findfirst(isequal(dfg[1, kwargs[:facet_col]]), cols)
            traces = GenericTrace(dfg; kwargs...)

            traces_vec = traces isa GenericTrace ? [traces] : traces
            for trace in traces_vec
                add_trace!(out, trace, row=row_ix, col=col_ix)
            end
        end

        return out
    end


    Plot(GenericTrace(df; kwargs...), l, style=style)
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
