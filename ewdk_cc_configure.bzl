# SPDX-FileCopyrightText: Copyright (c) 2022 Ira Strawser
# SPDX-License-Identifier: MIT

"""EWDK toolchain implementation"""

load("@bazel_tools//tools/cpp:lib_cc_configure.bzl", "execute")
load(
    "@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl",
    "action_config",
    "artifact_name_pattern",
    "env_entry",
    "env_set",
    "feature",
    "flag_group",
    "flag_set",
    "tool",
    "tool_path",
    "variable_with_value",
    "with_feature_set",
)
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")

_project_types = {
    "app": r"""<?xml version="1.0" encoding="utf-8"?>
<!-- msbuild.exe app.vcxproj /v:d /p:Configuration=Release;Platform=x64;WindowsTargetPlatformVersion=%Version_Number% -->
<Project DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
    <ItemGroup Label="ProjectConfigurations">
        <ProjectConfiguration Include="Release|Win32">
            <Configuration>Release</Configuration>
            <Platform>Win32</Platform>
        </ProjectConfiguration>
        <ProjectConfiguration Include="Release|x64">
            <Configuration>Release</Configuration>
            <Platform>x64</Platform>
        </ProjectConfiguration>
        <ProjectConfiguration Include="Release|ARM">
            <Configuration>Release</Configuration>
            <Platform>ARM</Platform>
        </ProjectConfiguration>
        <ProjectConfiguration Include="Release|ARM64">
            <Configuration>Release</Configuration>
            <Platform>ARM64</Platform>
        </ProjectConfiguration>
    </ItemGroup>
    <Import Project="$(VCTargetsPath)\Microsoft.Cpp.Default.props"/>
    <PropertyGroup>
        <ConfigurationType>Application</ConfigurationType>
        <PlatformToolset>v143</PlatformToolset>
    </PropertyGroup>
    <Import Project="$(VCTargetsPath)\Microsoft.Cpp.props"/>
    <ItemGroup>
        <ClCompile Include="app.cpp"/>
    </ItemGroup>
    <Import Project="$(VCTargetsPath)\Microsoft.Cpp.targets"/>
</Project>
""",
    "wdm": r"""<?xml version="1.0" encoding="utf-8"?>
<!-- msbuild.exe driver.vcxproj /v:d /p:Configuration=Release;Platform=x64;WindowsTargetPlatformVersion=%Version_Number% -->
<Project DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
    <ItemGroup Label="ProjectConfigurations">
        <ProjectConfiguration Include="Release|Win32">
            <Configuration>Release</Configuration>
            <Platform>Win32</Platform>
        </ProjectConfiguration>
        <ProjectConfiguration Include="Release|x64">
            <Configuration>Release</Configuration>
            <Platform>x64</Platform>
        </ProjectConfiguration>
        <ProjectConfiguration Include="Release|ARM">
            <Configuration>Release</Configuration>
            <Platform>ARM</Platform>
        </ProjectConfiguration>
        <ProjectConfiguration Include="Release|ARM64">
            <Configuration>Release</Configuration>
            <Platform>ARM64</Platform>
        </ProjectConfiguration>
    </ItemGroup>
    <Import Project="$(VCTargetsPath)\Microsoft.Cpp.Default.props"/>
    <PropertyGroup>
        <ConfigurationType>Driver</ConfigurationType>
        <PlatformToolset>WindowsKernelModeDriver10.0</PlatformToolset>
        <DriverType>WDM</DriverType>
    </PropertyGroup>
    <Import Project="$(VCTargetsPath)\Microsoft.Cpp.props"/>
    <ItemGroup>
        <ClCompile Include="wdm.cpp"/>
    </ItemGroup>
    <Import Project="$(VCTargetsPath)\Microsoft.Cpp.targets"/>
</Project>
""",
}

default_wdm_libs = [
    "bufferoverflowfastfailk.lib",
    "ntoskrnl.lib",
    "hal.lib",
    "wmilib.lib",
]

all_link_actions = [
    ACTION_NAMES.cpp_link_executable,
    ACTION_NAMES.cpp_link_dynamic_library,
    ACTION_NAMES.cpp_link_nodeps_dynamic_library,
]

def _get_envvar(env, name, default = None):
    for k, v in env.items():
        if k.lower() == name.lower():
            return v
    return default

def _get_path_envvar(env, name, default = None):
    value = _get_envvar(env, name)
    if value != None:
        if value[0] == '"':
            if len(value) == 1 or value[-1] != '"':
                fail("Env var %s unbalanced quotes" % name)
            value = value[1:-1]
        if "/" in value:
            value = value.replace("/", "\\")
        if value[-1] == "\\":
            value = value.rstrip("\\")
        if "\\\\" in value:
            value = value.replace("\\\\", "\\")
        return value
    return default

def _get_cpu_value(repository_ctx):
    """In the spirit of rules_cc's get_cpu_value"""

    # get_cpu_value() in the rule_cc library assumes x64 if windows is detected

    os_name = repository_ctx.os.name.lower()
    if os_name.find("windows") != -1:
        arch = _get_envvar(repository_ctx.os.environ, "PROCESSOR_ARCHITECTURE", "").lower()
        if arch == "amd64":
            return "x64_windows"

        #elif arch == "arm64":
        #    return "arm64_windows"

    return "unknown"

def _get_ewdk_env(repository_ctx, ewdkdir, host_cpu):
    """Retrieve the envvars set by the EWDK's LaunchBuildEnv.cmd"""
    plat = "amd64" if host_cpu == "x64_windows" else "x86_arm64"
    cmd = "\"{}\\BuildEnv\\SetupBuildenv.cmd\" {}".format(ewdkdir, plat)
    repository_ctx.file("ewdk_env.bat", "@echo off\r\ncall {} > nul \r\nset\r\n".format(cmd), True)
    envs = execute(repository_ctx, ["./ewdk_env.bat"])
    env_map = {}
    for line in envs.split("\n"):
        line = line.strip()
        offset = line.find("=")
        if offset == -1:
            continue
        env_map[line[:offset].upper()] = line[offset + 1:]
    vsversion = env_map["VISUALSTUDIOVERSION"]
    if vsversion == "17.0":
        env_map["VCINSTALLDIR_170"] = env_map["VCINSTALLDIR"]
    elif vsversion == "16.0":
        env_map["VCINSTALLDIR_160"] = env_map["VCINSTALLDIR"]
    elif vsversion == "15.0":
        env_map["VCINSTALLDIR_150"] = env_map["VCINSTALLDIR"]
    env_map["_MSBUILD_PATH"] = _get_exe_path(repository_ctx, "msbuild.exe", env_map)
    env_map["_RC_PATH"] = _get_exe_path(repository_ctx, "rc.exe", env_map)
    env_map["_TRACEWPP_PATH"] = _get_exe_path(repository_ctx, "tracewpp.exe", env_map)
    return env_map

def _get_exe_path(repository_ctx, filename, env):
    """Retrieve the path to the given exe"""
    repository_ctx.file("ewdk_get_exe.bat", "@echo off\r\nwhere %1\r\n", True)
    output = execute(repository_ctx, ["./ewdk_get_exe.bat", filename], environment = env)
    for line in output.split("\n"):
        if len(line):
            return line.strip()
    fail("Failed to locate %s for this EWDK" % filename)

