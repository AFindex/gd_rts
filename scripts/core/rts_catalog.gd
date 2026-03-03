extends RefCounted

const ICON_ROOT_SKILLS: String = "res://assets/raw/rts_icons/skills/"
const ICON_ROOT_UI: String = "res://assets/raw/rts_icons/ui_actions/"
const ICON_ROOT_BUILDINGS: String = "res://assets/raw/rts_icons/buildings/"
const ICON_TMP_BUILD: String = "res://icon_build_tmp.png"

const UNIT_DEFS: Dictionary = {
	"worker": {
		"display_name": "Worker",
		"role_tag": "W",
		"cost": 50,
		"supply": 1,
		"max_health": 60.0,
		"move_speed": 6.0,
		"gather_range": 1.8,
		"dropoff_range": 2.4,
		"carry_capacity": 24,
		"gather_amount": 4,
		"gather_interval": 0.55,
		"attack_damage": 0.0,
		"attack_range": 0.0,
		"attack_cooldown": 0.0,
		"requires_buildings": ["base"],
		"requires_tech": [],
		"skills": ["move", "gather", "return_resource", "build_menu", "stop"],
		"build_skills": ["build_barracks", "build_tower", "build_academy", "build_engineering_bay", "build_tech_lab"]
	},
	"soldier": {
		"display_name": "Soldier",
		"role_tag": "S",
		"cost": 70,
		"supply": 1,
		"max_health": 100.0,
		"move_speed": 6.2,
		"attack_damage": 12.0,
		"attack_range": 2.4,
		"attack_cooldown": 0.8,
		"requires_buildings": ["barracks"],
		"requires_tech": [],
		"skills": ["move", "attack", "stop"],
		"build_skills": []
	}
}

const BUILDING_DEFS: Dictionary = {
	"base": {
		"display_name": "Main Base",
		"role_tag": "Base",
		"max_health": 1400.0,
		"attack_range": 0.0,
		"attack_damage": 0.0,
		"attack_cooldown": 1.0,
		"is_resource_dropoff": true,
		"can_queue_worker": true,
		"can_queue_soldier": false,
		"worker_build_time": 2.8,
		"soldier_build_time": 0.0,
		"queue_limit": 6,
		"spawn_offset": Vector3(3.2, 0.0, 0.0),
		"requires_buildings": [],
		"requires_tech": [],
		"skills": ["train_worker", "build_menu"],
		"build_skills": ["build_barracks", "build_tower", "build_academy", "build_engineering_bay", "build_tech_lab"]
	},
	"barracks": {
		"display_name": "Barracks",
		"role_tag": "Barracks",
		"cost": 160,
		"max_health": 900.0,
		"attack_range": 0.0,
		"attack_damage": 0.0,
		"attack_cooldown": 1.0,
		"is_resource_dropoff": false,
		"can_queue_worker": false,
		"can_queue_soldier": true,
		"worker_build_time": 0.0,
		"soldier_build_time": 4.0,
		"queue_limit": 8,
		"spawn_offset": Vector3(3.6, 0.0, 0.0),
		"requires_buildings": ["base"],
		"requires_tech": [],
		"skills": ["train_soldier"],
		"build_skills": []
	},
	"tower": {
		"display_name": "Tower",
		"role_tag": "Tower",
		"cost": 120,
		"max_health": 700.0,
		"attack_range": 9.0,
		"attack_damage": 14.0,
		"attack_cooldown": 0.9,
		"is_resource_dropoff": false,
		"can_queue_worker": false,
		"can_queue_soldier": false,
		"worker_build_time": 0.0,
		"soldier_build_time": 0.0,
		"queue_limit": 0,
		"spawn_offset": Vector3(2.8, 0.0, 0.0),
		"requires_buildings": ["base", "barracks"],
		"requires_tech": [],
		"skills": [],
		"build_skills": []
	},
	"academy": {
		"display_name": "Academy",
		"role_tag": "Academy",
		"cost": 150,
		"max_health": 780.0,
		"attack_range": 0.0,
		"attack_damage": 0.0,
		"attack_cooldown": 1.0,
		"is_resource_dropoff": false,
		"can_queue_worker": false,
		"can_queue_soldier": false,
		"worker_build_time": 0.0,
		"soldier_build_time": 0.0,
		"queue_limit": 0,
		"spawn_offset": Vector3(2.8, 0.0, 0.0),
		"requires_buildings": ["base"],
		"requires_tech": [],
		"skills": ["research_infantry_weapons_1", "research_infantry_armor_1"],
		"build_skills": []
	},
	"engineering_bay": {
		"display_name": "Engineering Bay",
		"role_tag": "EngBay",
		"cost": 180,
		"max_health": 820.0,
		"attack_range": 0.0,
		"attack_damage": 0.0,
		"attack_cooldown": 1.0,
		"is_resource_dropoff": false,
		"can_queue_worker": false,
		"can_queue_soldier": false,
		"worker_build_time": 0.0,
		"soldier_build_time": 0.0,
		"queue_limit": 0,
		"spawn_offset": Vector3(2.8, 0.0, 0.0),
		"requires_buildings": ["base", "academy"],
		"requires_tech": [],
		"skills": ["research_field_logistics"],
		"build_skills": []
	},
	"tech_lab": {
		"display_name": "Tech Lab",
		"role_tag": "TechLab",
		"cost": 210,
		"max_health": 860.0,
		"attack_range": 0.0,
		"attack_damage": 0.0,
		"attack_cooldown": 1.0,
		"is_resource_dropoff": false,
		"can_queue_worker": false,
		"can_queue_soldier": false,
		"worker_build_time": 0.0,
		"soldier_build_time": 0.0,
		"queue_limit": 0,
		"spawn_offset": Vector3(2.8, 0.0, 0.0),
		"requires_buildings": ["base", "engineering_bay"],
		"requires_tech": ["field_logistics"],
		"skills": ["research_advanced_targeting"],
		"build_skills": []
	}
}

