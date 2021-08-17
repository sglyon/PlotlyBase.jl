# -------------------------- #
# Standard Julia API methods #
# -------------------------- #
const ROW_COL_TYPE = Union{String,Int,Vector{Int},Colon}

_check_row_col_arg(_l::Layout, x::String, name, dim::Int=1) = x == "all" || @error "Unknown specifier $x for $name, must be an integer or `\"all\"`"
_check_row_col_arg(l::Layout, x::Int, name, dim::Int=1) = x <= size(l.subplots.grid_ref, dim) || error("$name index $x is too large for layout")
_check_row_col_arg(l::Layout, x::Vector{Int}, name, dim::Int=1) = foreach(_val -> _check_row_col_arg(l, _val, name, dim), x)
_check_row_col_arg(_l::Layout, x::Colon, name, dim::Int=1) = nothing

prep_kwarg(pair::Union{Pair,Tuple}) =
    (Symbol(replace(string(pair[1]), "_" => ".")), pair[2])
prep_kwargs(pairs::AbstractVector) = Dict(map(prep_kwarg, pairs))
prep_kwargs(pairs::AbstractDict) = Dict(prep_kwarg((k, v)) for (k, v) in pairs)

"""
    size(::PlotlyBase.Plot)

Return the size of the plot in pixels. Obtained from the `layout.width` and
`layout.height` fields.
"""
Base.size(p::Plot) = (get(p.layout.fields, :width, 800),
                      get(p.layout.fields, :height, 450))

const _TRACE_TYPES = [
    :bar, :barpolar, :box, :candlestick, :carpet, :choropleth,
    :choroplethmapbox, :cone, :contour, :contourcarpet, :densitymapbox,
    :funnel, :funnelarea, :heatmap, :heatmapgl, :histogram, :histogram2d,
    :histogram2dcontour, :icicle, :image, :indicator, :isosurface, :mesh3d, :ohlc,
    :parcats, :parcoords, :pie, :pointcloud, :sankey, :scatter, :scatter3d,
    :scattercarpet, :scattergeo, :scattergl, :scattermapbox, :scatterpolar,
    :scatterpolargl, :scatterternary, :splom, :streamtube, :sunburst,
    :surface, :table, :treemap, :violin, :volume, :waterfall
]

for t in _TRACE_TYPES
    str_t = string(t)
    code = quote
        $t(;kwargs...) = GenericTrace($str_t; kwargs...)
        $t(d::AbstractDict; kwargs...) = GenericTrace($str_t, _symbol_dict(d); kwargs...)
    end
    eval(code)
    eval(Expr(:export, t))
end

Base.copy(hf::HF) where {HF <: HasFields} = HF(deepcopy(hf.fields))
Base.copy(p::Plot) = Plot(AbstractTrace[copy(t) for t in p.data], copy(p.layout))
fork(p::Plot) = Plot(deepcopy(p.data), copy(p.layout))

# -------------- #
# Javascript API #
# -------------- #

#= 

this function is internal and allows us to match plotly.js semantics in
`resytle!`. The reason is that if you try to set an attribute on a trace with
and array, Plotly.restyle expects an array of arrays.

This means that to set the :x field with [1,2,3], the json should look
something like `[[1,2,3]]`. In Julia we can get this with a one row matrix `[1
2 3]'` or a tuple of arrays `([1, 2, 3], )`. This function applies that logic
and extracts the first element from an array or a tuple before calling
setindex.

All other field types are let through directly

NOTE that the argument `i` here is _not_ the same as the argument `ind` below.
`i` tracks which index we should use when extracting an element from
`v::Union{AbstractArray,Tuple}` whereas `ind` below specifies which trace to
apply the update to. =#
function _apply_restyle_setindex!(hf::Union{AbstractDict,HasFields}, k::Symbol,
                                  v::Union{AbstractArray,Tuple}, i::Int)
    setindex!(hf, v[i], k)
end

_apply_restyle_setindex!(hf::Union{AbstractDict,HasFields}, k::Symbol, v, i::Int) =
    setindex!(hf, v, k)


