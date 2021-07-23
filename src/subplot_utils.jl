# implementation of algorithms from plotly.py/packages/python/plotly/plotly/subplots.py

# Constants
# ---------
# Subplot types that are each individually positioned with a domain
#
# Each of these subplot types has a `domain` property with `x`/`y`
# properties.
# Note that this set does not contain `xaxis`/`yaxis` because these behave a
# little differently.


const _single_subplot_types = Set(["scene", "geo", "polar", "ternary", "mapbox"])
const _subplot_types = union(_single_subplot_types, Set(["xy", "domain"]))

# For most subplot types, a trace is associated with a particular subplot
# using a trace property with a name that matches the subplot type. For
# example, a `scatter3d.scene` property set to `'scene2'` associates a
# scatter3d trace with the second `scene` subplot in the figure.
#
# There are a few subplot types that don't follow this pattern, and instead
# the trace property is just named `subplot`.  For example setting
# the `scatterpolar.subplot` property to `polar3` associates the scatterpolar
# trace with the third polar subplot in the figure
const _subplot_prop_named_subplot = Set(["polar", "ternary", "mapbox"])

@with_kw struct SubplotRef
    subplot_kind::String
    layout_keys::Vector{Symbol}
    trace_kwargs::PlotlyAttribute
end

const GridRef = Matrix{Vector{SubplotRef}}

function _get_initial_max_subplot_ids()
    max_subplot_ids = Dict(subplot_kind => 0 for subplot_kind in _single_subplot_types)
    max_subplot_ids["xaxis"] = 0
    max_subplot_ids["yaxis"] = 0
    return max_subplot_ids
end

"""
**Parameters**

- `kind` Subplot type. One of
    - 'xy': 2D Cartesian subplot type for scatter, bar, etc.
    - 'scene': 3D Cartesian subplot for scatter3d, cone, etc.
    - 'polar': Polar subplot for scatterpolar, barpolar, etc.
    - 'ternary': Ternary subplot for scatterternary
    - 'mapbox': Mapbox subplot for scattermapbox
    - 'domain': Subplot type for traces that are individually positioned. pie, parcoords, parcats, etc.

- `secondary_y`: If true, create a secondary y-axis positioned on the right side of the subplot. Only valid if kind="xy".
- `colspan`: number of subplot columns for this subplot to span.
- `rowspan`: number of subplot rows for this subplot to span.
- `l`: padding left of cell
- `r`: padding right of cell
- `t`: padding right of cell
- `b`: padding bottom of cell
"""
@with_kw struct Spec
    kind::String = "xy"
    secondary_y::Bool = false
    colspan::Int = 1
    rowspan::Int = 1
    l::Float64 = 0.0
    r::Float64 = 0.0
    b::Float64 = 0.0
    t::Float64 = 0.0

    @assert !secondary_y || (kind == "xy")
end

"""
**Parameters**

- `cell`: index of the subplot cell to overlay inset axes onto.
- `kind`: Subplot kind (see `Spec` docs)
- `l`: padding left of inset in fraction of cell width
- `w`: inset width in fraction of cell width ('to_end': to cell right edge)
- `b`: padding bottom of inset in fraction of cell height
- `h`: inset height in fraction of cell height ('to_end': to cell top edge)
"""
@with_kw struct Inset
    cell::Tuple{Int,Int} = (1, 1)
    kind::String = "xy"
    colspan::Int = 1
    rowspan::Int = 1
    l::Float64 = 0.0
    w::Union{String,Float64} = "to_end"
    b::Float64 = 0.0
    h::Union{String,Float64} = "to_end"
end

function _check_hv_spacing(dimsize::Int, spacing::Float64, name::String, dimvarname::String)
    spacing < 0 || spacing > 1 && error("$name spacing must be between 0 and 1")
    if dimsize <= 1
        return true
    end
    max_spacing = 1.0 / (dimsize - 1)
    if spacing > max_spacing
        error("$name spacing cannot be greater than 1/($dimvarname - 1) = $max_spacing")
    end
    return true
end


