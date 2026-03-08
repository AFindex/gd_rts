class_name RTSSkillConfig
extends Resource

@export var id: String = ""
@export var label: String = ""
@export var icon_path: String = ""
@export var hotkey: String = ""
@export var target_mode: String = "none"
@export var building_kind: String = ""
@export var tech_id: String = ""
@export var unit_kind: String = ""
@export var queue_idle_dispatch: bool = false
@export var description: String = ""
@export var extra: Dictionary = {}

func to_dict() -> Dictionary:
	var result: Dictionary = {
		"id": id,
		"label": label,
		"icon_path": icon_path,
		"hotkey": hotkey,
		"target_mode": target_mode
	}
	if building_kind != "":
		result["building_kind"] = building_kind
	if tech_id != "":
		result["tech_id"] = tech_id
	if unit_kind != "":
		result["unit_kind"] = unit_kind
	if queue_idle_dispatch:
		result["queue_idle_dispatch"] = true
	if description != "":
		result["description"] = description
	for key_value in extra.keys():
		var key: String = str(key_value)
		if key == "":
			continue
		result[key] = extra.get(key_value)
	return result
