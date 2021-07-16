"""
Given the number of rows and columns, return an NTuple{4,Float64} containing
`(width, height, vspace, hspace)`, where `width` and `height` are the
width and height of each subplot and `vspace` and `hspace` are the vertical
and horizonal spacing between subplots, respectively.
"""
function sizes(nr::Int, nc::Int, subplot_titles::Bool=false)
    # NOTE: the logic of this function was mostly borrowed from plotly.py
    dx = 0.2 / nc
    dy = subplot_titles ? 0.55 / nr : 0.3 / nr
    width = (1. - dx * (nc - 1)) / nc
    height = (1. - dy * (nr - 1)) / nr
vspace = nr == 1 ? 0.0 : (1 - height * nr) / (nr - 1)
    hspace = nc == 1 ? 0.0 : (1 - width * nc) / (nc - 1)
    width, height, vspace, hspace
end

function gen_layout(rows::Tuple{Vararg{Int}}, subplot_titles::Bool=false)
    
    x = 0.0  # start from left
    y = 1.0  # start from top

    out = Layout()

    subplot = 1
    nr = length(rows)
    for nc in rows
        w, h, dy, dx = sizes(nr, nc, subplot_titles)
        x = 0.0 # reset x as we start a new row
        for col in 1:nc

            out["xaxis$subplot"] = Dict{Any,Any}(:domain => [x, x + w],
                                                 :anchor => "y$subplot")
            out["yaxis$subplot"] = Dict{Any,Any}(:domain => [y - h, y],
                                                 :anchor => "x$subplot")

            x += nc == 1 ? 0.0 : w + dx
            subplot += 1
         end
         y -= nr == 1 ? 0.0 : h + dy
    end

    out

end

gen_layout(nr::Int, nc::Int, subplot_titles::Bool=false) = gen_layout(tuple(fill(nc, nr)), subplot_titles)


function handle_titles!(big_layout, sub_layout, ix::Int)
    # don't worry about it if the sub_layout doesn't have a title
    if !haskey(sub_layout.fields, "title") && !haskey(sub_layout.fields, :title)
        return big_layout
    end

    # check for symbol or string
    nm = haskey(sub_layout.fields, "title") ? "title" : :title

    ann = Dict{Any,Any}(:font => Dict{Any,Any}(:size => 16),
                        :showarrow => false,
                        :text => pop!(sub_layout.fields, nm),
                        :x => mean(big_layout["xaxis$(ix).domain"]),
                        :xanchor => "center",
                        :xref => "paper",
                        :y => big_layout["yaxis$(ix).domain"][2],
                        :yanchor => "bottom",
                        :yref => "paper")
    anns = get(big_layout.fields, :annotations, Dict{Any,Any}[])
    push!(anns, ann)
    big_layout[:annotations] = anns
    big_layout
end

# plots are 3d if any of their traces have a 3d type. This should flow down
# the methods as ordered here
_is3d(p::Plot) = any(_is3d, p.data)
_is3d(t::GenericTrace) = _is3d(t[:type])
_is3d(t::Symbol) = _is3d(string(t))
_is3d(s::AbstractString) = s in ["surface", "mesh3d", "scatter3d"]

# else (maybe if trace didn't have a :type field set)
_is3d(x::Any) = false

function _cat(rows::Tuple{Vararg{Int}}, ps::Plot...)
    copied_plots = Plot[copy(p) for p in ps]
    subplot_titles = any(map(x -> haskey(x.layout.fields, :title) ||
                                  haskey(x.layout.fields, "title"), ps))
    layout = gen_layout(rows, subplot_titles)

    for ix in 1:sum(rows)
        handle_titles!(layout, copied_plots[ix].layout, ix)
        layout["xaxis$ix"] = merge(copied_plots[ix].layout["xaxis"], layout["xaxis$ix"])
        layout["yaxis$ix"] = merge(copied_plots[ix].layout["yaxis"], layout["yaxis$ix"])

        if _is3d(copied_plots[ix])
            # need to move (x|y)axis$ix into scene$ix here
            layout["scene$ix"] = attr(
                xaxis=pop!(layout, "xaxis$(ix)"),
                yaxis=pop!(layout, "yaxis$(ix)")
            )
            for trace in copied_plots[ix].data
                trace["scene"] = "scene$ix"
            end
        else
            for trace in copied_plots[ix].data
                trace["xaxis"] = "x$ix"
                trace["yaxis"] = "y$ix"
end
        end

    end

    Plot(vcat([p.data for p in copied_plots]...), layout)
end

_cat(nr::Int, nc::Int, ps::Plot...) = _cat(Tuple(fill(nc, nr)), ps...)