#= 
Wrap the vector so it repeats to be at least length N

This means

```julia
_prep_restyle_vec_setindex([1, 2], 2) --> [1, 2]
_prep_restyle_vec_setindex([1, 2], 3) --> [1, 2, 1]
_prep_restyle_vec_setindex([1, 2], 4) --> [1, 2, 1, 2]

_prep_restyle_vec_setindex((1, [42, 4]), 2) --> [1, [42, 4]]
_prep_restyle_vec_setindex((1, [42, 4]), 3) --> [1, [42, 4], 1]
_prep_restyle_vec_setindex((1, [42, 4]), 4) --> [1, [42, 4], 1, [42, 4]]
``` =#
_prep_restyle_vec_setindex(v::AbstractVector, N::Int) =
    repeat(v, outer=[ceil(Int, N / length(v))])[1:N]

# treat tuples like vectors, just like JSON.json does
_prep_restyle_vec_setindex(v::Tuple, N::Int) =
    _prep_restyle_vec_setindex(Any[i for i in v], N)

# everything else just goes through
_prep_restyle_vec_setindex(v, N::Int) = v

function _update_fields(hf::GenericTrace, i::Int, update::Dict=Dict(); kwargs...)
    # apply updates in the dict w/out `_` processing
    for (k, v) in update
        _apply_restyle_setindex!(hf.fields, k, v, i)
    end
    for (k, v) in kwargs
        _apply_restyle_setindex!(hf, k, v, i)
    end
    hf
end

"""
    relayout!(l::Layout, update::AbstractDict=Dict(); kwargs...)

Update `l` using update dict and/or kwargs
"""
function relayout!(l::Layout, update::AbstractDict=Dict(); kwargs...)
    merge!(l.fields, update)  # apply updates in the dict w/out `_` processing
    merge!(l, Layout(;kwargs...))
    l
end

function relayout!(dest::Layout, src::Layout; kwargs...)
    merge!(dest, src)
    relayout!(dest; kwargs...)
end

"""
    relayout!(p::Plot, update::AbstractDict=Dict(); kwargs...)

Update `p.layout` on using update dict and/or kwargs
"""
relayout!(p::Plot, args...; kwargs...) =
    relayout!(p.layout, args...; kwargs...)

"""
    restyle!(gt::GenericTrace, i::Int=1, update::AbstractDict=Dict(); kwargs...)

Update trace `gt` using dict/kwargs, assuming it was the `i`th ind in a call
to `restyle!(::Plot, ...)`
"""
restyle!(gt::GenericTrace, i::Int=1, update::AbstractDict=Dict(); kwargs...) =
    _update_fields(gt, i, update; kwargs...)

"""
    restyle!(p::Plot, ind::Int=1, update::AbstractDict=Dict(); kwargs...)

Update `p.data[ind]` using update dict and/or kwargs
"""
restyle!(p::Plot, ind::Int, update::AbstractDict=Dict(); kwargs...) =
    restyle!(p.data[ind], 1, update; kwargs...)

"""
    restyle!(::Plot, ::AbstractVector{Int}, ::AbstractDict=Dict(); kwargs...)

Update specific traces at `p.data[inds]` using update dict and/or kwargs
"""
function restyle!(p::Plot, inds::AbstractVector{Int},
                  update::AbstractDict=Dict(); kwargs...)
    N = length(inds)
    kw = Dict{Symbol,Any}(kwargs)

    # prepare update and kw dicts for vectorized application
    for d in (kw, update)
        for (k, v) in d
            d[k] = _prep_restyle_vec_setindex(v, N)
        end
    end

    map((ind, i) -> restyle!(p.data[ind], i, update; kw...), inds, 1:N)
end

"""
    restyle!(p::Plot, update::AbstractDict=Dict(); kwargs...)

Update all traces using update dict and/or kwargs
"""
restyle!(p::Plot, update::AbstractDict=Dict(); kwargs...) =
    restyle!(p, 1:length(p.data), update; kwargs...)

