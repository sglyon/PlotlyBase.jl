import DataFrames.AbstractDataFrame
using DataFrames

@require Revise="295af30f-e4ad-537b-8983-00126c2a3abe" begin
    Revise.track(PlotlyBase, @__FILE__)
end

# utilities

_has_group(df::AbstractDataFrame, group::Any) = false
_has_group(df::AbstractDataFrame, group::Symbol) = haskey(df, group)
function _has_group(df::AbstractDataFrame, group::Vector{Symbol})
    all(x -> haskey(df, x), group)
end

_group_name(df::AbstractDataFrame, group::Symbol) = df[1, group]
function _group_name(df::AbstractDataFrame, groups::Vector{Symbol})
    string("(", join([df[1, g] for g in groups], ", "), ")")
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
\$(mean(df[:X1])))"` then the `name` attribute on the trace would be replaced by
the  `Wage (average = XX)`, where `XX` is the average of the `X1` column in the
DataFrame.

The ability to pass functions as values for keyword arguments is particularly
useful when using the `group` keyword arugment, as the function will be applied
to each SubDataFrame. In the example above, the name attribute would set a
different mean for each group.
"""
function GenericTrace(df::AbstractDataFrame; group=nothing, kind="scatter", kwargs...)
    d = Dict{Symbol,Any}(kwargs)
    if _has_group(df, group)
        _traces = by(df, group) do dfg
            GenericTrace(dfg; kind=kind, name=_group_name(dfg, group), kwargs...)
        end
        return GenericTrace[t for t in _traces[:x1]]
    else
        !isa(group, Void) && warn("Unknown group $(group), skipping")
    end

    for (k, v) in d
        if isa(v, Symbol) && haskey(df, v)
            d[k] = df[v]
        elseif isa(v, Function)
            d[k] = v(df)
        end
    end
    GenericTrace(kind; d...)
end


"""
$(SIGNATURES)
Pass the provided values of `x` and `y` as keyword arguments for constructing
the trace from `df`. See other method for more information
"""
function GenericTrace(df::AbstractDataFrame, x::Symbol, y::Symbol; kwargs...)
    GenericTrace(df; x=x, y=y, kwargs...)
end

"""
$(SIGNATURES)
Pass the provided value `y` as keyword argument for constructing the trace from
`df`. See other method for more information
"""
function GenericTrace(df::AbstractDataFrame, y::Symbol; kwargs...)
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
function Plot(df::AbstractDataFrame, l::Layout=Layout();
              style::Style=CURRENT_STYLE[], kwargs...)
    Plot(GenericTrace(df; kwargs...), l, style=style)
end

"""
$(SIGNATURES)
Construct a plot from `df`, passing the provided values of x and y as keyword
arguments. See docstring for other method for more information.
"""
function Plot(d::AbstractDataFrame, x::Symbol, y::Symbol, l::Layout=Layout();
              style::Style=CURRENT_STYLE[], kwargs...)
    Plot(d, l; x=x, y=y, style=style, kwargs...)
end

"""
$(SIGNATURES)
Construct a plot from `df`, passing the provided value y as a keyword argument.
See docstring for other method for more information.
"""
function Plot(d::AbstractDataFrame, y::Symbol, l::Layout=Layout();
              style::Style=CURRENT_STYLE[], kwargs...)
    Plot(d, l; y=y, style=style, kwargs...)
end


for t in _TRACE_TYPES
    str_t = string(t)
    @eval $t(df::AbstractDataFrame; kwargs...) = GenericTrace(df; kind=$(str_t), kwargs...)
end
