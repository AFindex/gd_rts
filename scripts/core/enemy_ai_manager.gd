extends Node

const RTS_CATALOG: Script = preload("res://scripts/core/config/rts_runtime_catalog.gd")
const RTS_AI_CATALOG: Script = preload("res://scripts/core/rts_ai_catalog.gd")
const MIN_TICK_RATE: float = 0.05

@export var player_team_id: int = 1
@export var enemy_team_id: int = 2

# Legacy compatibility; can override profile if enabled.
@export var train_interval: float = 3.2
@export var wave_interval: float = 10.0
@export var min_units_for_wave: int = 3
@export var train_per_cycle: int = 1

@export var ai_profile_id: String = "enemy_default"
@export var use_legacy_property_overrides: bool = true
@export var debug_ai_log: bool = false

enum CombatDirective {
	REGROUP,
	ATTACK,
}

var _profile: Dictionary = {}
var _production_timer: float = 0.0
var _tactical_timer: float = 0.0
var _economy_timer: float = 0.0
var _wave_cooldown_timer: float = 0.0
var _match_time_sec: float = 0.0
var _directive: int = CombatDirective.REGROUP
var _committed_wave_size: int = 0
var _attack_target_path: NodePath = NodePath("")
var _attack_order_stamp: Dictionary = {}
var _regroup_order_stamp: Dictionary = {}
var _worker_order_stamp: Dictionary = {}

func _ready() -> void:
	_reload_profile()

func _process(delta: float) -> void:
	_match_time_sec += delta
	_wave_cooldown_timer += delta
	_production_timer += delta
	_tactical_timer += delta
	_economy_timer += delta

	var production_tick: float = _tick_rate("production")
	if _production_timer >= production_tick:
		_production_timer = 0.0
		_run_production_cycle()

	var tactical_tick: float = _tick_rate("tactical")
	if _tactical_timer >= tactical_tick:
		_tactical_timer = 0.0
		_run_tactical_cycle()

	var economy_tick: float = _tick_rate("economy")
	if _economy_timer >= economy_tick:
		_economy_timer = 0.0
		_run_economy_cycle()

func _reload_profile() -> void:
	_profile = RTS_AI_CATALOG.get_profile(ai_profile_id)
	if use_legacy_property_overrides:
		_apply_legacy_overrides(_profile)

func _apply_legacy_overrides(profile: Dictionary) -> void:
	var tick_rates: Dictionary = _get_dict(profile, "tick_rates")
	tick_rates["production"] = maxf(MIN_TICK_RATE, train_interval)
	profile["tick_rates"] = tick_rates

	var production_cfg: Dictionary = _get_dict(profile, "production")
	var orders: Array = production_cfg.get("orders", [])
	var patched_orders: Array = orders.duplicate(true) if orders is Array else []
	var soldier_order_found: bool = false
	for i in patched_orders.size():
		var order_value: Variant = patched_orders[i]
		if not (order_value is Dictionary):
			continue
		var order: Dictionary = order_value as Dictionary
		if str(order.get("unit_kind", "")).to_lower() != "soldier":
			continue
		order["per_cycle"] = maxi(0, train_per_cycle)
		patched_orders[i] = order
		soldier_order_found = true
		break
	if not soldier_order_found and train_per_cycle > 0:
		patched_orders.append({
			"unit_kind": "soldier",
			"per_cycle": train_per_cycle,
			"building_roles": ["barracks"]
		})
	production_cfg["orders"] = patched_orders
	profile["production"] = production_cfg

	var combat_cfg: Dictionary = _get_dict(profile, "combat")
	combat_cfg["wave_cooldown"] = maxf(0.1, wave_interval)
	combat_cfg["base_wave_size"] = maxi(1, min_units_for_wave)
	profile["combat"] = combat_cfg

func _tick_rate(key: String) -> float:
	var tick_rates: Dictionary = _get_dict(_profile, "tick_rates")
	return maxf(MIN_TICK_RATE, float(tick_rates.get(key, 1.0)))