"""
The `restyle!` method follows the semantics of the `Plotly.restyle` function in
plotly.js. Specifically the following rules are applied when trying to set
an attribute `k` to a value `v` on trace `ind`, which happens to be the `i`th
trace listed in the vector of `ind`s (if `ind` is a scalar then `i` is always
equal to 1)

- if `v` is an array or a tuple (both translated to javascript arrays when
`json(v)` is called) then `p.data[ind][k]` will be set to `v[i]`. See examples
below
- if `v` is any other type (any scalar type), then `k` is set directly to `v`.

**Examples**

```julia
# set marker color on first two traces to be red
restyle!(p, [1, 2], marker_color="red")

# set marker color on trace 1 to be green and trace 2 to be red
restyle!(p, [2, 1], marker_color=["red", "green"])

# set marker color on trace 1 to be red. green is not used
restyle!(p, 1, marker_color=["red", "green"])

# set the first marker on trace 1 to red, the second marker on trace 1 to green
restyle!(p, 1, marker_color=(["red", "green"],))

# suppose p has 3 traces.
# sets marker color on trace 1 to ["red", "green"]
# sets marker color on trace 2 to "blue"
# sets marker color on trace 3 to ["red", "green"]
restyle!(p, 1:3, marker_color=(["red", "green"], "blue"))
```
"""
restyle!

function update!(
        p::Plot, ind::Union{AbstractVector{Int},Int},
        update::AbstractDict=Dict(); layout::Layout=Layout(),
        kwargs...
    )
    relayout!(p; layout.fields...)
    restyle!(p, ind, update; kwargs...)
    p
end

function update!(p::Plot, update=Dict(); layout::Layout=Layout(), kwargs...)
    update!(p, 1:length(p.data), update; layout=layout, kwargs...)
end

"""
Apply both `restyle!` and `relayout!` to the plot. Layout arguments are
specified by passing an instance of `Layout` to the `layout` keyword argument.

The `update` Dict (optional) and all keyword arguments will be passed to
restyle

## Example

```jlcon
julia> p = Plot([scatter(y=[1, 2, 3])], Layout(yaxis_title="this is y"));

julia> print(json(p, 2))
{
  "layout": {
    "margin": {
      "l": 50,
      "b": 50,
      "r": 50,
      "t": 60
    },
    "yaxis": {
      "title": "this is y"
    }
  },
  "data": [
    {
      "y": [
        1,
        2,
        3
      ],
      "type": "scatter"
    }
  ]
}

julia> update!(p, Dict(:marker => Dict(:color => "red")), layout=Layout(title="this is a title"), marker_symbol="star");

julia> print(json(p, 2))
{
  "layout": {
    "margin": {
      "l": 50,
      "b": 50,
      "r": 50,
      "t": 60
    },
    "yaxis": {
      "title": "this is y"
    },
    "title": "this is a title"
  },
  "data": [
    {
      "y": [
        1,
        2,
        3
      ],
      "type": "scatter",
      "marker": {
        "color": "red",
        "symbol": "star"
      }
    }
  ]
}
```
"""
update!

"""
    addtraces!(p::Plot, traces::AbstractTrace...)

Add trace(s) to the end of the Plot's array of data
"""
addtraces!(p::Plot, traces::AbstractTrace...) = push!(p.data, traces...)

"""
    addtraces!(p::Plot, i::Int, traces::AbstractTrace...)

Add trace(s) at a specified location in the Plot's array of data.

The new traces will start at index `p.data[i]`
"""
function addtraces!(p::Plot, i::Int, traces::AbstractTrace...)
    new_data = vcat(p.data[1:i - 1], traces..., p.data[i:end])
    p.data = new_data
end

"""
    deletetraces!(p::Plot, inds::Int...) =

Remove the traces at the specified indices
"""
deletetraces!(p::Plot, inds::Int...) =
    (p.data = p.data[setdiff(1:length(p.data), inds)])

"""
    movetraces!(p::Plot, to_end::Int...)

Move one or more traces to the end of the data array"
"""
movetraces!(p::Plot, to_end::Int...) =
    (p.data = p.data[vcat(setdiff(1:length(p.data), to_end), to_end...)])

