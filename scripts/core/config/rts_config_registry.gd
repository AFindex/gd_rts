class_name RTSConfigRegistry
extends RefCounted

const LEGACY_UNIT_CONFIG_DIR: String = "res://config/units"
const LEGACY_BUILDING_CONFIG_DIR: String = "res://config/buildings"
const LEGACY_TECH_CONFIG_DIR: String = "res://config/techs"
const LEGACY_SKILL_CONFIG_DIR: String = "res://config/skills"

const EXPANSION_UNIT_CONFIG_DIR: String = "res://config_expansion/units"
const EXPANSION_BUILDING_CONFIG_DIR: String = "res://config_expansion/buildings"
const EXPANSION_TECH_CONFIG_DIR: String = "res://config_expansion/techs"
const EXPANSION_SKILL_CONFIG_DIR: String = "res://config_expansion/skills"

const PROJECT_SETTING_CATALOG_MODE: String = "rts/config/catalog_mode"
const CATALOG_MODE_LEGACY: String = "legacy"
const CATALOG_MODE_MERGED: String = "merged"
const CATALOG_MODE_EXPANSION: String = "expansion"

static var _loaded: bool = false
static var _unit_defs: Dictionary = {}
static var _building_defs: Dictionary = {}
static var _tech_defs: Dictionary = {}
static var _skill_defs: Dictionary = {}
static var _unit_sources: Dictionary = {}
static var _building_sources: Dictionary = {}
static var _tech_sources: Dictionary = {}
static var _skill_sources: Dictionary = {}
static var _active_catalog_mode: String = CATALOG_MODE_LEGACY
static var _active_unit_dirs: Array[String] = []
static var _active_building_dirs: Array[String] = []
static var _active_tech_dirs: Array[String] = []
static var _active_skill_dirs: Array[String] = []

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
	_active_catalog_mode = CATALOG_MODE_LEGACY
	_active_unit_dirs.clear()
	_active_building_dirs.clear()
	_active_tech_dirs.clear()
	_active_skill_dirs.clear()
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

static func get_active_catalog_mode() -> String:
	_ensure_loaded()
	return _active_catalog_mode

static func get_active_config_dirs() -> Dictionary:
	_ensure_loaded()
	return {
		"units": _active_unit_dirs.duplicate(),
		"buildings": _active_building_dirs.duplicate(),
		"techs": _active_tech_dirs.duplicate(),
		"skills": _active_skill_dirs.duplicate()
	}

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_resolve_active_catalog_dirs()
	_unit_defs = _load_unit_defs(_active_unit_dirs)
	_building_defs = _load_building_defs(_active_building_dirs)
	_tech_defs = _load_tech_defs(_active_tech_dirs)
	_skill_defs = _load_skill_defs(_active_skill_dirs)

static func _clone_dict_from_map(source: Dictionary, id: String) -> Dictionary:
	var normalized: String = id.strip_edges().to_lower()
	if normalized == "":
		return {}
	var value: Variant = source.get(normalized, {})
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}

