# SPDX-FileCopyrightText: Copyright (c) 2022 Ira Strawser
# SPDX-License-Identifier: MIT

"""Defines a simple toolchain for windows resource scripts"""

ResourceScriptCompilerInfo = provider(
    doc = "Toolchain for windows resource scripts",
    fields = ["rcpath", "env", "defines"],
)

def _rc_toolchain_impl(ctx):
    toolchain_info = platform_common.ToolchainInfo(
        rcinfo = ResourceScriptCompilerInfo(
            rcpath = ctx.executable.rcpath,
            env = ctx.attr.env,
            defines = ctx.attr.defines,
        ),
    )
    return toolchain_info

resource_script_toolchain_config = rule(
    attrs = {
        "rcpath": attr.label(
            allow_files = True,
            executable = True,
            cfg = "target",
        ),
        "env": attr.string_dict(default = {}),
        "defines": attr.string_list(default = []),
    },
    implementation = _rc_toolchain_impl,
)

def _build_feature_flags(ctx):
    features = {}
    for feat in ctx.features:
        features[feat] = 1
    if not features.get("opt") and not features.get("dbg") and not features.get("fastbuild"):
        features[ctx.var.get("COMPILATION_MODE")] = 1

    ret = []
    for feature in features.keys():
        if feature == "opt":
            ret.append("/DNDEBUG")
        elif feature == "dbg" or feature == "fastbuild":
            ret += ["/D_DEBUG", "/DDBG=1"]
    return ret

def _compile_rc(ctx, tc):
    output = ctx.actions.declare_file(ctx.file.rcfile.basename + ".res")

    inputs = [ctx.file.rcfile]
    for x in ctx.attr.deps:
        inputs += x.files.to_list()

    feature_flags = _build_feature_flags(ctx)

    # the script must be last on the command line
    ctx.actions.run(
        inputs = inputs,
        outputs = [output],
        env = tc.env,
        executable = tc.rcpath,
        arguments = ["/nologo", "/fo", output.path, "/I."] + tc.defines + ctx.attr.rcopts + feature_flags + [ctx.file.rcfile.path],
        mnemonic = "ResourceScript",
    )
    return output

def _resource_script_impl(ctx):
    tc = ctx.toolchains["@ewdk_cc//:resource_script_toolchain_type"].rcinfo

    files = [_compile_rc(ctx, tc)]
    linker_input = cc_common.create_linker_input(
        owner = ctx.label,
        additional_inputs = depset(files),
        user_link_flags = depset([res.path for res in files]),
    )
    linker_ctx = cc_common.create_linking_context(linker_inputs = depset([linker_input]))
    return [
        DefaultInfo(files = depset(files)),
        CcInfo(linking_context = linker_ctx),
    ]

resource_script = rule(
    implementation = _resource_script_impl,
    attrs = {
        "rcfile": attr.label(
            mandatory = True,
            allow_single_file = [".rc"],
        ),
        "rcopts": attr.string_list(default = []),
        "deps": attr.label_list(allow_files = True),
    },
    fragments = ["cpp"],
    toolchains = ["@ewdk_cc//:resource_script_toolchain_type"],
)