"""
**Parameters**

- `rows`: Number of rows in the subplot grid. Must be greater than zero.
- `cols`: Number of columns in the subplot grid. Must be greater than zero.
- `shared_xaxes`: Assign shared (linked) x-axes for 2D cartesian subplots
    - true or "columns": Share axes among subplots in the same column
    - "rows": Share axes among subplots in the same row
    - "all": Share axes across all subplots in the grid
- `shared_yaxes`: Assign shared (linked) y-axes for 2D cartesian subplots
    - "columns": Share axes among subplots in the same column
    - true or "rows": Share axes among subplots in the same row
    - "all": Share axes across all subplots in the grid.
- `start_cell`:  Choose the starting cell in the subplot grid used to set the domains_grid of the subplots.
    - "top-left": Subplots are numbered with (1, 1) in the top left corner
    - "bottom-left": Subplots are numbererd with (1, 1) in the bottom left corner
- `horizontal_spacing`: Space between subplot columns in normalized plot coordinates. Must be a float between 0 and 1. Applies to all columns (use "specs" subplot-dependents spacing)
- `vertical_spacing`: Space between subplot rows in normalized plot coordinates. Must be a float between 0 and 1. Applies to all rows (use "specs" subplot-dependents spacing)
- `subplot_titles`: Title of each subplot as a list in row-major ordering. Empty strings ("") can be included in the list if no subplot title is desired in that space so that the titles are properly indexed.
- `specs`:  Per subplot specifications of subplot type, row/column spanning, and spacing.
    - The number of rows in "specs" must be equal to "rows".
    - The number of columns in "specs"
    - Each item in the "specs" list corresponds to one subplot
      in a subplot grid. (N.B. The subplot grid has exactly "rows"
      times "cols" cells.)
    - Use missing for a blank a subplot cell (or to move past a col/row span).
    - Each item in "specs" is an instance of `Spec`. See docs for `Spec` for more information
    - Note: Use `horizontal_spacing` and `vertical_spacing` to adjust the spacing in between the subplots.
- `insets`: Inset specifications.  Insets are subplots that overlay grid subplots
    - Each item in "insets" is an instance of `Inset`. See docs for `Inset` for more info
- `column_widths`:  Array of length `cols` of the relative widths of each column of suplots. Values are normalized internally and used to distribute overall width of the figure (excluding padding) among the columns.
- `row_heights`: Array of length `rows` of the relative heights of each row of subplots. Values are normalized internally and used to distribute overall height of the figure (excluding padding) among the rows
- `column_titles`: list of length `cols` of titles to place above the top subplot in each column.
- `row_titles`: list of length `rows` of titles to place on the right side of each row of subplots.
- `x_title`: Title to place below the bottom row of subplots, centered horizontally
- `y_title`: Title to place to the left of the left column of subplots, centered vertically
"""
@with_kw struct Subplots
    rows::Int = 1
    cols::Int = 1
    shared_xaxes::_Maybe{Union{String,Bool}} = false
    shared_yaxes::_Maybe{Union{String,Bool}} = false
    start_cell::String = "top-left"
    subplot_titles::_Maybe{Matrix{<:_Maybe{String}}} = missing
    column_widths::_Maybe{Vector{Float64}} = missing
    row_heights::_Maybe{Vector{Float64}} = missing
    specs::Matrix{<:_Maybe{Spec}} = [Spec() for _ in 1:rows, __ in 1:cols]
    insets::_Maybe{Union{Bool,Vector{Inset}}} = missing
    column_titles::_Maybe{Vector{String}} = missing
    row_titles::_Maybe{Vector{String}} = missing
    x_title::_Maybe{String} = missing
    y_title::_Maybe{String} = missing
    grid_ref::GridRef = let
        gr = GridRef(undef, (rows, cols))
        if rows == 1 && cols == 1
            gr[1, 1] = [SubplotRef(subplot_kind="xy", layout_keys=[:xaxis, :yaxis], trace_kwargs=attr())]
        end
        gr
    end

    # computed
    has_secondary_y::Bool = any(!ismissing(s) && getfield(s, :secondary_y) for s in specs)
    horizontal_spacing::Float64 = has_secondary_y ? 0.4 / cols : 0.2 / cols
    vertical_spacing::Float64 = ismissing(subplot_titles) ? 0.3 / rows : 0.5 / rows
    max_width::Float64 = has_secondary_y ? 0.94 : (ismissing(row_titles) ? 1.0 : 0.98)
    _widths::Vector{Float64} = let
        if ismissing(column_widths)
            fill((max_width - horizontal_spacing * (cols - 1)) / cols, cols)
        else
            w_sum = sum(column_widths)
            [(max_width - horizontal_spacing * (cols - 1)) * (w / w_sum) for w in column_widths]
        end
    end
    _heights::Vector{Float64} = let
        if ismissing(row_heights)
            fill((1.0 - vertical_spacing * (rows - 1)) / rows, rows)
        else
            h_sum = sum(row_heights)
        [(1.0 - vertical_spacing * (rows - 1)) * (h / h_sum) for h in row_heights]
        end
    end

    @assert start_cell in ["top-left", "bottom-left"]
    @assert ismissing(shared_xaxes) || (shared_xaxes in [true, false, "rows", "columns", "all"])
    @assert ismissing(shared_yaxes) || (shared_yaxes in [true, false, "rows", "columns", "all"])
    @assert _check_hv_spacing(cols, horizontal_spacing, "Horizontal", "cols")
    @assert _check_hv_spacing(rows, vertical_spacing, "Vertical", "rows")
    @assert length(_widths) == cols
    @assert length(_heights) == rows
    @assert ismissing(column_titles) || (length(column_titles) == cols)
    @assert ismissing(row_titles) || (length(row_titles) == rows)

end