static func _load_unit_defs(root_dirs: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	_unit_sources.clear()
	for file_path in _list_resource_files_from_roots(root_dirs):
		var resource: Resource = ResourceLoader.load(file_path)
		var config: RTSUnitConfig = resource as RTSUnitConfig
		if config == null:
			continue
		var normalized_id: String = config.id.strip_edges().to_lower()
		if normalized_id == "":
			continue
		if result.has(normalized_id):
			var existing_value: Variant = result.get(normalized_id, {})
			if existing_value is Dictionary:
				result[normalized_id] = _merge_catalog_entry(existing_value as Dictionary, config.to_dict())
			continue
		result[normalized_id] = config.to_dict()
		_unit_sources[normalized_id] = file_path
	return result

static func _load_building_defs(root_dirs: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	_building_sources.clear()
	for file_path in _list_resource_files_from_roots(root_dirs):
		var resource: Resource = ResourceLoader.load(file_path)
		var config: RTSBuildingConfig = resource as RTSBuildingConfig
		if config == null:
			continue
		var normalized_id: String = config.id.strip_edges().to_lower()
		if normalized_id == "":
			continue
		if result.has(normalized_id):
			var existing_value: Variant = result.get(normalized_id, {})
			if existing_value is Dictionary:
				result[normalized_id] = _merge_catalog_entry(existing_value as Dictionary, config.to_dict())
			continue
		result[normalized_id] = config.to_dict()
		_building_sources[normalized_id] = file_path
	return result

static func _load_tech_defs(root_dirs: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	_tech_sources.clear()
	for file_path in _list_resource_files_from_roots(root_dirs):
		var resource: Resource = ResourceLoader.load(file_path)
		var config: RTSTechConfig = resource as RTSTechConfig
		if config == null:
			continue
		var normalized_id: String = config.id.strip_edges().to_lower()
		if normalized_id == "":
			continue
		if result.has(normalized_id):
			var existing_value: Variant = result.get(normalized_id, {})
			if existing_value is Dictionary:
				result[normalized_id] = _merge_catalog_entry(existing_value as Dictionary, config.to_dict())
			continue
		result[normalized_id] = config.to_dict()
		_tech_sources[normalized_id] = file_path
	return result

static func _load_skill_defs(root_dirs: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	_skill_sources.clear()
	for file_path in _list_resource_files_from_roots(root_dirs):
		var resource: Resource = ResourceLoader.load(file_path)
		var config: RTSSkillConfig = resource as RTSSkillConfig
		if config == null:
			continue
		var normalized_id: String = config.id.strip_edges().to_lower()
		if normalized_id == "":
			continue
		if result.has(normalized_id):
			var existing_value: Variant = result.get(normalized_id, {})
			if existing_value is Dictionary:
				result[normalized_id] = _merge_catalog_entry(existing_value as Dictionary, config.to_dict())
			continue
		result[normalized_id] = config.to_dict()
		_skill_sources[normalized_id] = file_path
	return result

static func _resolve_active_catalog_dirs() -> void:
	var requested_mode: String = _requested_catalog_mode()
	_active_unit_dirs = _select_catalog_dirs(requested_mode, LEGACY_UNIT_CONFIG_DIR, EXPANSION_UNIT_CONFIG_DIR, "units")
	_active_building_dirs = _select_catalog_dirs(requested_mode, LEGACY_BUILDING_CONFIG_DIR, EXPANSION_BUILDING_CONFIG_DIR, "buildings")
	_active_tech_dirs = _select_catalog_dirs(requested_mode, LEGACY_TECH_CONFIG_DIR, EXPANSION_TECH_CONFIG_DIR, "techs")
	_active_skill_dirs = _select_catalog_dirs(requested_mode, LEGACY_SKILL_CONFIG_DIR, EXPANSION_SKILL_CONFIG_DIR, "skills")

	var using_legacy: bool = false
	var using_expansion: bool = false
	for dir_path in _active_unit_dirs + _active_building_dirs + _active_tech_dirs + _active_skill_dirs:
		if dir_path.begins_with("res://config_expansion"):
			using_expansion = true
		elif dir_path.begins_with("res://config"):
			using_legacy = true
	if using_legacy and using_expansion:
		_active_catalog_mode = CATALOG_MODE_MERGED
	elif using_expansion:
		_active_catalog_mode = CATALOG_MODE_EXPANSION
	else:
		_active_catalog_mode = CATALOG_MODE_LEGACY

static func _requested_catalog_mode() -> String:
	var raw_mode: String = str(ProjectSettings.get_setting(PROJECT_SETTING_CATALOG_MODE, CATALOG_MODE_MERGED)).strip_edges().to_lower()
	if raw_mode == CATALOG_MODE_LEGACY:
		return CATALOG_MODE_LEGACY
	if raw_mode == CATALOG_MODE_EXPANSION:
		return CATALOG_MODE_EXPANSION
	if raw_mode == CATALOG_MODE_MERGED:
		return CATALOG_MODE_MERGED
	return CATALOG_MODE_MERGED

static func _select_catalog_dirs(mode: String, legacy_dir: String, expansion_dir: String, category_label: String) -> Array[String]:
	var has_legacy: bool = _dir_has_resource_files(legacy_dir)
	var has_expansion: bool = _dir_has_resource_files(expansion_dir)
	var selected: Array[String] = []

	match mode:
		CATALOG_MODE_LEGACY:
			if has_legacy:
				selected.append(legacy_dir)
			elif has_expansion:
				push_warning("[RTSConfigRegistry] catalog_mode=legacy but %s missing in %s, fallback to %s." % [category_label, legacy_dir, expansion_dir])
				selected.append(expansion_dir)
		CATALOG_MODE_EXPANSION:
			if has_expansion:
				selected.append(expansion_dir)
			elif has_legacy:
				push_warning("[RTSConfigRegistry] catalog_mode=expansion but %s missing in %s, fallback to %s." % [category_label, expansion_dir, legacy_dir])
				selected.append(legacy_dir)
		_:
			if has_legacy:
				selected.append(legacy_dir)
			if has_expansion:
				selected.append(expansion_dir)
			if selected.is_empty() and has_legacy:
				selected.append(legacy_dir)
			elif selected.is_empty() and has_expansion:
				selected.append(expansion_dir)
	return selected

static func _dir_has_resource_files(root_dir: String) -> bool:
	var dir: DirAccess = DirAccess.open(root_dir)
	if dir == null:
		return false
	dir.list_dir_begin()
	while true:
		var entry_name: String = dir.get_next()
		if entry_name == "":
			break
		if entry_name.begins_with("."):
			continue
		var full_path: String = root_dir.path_join(entry_name)
		if dir.current_is_dir():
			if _dir_has_resource_files(full_path):
				dir.list_dir_end()
				return true
			continue
		var ext: String = entry_name.get_extension().to_lower()
		if ext == "tres" or ext == "res":
			dir.list_dir_end()
			return true
	dir.list_dir_end()
	return false

static func _list_resource_files_from_roots(root_dirs: Array[String]) -> Array[String]:
	var files: Array[String] = []
	for root_dir in root_dirs:
		var root_files: Array[String] = _list_resource_files_recursive(root_dir)
		for file_path in root_files:
			files.append(file_path)
	return files

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

static func _merge_catalog_entry(existing: Dictionary, incoming: Dictionary) -> Dictionary:
	var merged: Dictionary = existing.duplicate(true)
	for incoming_key in incoming.keys():
		var key: String = str(incoming_key)
		if key == "":
			continue
		var incoming_value: Variant = incoming.get(incoming_key)
		if not merged.has(key):
			merged[key] = _deep_duplicate(incoming_value)
			continue
		var existing_value: Variant = merged.get(key)
		if existing_value is Array and incoming_value is Array:
			merged[key] = _merge_array_unique(existing_value as Array, incoming_value as Array)
		elif existing_value is Dictionary and incoming_value is Dictionary:
			merged[key] = _merge_dictionary_keep_existing(existing_value as Dictionary, incoming_value as Dictionary)
	return merged

static func _merge_dictionary_keep_existing(existing: Dictionary, incoming: Dictionary) -> Dictionary:
	var merged: Dictionary = existing.duplicate(true)
	for incoming_key in incoming.keys():
		var key: String = str(incoming_key)
		if key == "":
			continue
		var incoming_value: Variant = incoming.get(incoming_key)
		if not merged.has(key):
			merged[key] = _deep_duplicate(incoming_value)
			continue
		var existing_value: Variant = merged.get(key)
		if existing_value is Array and incoming_value is Array:
			merged[key] = _merge_array_unique(existing_value as Array, incoming_value as Array)
		elif existing_value is Dictionary and incoming_value is Dictionary:
			merged[key] = _merge_dictionary_keep_existing(existing_value as Dictionary, incoming_value as Dictionary)
	return merged

static func _merge_array_unique(existing: Array, incoming: Array) -> Array:
	var merged: Array = existing.duplicate(true)
	var seen: Dictionary = {}
	for item in merged:
		seen[_variant_identity(item)] = true
	for item in incoming:
		var marker: String = _variant_identity(item)
		if seen.has(marker):
			continue
		seen[marker] = true
		merged.append(_deep_duplicate(item))
	return merged

static func _variant_identity(value: Variant) -> String:
	return var_to_str(value)

static func _deep_duplicate(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value
