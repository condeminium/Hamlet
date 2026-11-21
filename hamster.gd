extends CharacterBody2D

@export var target : Node2D
var current_job: Job = null
var carrying_food: Node2D = null
var haul_to_stockpile: bool = false

var hunger = 20
const SPEED = 50.0
const ACCELERATION = 4
var current_speed_multiplier: float = 1.0
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
@onready var cursor: Area2D = get_node_or_null("../Cursor")
@onready var food_detector: Area2D = $Area2D
@onready var terrain: Node = get_tree().get_first_node_in_group("terrain")

func _ready() -> void:
	add_to_group("hamsters")
	if terrain == null:
		terrain = get_tree().get_first_node_in_group("terrain")
	var fullname = prefix[randi_range(0, len(prefix) - 1)] + suffix[randi_range(0, len(suffix) - 1)]
	$Name.text = fullname

	if timer:
		await get_tree().create_timer(randf_range(0.0, timer.wait_time)).timeout
		if is_inside_tree() and not timer.timeout.is_connected(_on_timer_timeout):
			timer.timeout.connect(_on_timer_timeout)

func _clamp_to_map(pos: Vector2, margin: float = 20.0) -> Vector2:
	if terrain != null and terrain.has_method("clamp_world_pos_to_map"):
		return terrain.clamp_world_pos_to_map(pos, margin)
	return pos

func _get_nearest_stockpile(require_food: bool = false) -> Node2D:
	var piles := get_tree().get_nodes_in_group("stockpile")
	var nearest: Node2D = null
	var min_dist_sq: float = INF
	for node in piles:
		if node is Node2D and is_instance_valid(node):
			if require_food and node.has_method("has_food") and not node.has_food():
				continue
			var d := global_position.distance_squared_to(node.global_position)
			if d < min_dist_sq:
				min_dist_sq = d
				nearest = node
	return nearest

func _drop_carried_food() -> void:
	if carrying_food != null and is_instance_valid(carrying_food):
		carrying_food.global_position = _clamp_to_map(global_position, 12.0)
		carrying_food.visible = true
		carrying_food.set("claimed_by", null)
		FoodManager.register_food(carrying_food)
		if not TaskManager.has_job_for_node(carrying_food):
			TaskManager.add_job(Job.new("haul", 20, carrying_food.global_position, carrying_food))
	carrying_food = null
	haul_to_stockpile = false

func _eat_food_gain() -> void:
	hunger = min(hunger + 50, 100)
	mitosis_score += 1
	if current_job != null:
		TaskManager.complete_job(current_job, self)
		current_job = null
	target = null
	navigation_agent.target_position = global_position