def _get_msbuild_envs(repository_ctx, env):
    """Retrieve env vars set by msbuild used as defaults for the various project types supported here"""
    fast_safe = ["ni_release_svc_prod1.22621.382"]
    ewdk_version = env.get("BUILDLAB")

    build_envs = {}
    platforms = ["x86", "x64", "arm", "arm64"]
    project_types = _project_types.keys()
    if ewdk_version in fast_safe:
        # Only execute msbuild once per project_type and then use string replace to fill in other platforms
        for project_type in project_types:
            build_env = _msbuild_extract_vars(repository_ctx, env, project_type, platforms[0])
            build_envs["{}_{}".format(project_type, platforms[0])] = build_env
        for project_type in project_types:
            for platform in platforms:
                org_env = build_envs["{}_{}".format(project_type, platforms[0])]
                if platform != platforms[0]:
                    name = "{}_{}".format(project_type, platform)
                    build_envs[name] = _msbuild_replace_vars(repository_ctx, org_env, platforms[0], platform)
    else:
        # Unknown if it is safe to use the string replace method on this version. Execute msbuild for all combos
        asdf = print  # Avoid "problem" report from vscode bazel extension
        asdf("Warning: Unknown EWDK version. Using slow method to acquire env vars")
        for project_type in project_types:
            for platform in platforms:
                build_env = _msbuild_extract_vars(repository_ctx, env, project_type, platform)
                build_envs["{}_{}".format(project_type, platform)] = build_env
    return build_envs

def _msbuild_extract_vars(repository_ctx, env, project_type, platform):
    """Execute msbuild.exe with detailed verbosity enabled to extract the SetEnv tasks"""
    vars = ("PATH=", "INCLUDE=", "EXTERNAL_INCLUDE=", "LIBPATH=", "LIB=")
    projfile = project_type + ".vcxproj"
    repository_ctx.file(projfile, _project_types[project_type])
    args = [
        env["_MSBUILD_PATH"],
        projfile,
        "/verbosity:detailed",
        "/property:Configuration=Release",
        "/property:Platform={}".format(platform),
        "/property:WindowsTargetPlatformVersion={}".format(env["VERSION_NUMBER"]),
    ]
    result = repository_ctx.execute(args, environment = env)
    repository_ctx.delete("Release" if platform == "x86" else platform)
    tmp = {}
    for line in result.stdout.split("\n"):
        line = line.strip()
        if line.startswith(vars):
            offset = line.find("=")
            tmp[line[:offset]] = line[offset + 1:]
    return tmp

def _msbuild_replace_vars(repository_ctx, build_env, old_platform, new_platform):
    """Create a new build_env by replacing the platfrom value (e.g. x86 -> arm)"""
    to_replace = ["INCLUDE", "EXTERNAL_INCLUDE", "LIB", "LIBPATH"]
    keys = build_env.keys()
    tmp = {}
    for k in keys:
        if k in to_replace:
            tmp[k] = _msbuild_remove_nonexisting(repository_ctx, build_env[k].replace(old_platform, new_platform))
        else:
            tmp[k] = build_env[k]
    return tmp

def _msbuild_remove_nonexisting(repository_ctx, value):
    """Remove non-existing paths from the env var value"""
    dirs = value.split(";")
    for i in range(len(dirs)):
        if len(dirs[i]):
            ospath = repository_ctx.path(dirs[i])
            if not ospath.exists:
                dirs[i] = ""
    return ";".join([x for x in dirs if len(x)])

def _build_vscode_intellisense_config(repository_ctx, vscode_cfg_path, sdk_version, binroot, build_envs):
    host = "x64"
    app_includes = build_envs["app_" + host]["INCLUDE"]
    wdm_includes = build_envs["wdm_" + host]["INCLUDE"]

    includes = []
    prune = {}
    for x in app_includes.split(";") + wdm_includes.split(";"):
        if x and not prune.get(x) and not x.lower().endswith("\\km\\crt"):
            prune[x] = 1
            includes.append(x)

    indent = "    " * 4
    includes = (",\r\n%s" % indent).join(["\"%s\"" % x for x in includes])

    tpl_vars = {
        "%{cl_path}": "{}/bin/HostX64/{}/cl.exe".format(binroot, host),
        "%{c_standard}": "c17",
        "%{cpp_standard}": "c++17",
        "%{sdk_version}": sdk_version,
        "%{system_includes}": includes.replace("\\", "/"),
    }
    repository_ctx.template("c_cpp_properties.json", vscode_cfg_path, tpl_vars)

