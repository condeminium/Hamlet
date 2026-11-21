extends CharacterBody2D

@export var target : Node2D
@export var pathfinder: TerrainPathfinder
@export_group("Hunger & Needs")
@export var max_hunger: float = 100.0
@export var starting_hunger: float = 75.0
@export var hunger_drain_per_second: float = 0.65
@export var show_needs_in_world: bool = true

var current_job: Job = null
var carrying_food: Node2D = null
var haul_to_stockpile: bool = false

var hunger: float = 75.0
var _hunger_carryover: float = 0.0
const SPEED = 50.0
const ACCELERATION = 4
var current_speed_multiplier: float = 1.0
@export var follow_cursor : bool = false
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
var _stuck_time: float = 0.0
var _path_points: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0

@onready var navigation_agent: NavigationAgent2D = $Navigation/NavigationAgent2D
@onready var timer: Timer = $Navigation/Timer
@onready var cursor: Area2D = get_node_or_null("../Cursor")
@onready var food_detector: Area2D = $Area2D
@onready var terrain: Node = get_tree().get_first_node_in_group("terrain")
@onready var needs_label: Label = get_node_or_null("NeedsLabel")

func _ready() -> void:
	add_to_group("hamsters")
	_ensure_refs()
	hunger = clampf(starting_hunger, 0.0, max_hunger)
	var fullname = prefix[randi_range(0, len(prefix) - 1)] + suffix[randi_range(0, len(suffix) - 1)]
	$Name.text = fullname
	_refresh_needs_ui()

	if timer:
		await get_tree().create_timer(randf_range(0.0, timer.wait_time)).timeout
		if is_inside_tree() and not timer.timeout.is_connected(_on_timer_timeout):
			timer.timeout.connect(_on_timer_timeout)

func _ensure_refs() -> void:
	if terrain == null or not is_instance_valid(terrain):
		terrain = get_tree().get_first_node_in_group("terrain")
	if pathfinder == null or not is_instance_valid(pathfinder):
		var pf := get_tree().get_first_node_in_group("pathfinder")
		if pf is TerrainPathfinder:
			pathfinder = pf
		elif get_parent() != null:
			var found := get_parent().find_child("*Pathfinder*", true, false)
			if found is TerrainPathfinder:
				pathfinder = found
	if needs_label == null:
		needs_label = get_node_or_null("NeedsLabel")

func _clamp_to_map(pos: Vector2, margin: float = 20.0) -> Vector2:
	if terrain != null and terrain.has_method("clamp_world_pos_to_map"):
		return terrain.clamp_world_pos_to_map(pos, margin)
	return pos

func _is_walkable(pos: Vector2) -> bool:
	if terrain == null:
		return true
	if terrain.has_method("is_walkable_at"):
		return bool(terrain.call("is_walkable_at", pos))
	if terrain.has_method("is_wall_at"):
		return not bool(terrain.call("is_wall_at", pos))
	return true

func _can_step_to(next_pos: Vector2) -> bool:
	return _is_walkable(next_pos)

func _snap_to_walkable(pos: Vector2, margin: float = 16.0) -> Vector2:
	var clamped := _clamp_to_map(pos, margin)
	if _is_walkable(clamped):
		return clamped

	var step := 16.0
	for radius_idx in range(1, 6):
		var r := step * float(radius_idx)
		for dir_idx in range(12):
			var angle := (TAU / 12.0) * float(dir_idx)
			var candidate := _clamp_to_map(clamped + Vector2(cos(angle), sin(angle)) * r, margin)
			if _is_walkable(candidate):
				return candidate

	return clamped

func _set_nav_target(pos: Vector2, margin: float = 16.0) -> void:
	_ensure_refs()
	_stuck_time = 0.0
	var goal := _snap_to_walkable(pos, margin)

	if navigation_agent != null:
		navigation_agent.target_position = goal

	if pathfinder != null:
		_path_points = pathfinder.find_world_path(global_position, goal, true)
		_path_index = 1 if _path_points.size() > 1 else 0
	else:
		_path_points = PackedVector2Array([global_position, goal])
		_path_index = 1

