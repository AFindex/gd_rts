@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "GODOT_EXE=godot"
set "PROJECT_PATH=."
set "SKIP_EXPORT=0"
set "SKIP_SMOKE=0"
set "GODOT_QUIET=1"

:parse_args
if "%~1"=="" goto run_pipeline

if /I "%~1"=="--skip-export" (
    set "SKIP_EXPORT=1"
    shift
    goto parse_args
)

if /I "%~1"=="--skip-smoke" (
    set "SKIP_SMOKE=1"
    shift
    goto parse_args
)

if /I "%~1"=="--verbose" (
    set "GODOT_QUIET=0"
    shift
    goto parse_args
)

if /I "%~1"=="--godot" (
    if "%~2"=="" (
        echo [ConfigPipeline] Missing value for --godot
        exit /b 2
    )
    set "GODOT_EXE=%~2"
    shift
    shift
    goto parse_args
)

if /I "%~1"=="--project" (
    if "%~2"=="" (
        echo [ConfigPipeline] Missing value for --project
        exit /b 2
    )
    set "PROJECT_PATH=%~2"
    shift
    shift
    goto parse_args
)

echo [ConfigPipeline] Unknown argument: %~1
exit /b 2

:run_pipeline
set "COMMON_ARGS=--headless --path "%PROJECT_PATH%""
if "%GODOT_QUIET%"=="1" set "COMMON_ARGS=!COMMON_ARGS! --quiet"

if "%SKIP_EXPORT%"=="0" (
    echo [ConfigPipeline] Normalize config assets
    call "%GODOT_EXE%" !COMMON_ARGS! --script scripts/core/config/export_catalog_to_config.gd
    if errorlevel 1 exit /b 1
)

echo [ConfigPipeline] Validate config references
call "%GODOT_EXE%" !COMMON_ARGS! --script scripts/core/config/validate_config_catalog.gd
if errorlevel 1 exit /b 1

if "%SKIP_SMOKE%"=="0" (
    echo [ConfigPipeline] Editor headless smoke check
    call "%GODOT_EXE%" !COMMON_ARGS! --editor --quit
    if errorlevel 1 exit /b 1
)

echo [ConfigPipeline] Done
exit /b 0
