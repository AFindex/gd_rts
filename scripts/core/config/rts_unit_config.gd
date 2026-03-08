class_name RTSUnitConfig
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var role_tag: String = ""
@export var is_worker_role: bool = false
@export var cost: int = 0
@export var gas_cost: int = 0
@export var supply: int = 1
@export var stats: Dictionary = {}
@export var requires_buildings: Array[Variant] = []
@export var requires_tech: Array[String] = []
@export var skills: Array[String] = []
@export var build_skills: Array[String] = []

func to_dict() -> Dictionary:
	var result: Dictionary = {
		"display_name": display_name,
		"role_tag": role_tag,
		"is_worker_role": is_worker_role,
		"cost": maxi(0, cost),
		"gas_cost": maxi(0, gas_cost),
		"supply": maxi(1, supply),
		"requires_buildings": requires_buildings.duplicate(true),
		"requires_tech": requires_tech.duplicate(true),
		"skills": skills.duplicate(true),
		"build_skills": build_skills.duplicate(true)
	}
	for key_value in stats.keys():
		var key: String = str(key_value)
		if key == "":
			continue
		result[key] = stats.get(key_value)
	return result
