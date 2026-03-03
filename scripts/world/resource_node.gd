extends StaticBody3D

@export var total_minerals: int = 900
@export var max_visual_minerals: int = 900

@onready var _sprite: Sprite3D = $Sprite3D

func _ready() -> void:
	add_to_group("resource_node")
	_refresh_visual()

func harvest(request_amount: int) -> int:
	if request_amount <= 0:
		return 0
	if total_minerals <= 0:
		return 0

	var mined: int = mini(request_amount, total_minerals)
	total_minerals -= mined
	_refresh_visual()

	if total_minerals <= 0:
		queue_free()
	return mined

func _refresh_visual() -> void:
	if _sprite == null:
		return
	var ratio: float = clampf(float(total_minerals) / float(maxi(1, max_visual_minerals)), 0.25, 1.0)
	_sprite.scale = Vector3.ONE * ratio
	_sprite.scale = _sprite.scale * 8 # Temp: Scale up for better visibility