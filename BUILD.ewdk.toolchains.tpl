# SPDX-FileCopyrightText: Copyright (c) 2022 Ira Strawser
# SPDX-License-Identifier: MIT

"""ewdk_cc toolchains"""

load("@rules_cc//cc:defs.bzl", "cc_toolchain")
load(":ewdk_cc_configure.bzl", "ewdk_cc_toolchain_config")
load(":resource_toolchain.bzl", "resource_script_toolchain_config")

filegroup(
    name = "empty",
    srcs = [],
)

_MSVC_ENV_WDM_X86 = {
    "PATH": "%{msvc_env_path_wdm_x86}",
    "INCLUDE": "%{msvc_env_include_wdm_x86}",
    "EXTERNAL_INCLUDE": "%{msvc_env_external_include_wdm_x86}",
    "LIBPATH": "%{msvc_env_libpath_wdm_x86}",
    "LIB": "%{msvc_env_lib_wdm_x86}",
    "TMP": "%{msvc_env_tmp}",
}

_MSVC_ENV_APP_X86 = {
    "PATH": "%{msvc_env_path_app_x86}",
    "INCLUDE": "%{msvc_env_include_app_x86}",
    "EXTERNAL_INCLUDE": "%{msvc_env_external_include_app_x86}",
    "LIBPATH": "%{msvc_env_libpath_app_x86}",
    "LIB": "%{msvc_env_lib_app_x86}",
    "TMP": "%{msvc_env_tmp}",
}

_MSVC_ENV_WDM_X64 = {
    "PATH": "%{msvc_env_path_wdm_x64}",
    "INCLUDE": "%{msvc_env_include_wdm_x64}",
    "EXTERNAL_INCLUDE": "%{msvc_env_external_include_wdm_x64}",
    "LIBPATH": "%{msvc_env_libpath_wdm_x64}",
    "LIB": "%{msvc_env_lib_wdm_x64}",
    "TMP": "%{msvc_env_tmp}",
}

_MSVC_ENV_APP_X64 = {
    "PATH": "%{msvc_env_path_app_x64}",
    "INCLUDE": "%{msvc_env_include_app_x64}",
    "EXTERNAL_INCLUDE": "%{msvc_env_external_include_app_x64}",
    "LIBPATH": "%{msvc_env_libpath_app_x64}",
    "LIB": "%{msvc_env_lib_app_x64}",
    "TMP": "%{msvc_env_tmp}",
}

_MSVC_ENV_WDM_ARM = {
    "PATH": "%{msvc_env_path_wdm_arm}",
    "INCLUDE": "%{msvc_env_include_wdm_arm}",
    "EXTERNAL_INCLUDE": "%{msvc_env_external_include_wdm_arm}",
    "LIBPATH": "%{msvc_env_libpath_wdm_arm}",
    "LIB": "%{msvc_env_lib_wdm_arm}",
    "TMP": "%{msvc_env_tmp}",
}

_MSVC_ENV_APP_ARM = {
    "PATH": "%{msvc_env_path_app_arm}",
    "INCLUDE": "%{msvc_env_include_app_arm}",
    "EXTERNAL_INCLUDE": "%{msvc_env_external_include_app_arm}",
    "LIBPATH": "%{msvc_env_libpath_app_arm}",
    "LIB": "%{msvc_env_lib_app_arm}",
    "TMP": "%{msvc_env_tmp}",
}

_MSVC_ENV_WDM_ARM64 = {
    "PATH": "%{msvc_env_path_wdm_arm64}",
    "INCLUDE": "%{msvc_env_include_wdm_arm64}",
    "EXTERNAL_INCLUDE": "%{msvc_env_external_include_wdm_arm64}",
    "LIBPATH": "%{msvc_env_libpath_wdm_arm64}",
    "LIB": "%{msvc_env_lib_wdm_arm64}",
    "TMP": "%{msvc_env_tmp}",
}