func _run_production_cycle() -> void:
	var production_cfg: Dictionary = _production_cfg()
	var max_queue_per_building: int = int(production_cfg.get("max_queue_per_building", 2))
	var order_values: Variant = production_cfg.get("orders", [])
	if not (order_values is Array):
		return
	var orders: Array = order_values as Array
	for order_value in orders:
		if not (order_value is Dictionary):
			continue
		var order: Dictionary = order_value as Dictionary
		var unit_kind: String = str(order.get("unit_kind", "")).to_lower()
		if unit_kind == "":
			continue
		var per_cycle: int = maxi(0, int(order.get("per_cycle", 0)))
		if per_cycle <= 0:
			continue
		var max_team_units: int = int(order.get("max_team_units", -1))
		if max_team_units >= 0:
			var existing_units: int = _count_team_units(enemy_team_id, unit_kind)
			if existing_units >= max_team_units:
				continue
			per_cycle = mini(per_cycle, max_team_units - existing_units)
			if per_cycle <= 0:
				continue
		var role_filters: Array[String] = _to_string_array(order.get("building_roles", []))
		var buildings: Array[Node] = _enemy_production_buildings(unit_kind, role_filters)
		var trained_count: int = _queue_training_from_buildings(buildings, unit_kind, per_cycle, max_queue_per_building)
		if debug_ai_log and trained_count > 0:
			print("[EnemyAI] trained ", trained_count, " x ", unit_kind)

func _queue_training_from_buildings(buildings: Array[Node], unit_kind: String, target_count: int, max_queue_per_building: int) -> int:
	var trained: int = 0
	for building in buildings:
		if trained >= target_count:
			break
		if building == null or not is_instance_valid(building):
			continue
		if max_queue_per_building >= 0 and building.has_method("get_queue_size"):
			if int(building.call("get_queue_size")) >= max_queue_per_building:
				continue
		if _try_queue_unit(building, unit_kind):
			trained += 1
	return trained

func _try_queue_unit(building: Node, unit_kind: String) -> bool:
	if building == null or not is_instance_valid(building):
		return false
	match unit_kind:
		"soldier":
			if not building.has_method("can_queue_soldier_unit"):
				return false
			if not bool(building.call("can_queue_soldier_unit")):
				return false
			if not building.has_method("queue_soldier"):
				return false
			var soldier_cost: int = _unit_cost("soldier")
			if soldier_cost > 0 and not _try_spend_enemy_minerals(soldier_cost):
				return false
			var soldier_queued: bool = bool(building.call("queue_soldier"))
			if not soldier_queued and soldier_cost > 0:
				_add_enemy_minerals(soldier_cost)
			return soldier_queued
		"worker":
			if not building.has_method("can_queue_worker_unit"):
				return false
			if not bool(building.call("can_queue_worker_unit")):
				return false
			if not building.has_method("queue_worker"):
				return false
			var worker_cost: int = _unit_cost("worker")
			if worker_cost > 0 and not _try_spend_enemy_minerals(worker_cost):
				return false
			var worker_queued: bool = bool(building.call("queue_worker"))
			if not worker_queued and worker_cost > 0:
				_add_enemy_minerals(worker_cost)
			return worker_queued
		_:
			return false

func _enemy_production_buildings(unit_kind: String, role_filters: Array[String]) -> Array[Node]:
	var results: Array[Node] = []
	var nodes: Array[Node] = get_tree().get_nodes_in_group("selectable_building")
	for node in nodes:
		if node == null or not is_instance_valid(node):
			continue
		if not _node_is_team(node, enemy_team_id):
			continue
		if node.has_method("is_alive") and not bool(node.call("is_alive")):
			continue
		if not _building_matches_roles(node, role_filters):
			continue
		if unit_kind == "soldier":
			if not node.has_method("queue_soldier"):
				continue
		elif unit_kind == "worker":
			if not node.has_method("queue_worker"):
				continue
		else:
			continue
		results.append(node)
	return results

func _building_matches_roles(building_node: Node, role_filters: Array[String]) -> bool:
	if role_filters.is_empty():
		return true
	var kind_text: String = str(building_node.get("building_kind")).to_lower()
	var role_tag: String = ""
	if building_node.has_method("get_building_role_tag"):
		role_tag = str(building_node.call("get_building_role_tag")).to_lower()
	for role in role_filters:
		var normalized_role: String = role.strip_edges().to_lower()
		if normalized_role == "":
			continue
		if normalized_role == "*":
			return true
		if kind_text == normalized_role or kind_text.contains(normalized_role):
			return true
		if role_tag.contains(normalized_role):
			return true
	return false