Base.hcat(ps::Plot...) = _cat(1, length(ps), ps...)
Base.vcat(ps::Plot...) = _cat(length(ps), 1,  ps...)

Base.hvcat(rows::Tuple{Vararg{Int}}, ps::Plot...) = _cat(rows, ps...)


# implementation of algorithms from plotly.py/packages/python/plotly/plotly/subplots.py

function _init_subplot_xy!(
        layout::Layout, secondary_y::Bool, domain::NamedTuple{(:x, :y)}, max_subplot_ids::Dict
    )
    # Get axis label and anchor
    x_count = max_subplot_ids["xaxis"] + 1
    y_count = max_subplot_ids["xaxis"] + 1

    # Compute x/y labels (the values of trace.xaxis/trace.yaxis
    x_label = "x$(x_count > 1 ? x_count : "")"
    y_label = "y$(y_count > 1 ? y_count : "")"

    # Anchor x and y axes to each other
    x_anchor, y_anchor = y_label, x_label

    # Build layout.xaxis/layout.yaxis containers
    xaxis_name = "xaxis$(x_count > 1 ? x_count : "")"
    yaxis_name = "yaxis$(y_count > 1 ? y_count : "")"
    x_axis = attr(domain=domain.x, anchor=x_anchor)
    y_axis = attr(domain=domain.y, anchor=y_anchor)
    layout[xaxis_name] = x_axis
    layout[yaxis_name] = y_axis

    subplot_refs = [
        SubplotRef(
            subplot_kind="xy",
            layout_keys=Symbol.([xaxis_name, yaxis_name]),
            trace_kwargs=attr(xaxis=x_label, yaxis=y_label)
        )
    ]

    if secondary_y
        y_count += 1
        secondary_yaxis_name = "yaxis$(y_count > 1 ? y_count : "")"
        secondary_y_label = "y$(y_count > 1 ? y_count : "")"
        push!(
            subplot_refs,
            SubplotRef(
                subplot_kind="xy",
                layout_keys=Symbol.([xaxis_name, secondary_yaxis_name]),
                trace_kwargs=attr(xaxis=x_label, yaxis=secondary_y_label),
            )
        )
        secondary_y_axis = attr(anchor=y_anchor, overlaying=y_label, side="right")
        layout[secondary_yaxis_name] = secondary_y_axis
    end

    max_subplot_ids["xaxis"] = x_count
    max_subplot_ids["yaxis"] = y_count

    subplot_refs
end

function _init_subplot_single!(
        layout::Layout, subplot_kind::String, domain::NamedTuple{(:x, :y)}, max_subplot_ids::Dict
    )
    count = max_subplot_ids[subplot_kind] + 1
    label = "$(subplot_kind)$(count > 1 ? count : "")"
scene = attr(domain=attr(;domain...))
    layout[label] = scene

    trace_key = subplot_kind in _subplot_prop_named_subplot ? "subplot" : subplot_kind
    subplot_ref = SubplotRef(
        subplot_kind=subplot_kind,
        layout_keys=[Symbol(label)],
        trace_kwargs=attr(;Dict(Symbol(trace_key) => label)...)
    )
    max_subplot_ids[subplot_kind] = count
    [subplot_ref]
end

function _init_subplot_domain!(domain::NamedTuple{(:x, :y)})
    [SubplotRef(
        subplot_kind="domain",
        layout_keys=[],
        trace_kwargs=attr(domain=attr(;domain...))
    )]
end

function _init_subplot!(
        layout::Layout, subplot_kind::String, secondary_y::Bool,
        domain::NamedTuple{(:x, :y)}, max_subplot_ids::Dict
    )
    if subplot_kind == "xy"
        return _init_subplot_xy!(layout, secondary_y, domain, max_subplot_ids)
    elseif subplot_kind in _single_subplot_types
        return _init_subplot_single!(layout, subplot_kind, domain, max_subplot_ids)
    elseif subplot_kind == "domain"
        return _init_subplot_domain!(domain)
    end
    error("Unknown subplot_kind $subplot_kind")
end