def _impl(ctx):
    wdm_default_includes = [x.replace("\\", "/") for x in ctx.attr.msvc_env_wdm["INCLUDE"].split(";") if x]

    artifact_name_patterns = [
        artifact_name_pattern(
            category_name = "object_file",
            prefix = "",
            extension = ".obj",
        ),
        artifact_name_pattern(
            category_name = "static_library",
            prefix = "",
            extension = ".lib",
        ),
        artifact_name_pattern(
            category_name = "alwayslink_static_library",
            prefix = "",
            extension = ".lo.lib",
        ),
        artifact_name_pattern(
            category_name = "executable",
            prefix = "",
            extension = ".exe",
        ),
        artifact_name_pattern(
            category_name = "dynamic_library",
            prefix = "",
            extension = ".dll",
        ),
        artifact_name_pattern(
            category_name = "interface_library",
            prefix = "",
            extension = ".if.lib",
        ),
    ]

    cpp_link_nodeps_dynamic_library_action = action_config(
        action_name = ACTION_NAMES.cpp_link_nodeps_dynamic_library,
        implies = [
            "nologo",
            "msvc_env",
            "no_stripping",
            "output_execpath_flags",
            "input_param_flags",
            "linker_param_file",
            "shared_flag",
            "linkstamps",
            "has_configured_linker_path",
            "user_link_flags",
            "def_file",
        ],
        tools = [tool(path = ctx.attr.tool_paths["ld"])],
    )

    cpp_link_static_library_action = action_config(
        action_name = ACTION_NAMES.cpp_link_static_library,
        implies = [
            "nologo",
            "msvc_env",
            "input_param_flags",
            "archiver_flags",
            "linker_param_file",
        ],
        tools = [tool(path = ctx.attr.tool_paths["ar"])],
    )

    assemble_action = action_config(
        action_name = ACTION_NAMES.assemble,
        implies = [
            "nologo",
            "msvc_env",
            "compiler_input_flags",
            "compiler_output_flags",
        ],
        tools = [tool(path = ctx.attr.tool_paths["ml"])],
    )

    preprocess_assemble_action = action_config(
        action_name = ACTION_NAMES.preprocess_assemble,
        implies = [
            "nologo",
            "msvc_env",
            "compiler_input_flags",
            "compiler_output_flags",
        ],
        tools = [tool(path = ctx.attr.tool_paths["ml"])],
    )

    c_compile_action = action_config(
        action_name = ACTION_NAMES.c_compile,
        implies = [
            "nologo",
            "msvc_env",
            "compiler_input_flags",
            "compiler_output_flags",
            "parse_showincludes",
            "user_compile_flags",
        ],
        tools = [tool(path = ctx.attr.tool_paths["cpp"])],
    )

    linkstamp_compile_action = action_config(
        action_name = ACTION_NAMES.linkstamp_compile,
        implies = [
            "nologo",
            "msvc_env",
            "compiler_input_flags",
            "compiler_output_flags",
            "parse_showincludes",
            "user_compile_flags",
        ],
        tools = [tool(path = ctx.attr.tool_paths["cpp"])],
    )

    cpp_compile_action = action_config(
        action_name = ACTION_NAMES.cpp_compile,
        implies = [
            "nologo",
            "msvc_env",
            "compiler_input_flags",
            "compiler_output_flags",
            "parse_showincludes",
            "user_compile_flags",
        ],
        tools = [tool(path = ctx.attr.tool_paths["cpp"])],
    )

    cpp_link_executable_action = action_config(
        action_name = ACTION_NAMES.cpp_link_executable,
        implies = [
            "nologo",
            "msvc_env",
            "no_stripping",
            "linkstamps",
            "output_execpath_flags",
            "input_param_flags",
            "linker_param_file",
            "user_link_flags",
        ],
        tools = [tool(path = ctx.attr.tool_paths["ld"])],
    )

    cpp_link_dynamic_library_action = action_config(
        action_name = ACTION_NAMES.cpp_link_dynamic_library,
        implies = [
            "nologo",
            "msvc_env",
            "no_stripping",
            "linkstamps",
            "output_execpath_flags",
            "input_param_flags",
            "linker_param_file",
            "shared_flag",
            "has_configured_linker_path",
            "user_link_flags",
            "def_file",
        ],
        tools = [tool(path = ctx.attr.tool_paths["ld"])],
    )

    action_configs = [
        assemble_action,
        preprocess_assemble_action,
        c_compile_action,
        linkstamp_compile_action,
        cpp_compile_action,
        cpp_link_executable_action,
        cpp_link_dynamic_library_action,
        cpp_link_nodeps_dynamic_library_action,
        cpp_link_static_library_action,
    ]

    no_legacy_features_feature = feature(name = "no_legacy_features")

    compiler_param_file_feature = feature(name = "compiler_param_file")

    archive_param_file_feature = feature(name = "archive_param_file")

    linkstamps_feature = feature(
        name = "linkstamps",
        flag_sets = [
            flag_set(
                actions = all_link_actions,
                flag_groups = [
                    flag_group(
                        flags = ["%{linkstamp_paths}"],
                        iterate_over = "linkstamp_paths",
                        expand_if_available = "linkstamp_paths",
                    ),
                ],
            ),
        ],
    )

    targets_windows_feature = feature(
        name = "targets_windows",
        enabled = True,
        implies = ["copy_dynamic_libraries_to_binary"],
    )

    copy_dynamic_libraries_to_binary_feature = feature(name = "copy_dynamic_libraries_to_binary")

    has_configured_linker_path_feature = feature(name = "has_configured_linker_path")

    supports_dynamic_linker_feature = feature(name = "supports_dynamic_linker", enabled = True)

    supports_interface_shared_libraries_feature = feature(
        name = "supports_interface_shared_libraries",
        enabled = True,
    )

    no_stripping_feature = feature(name = "no_stripping")

    linker_param_file_feature = feature(
        name = "linker_param_file",
        flag_sets = [
            flag_set(
                actions = all_link_actions +
                          [ACTION_NAMES.cpp_link_static_library],
                flag_groups = [
                    flag_group(
                        flags = ["@%{linker_param_file}"],
                        expand_if_available = "linker_param_file",
                    ),
                ],
            ),
        ],
    )

    nologo_feature = feature(
        name = "nologo",
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.assemble,
                    ACTION_NAMES.preprocess_assemble,
                    ACTION_NAMES.cpp_link_executable,
                    ACTION_NAMES.cpp_link_dynamic_library,
                    ACTION_NAMES.cpp_link_nodeps_dynamic_library,
                    ACTION_NAMES.cpp_link_static_library,
                ],
                flag_groups = [flag_group(flags = ["/nologo"])],
            ),
        ],
    )

    wdm_feature = feature(
        name = "wdm",
        provides = ["project_type"],
        implies = ["wdm_entry", "disable_msvcrt"],
    )

    wdm_entry_feature = feature(
        name = "wdm_entry",
        flag_sets = [
            flag_set(
                actions = [ACTION_NAMES.cpp_link_dynamic_library, ACTION_NAMES.cpp_link_nodeps_dynamic_library],
                flag_groups = [flag_group(flags = ["/ENTRY:DriverEntry"])],
                with_features = [with_feature_set(not_features = ["buffer_security_checks"])],
            ),
        ],
    )

    msvc_env_feature = feature(
        name = "msvc_env",
        env_sets = [
            env_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.assemble,
                    ACTION_NAMES.preprocess_assemble,
                    ACTION_NAMES.cpp_link_executable,
                    ACTION_NAMES.cpp_link_dynamic_library,
                    ACTION_NAMES.cpp_link_nodeps_dynamic_library,
                    ACTION_NAMES.cpp_link_static_library,
                ],
                env_entries = [
                    env_entry(key = "PATH", value = ctx.attr.msvc_env_app["PATH"]),
                    env_entry(key = "INCLUDE", value = ctx.attr.msvc_env_app["INCLUDE"]),
                    env_entry(key = "EXTERNAL_INCLUDE", value = ctx.attr.msvc_env_app["EXTERNAL_INCLUDE"]),
                    env_entry(key = "LIBPATH", value = ctx.attr.msvc_env_app["LIBPATH"]),
                    env_entry(key = "LIB", value = ctx.attr.msvc_env_app["LIB"]),
                    env_entry(key = "TMP", value = ctx.attr.msvc_env_app["TMP"]),
                    env_entry(key = "TEMP", value = ctx.attr.msvc_env_app["TMP"]),
                ],
                with_features = [with_feature_set(not_features = ["wdm"])],
            ),
            env_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.assemble,
                    ACTION_NAMES.preprocess_assemble,
                    ACTION_NAMES.cpp_link_executable,
                    ACTION_NAMES.cpp_link_dynamic_library,
                    ACTION_NAMES.cpp_link_nodeps_dynamic_library,
                    ACTION_NAMES.cpp_link_static_library,
                ],
                env_entries = [
                    env_entry(key = "PATH", value = ctx.attr.msvc_env_wdm["PATH"]),
                    env_entry(key = "INCLUDE", value = ctx.attr.msvc_env_wdm["INCLUDE"]),
                    env_entry(key = "EXTERNAL_INCLUDE", value = ctx.attr.msvc_env_wdm["EXTERNAL_INCLUDE"]),
                    env_entry(key = "LIBPATH", value = ctx.attr.msvc_env_wdm["LIBPATH"]),
                    env_entry(key = "LIB", value = ctx.attr.msvc_env_wdm["LIB"]),
                    env_entry(key = "TMP", value = ctx.attr.msvc_env_wdm["TMP"]),
                    env_entry(key = "TEMP", value = ctx.attr.msvc_env_wdm["TMP"]),
                ],
                with_features = [with_feature_set(features = ["wdm"])],
            ),
        ],
    )

    preprocessor_defines_feature = feature(
        name = "preprocessor_defines",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.assemble,
                    ACTION_NAMES.preprocess_assemble,
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                ],
                flag_groups = [
                    flag_group(
                        flags = ["/D%{preprocessor_defines}"],
                        iterate_over = "preprocessor_defines",
                    ),
                ],
            ),
        ],
    )

    msvc_enable_minmax_feature = feature(name = "msvc_enable_minmax")

    msvc_no_minmax_feature = feature(
        name = "msvc_no_minmax",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                ],
                flag_groups = [flag_group(flags = ["/DNOMINMAX"])],
                with_features = [with_feature_set(not_features = ["msvc_enable_minmax"])],
            ),
        ],
    )

    msvc_profile_feature = feature(
        name = "msvc_profile",
        flag_sets = [
            flag_set(
                actions = all_link_actions,
                flag_groups = [flag_group(flags = ["/PROFILE"])],
            ),
        ],
    )

    # Older bazel (pre-6) forces static or dynamic msvcrt features in CcCommon.java.
    #
    # Specifically, if "static_link_msvcrt" is specified, then the compilation mode is checked
    # and either "static_link_msvcrt_debug" or "static_link_msvcrt_no_debug" is set.
    # If "static_link_msvcrt" is not set, then either "dynamic_link_msvcrt_debug" or
    # "dynamic_link_msvcrt_no_debug" is set.
    #
    # This logic also means fastbuild will always specify a *_no_debug variant.
    #
    # This feature can be used to disable all msvcrt features on older bazel.
    disable_msvcrt_feature = feature(name = "disable_msvcrt")

    static_link_msvcrt_feature = feature(
        name = "static_link_msvcrt",
        flag_sets = [
            flag_set(
                actions = [ACTION_NAMES.c_compile, ACTION_NAMES.cpp_compile],
                flag_groups = [flag_group(flags = ["/MTd"])],
                with_features = [
                    with_feature_set(features = ["dbg"], not_features = ["static_link_msvcrt_no_debug", "disable_msvcrt"]),
                    with_feature_set(features = ["fastbuild"], not_features = ["static_link_msvcrt_no_debug", "disable_msvcrt"]),
                ],
            ),
            flag_set(
                actions = [ACTION_NAMES.c_compile, ACTION_NAMES.cpp_compile],
                flag_groups = [flag_group(flags = ["/MT"])],
                with_features = [with_feature_set(features = ["opt"], not_features = ["static_link_msvcrt_no_debug", "disable_msvcrt"])],
            ),
            flag_set(
                actions = all_link_actions,
                flag_groups = [flag_group(flags = ["/DEFAULTLIB:libcmtd.lib"])],
                with_features = [
                    with_feature_set(features = ["dbg"], not_features = ["static_link_msvcrt_no_debug", "disable_msvcrt"]),
                    with_feature_set(features = ["fastbuild"], not_features = ["static_link_msvcrt_no_debug", "disable_msvcrt"]),
                ],
            ),
            flag_set(
                actions = all_link_actions,
                flag_groups = [flag_group(flags = ["/DEFAULTLIB:libcmt.lib"])],
                with_features = [with_feature_set(features = ["opt"], not_features = ["static_link_msvcrt_no_debug", "disable_msvcrt"])],
            ),
        ],
    )

    static_link_msvcrt_debug_feature = feature(
        name = "static_link_msvcrt_debug",
        flag_sets = [
            flag_set(
                actions = [ACTION_NAMES.c_compile, ACTION_NAMES.cpp_compile],
                flag_groups = [flag_group(flags = ["/MTd"])],
                with_features = [with_feature_set(not_features = ["static_link_msvcrt", "static_link_msvcrt_no_debug", "disable_msvcrt"])],
            ),
            flag_set(
                actions = all_link_actions,
                flag_groups = [flag_group(flags = ["/DEFAULTLIB:libcmtd.lib"])],
                with_features = [with_feature_set(not_features = ["static_link_msvcrt", "static_link_msvcrt_no_debug", "disable_msvcrt"])],
            ),
        ],
    )

    static_link_msvcrt_no_debug_feature = feature(
        name = "static_link_msvcrt_no_debug",
        flag_sets = [
            flag_set(
                actions = [ACTION_NAMES.c_compile, ACTION_NAMES.cpp_compile],
                flag_groups = [flag_group(flags = ["/MT"])],
                with_features = [with_feature_set(not_features = ["disable_msvcrt"])],
            ),
            flag_set(
                actions = all_link_actions,
                flag_groups = [flag_group(flags = ["/DEFAULTLIB:libcmt.lib"])],
                with_features = [with_feature_set(not_features = ["disable_msvcrt"])],
            ),
        ],
    )

    static_disable_dynamic_msvcrt_features = [
        "disable_msvcrt",
        "static_link_msvcrt",
        "static_link_msvcrt_debug",
        "static_link_msvcrt_no_debug",
    ]

    dynamic_link_msvcrt_feature = feature(
        name = "dynamic_link_msvcrt",
        flag_sets = [
            flag_set(
                actions = [ACTION_NAMES.c_compile, ACTION_NAMES.cpp_compile],
                flag_groups = [flag_group(flags = ["/MDd"])],
                with_features = [
                    with_feature_set(features = ["dbg"], not_features = ["dynamic_link_msvcrt_no_debug"] + static_disable_dynamic_msvcrt_features),
                    with_feature_set(features = ["fastbuild"], not_features = ["dynamic_link_msvcrt_no_debug"] + static_disable_dynamic_msvcrt_features),
                ],
            ),
            flag_set(
                actions = [ACTION_NAMES.c_compile, ACTION_NAMES.cpp_compile],
                flag_groups = [flag_group(flags = ["/MD"])],
                with_features = [with_feature_set(features = ["opt"], not_features = ["dynamic_link_msvcrt_no_debug"] + static_disable_dynamic_msvcrt_features)],
            ),
            flag_set(
                actions = all_link_actions,
                flag_groups = [flag_group(flags = ["/DEFAULTLIB:msvcrtd.lib"])],
                with_features = [
                    with_feature_set(features = ["dbg"], not_features = ["dynamic_link_msvcrt_no_debug"] + static_disable_dynamic_msvcrt_features),
                    with_feature_set(features = ["fastbuild"], not_features = ["dynamic_link_msvcrt_no_debug"] + static_disable_dynamic_msvcrt_features),
                ],
            ),
            flag_set(
                actions = all_link_actions,
                flag_groups = [flag_group(flags = ["/DEFAULTLIB:msvcrt.lib"])],
                with_features = [with_feature_set(features = ["opt"], not_features = ["dynamic_link_msvcrt_no_debug"] + static_disable_dynamic_msvcrt_features)],
            ),
        ],
    )

    dynamic_link_msvcrt_debug_feature = feature(
        name = "dynamic_link_msvcrt_debug",
        flag_sets = [
            flag_set(
                actions = [ACTION_NAMES.c_compile, ACTION_NAMES.cpp_compile],
                flag_groups = [flag_group(flags = ["/MDd"])],
                with_features = [with_feature_set(not_features = ["dynamic_link_msvcrt"] + static_disable_dynamic_msvcrt_features)],
            ),
            flag_set(
                actions = all_link_actions,
                flag_groups = [flag_group(flags = ["/DEFAULTLIB:msvcrtd.lib"])],
                with_features = [with_feature_set(not_features = ["dynamic_link_msvcrt"] + static_disable_dynamic_msvcrt_features)],
            ),
        ],
    )

    dynamic_link_msvcrt_no_debug_feature = feature(
        name = "dynamic_link_msvcrt_no_debug",
        flag_sets = [
            flag_set(
                actions = [ACTION_NAMES.c_compile, ACTION_NAMES.cpp_compile],
                flag_groups = [flag_group(flags = ["/MD"])],
                with_features = [with_feature_set(not_features = ["dynamic_link_msvcrt_debug"] + static_disable_dynamic_msvcrt_features)],
            ),
            flag_set(
                actions = all_link_actions,
                flag_groups = [flag_group(flags = ["/DEFAULTLIB:msvcrt.lib"])],
                with_features = [with_feature_set(not_features = ["dynamic_link_msvcrt_debug"] + static_disable_dynamic_msvcrt_features)],
            ),
        ],
    )

    subsystem_console_feature = feature(
        name = "subsystem_console",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = all_link_actions,
                flag_groups = [flag_group(flags = ["/SUBSYSTEM:CONSOLE"])],
                with_features = [with_feature_set(not_features = ["subsystem_windows", "subsystem_native"])],
            ),
        ],
    )

    subsystem_windows_feature = feature(
        name = "subsystem_windows",
        flag_sets = [
            flag_set(
                actions = all_link_actions,
                flag_groups = [flag_group(flags = ["/SUBSYSTEM:WINDOWS"])],
            ),
        ],
        provides = ["subsystem"],
    )

    subsystem_native_feature = feature(
        name = "subsystem_native",
        flag_sets = [
            flag_set(
                actions = all_link_actions,
                flag_groups = [flag_group(flags = ["/SUBSYSTEM:NATIVE"])],
            ),
        ],
        provides = ["subsystem"],
    )

    win32_lean_and_mean_feature = feature(
        name = "win32_lean_and_mean",
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                ],
                flag_groups = [flag_group(flags = ["/DWIN32_LEAN_AND_MEAN=1"])],
            ),
        ],
    )

    cdecl_feature = feature(
        name = "cdecl",
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                ],
                flag_groups = [flag_group(flags = ["/Gd"])],
            ),
        ],
    )

    stdcall_feature = feature(
        name = "stdcall",
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                ],
                flag_groups = [flag_group(flags = [ctx.attr.has_gz_option])],
            ),
        ],
    )

    target_win7_default_feature = feature(
        name = "target_win7_default",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                ],
                flag_groups = [flag_group(flags = ["/DWINVER=0x0601", "/D_WIN32_WINNT=0x0601", "/DNTDDI_VERSION=0x06010000"])],
                with_features = [with_feature_set(not_features = ["target_win7", "target_win8", "target_win10", "target_win11"])],
            ),
        ],
    )

    target_win7_feature = feature(
        name = "target_win7",
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                ],
                flag_groups = [flag_group(flags = ["/DWINVER=0x0601", "/D_WIN32_WINNT=0x0601", "/DNTDDI_VERSION=0x06010000"])],
            ),
        ],
        provides = ["windows_target_version"],
    )

    target_win8_feature = feature(
        name = "target_win8",
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                ],
                flag_groups = [flag_group(flags = ["/DWINVER=0x0602", "/D_WIN32_WINNT=0x0602", "/DNTDDI_VERSION=0x06020000"])],
            ),
        ],
        provides = ["windows_target_version"],
    )

    target_win10_feature = feature(
        name = "target_win10",
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                ],
                flag_groups = [flag_group(flags = ["/DWINVER=0x0A00", "/D_WIN32_WINNT=0x0A00", "/DNTDDI_VERSION=0x0A000000"])],
            ),
        ],
        provides = ["windows_target_version"],
    )

    target_win11_feature = feature(
        name = "target_win11",
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                ],
                flag_groups = [flag_group(flags = ["/DWINVER=0x0A00", "/D_WIN32_WINNT=0x0A00", "/DNTDDI_VERSION=0x0A00000C"])],
            ),
        ],
        provides = ["windows_target_version"],
    )

    c11_feature = feature(
        name = "c11",
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                ],
                flag_groups = [flag_group(flags = ["/std:c11"])],
            ),
        ],
        provides = ["c_standard"],
    )

    c17_feature = feature(
        name = "c17",
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                ],
                flag_groups = [flag_group(flags = ["/std:c17"])],
            ),
        ],
        provides = ["c_standard"],
    )

    cpp14_feature = feature(
        name = "cpp14",
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                ],
                flag_groups = [flag_group(flags = ["/std:c++14"])],
            ),
        ],
        provides = ["cpp_standard"],
    )

    cpp17_feature = feature(
        name = "cpp17",
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                ],
                flag_groups = [flag_group(flags = ["/std:c++17"])],
            ),
        ],
        provides = ["cpp_standard"],
    )

    cpp20_feature = feature(
        name = "cpp20",
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                ],
                flag_groups = [flag_group(flags = ["/std:c++20"])],
            ),
        ],
        provides = ["cpp_standard"],
    )

    buffer_security_checks_feature = feature(
        name = "buffer_security_checks",
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                ],
                flag_groups = [flag_group(flags = ["/GS"])],
            ),
            flag_set(
                actions = [ACTION_NAMES.cpp_link_dynamic_library, ACTION_NAMES.cpp_link_nodeps_dynamic_library],
                flag_groups = [flag_group(flags = ["/ENTRY:GsDriverEntry" + ctx.attr.entry_symbol_suffix])],
                with_features = [with_feature_set(features = ["wdm"])],
            ),
        ],
    )

    sdl_security_checks_feature = feature(
        name = "sdl_security_checks",
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                ],
                flag_groups = [flag_group(flags = ["/sdl"])],
            ),
        ],
    )

    cfg_security_checks_feature = feature(
        name = "cfg_security_checks",
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                ],
                flag_groups = [flag_group(flags = ["/guard:cf"])],
            ),
            flag_set(
                actions = all_link_actions,
                flag_groups = [flag_group(flags = ["/guard:cf"])],
            ),
        ],
    )

    cet_compatible_feature = feature(
        name = "cet_compatible",
        flag_sets = [
            flag_set(
                actions = all_link_actions,
                flag_groups = [flag_group(flags = [ctx.attr.cetcompat_option])],
            ),
        ],
        provides = ["cet_spectre_load_cf_incompatible"],
    )

    guard_ehcont_feature = feature(
        name = "guard_ehcont",
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                ],
                flag_groups = [flag_group(flags = ["/guard:ehcont"])],
            ),
        ],
    )

    spectre_feature = feature(
        name = "spectre",
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                ],
                flag_groups = [flag_group(flags = ["/Qspectre"])],
            ),
        ],
    )

    spectre_load_cf_feature = feature(
        name = "spectre_load_cf",
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                ],
                flag_groups = [flag_group(flags = ["/Qspectre-load-cf"])],
            ),
        ],
        provides = ["cet_spectre_load_cf_incompatible"],
    )

    retpoline_check_feature = feature(
        name = "retpoline_check",
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                ],
                flag_groups = [flag_group(flags = ["/d2guardretpoline"])],
            ),
            flag_set(
                actions = all_link_actions,
                flag_groups = [flag_group(flags = ["/guard:retpoline"])],
            ),
        ],
    )

    charset_unicode_feature = feature(
        name = "charset_unicode",
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                ],
                flag_groups = [flag_group(flags = ["/D_UNICODE", "/DUNICODE"])],
            ),
        ],
    )

    charset_multibyte_feature = feature(
        name = "charset_multibyte",
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                ],
                flag_groups = [flag_group(flags = ["/D_MBCS"])],
            ),
        ],
    )

    compiler_input_flags_feature = feature(
        name = "compiler_input_flags",
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                ],
                flag_groups = [
                    flag_group(
                        flags = ["/c", "%{source_file}"],
                        expand_if_available = "source_file",
                    ),
                ],
            ),
        ],
    )

    compiler_output_flags_feature = feature(
        name = "compiler_output_flags",
        flag_sets = [
            flag_set(
                actions = [ACTION_NAMES.assemble],
                flag_groups = [
                    flag_group(
                        flag_groups = [
                            flag_group(
                                flags = ["/Fo", "%{output_file}", "/c", "/Zi", "/Zd", "/W3"],
                                expand_if_available = "output_file",
                                expand_if_not_available = "output_assembly_file",
                            ),
                        ],
                        expand_if_not_available = "output_preprocess_file",
                    ),
                ],
            ),
            flag_set(
                actions = [ACTION_NAMES.assemble],
                flag_groups = [
                    flag_group(
                        flag_groups = [
                            flag_group(
                                flags = ["/Ta", "%{source_file}"],
                                expand_if_available = "source_file",
                            ),
                        ],
                    ),
                ],
            ),
            flag_set(
                actions = [
                    ACTION_NAMES.preprocess_assemble,
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                ],
                flag_groups = [
                    flag_group(
                        flag_groups = [
                            flag_group(
                                flags = ["/Fo%{output_file}"],
                                expand_if_not_available = "output_preprocess_file",
                            ),
                        ],
                        expand_if_available = "output_file",
                        expand_if_not_available = "output_assembly_file",
                    ),
                    flag_group(
                        flag_groups = [
                            flag_group(
                                flags = ["/Fa%{output_file}"],
                                expand_if_available = "output_assembly_file",
                            ),
                        ],
                        expand_if_available = "output_file",
                    ),
                    flag_group(
                        flag_groups = [
                            flag_group(
                                flags = ["/P", "/Fi%{output_file}"],
                                expand_if_available = "output_preprocess_file",
                            ),
                        ],
                        expand_if_available = "output_file",
                    ),
                ],
            ),
        ],
    )

    default_includes_cmdline_feature = feature(
        name = "default_includes_cmdline",
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                    ACTION_NAMES.lto_backend,
                    ACTION_NAMES.clif_match,
                ],
                flag_groups = [flag_group(flags = ["/I" + x for x in wdm_default_includes])],
                with_features = [with_feature_set(features = ["wdm"])],
            ),
        ],
    )

    default_compile_flags_feature = feature(
        name = "default_compile_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                    ACTION_NAMES.lto_backend,
                    ACTION_NAMES.clif_match,
                ],
                flag_groups = [
                    flag_group(
                        flags = [
                            "/DCOMPILER_MSVC",
                            "/bigobj",
                            "/Zm500",
                            "/EHsc",
                            "/FC",
                            "/Zc:wchar_t",
                            "/Gm-",
                        ],
                    ),
                ],
                with_features = [with_feature_set(not_features = ["wdm"])],
            ),
            flag_set(
                actions = [
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                    ACTION_NAMES.lto_backend,
                    ACTION_NAMES.clif_match,
                ],
                flag_groups = [
                    flag_group(
                        flags = [
                            "/DCOMPILER_MSVC",
                            "/DWINNT=1",
                            "/kernel",
                            "/FC",
                            "/Zc:wchar_t",
                            "/Gm-",
                            "/GR-",
                        ] + ctx.attr.arch_c_opts_wdm,
                    ),
                ],
                with_features = [with_feature_set(features = ["wdm"])],
            ),
        ],
    )

    output_execpath_flags_feature = feature(
        name = "output_execpath_flags",
        flag_sets = [
            flag_set(
                actions = all_link_actions,
                flag_groups = [
                    flag_group(
                        flags = ["/OUT:%{output_execpath}"],
                        expand_if_available = "output_execpath",
                    ),
                ],
            ),
        ],
    )

    input_param_flags_feature = feature(
        name = "input_param_flags",
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.cpp_link_dynamic_library,
                    ACTION_NAMES.cpp_link_nodeps_dynamic_library,
                ],
                flag_groups = [
                    flag_group(
                        flags = ["/IMPLIB:%{interface_library_output_path}"],
                        expand_if_available = "interface_library_output_path",
                    ),
                ],
            ),
            flag_set(
                actions = all_link_actions,
                flag_groups = [
                    flag_group(
                        flags = ["%{libopts}"],
                        iterate_over = "libopts",
                        expand_if_available = "libopts",
                    ),
                ],
            ),
            flag_set(
                actions = all_link_actions +
                          [ACTION_NAMES.cpp_link_static_library],
                flag_groups = [
                    flag_group(
                        iterate_over = "libraries_to_link",
                        flag_groups = [
                            flag_group(
                                iterate_over = "libraries_to_link.object_files",
                                flag_groups = [flag_group(flags = ["%{libraries_to_link.object_files}"])],
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "object_file_group",
                                ),
                            ),
                            flag_group(
                                flag_groups = [flag_group(flags = ["%{libraries_to_link.name}"])],
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "object_file",
                                ),
                            ),
                            flag_group(
                                flag_groups = [flag_group(flags = ["%{libraries_to_link.name}"])],
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "interface_library",
                                ),
                            ),
                            flag_group(
                                flag_groups = [
                                    flag_group(
                                        flags = ["%{libraries_to_link.name}"],
                                        expand_if_false = "libraries_to_link.is_whole_archive",
                                    ),
                                    flag_group(
                                        flags = ["/WHOLEARCHIVE:%{libraries_to_link.name}"],
                                        expand_if_true = "libraries_to_link.is_whole_archive",
                                    ),
                                ],
                                expand_if_equal = variable_with_value(
                                    name = "libraries_to_link.type",
                                    value = "static_library",
                                ),
                            ),
                        ],
                        expand_if_available = "libraries_to_link",
                    ),
                ],
            ),
        ],
    )

    archiver_flags_feature = feature(
        name = "archiver_flags",
        flag_sets = [
            flag_set(
                actions = [ACTION_NAMES.cpp_link_static_library],
                flag_groups = [
                    flag_group(
                        flags = ["/OUT:%{output_execpath}"],
                        expand_if_available = "output_execpath",
                    ),
                    flag_group(
                        flags = [ctx.attr.link_machine_flag],
                    ),
                ],
            ),
        ],
    )

    shared_flag_feature = feature(
        name = "shared_flag",
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.cpp_link_dynamic_library,
                    ACTION_NAMES.cpp_link_nodeps_dynamic_library,
                ],
                flag_groups = [flag_group(flags = ["/DLL"])],
                with_features = [with_feature_set(not_features = ["wdm"])],
            ),
        ],
    )

    default_link_flags_feature = feature(
        name = "default_link_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = all_link_actions,
                flag_groups = [
                    flag_group(
                        flags = [
                            ctx.attr.link_machine_flag,
                            "/DYNAMICBASE",
                            "/NXCOMPAT",
                        ],
                    ),
                ],
                with_features = [with_feature_set(not_features = ["wdm"])],
            ),
            flag_set(
                actions = all_link_actions,
                flag_groups = [
                    flag_group(
                        flags = [
                            ctx.attr.link_machine_flag,
                            "/INTEGRITYCHECK",
                            "/DYNAMICBASE",
                            "/NXCOMPAT",
                            "/DRIVER",
                            "/NODEFAULTLIB",
                            "/SECTION:INIT,d",
                            "/MERGE:_TEXT=.text;_PAGE=PAGE",
                        ] + default_wdm_libs,
                    ),
                ],
                with_features = [with_feature_set(features = ["wdm"])],
            ),
        ],
    )

    user_link_flags_feature = feature(
        name = "user_link_flags",
        flag_sets = [
            flag_set(
                actions = all_link_actions,
                flag_groups = [
                    flag_group(
                        flags = ["%{user_link_flags}"],
                        iterate_over = "user_link_flags",
                        expand_if_available = "user_link_flags",
                    ),
                ],
            ),
        ],
    )

    def_file_feature = feature(
        name = "def_file",
        flag_sets = [
            flag_set(
                actions = all_link_actions,
                flag_groups = [
                    flag_group(
                        flags = ["/DEF:%{def_file_path}", "/ignore:4070"],
                        expand_if_available = "def_file_path",
                    ),
                ],
            ),
        ],
    )

    user_compile_flags_feature = feature(
        name = "user_compile_flags",
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.preprocess_assemble,
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                ],
                flag_groups = [
                    flag_group(
                        flags = ["%{user_compile_flags}"],
                        iterate_over = "user_compile_flags",
                        expand_if_available = "user_compile_flags",
                    ),
                ],
            ),
        ],
    )

    unfiltered_compile_flags_feature = feature(
        name = "unfiltered_compile_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.preprocess_assemble,
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                ],
                flag_groups = [
                    flag_group(
                        flags = ["%{unfiltered_compile_flags}"],
                        iterate_over = "unfiltered_compile_flags",
                        expand_if_available = "unfiltered_compile_flags",
                    ),
                ],
            ),
        ],
    )

    parse_showincludes_feature = feature(
        name = "parse_showincludes",
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.preprocess_assemble,
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_header_parsing,
                ],
                flag_groups = [flag_group(flags = ["/showIncludes"])],
            ),
        ],
    )

    msvc_level3_warnings_feature = feature(
        name = "msvc_level3_warnings",
        flag_sets = [
            flag_set(
                actions = [ACTION_NAMES.c_compile, ACTION_NAMES.cpp_compile],
                flag_groups = [flag_group(flags = ["/W3"])],
            ),
        ],
        provides = ["warning_level"],
    )

    msvc_level4_warnings_feature = feature(
        name = "msvc_level4_warnings",
        flag_sets = [
            flag_set(
                actions = [ACTION_NAMES.c_compile, ACTION_NAMES.cpp_compile],
                flag_groups = [flag_group(flags = ["/W4"])],
            ),
        ],
        provides = ["warning_level"],
    )

    treat_warnings_as_errors_feature = feature(
        name = "treat_warnings_as_errors",
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.assemble,
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.cpp_compile,
                ] + all_link_actions,
                flag_groups = [flag_group(flags = ["/WX"])],
            ),
        ],
    )

    windows_export_all_symbols_feature = feature(name = "windows_export_all_symbols")

    no_windows_export_all_symbols_feature = feature(name = "no_windows_export_all_symbols")

    include_paths_feature = feature(
        name = "include_paths",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.assemble,
                    ACTION_NAMES.preprocess_assemble,
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.linkstamp_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                ],
                flag_groups = [
                    flag_group(
                        flags = ["/I%{quote_include_paths}"],
                        iterate_over = "quote_include_paths",
                    ),
                    flag_group(
                        flags = ["/I%{include_paths}"],
                        iterate_over = "include_paths",
                    ),
                    flag_group(
                        flags = ["/I%{system_include_paths}"],
                        iterate_over = "system_include_paths",
                    ),
                ],
            ),
        ],
    )

    dbg_compile_flags = [
        flag_set(
            actions = [ACTION_NAMES.c_compile, ACTION_NAMES.cpp_compile],
            flag_groups = [flag_group(flags = ["/Od", "/Z7"])],
        ),
        flag_set(
            actions = [ACTION_NAMES.c_compile, ACTION_NAMES.cpp_compile],
            flag_groups = [flag_group(flags = ["/RTC1"])],
            with_features = [with_feature_set(not_features = ["wdm"])],
        ),
        flag_set(
            actions = [ACTION_NAMES.c_compile, ACTION_NAMES.cpp_compile],
            flag_groups = [flag_group(flags = ["/DMSC_NOOPT", "/DDBG=1"])],
            with_features = [with_feature_set(features = ["wdm"])],
        ),
    ]

    dbg_link_flags_fast = [
        flag_set(
            actions = all_link_actions,
            # this should be /DEBUG:FASTLINK but the EWDK link.exe was crashing very often in large builds
            flag_groups = [flag_group(flags = ["/DEBUG:FULL", "/INCREMENTAL:NO"])],
        ),
    ]

    dbg_link_flags_full = [
        flag_set(
            actions = all_link_actions,
            flag_groups = [flag_group(flags = ["/DEBUG:FULL", "/INCREMENTAL:NO"])],
        ),
    ]

    dbg_feature = feature(
        name = "dbg",
        flag_sets = dbg_compile_flags + dbg_link_flags_full,
        implies = ["generate_pdb_file"],
        provides = ["build_type"],
    )

    fastbuild_feature = feature(
        name = "fastbuild",
        flag_sets = dbg_compile_flags + dbg_link_flags_fast,
        implies = ["generate_pdb_file"],
        provides = ["build_type"],
    )

    generate_pdb_file_feature = feature(name = "generate_pdb_file")

    opt_feature = feature(
        name = "opt",
        flag_sets = [
            flag_set(
                actions = [ACTION_NAMES.c_compile, ACTION_NAMES.cpp_compile],
                flag_groups = [flag_group(flags = ["/DNDEBUG", "/Gy", "/GF", "/Z7"])],
            ),
            flag_set(
                actions = [ACTION_NAMES.c_compile, ACTION_NAMES.cpp_compile],
                flag_groups = [flag_group(flags = ["/GL", "/O2"])],
                with_features = [with_feature_set(not_features = ["wdm"])],
            ),
            flag_set(
                actions = [ACTION_NAMES.c_compile, ACTION_NAMES.cpp_compile],
                flag_groups = [flag_group(flags = ["/Ox", "/Os", "/GL"])],
                with_features = [with_feature_set(features = ["wdm"])],
            ),
            flag_set(
                actions = all_link_actions,
                flag_groups = [flag_group(flags = ["/DEBUG:FULL", "/OPT:REF", "/INCREMENTAL:NO", "/LTCG"])],
                with_features = [with_feature_set(not_features = ["wdm"])],
            ),
            flag_set(
                actions = all_link_actions,
                flag_groups = [flag_group(flags = ["/DEBUG:FULL", "/OPT:REF", "/INCREMENTAL:NO", "/LTCG"])],
                with_features = [with_feature_set(features = ["wdm"])],
            ),
        ],
        implies = ["generate_pdb_file"],
        provides = ["build_type"],
    )

    features = [
        no_legacy_features_feature,
        compiler_param_file_feature,
        archive_param_file_feature,
        linkstamps_feature,
        targets_windows_feature,
        copy_dynamic_libraries_to_binary_feature,
        has_configured_linker_path_feature,
        supports_dynamic_linker_feature,
        supports_interface_shared_libraries_feature,
        no_stripping_feature,
        linker_param_file_feature,
        nologo_feature,
        wdm_feature,
        wdm_entry_feature,
        msvc_env_feature,
        preprocessor_defines_feature,
        msvc_enable_minmax_feature,
        msvc_no_minmax_feature,
        msvc_profile_feature,
        disable_msvcrt_feature,
        static_link_msvcrt_feature,
        static_link_msvcrt_debug_feature,
        static_link_msvcrt_no_debug_feature,
        dynamic_link_msvcrt_feature,
        dynamic_link_msvcrt_debug_feature,
        dynamic_link_msvcrt_no_debug_feature,
        subsystem_console_feature,
        subsystem_windows_feature,
        subsystem_native_feature,
        win32_lean_and_mean_feature,
        cdecl_feature,
        stdcall_feature,
        target_win7_feature,
        target_win7_default_feature,
        target_win8_feature,
        target_win10_feature,
        target_win11_feature,
        c11_feature,
        c17_feature,
        cpp14_feature,
        cpp17_feature,
        cpp20_feature,
        buffer_security_checks_feature,
        sdl_security_checks_feature,
        cfg_security_checks_feature,
        cet_compatible_feature,
        guard_ehcont_feature,
        spectre_feature,
        spectre_load_cf_feature,
        retpoline_check_feature,
        charset_unicode_feature,
        charset_multibyte_feature,
        compiler_input_flags_feature,
        compiler_output_flags_feature,
        default_includes_cmdline_feature,
        default_compile_flags_feature,
        output_execpath_flags_feature,
        input_param_flags_feature,
        archiver_flags_feature,
        shared_flag_feature,
        default_link_flags_feature,
        user_link_flags_feature,
        def_file_feature,
        user_compile_flags_feature,
        unfiltered_compile_flags_feature,
        parse_showincludes_feature,
        msvc_level3_warnings_feature,
        msvc_level4_warnings_feature,
        treat_warnings_as_errors_feature,
        windows_export_all_symbols_feature,
        no_windows_export_all_symbols_feature,
        include_paths_feature,
        dbg_feature,
        fastbuild_feature,
        generate_pdb_file_feature,
        opt_feature,
    ]

    tool_paths = [
        tool_path(name = name, path = path)
        for name, path in ctx.attr.tool_paths.items()
    ]

    builtin_includes = ("%s;%s;%s;%s" % (
        ctx.attr.msvc_env_app["INCLUDE"],
        ctx.attr.msvc_env_app["EXTERNAL_INCLUDE"],
        ctx.attr.msvc_env_wdm["INCLUDE"],
        ctx.attr.msvc_env_wdm["EXTERNAL_INCLUDE"],
    )).split(";")
    tmp = {}
    for inc in builtin_includes:
        if len(inc):
            tmp[inc] = None
    builtin_includes = tmp.keys()

    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        features = features,
        action_configs = action_configs,
        artifact_name_patterns = artifact_name_patterns,
        cxx_builtin_include_directories = builtin_includes,
        toolchain_identifier = ctx.attr.toolchain_identifier,
        host_system_name = ctx.attr.host_system_name,
        target_system_name = ctx.attr.target_system_name,
        target_cpu = ctx.attr.cpu,
        target_libc = "msvcrt",
        compiler = "msvc-cl",
        abi_version = "local",
        abi_libc_version = "local",
        tool_paths = tool_paths,
    )

