extends RefCounted
class_name RTSCommand

enum CommandType {
	NONE,
	MOVE,
	ATTACK,
	ATTACK_MOVE,
	GATHER,
	RETURN_RESOURCE,
	STOP,
	SKILL,
	BUILD,
}

enum TargetType {
	NONE,
	POINT,
	UNIT,
	DIRECTION,
}

var command_type: int = CommandType.NONE
var target_type: int = TargetType.NONE
var target_position: Vector3 = Vector3.ZERO
var target_unit: Node = null
var direction: Vector3 = Vector3.ZERO
var is_queue_command: bool = false
var is_auto_cast: bool = false
var control_group_id: int = -1
var timestamp: float = 0.0
var subgroup_index: int = -1
var payload: Dictionary = {}

func _init(initial_type: int = CommandType.NONE, initial_target_type: int = TargetType.NONE) -> void:
	command_type = initial_type
	target_type = initial_target_type
	timestamp = float(Time.get_ticks_msec()) / 1000.0

static func create(initial_type: int, initial_target_type: int = TargetType.NONE, queue_command: bool = false) -> RTSCommand:
	var command: RTSCommand = RTSCommand.new(initial_type, initial_target_type)
	command.is_queue_command = queue_command
	return command

static func make_move(target: Vector3, queue_command: bool = false) -> RTSCommand:
	var command: RTSCommand = create(CommandType.MOVE, TargetType.POINT, queue_command)
	command.target_position = target
	return command

static func make_attack(target: Node, queue_command: bool = false) -> RTSCommand:
	var command: RTSCommand = create(CommandType.ATTACK, TargetType.UNIT, queue_command)
	command.target_unit = target
	if target is Node3D:
		command.target_position = (target as Node3D).global_position
	return command

static func make_attack_move(target: Vector3, queue_command: bool = false) -> RTSCommand:
	var command: RTSCommand = create(CommandType.ATTACK_MOVE, TargetType.POINT, queue_command)
	command.target_position = target
	return command

static func make_gather(resource_node: Node, dropoff_node: Node, queue_command: bool = false) -> RTSCommand:
	var command: RTSCommand = create(CommandType.GATHER, TargetType.UNIT, queue_command)
	command.target_unit = resource_node
	command.payload = {
		"resource": resource_node,
		"dropoff": dropoff_node
	}
	if resource_node is Node3D:
		command.target_position = (resource_node as Node3D).global_position
	return command

static func make_return(dropoff_node: Node, queue_command: bool = false) -> RTSCommand:
	var command: RTSCommand = create(CommandType.RETURN_RESOURCE, TargetType.UNIT, queue_command)
	command.target_unit = dropoff_node
	command.payload = {
		"dropoff": dropoff_node
	}
	if dropoff_node is Node3D:
		command.target_position = (dropoff_node as Node3D).global_position
	return command

static func make_stop(queue_command: bool = false) -> RTSCommand:
	return create(CommandType.STOP, TargetType.NONE, queue_command)
