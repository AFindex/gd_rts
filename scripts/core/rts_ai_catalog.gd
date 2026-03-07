extends RefCounted

const DEFAULT_PROFILE_ID: String = "enemy_default"

const BASE_PROFILE: Dictionary = {
	"tick_rates": {
		"production": 3.2,
		"tactical": 0.9,
		"economy": 1.1
	},
	"production": {
		"max_queue_per_building": 2,
		"orders": [
			{
				"unit_kind": "soldier",
				"per_cycle": 1,
				"max_team_units": -1,
				"building_roles": ["barracks", "warp", "vat", "core"]
			},
			{
				"unit_kind": "worker",
				"per_cycle": 1,
				"max_team_units": 8,
				"building_roles": ["base"]
			}
		]
	},
	"economy": {
		"enabled": true,
		"worker_order_refresh": 8.0,
		"max_resource_search_distance": 36.0
	},
	"combat": {
		"wave_cooldown": 10.0,
		"base_wave_size": 3,
		"growth_step": 1,
		"growth_interval": 75.0,
		"max_wave_size": 12,
		"retreat_ratio": 0.35,
		"rally_distance": 10.0,
		"attack_order_mode": "attack_move",
		"regroup_order_mode": "move",
		"attack_order_refresh": 1.2,
		"regroup_order_refresh": 1.2,
		"target_priority_building_kinds": ["base", "barracks", "tower", "*"],
		"fallback_to_units": true,
		"ignore_worker_targets": false
	}
}

const PROFILE_OVERRIDES: Dictionary = {
	"enemy_default": {},
	"enemy_rush": {
		"tick_rates": {
			"production": 2.4,
			"tactical": 0.65,
			"economy": 0.95
		},
		"production": {
			"max_queue_per_building": 2,
			"orders": [
				{
					"unit_kind": "soldier",
					"per_cycle": 2,
					"max_team_units": -1,
					"building_roles": ["barracks", "warp", "vat", "core"]
				},
				{
					"unit_kind": "worker",
					"per_cycle": 1,
					"max_team_units": 6,
					"building_roles": ["base"]
				}
			]
		},
		"economy": {
			"enabled": true,
			"worker_order_refresh": 6.0,
			"max_resource_search_distance": 34.0
		},
		"combat": {
			"wave_cooldown": 6.5,
			"base_wave_size": 2,
			"growth_step": 1,
			"growth_interval": 55.0,
			"max_wave_size": 14,
			"retreat_ratio": 0.3,
			"rally_distance": 8.0,
			"attack_order_mode": "attack_move",
			"regroup_order_mode": "attack_move",
			"attack_order_refresh": 0.9,
			"regroup_order_refresh": 0.7,
			"target_priority_building_kinds": ["base", "*"],
			"fallback_to_units": true,
			"ignore_worker_targets": true
		}
	},
	"enemy_turtle": {
		"tick_rates": {
			"production": 4.0,
			"tactical": 1.0,
			"economy": 1.2
		},
		"production": {
			"max_queue_per_building": 3,
			"orders": [
				{
					"unit_kind": "soldier",
					"per_cycle": 1,
					"max_team_units": 20,
					"building_roles": ["barracks", "warp", "vat", "core"]
				},
				{
					"unit_kind": "worker",
					"per_cycle": 1,
					"max_team_units": 10,
					"building_roles": ["base"]
				}
			]
		},
		"economy": {
			"enabled": true,
			"worker_order_refresh": 10.0,
			"max_resource_search_distance": 40.0
		},
		"combat": {
			"wave_cooldown": 14.0,
			"base_wave_size": 5,
			"growth_step": 1,
			"growth_interval": 120.0,
			"max_wave_size": 16,
			"retreat_ratio": 0.45,
			"rally_distance": 12.0,
			"attack_order_mode": "attack_move",
			"regroup_order_mode": "move",
			"attack_order_refresh": 1.5,
			"regroup_order_refresh": 1.6,
			"target_priority_building_kinds": ["tower", "barracks", "base", "*"],
			"fallback_to_units": true,
			"ignore_worker_targets": false
		}
	}
}

static func get_profile(profile_id: String) -> Dictionary:
	var resolved_id: String = _normalize_profile_id(profile_id)
	var profile: Dictionary = BASE_PROFILE.duplicate(true)
	var override_value: Variant = PROFILE_OVERRIDES.get(resolved_id, {})
	if override_value is Dictionary:
		_deep_merge(profile, override_value as Dictionary)
	return profile

static func has_profile(profile_id: String) -> bool:
	var resolved_id: String = _normalize_profile_id(profile_id)
	return PROFILE_OVERRIDES.has(resolved_id)

static func get_profile_ids() -> Array[String]:
	var ids: Array[String] = []
	for key_value in PROFILE_OVERRIDES.keys():
		ids.append(str(key_value))
	ids.sort()
	return ids

static func _normalize_profile_id(profile_id: String) -> String:
	var normalized: String = profile_id.strip_edges().to_lower()
	if normalized == "":
		return DEFAULT_PROFILE_ID
	return normalized

static func _deep_merge(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		var source_value: Variant = source[key]
		if target.has(key) and target[key] is Dictionary and source_value is Dictionary:
			var nested_target: Dictionary = (target[key] as Dictionary).duplicate(true)
			_deep_merge(nested_target, source_value as Dictionary)
			target[key] = nested_target
		else:
			target[key] = _duplicate_variant(source_value)

static func _duplicate_variant(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value