ewdk_cc_toolchain_config = rule(
    implementation = _impl,
    attrs = {
        "cpu": attr.string(mandatory = True),
        "link_machine_flag": attr.string(mandatory = True),
        "entry_symbol_suffix": attr.string(mandatory = True),
        "has_gz_option": attr.string(mandatory = True),
        "cetcompat_option": attr.string(mandatory = True),
        "toolchain_identifier": attr.string(),
        "host_system_name": attr.string(),
        "target_system_name": attr.string(),
        "msvc_env_wdm": attr.string_dict(),
        "msvc_env_app": attr.string_dict(),
        "arch_c_opts_wdm": attr.string_list(default = []),
        "tool_paths": attr.string_dict(),
    },
)

def _configure_ewdk_cc(repository_ctx, host_cpu):
    """Produce toolchain BUILD file from template.
    
    Args:
        repository_ctx: 
        host_cpu: Build execution cpu (e.g. x64_windows)
    """

    repository_ctx.symlink(
        repository_ctx.path(Label("//:ewdk_cc_configure.bzl")),
        "ewdk_cc_configure.bzl",
    )
    repository_ctx.symlink(
        repository_ctx.path(Label("//:resource_toolchain.bzl")),
        "resource_toolchain.bzl",
    )
    repository_ctx.symlink(
        repository_ctx.path(Label("//:wpp_toolchain.bzl")),
        "wpp_toolchain.bzl",
    )
    tpl_path = repository_ctx.path(Label("//:BUILD.ewdk.toolchains.tpl"))
    vscode_cfg_path = repository_ctx.path(Label("//:c_cpp_properties.tpl"))

    # First, we need to get the envvars from executing the EWDK LaunchBuildEnv.cmd.
    # The user must have specified an EWDKDIR env var to the root of the EWDK location before executing bazel
    ewdkdir = _get_path_envvar(repository_ctx.os.environ, "EWDKDIR")
    if not ewdkdir:
        fail("EWDKDIR envvar undefined. Please define to point to the root of the EWDK.")
    env = _get_ewdk_env(repository_ctx, ewdkdir, host_cpu)

    # Next we need to get the relevant env vars set by msbuild for the various project types we will support.
    # This is currently limited to project types "Application" and "Driver" (WDM driver type only).
    build_envs = _get_msbuild_envs(repository_ctx, env)

    # Now we produce the toolchain's BUILD file from the template
    binroot = env["VCTOOLSINSTALLDIR"].rstrip("\\").replace("\\", "/")
    content_root = env["WINDOWSSDKDIR"].rstrip("\\").replace("\\", "/")

    platforms = ["x86", "x64", "arm", "arm64"]
    plat32 = ["x86", "arm"]
    tpl_vars = {
        "%{msvc_env_tmp}": env["TMP"].replace("\\", "\\\\"),
        "%{msvc_rc_path}": env["_RC_PATH"].replace("\\", "/"),
        "%{msvc_tracewpp_path}": env["_TRACEWPP_PATH"].replace("\\", "/"),
        "%{msvc_tracewpp_cfgdir}": "{}/bin/{}/wppconfig/rev1".format(content_root, env["VERSION_NUMBER"]).replace("/", "\\\\"),
    }
    for platform in platforms:
        ml_name = "ml.exe" if platform in plat32 else "ml64.exe"
        tpl_vars["%%{msvc_lib_path_%s}" % platform] = "{}/bin/HostX64/{}/lib.exe".format(binroot, platform)
        tpl_vars["%%{msvc_ml_path_%s}" % platform] = "{}/bin/HostX64/{}/{}".format(binroot, platform, ml_name)
        tpl_vars["%%{msvc_cl_path_%s}" % platform] = "{}/bin/HostX64/{}/cl.exe".format(binroot, platform)
        tpl_vars["%%{msvc_link_path_%s}" % platform] = "{}/bin/HostX64/{}/link.exe".format(binroot, platform)

    for platform, buildenv in build_envs.items():
        include = buildenv["INCLUDE"]
        tpl_vars["%%{msvc_env_path_%s}" % platform] = buildenv["PATH"].replace("\\", "\\\\")
        tpl_vars["%%{msvc_env_include_%s}" % platform] = include.replace("\\", "\\\\")
        tpl_vars["%%{msvc_env_external_include_%s}" % platform] = buildenv.get("EXTERNAL_INCLUDE", include).replace("\\", "\\\\")
        tpl_vars["%%{msvc_env_libpath_%s}" % platform] = buildenv["LIBPATH"].replace("\\", "\\\\")
        tpl_vars["%%{msvc_env_lib_%s}" % platform] = buildenv["LIB"].replace("\\", "\\\\")
    repository_ctx.template("BUILD", tpl_path, tpl_vars)

    repository_ctx.file("rc_wrapper.bat", content = "@echo off\r\n\"%s\" %%*\r\n" % env["_RC_PATH"])
    repository_ctx.file("tracewpp_wrapper.bat", content = "@echo off\r\n\"%s\" %%3 %%4 %%5 %%6 %%7 %%8 %%9 && copy /Y /V \"%%1\" \"%%2\" >nul" % env["_TRACEWPP_PATH"])

    _build_vscode_intellisense_config(repository_ctx, vscode_cfg_path, env["VERSION_NUMBER"], binroot, build_envs)

def _ewdk_cc_autoconf_toolchains_impl(repository_ctx):
    """Produce BUILD file containing toolchain() definitions for EWDK C++
    
    Args:
        repository_ctx: 
    """
    host_cpu = _get_cpu_value(repository_ctx)
    if host_cpu != "x64_windows":
        repository_ctx.file("BUILD", "# EWDK C++ toolchain unsupported host platform")

    ewdkdir = _get_path_envvar(repository_ctx.os.environ, "EWDKDIR")
    if not ewdkdir:
        repository_ctx.file("BUILD", "# EWDKDIR envar not present")
    else:
        _configure_ewdk_cc(repository_ctx, host_cpu)

ewdk_cc_autoconf_toolchains = repository_rule(
    implementation = _ewdk_cc_autoconf_toolchains_impl,
    local = True,
    configure = True,
)

def register_ewdk_cc_toolchains(name = "ewdk_cc_configured_toolchain"):
    """Register EWDK C++ toolchains"""
    ewdk_cc_autoconf_toolchains(name = name)
    native.register_toolchains("@%s//:all" % name)
