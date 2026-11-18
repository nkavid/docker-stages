ARCHIVES_ENV = "NKAVID_TOOLCHAIN_ARCHIVES"

def _local_tarball_impl(rctx):
    directory = rctx.getenv(ARCHIVES_ENV)

    if not directory:
        fail("{}: {} is not set; add 'common --repo_env={}=<directory>' to .bazelrc.user".format(
            rctx.name,
            ARCHIVES_ENV,
            ARCHIVES_ENV,
        ))

    archive = rctx.path(directory).get_child(rctx.attr.archive)
    rctx.watch(archive)

    if not archive.exists:
        fail("{}: archive {} does not exist".format(rctx.name, archive))

    download = rctx.download(
        url = "file://{}".format(archive),
        output = "archive.tar",
    )

    if download.sha256 != rctx.attr.sha256:
        fail("{}: sha256 mismatch for {}: declared {}, actual {}".format(
            rctx.name,
            archive,
            rctx.attr.sha256,
            download.sha256,
        ))

    rctx.extract(
        archive = "archive.tar",
        strip_prefix = rctx.attr.strip_prefix,
        watch_archive = "no",
    )
    rctx.delete("archive.tar")
    rctx.file("BUILD.bazel", rctx.read(rctx.attr.build_file))

local_tarball = repository_rule(
    implementation = _local_tarball_impl,
    attrs = {
        "archive": attr.string(mandatory = True),
        "build_file": attr.label(mandatory = True, allow_single_file = True),
        "sha256": attr.string(mandatory = True),
        "strip_prefix": attr.string(),
    },
)
