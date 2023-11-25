# SPDX-FileCopyrightText: Copyright (c) 2023 Ira Strawser
# SPDX-License-Identifier: MIT

"""Run an ewdk command with correct environment"""

EwdkCommandInfo = provider(
    doc = "Toolchain for running any ewdk command with correct environment set",
    fields = ["command_path", "launch_env"],
)

def _ewdk_command_config_impl(ctx):
    toolchain_info = platform_common.ToolchainInfo(
        idlinfo = EwdkCommandInfo(
            command_path = ctx.executable.command_path,
            launch_env = ctx.attr.launch_env,
        ),
    )
    return toolchain_info

ewdk_command_config = rule(
    implementation = _ewdk_command_config_impl,
    attrs = {
        "command_path": attr.label(
            allow_files = True,
            executable = True,
            cfg = "target",
        ),
        "launch_env": attr.string_dict(default = {}),
    },
)

def _parse_args(cmd):
    args = []
    curarg = []
    state = 0 # 0 = between args, 1 = in quoted arg, 2 = in non-quoted arg
    prev = ''
    
    for _ in range(len(cmd)):
        c, cmd = cmd[:1], cmd[1:]
        if state == 0:
            if c == '"':
                state = 1
                continue
            elif c != ' ':
                state = 2
            else:
                prev = c
                continue

        if (c == '"' and state == 1) or (c == ' ' and state == 2):
            if prev != '`':
                args.append(''.join(curarg))
                state, prev, curarg = 0, c, []
                continue

        if c == '`':
            if prev != '`':
                prev = c
                continue

        curarg.append(c)
        prev = c
    
    return args

def _impl(ctx):
    tc = ctx.toolchains["@ewdk_cc//:ewdk_command_type"].idlinfo

    args = []
    for x in _parse_args(ctx.attr.cmd):
        nx = ctx.expand_location(x, ctx.attr.srcs)
        if nx != x:
            nx = nx.replace("/", "\\")
        args.append(nx)

    ctx.actions.run(
        inputs = ctx.files.srcs,
        outputs = ctx.outputs.outs,
        env = tc.launch_env,
        executable = tc.command_path,
        arguments = args,
        mnemonic = "EwdkCommand",
    )

    return [
        DefaultInfo(files = depset(ctx.outputs.outs)),
    ]

ewdk_command = rule(
    implementation = _impl,
    attrs = {
        "srcs": attr.label_list(
            mandatory = True,
            allow_files = True,
        ),
        "outs": attr.output_list(
            mandatory = True,
            allow_empty = False,
        ),
        "cmd": attr.string(mandatory = True),
    },
    toolchains = ["@ewdk_cc//:ewdk_command_type"],
)
