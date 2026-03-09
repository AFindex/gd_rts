param(
	[switch]$Clean
)

$ErrorActionPreference = "Stop"

function Split-PipeList {
	param([string]$Value)
	if ([string]::IsNullOrWhiteSpace($Value)) {
		return @()
	}
	$parts = @()
	foreach ($part in ($Value -split "\|")) {
		$trimmed = $part.Trim()
		if ($trimmed -ne "") {
			$parts += $trimmed
		}
	}
	return $parts
}

function Join-GdStringArray {
	param([string[]]$Values)
	if ($null -eq $Values -or $Values.Count -eq 0) {
		return "Array[String]([])"
	}
	$quoted = @()
	foreach ($v in $Values) {
		$escaped = $v.Replace('"', '\"')
		$quoted += ('"{0}"' -f $escaped)
	}
	return ("Array[String]([{0}])" -f ($quoted -join ", "))
}

function Join-GdVariantArray {
	param([string[]]$Values)
	if ($null -eq $Values -or $Values.Count -eq 0) {
		return "[]"
	}
	$quoted = @()
	foreach ($v in $Values) {
		$escaped = $v.Replace('"', '\"')
		$quoted += ('"{0}"' -f $escaped)
	}
	return ("[{0}]" -f ($quoted -join ", "))
}

function Escape-GdString {
	param([string]$Value)
	if ($null -eq $Value) {
		return ""
	}
	return $Value.Replace('"', '\"')
}

function Write-Utf8NoBom {
	param(
		[Parameter(Mandatory = $true)] [string] $Path,
		[Parameter(Mandatory = $true)] [string] $Text
	)
	$encoding = New-Object System.Text.UTF8Encoding($false)
	[System.IO.File]::WriteAllText($Path, $Text, $encoding)
}