function _configure_shared_axes!(layout::Layout, grid_ref::Matrix, specs::Matrix{<:_Maybe{Spec}}, x_or_y::String, shared::Union{Bool,String}, row_dir::Int)
    rows, cols = size(grid_ref)

    layout_key_ind = x_or_y == "x" ? 1 : 2

    rows_iter = collect(1:rows)
    row_dir < 0 && reverse!(rows_iter)

    function update_axis_matches!(
            first_axis_id, subplot_ref::SubplotRef, spec::Spec, remove_label::Bool
        )
        span = x_or_y == "x" ? spec.colspan : spec.rowspan

        if subplot_ref.subplot_kind == "xy" && span == 1
            if ismissing(first_axis_id)
                first_axis_name = subplot_ref.layout_keys[layout_key_ind]
                first_axis_id = replace(String(first_axis_name), "axis" => "")
            else
                axis_name = subplot_ref.layout_keys[layout_key_ind]
                axis_to_match = layout[axis_name]
                axis_to_match[:matches] = first_axis_id
                if remove_label
                    axis_to_match[:showticklabels] = false
                end
            end
        end
        return first_axis_id
    end

    if shared == "columns" || (x_or_y == "x" && shared == true)
        for c in 1:cols
            first_axis_id = missing
            ok_to_remove_label = x_or_y == "x"
            for r in rows_iter
                subplot_ref = grid_ref[r, c][1]
                spec = specs[r, c]
                first_axis_id = update_axis_matches!(
                    first_axis_id, subplot_ref, spec, ok_to_remove_label
                )
            end
        end
    elseif shared == "rows" || (x_or_y == "y" && shared == true)
        for r in rows_iter
            first_axis_id = missing
            ok_to_remove_label = x_or_y == "y"
            for c in 1:cols
                subplot_ref = grid_ref[r, c][1]
                spec = specs[r, c]
                first_axis_id = update_axis_matches!(
                    first_axis_id, subplot_ref, spec, ok_to_remove_label
                )
            end
        end
    elseif shared == "all"
        first_axis_id = missing
        for c in 1:cols, (ri, r) in enumerate(rows_iter)
            subplot_ref = grid_ref[r, c][1]
            spec = specs[r, c]
            ok_to_remove_label = let
                if x_or_y == "y"
                    c > 0
                else
                    row_dir > 0 ? ri > 0 : r < rows
                end
            end
            first_axis_id = update_axis_matches!(
                first_axis_id, subplot_ref, spec, ok_to_remove_label
            )
        end
    end
end

_build_subplot_title_annotations(::Missing, list_of_domains; kw...) = []

function _build_subplot_title_annotations(
        subplot_titles::Array{<:_Maybe{String}},
        list_of_domains::Vector{<:NamedTuple{(:x, :y)}};
        title_edge="top", offset=0
    )
    # If shared_axes is false (default) use list_of_domains
    # This is used for insets and irregular layouts
    # if not shared_xaxes and not shared_yaxes:
    x_dom = [dom.x for dom in list_of_domains]
    y_dom = [dom.y for dom in list_of_domains]
    subtitle_pos_x = []
    subtitle_pos_y = []


    if title_edge == "top"
        text_angle = 0
        xanchor = "center"
        yanchor = "bottom"

        for x_domains in x_dom
            push!(subtitle_pos_x, sum(x_domains) / 2)
        end
        for y_domains in y_dom
            push!(subtitle_pos_y, y_domains[2])
        end
        yshift = offset
        xshift = 0
    elseif title_edge == "bottom"
        text_angle = 0
        xanchor = "center"
        yanchor = "top"

        for x_domains in x_dom
            push!(subtitle_pos_x, sum(x_domains) / 2)
        end
        for y_domains in y_dom
            push!(subtitle_pos_y, y_domains[1])
        end
        yshift = -offset
        xshift = 0
    elseif title_edge == "right"
        text_angle = 90
        xanchor = "left"
        yanchor = "middle"

        for x_domains in x_dom
            push!(subtitle_pos_x, x_domains[2])
        end
        for y_domains in y_dom
            push!(subtitle_pos_y, sum(y_domains) / 2.0)
        end
        yshift = 0
        xshift = offset
    elseif title_edge == "left"
        text_angle = -90
        xanchor = "right"
        yanchor = "middle"

        for x_domains in x_dom
            push!(subtitle_pos_x, x_domains[1])
        end
        for y_domains in y_dom
            push!(subtitle_pos_y, sum(y_domains) / 2.0)
        end
        yshift = 0
        xshift = -offset
    else
        error("title_edge must be one of [top, bottom, left, right]")
    end

    plot_titles = []
    for index in 1:length(subplot_titles)
        title = subplot_titles[index]
        should_continue = (
            ismissing(title) || title == false || length(title) == 0 ||
            index > length(subtitle_pos_y)
        )
        if should_continue
            continue
        end
        annotation = attr(
            y=subtitle_pos_y[index], yref="paper", yanchor=yanchor,
            x=subtitle_pos_x[index], xref="paper", xanchor=xanchor,
            text=title, font_size=16,
            showarrow=false,
        )
        xshift != 0 && setindex!(annotation, xshift, :xshift)
        yshift != 0 && setindex!(annotation, yshift, :yshift)
        text_angle != 0 && setindex!(annotation, text_angle, :textangle)
        push!(plot_titles, annotation)
    end
    plot_titles
