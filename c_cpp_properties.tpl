{
    "configurations": [
        {
            "name": "win-X86-dbg",
            "includePath": [
                "${workspaceFolder}/**",
                %{system_includes}
            ],
            "defines": ["_X86_=1", "i386=1", "STD_CALL", "COMPILER_MSVC", "_M_IX86", "_DEBUG", "DBG=1", "MSC_NOOPT"],
            "windowsSdkVersion": "%{sdk_version}",
            "compilerPath": "%{cl_path}",
            "cStandard": "%{c_standard}",
            "cppStandard": "%{cpp_standard}",
            "intelliSenseMode": "windows-msvc-x86",
            "mergeConfigurations": true,
            "browse": {
                "path": [
                    "${workspaceFolder}/**"
                ],
                "limitSymbolsToIncludedHeaders": true
            }
        },
        {
            "name": "win-X86-opt",
            "includePath": [
                "${workspaceFolder}/**",
                %{system_includes}
            ],
            "defines": ["_X86_=1", "i386=1", "STD_CALL", "COMPILER_MSVC", "_M_IX86", "NDEBUG"],
            "windowsSdkVersion": "%{sdk_version}",
            "compilerPath": "%{cl_path}",
            "cStandard": "%{c_standard}",
            "cppStandard": "%{cpp_standard}",
            "intelliSenseMode": "windows-msvc-x86",
            "mergeConfigurations": true,
            "browse": {
                "path": [
                    "${workspaceFolder}/**"
                ],
                "limitSymbolsToIncludedHeaders": true
            }
        },
        {
            "name": "win-X64-dbg",
            "includePath": [
                "${workspaceFolder}/**",
                %{system_includes}
            ],
            "defines": ["_WIN64", "_AMD64_", "AMD64", "COMPILER_MSVC", "_M_AMD64", "_DEBUG", "DBG=1", "MSC_NOOPT"],
            "windowsSdkVersion": "%{sdk_version}",
            "compilerPath": "%{cl_path}",
            "cStandard": "%{c_standard}",
            "cppStandard": "%{cpp_standard}",
            "intelliSenseMode": "windows-msvc-x64",
            "mergeConfigurations": true,
            "browse": {
                "path": [
                    "${workspaceFolder}/**"
                ],
                "limitSymbolsToIncludedHeaders": true
            }
        },
        {
            "name": "win-X64-opt",
            "includePath": [
                "${workspaceFolder}/**",
                %{system_includes}
            ],
            "defines": ["_WIN64", "_AMD64_", "AMD64", "COMPILER_MSVC", "_M_AMD64", "NDEBUG"],
            "windowsSdkVersion": "%{sdk_version}",
            "compilerPath": "%{cl_path}",
            "cStandard": "%{c_standard}",
            "cppStandard": "%{cpp_standard}",
            "intelliSenseMode": "windows-msvc-x64",
            "mergeConfigurations": true,
            "browse": {
                "path": [
                    "${workspaceFolder}/**"
                ],
                "limitSymbolsToIncludedHeaders": true
            }
        },
        {
            "name": "win-ARM-dbg",
            "includePath": [
                "${workspaceFolder}/**",
                %{system_includes}
            ],
            "defines": ["_ARM_", "ARM", "STD_CALL", "COMPILER_MSVC", "_M_ARM", "_DEBUG", "DBG=1", "MSC_NOOPT"],
            "windowsSdkVersion": "%{sdk_version}",
            "compilerPath": "%{cl_path}",
            "cStandard": "%{c_standard}",
            "cppStandard": "%{cpp_standard}",
            "intelliSenseMode": "windows-msvc-arm",
            "mergeConfigurations": true,
            "browse": {
                "path": [
                    "${workspaceFolder}/**"
                ],
                "limitSymbolsToIncludedHeaders": true
            }
        },
        {
            "name": "win-ARM-opt",
            "includePath": [
                "${workspaceFolder}/**",
                %{system_includes}
            ],
            "defines": ["_ARM_", "ARM", "STD_CALL", "COMPILER_MSVC", "_M_ARM", "NDEBUG"],
            "windowsSdkVersion": "%{sdk_version}",
            "compilerPath": "%{cl_path}",
            "cStandard": "%{c_standard}",
            "cppStandard": "%{cpp_standard}",
            "intelliSenseMode": "windows-msvc-arm",
            "mergeConfigurations": true,
            "browse": {
                "path": [
                    "${workspaceFolder}/**"
                ],
                "limitSymbolsToIncludedHeaders": true
            }
        },
        {
            "name": "win-ARM64-dbg",
            "includePath": [
                "${workspaceFolder}/**",
                %{system_includes}
            ],
            "defines": ["_WIN64", "_ARM64_", "ARM64", "COMPILER_MSVC", "_M_ARM64", "STD_CALL", "_M_ARM64", "_DEBUG", "DBG=1", "MSC_NOOPT"],
            "windowsSdkVersion": "%{sdk_version}",
            "compilerPath": "%{cl_path}",
            "cStandard": "%{c_standard}",
            "cppStandard": "%{cpp_standard}",
            "intelliSenseMode": "windows-msvc-arm64",
            "mergeConfigurations": true,
            "browse": {
                "path": [
                    "${workspaceFolder}/**"
                ],
                "limitSymbolsToIncludedHeaders": true
            }
        },
        {
            "name": "win-ARM64-opt",
            "includePath": [
                "${workspaceFolder}/**",
                %{system_includes}
            ],
            "defines": ["_WIN64", "_ARM64_", "ARM64", "COMPILER_MSVC", "_M_ARM64", "STD_CALL", "_M_ARM64", "NDEBUG"],
            "windowsSdkVersion": "%{sdk_version}",
            "compilerPath": "%{cl_path}",
            "cStandard": "%{c_standard}",
            "cppStandard": "%{cpp_standard}",
            "intelliSenseMode": "windows-msvc-arm64",
            "mergeConfigurations": true,
            "browse": {
                "path": [
                    "${workspaceFolder}/**"
                ],
                "limitSymbolsToIncludedHeaders": true
            }
        },
        {
            "name": "win-ARM64EC-dbg",
            "includePath": [
                "${workspaceFolder}/**",
                %{system_includes}
            ],
            "defines": ["_WIN64", "_AMD64_", "AMD64", "COMPILER_MSVC", "_M_AMD64", "_M_ARM64EC", "_ARM64EC_", "_DEBUG", "DBG=1", "MSC_NOOPT"],
            "windowsSdkVersion": "%{sdk_version}",
            "compilerPath": "%{cl_path}",
            "cStandard": "%{c_standard}",
            "cppStandard": "%{cpp_standard}",
            "intelliSenseMode": "windows-msvc-x64",
            "mergeConfigurations": true,
            "browse": {
                "path": [
                    "${workspaceFolder}/**"
                ],
                "limitSymbolsToIncludedHeaders": true
            }
        },
        {
            "name": "win-ARM64EC-opt",
            "includePath": [
                "${workspaceFolder}/**",
                %{system_includes}
            ],
            "defines": ["_WIN64", "_AMD64_", "AMD64", "COMPILER_MSVC", "_M_AMD64", "_M_ARM64EC", "_ARM64EC_", "NDEBUG"],
            "windowsSdkVersion": "%{sdk_version}",
            "compilerPath": "%{cl_path}",
            "cStandard": "%{c_standard}",
            "cppStandard": "%{cpp_standard}",
            "intelliSenseMode": "windows-msvc-x64",
            "mergeConfigurations": true,
            "browse": {
                "path": [
                    "${workspaceFolder}/**"
                ],
                "limitSymbolsToIncludedHeaders": true
            }
        }
    ],
    "version": 4
}