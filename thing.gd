extends Sprite2D

var claimed_by = null

func _ready() -> void:
	if not Engine.is_editor_hint():
		FoodManager.register_food(self)

func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		FoodManager.unregister_food(self)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("clear"):
		queue_free()
