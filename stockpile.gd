extends Node2D

@export var stored_food: int = 0
@export var max_visual_items: int = 24
@export var pile_radius: float = 24.0

@onready var label: Label = get_node_or_null("Label")
@onready var visual_scene: PackedScene = load("res://thing.tscn")

func add_to_group_safe() -> void:
	if not is_in_group("stockpile"):
		add_to_group("stockpile")

func _ready() -> void:
	add_to_group_safe()
	_update_ui()

func has_food() -> bool:
	return stored_food > 0

func deposit_food(amount: int = 1) -> void:
	stored_food += amount
	_update_ui()
	_spawn_visual_item()

func consume_food(amount: int = 1) -> bool:
	if stored_food < amount:
		return false
	stored_food -= amount
	_update_ui()
	var visuals := get_tree().get_nodes_in_group("stockpile_visual")
	if visuals.size() > 0:
		var last_vis: Node = visuals[visuals.size() - 1]
		if is_instance_valid(last_vis):
			last_vis.queue_free()
	return true

func _update_ui() -> void:
	if label != null:
		label.text = "Food: " + str(stored_food)

func _spawn_visual_item() -> void:
	if visual_scene == null:
		return
	var current_visuals := get_tree().get_node_count_in_group("stockpile_visual")
	if current_visuals >= max_visual_items:
		return

	var item := visual_scene.instantiate()
	if item.has_method("set_script"):
		item.set_script(null)
	var angle := randf_range(0.0, TAU)
	var dist := randf_range(2.0, pile_radius)
	item.position = Vector2(cos(angle), sin(angle)) * dist
	item.scale = Vector2(0.75, 0.75)
	item.add_to_group("stockpile_visual")
	add_child(item)