const TECH_DEFS: Dictionary = {
	"infantry_weapons_1": {
		"display_name": "Infantry Weapons I",
		"description": "Improves infantry firepower.",
		"cost": 140,
		"research_time": 9.0,
		"requires_buildings": ["academy"],
		"requires_tech": []
	},
	"infantry_armor_1": {
		"display_name": "Infantry Armor I",
		"description": "Improves infantry survivability.",
		"cost": 130,
		"research_time": 8.0,
		"requires_buildings": ["academy"],
		"requires_tech": []
	},
	"field_logistics": {
		"display_name": "Field Logistics",
		"description": "Optimizes frontline throughput.",
		"cost": 160,
		"research_time": 10.0,
		"requires_buildings": ["engineering_bay"],
		"requires_tech": []
	},
	"advanced_targeting": {
		"display_name": "Advanced Targeting",
		"description": "Enables better target acquisition.",
		"cost": 200,
		"research_time": 12.0,
		"requires_buildings": ["tech_lab"],
		"requires_tech": ["infantry_weapons_1", "field_logistics"]
	}
}

const DEFAULT_UNLOCKED_TECHS: Array[String] = []

const SKILL_DEFS: Dictionary = {
	"move": {
		"id": "move",
		"label": "Move",
		"icon_path": ICON_ROOT_SKILLS + "cmd_move.png",
		"hotkey": "RMB",
		"target_mode": "ground"
	},
	"attack": {
		"id": "attack",
		"label": "Attack",
		"icon_path": ICON_ROOT_SKILLS + "cmd_attack.png",
		"hotkey": "A",
		"target_mode": "unit_or_building"
	},
	"stop": {
		"id": "stop",
		"label": "Stop",
		"icon_path": ICON_ROOT_SKILLS + "cmd_stop.png",
		"hotkey": "S",
		"target_mode": "none"
	},
	"gather": {
		"id": "gather",
		"label": "Gather",
		"icon_path": ICON_ROOT_SKILLS + "cmd_gather.png",
		"hotkey": "",
		"target_mode": "resource"
	},
	"return_resource": {
		"id": "return_resource",
		"label": "Return",
		"icon_path": ICON_ROOT_SKILLS + "cmd_return.png",
		"hotkey": "",
		"target_mode": "none"
	},
	"build_menu": {
		"id": "build_menu",
		"label": "Build",
		"icon_path": ICON_ROOT_SKILLS + "cmd_build.png",
		"hotkey": "B",
		"target_mode": "none"
	},
	"build_barracks": {
		"id": "build_barracks",
		"label": "Barracks",
		"icon_path": ICON_ROOT_BUILDINGS + "building_barracks.png",
		"hotkey": "Q",
		"target_mode": "placement",
		"building_kind": "barracks"
	},
	"build_tower": {
		"id": "build_tower",
		"label": "Tower",
		"icon_path": ICON_ROOT_BUILDINGS + "building_tower.png",
		"hotkey": "W",
		"target_mode": "placement",
		"building_kind": "tower"
	},
	"build_academy": {
		"id": "build_academy",
		"label": "Academy",
		"icon_path": ICON_TMP_BUILD,
		"hotkey": "E",
		"target_mode": "placement",
		"building_kind": "academy"
	},
	"build_engineering_bay": {
		"id": "build_engineering_bay",
		"label": "Eng Bay",
		"icon_path": ICON_TMP_BUILD,
		"hotkey": "D",
		"target_mode": "placement",
		"building_kind": "engineering_bay"
	},
	"build_tech_lab": {
		"id": "build_tech_lab",
		"label": "Tech Lab",
		"icon_path": ICON_TMP_BUILD,
		"hotkey": "C",
		"target_mode": "placement",
		"building_kind": "tech_lab"
	},
	"close_menu": {
		"id": "close_menu",
		"label": "Back",
		"icon_path": ICON_ROOT_UI + "ui_close_back.png",
		"hotkey": "ESC",
		"target_mode": "none"
	},
	"placement_confirm": {
		"id": "placement_confirm",
		"label": "Confirm Build",
		"icon_path": ICON_ROOT_SKILLS + "cmd_build.png",
		"hotkey": "LMB",
		"target_mode": "none"
	},
	"placement_rotate": {
		"id": "placement_rotate",
		"label": "Rotate",
		"icon_path": ICON_ROOT_UI + "ui_hold.png",
		"hotkey": "R",
		"target_mode": "none"
	},
	"placement_cancel": {
		"id": "placement_cancel",
		"label": "Cancel",
		"icon_path": ICON_ROOT_UI + "ui_close_back.png",
		"hotkey": "ESC",
		"target_mode": "none"
	},
	"train_worker": {
		"id": "train_worker",
		"label": "Train Worker",
		"icon_path": ICON_ROOT_SKILLS + "cmd_train.png",
		"hotkey": "R",
		"target_mode": "none"
	},
	"train_soldier": {
		"id": "train_soldier",
		"label": "Train Soldier",
		"icon_path": ICON_ROOT_SKILLS + "cmd_train.png",
		"hotkey": "T",
		"target_mode": "none"
	},
	"research_infantry_weapons_1": {
		"id": "research_infantry_weapons_1",
		"label": "Weapons I",
		"icon_path": ICON_ROOT_SKILLS + "cmd_train.png",
		"hotkey": "Z",
		"target_mode": "none",
		"tech_id": "infantry_weapons_1"
	},
	"research_infantry_armor_1": {
		"id": "research_infantry_armor_1",
		"label": "Armor I",
		"icon_path": ICON_ROOT_SKILLS + "cmd_train.png",
		"hotkey": "X",
		"target_mode": "none",
		"tech_id": "infantry_armor_1"
	},
	"research_field_logistics": {
		"id": "research_field_logistics",
		"label": "Logistics",
		"icon_path": ICON_ROOT_SKILLS + "cmd_train.png",
		"hotkey": "V",
		"target_mode": "none",
		"tech_id": "field_logistics"
	},
	"research_advanced_targeting": {
		"id": "research_advanced_targeting",
		"label": "Targeting",
		"icon_path": ICON_ROOT_SKILLS + "cmd_train.png",
		"hotkey": "G",
		"target_mode": "none",
		"tech_id": "advanced_targeting"
	},
	"menu": {
		"id": "menu",
		"label": "Menu",
		"icon_path": ICON_ROOT_UI + "ui_hold.png",
		"hotkey": "F10",
		"target_mode": "none"
	}
}