_MSVC_ENV_APP_ARM64 = {
    "PATH": "%{msvc_env_path_app_arm64}",
    "INCLUDE": "%{msvc_env_include_app_arm64}",
    "EXTERNAL_INCLUDE": "%{msvc_env_external_include_app_arm64}",
    "LIBPATH": "%{msvc_env_libpath_app_arm64}",
    "LIB": "%{msvc_env_lib_app_arm64}",
    "TMP": "%{msvc_env_tmp}",
}

_TOOL_PATHS_X86 = {
    "ar": "%{msvc_lib_path_x86}",
    "ml": "%{msvc_ml_path_x86}",
    "cpp": "%{msvc_cl_path_x86}",
    "gcc": "%{msvc_cl_path_x86}",
    "ld": "%{msvc_link_path_x86}",
    "gcov": "wrapper/bin/msvc_nop.bat",
    "nm": "wrapper/bin/msvc_nop.bat",
    "objcopy": "wrapper/bin/msvc_nop.bat",
    "objdump": "wrapper/bin/msvc_nop.bat",
    "strip": "wrapper/bin/msvc_nop.bat",
}

_TOOL_PATHS_X64 = {
    "ar": "%{msvc_lib_path_x64}",
    "ml": "%{msvc_ml_path_x64}",
    "cpp": "%{msvc_cl_path_x64}",
    "gcc": "%{msvc_cl_path_x64}",
    "ld": "%{msvc_link_path_x64}",
    "gcov": "wrapper/bin/msvc_nop.bat",
    "nm": "wrapper/bin/msvc_nop.bat",
    "objcopy": "wrapper/bin/msvc_nop.bat",
    "objdump": "wrapper/bin/msvc_nop.bat",
    "strip": "wrapper/bin/msvc_nop.bat",
}

_TOOL_PATHS_ARM = {
    "ar": "%{msvc_lib_path_arm}",
    "ml": "%{msvc_ml_path_arm}",
    "cpp": "%{msvc_cl_path_arm}",
    "gcc": "%{msvc_cl_path_arm}",
    "ld": "%{msvc_link_path_arm}",
    "gcov": "wrapper/bin/msvc_nop.bat",
    "nm": "wrapper/bin/msvc_nop.bat",
    "objcopy": "wrapper/bin/msvc_nop.bat",
    "objdump": "wrapper/bin/msvc_nop.bat",
    "strip": "wrapper/bin/msvc_nop.bat",
}

_TOOL_PATHS_ARM64 = {
    "ar": "%{msvc_lib_path_arm64}",
    "ml": "%{msvc_ml_path_arm64}",
    "cpp": "%{msvc_cl_path_arm64}",
    "gcc": "%{msvc_cl_path_arm64}",
    "ld": "%{msvc_link_path_arm64}",
    "gcov": "wrapper/bin/msvc_nop.bat",
    "nm": "wrapper/bin/msvc_nop.bat",
    "objcopy": "wrapper/bin/msvc_nop.bat",
    "objdump": "wrapper/bin/msvc_nop.bat",
    "strip": "wrapper/bin/msvc_nop.bat",
}

# x64 toolchain
cc_toolchain(
    name = "ewdk-cc-compiler-x64_windows",
    all_files = ":empty",
    ar_files = ":empty",
    as_files = ":empty",
    compiler_files = ":empty",
    dwp_files = ":empty",
    linker_files = ":empty",
    objcopy_files = ":empty",
    strip_files = ":empty",
    supports_param_files = 1,
    toolchain_config = ":ewdk_msvc_x64",
    toolchain_identifier = "ewdk_msvc_x64",
)

ewdk_cc_toolchain_config(
    name = "ewdk_msvc_x64",
    arch_c_opts_wdm = [
        "/D_WIN64",
        "/D_AMD64_",
        "/DAMD64",
        "/Zp8",
    ],
    cetcompat_option = "/CETCOMPAT",
    cpu = "x64_windows",
    entry_symbol_suffix = "",
    has_gz_option = "/Gz",
    host_system_name = "local",
    link_machine_flag = "/MACHINE:X64",
    msvc_env_app = _MSVC_ENV_APP_X64,
    msvc_env_wdm = _MSVC_ENV_WDM_X64,
    target_system_name = "local",
    tool_paths = _TOOL_PATHS_X64,
    toolchain_identifier = "ewdk_msvc_x64",
)

