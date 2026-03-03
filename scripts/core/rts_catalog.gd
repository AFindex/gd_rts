extends RefCounted

const ICON_ROOT_SKILLS: String = "res://assets/raw/rts_icons/skills/"
const ICON_ROOT_UI: String = "res://assets/raw/rts_icons/ui_actions/"
const ICON_ROOT_BUILDINGS: String = "res://assets/raw/rts_icons/buildings/"

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
		"skills": ["move", "gather", "return_resource", "build_menu", "stop"]
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
		"skills": ["move", "attack", "stop"]
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
		"spawn_offset": Vector3(3.2, 0.0, 0.0),
		"skills": ["train_worker", "build_menu"]
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
		"spawn_offset": Vector3(3.6, 0.0, 0.0),
		"skills": ["train_soldier"]
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
		"spawn_offset": Vector3(2.8, 0.0, 0.0),
		"skills": []
	}
}

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
		"target_mode": "placement"
	},
	"build_tower": {
		"id": "build_tower",
		"label": "Tower",
		"icon_path": ICON_ROOT_BUILDINGS + "building_tower.png",
		"hotkey": "W",
		"target_mode": "placement"
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
	"menu": {
		"id": "menu",
		"label": "Menu",
		"icon_path": ICON_ROOT_UI + "ui_hold.png",
		"hotkey": "F10",
		"target_mode": "none"
	}
}

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