func _physics_process(delta: float) -> void:
	if terrain == null:
		terrain = get_tree().get_first_node_in_group("terrain")

	if Input.is_action_just_pressed("DEBUG FEED"):
		hunger += 100
	$Hunger.text = str(hunger)

	if mitosis_score == 10:
		if get_tree().get_node_count_in_group("hamsters") < 60:
			var hamclone = hamster.instantiate()
			get_parent().add_child(hamclone)
			hamclone.global_position = _clamp_to_map(global_position - Vector2(10, 10), 20.0)
		mitosis_score = 1

	if Input.is_action_just_pressed("exit"):
		get_tree().quit()

	if hunger > 10:
		mood = MoodState.HAPPY
		pouch = PouchState.FULL if carrying_food != null else PouchState.EMPTY
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

	if current_job != null and not haul_to_stockpile and not current_job.is_valid_job():
		_drop_carried_food()
		TaskManager.complete_job(current_job, self)
		current_job = null
		target = null
		navigation_agent.target_position = global_position

	if target != null and not is_instance_valid(target) and not haul_to_stockpile:
		target = null
		navigation_agent.target_position = global_position

	var target_multiplier: float = 1.0
	if terrain != null and terrain.has_method("get_speed_multiplier_at"):
		target_multiplier = terrain.get_speed_multiplier_at(global_position)
	current_speed_multiplier = lerpf(current_speed_multiplier, target_multiplier, 8.0 * delta)
	var effective_speed: float = SPEED * current_speed_multiplier

	var just_switched_to_stockpile := false

	if current_job != null and current_job.type == "haul" and not haul_to_stockpile and is_instance_valid(current_job.target_node):
		if global_position.distance_to(current_job.target_node.global_position) < 16.0:
			var pile := _get_nearest_stockpile(false)
			if pile != null:
				carrying_food = current_job.target_node
				carrying_food.visible = false
				carrying_food.set("claimed_by", self)
				FoodManager.unregister_food(carrying_food)
				haul_to_stockpile = true
				target = pile
				navigation_agent.target_position = _clamp_to_map(pile.global_position, 16.0)
				just_switched_to_stockpile = true

	if not just_switched_to_stockpile and navigation_agent.is_navigation_finished():
		velocity = velocity.lerp(Vector2.ZERO, ACCELERATION * delta)
		if current_job != null:
			if current_job.type == "wander":
				TaskManager.complete_job(current_job, self)
				current_job = null
			elif current_job.type == "haul" and haul_to_stockpile:
				var pile := _get_nearest_stockpile(false)
				if pile != null and global_position.distance_to(pile.global_position) <= 24.0:
					if pile.has_method("deposit_food"):
						pile.deposit_food(1)
					if carrying_food != null and is_instance_valid(carrying_food):
						carrying_food.queue_free()
					carrying_food = null
					haul_to_stockpile = false
					TaskManager.complete_job(current_job, self)
					current_job = null
					target = null
				elif pile != null:
					navigation_agent.target_position = _clamp_to_map(pile.global_position, 16.0)
			elif current_job.type == "fetch_stockpile":
				var pile := current_job.target_node
				if pile != null and is_instance_valid(pile) and pile.has_method("consume_food") and global_position.distance_to(pile.global_position) <= 24.0:
					if pile.consume_food(1):
						_eat_food_gain()
					else:
						TaskManager.release_job(current_job, self)
						current_job = null
						target = null
		elif target != null:
			FoodManager.release_claim(target, self)
			target = null
	else:
		var direction = navigation_agent.get_next_path_position() - global_position
		direction = direction.normalized()
		velocity = velocity.lerp(direction * effective_speed, ACCELERATION * delta)

	move_and_slide()
	global_position = _clamp_to_map(global_position, 12.0)

	for area in food_detector.get_overlapping_areas():
		if area.is_in_group("food"):
			var food_root := area.get_parent()
			if food_root == carrying_food:
				continue
			if hunger <= 10 or (current_job != null and current_job.type == "forage"):
				if is_instance_valid(food_root):
					TaskManager.remove_jobs_for_node(food_root, self)
					FoodManager.unregister_food(food_root)
					food_root.queue_free()
				_eat_food_gain()
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
		walk_timer += delta * squish_speed * maxf(current_speed_multiplier, 0.35)
		var squish_y = sin(walk_timer) * squish_amount
		$Sprite2D.scale.y = 1.0 - squish_y
		$Sprite2D.scale.x = 1.0 + squish_y
	else:
		walk_timer = 0.0
		$Sprite2D.scale = $Sprite2D.scale.lerp(Vector2.ONE, 10.0 * delta)

func _on_timer_timeout() -> void:
	hunger = move_toward(hunger, 0, 1)

	if hunger == 0:
		if current_job != null and (current_job.type == "forage" or current_job.type == "fetch_stockpile") and is_instance_valid(target):
			return

		if current_job != null:
			if current_job.type == "haul" and haul_to_stockpile:
				_drop_carried_food()
			TaskManager.release_job(current_job, self)
			current_job = null

		var food_node := FoodManager.find_and_claim_nearest(self, global_position)
		if food_node != null:
			target = food_node
			var forage_job := Job.new("forage", 1, food_node.global_position, food_node)
			forage_job.claimed_by = self
			TaskManager.add_job(forage_job)
			current_job = forage_job
			navigation_agent.target_position = _clamp_to_map(food_node.global_position, 16.0)
		else:
			var pile := _get_nearest_stockpile(true)
			if pile != null:
				target = pile
				var fetch_job := Job.new("fetch_stockpile", 2, pile.global_position, pile)
				fetch_job.claimed_by = self
				TaskManager.add_job(fetch_job)
				current_job = fetch_job
				navigation_agent.target_position = _clamp_to_map(pile.global_position, 16.0)
			else:
				target = null
				navigation_agent.target_position = global_position
	else:
		if follow_cursor and is_instance_valid(cursor):
			if current_job != null:
				if current_job.type == "haul" and haul_to_stockpile:
					_drop_carried_food()
				TaskManager.release_job(current_job, self)
				current_job = null
			target = null
			navigation_agent.target_position = _clamp_to_map(cursor.global_position, 16.0)
			return

		if current_job == null:
			var next_job := TaskManager.request_job(self, global_position)
			if next_job == null:
				var wander_offset := Vector2(randf_range(-80.0, 80.0), randf_range(-80.0, 80.0))
				var clamped_wander := _clamp_to_map(global_position + wander_offset, 24.0)
				next_job = Job.new("wander", 50, clamped_wander, null)
				next_job.claimed_by = self
				TaskManager.add_job(next_job)

			current_job = next_job
			if current_job.type == "haul" and is_instance_valid(current_job.target_node):
				target = current_job.target_node
				navigation_agent.target_position = _clamp_to_map(current_job.target_node.global_position, 16.0)
			else:
				navigation_agent.target_position = _clamp_to_map(current_job.target_pos, 24.0)