func _has_active_path() -> bool:
	return _path_index < _path_points.size()

func _get_current_waypoint() -> Vector2:
	if _path_index < _path_points.size():
		return _path_points[_path_index]
	if pathfinder == null and navigation_agent != null:
		return navigation_agent.get_next_path_position()
	return global_position

func _abort_current_job(drop_food: bool = true) -> void:
	if drop_food and haul_to_stockpile:
		_drop_carried_food()
	if current_job != null:
		TaskManager.release_job(current_job, self)
		current_job = null
	if target != null:
		FoodManager.release_claim(target, self)
		target = null
	_stuck_time = 0.0
	_path_points.clear()
	_path_index = 0
	velocity = Vector2.ZERO
	if navigation_agent != null:
		navigation_agent.target_position = global_position
	_refresh_needs_ui()

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
		carrying_food.global_position = _snap_to_walkable(global_position, 12.0)
		carrying_food.visible = true
		carrying_food.set("claimed_by", null)
		FoodManager.register_food(carrying_food)
		if not TaskManager.has_job_for_node(carrying_food):
			TaskManager.add_job(Job.new("haul", 20, carrying_food.global_position, carrying_food))
	carrying_food = null
	haul_to_stockpile = false
	_refresh_needs_ui()

func _eat_food_gain() -> void:
	hunger = clampf(hunger + 45.0, 0.0, max_hunger)
	if current_job != null:
		TaskManager.complete_job(current_job, self)
		current_job = null
	target = null
	_stuck_time = 0.0
	_path_points.clear()
	_path_index = 0
	navigation_agent.target_position = global_position
	_refresh_needs_ui()

func get_primary_need_text() -> String:
	if hunger <= 15.0:
		return "STARVING (Food)"
	if hunger <= 35.0:
		return "Hungry (Food)"
	if carrying_food != null:
		return "Hauling Food"
	if current_job != null:
		match current_job.type:
			"haul":
				return "Finding Food to Haul"
			"forage":
				return "Foraging"
			"fetch_stockpile":
				return "Fetching from Stockpile"
			"wander":
				return "Exploring"
			_:
				return "Job: %s" % current_job.type
	return "Idle / Content"

func get_needs_summary() -> String:
	var h_int := int(round(hunger))
	var pouch_str := "Pouch: Full" if carrying_food != null else "Pouch: Empty"
	return "%s | Hunger: %d/%d | %s" % [get_primary_need_text(), h_int, int(max_hunger), pouch_str]

func _refresh_needs_ui() -> void:
	var h_int := int(round(hunger))
	$Hunger.text = "%d%%" % h_int
	if needs_label != null and is_instance_valid(needs_label):
		needs_label.visible = show_needs_in_world
		if show_needs_in_world:
			var pouch_str := "Pouch: Full" if carrying_food != null else "Pouch: Empty"
			needs_label.text = "%s\n%s" % [get_primary_need_text(), pouch_str]

func _seek_food_if_needed() -> bool:
	if hunger > 35.0:
		return false
	if current_job != null and (current_job.type == "forage" or current_job.type == "fetch_stockpile") and is_instance_valid(target):
		return true

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
		_set_nav_target(food_node.global_position, 16.0)
		_refresh_needs_ui()
		return true

	var pile := _get_nearest_stockpile(true)
	if pile != null:
		target = pile
		var fetch_job := Job.new("fetch_stockpile", 2, pile.global_position, pile)
		fetch_job.claimed_by = self
		TaskManager.add_job(fetch_job)
		current_job = fetch_job
		_set_nav_target(pile.global_position, 16.0)
		_refresh_needs_ui()
		return true

	return false