func _run_economy_cycle() -> void:
	var economy_cfg: Dictionary = _economy_cfg()
	if not bool(economy_cfg.get("enabled", true)):
		return
	var workers: Array[Node3D] = _enemy_worker_units()
	if workers.is_empty():
		return
	var worker_refresh: float = maxf(0.2, float(economy_cfg.get("worker_order_refresh", 8.0)))
	var max_search_distance: float = maxf(4.0, float(economy_cfg.get("max_resource_search_distance", 36.0)))
	for worker in workers:
		if worker == null or not is_instance_valid(worker):
			continue
		if worker.has_method("is_construction_locked") and bool(worker.call("is_construction_locked")):
			continue
		if not _should_issue_unit_order(_worker_order_stamp, worker, worker_refresh):
			continue
		var dropoff: Node3D = _nearest_dropoff_for_team(enemy_team_id, worker.global_position)
		if dropoff == null:
			continue
		if worker.has_method("has_cargo") and bool(worker.call("has_cargo")):
			if worker.has_method("command_return_to_dropoff"):
				worker.call("command_return_to_dropoff", dropoff)
			continue
		var mineral: Node3D = _nearest_resource_node(worker.global_position, max_search_distance)
		if mineral == null:
			continue
		if worker.has_method("command_gather"):
			worker.call("command_gather", mineral, dropoff)

func _run_tactical_cycle() -> void:
	var combat_units: Array[Node3D] = _enemy_combat_units()
	if combat_units.is_empty():
		_reset_combat_state()
		return

	var rally_point: Vector3 = _compute_rally_point(combat_units)
	if _directive == CombatDirective.ATTACK:
		_process_attack_directive(combat_units, rally_point)
	else:
		_process_regroup_directive(combat_units, rally_point)

func _process_regroup_directive(combat_units: Array[Node3D], rally_point: Vector3) -> void:
	_issue_regroup_orders(combat_units, rally_point)
	if combat_units.size() < _current_wave_threshold():
		return
	var cooldown: float = maxf(0.1, float(_combat_cfg().get("wave_cooldown", 10.0)))
	if _wave_cooldown_timer < cooldown:
		return
	var target: Node3D = _find_player_priority_target(rally_point)
	if target == null:
		return
	_directive = CombatDirective.ATTACK
	_committed_wave_size = combat_units.size()
	_attack_target_path = target.get_path()
	_wave_cooldown_timer = 0.0
	_attack_order_stamp.clear()
	_regroup_order_stamp.clear()
	if debug_ai_log:
		print("[EnemyAI] launch wave size=", _committed_wave_size, " target=", target.name)
	_issue_attack_orders(combat_units, target)

func _process_attack_directive(combat_units: Array[Node3D], rally_point: Vector3) -> void:
	var target: Node3D = _current_attack_target()
	if target == null or not _is_valid_hostile_target(target):
		target = _find_player_priority_target(_centroid(combat_units))
		if target != null:
			_attack_target_path = target.get_path()

	if target == null:
		if debug_ai_log:
			print("[EnemyAI] lost attack target, fallback regroup")
		_directive = CombatDirective.REGROUP
		_attack_target_path = NodePath("")
		_attack_order_stamp.clear()
		_regroup_order_stamp.clear()
		_issue_regroup_orders(combat_units, rally_point)
		return

	var retreat_ratio: float = clampf(float(_combat_cfg().get("retreat_ratio", 0.35)), 0.05, 1.0)
	var retreat_threshold: int = maxi(1, int(ceil(float(maxi(1, _committed_wave_size)) * retreat_ratio)))
	if combat_units.size() < retreat_threshold:
		if debug_ai_log:
			print("[EnemyAI] retreat size=", combat_units.size(), " threshold=", retreat_threshold)
		_directive = CombatDirective.REGROUP
		_attack_target_path = NodePath("")
		_attack_order_stamp.clear()
		_regroup_order_stamp.clear()
		_issue_regroup_orders(combat_units, rally_point)
		return

	_issue_attack_orders(combat_units, target)

