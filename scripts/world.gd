extends Node2D

const FOOD = preload("res://food.tscn")
const HAM = preload("res://hamster.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var clicker = get_local_mouse_position()
	if Input.is_action_just_pressed("exit"):
		get_tree().quit()
	if Input.is_action_just_pressed("click"):
		var instance = FOOD.instantiate()
		instance.global_position = clicker
		var foodCollection = get_tree().get_nodes_in_group("Food")[0]
		foodCollection.add_child(instance)
	if Input.is_action_just_pressed("right_click"):
		var instance = HAM.instantiate()
		instance.global_position = clicker
		get_parent().add_child(instance)
	pass
