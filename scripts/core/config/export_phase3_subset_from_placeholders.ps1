Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$placeholdersRoot = Join-Path $projectRoot "docs\content_expansion\placeholders"
$phaseRoot = Join-Path $projectRoot "docs\content_expansion\phases\phase3"

$buildingsCsv = Join-Path $placeholdersRoot "buildings_v2_placeholder.csv"
$unitsCsv = Join-Path $placeholdersRoot "units_v2_placeholder.csv"
$techsCsv = Join-Path $placeholdersRoot "techs_v2_placeholder.csv"
$skillsCsv = Join-Path $placeholdersRoot "skills_v2_placeholder.csv"

$phaseBuildingsCsv = Join-Path $phaseRoot "phase3_buildings.csv"
$phaseUnitsCsv = Join-Path $phaseRoot "phase3_units.csv"
$phaseTechsCsv = Join-Path $phaseRoot "phase3_techs.csv"
$phaseSkillsCsv = Join-Path $phaseRoot "phase3_skills.csv"
$phaseSummaryMd = Join-Path $phaseRoot "PHASE3_SCOPE.md"

$phase3BuildingIds = @(
	"psionic_relay",
	"bio_vat",
	"warp_gate",
	"void_core",
	"orbital_array"
)

$phase3UnitIds = @(
	"infiltrator",
	"guardian",
	"siege_mech",
	"guardian_tank",
	"disruptor_walker",
	"commando",
	"psionic_adept",
	"warlord"
)

$phase3TechIds = @(
	"infantry_weapons_3",
	"infantry_armor_3",
	"heavy_plating",
	"mech_chassis",
	"mech_weapons_3",
	"mech_plating_3",
	"precision_targeting",
	"quantum_command",
	"orbital_targeting",
	"phase_manipulation"
)

$phase3SkillIds = @(
	"build_orbital_array",
	"train_infiltrator",
	"train_guardian",
	"train_siege_mech",
	"train_guardian_tank",
	"train_disruptor_walker",
	"train_commando",
	"train_psionic_adept",
	"train_warlord",
	"research_infantry_weapons_3",
	"research_infantry_armor_3",
	"research_mech_weapons_3",
	"research_mech_plating_3",
	"research_orbital_targeting",
	"research_phase_manipulation",
	"research_structure_overclock",
	"fortify_mode",
	"siege_mode",
	"call_drop_pod",
	"orbital_strike"
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

$phaseBuildings = Select-ById -Rows $buildingRows -Ids $phase3BuildingIds -TypeName "building"
$phaseUnits = Select-ById -Rows $unitRows -Ids $phase3UnitIds -TypeName "unit"
$phaseTechs = Select-ById -Rows $techRows -Ids $phase3TechIds -TypeName "tech"
$phaseSkills = Select-ById -Rows $skillRows -Ids $phase3SkillIds -TypeName "skill"

$phaseBuildings | Export-Csv -Path $phaseBuildingsCsv -NoTypeInformation -Encoding UTF8
$phaseUnits | Export-Csv -Path $phaseUnitsCsv -NoTypeInformation -Encoding UTF8
$phaseTechs | Export-Csv -Path $phaseTechsCsv -NoTypeInformation -Encoding UTF8
$phaseSkills | Export-Csv -Path $phaseSkillsCsv -NoTypeInformation -Encoding UTF8

$summaryLines = @()
$summaryLines += "# Phase-3 Scope"
$summaryLines += ""
$summaryLines += "Generated from master placeholders via:"
$summaryLines += '`scripts/core/config/export_phase3_subset_from_placeholders.ps1`'
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
foreach ($id in $phase3BuildingIds) {
	$summaryLines += "- $id"
}
$summaryLines += ""
$summaryLines += "## Unit IDs"
$summaryLines += ""
foreach ($id in $phase3UnitIds) {
	$summaryLines += "- $id"
}
$summaryLines += ""
$summaryLines += "## Tech IDs"
$summaryLines += ""
foreach ($id in $phase3TechIds) {
	$summaryLines += "- $id"
}
$summaryLines += ""
$summaryLines += "## Skill IDs"
$summaryLines += ""
foreach ($id in $phase3SkillIds) {
	$summaryLines += "- $id"
}
$summaryLines += ""
$summaryLines += "Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

$summary = $summaryLines -join "`n"

Set-Content -Path $phaseSummaryMd -Value $summary -Encoding UTF8

Write-Output "Phase-3 subset exported:"
Write-Output ("  buildings = {0}" -f $phaseBuildings.Count)
Write-Output ("  units     = {0}" -f $phaseUnits.Count)
Write-Output ("  techs     = {0}" -f $phaseTechs.Count)
Write-Output ("  skills    = {0}" -f $phaseSkills.Count)