func _issue_regroup_orders(combat_units: Array[Node3D], rally_point: Vector3) -> void:
	var regroup_mode: String = str(_combat_cfg().get("regroup_order_mode", "move")).to_lower()
	var regroup_refresh: float = maxf(0.05, float(_combat_cfg().get("regroup_order_refresh", 1.2)))
	for unit_node in combat_units:
		if unit_node == null or not is_instance_valid(unit_node):
			continue
		if not _should_issue_unit_order(_regroup_order_stamp, unit_node, regroup_refresh):
			continue
		if regroup_mode == "attack_move" and unit_node.has_method("command_attack_move"):
			if bool(unit_node.call("command_attack_move", rally_point)):
				continue
		if unit_node.has_method("command_move"):
			unit_node.call("command_move", rally_point)

func _issue_attack_orders(combat_units: Array[Node3D], target: Node3D) -> void:
	if target == null or not is_instance_valid(target):
		return
	var attack_mode: String = str(_combat_cfg().get("attack_order_mode", "attack_move")).to_lower()
	var attack_refresh: float = maxf(0.05, float(_combat_cfg().get("attack_order_refresh", 1.2)))
	for unit_node in combat_units:
		if unit_node == null or not is_instance_valid(unit_node):
			continue
		if not _should_issue_unit_order(_attack_order_stamp, unit_node, attack_refresh):
			continue
		if attack_mode == "attack_move" and unit_node.has_method("command_attack_move"):
			if bool(unit_node.call("command_attack_move", target.global_position)):
				continue
		if unit_node.has_method("command_attack"):
			if bool(unit_node.call("command_attack", target)):
				continue
		if unit_node.has_method("command_move"):
			unit_node.call("command_move", target.global_position)

func _current_wave_threshold() -> int:
	var combat_cfg: Dictionary = _combat_cfg()
	var base_wave: int = maxi(1, int(combat_cfg.get("base_wave_size", 3)))
	var growth_step: int = maxi(0, int(combat_cfg.get("growth_step", 0)))
	var growth_interval: float = maxf(1.0, float(combat_cfg.get("growth_interval", 60.0)))
	var growth_times: int = int(floor(_match_time_sec / growth_interval))
	var wave_size: int = base_wave + growth_step * growth_times
	var cap: int = maxi(base_wave, int(combat_cfg.get("max_wave_size", wave_size)))
	return mini(wave_size, cap)

func _compute_rally_point(combat_units: Array[Node3D]) -> Vector3:
	var combat_cfg: Dictionary = _combat_cfg()
	var rally_distance: float = clampf(float(combat_cfg.get("rally_distance", 10.0)), 1.0, 80.0)
	var enemy_anchor: Vector3 = _team_anchor(enemy_team_id)
	var player_anchor: Vector3 = _team_anchor(player_team_id)
	if not _is_valid_anchor(enemy_anchor) and not combat_units.is_empty():
		enemy_anchor = _centroid(combat_units)
	if not _is_valid_anchor(enemy_anchor):
		enemy_anchor = Vector3.ZERO
	if not _is_valid_anchor(player_anchor):
		var fallback_target: Node3D = _nearest_node_for_team("selectable_unit", player_team_id, enemy_anchor, false)
		if fallback_target != null:
			player_anchor = fallback_target.global_position
		else:
			player_anchor = enemy_anchor + Vector3.RIGHT
	var direction: Vector3 = player_anchor - enemy_anchor
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = Vector3.RIGHT
	return enemy_anchor + direction.normalized() * rally_distance

func _find_player_priority_target(from_position: Vector3) -> Node3D:
	var combat_cfg: Dictionary = _combat_cfg()
	var priorities: Array[String] = _to_string_array(combat_cfg.get("target_priority_building_kinds", []))
	for priority in priorities:
		var target: Node3D = _nearest_player_building(from_position, priority)
		if target != null:
			return target
	if bool(combat_cfg.get("fallback_to_units", true)):
		var ignore_workers: bool = bool(combat_cfg.get("ignore_worker_targets", false))
		return _nearest_node_for_team("selectable_unit", player_team_id, from_position, ignore_workers)
	return null

