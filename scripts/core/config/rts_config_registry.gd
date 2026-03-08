class_name RTSConfigRegistry
extends RefCounted

const UNIT_CONFIG_DIR: String = "res://config/units"
const BUILDING_CONFIG_DIR: String = "res://config/buildings"
const TECH_CONFIG_DIR: String = "res://config/techs"
const SKILL_CONFIG_DIR: String = "res://config/skills"

static var _loaded: bool = false
static var _unit_defs: Dictionary = {}
static var _building_defs: Dictionary = {}
static var _tech_defs: Dictionary = {}
static var _skill_defs: Dictionary = {}
static var _unit_sources: Dictionary = {}
static var _building_sources: Dictionary = {}
static var _tech_sources: Dictionary = {}
static var _skill_sources: Dictionary = {}

static func reload() -> void:
	_loaded = false
	_unit_defs.clear()
	_building_defs.clear()
	_tech_defs.clear()
	_skill_defs.clear()
	_unit_sources.clear()
	_building_sources.clear()
	_tech_sources.clear()
	_skill_sources.clear()
	_ensure_loaded()

static func get_unit_def(unit_id: String) -> Dictionary:
	_ensure_loaded()
	return _clone_dict_from_map(_unit_defs, unit_id)

static func get_building_def(building_id: String) -> Dictionary:
	_ensure_loaded()
	return _clone_dict_from_map(_building_defs, building_id)

static func get_tech_def(tech_id: String) -> Dictionary:
	_ensure_loaded()
	return _clone_dict_from_map(_tech_defs, tech_id)

static func get_skill_def(skill_id: String) -> Dictionary:
	_ensure_loaded()
	return _clone_dict_from_map(_skill_defs, skill_id)

static func get_all_unit_defs() -> Dictionary:
	_ensure_loaded()
	return _unit_defs.duplicate(true)

static func get_all_building_defs() -> Dictionary:
	_ensure_loaded()
	return _building_defs.duplicate(true)

static func get_all_tech_defs() -> Dictionary:
	_ensure_loaded()
	return _tech_defs.duplicate(true)

static func get_all_skill_defs() -> Dictionary:
	_ensure_loaded()
	return _skill_defs.duplicate(true)

static func get_unit_source_path(unit_id: String) -> String:
	_ensure_loaded()
	return _source_path_for(_unit_sources, unit_id)

static func get_building_source_path(building_id: String) -> String:
	_ensure_loaded()
	return _source_path_for(_building_sources, building_id)

static func get_tech_source_path(tech_id: String) -> String:
	_ensure_loaded()
	return _source_path_for(_tech_sources, tech_id)

static func get_skill_source_path(skill_id: String) -> String:
	_ensure_loaded()
	return _source_path_for(_skill_sources, skill_id)

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_unit_defs = _load_unit_defs()
	_building_defs = _load_building_defs()
	_tech_defs = _load_tech_defs()
	_skill_defs = _load_skill_defs()

static func _clone_dict_from_map(source: Dictionary, id: String) -> Dictionary:
	var normalized: String = id.strip_edges().to_lower()
	if normalized == "":
		return {}
	var value: Variant = source.get(normalized, {})
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}

static func _load_unit_defs() -> Dictionary:
	var result: Dictionary = {}
	_unit_sources.clear()
	for file_path in _list_resource_files_recursive(UNIT_CONFIG_DIR):
		var resource: Resource = ResourceLoader.load(file_path)
		var config: RTSUnitConfig = resource as RTSUnitConfig
		if config == null:
			continue
		var normalized_id: String = config.id.strip_edges().to_lower()
		if normalized_id == "":
			continue
		if result.has(normalized_id):
			_warn_duplicate_id("unit", normalized_id, str(_unit_sources.get(normalized_id, "")), file_path)
			continue
		result[normalized_id] = config.to_dict()
		_unit_sources[normalized_id] = file_path
	return result

static func _load_building_defs() -> Dictionary:
	var result: Dictionary = {}
	_building_sources.clear()
	for file_path in _list_resource_files_recursive(BUILDING_CONFIG_DIR):
		var resource: Resource = ResourceLoader.load(file_path)
		var config: RTSBuildingConfig = resource as RTSBuildingConfig
		if config == null:
			continue
		var normalized_id: String = config.id.strip_edges().to_lower()
		if normalized_id == "":
			continue
		if result.has(normalized_id):
			_warn_duplicate_id("building", normalized_id, str(_building_sources.get(normalized_id, "")), file_path)
			continue
		result[normalized_id] = config.to_dict()
		_building_sources[normalized_id] = file_path
	return result

static func _load_tech_defs() -> Dictionary:
	var result: Dictionary = {}
	_tech_sources.clear()
	for file_path in _list_resource_files_recursive(TECH_CONFIG_DIR):
		var resource: Resource = ResourceLoader.load(file_path)
		var config: RTSTechConfig = resource as RTSTechConfig
		if config == null:
			continue
		var normalized_id: String = config.id.strip_edges().to_lower()
		if normalized_id == "":
			continue
		if result.has(normalized_id):
			_warn_duplicate_id("tech", normalized_id, str(_tech_sources.get(normalized_id, "")), file_path)
			continue
		result[normalized_id] = config.to_dict()
		_tech_sources[normalized_id] = file_path
	return result

static func _load_skill_defs() -> Dictionary:
	var result: Dictionary = {}
	_skill_sources.clear()
	for file_path in _list_resource_files_recursive(SKILL_CONFIG_DIR):
		var resource: Resource = ResourceLoader.load(file_path)
		var config: RTSSkillConfig = resource as RTSSkillConfig
		if config == null:
			continue
		var normalized_id: String = config.id.strip_edges().to_lower()
		if normalized_id == "":
			continue
		if result.has(normalized_id):
			_warn_duplicate_id("skill", normalized_id, str(_skill_sources.get(normalized_id, "")), file_path)
			continue
		result[normalized_id] = config.to_dict()
		_skill_sources[normalized_id] = file_path
	return result

static func _list_resource_files_recursive(root_dir: String) -> Array[String]:
	var files: Array[String] = []
	_collect_resource_files_recursive(root_dir, files)
	files.sort()
	return files

static func _collect_resource_files_recursive(dir_path: String, out_files: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry_name: String = dir.get_next()
		if entry_name == "":
			break
		if entry_name.begins_with("."):
			continue
		var full_path: String = dir_path.path_join(entry_name)
		if dir.current_is_dir():
			_collect_resource_files_recursive(full_path, out_files)
			continue
		var ext: String = entry_name.get_extension().to_lower()
		if ext == "tres" or ext == "res":
			out_files.append(full_path)
	dir.list_dir_end()

static func _source_path_for(source_map: Dictionary, id: String) -> String:
	var normalized: String = id.strip_edges().to_lower()
	if normalized == "":
		return ""
	return str(source_map.get(normalized, ""))

static func _warn_duplicate_id(category: String, id: String, existing_path: String, duplicated_path: String) -> void:
	push_warning("[RTSConfigRegistry] Duplicate %s id '%s'. Keeping first: %s, ignoring: %s" % [category, id, existing_path, duplicated_path])
