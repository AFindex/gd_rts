Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$placeholdersRoot = Join-Path $projectRoot "docs\content_expansion\placeholders"
$phaseRoot = Join-Path $projectRoot "docs\content_expansion\phases\phase4"

$phase1Root = Join-Path $projectRoot "docs\content_expansion\phases\phase1"
$phase2Root = Join-Path $projectRoot "docs\content_expansion\phases\phase2"
$phase3Root = Join-Path $projectRoot "docs\content_expansion\phases\phase3"

$buildingsCsv = Join-Path $placeholdersRoot "buildings_v2_placeholder.csv"
$unitsCsv = Join-Path $placeholdersRoot "units_v2_placeholder.csv"
$techsCsv = Join-Path $placeholdersRoot "techs_v2_placeholder.csv"
$skillsCsv = Join-Path $placeholdersRoot "skills_v2_placeholder.csv"

$phaseBuildingsCsv = Join-Path $phaseRoot "phase4_buildings.csv"
$phaseUnitsCsv = Join-Path $phaseRoot "phase4_units.csv"
$phaseTechsCsv = Join-Path $phaseRoot "phase4_techs.csv"
$phaseSkillsCsv = Join-Path $phaseRoot "phase4_skills.csv"
$phaseSummaryMd = Join-Path $phaseRoot "PHASE4_SCOPE.md"

function Get-UsedIds {
	param(
		[Parameter(Mandatory = $true)] [string[]] $CsvPaths
	)

	$ids = @()
	foreach ($path in $CsvPaths) {
		if (Test-Path $path) {
			$rows = Import-Csv -Path $path
			$ids += ($rows | ForEach-Object { [string]$_.id } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
		}
	}

	return $ids
}

function Select-Remaining {
	param(
		[Parameter(Mandatory = $true)] [object[]] $MasterRows,
		[Parameter(Mandatory = $true)] [string[]] $UsedIds
	)

	$usedSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
	foreach ($id in $UsedIds) {
		$null = $usedSet.Add($id)
	}

	$remaining = @()
	foreach ($row in $MasterRows) {
		$id = [string]$row.id
		if ([string]::IsNullOrWhiteSpace($id)) {
			continue
		}
		if (-not $usedSet.Contains($id)) {
			$remaining += $row
		}
	}
	return $remaining
}

New-Item -ItemType Directory -Force -Path $phaseRoot | Out-Null

$buildingRows = Import-Csv -Path $buildingsCsv
$unitRows = Import-Csv -Path $unitsCsv
$techRows = Import-Csv -Path $techsCsv
$skillRows = Import-Csv -Path $skillsCsv

$usedBuildingIds = Get-UsedIds -CsvPaths @(
	(Join-Path $phase1Root "phase1_buildings.csv"),
	(Join-Path $phase2Root "phase2_buildings.csv"),
	(Join-Path $phase3Root "phase3_buildings.csv")
)
$usedUnitIds = Get-UsedIds -CsvPaths @(
	(Join-Path $phase1Root "phase1_units.csv"),
	(Join-Path $phase2Root "phase2_units.csv"),
	(Join-Path $phase3Root "phase3_units.csv")
)
$usedTechIds = Get-UsedIds -CsvPaths @(
	(Join-Path $phase1Root "phase1_techs.csv"),
	(Join-Path $phase2Root "phase2_techs.csv"),
	(Join-Path $phase3Root "phase3_techs.csv")
)
$usedSkillIds = Get-UsedIds -CsvPaths @(
	(Join-Path $phase1Root "phase1_skills.csv"),
	(Join-Path $phase2Root "phase2_skills.csv"),
	(Join-Path $phase3Root "phase3_skills.csv")
)

$phaseBuildings = Select-Remaining -MasterRows $buildingRows -UsedIds $usedBuildingIds
$phaseUnits = Select-Remaining -MasterRows $unitRows -UsedIds $usedUnitIds
$phaseTechs = Select-Remaining -MasterRows $techRows -UsedIds $usedTechIds
$phaseSkills = Select-Remaining -MasterRows $skillRows -UsedIds $usedSkillIds

$phaseBuildings | Export-Csv -Path $phaseBuildingsCsv -NoTypeInformation -Encoding UTF8
$phaseUnits | Export-Csv -Path $phaseUnitsCsv -NoTypeInformation -Encoding UTF8
$phaseTechs | Export-Csv -Path $phaseTechsCsv -NoTypeInformation -Encoding UTF8
$phaseSkills | Export-Csv -Path $phaseSkillsCsv -NoTypeInformation -Encoding UTF8

$phaseBuildingIds = $phaseBuildings | ForEach-Object { [string]$_.id }
$phaseUnitIds = $phaseUnits | ForEach-Object { [string]$_.id }
$phaseTechIds = $phaseTechs | ForEach-Object { [string]$_.id }
$phaseSkillIds = $phaseSkills | ForEach-Object { [string]$_.id }

$summaryLines = @()
$summaryLines += "# Phase-4 Scope (Remaining Pool)"
$summaryLines += ""
$summaryLines += "Generated from master placeholders via:"
$summaryLines += '`scripts/core/config/export_phase4_remaining_from_placeholders.ps1`'
$summaryLines += ""
$summaryLines += "## Counts"
$summaryLines += ""
$summaryLines += "- Buildings: $($phaseBuildings.Count)"
$summaryLines += "- Units: $($phaseUnits.Count)"
$summaryLines += "- Techs: $($phaseTechs.Count)"
$summaryLines += "- Skills: $($phaseSkills.Count)"
$summaryLines += ""
$summaryLines += "## Building IDs"
$summaryLines += ""
foreach ($id in $phaseBuildingIds) {
	$summaryLines += "- $id"
}
$summaryLines += ""
$summaryLines += "## Unit IDs"
$summaryLines += ""
foreach ($id in $phaseUnitIds) {
	$summaryLines += "- $id"
}
$summaryLines += ""
$summaryLines += "## Tech IDs"
$summaryLines += ""
foreach ($id in $phaseTechIds) {
	$summaryLines += "- $id"
}
$summaryLines += ""
$summaryLines += "## Skill IDs"
$summaryLines += ""
foreach ($id in $phaseSkillIds) {
	$summaryLines += "- $id"
}
$summaryLines += ""
$summaryLines += "Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

$summary = $summaryLines -join "`n"

Set-Content -Path $phaseSummaryMd -Value $summary -Encoding UTF8

Write-Output "Phase-4 subset exported (remaining pool):"
Write-Output ("  buildings = {0}" -f $phaseBuildings.Count)
Write-Output ("  units     = {0}" -f $phaseUnits.Count)
Write-Output ("  techs     = {0}" -f $phaseTechs.Count)
Write-Output ("  skills    = {0}" -f $phaseSkills.Count)
