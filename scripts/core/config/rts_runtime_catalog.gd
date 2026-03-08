extends RefCounted

const RTS_CONFIG_REGISTRY: Script = preload("res://scripts/core/config/rts_config_registry.gd")

const DEFAULT_UNLOCKED_TECHS: Array[String] = []

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
	var registry_def: Dictionary = RTS_CONFIG_REGISTRY.get_unit_def(unit_kind)
	if registry_def.is_empty():
		return {}
	return _localize_dict_fields(registry_def, ["display_name"])

static func get_building_def(building_kind: String) -> Dictionary:
	var registry_def: Dictionary = RTS_CONFIG_REGISTRY.get_building_def(building_kind)
	if registry_def.is_empty():
		return {}
	return _localize_dict_fields(registry_def, ["display_name"])

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

static func get_unit_cost(unit_kind: String) -> int:
	var unit_def: Dictionary = get_unit_def(unit_kind)
	return maxi(0, int(unit_def.get("cost", 0)))

static func get_unit_gas_cost(unit_kind: String) -> int:
	var unit_def: Dictionary = get_unit_def(unit_kind)
	return maxi(0, int(unit_def.get("gas_cost", 0)))

static func get_unit_costs(unit_kind: String) -> Dictionary:
	return {
		"minerals": get_unit_cost(unit_kind),
		"gas": get_unit_gas_cost(unit_kind)
	}

static func get_building_cost(building_kind: String) -> int:
	var building_def: Dictionary = get_building_def(building_kind)
	return maxi(0, int(building_def.get("cost", 0)))

static func get_building_gas_cost(building_kind: String) -> int:
	var building_def: Dictionary = get_building_def(building_kind)
	return maxi(0, int(building_def.get("gas_cost", 0)))

static func get_building_costs(building_kind: String) -> Dictionary:
	return {
		"minerals": get_building_cost(building_kind),
		"gas": get_building_gas_cost(building_kind)
	}

static func get_tech_def(tech_id: String) -> Dictionary:
	var registry_def: Dictionary = RTS_CONFIG_REGISTRY.get_tech_def(tech_id)
	if registry_def.is_empty():
		return {}
	return _localize_dict_fields(registry_def, ["display_name", "description"])

static func get_tech_cost(tech_id: String) -> int:
	var tech_def: Dictionary = get_tech_def(tech_id)
	return maxi(0, int(tech_def.get("cost", 0)))

static func get_tech_gas_cost(tech_id: String) -> int:
	var tech_def: Dictionary = get_tech_def(tech_id)
	return maxi(0, int(tech_def.get("gas_cost", 0)))

static func get_tech_costs(tech_id: String) -> Dictionary:
	return {
		"minerals": get_tech_cost(tech_id),
		"gas": get_tech_gas_cost(tech_id)
	}

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
			result.append(_localize_dict_fields((rule_value as Dictionary).duplicate(true), ["notice"]))
	return result

static func get_skill_def(skill_id: String) -> Dictionary:
	var registry_def: Dictionary = RTS_CONFIG_REGISTRY.get_skill_def(skill_id)
	if registry_def.is_empty():
		return {}
	return _localize_dict_fields(registry_def, ["label", "description"])

static func make_command_entry(skill_id: String, overrides: Dictionary = {}) -> Dictionary:
	var entry: Dictionary = get_skill_def(skill_id)
	if entry.is_empty():
		entry = {
			"id": skill_id,
			"label": _translate_text(skill_id.capitalize()),
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

static func get_unit_kind_from_skill(skill_id: String) -> String:
	var skill_def: Dictionary = get_skill_def(skill_id)
	return str(skill_def.get("unit_kind", ""))

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

static func _localize_dict_fields(source: Dictionary, fields: Array[String]) -> Dictionary:
	for field in fields:
		if not source.has(field):
			continue
		source[field] = _translate_text(str(source.get(field, "")))
	return source

static func _translate_text(message: String) -> String:
	if message == "":
		return ""
	return TranslationServer.translate(message)
