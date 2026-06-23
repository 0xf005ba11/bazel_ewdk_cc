# SPDX-FileCopyrightText: Copyright (c) 2022 Ira Strawser
# SPDX-License-Identifier: MIT

load("//:ewdk_cc_configure.bzl", "ewdk_cc_autoconf_toolchains")

def _toolchains_impl(ctx):
    # Default to upstream behavior: ewdk_toolchain defaults to :ewdk_cc. A module
    # can opt out with toolchains.configure(default_constraint = False). Last
    # configure tag wins; typically only the root module configures this.
    default_constraint = True
    for mod in ctx.modules:
        for tag in mod.tags.configure:
            default_constraint = tag.default_constraint

    ewdk_cc_autoconf_toolchains(
        name = "ewdk_toolchains",
        default_constraint = default_constraint,
    )

toolchains = module_extension(
    implementation = _toolchains_impl,
    tag_classes = {
        "configure": tag_class(attrs = {
            "default_constraint": attr.bool(
                default = True,
                doc = "If True (default), the ewdk_toolchain constraint_setting " +
                      "defaults every platform to :ewdk_cc.",
            ),
        }),
    },
)
