load(
    "//container:container.bzl",
    _container = "container",
)
load(
    "//container:layer_tools.bzl",
    _get_layers = "get_from_target",
)

def rpms_image(**kwargs):
    _rpms_layer(**kwargs)

def _rpms_impl(ctx, rpms = None):
    rpms = rpms or ctx.files.rpms
    database_updater = ctx.executable._database_updater
    parent_parts = _get_layers(ctx, ctx.label.name, ctx.attr.base)
    uncompressed_blobs = parent_parts.get("unzipped_layer", [])
    uncompressed_layer_args = ["--uncompressed_layer=" + f.path for f in uncompressed_blobs]
    rpm_args = ["--rpm=" + f.path for f in rpms]
    database = ctx.actions.declare_file(ctx.label.name + "-database.tar")
    target = "--output=%s" % database.path
    ctx.actions.run(
        executable = database_updater,
        arguments = rpm_args + uncompressed_layer_args + [target],
        inputs = rpms + uncompressed_blobs,
        outputs = [database],
        use_default_shell_env = True,
        progress_message = "Update the rpm database in the container",
        mnemonic = "updaterpmregistry",
    )
    return _container.image.implementation(ctx, tars = [database])

_rpms_layer = rule(
    attrs = dict(_container.image.attrs.items() + {
        # The dependency whose runfiles we're appending.
        "rpms": attr.label_list(allow_files = True, mandatory = True),
        "_database_updater": attr.label(
            default = Label("//rpms:install_rpms"),
            cfg = "host",
            executable = True,
            allow_files = True,
        ),
    }.items()),
    executable = True,
    outputs = _container.image.outputs,
    toolchains = ["@io_bazel_rules_docker//toolchains/docker:toolchain_type"],
    implementation = _rpms_impl,
)
