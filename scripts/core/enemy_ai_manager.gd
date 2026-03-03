extends Node

@export var player_team_id: int = 1
@export var enemy_team_id: int = 2
@export var train_interval: float = 3.2
@export var wave_interval: float = 10.0
@export var min_units_for_wave: int = 3
@export var train_per_cycle: int = 1

var _train_timer: float = 0.0
var _wave_timer: float = 0.0

func _process(delta: float) -> void:
	_train_timer += delta
	_wave_timer += delta

	if _train_timer >= train_interval:
		_train_timer = 0.0
		_train_enemy_units()

	if _wave_timer >= wave_interval:
		_wave_timer = 0.0
		_issue_attack_wave()

func _train_enemy_units() -> void:
	var trained: int = 0
	var barracks_list: Array[Node] = _enemy_barracks()
	for barracks in barracks_list:
		if trained >= train_per_cycle:
			return
		if barracks == null or not is_instance_valid(barracks):
			continue
		if not barracks.has_method("can_queue_soldier_unit"):
			continue
		if not bool(barracks.call("can_queue_soldier_unit")):
			continue
		if not barracks.has_method("queue_soldier"):
			continue
		if bool(barracks.call("queue_soldier")):
			trained += 1

func _issue_attack_wave() -> void:
	var enemy_units: Array[Node3D] = _enemy_combat_units()
	if enemy_units.size() < min_units_for_wave:
		return

	var target: Node3D = _find_player_priority_target(enemy_units[0].global_position)
	if target == null:
		return

	for unit_node in enemy_units:
		if unit_node == null or not is_instance_valid(unit_node):
			continue
		if unit_node.has_method("command_attack"):
			unit_node.call("command_attack", target)
		elif unit_node.has_method("command_move"):
			unit_node.call("command_move", target.global_position)

func _enemy_barracks() -> Array[Node]:
	var results: Array[Node] = []
	var nodes: Array[Node] = get_tree().get_nodes_in_group("selectable_building")
	for node in nodes:
		if node == null or not is_instance_valid(node):
			continue
		if not _node_is_team(node, enemy_team_id):
			continue
		if node.has_method("get_building_role_tag"):
			var role_tag: String = str(node.call("get_building_role_tag")).to_lower()
			if role_tag.contains("barracks"):
				results.append(node)
	return results

func _enemy_combat_units() -> Array[Node3D]:
	var results: Array[Node3D] = []
	var nodes: Array[Node] = get_tree().get_nodes_in_group("selectable_unit")
	for node in nodes:
		var unit_node: Node3D = node as Node3D
		if unit_node == null or not is_instance_valid(unit_node):
			continue
		if not _node_is_team(unit_node, enemy_team_id):
			continue
		if unit_node.has_method("is_alive") and not bool(unit_node.call("is_alive")):
			continue
		if unit_node.has_method("is_worker_unit") and bool(unit_node.call("is_worker_unit")):
			continue
		results.append(unit_node)
	return results

func _find_player_priority_target(from_position: Vector3) -> Node3D:
	var building_target: Node3D = _nearest_node_for_team("selectable_building", player_team_id, from_position)
	if building_target != null:
		return building_target
	return _nearest_node_for_team("selectable_unit", player_team_id, from_position)

func _nearest_node_for_team(group_name: String, team: int, from_position: Vector3) -> Node3D:
	var nearest: Node3D = null
	var best_distance_sq: float = INF
	var nodes: Array[Node] = get_tree().get_nodes_in_group(group_name)
	for node in nodes:
		var node_3d: Node3D = node as Node3D
		if node_3d == null or not is_instance_valid(node_3d):
			continue
		if not _node_is_team(node_3d, team):
			continue
		if node_3d.has_method("is_alive") and not bool(node_3d.call("is_alive")):
			continue
		var distance_sq: float = from_position.distance_squared_to(node_3d.global_position)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			nearest = node_3d
	return nearest

func _node_is_team(node: Node, team: int) -> bool:
	if node == null or not node.has_method("get_team_id"):
		return false
	return int(node.call("get_team_id")) == team
