extends CanvasLayer

@export var toggle_key: Key = KEY_F1
@export var start_open: bool = false
@export var cursor_node_path: NodePath = NodePath("../Cursor")
@export var hamster_scene: PackedScene = preload("res://hamster.tscn")
@export var food_scene: PackedScene
@export var other_item_scenes: Array[PackedScene] = []
@export var other_item_names: PackedStringArray = []

var _panel: PanelContainer
var _stats_label: Label
var _needs_list_label: RichTextLabel
var _selected_other_index: int = 0
var _refresh_accum: float = 0.0

func _ready() -> void:
	layer = 100
	_build_ui()
	_set_menu_visible(start_open)
	_refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == toggle_key:
		_set_menu_visible(not _panel.visible)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not _panel.visible:
		return
	_refresh_accum += delta
	if _refresh_accum >= 0.25:
		_refresh_accum = 0.0
		_refresh_ui()

func _set_menu_visible(is_vis: bool) -> void:
	if _panel != null:
		_panel.visible = is_vis
	if is_vis:
		_refresh_ui()

func _get_terrain() -> Node2D:
	if get_tree() != null and not get_tree().get_nodes_in_group("terrain").is_empty():
		var first_terrain: Node = get_tree().get_nodes_in_group("terrain")[0]
		if first_terrain is Node2D:
			return first_terrain as Node2D
	return null

func _get_cursor_node() -> Node2D:
	if cursor_node_path != NodePath(""):
		var direct: Node = get_node_or_null(cursor_node_path)
		if direct is Node2D and is_instance_valid(direct):
			return direct as Node2D

	var parent_node: Node = get_parent()
	if parent_node != null:
		var sibling_cursor: Node = parent_node.get_node_or_null("Cursor")
		if sibling_cursor is Node2D and is_instance_valid(sibling_cursor):
			return sibling_cursor as Node2D
		var found_in_parent: Node = parent_node.find_child("Cursor", true, false)
		if found_in_parent is Node2D and is_instance_valid(found_in_parent):
			return found_in_parent as Node2D

	if get_tree() != null and get_tree().current_scene != null:
		var scene_cursor: Node = get_tree().current_scene.get_node_or_null("Cursor")
		if scene_cursor is Node2D and is_instance_valid(scene_cursor):
			return scene_cursor as Node2D
		var found_in_scene: Node = get_tree().current_scene.find_child("Cursor", true, false)
		if found_in_scene is Node2D and is_instance_valid(found_in_scene):
			return found_in_scene as Node2D

	return null

func _get_spawn_parent() -> Node:
	var cursor_node: Node2D = _get_cursor_node()
	if cursor_node != null and cursor_node.get_parent() != null:
		return cursor_node.get_parent()
	var terrain: Node2D = _get_terrain()
	if terrain != null and terrain.get_parent() != null:
		return terrain.get_parent()
	if get_tree() != null and get_tree().current_scene != null:
		return get_tree().current_scene
	return self

func _get_spawn_pos() -> Vector2:
	var spawn_pos: Vector2 = Vector2.ZERO
	var cursor_node: Node2D = _get_cursor_node()
	if cursor_node != null:
		spawn_pos = cursor_node.global_position
	else:
		var cam: Camera2D = get_viewport().get_camera_2d()
		if cam != null:
			spawn_pos = cam.get_screen_center_position()

	var terrain: Node2D = _get_terrain()
	if terrain != null and terrain.has_method("clamp_world_pos_to_map"):
		var clamped_val: Variant = terrain.call("clamp_world_pos_to_map", spawn_pos, 16.0)
		if clamped_val is Vector2:
			spawn_pos = clamped_val as Vector2
	return spawn_pos

func _resolve_food_scene() -> PackedScene:
	if food_scene != null:
		return food_scene
	var terrain: Node2D = _get_terrain()
	if terrain != null:
		var cs: Variant = terrain.get("custom_scene")
		if cs is PackedScene:
			return cs as PackedScene
	return null

func _on_spawn_hamster_pressed() -> void:
	if hamster_scene == null:
		push_warning("DebugMenu: hamster_scene is not assigned.")
		return
	var h: Node = hamster_scene.instantiate()
	if h is Node2D:
		_get_spawn_parent().add_child(h)
		(h as Node2D).global_position = _get_spawn_pos()
	_refresh_ui()

func _on_remove_hamster_pressed() -> void:
	var hamsters: Array[Node] = get_tree().get_nodes_in_group("hamsters")
	for i in range(hamsters.size() - 1, -1, -1):
		var h: Node = hamsters[i]
		if is_instance_valid(h):
			if h.has_method("_abort_current_job"):
				h.call("_abort_current_job", true)
			h.queue_free()
			break
	call_deferred("_refresh_ui")

func _on_spawn_food_pressed() -> void:
	var f_scene: PackedScene = _resolve_food_scene()
	if f_scene == null:
		push_warning("DebugMenu: No food_scene set on DebugMenu or custom_scene on Terrain.")
		return
	var item: Node = f_scene.instantiate()
	if item is Node2D:
		item.add_to_group("spawned_prop")
		_get_spawn_parent().add_child(item)
		var item_2d: Node2D = item as Node2D
		item_2d.global_position = _get_spawn_pos()
		FoodManager.register_food(item_2d)
		var haul_job: Job = Job.new("haul", 20, item_2d.global_position, item_2d)
		TaskManager.add_job(haul_job)
	_refresh_ui()