function Get-RoleTagFromId {
	param([string]$Id)
	$upper = ($Id -replace "_", "").ToUpperInvariant()
	if ($upper.Length -ge 3) {
		return $upper.Substring(0, 3)
	}
	return $upper
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Resolve-Path (Join-Path $scriptDir "..\..\..")

$csvRoot = Join-Path $projectRoot "docs\content_expansion\placeholders"
$outputRoot = Join-Path $projectRoot "config_expansion"

$unitsOut = Join-Path $outputRoot "units"
$buildingsOut = Join-Path $outputRoot "buildings"
$techsOut = Join-Path $outputRoot "techs"
$skillsOut = Join-Path $outputRoot "skills"

if ($Clean -and (Test-Path $outputRoot)) {
	Remove-Item -Recurse -Force $outputRoot
}

foreach ($dir in @($unitsOut, $buildingsOut, $techsOut, $skillsOut)) {
	New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

$unitsCsvPath = Join-Path $csvRoot "units_v2_placeholder.csv"
$buildingsCsvPath = Join-Path $csvRoot "buildings_v2_placeholder.csv"
$techsCsvPath = Join-Path $csvRoot "techs_v2_placeholder.csv"
$skillsCsvPath = Join-Path $csvRoot "skills_v2_placeholder.csv"

$unitRows = Import-Csv -Path $unitsCsvPath
$buildingRows = Import-Csv -Path $buildingsCsvPath
$techRows = Import-Csv -Path $techsCsvPath
$skillRows = Import-Csv -Path $skillsCsvPath

$workerLikeUnitIds = @(
	"worker",
	"field_technician",
	"hauler_drone",
	"salvage_truck",
	"gas_siphon_drone",
	"fabrication_drone"
)

# Build lookup helpers for cross-linking.
$unitRowsByProducer = @{}
foreach ($unit in $unitRows) {
	$producers = Split-PipeList $unit.producer_buildings
	foreach ($producer in $producers) {
		if (-not $unitRowsByProducer.ContainsKey($producer)) {
			$unitRowsByProducer[$producer] = @()
		}
		$unitRowsByProducer[$producer] += $unit.id
	}
}

$skillsBySource = @{}
foreach ($skill in $skillRows) {
	$sources = Split-PipeList $skill.source_ids
	foreach ($source in $sources) {
		if (-not $skillsBySource.ContainsKey($source)) {
			$skillsBySource[$source] = @()
		}
		$skillsBySource[$source] += $skill
	}
}

foreach ($unit in $unitRows) {
	$unitId = $unit.id.Trim()
	$displayName = Escape-GdString $unit.display_name
	$roleTag = Get-RoleTagFromId $unitId
	$isWorkerRole = $workerLikeUnitIds -contains $unitId
	$requiresBuildings = Split-PipeList $unit.requires_buildings
	$requiresTech = Split-PipeList $unit.requires_tech

	$baseSkills = @("move", "attack", "stop")
	if ($isWorkerRole) {
		$baseSkills = @("move", "gather", "repair", "return_resource", "stop")
	}
	if ($unitId -eq "worker" -or $unitId -eq "fabrication_drone") {
		if ($baseSkills -notcontains "build_menu") {
			$baseSkills = @("move", "gather", "repair", "return_resource", "build_menu", "stop")
		}
	}

	$buildSkills = @()
	if ($skillsBySource.ContainsKey($unitId)) {
		foreach ($candidate in $skillsBySource[$unitId]) {
			if ($candidate.skill_type -eq "build") {
				$buildSkills += $candidate.id
			}
		}
	}
	$buildSkills = $buildSkills | Select-Object -Unique

	$statsBlock = @()
	if ($isWorkerRole) {
		$statsBlock += '"attack_cooldown": 0.0,'
		$statsBlock += '"attack_damage": 0.0,'
		$statsBlock += '"attack_range": 0.0,'
		$statsBlock += '"carry_capacity": 6,'
		$statsBlock += '"gather_amount": 5,'
		$statsBlock += '"gather_interval": 1.5,'
		$statsBlock += '"max_health": 72.0,'
		$statsBlock += '"move_speed": 5.0'
	}
	else {
		$statsBlock += '"attack_cooldown": 1.0,'
		$statsBlock += '"attack_damage": 16.0,'
		$statsBlock += '"attack_range": 2.6,'
		$statsBlock += '"max_health": 130.0,'
		$statsBlock += '"move_speed": 5.8'
	}

	$unitText = @(
		'[gd_resource type="Resource" script_class="RTSUnitConfig" format=3]',
		'',
		'[ext_resource type="Script" path="res://scripts/core/config/rts_unit_config.gd" id="1"]',
		'',
		'[resource]',
		'script = ExtResource("1")',
		('id = "{0}"' -f $unitId),
		('display_name = "{0}"' -f $displayName),
		('role_tag = "{0}"' -f $roleTag),
		('is_worker_role = {0}' -f ($isWorkerRole.ToString().ToLowerInvariant())),
		'cost = 0',
		'gas_cost = 0',
		'supply = 1',
		'stats = {',
		("`t{0}" -f ($statsBlock -join "`n`t")),
		'}',
		('requires_buildings = {0}' -f (Join-GdVariantArray $requiresBuildings)),
		('requires_tech = {0}' -f (Join-GdStringArray $requiresTech)),
		('skills = {0}' -f (Join-GdStringArray $baseSkills)),
		('build_skills = {0}' -f (Join-GdStringArray $buildSkills))
	) -join "`n"

	$unitPath = Join-Path $unitsOut ("{0}.tres" -f $unitId)
	Write-Utf8NoBom -Path $unitPath -Text $unitText
}

foreach ($building in $buildingRows) {
	$buildingId = $building.id.Trim()
	$displayName = Escape-GdString $building.display_name
	$roleTag = Get-RoleTagFromId $buildingId
	$requiresBuildings = Split-PipeList $building.requires_buildings
	$requiresTech = Split-PipeList $building.requires_tech
	$constructionParadigm = if ([string]::IsNullOrWhiteSpace($building.construction_paradigm)) { "garrisoned" } else { $building.construction_paradigm.Trim() }

	$trainableUnits = @()
	if ($unitRowsByProducer.ContainsKey($buildingId)) {
		$trainableUnits = $unitRowsByProducer[$buildingId] | Select-Object -Unique
	}

	$skills = @()
	$buildSkills = @()
	if ($skillsBySource.ContainsKey($buildingId)) {
		foreach ($candidate in $skillsBySource[$buildingId]) {
			switch ($candidate.skill_type) {
				"train" { $skills += $candidate.id }
				"research" { $skills += $candidate.id }
				"active" { $skills += $candidate.id }
				"build" { $buildSkills += $candidate.id }
			}
		}
	}
	if ($buildingId -eq "base") {
		if ($skills -notcontains "build_menu") {
			$skills += "build_menu"
		}
	}
	$skills = $skills | Select-Object -Unique
	$buildSkills = $buildSkills | Select-Object -Unique

	$trainableDict = "{}"
	if ($trainableUnits.Count -gt 0) {
		$pairs = @()
		foreach ($unitId in $trainableUnits) {
			$pairs += ('"{0}": 5.0' -f $unitId)
		}
		$trainableDict = "{`n`t" + ($pairs -join ",`n`t") + "`n}"
	}

	$canQueueWorker = (@($trainableUnits | Where-Object { $_ -eq "worker" }).Count -gt 0)
	$canQueueSoldier = (@($trainableUnits | Where-Object { $_ -ne "worker" }).Count -gt 0)

	$isResourceDropoff = ($buildingId -eq "base")
	$supplyBonus = if ($buildingId -eq "supply_depot") { 12 } else { 0 }
	$attackRange = if ($buildingId -eq "tower") { 9.2 } else { 0.0 }
	$attackDamage = if ($buildingId -eq "tower") { 15.0 } else { 0.0 }
	$attackCooldown = if ($buildingId -eq "tower") { 0.9 } else { 1.0 }
	$queueLimit = if (@($trainableUnits).Count -gt 0 -or @($skills).Count -gt 0) { 6 } else { 0 }
	$costValue = if ($buildingId -eq "base") { 0 } else { 100 }
	$buildTimeValue = if ($buildingId -eq "base") { "0.0" } else { "6.0" }
	$maxHealthValue = if ($buildingId -eq "base") { "1450.0" } else { "800.0" }

	$buildingText = @(
		'[gd_resource type="Resource" script_class="RTSBuildingConfig" format=3]',
		'',
		'[ext_resource type="Script" path="res://scripts/core/config/rts_building_config.gd" id="1"]',
		'',
		'[resource]',
		'script = ExtResource("1")',
		('id = "{0}"' -f $buildingId),
		('display_name = "{0}"' -f $displayName),
		('role_tag = "{0}"' -f $roleTag),
		('cost = {0}' -f $costValue),
		'gas_cost = 0',
		('construction_paradigm = "{0}"' -f $constructionParadigm),
		('build_time = {0}' -f $buildTimeValue),
		'cancel_refund_ratio = 0.75',
		('max_health = {0}' -f $maxHealthValue),
		('attack_range = {0}' -f $attackRange),
		('attack_damage = {0}' -f $attackDamage),
		('attack_cooldown = {0}' -f $attackCooldown),
		('is_resource_dropoff = {0}' -f ($isResourceDropoff.ToString().ToLowerInvariant())),
		('can_queue_worker = {0}' -f ($canQueueWorker.ToString().ToLowerInvariant())),
		('can_queue_soldier = {0}' -f ($canQueueSoldier.ToString().ToLowerInvariant())),
		'worker_build_time = 3.0',
		'soldier_build_time = 5.0',
		('trainable_units = {0}' -f $trainableDict),
		('queue_limit = {0}' -f $queueLimit),
		'spawn_offset = Vector3(2.8, 0, 0)',
		('supply_bonus = {0}' -f $supplyBonus),
		('requires_buildings = {0}' -f (Join-GdVariantArray $requiresBuildings)),
		('requires_tech = {0}' -f (Join-GdStringArray $requiresTech)),
		('skills = {0}' -f (Join-GdStringArray $skills)),
		('build_skills = {0}' -f (Join-GdStringArray $buildSkills)),
		('extra = {"placeholder_tier": "' + (Escape-GdString $building.tier) + '", "placeholder_category": "' + (Escape-GdString $building.category) + '", "placeholder_status": "' + (Escape-GdString $building.status) + '"}')
	) -join "`n"

	$buildingPath = Join-Path $buildingsOut ("{0}.tres" -f $buildingId)
	Write-Utf8NoBom -Path $buildingPath -Text $buildingText
}

foreach ($tech in $techRows) {
	$techId = $tech.id.Trim()
	$displayName = Escape-GdString $tech.display_name
	$requiresTech = Split-PipeList $tech.requires_tech
	$researchBuildings = Split-PipeList $tech.research_buildings

	$techText = @(
		'[gd_resource type="Resource" script_class="RTSTechConfig" format=3]',
		'',
		'[ext_resource type="Script" path="res://scripts/core/config/rts_tech_config.gd" id="1"]',
		'',
		'[resource]',
		'script = ExtResource("1")',
		('id = "{0}"' -f $techId),
		('display_name = "{0}"' -f $displayName),
		('description = "Placeholder tech generated from expansion CSV."'),
		'cost = 100',
		'gas_cost = 50',
		'research_time = 10.0',
		('requires_buildings = {0}' -f (Join-GdVariantArray $researchBuildings)),
		('requires_tech = {0}' -f (Join-GdStringArray $requiresTech)),
		('extra = {"placeholder_tier": "' + (Escape-GdString $tech.tier) + '", "placeholder_branch": "' + (Escape-GdString $tech.branch) + '", "placeholder_status": "' + (Escape-GdString $tech.status) + '"}')
	) -join "`n"

	$techPath = Join-Path $techsOut ("{0}.tres" -f $techId)
	Write-Utf8NoBom -Path $techPath -Text $techText
}

foreach ($skill in $skillRows) {
	$skillId = $skill.id.Trim()
	$label = Escape-GdString $skill.label
	$targetMode = if ([string]::IsNullOrWhiteSpace($skill.target_mode)) { "none" } else { $skill.target_mode.Trim() }
	$sourceIds = Split-PipeList $skill.source_ids
	$unlockTech = $skill.unlock_tech.Trim()
	$skillType = $skill.skill_type.Trim()

	$buildingKind = ""
	$techId = ""
	$unitKind = ""

	if ($skillType -eq "build" -and $skillId.StartsWith("build_")) {
		$buildingKind = $skillId.Substring(6)
	}
	elseif ($skillType -eq "research") {
		$techId = if ($unlockTech -ne "") { $unlockTech } elseif ($skillId.StartsWith("research_")) { $skillId.Substring(9) } else { "" }
	}
	elseif ($skillType -eq "train" -and $skillId.StartsWith("train_")) {
		$unitKind = $skillId.Substring(6)
	}

	$skillLines = @(
		'[gd_resource type="Resource" script_class="RTSSkillConfig" format=3]',
		'',
		'[ext_resource type="Script" path="res://scripts/core/config/rts_skill_config.gd" id="1"]',
		'',
		'[resource]',
		'script = ExtResource("1")',
		('id = "{0}"' -f $skillId),
		('label = "{0}"' -f $label),
		'icon_path = "res://assets/raw/rts_icons/skills/cmd_train.png"',
		'hotkey = ""',
		('target_mode = "{0}"' -f (Escape-GdString $targetMode))
	)

	if ($buildingKind -ne "") {
		$skillLines += ('building_kind = "{0}"' -f $buildingKind)
	}
	if ($techId -ne "") {
		$skillLines += ('tech_id = "{0}"' -f $techId)
	}
	if ($unitKind -ne "") {
		$skillLines += ('unit_kind = "{0}"' -f $unitKind)
	}
	$skillLines += ('description = "Placeholder skill generated from expansion CSV."')
	$skillLines += ('extra = {"placeholder_skill_type": "' + (Escape-GdString $skillType) + '", "placeholder_sources": "' + (Escape-GdString ($sourceIds -join "|")) + '", "placeholder_status": "' + (Escape-GdString $skill.status) + '"}')

	$skillText = $skillLines -join "`n"
	$skillPath = Join-Path $skillsOut ("{0}.tres" -f $skillId)
	Write-Utf8NoBom -Path $skillPath -Text $skillText
}

# Ensure expansion-only runtime has core build-menu command definition.
$buildMenuSkillPath = Join-Path $skillsOut "build_menu.tres"
if (-not (Test-Path $buildMenuSkillPath)) {
	$buildMenuSkillText = @(
		'[gd_resource type="Resource" script_class="RTSSkillConfig" format=3]',
		'',
		'[ext_resource type="Script" path="res://scripts/core/config/rts_skill_config.gd" id="1"]',
		'',
		'[resource]',
		'script = ExtResource("1")',
		'id = "build_menu"',
		'label = "Build"',
		'icon_path = "res://assets/raw/rts_icons/skills/cmd_build.png"',
		'hotkey = "B"',
		'target_mode = "none"',
		'description = "Open build menu."'
	) -join "`n"
	Write-Utf8NoBom -Path $buildMenuSkillPath -Text $buildMenuSkillText
}

$readmePath = Join-Path $outputRoot "README.md"
$readme = @(
	"# Expansion Placeholder Resources",
	"",
	"This folder is generated by:",
	'`scripts/core/config/generate_expansion_placeholders_from_csv.ps1`',
	"",
	"Source CSV files:",
	'- `docs/content_expansion/placeholders/buildings_v2_placeholder.csv`',
	'- `docs/content_expansion/placeholders/units_v2_placeholder.csv`',
	'- `docs/content_expansion/placeholders/techs_v2_placeholder.csv`',
	'- `docs/content_expansion/placeholders/skills_v2_placeholder.csv`',
	"",
	"Runtime loading behavior is controlled by:",
	'`ProjectSettings["rts/config/catalog_mode"]` in `scripts/core/config/rts_config_registry.gd`',
	"Modes:",
	'- `legacy`: load only `res://config/*`',
	'- `expansion`: load only `res://config_expansion/*`',
	'- `merged`: load `res://config/*` first, then merge in new content from `res://config_expansion/*`',
	"",
	("Generated at: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
) -join "`n"
Write-Utf8NoBom -Path $readmePath -Text $readme

Write-Output ("Generated units: {0}" -f ((Get-ChildItem $unitsOut -Filter "*.tres").Count))
Write-Output ("Generated buildings: {0}" -f ((Get-ChildItem $buildingsOut -Filter "*.tres").Count))
Write-Output ("Generated techs: {0}" -f ((Get-ChildItem $techsOut -Filter "*.tres").Count))
Write-Output ("Generated skills: {0}" -f ((Get-ChildItem $skillsOut -Filter "*.tres").Count))