end

function Layout(sp::Subplots; kw...)
    layout = Layout(;kw...)

    @unpack_Subplots sp

    row_dir = start_cell == "top-left" ? -1 : 1

    col_seq = collect(1:cols) .- 1
    row_seq = collect(1:rows) .- 1
    row_dir < 0 && reverse!(row_seq)

    grid = [
        (
            sum(_widths[1:c]) + c * horizontal_spacing,
            sum(_heights[1:r]) + r * vertical_spacing
        )
        for r in row_seq, c in col_seq
    ]
    domains_grid = _Maybe{NamedTuple{(:x, :y)}}[missing for _ in 1:rows, __ in 1:cols]
    list_of_domains = NamedTuple{(:x, :y)}[]
    max_subplot_ids = _get_initial_max_subplot_ids()

    for r in 1:rows, c in 1:cols
        spec = specs[r, c]
        if ismissing(spec)
            continue
        end
        c_spanned = c + spec.colspan - 1
        r_spanned = r + spec.rowspan - 1

        c_spanned > cols && error("Some colspan value is too large for this subplot grid")
        r_spanned > rows && error("Some rowspan value is too large for this subplot grid")

        # grid x c_spanned -> x_domain
        x_s = grid[r, c][1]
        x_e = grid[r, c_spanned][1] + _widths[c_spanned] - spec.r
        x_domain = (max(0.0, x_s), min(1.0, x_e))

        # grid x r_spanned x row_dir -> yaxis_domain
        y_domain = let
            if row_dir > 1
                (grid[r, c][2] + spec.b, grid[r_spanned, c][2] + _heights[r_spanned] - spec.t)
            else
                (grid[r_spanned, c][2], grid[r, c][2] + _heights[end - r + 1] - spec.t)
            end
        end
        domain = (x = x_domain, y = y_domain)
        domains_grid[r, c] = domain

        push!(list_of_domains, domain)

        grid_ref[r, c] = _init_subplot!(layout, spec.kind, spec.secondary_y, domain, max_subplot_ids)

    end

    _configure_shared_axes!(layout, grid_ref, specs, "x", shared_xaxes, row_dir)
    _configure_shared_axes!(layout, grid_ref, specs, "y", shared_yaxes, row_dir)

    # handle insets

    insets_ref = ismissing(insets) ? missing : Any[missing for _ in 1:length(insets)]
    if !ismissing(insets)
        for (i_inset, inset) in enumerate(insets)
            r = inset.cell[1]
            c = inset.cell[2]

            0 <= r <= rows || error("Some `cell` out of range")
            0 <= c <= cols || error("Some `cell` out of range")

            x_s = grid[r, c][1] + inset.l * _widths[c]
            x_e = inset.w == "to_end" ? grid[r, c][1] + _widths[c] : (x_s + inset.w * _widths[c])
            x_domain = (x_s, x_e)

            y_s = grid[r, c][2] + inset.b * _heights[end - r + 1]
            y_e = inset.h == "to_end" ? (grid[r, c][2] + _heights[end - r + 1]) : (y_s + inset.h * _heights[end - r + 1])
            y_domain = (y_s, y_e)
            domain = (x = x_domain, y = y_domain)

            push!(list_of_domains, domain)

            insets_ref[i_inset] = _init_subplot!(
                layout, inset.kind, false, domain, max_subplot_ids
            )
        end
    end

    plot_title_annotations = _build_subplot_title_annotations(
        subplot_titles, list_of_domains
    )
    layout[:annotations] = plot_title_annotations

    if !ismissing(column_titles)
        domains_list = let
            if row_dir > 0
                [domains_grid[end, c] for c in 1:cols]
            else
                [domains_grid[1, c] for c in 1:cols]
            end
        end
        append!(
            layout[:annotations],
            _build_subplot_title_annotations(column_titles, domains_list)
        )
    end

    if !ismissing(row_titles)
        domains_list = [domains_grid[r, end] for r in 1:rows]
        append!(
            layout[:annotations],
            _build_subplot_title_annotations(row_titles, domains_list, title_edge="right")
        )
    end

    if !ismissing(x_title)
        domains_list = [(x = (0, max_width), y = (0, 1))]
        append!(
            layout[:annotations],
            _build_subplot_title_annotations(
                [x_title], domains_list, title_edge="bottom", offset=30
            )
        )
    end
    if !ismissing(y_title)
        domains_list = [(x = (0, 1), y = (0, 1))]
        append!(
            layout[:annotations],
            _build_subplot_title_annotations(
                [y_title], domains_list, title_edge="left", offset=40
            )
        )
    end
    layout.subplots = sp
    layout
end
