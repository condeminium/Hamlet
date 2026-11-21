class_name TerrainPathfinder
extends Node

@export var terrain_generator: Node2D
@export var diagonal_mode: AStarGrid2D.DiagonalMode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
@export var max_weight_scale: float = 12.0
@export var min_speed_for_cost: float = 0.05

var _grid: AStarGrid2D = AStarGrid2D.new()
var _region: Rect2i = Rect2i()
var _cell_size: Vector2 = Vector2(16.0, 16.0)
var _is_built: bool = false

func _ready() -> void:
	add_to_group("pathfinder")
	if terrain_generator == null:
		if get_tree() != null and not get_tree().get_nodes_in_group("terrain").is_empty():
			terrain_generator = get_tree().get_nodes_in_group("terrain")[0] as Node2D
		elif get_parent() != null:
			var parent_node := get_parent()
			if parent_node.has_method("GenerateTerrain"):
				terrain_generator = parent_node as Node2D
			else:
				var found := parent_node.find_child("*Terrain*", true, false)
				if found is Node2D:
					terrain_generator = found
	rebuild()

func rebuild() -> void:
	if terrain_generator == null:
		_is_built = false
		return

	var w: int = int(terrain_generator.get("width")) if terrain_generator.get("width") != null else 80
	var h: int = int(terrain_generator.get("height")) if terrain_generator.get("height") != null else 80
	var half_w: int = int(w / 2)
	var half_h: int = int(h / 2)

	_cell_size = _resolve_cell_size()
	_region = Rect2i(-half_w, -half_h, w, h)

	_grid.clear()
	_grid.region = _region
	_grid.cell_size = _cell_size
	_grid.diagonal_mode = diagonal_mode
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()

	_apply_terrain_costs()
	_is_built = true

func _resolve_cell_size() -> Vector2:
	if terrain_generator.has_method("_get_tile_size"):
		return terrain_generator.call("_get_tile_size")
	var ground_layer: TileMapLayer = terrain_generator.get("ground") as TileMapLayer
	if ground_layer != null and ground_layer.tile_set != null:
		return Vector2(ground_layer.tile_set.tile_size)
	return Vector2(16.0, 16.0)

func _world_to_cell(world_pos: Vector2) -> Vector2i:
	var ground_layer: TileMapLayer = terrain_generator.get("ground") as TileMapLayer
	if ground_layer != null:
		return ground_layer.local_to_map(ground_layer.to_local(world_pos))
	var local_pos: Vector2 = terrain_generator.to_local(world_pos)
	return Vector2i(
		floori(local_pos.x / maxf(_cell_size.x, 1.0)),
		floori(local_pos.y / maxf(_cell_size.y, 1.0))
	)

func _cell_to_world(cell: Vector2i) -> Vector2:
	var ground_layer: TileMapLayer = terrain_generator.get("ground") as TileMapLayer
	if ground_layer != null:
		return ground_layer.to_global(ground_layer.map_to_local(cell))
	return terrain_generator.to_global(
		Vector2((float(cell.x) + 0.5) * _cell_size.x, (float(cell.y) + 0.5) * _cell_size.y)
	)

func _apply_terrain_costs() -> void:
	var min_x: int = _region.position.x
	var max_x: int = _region.end.x
	var min_y: int = _region.position.y
	var max_y: int = _region.end.y

	var has_walkable: bool = terrain_generator.has_method("is_walkable_at")
	var has_wall: bool = terrain_generator.has_method("is_wall_at")
	var has_speed: bool = terrain_generator.has_method("get_speed_multiplier_at")

	for gx in range(min_x, max_x):
		for gy in range(min_y, max_y):
			var cell := Vector2i(gx, gy)
			var world_pos := _cell_to_world(cell)

			var walkable: bool = true
			if has_walkable:
				walkable = bool(terrain_generator.call("is_walkable_at", world_pos))
			elif has_wall:
				walkable = not bool(terrain_generator.call("is_wall_at", world_pos))

			var speed_mult: float = 1.0
			if has_speed:
				speed_mult = float(terrain_generator.call("get_speed_multiplier_at", world_pos))

			if not walkable or speed_mult <= 0.0:
				_grid.set_point_solid(cell, true)
			else:
				_grid.set_point_solid(cell, false)
				var effective_speed := maxf(speed_mult, min_speed_for_cost)
				var weight := clampf(1.0 / effective_speed, 0.25, max_weight_scale)
				_grid.set_point_weight_scale(cell, weight)

func find_world_path(from_world: Vector2, to_world: Vector2, allow_partial: bool = true) -> PackedVector2Array:
	if not _is_built:
		rebuild()
	if not _is_built:
		return PackedVector2Array()

	var start_cell := _world_to_cell(from_world)
	var goal_cell := _world_to_cell(to_world)

	if not _region.has_point(start_cell) or not _region.has_point(goal_cell):
		return PackedVector2Array()

	var was_start_solid := _grid.is_point_solid(start_cell)
	var was_goal_solid := _grid.is_point_solid(goal_cell)

	if was_start_solid:
		_grid.set_point_solid(start_cell, false)
	if was_goal_solid:
		_grid.set_point_solid(goal_cell, false)

	var cell_path: Array[Vector2i] = _grid.get_id_path(start_cell, goal_cell, allow_partial)

	_grid.set_point_solid(start_cell, was_start_solid)
	_grid.set_point_solid(goal_cell, was_goal_solid)

	var world_points := PackedVector2Array()
	for i in range(cell_path.size()):
		if i == cell_path.size() - 1 and not was_goal_solid:
			world_points.append(to_world)
		else:
			world_points.append(_cell_to_world(cell_path[i]))
	return world_points