toolchain(
    name = "ewdk-cc-toolchain-x64_windows",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:windows",
    ],
    target_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:windows",
    ],
    toolchain = ":ewdk-cc-compiler-x64_windows",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

# x86 toolchain
cc_toolchain(
    name = "ewdk-cc-compiler-x86_windows",
    all_files = ":empty",
    ar_files = ":empty",
    as_files = ":empty",
    compiler_files = ":empty",
    dwp_files = ":empty",
    linker_files = ":empty",
    objcopy_files = ":empty",
    strip_files = ":empty",
    supports_param_files = 1,
    toolchain_config = ":ewdk_msvc_x86",
    toolchain_identifier = "ewdk_msvc_x86",
)

ewdk_cc_toolchain_config(
    name = "ewdk_msvc_x86",
    arch_c_opts_wdm = [
        "/D_X86_=1",
        "/Di386=1",
        "/DSTD_CALL",
        "/Zp8",
    ],
    cetcompat_option = "/CETCOMPAT",
    cpu = "x86_windows",
    entry_symbol_suffix = "@8",
    has_gz_option = "/Gz",
    host_system_name = "local",
    link_machine_flag = "/MACHINE:X86",
    msvc_env_app = _MSVC_ENV_APP_X86,
    msvc_env_wdm = _MSVC_ENV_WDM_X86,
    target_system_name = "local",
    tool_paths = _TOOL_PATHS_X86,
    toolchain_identifier = "ewdk_msvc_x86",
)

toolchain(
    name = "ewdk-cc-toolchain-x86_windows",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:windows",
    ],
    target_compatible_with = [
        "@platforms//cpu:x86_32",
        "@platforms//os:windows",
    ],
    toolchain = ":ewdk-cc-compiler-x86_windows",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

# arm64 toolchain
cc_toolchain(
    name = "ewdk-cc-compiler-arm64_windows",
    all_files = ":empty",
    ar_files = ":empty",
    as_files = ":empty",
    compiler_files = ":empty",
    dwp_files = ":empty",
    linker_files = ":empty",
    objcopy_files = ":empty",
    strip_files = ":empty",
    supports_param_files = 1,
    toolchain_config = ":ewdk_msvc_arm64",
    toolchain_identifier = "ewdk_msvc_arm64",
)

ewdk_cc_toolchain_config(
    name = "ewdk_msvc_arm64",
    arch_c_opts_wdm = [
        "/D_WIN64",
        "/D_ARM64_",
        "/DARM64",
        "/DSTD_CALL",
        "/Zp8",
    ],
    cetcompat_option = "/CETCOMPAT:NO",
    cpu = "arm64_windows",
    entry_symbol_suffix = "",
    has_gz_option = "/Gd",
    host_system_name = "local",
    link_machine_flag = "/MACHINE:ARM64",
    msvc_env_app = _MSVC_ENV_APP_ARM64,
    msvc_env_wdm = _MSVC_ENV_WDM_ARM64,
    target_system_name = "local",
    tool_paths = _TOOL_PATHS_ARM64,
    toolchain_identifier = "ewdk_msvc_arm64",
)

toolchain(
    name = "ewdk-cc-toolchain-arm64_windows",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:windows",
    ],
    target_compatible_with = [
        "@platforms//cpu:arm64",
        "@platforms//os:windows",
    ],
    toolchain = ":ewdk-cc-compiler-arm64_windows",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

# arm toolchain
cc_toolchain(
    name = "ewdk-cc-compiler-arm_windows",
    all_files = ":empty",
    ar_files = ":empty",
    as_files = ":empty",
    compiler_files = ":empty",
    dwp_files = ":empty",
    linker_files = ":empty",
    objcopy_files = ":empty",
    strip_files = ":empty",
    supports_param_files = 1,
    toolchain_config = ":ewdk_msvc_arm",
    toolchain_identifier = "ewdk_msvc_arm",
)