function _move_one!(x::AbstractArray, from::Int, to::Int)
    el = splice!(x, from)  # extract the element
    splice!(x, to:to - 1, (el,))  # put it back in the new position
    x
end

"""
    movetraces!(p::Plot, src::AbstractVector{Int}, dest::AbstractVector{Int})

Move traces from indices `src` to indices `dest`.

Both `src` and `dest` must be `Vector{Int}`
"""
movetraces!(p::Plot, src::AbstractVector{Int}, dest::AbstractVector{Int}) =
    (map((i, j) -> _move_one!(p.data, i, j), src, dest); p)

function purge!(p::Plot)
    empty!(p.data)
    p.layout = Layout()
    nothing
end

function react!(p::Plot, data::AbstractVector{<:AbstractTrace}, layout::Layout)
    p.data = data
    p.layout = layout
    nothing
end

# no-op here
redraw!(p::Plot) = nothing
to_image(p::Plot; kwargs...) = nothing
download_image(p::Plot; kwargs...) = nothing

_tovec(v) = _tovec([v])
_tovec(v::Vector) = eltype(v) <: Vector ? v : Vector[v]

"""
    extendtraces!(::Plot, ::Dict{Union{Symbol,AbstractString},AbstractVector{Vector{Any}}}), indices, maxpoints)

Extend one or more traces with more data. A few notes about the structure of the
update dict are important to remember:

- The keys of the dict should be of type `Symbol` or `AbstractString` specifying
  the trace attribute to be updated. These attributes must already exist in the
  trace
- The values of the dict _must be_ a `Vector` of `Vector` of data. The outer index
  tells Plotly which trace to update, whereas the `Vector` at that index contains
  the value to be appended to the trace attribute.

These concepts are best understood by example:

```julia
# adds the values [1, 3] to the end of the first trace's y attribute and doesn't
# remove any points
extendtraces!(p, Dict(:y=>Vector[[1, 3]]), [1], -1)
extendtraces!(p, Dict(:y=>Vector[[1, 3]]))  # equivalent to above
```

```julia
# adds the values [1, 3] to the end of the third trace's marker.size attribute
# and [5,5,6] to the end of the 5th traces marker.size -- leaving at most 10
# points per marker.size attribute
extendtraces!(p, Dict("marker.size"=>Vector[[1, 3], [5, 5, 6]]), [3, 5], 10)
```

"""
function extendtraces!(p::Plot, update::AbstractDict, indices::AbstractVector{Int}=[1],
                       maxpoints=-1)
    # TODO: maxpoints not handled here
    for (ix, p_ix) in enumerate(indices)
        tr = p.data[p_ix]
        for k in keys(update)
            v = update[k][ix]
            tr[k] = push!(tr[k], v...)
        end
    end
end

"""
    prependtraces!(p::Plot, update::AbstractDict, indices::AbstractVector{Int}=[1],
                    maxpoints=-1)

The API for `prependtraces` is equivalent to that for `extendtraces` except that
the data is added to the front of the traces attributes instead of the end. See
Those docstrings for more information
"""
function prependtraces!(p::Plot, update::AbstractDict, indices::AbstractVector{Int}=[1],
                        maxpoints=-1)
    # TODO: maxpoints not handled here
    for (ix, p_ix) in enumerate(indices)
        tr = p.data[p_ix]
        for k in keys(update)
            v = update[k][ix]
            tr[k] = vcat(v, tr[k])
        end
    end
end


for f in (:extendtraces!, :prependtraces!)
    @eval begin
        $(f)(p::Plot, inds::Vector{Int}=[1], maxpoints=-1; update...) =
            ($f)(p, Dict(map(x -> (x[1], _tovec(x[2])), update)), inds, maxpoints)

        $(f)(p::Plot, ind::Int, maxpoints=-1; update...) =
            ($f)(p, [ind], maxpoints; update...)

        $(f)(p::Plot, update::AbstractDict, ind::Int, maxpoints=-1) =
            ($f)(p, update, [ind], maxpoints)
    end
end