func _nearest_player_building(from_position: Vector3, kind_filter: String) -> Node3D:
	var nearest: Node3D = null
	var best_distance_sq: float = INF
	var normalized_filter: String = kind_filter.strip_edges().to_lower()
	var nodes: Array[Node] = get_tree().get_nodes_in_group("selectable_building")
	for node in nodes:
		var node_3d: Node3D = node as Node3D
		if node_3d == null or not is_instance_valid(node_3d):
			continue
		if not _node_is_team(node_3d, player_team_id):
			continue
		if node_3d.has_method("is_alive") and not bool(node_3d.call("is_alive")):
			continue
		if not _building_kind_matches(node_3d, normalized_filter):
			continue
		var distance_sq: float = from_position.distance_squared_to(node_3d.global_position)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			nearest = node_3d
	return nearest

func _building_kind_matches(building_node: Node, kind_filter: String) -> bool:
	if kind_filter == "" or kind_filter == "*":
		return true
	var building_kind: String = str(building_node.get("building_kind")).to_lower()
	if building_kind == kind_filter:
		return true
	return building_kind.contains(kind_filter)

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

func _enemy_worker_units() -> Array[Node3D]:
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
		if not (unit_node.has_method("is_worker_unit") and bool(unit_node.call("is_worker_unit"))):
			continue
		results.append(unit_node)
	return results

func _nearest_dropoff_for_team(team_id: int, from_position: Vector3) -> Node3D:
	var nearest: Node3D = null
	var best_distance_sq: float = INF
	var dropoff_nodes: Array[Node] = get_tree().get_nodes_in_group("resource_dropoff")
	for node in dropoff_nodes:
		var dropoff: Node3D = node as Node3D
		if dropoff == null or not is_instance_valid(dropoff):
			continue
		if dropoff.has_method("is_alive") and not bool(dropoff.call("is_alive")):
			continue
		if dropoff.has_method("get_team_id") and int(dropoff.call("get_team_id")) != team_id:
			continue
		var distance_sq: float = from_position.distance_squared_to(dropoff.global_position)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			nearest = dropoff
	return nearest

func _nearest_resource_node(from_position: Vector3, max_distance: float = INF) -> Node3D:
	var nearest: Node3D = null
	var best_distance_sq: float = max_distance * max_distance if is_finite(max_distance) else INF
	var resource_nodes: Array[Node] = get_tree().get_nodes_in_group("resource_node")
	for node in resource_nodes:
		var mineral: Node3D = node as Node3D
		if mineral == null or not is_instance_valid(mineral):
			continue
		if mineral.has_method("is_depleted") and bool(mineral.call("is_depleted")):
			continue
		var distance_sq: float = from_position.distance_squared_to(mineral.global_position)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			nearest = mineral
	return nearest

func _nearest_node_for_team(group_name: String, team: int, from_position: Vector3, ignore_workers: bool) -> Node3D:
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
		if ignore_workers and node_3d.has_method("is_worker_unit") and bool(node_3d.call("is_worker_unit")):
			continue
		var distance_sq: float = from_position.distance_squared_to(node_3d.global_position)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			nearest = node_3d
	return nearest

func _count_team_units(team: int, unit_kind: String) -> int:
	var count: int = 0
	var nodes: Array[Node] = get_tree().get_nodes_in_group("selectable_unit")
	for node in nodes:
		if node == null or not is_instance_valid(node):
			continue
		if not _node_is_team(node, team):
			continue
		if node.has_method("is_alive") and not bool(node.call("is_alive")):
			continue
		if _unit_matches_kind(node, unit_kind):
			count += 1
	return count

func _unit_matches_kind(unit_node: Node, unit_kind: String) -> bool:
	var normalized_kind: String = unit_kind.strip_edges().to_lower()
	if unit_node.has_method("get_unit_kind"):
		return str(unit_node.call("get_unit_kind")).to_lower() == normalized_kind
	if unit_node.has_method("is_worker_unit"):
		var is_worker: bool = bool(unit_node.call("is_worker_unit"))
		if normalized_kind == "worker":
			return is_worker
		if normalized_kind == "soldier":
			return not is_worker
	return false

func _team_anchor(team: int) -> Vector3:
	var building_nodes: Array[Node3D] = _team_nodes("selectable_building", team)
	if not building_nodes.is_empty():
		return _centroid(building_nodes)
	var unit_nodes: Array[Node3D] = _team_nodes("selectable_unit", team)
	if not unit_nodes.is_empty():
		return _centroid(unit_nodes)
	return Vector3(INF, INF, INF)

