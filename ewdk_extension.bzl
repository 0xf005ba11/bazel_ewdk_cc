# SPDX-FileCopyrightText: Copyright (c) 2022 Ira Strawser
# SPDX-License-Identifier: MIT

load("//:ewdk_cc_configure.bzl", "ewdk_cc_autoconf_toolchains")

toolchains = module_extension(
    implementation = lambda ctx: ewdk_cc_autoconf_toolchains(name = "ewdk_toolchains")
)