for f in [:restyle, :relayout, :update, :addtraces, :deletetraces,
          :movetraces, :redraw, :extendtraces, :prependtraces, :purge, :react]
    f! = Symbol(f, "!")
    @eval function $(f)(p::Plot, args...; kwargs...)
        out = fork(p)
        $(f!)(out, args...; kwargs...)
        out
    end
end

function _add_trace!(p::Plot, trace::GenericTrace, row::Int, col::Int, secondary_y::Bool)
    refs = p.layout.subplots.grid_ref[row, col]
    if secondary_y && length(refs) == 1
        msg = "To use secondary_y, you must have created the Subplot with seconary_y=true"
        error(msg)
    end

    ref = refs[secondary_y ? 2 : 1]
    ref_trace = deepcopy(trace)
    merge!(ref_trace, ref.trace_kwargs)
    push!(p.data, ref_trace)
    p
end

function _add_trace!(p::Plot, trace::GenericTrace, row::ROW_COL_TYPE, col::ROW_COL_TYPE, secondary_y::Bool)
    for refs in p.layout.subplots.grid_ref[row, col]
        if secondary_y && length(refs) == 1
            msg = "To use secondary_y, you must have created the Subplot with seconary_y=true"
            error(msg)
        end
        ref = refs[secondary_y ? 2 : 1]
        ref_trace = deepcopy(trace)
        merge!(ref_trace, ref.trace_kwargs)
        push!(p.data, ref_trace)
    end
    p
end


function add_trace!(p::Plot, trace::GenericTrace; row::ROW_COL_TYPE=1, col::ROW_COL_TYPE=1, secondary_y::Bool=false)
    if row == 1 && col == 1
        push!(p.data, trace)
        return p
    end

    _check_row_col_arg(p.layout, row, "row", 1)
    _check_row_col_arg(p.layout, col, "col", 2)

    gridref_row_ix = row isa String ? Colon() : row
    gridref_col_ix = col isa String ? Colon() : col

    _add_trace!(p, trace, gridref_row_ix, gridref_col_ix, secondary_y)
    p
end

## internal helpers
_get_colorway(p::Plot) = _get_colorway(p.layout)
function _get_colorway(l::Layout)
    D3_colorway = [
        "#1F77B4",
        "#FF7F0E",
        "#2CA02C",
        "#D62728",
        "#9467BD",
        "#8C564B",
        "#E377C2",
        "#7F7F7F",
        "#BCBD22",
        "#17BECF",
    ]
    Cycler(get(l, :template_colorway, D3_colorway))
end

_get_seq_from_template_data(p::Plot, args...; kwargs...) = _get_seq_from_template_data(p.layout, args...; kwargs...)
function _get_seq_from_template_data(
        l::Layout,
        default::Cycler,
        property_sub_path::Symbol,
        root_template_path::Symbol=:scatter
    )
    template_specs = getindex(l, Symbol("template_data_$(root_template_path)"))
    if !isempty(template_specs)
        seq = []
        default_ix = 0
        for spec in template_specs
            want = get(spec, property_sub_path, Dict())
            if ismissing(want)
                push!(seq, default[default_ix += 1])
            else
                push!(seq, want)
            end
        end
        return Cycler(seq)
    end
    return default
end

function _get_line_dash_seq(l::Union{Layout,Plot})
    default_line_dash = Cycler([
        "solid",
        "dot",
        "dash",
        "longdash",
        "dashdot",
        "longdashdot",
    ])
    return _get_seq_from_template_data(l, default_line_dash, :line_dash, :scatter)
end


