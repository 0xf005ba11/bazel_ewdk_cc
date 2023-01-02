EWDK toolchain for Bazel
=========

Build windows applications and drivers with the EWDK.

Supports:
* Building WDM drivers (KMDF not yet implemented)
* Building applications, DLLs and static libraries.
* Cross-compiling to x86, x64, ARM and ARM64
* Supports building on x64 hosts only.

Supported bazel versions:
* 6.0.0 - Built and tested with. Unknown if other versions work.

## Quick Start

First, make sure the EWDKDIR environment variable is set to the root of the EWDK when executing bazel.

```cmd
set EWDKDIR=D:\EWDK
bazel build ...
```

Include the following in your WORKSPACE:
```starlark
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

git_repository(
    name = "bazel_ewdk_cc",
    remote = "https://github.com/0xf005ba11/bazel_ewdk_cc",
    commit = "47f0aff241e9eca1318573f7f605a29766502723",
)

load("@bazel_ewdk_cc//:ewdk_cc_configure.bzl", "register_ewdk_cc_toolchains")

register_ewdk_cc_toolchains()
```

Add the following to your .bazelrc (this should hopefully no longer be needed once this [issue](https://github.com/bazelbuild/bazel/issues/7260) is closed in bazel 7.0.0):
```
build --incompatible_enable_cc_toolchain_resolution
```

If you have problems with toolchain selection (```--toolchain_resolution_debug=.*```), you may also need to set this action_env:
```
build --action_env=BAZEL_DO_NOT_DETECT_CPP_TOOLCHAIN=1
```

## Building a WDM driver

The easiest way to do this is to build a DLL (```linkedshared = True```) and include the ```wdm```, ```subsystem_native``` and one of (```target_win7```, ```target_win8```, ```target_win10```, or ```target_win11```) features. You will also likely want to include the ```stdcall```, ```msvc_level4_warnings```, and ```treat_warnings_as_errors``` features.

For example:
```starlark
cc_binary(
    name = "sys",
    srcs = glob(["*.cpp"]),
    features = [
        "wdm",
        "subsystem_native",
        "target_win10",
        "stdcall",
        "msvc_level4_warnings",
        "treat_warnings_as_errors",
        "cpp20",
        "msvc_no_minmax",
        "buffer_security_checks",
        "sdl_security_checks",
        "cfg_security_checks",
        "spectre",
    ],
    linkshared = True,
    target_compatible_with = ["@platforms//os:windows"],
)
```

This will result in a ```sys.dll``` being built. Bazel doesn't currently understand the ```.sys``` extension directly in a ```cc_binary``` rule.

## Building an executable

Make sure to include one of ```subsystem_console``` or ```subsystem_windows```. Use ```subsystem_windows``` for DLLs.

If you are using the MS C-Runtime, also include one of ```static_link_msvcrt``` or ```dynamic_link_msvcrt```. These features will automatically choose debug versions when building in ```dbg``` or ```fastbuild``` modes. To always specify a non-debug version, use one of ```static_link_msvcrt_no_debug``` or ```dynamic_link_msvcrt_no_debug```. This may be required when external depedencies always link against a non-debug version.

```starlark
cc_binary(
    name = "exe",
    srcs = ["exe.cpp"],
    features = [
        "subsystem_console",
        "static_link_msvcrt",
        "msvc_level4_warnings",
        "treat_warnings_as_errors",
        "cdecl",
    ],
)
```

## Features specific to this toolchain

In addition to features from the built-in bazel C++ toolchain, the following have been added:

* wdm - Building a WDM driver
* subsystem_native - /SUBSYSTEM:NATIVE
* subsystem_console - /SUBSYSTEM:CONSOLE
* subsystem_windows - /SUBSYSTEM:WINDOWS
* stdcall - /Gz  (Note: For ARM this will automatically revert to /Gd)
* cdecl - /Gd
* msvc_level3_warnings - /W3
* msvc_level4_warnings - /W4
* treat_warnings_as_errors - /WX
* target_win7 - WINVER, _WIN32_WINNT and NTDDI_VERSION for Windows 7 (0x06010000)
* target_win8 - 0x06020000
* target_win10 - 0x0A000000
* target_win11 -  0x0A00000C
* c11 - /std:c11
* c17 - /std:c17
* cpp14 - /std:c++14
* cpp17 - /std:c++17
* cpp20 - /std:c++20
* msvc_no_minmax - /DNOMINMAX
* win32_lean_and_mean - /DWIN32_LEAN_AND_MEAN=1
* buffer_security_checks - /GS
* sdl_security_checks - /sdl
* cfg_security_checks - /guard:cf
* cet_compatible - /CETCOMPAT (Note: For ARM this will automatically revert to /CETCOMPAT:NO)
* guard_ehcont - /guard:ehcont
* retpoline_check - /d2guardretpoline and /guard:retpoline
* spectre - /Qspectre
* spectre_load_cf - /Qspectre-load-cf
* default_includes_cmdline - Adds the default include paths to the command line (/I). This can be useful for tooling like producing intellisense configurations.

## Default compile flags
* /DCOMPILER_MSVC
* /EHsc - non-```wdm``` builds only
* /D_UNICODE - non-```wdm``` builds only
* /DUNICODE - non-```wdm``` builds only
* /FC
* /Zc:wchar_t
* /utf-8
* /Gm-
* /GR- - ```wdm``` builds only

When building in dbg or fastbuild mode, the following are added:
* /Od
* /Z7
* /RTC1 - non-```wdm``` builds only
* /DMSC_NOOPT - ```wdm``` builds only
* /DDBG=1 - ```wdm``` builds only

When building in opt mode, the following are added:
* /DNDEBUG
* /Gy
* /GF
* /Z7
* /GL
* /O2 - non-```wdm``` builds only
* /Ox - ```wdm``` builds only
* /Os - ```wdm``` builds only
* /OPT:REF
* /LTCG - (linker flag to compliment /GL)

When building for x86 32-bit (WDM drivers):
* /D_X86_=1
* /Di386=1
* /DSTD_CALL
* /Zp8

When building for x64 (WDM drivers):
* /D_WIN64
* /D_AMD64_
* /DAMD64
* /Zp8

When building for ARM (WDM drivers):
* /D_ARM_
* /DARM
* /DSTD_CALL
* /Zp8

When building for ARM64 (WDM drivers):
* /D_WIN64
* /D_ARM64_
* /DARM64
* /DSTD_CALL
* /Zp8

## Default link flags
* /DYNAMICBASE
* /NXCOMPAT
* /INTEGRITYCHECK - ```wdm``` builds only
* /DRIVER - ```wdm``` builds only
* /NODEFAULTLIB - ```wdm``` builds only
* /SECTION:INIT,d - ```wdm``` builds only
* /MERGE:_TEXT=.text;_PAGE=PAGE - ```wdm``` builds only
* /DEBUG:FULL
* /INCREMENTAL:NO

## Default linked libs for WDM drivers
* BufferOverflowFastFailK.lib
* ntoskrnl.lib
* hal.lib
* wmilib.lib
