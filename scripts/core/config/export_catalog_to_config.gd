extends SceneTree

const REGISTRY: Script = preload("res://scripts/core/config/rts_config_registry.gd")
const UNIT_CONFIG_SCRIPT: Script = preload("res://scripts/core/config/rts_unit_config.gd")
const BUILDING_CONFIG_SCRIPT: Script = preload("res://scripts/core/config/rts_building_config.gd")
const TECH_CONFIG_SCRIPT: Script = preload("res://scripts/core/config/rts_tech_config.gd")
const SKILL_CONFIG_SCRIPT: Script = preload("res://scripts/core/config/rts_skill_config.gd")

const UNIT_DIR: String = "res://config/units"
const BUILDING_DIR: String = "res://config/buildings"
const TECH_DIR: String = "res://config/techs"
const SKILL_DIR: String = "res://config/skills"

const UNIT_KNOWN_KEYS: Array[String] = [
	"display_name",
	"role_tag",
	"is_worker_role",
	"cost",
	"gas_cost",
	"supply",
	"requires_buildings",
	"requires_tech",
	"skills",
	"build_skills"
]

const BUILDING_KNOWN_KEYS: Array[String] = [
	"display_name",
	"role_tag",
	"cost",
	"gas_cost",
	"construction_paradigm",
	"build_time",
	"cancel_refund_ratio",
	"max_health",
	"attack_range",
	"attack_damage",
	"attack_cooldown",
	"is_resource_dropoff",
	"can_queue_worker",
	"can_queue_soldier",
	"worker_build_time",
	"soldier_build_time",
	"trainable_units",
	"queue_limit",
	"spawn_offset",
	"supply_bonus",
	"requires_buildings",
	"requires_tech",
	"skills",
	"build_skills"
]

const TECH_KNOWN_KEYS: Array[String] = [
	"display_name",
	"description",
	"cost",
	"gas_cost",
	"research_time",
	"requires_buildings",
	"requires_tech"
]

const SKILL_KNOWN_KEYS: Array[String] = [
	"id",
	"label",
	"icon_path",
	"hotkey",
	"target_mode",
	"building_kind",
	"tech_id",
	"unit_kind",
	"queue_idle_dispatch",
	"description"
]

func _init() -> void:
	REGISTRY.reload()
	_ensure_dir(UNIT_DIR)
	_ensure_dir(BUILDING_DIR)
	_ensure_dir(TECH_DIR)
	_ensure_dir(SKILL_DIR)

	var unit_count: int = _export_units()
	var building_count: int = _export_buildings()
	var tech_count: int = _export_techs()
	var skill_count: int = _export_skills()

	print("[ConfigExport] units=", unit_count, " buildings=", building_count, " techs=", tech_count, " skills=", skill_count)
	quit()

func _export_units() -> int:
	var count: int = 0
	var unit_defs: Dictionary = REGISTRY.get_all_unit_defs()
	for key_value in unit_defs.keys():
		var id: String = str(key_value).strip_edges().to_lower()
		if id == "":
			continue
		var raw_value: Variant = unit_defs.get(key_value, {})
		if not (raw_value is Dictionary):
			continue
		var unit_def: Dictionary = raw_value as Dictionary
		var config: Resource = UNIT_CONFIG_SCRIPT.new()
		config.set("id", id)
		config.set("display_name", str(unit_def.get("display_name", "")))
		config.set("role_tag", str(unit_def.get("role_tag", "")))
		config.set("is_worker_role", bool(unit_def.get("is_worker_role", false)))
		config.set("cost", maxi(0, int(unit_def.get("cost", 0))))
		config.set("gas_cost", maxi(0, int(unit_def.get("gas_cost", 0))))
		config.set("supply", maxi(1, int(unit_def.get("supply", 1))))
		config.set("requires_buildings", _as_variant_array(unit_def.get("requires_buildings", [])))
		config.set("requires_tech", _as_string_array(unit_def.get("requires_tech", [])))
		config.set("skills", _as_string_array(unit_def.get("skills", [])))
		config.set("build_skills", _as_string_array(unit_def.get("build_skills", [])))

		var stats: Dictionary = {}
		for stat_key_value in unit_def.keys():
			var stat_key: String = str(stat_key_value)
			if UNIT_KNOWN_KEYS.has(stat_key):
				continue
			stats[stat_key] = unit_def.get(stat_key_value)
		config.set("stats", stats)

		if _save_resource(config, UNIT_DIR.path_join(_safe_file_name(id) + ".tres")):
			count += 1
	return count