const MATCH_SETTINGS: Dictionary = {
	"rule_check_interval": 0.25,
	"notify_only": true
}

const MATCH_RULE_DEFS: Array[Dictionary] = [
	{
		"id": "player_defeat_base_lost",
		"watch_group": "selectable_building",
		"team_id": 1,
		"building_kind": "base",
		"trigger_at_or_below": 0,
		"notice": "[DEFEAT] Main Base destroyed (test notice)."
	},
	{
		"id": "player_victory_enemy_core_lost",
		"watch_group": "selectable_building",
		"team_id": 2,
		"building_kind": "barracks",
		"trigger_at_or_below": 0,
		"notice": "[VICTORY] Enemy core destroyed (test notice)."
	}
]

static func get_unit_def(unit_kind: String) -> Dictionary:
	var value: Variant = UNIT_DEFS.get(unit_kind, {})
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}

static func get_building_def(building_kind: String) -> Dictionary:
	var value: Variant = BUILDING_DEFS.get(building_kind, {})
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}

static func get_unit_skill_ids(unit_kind: String) -> Array[String]:
	var unit_def: Dictionary = get_unit_def(unit_kind)
	return _normalize_skill_ids(unit_def.get("skills", []))

static func get_building_skill_ids(building_kind: String) -> Array[String]:
	var building_def: Dictionary = get_building_def(building_kind)
	return _normalize_skill_ids(building_def.get("skills", []))

static func get_unit_build_skill_ids(unit_kind: String) -> Array[String]:
	var unit_def: Dictionary = get_unit_def(unit_kind)
	return _normalize_skill_ids(unit_def.get("build_skills", []))

