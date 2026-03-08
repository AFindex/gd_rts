param(
    [string]$GodotExe = "godot",
    [string]$ProjectPath = ".",
    [switch]$SkipExport,
    [switch]$SkipSmoke,
    [switch]$VerboseGodot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-Step {
    param(
        [string]$Name,
        [string[]]$Args
    )

    Write-Host "[ConfigPipeline] $Name"
    & $GodotExe @Args
    if ($LASTEXITCODE -ne 0) {
        throw "Step failed: $Name (exit code $LASTEXITCODE)"
    }
}

$projectArg = @("--headless", "--path", $ProjectPath)
if (-not $VerboseGodot) {
    $projectArg += @("--quiet")
}

if (-not $SkipExport) {
    Invoke-Step -Name "Normalize config assets" -Args ($projectArg + @("--script", "scripts/core/config/export_catalog_to_config.gd"))
}

Invoke-Step -Name "Validate config references" -Args ($projectArg + @("--script", "scripts/core/config/validate_config_catalog.gd"))

if (-not $SkipSmoke) {
    Invoke-Step -Name "Editor headless smoke check" -Args ($projectArg + @("--editor", "--quit"))
}

Write-Host "[ConfigPipeline] Done"
exit 0
