EWDK toolchain for Bazel
=========

Build windows applications and drivers with the EWDK.

Supports:
* Building WDM drivers (KMDF not yet implemented)
* Building applications, DLLs and static libraries.
* Windows resource scripts.
* Cross-compiling to x86, x64, ARM and ARM64
* Supports building on x64 hosts only.
* Intellisense configurations for use with the EWDK.

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
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "bazel_ewdk_cc",
    sha256 = "fdc6ca9a8610f28744cf37af132a03422599f580757b6e54478e007e7505bac9",
    strip_prefix = "bazel_ewdk_cc-1.0.3/",
    url = "https://github.com/0xf005ba11/bazel_ewdk_cc/archive/refs/tags/v1.0.3.zip",
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

## Building a resource script

```starlark
load("@bazel_ewdk_cc//:resource_toolchain.bzl", "resource_script")

resource_script(
    name = "your_rc",
    rcfile = "your.rc",
    rcopts = [], # put additional command line options here if needed
)

# "your_rc" can now be referenced in deps of other binaries
```

## Windows vscode intellisense settings

When the toolchain is registered, it will emit a ```c_cpp_properties.json``` in its output folder that contains intellisense configurations for windows. This file can be copied into place with something like:

```powershell
copy "$(bazel info output_base)/external/ewdk_cc_configured_toolchain/c_cpp_properties.json" "./.vscode/c_cpp_properties.json"
```

This file will only change if the EWDK location changes, so it is recommended to modify it as you see fit. Consider it a starting point for your configuration. Additionally, these settings will be imperfect as the kernel-mode CRT is not included to avoid conflicting with the regular CRT.  However, they should work well enough.

## Features specific to this toolchain

In addition to features from the built-in bazel C++ toolchain, the following have been added:

* wdm - Building a WDM driver
* subsystem_native - /SUBSYSTEM:NATIVE
* subsystem_console - /SUBSYSTEM:CONSOLE
* subsystem_windows - /SUBSYSTEM:WINDOWS
* stdcall - /Gz  (Note: For ARM this will automatically revert to /Gd)
* cdecl - /Gd
* charset_unicode - /D_UNICODE /DUNICODE
* charset_multibyte - /D_MBCS
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
* msvc_enable_minmax - Enable the windows SDK min and max macros (they are disabled by default with /DNOMINMAX)
* win32_lean_and_mean - /DWIN32_LEAN_AND_MEAN=1
* buffer_security_checks - /GS
* sdl_security_checks - /sdl
* cfg_security_checks - /guard:cf
* cet_compatible - /CETCOMPAT (Note: For ARM this will automatically revert to /CETCOMPAT:NO)
* guard_ehcont - /guard:ehcont
* retpoline_check - /d2guardretpoline and /guard:retpoline (x64-only)
* spectre - /Qspectre
* spectre_load_cf - /Qspectre-load-cf
* default_includes_cmdline - Adds the default include paths to the command line (/I). This can be useful for tooling like producing intellisense configurations.

## Default compile flags
* /DCOMPILER_MSVC
* /bigobj
* /Zm500
* /EHsc - non-```wdm``` builds only
* /DNOMINMAX - use the msvc_enable_minmax feature to re-enable these macros
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
* /Zi
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

## Default masm flags
* /Zi
* /Zd
* /W3

## Default linked libs for WDM drivers
* BufferOverflowFastFailK.lib
* ntoskrnl.lib
* hal.lib
* wmilib.lib