func _on_spawn_other_item_pressed() -> void:
	if other_item_scenes.is_empty():
		push_warning("DebugMenu: Assign one or more PackedScenes to other_item_scenes.")
		return
	var idx: int = clampi(_selected_other_index, 0, other_item_scenes.size() - 1)
	var chosen: PackedScene = other_item_scenes[idx]
	if chosen == null:
		return
	var prop: Node = chosen.instantiate()
	if prop is Node2D:
		prop.add_to_group("spawned_prop")
		_get_spawn_parent().add_child(prop)
		(prop as Node2D).global_position = _get_spawn_pos()
	_refresh_ui()

func _on_cycle_other_item_pressed() -> void:
	if other_item_scenes.is_empty():
		return
	_selected_other_index = (_selected_other_index + 1) % other_item_scenes.size()
	_refresh_ui()

func _on_toggle_world_needs_pressed() -> void:
	for h in get_tree().get_nodes_in_group("hamsters"):
		if is_instance_valid(h) and "show_needs_in_world" in h:
			h.set("show_needs_in_world", not bool(h.get("show_needs_in_world")))
			if h.has_method("_refresh_needs_ui"):
				h.call("_refresh_needs_ui")
	_refresh_ui()

func _get_other_item_label() -> String:
	if other_item_scenes.is_empty():
		return "Other Item: (None)"
	var idx: int = clampi(_selected_other_index, 0, other_item_scenes.size() - 1)
	var item_name: String = "Item %d" % idx
	if idx < other_item_names.size() and other_item_names[idx] != "":
		item_name = other_item_names[idx]
	elif other_item_scenes[idx] != null:
		item_name = other_item_scenes[idx].resource_path.get_file()
	return "Other Item: %s (%d/%d)" % [item_name, idx + 1, other_item_scenes.size()]

func _refresh_ui() -> void:
	if _stats_label == null or _needs_list_label == null:
		return
	var hamsters: Array[Node] = get_tree().get_nodes_in_group("hamsters")
	var valid_hamsters: Array[Node] = []
	for h in hamsters:
		if is_instance_valid(h) and not h.is_queued_for_deletion():
			valid_hamsters.append(h)

	var food_count: int = 0
	var foods_prop: Variant = FoodManager.get("foods")
	if foods_prop is Array:
		var foods_arr: Array = foods_prop as Array
		food_count = foods_arr.size()
	elif foods_prop is Dictionary:
		var foods_dict: Dictionary = foods_prop as Dictionary
		food_count = foods_dict.size()
	_stats_label.text = "Hamsters: %d | Tracked Food: %d | [F1] Toggle" % [valid_hamsters.size(), food_count]

	var lines: PackedStringArray = PackedStringArray()
	for h in valid_hamsters:
		var h_name: String = str(h.get_node("Name").text) if h.has_node("Name") else h.name
		var summary: String = str(h.call("get_needs_summary")) if h.has_method("get_needs_summary") else "Hunger: %s" % str(h.get("hunger"))
		lines.append("[b]%s[/b]: %s" % [h_name, summary])

	_needs_list_label.text = "\n".join(lines) if not lines.is_empty() else "[i]No active hamsters.[/i]"

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "DebugPanel"
	_panel.position = Vector2(16, 16)
	_panel.custom_minimum_size = Vector2(360, 320)
	add_child(_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var title: Label = Label.new()
	title.text = "COLONY DEBUG MENU"
	vbox.add_child(title)

	_stats_label = Label.new()
	vbox.add_child(_stats_label)

	var row1: HBoxContainer = HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	vbox.add_child(row1)

	var btn_spawn_ham: Button = Button.new()
	btn_spawn_ham.text = "+ Spawn Hamster"
	btn_spawn_ham.pressed.connect(_on_spawn_hamster_pressed)
	row1.add_child(btn_spawn_ham)

	var btn_rem_ham: Button = Button.new()
	btn_rem_ham.text = "- Remove Hamster"
	btn_rem_ham.pressed.connect(_on_remove_hamster_pressed)
	row1.add_child(btn_rem_ham)

	var row2: HBoxContainer = HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	vbox.add_child(row2)

	var btn_spawn_food: Button = Button.new()
	btn_spawn_food.text = "+ Spawn Food"
	btn_spawn_food.pressed.connect(_on_spawn_food_pressed)
	row2.add_child(btn_spawn_food)

	var btn_toggle_needs: Button = Button.new()
	btn_toggle_needs.text = "Toggle World Needs"
	btn_toggle_needs.pressed.connect(_on_toggle_world_needs_pressed)
	row2.add_child(btn_toggle_needs)

	var row3: HBoxContainer = HBoxContainer.new()
	row3.add_theme_constant_override("separation", 6)
	vbox.add_child(row3)

	var btn_spawn_other: Button = Button.new()
	btn_spawn_other.text = "+ Spawn Item"
	btn_spawn_other.pressed.connect(_on_spawn_other_item_pressed)
	row3.add_child(btn_spawn_other)

	var btn_cycle_other: Button = Button.new()
	btn_cycle_other.text = _get_other_item_label()
	btn_cycle_other.pressed.connect(func() -> void:
		_on_cycle_other_item_pressed()
		btn_cycle_other.text = _get_other_item_label()
	)
	row3.add_child(btn_cycle_other)

	var needs_header: Label = Label.new()
	needs_header.text = "Hamster Needs:"
	vbox.add_child(needs_header)

	_needs_list_label = RichTextLabel.new()
	_needs_list_label.bbcode_enabled = true
	_needs_list_label.custom_minimum_size = Vector2(335, 150)
	_needs_list_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_needs_list_label)
