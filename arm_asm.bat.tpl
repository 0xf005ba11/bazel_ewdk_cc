@echo off
setlocal enableextensions

set userargs=
set incdirs=
set cl_incdirs=
set state=
set output=
set input=

shift
:parse_args
set arg=%~0
REM This argument forced in cc rules from bazel breaks the following if statement
if "%arg:~0,26%"=="/DBAZEL_CURRENT_REPOSITORY" goto next_arg
if "%0"=="" (
    goto done_args
)
if "%state%"=="out" (
    set output=%arg%
    set state=
    goto next_arg
)
if "%state%"=="in" (
    set input=%arg%
    set state=
    goto next_arg
)
if "%arg:~0,2%"=="/I" (
    set cl_incdirs=%cl_incdirs% %0
    if "%incdirs%"=="" (
        set incdirs=%arg:~2%
    ) else (
        set incdirs=%incdirs%;%arg:~2%
    )
    goto next_arg
)
if "%arg%"=="/Fo" (
    set state=out
    goto next_arg
)
if "%arg%"=="/Ta" (
    set state=in
    goto next_arg
)
if /i "%arg%"=="/nologo" set arg=-nologo
if /i "%arg%"=="/zh:sha_256" set arg=-gh:SHA256
if "%arg:~0,1%"=="-" (
    set userargs=%userargs% %arg%
    goto next_arg
)
if not "%arg:~0,1%"=="/" (
    set input=%arg%
    goto next_arg
)
:next_arg
shift
goto parse_args
:done_args

if not "%incdirs%"=="" (
    set incdirs=-i "%incdirs%"
)

"%{cl_path}" /nologo /c /P %cl_incdirs% /Fi"%input%.preprocessed.asm" /TC "%input%" && (
    "%{armasm_path}"%userargs% %incdirs% "%input%.preprocessed.asm" "%output%"
) || (
    exit 1
)
