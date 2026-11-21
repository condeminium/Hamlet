extends CharacterBody2D

@export var target : Node2D
var hunger = 20
const SPEED = 50.0
const ACCELERATION = 4
var mitosis_score = 9
@export var follow_cursor : bool = false
@onready var hamster = load("res://hamster.tscn")
var prefix = ["Chud", "Cumber", "Bundah", "Flimber", "Snorb", "Flurb", "Fingle", "Blorgle", "Myrgle", "Shlerble"]
var suffix = ["ton", "son", "man", "person", "churgle", "bobulon", "ingerson", "jimbleton", "sie", " The Goat", " The Chudly One"]
enum MovementState {IDLE, WALKING}
enum PouchState {EMPTY, FULL}
enum MoodState {HAPPY, SAD}

var mood = MoodState.HAPPY
var pouch = PouchState.EMPTY
var movement_state = MovementState.IDLE

@export var squish_speed : float = 6.0
@export var squish_amount : float = 0.08
var walk_timer : float = 0.0

@onready var navigation_agent: NavigationAgent2D = $Navigation/NavigationAgent2D
@onready var timer: Timer = $Navigation/Timer
@onready var cursor: Area2D = $"../Cursor"
@onready var food_detector: Area2D = $Area2D

func _ready() -> void:
	add_to_group("hamsters")
	var fullname = prefix[randi_range(0, len(prefix) - 1)] + suffix[randi_range(0, len(suffix) - 1)]
	$Name.text = fullname

	if timer:
		await get_tree().create_timer(randf_range(0.0, timer.wait_time)).timeout
		if is_inside_tree() and not timer.timeout.is_connected(_on_timer_timeout):
			timer.timeout.connect(_on_timer_timeout)

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("DEBUG FEED"):
		hunger += 100
	$Hunger.text = str(hunger)

	if mitosis_score == 10:
		if get_tree().get_node_count_in_group("hamsters") < 60:
			var hamclone = hamster.instantiate()
			get_parent().add_child(hamclone)
			hamclone.global_position = global_position - Vector2(10, 10)
		mitosis_score = 1

	if Input.is_action_just_pressed("exit"):
		get_tree().quit()

	if hunger > 10:
		mood = MoodState.HAPPY
		pouch = PouchState.FULL
	elif hunger == 10:
		mood = MoodState.HAPPY
		pouch = PouchState.EMPTY
	else:
		mood = MoodState.SAD
		pouch = PouchState.EMPTY

	match [mood, pouch]:
		[MoodState.HAPPY, PouchState.FULL]:
			$Sprite2D.set_frame(3)
		[MoodState.HAPPY, PouchState.EMPTY]:
			$Sprite2D.set_frame(0)
		[MoodState.SAD, PouchState.FULL]:
			$Sprite2D.set_frame(1)
		[MoodState.SAD, PouchState.EMPTY]:
			$Sprite2D.set_frame(1)

	if target != null and not is_instance_valid(target):
		target = null
		navigation_agent.target_position = global_position

	if navigation_agent.is_navigation_finished():
		velocity = velocity.lerp(Vector2.ZERO, ACCELERATION * delta)
		if target != null:
			FoodManager.release_claim(target, self)
			target = null
	else:
		var direction = navigation_agent.get_next_path_position() - global_position
		direction = direction.normalized()
		velocity = velocity.lerp(direction * SPEED, ACCELERATION * delta)

	move_and_slide()

	for area in food_detector.get_overlapping_areas():
		if area.is_in_group("food"):
			var food_root := area.get_parent()
			hunger = min(hunger + 50, 100)
			mitosis_score += 1

			if is_instance_valid(food_root):
				FoodManager.unregister_food(food_root)
				food_root.queue_free()

			target = null
			navigation_agent.target_position = global_position
			break

	if velocity.length() > 2.0:
		movement_state = MovementState.WALKING
	else:
		movement_state = MovementState.IDLE

	if velocity.y < -1.0 and movement_state == MovementState.WALKING:
		$Sprite2D.set_frame(2)

	animate_walk(delta)

func animate_walk(delta: float) -> void:
	if movement_state == MovementState.WALKING:
		walk_timer += delta * squish_speed
		var squish_y = sin(walk_timer) * squish_amount
		$Sprite2D.scale.y = 1.0 - squish_y
		$Sprite2D.scale.x = 1.0 + squish_y
	else:
		walk_timer = 0.0
		$Sprite2D.scale = $Sprite2D.scale.lerp(Vector2.ONE, 10.0 * delta)

func _on_timer_timeout() -> void:
	hunger = move_toward(hunger, 0, 1)

	if hunger == 0:
		if is_instance_valid(target):
			return

		target = FoodManager.find_and_claim_nearest(self, global_position)
		if target != null:
			navigation_agent.target_position = target.global_position
		else:
			navigation_agent.target_position = global_position
	else:
		if is_instance_valid(target):
			FoodManager.release_claim(target, self)
			target = null
		if follow_cursor and is_instance_valid(cursor):
			navigation_agent.target_position = cursor.global_position
