extends Camera2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	global_position = lerp(global_position, get_global_mouse_position(),0.01)
	if Input.is_action_just_pressed("scroll up"):
		zoom += Vector2(1,1)
	elif Input.is_action_just_pressed("scroll down"):
		zoom -= Vector2(1,1)
	pass
