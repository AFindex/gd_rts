Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$placeholdersRoot = Join-Path $projectRoot "docs\content_expansion\placeholders"
$phaseRoot = Join-Path $projectRoot "docs\content_expansion\phases\phase1"

$buildingsCsv = Join-Path $placeholdersRoot "buildings_v2_placeholder.csv"
$unitsCsv = Join-Path $placeholdersRoot "units_v2_placeholder.csv"
$techsCsv = Join-Path $placeholdersRoot "techs_v2_placeholder.csv"
$skillsCsv = Join-Path $placeholdersRoot "skills_v2_placeholder.csv"

$phaseBuildingsCsv = Join-Path $phaseRoot "phase1_buildings.csv"
$phaseUnitsCsv = Join-Path $phaseRoot "phase1_units.csv"
$phaseTechsCsv = Join-Path $phaseRoot "phase1_techs.csv"
$phaseSkillsCsv = Join-Path $phaseRoot "phase1_skills.csv"
$phaseSummaryMd = Join-Path $phaseRoot "PHASE1_SCOPE.md"

$phase1BuildingIds = @(
	"refinery",
	"forward_outpost",
	"armory",
	"sensor_spire",
	"med_bay"
)

$phase1UnitIds = @(
	"salvage_truck",
	"gas_siphon_drone",
	"combat_medic",
	"breacher",
	"grenadier",
	"suppressor",
	"recon_sniper",
	"flamelancer"
)

$phase1TechIds = @(
	"auto_refining",
	"combat_medicine",
	"emergency_repair",
	"squad_tactics",
	"stim_injection",
	"adaptive_camouflage",
	"composite_ballistics",
	"mech_weapons_1",
	"mech_plating_1",
	"missile_guidance"
)

$phase1SkillIds = @(
	"build_refinery",
	"build_forward_outpost",
	"build_armory",
	"build_sensor_spire",
	"build_med_bay",
	"train_salvage_truck",
	"train_gas_siphon_drone",
	"train_combat_medic",
	"train_breacher",
	"train_grenadier",
	"train_suppressor",
	"train_recon_sniper",
	"train_flamelancer",
	"research_auto_refining",
	"research_combat_medicine",
	"research_emergency_repair",
	"research_squad_tactics",
	"research_stim_injection",
	"research_adaptive_camouflage",
	"research_composite_ballistics"
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

$phaseBuildings = Select-ById -Rows $buildingRows -Ids $phase1BuildingIds -TypeName "building"
$phaseUnits = Select-ById -Rows $unitRows -Ids $phase1UnitIds -TypeName "unit"
$phaseTechs = Select-ById -Rows $techRows -Ids $phase1TechIds -TypeName "tech"
$phaseSkills = Select-ById -Rows $skillRows -Ids $phase1SkillIds -TypeName "skill"

$phaseBuildings | Export-Csv -Path $phaseBuildingsCsv -NoTypeInformation -Encoding UTF8
$phaseUnits | Export-Csv -Path $phaseUnitsCsv -NoTypeInformation -Encoding UTF8
$phaseTechs | Export-Csv -Path $phaseTechsCsv -NoTypeInformation -Encoding UTF8
$phaseSkills | Export-Csv -Path $phaseSkillsCsv -NoTypeInformation -Encoding UTF8

$summaryLines = @()
$summaryLines += "# Phase-1 Scope"
$summaryLines += ""
$summaryLines += "Generated from master placeholders via:"
$summaryLines += '`scripts/core/config/export_phase1_subset_from_placeholders.ps1`'
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
foreach ($id in $phase1BuildingIds) {
	$summaryLines += "- $id"
}
$summaryLines += ""
$summaryLines += "## Unit IDs"
$summaryLines += ""
foreach ($id in $phase1UnitIds) {
	$summaryLines += "- $id"
}
$summaryLines += ""
$summaryLines += "## Tech IDs"
$summaryLines += ""
foreach ($id in $phase1TechIds) {
	$summaryLines += "- $id"
}
$summaryLines += ""
$summaryLines += "## Skill IDs"
$summaryLines += ""
foreach ($id in $phase1SkillIds) {
	$summaryLines += "- $id"
}
$summaryLines += ""
$summaryLines += "Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

$summary = $summaryLines -join "`n"

Set-Content -Path $phaseSummaryMd -Value $summary -Encoding UTF8

Write-Output "Phase-1 subset exported:"
Write-Output ("  buildings = {0}" -f $phaseBuildings.Count)
Write-Output ("  units     = {0}" -f $phaseUnits.Count)
Write-Output ("  techs     = {0}" -f $phaseTechs.Count)
Write-Output ("  skills    = {0}" -f $phaseSkills.Count)
