# This script gets run once, on a developer's machine, to generate artifacts
using Pkg.Artifacts
using Downloads

function generate_artifacts(ver="2.3.0", repo="https://github.com/sglyon/PlotlyBase.jl")
    artifacts_toml = joinpath(dirname(@__DIR__), "Artifacts.toml")

    # if Artifacts.toml does not exist we also do not have to remove it
    isfile(artifacts_toml) && rm(artifacts_toml)

    plotschema_url = "https://raw.githubusercontent.com/plotly/plotly.js/v$(ver)/dist/plot-schema.json"

    plotlyartifacts_hash = create_artifact() do artifact_dir
        @show artifact_dir
        Downloads.download(plotschema_url, joinpath(artifact_dir, "plot-schema.json"))
        cp(joinpath(dirname(@__DIR__), "templates"), joinpath(artifact_dir, "templates"))
    end

    tarball_hash = archive_artifact(plotlyartifacts_hash, "plotly-base-artifacts-$ver.tar.gz")

    bind_artifact!(artifacts_toml, "plotly-base-artifacts", plotlyartifacts_hash; download_info=[
        ("$repo/releases/download/plotly-base-artifacts-$ver/plotly-base-artifacts-$ver.tar.gz", tarball_hash)
    ])
end
