# SPDX-FileCopyrightText: Copyright (c) 2023 Ira Strawser
# SPDX-License-Identifier: MIT

"""Defines a simple toolchain for windows IDL source files"""

IdlCompilerInfo = provider(
    doc = "Toolchain for windows IDL source files",
    fields = ["midl_path", "msvc_env_app", "msvc_env_wdm", "arch_opts"],
)

def _idl_toolchain_config_impl(ctx):
    toolchain_info = platform_common.ToolchainInfo(
        idlinfo = IdlCompilerInfo(
            midl_path = ctx.executable.midl_path,
            msvc_env_app = ctx.attr.msvc_env_app,
            msvc_env_wdm = ctx.attr.msvc_env_wdm,
            arch_opts = ctx.attr.arch_opts,
        ),
    )
    return toolchain_info

idl_toolchain_config = rule(
    implementation = _idl_toolchain_config_impl,
    attrs = {
        "midl_path": attr.label(
            allow_files = True,
            executable = True,
            cfg = "target",
        ),
        "msvc_env_app": attr.string_dict(default = {}),
        "msvc_env_wdm": attr.string_dict(default = {}),
        "arch_opts": attr.string_list(default = []),
    },
)

def _build_feature_flags(ctx):
    features = {}
    for feat in ctx.features:
        features[feat] = 1
    if not features.get("opt") and not features.get("dbg") and not features.get("fastbuild"):
        features[ctx.var.get("COMPILATION_MODE")] = 1

    ret = []
    target = None
    for feature in features.keys():
        if feature == "dbg" or feature == "fastbuild":
            ret += ["/DDEPRECATE_DDK_FUNCTIONS=1", "/DMSC_NOOPT"]
        elif feature == "target_win7":
            target = ["/DNTDDI_VERSION=0x06010000", "/D_WIN32_WINNT=0x0601", "/target", "NT61"]
        elif feature == "target_win8":
            target = ["/DNTDDI_VERSION=0x06020000", "/D_WIN32_WINNT=0x0602", "/target", "NT62"]
        elif feature == "target_win10":
            target = ["/DNTDDI_VERSION=0x0A000000", "/D_WIN32_WINNT=0x0A00", "/target", "NT100"]
        elif feature == "target_win11":
            target = ["/DNTDDI_VERSION=0x0A00000C", "/D_WIN32_WINNT=0x0A00", "/target", "NT100"]
    if not target:
        target = ["/DNTDDI_VERSION=0x06010000", "/D_WIN32_WINNT=0x0601", "/target", "NT61"]
    return ret + target

def _compile_idl(ctx, tc, input):
    basename = input.basename[:-(len(input.extension) + 1)]
    header = basename + ".h"

    if ctx.attr.client:
        basename += "_client"
    else:
        basename += "_server"

    iid = basename + "_i.c"
    proxy = basename + "_p.c"
    tlb = basename + ".tlb"

    output = basename + "_c.c" if ctx.attr.client else basename + "_s.c"
    output_hdr = ctx.actions.declare_file(header)
    output_src = ctx.actions.declare_file(output)
    outdir = output_src.dirname.replace("/", "\\")

    env = tc.msvc_env_wdm if ctx.attr.kernel else tc.msvc_env_app
    includes = ["/I" + x.replace("/", "\\") for x in env["INCLUDE"].split(";") if x]
    includes.append("/I" + outdir)

    default_opts = _build_feature_flags(ctx) + [
        "/D_WCHAR_T_DEFINED",
        "/D_USE_DECLSPECS_FOR_SAL=1",
        "/W1",
        "/nologo",
        "/char",
        "unsigned",
        "/h",
        header,
        "/cstub",
        basename + "_c.c",
        "/sstub",
        basename + "_s.c",
        "/dlldata",
        "dlldata.c",
        "/iid",
        iid,
        "/proxy",
        proxy,
        "/tlb",
        tlb,
        "/Zp8",
        "/sal",
        "/no_stamp",
        "/out" + outdir
    ]

    args = []
    if not ctx.attr.disable_arch_opts:
        args += tc.arch_opts
    if not ctx.attr.disable_default_includes:
        args += includes
    if not ctx.attr.disable_default_opts:
        args += default_opts
    args += ctx.attr.opts
    args.append(input.path.replace("/", "\\"))

    ctx.actions.run(
        inputs = [input],
        outputs = [output_src, output_hdr],
        env = env,
        executable = tc.midl_path,
        arguments = args,
        mnemonic = "MidlCompile",
    )

    return {
        "header": output_hdr,
        "src": output_src,
    }

def _impl(ctx):
    tc = ctx.toolchains["@ewdk_cc_configured_toolchain//:idl_toolchain_type"].idlinfo

    inputs = []
    for x in ctx.attr.srcs:
        inputs += x.files.to_list()

    headers = []
    srcs = []
    for inp in inputs:
        outs = _compile_idl(ctx, tc, inp)
        headers.append(outs["header"])
        srcs.append(outs["src"])

    incdirs = {}
    for hdr in headers:
        incdirs[hdr.dirname] = True
    incdirs = incdirs.keys()

    return [
        DefaultInfo(files = depset(headers + srcs)),
        CcInfo(compilation_context = cc_common.create_compilation_context(
            quote_includes = depset(incdirs),
            headers = depset(headers),
        )),
    ]

idl_script = rule(
    implementation = _impl,
    attrs = {
        "srcs": attr.label_list(
            mandatory = True,
            allow_files = True,
        ),
        "client": attr.bool(mandatory = True),
        "kernel": attr.bool(default = False),
        "opts": attr.string_list(default = []),
        "disable_default_includes": attr.bool(default = False),
        "disable_default_opts": attr.bool(default = False),
        "disable_arch_opts": attr.bool(default = False),
    },
    toolchains = ["@ewdk_cc_configured_toolchain//:idl_toolchain_type"],
)
