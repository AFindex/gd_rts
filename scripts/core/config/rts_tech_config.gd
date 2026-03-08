class_name RTSTechConfig
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var cost: int = 0
@export var gas_cost: int = 0
@export var research_time: float = 0.0
@export var requires_buildings: Array[Variant] = []
@export var requires_tech: Array[String] = []
@export var extra: Dictionary = {}

func to_dict() -> Dictionary:
	var result: Dictionary = {
		"display_name": display_name,
		"description": description,
		"cost": maxi(0, cost),
		"gas_cost": maxi(0, gas_cost),
		"research_time": maxf(0.0, research_time),
		"requires_buildings": requires_buildings.duplicate(true),
		"requires_tech": requires_tech.duplicate(true)
	}
	for key_value in extra.keys():
		var key: String = str(key_value)
		if key == "":
			continue
		result[key] = extra.get(key_value)
	return result