static func get_building_build_skill_ids(building_kind: String) -> Array[String]:
	var building_def: Dictionary = get_building_def(building_kind)
	return _normalize_skill_ids(building_def.get("build_skills", []))

static func get_unit_requires_buildings(unit_kind: String) -> Array[Dictionary]:
	var unit_def: Dictionary = get_unit_def(unit_kind)
	return _normalize_building_requirements(unit_def.get("requires_buildings", []))

static func get_unit_requires_tech(unit_kind: String) -> Array[String]:
	var unit_def: Dictionary = get_unit_def(unit_kind)
	return _normalize_tech_ids(unit_def.get("requires_tech", []))

static func get_building_requires_buildings(building_kind: String) -> Array[Dictionary]:
	var building_def: Dictionary = get_building_def(building_kind)
	return _normalize_building_requirements(building_def.get("requires_buildings", []))

static func get_building_requires_tech(building_kind: String) -> Array[String]:
	var building_def: Dictionary = get_building_def(building_kind)
	return _normalize_tech_ids(building_def.get("requires_tech", []))

static func get_tech_def(tech_id: String) -> Dictionary:
	var value: Variant = TECH_DEFS.get(tech_id, {})
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}

static func get_tech_cost(tech_id: String) -> int:
	var tech_def: Dictionary = get_tech_def(tech_id)
	return int(tech_def.get("cost", 0))

static func get_tech_research_time(tech_id: String) -> float:
	var tech_def: Dictionary = get_tech_def(tech_id)
	return maxf(0.0, float(tech_def.get("research_time", 0.0)))

static func get_tech_requires_buildings(tech_id: String) -> Array[Dictionary]:
	var tech_def: Dictionary = get_tech_def(tech_id)
	return _normalize_building_requirements(tech_def.get("requires_buildings", []))

static func get_tech_requires_tech(tech_id: String) -> Array[String]:
	var tech_def: Dictionary = get_tech_def(tech_id)
	return _normalize_tech_ids(tech_def.get("requires_tech", []))

static func get_default_unlocked_techs() -> Array[String]:
	return _normalize_tech_ids(DEFAULT_UNLOCKED_TECHS)

static func get_match_settings() -> Dictionary:
	return MATCH_SETTINGS.duplicate(true)

static func get_match_rule_defs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for rule_value in MATCH_RULE_DEFS:
		if rule_value is Dictionary:
			result.append((rule_value as Dictionary).duplicate(true))
	return result

static func get_skill_def(skill_id: String) -> Dictionary:
	var value: Variant = SKILL_DEFS.get(skill_id, {})
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}

static func make_command_entry(skill_id: String, overrides: Dictionary = {}) -> Dictionary:
	var entry: Dictionary = get_skill_def(skill_id)
	if entry.is_empty():
		entry = {
			"id": skill_id,
			"label": skill_id.capitalize(),
			"icon_path": "",
			"hotkey": "",
			"target_mode": "none"
		}
	for key in overrides.keys():
		entry[key] = overrides[key]
	if not entry.has("id"):
		entry["id"] = skill_id
	if not entry.has("enabled"):
		entry["enabled"] = true
	return entry

static func get_build_kind_from_skill(skill_id: String) -> String:
	var skill_def: Dictionary = get_skill_def(skill_id)
	return str(skill_def.get("building_kind", ""))

static func get_tech_id_from_skill(skill_id: String) -> String:
	var skill_def: Dictionary = get_skill_def(skill_id)
	return str(skill_def.get("tech_id", ""))

static func _normalize_skill_ids(raw_value: Variant) -> Array[String]:
	var skill_ids: Array[String] = []
	if raw_value is Array:
		for value in raw_value:
			var skill_id: String = str(value)
			if skill_id == "":
				continue
			skill_ids.append(skill_id)
	return skill_ids

static func _normalize_tech_ids(raw_value: Variant) -> Array[String]:
	var tech_ids: Array[String] = []
	if raw_value is Array:
		for value in raw_value:
			var tech_id: String = str(value).strip_edges()
			if tech_id == "":
				continue
			tech_ids.append(tech_id)
	return tech_ids

static func _normalize_building_requirements(raw_value: Variant) -> Array[Dictionary]:
	var requirements: Array[Dictionary] = []
	if not (raw_value is Array):
		return requirements
	for raw_item in raw_value:
		var kind: String = ""
		var required_count: int = 1
		if raw_item is Dictionary:
			var item: Dictionary = raw_item as Dictionary
			kind = str(item.get("kind", item.get("building_kind", ""))).strip_edges()
			required_count = maxi(1, int(item.get("count", item.get("required_count", 1))))
		else:
			kind = str(raw_item).strip_edges()
		if kind == "":
			continue
		requirements.append({
			"kind": kind,
			"count": required_count
		})
	return requirements
