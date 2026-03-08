extends RefCounted

const DEFAULT_PROFILE_ID: String = "enemy_default"

const BASE_PROFILE: Dictionary = {
	"tick_rates": {
		"production": 3.0,
		"tactical": 0.85,
		"economy": 1.0,
		"strategy": 1.0
	},
	"production": {
		"max_queue_per_building": 2,
		"orders": [
			{
				"unit_kind": "worker",
				"per_cycle": 1,
				"max_team_units": 8,
				"building_roles": ["base"]
			},
			{
				"unit_kind": "soldier",
				"per_cycle": 1,
				"max_team_units": -1,
				"building_roles": ["barracks", "warp", "vat", "core"]
			}
		]
	},
	"economy": {
		"enabled": true,
		"worker_order_refresh": 7.5,
		"max_resource_search_distance": 38.0,
		"preferred_resource_type": "auto",
		"auto_prefer_gas_below": 120,
		"allow_resource_fallback": true
	},
	"combat": {
		"engagement_mode": "wave",
		"wave_cooldown": 10.0,
		"base_wave_size": 3,
		"growth_step": 1,
		"growth_interval": 75.0,
		"max_wave_size": 14,
		"retreat_ratio": 0.35,
		"rally_distance": 10.0,
		"defense_radius": 18.0,
		"defense_forward_offset": 4.0,
		"harass_min_units": 4,
		"harass_squad_size": 4,
		"all_in_min_units": 8,
		"attack_order_mode": "attack_move",
		"regroup_order_mode": "move",
		"attack_order_refresh": 1.1,
		"regroup_order_refresh": 1.2,
		"target_mode": "structures_first",
		"target_priority_building_kinds": ["base", "barracks", "tower", "*"],
		"fallback_to_units": true,
		"ignore_worker_targets": false,
		"ignore_worker_pressure": true
	},
	"strategy": {
		"enabled": true,
		"min_hold_seconds": 8.0,
		"default_mode_id": "balanced_frontline",
		"modes": [
			{
				"id": "hold_under_pressure",
				"priority": 120,
				"hold_seconds": 9.0,
				"when": {
					"min_enemy_pressure": 3
				},
				"overrides": {
					"production": {
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
								"max_team_units": 7,
								"building_roles": ["base"]
							}
						]
					},
					"combat": {
						"engagement_mode": "defend",
						"target_mode": "units_first",
						"ignore_worker_targets": true,
						"defense_radius": 22.0
					}
				}
			},
			{
				"id": "opening_economy",
				"priority": 90,
				"hold_seconds": 10.0,
				"when": {
					"max_match_time": 120,
					"max_team_workers": 8
				},
				"overrides": {
					"production": {
						"orders": [
							{
								"unit_kind": "worker",
								"per_cycle": 2,
								"max_team_units": 10,
								"building_roles": ["base"]
							},
							{
								"unit_kind": "soldier",
								"per_cycle": 1,
								"max_team_units": -1,
								"building_roles": ["barracks", "warp", "vat", "core"]
							}
						]
					},
					"combat": {
						"engagement_mode": "defend",
						"target_mode": "units_first",
						"wave_cooldown": 13.0,
						"base_wave_size": 4
					}
				}
			},
			{
				"id": "balanced_frontline",
				"priority": 60,
				"when": {
					"min_match_time": 90
				},
				"overrides": {
					"production": {
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
								"max_team_units": 10,
								"building_roles": ["base"]
							}
						]
					},
					"combat": {
						"engagement_mode": "wave",
						"target_mode": "structures_first"
					}
				}
			},
			{
				"id": "closing_all_in",
				"priority": 80,
				"hold_seconds": 16.0,
				"when": {
					"min_match_time": 420,
					"min_team_combat_units": 8
				},
				"overrides": {
					"production": {
						"orders": [
							{
								"unit_kind": "soldier",
								"per_cycle": 3,
								"max_team_units": -1,
								"building_roles": ["barracks", "warp", "vat", "core"]
							}
						]
					},
					"combat": {
						"engagement_mode": "all_in",
						"all_in_min_units": 8,
						"retreat_ratio": 0.18,
						"target_mode": "structures_first",
						"ignore_worker_targets": true
					}
				}
			}
		]
	}
}