function _get_marker_symbol_seq(l::Union{Layout,Plot})
    default = Cycler([
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
    return _get_seq_from_template_data(l, default, :marker_symbol, :scatter)
end

function _get_default_seq(l::Layout, attribute::Symbol)
    _getter_funcs = Dict(
        :line_dash => _get_line_dash_seq,
        :symbol => _get_marker_symbol_seq,
        :color => _get_colorway
    )
    if attribute in keys(_getter_funcs)
        return _getter_funcs[attribute](l)
    end
    error("Don't know how to get defaults for $(attribute)")
end

function _update_all_layout_type!(l::Layout, layout_type::Symbol, with::PlotlyAttribute)
    l[layout_type] = with

    for (k, v) in pairs(l)
        if startswith(string(k), string(layout_type))
            l[k] = with
        end
    end
    l
end


const _layout_obj_updaters = [:update_xaxes! => :xaxis, :update_yaxes! => :yaxis, :update_geos! => :geo, :update_mapboxes! => :mapbox, :update_polars! => :polar, :update_scenes! => :scene, :update_ternaries! => :ternary]

for (k1, k2) in _layout_obj_updaters
    @eval $(k1)(l::Layout, with::PlotlyAttribute=attr(); kwargs...) = _update_all_layout_type!(l, $(Meta.quot(k2)), merge(with, attr(;kwargs...)))
    @eval $(k1)(p::Plot, with::PlotlyAttribute=attr(); kwargs...) = $(k1)(p.layout, merge(with, attr(;kwargs...)))
    @eval export $k1
end

const _layout_vector_updaters = [:update_annotations! => :(layout.annotations), :update_shapes! => :(layout.shapes)]

for (k1, k2) in _layout_vector_updaters
    @eval function $(k1)(layout::Layout, with::PlotlyAttribute; kwargs...)
        final_with = merge(with, attr(;kwargs...))
        for val in $(k2)
            merge!(val, final_with)
        end
    end
    @eval $(k1)(p::Plot, with::PlotlyAttribute=attr(); kwargs...) = $(k1)(p.layout, merge(with, attr(;kwargs...)))
    @eval export $(k1)
end



function _add_many_shapes!(
        l::Layout, base_shape::Shape, direction::Char, row::ROW_COL_TYPE, col::ROW_COL_TYPE
    )
    _check_row_col_arg(l, row, "row", 1)
    _check_row_col_arg(l, col, "col", 2)

    if direction != 'h' && direction != 'v'
        error("direction must be one of `'h'` or `'v'`")
    end

    shapes = get(l, :shapes, [])
    gridref_row_ix = row isa String ? Colon() : row
    gridref_col_ix = col isa String ? Colon() : col
    for refs in l.subplots.grid_ref[gridref_row_ix, gridref_col_ix]
        # refs is always a vector...
        ref = refs[1]

        # find xref and yref
        xax, yax = string.(ref.layout_keys)
        xid = string("x", xax[6:end])
        yid = string("y", yax[6:end])

        new_shape = deepcopy(base_shape)
        if direction == 'h'
            new_shape.xref = "$xid domain"
            new_shape.yref = yid
        else
            new_shape.xref = xid
            new_shape.yref = "$yid domain"
        end
        push!(shapes, new_shape)
    end
    l.shapes = shapes
end

_add_many_shapes!(p::Plot, args...) = _add_many_shapes!(p.layout, args...)

function add_hrect!(l::Union{Plot,Layout}, y0, y1; row::ROW_COL_TYPE="all", col::ROW_COL_TYPE="all", kw...)
    base_shape = rect(0, 1, y0, y1; kw...)
    _add_many_shapes!(l, base_shape, 'h', row, col)
end

function add_hline!(l::Union{Plot,Layout}, y; row::ROW_COL_TYPE="all", col::ROW_COL_TYPE="all", kw...)
    base_shape = hline(y; kw...)
    _add_many_shapes!(l, base_shape, 'h', row, col)
end

function add_vrect!(l::Union{Plot,Layout}, x0, x1; row::ROW_COL_TYPE="all", col::ROW_COL_TYPE="all", kw...)
    base_shape = rect(x0, x1, 0, 1; kw...)
    _add_many_shapes!(l, base_shape, 'v', row, col)
end

function add_vline!(l::Union{Plot,Layout}, x; row::ROW_COL_TYPE="all", col::ROW_COL_TYPE="all", kw...)
    base_shape = hline(x; kw...)
    _add_many_shapes!(l, base_shape, 'v', row, col)
end

export add_hrect!, add_hline!, add_vrect!, add_vline!