func _export_buildings() -> int:
	var count: int = 0
	var building_defs: Dictionary = REGISTRY.get_all_building_defs()
	for key_value in building_defs.keys():
		var id: String = str(key_value).strip_edges().to_lower()
		if id == "":
			continue
		var raw_value: Variant = building_defs.get(key_value, {})
		if not (raw_value is Dictionary):
			continue
		var building_def: Dictionary = raw_value as Dictionary
		var config: Resource = BUILDING_CONFIG_SCRIPT.new()
		config.set("id", id)
		config.set("display_name", str(building_def.get("display_name", "")))
		config.set("role_tag", str(building_def.get("role_tag", "")))
		config.set("cost", maxi(0, int(building_def.get("cost", 0))))
		config.set("gas_cost", maxi(0, int(building_def.get("gas_cost", 0))))
		config.set("construction_paradigm", str(building_def.get("construction_paradigm", "garrisoned")))
		config.set("build_time", maxf(0.0, float(building_def.get("build_time", 0.0))))
		config.set("cancel_refund_ratio", clampf(float(building_def.get("cancel_refund_ratio", 0.75)), 0.0, 1.0))
		config.set("max_health", maxf(1.0, float(building_def.get("max_health", 1.0))))
		config.set("attack_range", maxf(0.0, float(building_def.get("attack_range", 0.0))))
		config.set("attack_damage", maxf(0.0, float(building_def.get("attack_damage", 0.0))))
		config.set("attack_cooldown", maxf(0.01, float(building_def.get("attack_cooldown", 1.0))))
		config.set("is_resource_dropoff", bool(building_def.get("is_resource_dropoff", false)))
		config.set("can_queue_worker", bool(building_def.get("can_queue_worker", false)))
		config.set("can_queue_soldier", bool(building_def.get("can_queue_soldier", false)))
		config.set("worker_build_time", maxf(0.0, float(building_def.get("worker_build_time", 0.0))))
		config.set("soldier_build_time", maxf(0.0, float(building_def.get("soldier_build_time", 0.0))))
		config.set("trainable_units", _as_dictionary(building_def.get("trainable_units", {})))
		config.set("queue_limit", maxi(0, int(building_def.get("queue_limit", 0))))
		var spawn_offset_value: Variant = building_def.get("spawn_offset", Vector3(3.0, 0.0, 0.0))
		var spawn_offset: Vector3 = spawn_offset_value as Vector3 if spawn_offset_value is Vector3 else Vector3(3.0, 0.0, 0.0)
		config.set("spawn_offset", spawn_offset)
		config.set("supply_bonus", maxi(0, int(building_def.get("supply_bonus", 0))))
		config.set("requires_buildings", _as_variant_array(building_def.get("requires_buildings", [])))
		config.set("requires_tech", _as_string_array(building_def.get("requires_tech", [])))
		config.set("skills", _as_string_array(building_def.get("skills", [])))
		config.set("build_skills", _as_string_array(building_def.get("build_skills", [])))

		var extra: Dictionary = {}
		for extra_key_value in building_def.keys():
			var extra_key: String = str(extra_key_value)
			if BUILDING_KNOWN_KEYS.has(extra_key):
				continue
			extra[extra_key] = building_def.get(extra_key_value)
		config.set("extra", extra)

		if _save_resource(config, BUILDING_DIR.path_join(_safe_file_name(id) + ".tres")):
			count += 1
	return count

