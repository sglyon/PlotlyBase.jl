using Distributions

@require Revise="295af30f-e4ad-537b-8983-00126c2a3abe" begin
    Revise.track(PlotlyBase, @__FILE__)
end

_strip_module(s) = split(s, '.', limit=2)[end]
_strip_type_param(s) = replace(s, r"{.+?}" => "")
_clean_name(d::Distribution) = _strip_module(_strip_type_param(repr(d)))

function scatter(d::Distributions.ContinuousUnivariateDistribution)
    x = linspace(quantile.(d, [0.01, 0.99])..., 100)
    trace = scatter(x=x, y=pdf.(d, x), name=_clean_name(d))
end

Plot(d::Distributions.UnivariateDistribution...) = Plot(collect(map(scatter, d)))
