using Pkg.Artifacts, ghr_jll
using Pkg.BinaryPlatforms
import ZipFile

release_tag = "v0.5.0"

const PLATFORMS = Dict(
    Linux(:aarch64) => "linux_arm64",
    Linux(:x86_64) => "linux_x64",
    MacOS(:x86_64) => "mac",
    Windows(:x86_64) => "win_x64",
    Windows(:i686) => "win_x86",
)

artifact_toml = joinpath(@__DIR__, "Artifacts.toml")

function unzip(zf_path, dest_path)
    r = ZipFile.Reader(zf_path)
    k_path = joinpath(dest_path, "kaleido")
    rm(k_path , force=true, recursive=true)
    mkdir(k_path)
    for f in r.files
        @show f
        out_path = joinpath(dest_path, f.name)
        if (endswith(f.name, "/") || endswith(f.name, "\\"))
            !isdir(out_path) && mkdir(out_path)
        else
            parent_dir = joinpath(dest_path, dirname(f.name))
            if !isdir(parent_dir)
                mkpath(parent_dir)
            end
            v = Vector{UInt8}(undef, f.uncompressedsize)
            read!(f, v)
            write(out_path, v)
        end
    end
    close(r)
end

function _download_os_arch(k_platform=platform_key_abi())
    keys_platforms = keys(PLATFORMS) |> collect
    os_arch = findfirst(x->platforms_match(x, k_platform), keys_platforms)
    if !isnothing(os_arch)
        return PLATFORMS[keys_platforms[os_arch]]
    end
    str_platforms = join(string.(keys_platforms), ", ", " and ")
    error("Only $(str_platforms) are supported")
end

function download_kaleido(k_dir, os_arch=_download_os_arch())
    url = "https://github.com/plotly/Kaleido/releases/download/v0.1.0/kaleido_$os_arch.zip"
    dest = joinpath(k_dir, "kaleido.zip")
    download(url, dest)
    unzip(dest, k_dir)
    rm(dest)  # remove zip file
    if Sys.isunix() && any(contains.(os_arch, ["mac", "linux"]))
        ex1_path = joinpath(k_dir, "kaleido", "kaleido")
        run(`chmod +x $ex1_path`)

        ex2_path = joinpath(k_dir, "kaleido", "bin", "kaleido")
        run(`chmod +x $ex2_path`)
    end
    return
end

for platform in keys(PLATFORMS)
# for platform in [MacOS(:x86_64)]
    @show platform
    kaleido_hash = artifact_hash("kaleido", artifact_toml, platform=platform)
    # If the name was not bound, or the hash it was bound to does not exist, create it!
    if kaleido_hash === nothing || !artifact_exists(kaleido_hash)
        # create_artifact() returns the content-hash of the artifact directory once we're finished creating it
        kaleido_hash = create_artifact() do k_dir
            download_kaleido(k_dir, _download_os_arch(platform))
        end
    end

    local tarball_hash
    gz_name = "kaleido_$(_download_os_arch(platform)).tar.gz"
    mktempdir() do dir
        gz_path = joinpath(dir, gz_name)
        tarball_hash = archive_artifact(kaleido_hash, gz_path)
        ghr() do ghr
            run(`$(ghr) -u sglyon -r PlotlyBase.jl -replace $(release_tag) $(gz_path)`)
        end
    end
    bind_artifact!(
        artifact_toml,
        "kaleido",
        kaleido_hash;
        platform=platform,
        force=true,
        download_info = [
            ("https://github.com/sglyon/PlotlyBase.jl/releases/download/$(release_tag)/$(gz_name)", tarball_hash),
        ],
    )
end
