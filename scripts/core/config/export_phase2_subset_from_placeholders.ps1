Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$placeholdersRoot = Join-Path $projectRoot "docs\content_expansion\placeholders"
$phaseRoot = Join-Path $projectRoot "docs\content_expansion\phases\phase2"

$buildingsCsv = Join-Path $placeholdersRoot "buildings_v2_placeholder.csv"
$unitsCsv = Join-Path $placeholdersRoot "units_v2_placeholder.csv"
$techsCsv = Join-Path $placeholdersRoot "techs_v2_placeholder.csv"
$skillsCsv = Join-Path $placeholdersRoot "skills_v2_placeholder.csv"

$phaseBuildingsCsv = Join-Path $phaseRoot "phase2_buildings.csv"
$phaseUnitsCsv = Join-Path $phaseRoot "phase2_units.csv"
$phaseTechsCsv = Join-Path $phaseRoot "phase2_techs.csv"
$phaseSkillsCsv = Join-Path $phaseRoot "phase2_skills.csv"
$phaseSummaryMd = Join-Path $phaseRoot "PHASE2_SCOPE.md"

$phase2BuildingIds = @(
	"drone_bay",
	"shield_array",
	"artillery_foundry",
	"air_control_hub",
	"command_uplink"
)

$phase2UnitIds = @(
	"fabrication_drone",
	"shieldbearer",
	"logistics_officer",
	"assault_mech",
	"aa_mech",
	"support_mech",
	"artillery_mech",
	"vanguard"
)

$phase2TechIds = @(
	"logistics_network",
	"mech_weapons_2",
	"mech_plating_2",
	"servo_actuators",
	"siege_calibration",
	"drone_link",
	"air_control",
	"reactive_shields",
	"structure_overclock",
	"command_matrix"
)

$phase2SkillIds = @(
	"build_drone_bay",
	"build_shield_array",
	"build_artillery_foundry",
	"build_air_control_hub",
	"build_command_uplink",
	"train_fabrication_drone",
	"train_shieldbearer",
	"train_logistics_officer",
	"train_assault_mech",
	"train_aa_mech",
	"train_support_mech",
	"train_artillery_mech",
	"train_vanguard",
	"research_logistics_network",
	"research_mech_weapons_2",
	"research_mech_plating_2",
	"research_siege_calibration",
	"research_drone_link",
	"research_reactive_shields",
	"research_command_matrix"
)

function Select-ById {
	param(
		[Parameter(Mandatory = $true)] [object[]] $Rows,
		[Parameter(Mandatory = $true)] [string[]] $Ids,
		[Parameter(Mandatory = $true)] [string] $TypeName
	)

	$index = @{}
	foreach ($row in $Rows) {
		$id = [string]$row.id
		if ([string]::IsNullOrWhiteSpace($id)) {
			continue
		}
		$index[$id] = $row
	}

	$selected = @()
	$missing = @()
	foreach ($id in $Ids) {
		if ($index.ContainsKey($id)) {
			$selected += $index[$id]
		}
		else {
			$missing += $id
		}
	}

	if ($missing.Count -gt 0) {
		throw "Missing $TypeName ids in placeholder CSV: $($missing -join ', ')"
	}

	return $selected
}

New-Item -ItemType Directory -Force -Path $phaseRoot | Out-Null

$buildingRows = Import-Csv -Path $buildingsCsv
$unitRows = Import-Csv -Path $unitsCsv
$techRows = Import-Csv -Path $techsCsv
$skillRows = Import-Csv -Path $skillsCsv

$phaseBuildings = Select-ById -Rows $buildingRows -Ids $phase2BuildingIds -TypeName "building"
$phaseUnits = Select-ById -Rows $unitRows -Ids $phase2UnitIds -TypeName "unit"
$phaseTechs = Select-ById -Rows $techRows -Ids $phase2TechIds -TypeName "tech"
$phaseSkills = Select-ById -Rows $skillRows -Ids $phase2SkillIds -TypeName "skill"

$phaseBuildings | Export-Csv -Path $phaseBuildingsCsv -NoTypeInformation -Encoding UTF8
$phaseUnits | Export-Csv -Path $phaseUnitsCsv -NoTypeInformation -Encoding UTF8
$phaseTechs | Export-Csv -Path $phaseTechsCsv -NoTypeInformation -Encoding UTF8
$phaseSkills | Export-Csv -Path $phaseSkillsCsv -NoTypeInformation -Encoding UTF8

$summaryLines = @()
$summaryLines += "# Phase-2 Scope"
$summaryLines += ""
$summaryLines += "Generated from master placeholders via:"
$summaryLines += '`scripts/core/config/export_phase2_subset_from_placeholders.ps1`'
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
foreach ($id in $phase2BuildingIds) {
	$summaryLines += "- $id"
}
$summaryLines += ""
$summaryLines += "## Unit IDs"
$summaryLines += ""
foreach ($id in $phase2UnitIds) {
	$summaryLines += "- $id"
}
$summaryLines += ""
$summaryLines += "## Tech IDs"
$summaryLines += ""
foreach ($id in $phase2TechIds) {
	$summaryLines += "- $id"
}
$summaryLines += ""
$summaryLines += "## Skill IDs"
$summaryLines += ""
foreach ($id in $phase2SkillIds) {
	$summaryLines += "- $id"
}
$summaryLines += ""
$summaryLines += "Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

$summary = $summaryLines -join "`n"

Set-Content -Path $phaseSummaryMd -Value $summary -Encoding UTF8

Write-Output "Phase-2 subset exported:"
Write-Output ("  buildings = {0}" -f $phaseBuildings.Count)
Write-Output ("  units     = {0}" -f $phaseUnits.Count)
Write-Output ("  techs     = {0}" -f $phaseTechs.Count)
Write-Output ("  skills    = {0}" -f $phaseSkills.Count)
