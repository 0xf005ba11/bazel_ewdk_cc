# SPDX-FileCopyrightText: Copyright (c) 2023 Ira Strawser
# SPDX-License-Identifier: MIT

"""Defines a simple toolchain for windows WPP tracing"""

WppCompilerInfo = provider(
    doc = "Toolchain for windows WPP tracing",
    fields = ["tracewpp_path", "env", "cfgdir"],
)

def _wpp_toolchain_config_impl(ctx):
    toolchain_info = platform_common.ToolchainInfo(
        wppinfo = WppCompilerInfo(
            tracewpp_path = ctx.executable.tracewpp_path,
            env = ctx.attr.env,
            cfgdir = ctx.attr.cfgdir,
        ),
    )
    return toolchain_info

wpp_toolchain_config = rule(
    implementation = _wpp_toolchain_config_impl,
    attrs = {
        "tracewpp_path": attr.label(
            allow_files = True,
            executable = True,
            cfg = "target",
        ),
        "env": attr.string_dict(default = {}),
        "cfgdir": attr.string(),
    },
)

def _compile_wpp(ctx, tc, cfg, input, output):
    output_file = ctx.actions.declare_file(output)
    raw_path = output_file.path.replace("/", "\\")
    args = [
        raw_path[:-len(output_file.extension)],
        raw_path,
        "-scan:" + cfg.path.replace("/", "\\"),
        "-cfgdir:" + tc.cfgdir,
        "-odir:" + output_file.dirname.replace("/", "\\") + "\\",
    ]
    if ctx.attr.kernel:
        args.append("-km")
    elif ctx.attr.dll:
        args.append("-dll")
    args.append(input.path.replace("/", "\\"))

    ctx.actions.run(
        inputs = [cfg, input],
        outputs = [output_file],
        env = tc.env,
        executable = tc.tracewpp_path,
        arguments = args,
        mnemonic = "WppTraceHeader",
    )

    return output_file

def _impl(ctx):
    tc = ctx.toolchains["@ewdk_cc//:wpp_toolchain_type"].wppinfo

    inputs = []
    for x in ctx.attr.srcs:
        inputs += x.files.to_list()
    outputs = []
    for inp in inputs:
        name = inp.basename
        index = name.rfind(".")
        if index != -1:
            name = name[:index]

        # tracewpp.exe will only emit .tmh files and cc_binary won't recognize these.
        # the wrapper batch file will copy the .tmh to the .h to satisfy bazel
        outputs.append(name + ".tmh.h")

    files = [ctx.file.cfghdr]
    for i in range(len(inputs)):
        files.append(_compile_wpp(ctx, tc, ctx.file.cfghdr, inputs[i], outputs[i]))

    incdirs = {ctx.file.cfghdr.dirname: True}
    for file in files:
        incdirs[file.dirname] = True
    incdirs = incdirs.keys()

    return [
        DefaultInfo(files = depset(files)),
        CcInfo(compilation_context = cc_common.create_compilation_context(
            quote_includes = depset(incdirs),
            headers = depset(files),
        )),
    ]

wpp_trace = rule(
    implementation = _impl,
    attrs = {
        "cfghdr": attr.label(
            mandatory = True,
            allow_single_file = True,
        ),
        "srcs": attr.label_list(
            mandatory = True,
            allow_files = True,
        ),
        "kernel": attr.bool(default = False),
        "dll": attr.bool(default = False),
    },
    fragments = ["c", "cpp"],
    toolchains = ["@ewdk_cc//:wpp_toolchain_type"],
)
