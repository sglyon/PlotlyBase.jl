module DistributionsExt

isdefined(Base, :get_extension) ? (using Distributions) : (using ..Distributions)
using PlotlyBase

_strip_module(s) = split(s, '.', limit=2)[end]
_strip_type_param(s) = replace(s, r"{.+?}" => "")
_clean_name(d::Distributions.Distribution) = _strip_module(_strip_type_param(repr(d)))

function PlotlyBase.scatter(d::Distributions.ContinuousUnivariateDistribution)
    ls(a, b, c) = range(a, stop=b, length=c)
    x = ls(Distributions.quantile.([d], [0.01, 0.99])..., 100)
    trace = scatter(x=x, y=Distributions.pdf.([d], x), name=_clean_name(d))
end

PlotlyBase.Plot(d::Distributions.UnivariateDistribution...) = Plot(collect(map(scatter, d)))

end
