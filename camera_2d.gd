extends Camera2D

@export var pan_smoothing: float = 4.0
@export var zoom_step: float = 0.25
@export var min_zoom: float = 0.5
@export var max_zoom: float = 4.0
@export var clamp_to_map: bool = true

@onready var terrain: Node = get_tree().get_first_node_in_group("terrain")

func _ready() -> void:
	if terrain == null:
		terrain = get_tree().get_first_node_in_group("terrain")
	make_current()
	_apply_map_clamp()

func _apply_map_clamp() -> void:
	if not clamp_to_map:
		return
	if terrain == null or not is_instance_valid(terrain):
		terrain = get_tree().get_first_node_in_group("terrain")
	if terrain != null and terrain.has_method("clamp_world_pos_to_map"):
		global_position = terrain.clamp_world_pos_to_map(global_position, 0.0)

func _process(delta: float) -> void:
	if Input.is_action_pressed("camerapan"):
		var weight: float = clampf(1.0 - exp(-pan_smoothing * delta), 0.0, 1.0)
		var desired_pos: Vector2 = get_global_mouse_position()
		if clamp_to_map and terrain != null and terrain.has_method("clamp_world_pos_to_map"):
			desired_pos = terrain.clamp_world_pos_to_map(desired_pos, 0.0)

		global_position = global_position.lerp(desired_pos, weight)
		_apply_map_clamp()

	if Input.is_action_just_pressed("scroll up"):
		zoom = (zoom + Vector2(zoom_step, zoom_step)).clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
	elif Input.is_action_just_pressed("scroll down"):
		zoom = (zoom - Vector2(zoom_step, zoom_step)).clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
