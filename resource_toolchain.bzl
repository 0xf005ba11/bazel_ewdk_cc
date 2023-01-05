# SPDX-FileCopyrightText: Copyright (c) 2022 Ira Strawser
# SPDX-License-Identifier: MIT

"""Defines a simple toolchain for windows resource scripts"""

ResourceScriptCompilerInfo = provider(
    doc = "Toolchain for windows resource scripts",
    fields = ["rcpath"],
)

def _rc_toolchain_impl(ctx):
    toolchain_info = platform_common.ToolchainInfo(
        rcinfo = ResourceScriptCompilerInfo(
            rcpath = ctx.executable.rcpath,
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
    },
    implementation = _rc_toolchain_impl,
)

def _change_extension(filename, ext):
    offset = filename.rfind(".")
    return filename + ext if offset > 0 else filename[:offset] + ext

def _compile_rc(ctx, rcpath, script, rcopts):
    output = ctx.actions.declare_file(_change_extension(script.rcfile.basename, ".res"))
    
    # the script must be last on the command line
    ctx.actions.run(
        inputs = [script.rcfile],
        outputs = [output],
        executable = rcpath,
        arguments = ["/nologo", "/fo", output.path] + rcopts + [script.rcfile.path],
        mnemonic = "ResourceScript",
    )
    return output

def _resource_script_impl(ctx):
    tc = ctx.toolchains["@ewdk_cc_configured_toolchain//:resource_script_toolchain_type"].rcinfo

    files = [_compile_rc(ctx, tc.rcpath, ctx.file, ctx.attr.rcopts)]
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
    },
    fragments = ["cpp"],
    toolchains = ["@ewdk_cc_configured_toolchain//:resource_script_toolchain_type"],
)