func _team_nodes(group_name: String, team: int) -> Array[Node3D]:
	var results: Array[Node3D] = []
	var nodes: Array[Node] = get_tree().get_nodes_in_group(group_name)
	for node in nodes:
		var node_3d: Node3D = node as Node3D
		if node_3d == null or not is_instance_valid(node_3d):
			continue
		if not _node_is_team(node_3d, team):
			continue
		if node_3d.has_method("is_alive") and not bool(node_3d.call("is_alive")):
			continue
		results.append(node_3d)
	return results

func _centroid(nodes: Array[Node3D]) -> Vector3:
	if nodes.is_empty():
		return Vector3.ZERO
	var sum: Vector3 = Vector3.ZERO
	var valid_count: int = 0
	for node_3d in nodes:
		if node_3d == null or not is_instance_valid(node_3d):
			continue
		sum += node_3d.global_position
		valid_count += 1
	if valid_count <= 0:
		return Vector3.ZERO
	return sum / float(valid_count)

func _current_attack_target() -> Node3D:
	if str(_attack_target_path) == "":
		return null
	var target_node: Node3D = get_node_or_null(_attack_target_path) as Node3D
	if target_node == null or not is_instance_valid(target_node):
		return null
	return target_node

func _is_valid_hostile_target(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if not node.has_method("get_team_id"):
		return false
	if int(node.call("get_team_id")) == enemy_team_id:
		return false
	if node.has_method("is_alive") and not bool(node.call("is_alive")):
		return false
	return true

func _unit_cost(unit_kind: String) -> int:
	return RTS_CATALOG.get_unit_cost(unit_kind)

func _try_spend_enemy_minerals(cost: int) -> bool:
	if cost <= 0:
		return true
	var game_manager: Node = _game_manager()
	if game_manager == null:
		return false
	if game_manager.has_method("try_spend_minerals_for_team"):
		return bool(game_manager.call("try_spend_minerals_for_team", enemy_team_id, cost))
	if game_manager.has_method("try_spend_minerals"):
		return bool(game_manager.call("try_spend_minerals", cost))
	return false

func _add_enemy_minerals(amount: int) -> void:
	if amount <= 0:
		return
	var game_manager: Node = _game_manager()
	if game_manager == null:
		return
	if game_manager.has_method("add_minerals_for_team"):
		game_manager.call("add_minerals_for_team", enemy_team_id, amount)
	elif game_manager.has_method("add_minerals"):
		game_manager.call("add_minerals", amount)

func _game_manager() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var game_manager: Node = tree.get_first_node_in_group("game_manager")
	if game_manager != null and is_instance_valid(game_manager):
		return game_manager
	return null

func _node_is_team(node: Node, team: int) -> bool:
	if node == null or not node.has_method("get_team_id"):
		return false
	return int(node.call("get_team_id")) == team

func _is_valid_anchor(anchor: Vector3) -> bool:
	return is_finite(anchor.x) and is_finite(anchor.y) and is_finite(anchor.z)

func _should_issue_unit_order(order_stamps: Dictionary, unit_node: Node, refresh_sec: float) -> bool:
	if unit_node == null or not is_instance_valid(unit_node):
		return false
	var key: String = str(unit_node.get_path())
	var now_sec: float = float(Time.get_ticks_msec()) / 1000.0
	var last_sec: float = float(order_stamps.get(key, -INF))
	if now_sec - last_sec < maxf(0.05, refresh_sec):
		return false
	order_stamps[key] = now_sec
	return true

func _reset_combat_state() -> void:
	_directive = CombatDirective.REGROUP
	_committed_wave_size = 0
	_attack_target_path = NodePath("")
	_attack_order_stamp.clear()
	_regroup_order_stamp.clear()

func _production_cfg() -> Dictionary:
	return _get_dict(_profile, "production")

func _economy_cfg() -> Dictionary:
	return _get_dict(_profile, "economy")

func _combat_cfg() -> Dictionary:
	return _get_dict(_profile, "combat")

func _get_dict(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value as Dictionary
	return {}

func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not (value is Array):
		return result
	for raw in value:
		var text: String = str(raw).strip_edges()
		if text == "":
			continue
		result.append(text.to_lower())
	return result
