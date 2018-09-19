_strip_module(s) = split(s, '.', limit=2)[end]
_strip_type_param(s) = replace(s, r"{.+?}" => "")
_clean_name(d::Distributions.Distribution) = _strip_module(_strip_type_param(repr(d)))

function scatter(d::Distributions.ContinuousUnivariateDistribution)
    ls(a, b, c) = range(a, stop=b, length=c)
    x = ls(quantile.([d], [0.01, 0.99])..., 100)
    trace = scatter(x=x, y=pdf.([d], x), name=_clean_name(d))
end

Plot(d::Distributions.UnivariateDistribution...) = Plot(collect(map(scatter, d)))
