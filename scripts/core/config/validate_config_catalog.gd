extends SceneTree

const REGISTRY: Script = preload("res://scripts/core/config/rts_config_registry.gd")

var _unit_defs: Dictionary = {}
var _building_defs: Dictionary = {}
var _tech_defs: Dictionary = {}
var _skill_defs: Dictionary = {}

func _init() -> void:
	REGISTRY.reload()
	_unit_defs = REGISTRY.get_all_unit_defs()
	_building_defs = REGISTRY.get_all_building_defs()
	_tech_defs = REGISTRY.get_all_tech_defs()
	_skill_defs = REGISTRY.get_all_skill_defs()
	var active_mode: String = REGISTRY.get_active_catalog_mode()
	var active_dirs: Dictionary = REGISTRY.get_active_config_dirs()

	var errors: Array[String] = []
	_validate_non_empty(errors, active_dirs)
	_validate_unit_refs(errors)
	_validate_building_refs(errors)
	_validate_tech_refs(errors)
	_validate_skill_refs(errors)

	if errors.is_empty():
		print("[ConfigValidate] OK | mode=", active_mode, " dirs=", active_dirs, " units=", _unit_defs.size(), " buildings=", _building_defs.size(), " techs=", _tech_defs.size(), " skills=", _skill_defs.size())
		quit(0)
		return

	for issue in errors:
		printerr("[ConfigValidate][ERROR] ", issue)
	printerr("[ConfigValidate] FAILED | errors=", errors.size())
	quit(1)

func _validate_non_empty(errors: Array[String], active_dirs: Dictionary) -> void:
	if _unit_defs.is_empty():
		errors.append("No unit configs loaded from %s" % [str(active_dirs.get("units", []))])
	if _building_defs.is_empty():
		errors.append("No building configs loaded from %s" % [str(active_dirs.get("buildings", []))])
	if _tech_defs.is_empty():
		errors.append("No tech configs loaded from %s" % [str(active_dirs.get("techs", []))])
	if _skill_defs.is_empty():
		errors.append("No skill configs loaded from %s" % [str(active_dirs.get("skills", []))])

func _validate_unit_refs(errors: Array[String]) -> void:
	for unit_id_value in _unit_defs.keys():
		var unit_id: String = str(unit_id_value)
		var unit_def: Dictionary = _unit_defs.get(unit_id_value, {}) as Dictionary
		var src: String = REGISTRY.get_unit_source_path(unit_id)
		for building_id in _required_building_ids(unit_def.get("requires_buildings", [])):
			if not _building_defs.has(building_id):
				errors.append("unit '%s' requires missing building '%s' | %s" % [unit_id, building_id, src])
		for tech_id in _string_array(unit_def.get("requires_tech", [])):
			if tech_id == "":
				continue
			if not _tech_defs.has(tech_id):
				errors.append("unit '%s' requires missing tech '%s' | %s" % [unit_id, tech_id, src])
		for skill_id in _string_array(unit_def.get("skills", [])):
			if skill_id == "":
				continue
			if not _skill_defs.has(skill_id):
				errors.append("unit '%s' references missing skill '%s' (skills) | %s" % [unit_id, skill_id, src])
		for skill_id in _string_array(unit_def.get("build_skills", [])):
			if skill_id == "":
				continue
			if not _skill_defs.has(skill_id):
				errors.append("unit '%s' references missing skill '%s' (build_skills) | %s" % [unit_id, skill_id, src])