func _export_techs() -> int:
	var count: int = 0
	var tech_defs: Dictionary = REGISTRY.get_all_tech_defs()
	for key_value in tech_defs.keys():
		var id: String = str(key_value).strip_edges().to_lower()
		if id == "":
			continue
		var raw_value: Variant = tech_defs.get(key_value, {})
		if not (raw_value is Dictionary):
			continue
		var tech_def: Dictionary = raw_value as Dictionary
		var config: Resource = TECH_CONFIG_SCRIPT.new()
		config.set("id", id)
		config.set("display_name", str(tech_def.get("display_name", "")))
		config.set("description", str(tech_def.get("description", "")))
		config.set("cost", maxi(0, int(tech_def.get("cost", 0))))
		config.set("gas_cost", maxi(0, int(tech_def.get("gas_cost", 0))))
		config.set("research_time", maxf(0.0, float(tech_def.get("research_time", 0.0))))
		config.set("requires_buildings", _as_variant_array(tech_def.get("requires_buildings", [])))
		config.set("requires_tech", _as_string_array(tech_def.get("requires_tech", [])))

		var extra: Dictionary = {}
		for extra_key_value in tech_def.keys():
			var extra_key: String = str(extra_key_value)
			if TECH_KNOWN_KEYS.has(extra_key):
				continue
			extra[extra_key] = tech_def.get(extra_key_value)
		config.set("extra", extra)

		if _save_resource(config, TECH_DIR.path_join(_safe_file_name(id) + ".tres")):
			count += 1
	return count

func _export_skills() -> int:
	var count: int = 0
	var skill_defs: Dictionary = REGISTRY.get_all_skill_defs()
	for key_value in skill_defs.keys():
		var id: String = str(key_value).strip_edges().to_lower()
		if id == "":
			continue
		var raw_value: Variant = skill_defs.get(key_value, {})
		if not (raw_value is Dictionary):
			continue
		var skill_def: Dictionary = raw_value as Dictionary
		var config: Resource = SKILL_CONFIG_SCRIPT.new()
		config.set("id", id)
		config.set("label", str(skill_def.get("label", "")))
		config.set("icon_path", str(skill_def.get("icon_path", "")))
		config.set("hotkey", str(skill_def.get("hotkey", "")))
		config.set("target_mode", str(skill_def.get("target_mode", "none")))
		config.set("building_kind", str(skill_def.get("building_kind", "")))
		config.set("tech_id", str(skill_def.get("tech_id", "")))
		config.set("unit_kind", str(skill_def.get("unit_kind", "")))
		config.set("queue_idle_dispatch", bool(skill_def.get("queue_idle_dispatch", false)))
		config.set("description", str(skill_def.get("description", "")))

		var extra: Dictionary = {}
		for extra_key_value in skill_def.keys():
			var extra_key: String = str(extra_key_value)
			if SKILL_KNOWN_KEYS.has(extra_key):
				continue
			extra[extra_key] = skill_def.get(extra_key_value)
		config.set("extra", extra)

		if _save_resource(config, SKILL_DIR.path_join(_safe_file_name(id) + ".tres")):
			count += 1
	return count

func _save_resource(resource: Resource, path: String) -> bool:
	if resource == null:
		return false
	var err: Error = ResourceSaver.save(resource, path)
	if err != OK:
		push_error("[ConfigExport] save failed: %s err=%d" % [path, err])
		return false
	return true

func _ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))

func _as_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}

func _as_variant_array(value: Variant) -> Array[Variant]:
	var result: Array[Variant] = []
	if value is Array:
		for item in value:
			result.append(item)
	return result

func _as_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result

func _safe_file_name(id: String) -> String:
	var source: String = id.strip_edges().to_lower()
	if source == "":
		return "unnamed"
	var out: String = ""
	for i in range(source.length()):
		var ch: String = source.substr(i, 1)
		var valid: bool = (
			(ch >= "a" and ch <= "z")
			or (ch >= "0" and ch <= "9")
			or ch == "_"
			or ch == "-"
		)
		out += ch if valid else "_"
	if out == "":
		return "unnamed"
	return out
