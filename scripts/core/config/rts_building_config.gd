class_name RTSBuildingConfig
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var role_tag: String = ""
@export var cost: int = 0
@export var gas_cost: int = 0
@export var construction_paradigm: String = "garrisoned"
@export var build_time: float = 0.0
@export var cancel_refund_ratio: float = 0.75
@export var max_health: float = 1200.0
@export var attack_range: float = 0.0
@export var attack_damage: float = 0.0
@export var attack_cooldown: float = 1.0
@export var is_resource_dropoff: bool = false
@export var can_queue_worker: bool = false
@export var can_queue_soldier: bool = false
@export var worker_build_time: float = 0.0
@export var soldier_build_time: float = 0.0
@export var trainable_units: Dictionary = {}
@export var queue_limit: int = 0
@export var spawn_offset: Vector3 = Vector3(3.0, 0.0, 0.0)
@export var supply_bonus: int = 0
@export var requires_buildings: Array[Variant] = []
@export var requires_tech: Array[String] = []
@export var skills: Array[String] = []
@export var build_skills: Array[String] = []
@export var extra: Dictionary = {}

func to_dict() -> Dictionary:
	var result: Dictionary = {
		"display_name": display_name,
		"role_tag": role_tag,
		"cost": maxi(0, cost),
		"gas_cost": maxi(0, gas_cost),
		"construction_paradigm": construction_paradigm,
		"build_time": maxf(0.0, build_time),
		"cancel_refund_ratio": clampf(cancel_refund_ratio, 0.0, 1.0),
		"max_health": maxf(1.0, max_health),
		"attack_range": maxf(0.0, attack_range),
		"attack_damage": maxf(0.0, attack_damage),
		"attack_cooldown": maxf(0.01, attack_cooldown),
		"is_resource_dropoff": is_resource_dropoff,
		"can_queue_worker": can_queue_worker,
		"can_queue_soldier": can_queue_soldier,
		"worker_build_time": maxf(0.0, worker_build_time),
		"soldier_build_time": maxf(0.0, soldier_build_time),
		"trainable_units": trainable_units.duplicate(true),
		"queue_limit": maxi(0, queue_limit),
		"spawn_offset": spawn_offset,
		"supply_bonus": maxi(0, supply_bonus),
		"requires_buildings": requires_buildings.duplicate(true),
		"requires_tech": requires_tech.duplicate(true),
		"skills": skills.duplicate(true),
		"build_skills": build_skills.duplicate(true)
	}
	for key_value in extra.keys():
		var key: String = str(key_value)
		if key == "":
			continue
		result[key] = extra.get(key_value)
	return result