func _validate_building_refs(errors: Array[String]) -> void:
	for building_id_value in _building_defs.keys():
		var building_id: String = str(building_id_value)
		var building_def: Dictionary = _building_defs.get(building_id_value, {}) as Dictionary
		var src: String = REGISTRY.get_building_source_path(building_id)
		for required_id in _required_building_ids(building_def.get("requires_buildings", [])):
			if not _building_defs.has(required_id):
				errors.append("building '%s' requires missing building '%s' | %s" % [building_id, required_id, src])
		for tech_id in _string_array(building_def.get("requires_tech", [])):
			if tech_id == "":
				continue
			if not _tech_defs.has(tech_id):
				errors.append("building '%s' requires missing tech '%s' | %s" % [building_id, tech_id, src])
		var trainable_units_value: Variant = building_def.get("trainable_units", {})
		if trainable_units_value is Dictionary:
			var trainable_units: Dictionary = trainable_units_value as Dictionary
			for unit_id_value2 in trainable_units.keys():
				var unit_id: String = str(unit_id_value2).strip_edges().to_lower()
				if unit_id == "":
					continue
				if not _unit_defs.has(unit_id):
					errors.append("building '%s' has missing trainable unit '%s' | %s" % [building_id, unit_id, src])
		for skill_id in _string_array(building_def.get("skills", [])):
			if skill_id == "":
				continue
			if not _skill_defs.has(skill_id):
				errors.append("building '%s' references missing skill '%s' (skills) | %s" % [building_id, skill_id, src])
		for skill_id in _string_array(building_def.get("build_skills", [])):
			if skill_id == "":
				continue
			if not _skill_defs.has(skill_id):
				errors.append("building '%s' references missing skill '%s' (build_skills) | %s" % [building_id, skill_id, src])

func _validate_tech_refs(errors: Array[String]) -> void:
	for tech_id_value in _tech_defs.keys():
		var tech_id: String = str(tech_id_value)
		var tech_def: Dictionary = _tech_defs.get(tech_id_value, {}) as Dictionary
		var src: String = REGISTRY.get_tech_source_path(tech_id)
		for building_id in _required_building_ids(tech_def.get("requires_buildings", [])):
			if not _building_defs.has(building_id):
				errors.append("tech '%s' requires missing building '%s' | %s" % [tech_id, building_id, src])
		for required_tech_id in _string_array(tech_def.get("requires_tech", [])):
			if required_tech_id == "":
				continue
			if not _tech_defs.has(required_tech_id):
				errors.append("tech '%s' requires missing tech '%s' | %s" % [tech_id, required_tech_id, src])

func _validate_skill_refs(errors: Array[String]) -> void:
	for skill_id_value in _skill_defs.keys():
		var skill_id: String = str(skill_id_value)
		var skill_def: Dictionary = _skill_defs.get(skill_id_value, {}) as Dictionary
		var src: String = REGISTRY.get_skill_source_path(skill_id)
		var declared_id: String = str(skill_def.get("id", "")).strip_edges().to_lower()
		if declared_id != "" and declared_id != skill_id:
			errors.append("skill key/id mismatch: key='%s' id='%s' | %s" % [skill_id, declared_id, src])
		var building_kind: String = str(skill_def.get("building_kind", "")).strip_edges().to_lower()
		if building_kind != "" and not _building_defs.has(building_kind):
			errors.append("skill '%s' references missing building_kind '%s' | %s" % [skill_id, building_kind, src])
		var tech_id: String = str(skill_def.get("tech_id", "")).strip_edges().to_lower()
		if tech_id != "" and not _tech_defs.has(tech_id):
			errors.append("skill '%s' references missing tech_id '%s' | %s" % [skill_id, tech_id, src])
		var unit_kind: String = str(skill_def.get("unit_kind", "")).strip_edges().to_lower()
		if unit_kind != "" and not _unit_defs.has(unit_kind):
			errors.append("skill '%s' references missing unit_kind '%s' | %s" % [skill_id, unit_kind, src])

func _required_building_ids(raw_value: Variant) -> Array[String]:
	var ids: Array[String] = []
	if not (raw_value is Array):
		return ids
	for item in raw_value:
		if item is Dictionary:
			var dict_item: Dictionary = item as Dictionary
			var id: String = str(dict_item.get("kind", dict_item.get("building_kind", ""))).strip_edges().to_lower()
			if id != "":
				ids.append(id)
		else:
			var id: String = str(item).strip_edges().to_lower()
			if id != "":
				ids.append(id)
	return ids

func _string_array(raw_value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not (raw_value is Array):
		return result
	for item in raw_value:
		result.append(str(item).strip_edges().to_lower())
	return result
