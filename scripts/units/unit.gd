extends CharacterBody3D

@export var move_speed: float = 6.0

@onready var _selection_ring: MeshInstance3D = $SelectionRing

var _has_target: bool = false
var _target_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	add_to_group("selectable_unit")
	_selection_ring.visible = false

func _physics_process(_delta: float) -> void:
	if not _has_target:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var to_target := _target_position - global_position
	to_target.y = 0.0
	if to_target.length() <= 0.1:
		_has_target = false
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var direction := to_target.normalized()
	velocity = direction * move_speed
	move_and_slide()

func move_to(target: Vector3) -> void:
	_target_position = target
	_has_target = true

func set_selected(selected: bool) -> void:
	_selection_ring.visible = selected
