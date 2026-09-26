extends Node2D

const FOOD = preload("res://food.tscn")
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
		instance.global_position = clicker.global_position
	pass