func _physics_process(delta: float) -> void:
	_ensure_refs()

	var activity_drain_mult := 1.25 if movement_state == MovementState.WALKING else 0.85
	_hunger_carryover += hunger_drain_per_second * activity_drain_mult * delta
	if _hunger_carryover >= 0.25:
		hunger = maxf(0.0, hunger - _hunger_carryover)
		_hunger_carryover = 0.0

	if Input.is_action_just_pressed("DEBUG FEED"):
		hunger = clampf(hunger + 50.0, 0.0, max_hunger)

	if Input.is_action_just_pressed("exit"):
		get_tree().quit()

	if hunger > 25.0:
		mood = MoodState.HAPPY
		pouch = PouchState.FULL if carrying_food != null else PouchState.EMPTY
	elif hunger >= 15.0:
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
		_abort_current_job(true)

	if target != null and not is_instance_valid(target) and not haul_to_stockpile:
		target = null
		_path_points.clear()
		_path_index = 0
		navigation_agent.target_position = global_position

	var target_multiplier: float = 1.0
	if terrain != null and terrain.has_method("get_speed_multiplier_at"):
		target_multiplier = float(terrain.call("get_speed_multiplier_at", global_position))
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
				_set_nav_target(pile.global_position, 16.0)
				just_switched_to_stockpile = true
				_refresh_needs_ui()

	while _has_active_path() and global_position.distance_to(_path_points[_path_index]) <= 6.0:
		_path_index += 1

	var path_done := not _has_active_path() and (navigation_agent == null or navigation_agent.is_navigation_finished())

	if not just_switched_to_stockpile and path_done:
		velocity = velocity.lerp(Vector2.ZERO, ACCELERATION * delta)
		_stuck_time = 0.0
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
					_set_nav_target(pile.global_position, 16.0)
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
		_refresh_needs_ui()
	else:
		var waypoint := _get_current_waypoint()
		var direction := waypoint - global_position
		if direction.length_squared() > 0.0001:
			direction = direction.normalized()
		else:
			direction = Vector2.ZERO

		if effective_speed <= 0.01:
			_stuck_time += delta
			velocity = velocity.lerp(Vector2.ZERO, ACCELERATION * 2.0 * delta)
			if _stuck_time >= 0.6:
				_abort_current_job(true)
		else:
			_stuck_time = 0.0
			velocity = velocity.lerp(direction * effective_speed, ACCELERATION * delta)

	var proposed_pos := global_position + velocity * delta
	if not _can_step_to(proposed_pos):
		var slide_x := Vector2(velocity.x, 0.0)
		var slide_y := Vector2(0.0, velocity.y)
		if velocity.x != 0.0 and _can_step_to(global_position + slide_x * delta):
			velocity = slide_x
		elif velocity.y != 0.0 and _can_step_to(global_position + slide_y * delta):
			velocity = slide_y
		else:
			velocity = Vector2.ZERO
			_stuck_time += delta
			if _stuck_time >= 0.35:
				_abort_current_job(true)

	move_and_slide()

	if not _is_walkable(global_position):
		global_position = _snap_to_walkable(global_position, 12.0)
		velocity = Vector2.ZERO
	else:
		global_position = _clamp_to_map(global_position, 12.0)

	for area in food_detector.get_overlapping_areas():
		if area.is_in_group("food"):
			var food_root := area.get_parent()
			if food_root == carrying_food:
				continue
			if hunger <= 35.0 or (current_job != null and current_job.type == "forage"):
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
	_refresh_needs_ui()

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
	if _seek_food_if_needed():
		return

	if follow_cursor and is_instance_valid(cursor):
		if current_job != null:
			if current_job.type == "haul" and haul_to_stockpile:
				_drop_carried_food()
			TaskManager.release_job(current_job, self)
			current_job = null
		target = null
		_set_nav_target(cursor.global_position, 16.0)
		_refresh_needs_ui()
		return

	if current_job == null:
		var next_job := TaskManager.request_job(self, global_position)
		if next_job == null:
			var wander_offset := Vector2(randf_range(-80.0, 80.0), randf_range(-80.0, 80.0))
			var clamped_wander := _snap_to_walkable(global_position + wander_offset, 24.0)
			next_job = Job.new("wander", 50, clamped_wander, null)
			next_job.claimed_by = self
			TaskManager.add_job(next_job)

		current_job = next_job
		if current_job.type == "haul" and is_instance_valid(current_job.target_node):
			target = current_job.target_node
			_set_nav_target(current_job.target_node.global_position, 16.0)
		else:
			_set_nav_target(current_job.target_pos, 24.0)

	_refresh_needs_ui()