const PROFILE_OVERRIDES: Dictionary = {
	"enemy_default": {},
	"enemy_rush": {
		"tick_rates": {
			"production": 2.2,
			"tactical": 0.6,
			"economy": 0.9,
			"strategy": 0.75
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
		"combat": {
			"wave_cooldown": 6.0,
			"base_wave_size": 2,
			"max_wave_size": 15,
			"retreat_ratio": 0.28,
			"rally_distance": 8.0,
			"target_mode": "workers_first"
		},
		"strategy": {
			"default_mode_id": "rush_window",
			"modes": [
				{
					"id": "rush_window",
					"priority": 100,
					"hold_seconds": 7.0,
					"when": {
						"max_match_time": 220
					},
					"overrides": {
						"production": {
							"orders": [
								{
									"unit_kind": "soldier",
									"per_cycle": 3,
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
						"combat": {
							"engagement_mode": "harass",
							"target_mode": "workers_first",
							"harass_min_units": 3,
							"harass_squad_size": 5,
							"wave_cooldown": 4.5
						}
					}
				},
				{
					"id": "rush_counter_defense",
					"priority": 130,
					"hold_seconds": 8.0,
					"when": {
						"min_enemy_pressure": 4
					},
					"overrides": {
						"combat": {
							"engagement_mode": "defend",
							"target_mode": "units_first",
							"ignore_worker_targets": true
						}
					}
				},
				{
					"id": "rush_finish_all_in",
					"priority": 85,
					"hold_seconds": 14.0,
					"when": {
						"min_match_time": 260,
						"min_team_combat_units": 6
					},
					"overrides": {
						"combat": {
							"engagement_mode": "all_in",
							"all_in_min_units": 6,
							"retreat_ratio": 0.15
						}
					}
				}
			]
		}
	},
	"enemy_turtle": {
		"tick_rates": {
			"production": 3.8,
			"tactical": 1.0,
			"economy": 1.1,
			"strategy": 1.1
		},
		"production": {
			"max_queue_per_building": 3,
			"orders": [
				{
					"unit_kind": "worker",
					"per_cycle": 1,
					"max_team_units": 10,
					"building_roles": ["base"]
				},
				{
					"unit_kind": "soldier",
					"per_cycle": 1,
					"max_team_units": 24,
					"building_roles": ["barracks", "warp", "vat", "core"]
				}
			]
		},
		"combat": {
			"engagement_mode": "defend",
			"wave_cooldown": 14.0,
			"base_wave_size": 5,
			"max_wave_size": 18,
			"retreat_ratio": 0.45,
			"defense_radius": 24.0,
			"target_mode": "units_first"
		},
		"strategy": {
			"default_mode_id": "fortify_opening",
			"modes": [
				{
					"id": "fortify_opening",
					"priority": 95,
					"hold_seconds": 12.0,
					"when": {
						"max_match_time": 260
					},
					"overrides": {
						"combat": {
							"engagement_mode": "defend",
							"target_mode": "units_first",
							"defense_radius": 26.0
						}
					}
				},
				{
					"id": "counter_punch",
					"priority": 130,
					"hold_seconds": 8.0,
					"when": {
						"min_enemy_pressure": 5
					},
					"overrides": {
						"production": {
							"orders": [
								{
									"unit_kind": "soldier",
									"per_cycle": 2,
									"max_team_units": -1,
									"building_roles": ["barracks", "warp", "vat", "core"]
								}
							]
						},
						"combat": {
							"engagement_mode": "defend",
							"target_mode": "units_first"
						}
					}
				},
				{
					"id": "late_breakout",
					"priority": 80,
					"hold_seconds": 14.0,
					"when": {
						"min_match_time": 360,
						"min_team_combat_units": 10
					},
					"overrides": {
						"combat": {
							"engagement_mode": "wave",
							"base_wave_size": 6,
							"wave_cooldown": 9.0,
							"target_mode": "structures_first"
						}
					}
				}
			]
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
