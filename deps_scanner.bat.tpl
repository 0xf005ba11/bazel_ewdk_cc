@echo off
setlocal
set DEPS_SCANNER_OUTPUT_FILE=%DEPS_SCANNER_OUTPUT_FILE:"=%
"%{cl_path}" /TP /scanDependencies "%DEPS_SCANNER_OUTPUT_FILE%" %*