ewdk_cc_toolchain_config(
    name = "ewdk_msvc_arm",
    arch_c_opts_wdm = [
        "/D_ARM_",
        "/DARM",
        "/DSTD_CALL",
        "/Zp8",
    ],
    cetcompat_option = "/CETCOMPAT:NO",
    cpu = "arm_windows",
    entry_symbol_suffix = "",
    has_gz_option = "/Gd",
    host_system_name = "local",
    link_machine_flag = "/MACHINE:ARM",
    msvc_env_app = _MSVC_ENV_APP_ARM,
    msvc_env_wdm = _MSVC_ENV_WDM_ARM,
    target_system_name = "local",
    tool_paths = _TOOL_PATHS_ARM,
    toolchain_identifier = "ewdk_msvc_arm",
)

toolchain(
    name = "ewdk-cc-toolchain-arm_windows",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:windows",
    ],
    target_compatible_with = [
        "@platforms//cpu:arm",
        "@platforms//os:windows",
    ],
    toolchain = ":ewdk-cc-compiler-arm_windows",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

# resource script x86 toolchain
toolchain_type(
    name = "resource_script_toolchain_type",
    visibility = ["//visibility:public"],
)

resource_script_toolchain_config(
    name = "ewdk_resource_script_toolchain_x86",
    defines = [
        "/Di386=1",
        "/D_X86_=1",
        "/D_M_IX86",
    ],
    env = _MSVC_ENV_APP_X86,
    rcpath = "rc_wrapper.bat",
)

toolchain(
    name = "resource-script-windows-x86",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:windows",
    ],
    target_compatible_with = [
        "@platforms//os:windows",
        "@platforms//cpu:x86_32",
    ],
    toolchain = ":ewdk_resource_script_toolchain_x86",
    toolchain_type = ":resource_script_toolchain_type",
)

# resource script x64 toolchain
resource_script_toolchain_config(
    name = "ewdk_resource_script_toolchain_x64",
    defines = [
        "/D_WIN64",
        "/D_AMD64_",
        "/DAMD64",
        "/D_M_AMD64",
    ],
    env = _MSVC_ENV_APP_X64,
    rcpath = "rc_wrapper.bat",
)

toolchain(
    name = "resource-script-windows-x64",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:windows",
    ],
    target_compatible_with = [
        "@platforms//os:windows",
        "@platforms//cpu:x86_64",
    ],
    toolchain = ":ewdk_resource_script_toolchain_x64",
    toolchain_type = ":resource_script_toolchain_type",
)

# resource script arm toolchain
resource_script_toolchain_config(
    name = "ewdk_resource_script_toolchain_arm",
    defines = [
        "/D_ARM_",
        "/DARM",
        "/D_M_ARM",
    ],
    env = _MSVC_ENV_APP_ARM,
    rcpath = "rc_wrapper.bat",
)

toolchain(
    name = "resource-script-windows-arm",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:windows",
    ],
    target_compatible_with = [
        "@platforms//os:windows",
        "@platforms//cpu:arm",
    ],
    toolchain = ":ewdk_resource_script_toolchain_arm",
    toolchain_type = ":resource_script_toolchain_type",
)

# resource script arm64 toolchain
resource_script_toolchain_config(
    name = "ewdk_resource_script_toolchain_arm64",
    defines = [
        "/D_WIN64",
        "/D_ARM64_",
        "/DARM64",
        "/D_M_ARM64",
    ],
    env = _MSVC_ENV_APP_ARM64,
    rcpath = "rc_wrapper.bat",
)

toolchain(
    name = "resource-script-windows-arm64",
    exec_compatible_with = [
        "@platforms//cpu:x86_64",
        "@platforms//os:windows",
    ],
    target_compatible_with = [
        "@platforms//os:windows",
        "@platforms//cpu:arm64",
    ],
    toolchain = ":ewdk_resource_script_toolchain_arm64",
    toolchain_type = ":resource_script_toolchain_type",
)
