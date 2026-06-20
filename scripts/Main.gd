extends Node2D

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const GHOST_SCENE := preload("res://scenes/Ghost.tscn")
const KEY_SCENE := preload("res://scenes/Key.tscn")
const EXIT_SCENE := preload("res://scenes/ExitDoor.tscn")
const HIDING_SPOT_SCENE := preload("res://scenes/HidingSpot.tscn")
const UI_SCENE := preload("res://scenes/UI.tscn")

const TOTAL_KEYS := 3

var player: Node = null
var ghost: Node = null
var exit_door: Node = null
var ui: Node = null
var collected_keys: int = 0
var game_finished: bool = false
var patrol_points: Array[Vector2] = [
	Vector2(-520, -260),
	Vector2(-120, 0),
	Vector2(390, -260),
	Vector2(-510, 250),
	Vector2(380, 250),
	Vector2(620, 0),
]

var _paranormal_timer: float = 5.0
var _rng := RandomNumberGenerator.new()

@onready var world: Node2D = $World
@onready var map_root: Node2D = $World/Map
@onready var props_root: Node2D = $World/Props
@onready var actors_root: Node2D = $World/Actors

func _ready() -> void:
	_rng.randomize()
	_build_map()
	_spawn_gameplay()


func _process(delta: float) -> void:
	if game_finished:
		return

	var ghost_distance: float = player.global_position.distance_to(ghost.global_position)
	var proximity_fear: float = inverse_lerp(420.0, 85.0, ghost_distance)
	var darkness_fear: float = 0.2 if not player.flashlight_on else 0.0
	var calm_bonus: float = 0.18 if player.flashlight_on and ghost_distance > 300.0 else 0.0
	var fear: float = clampf(proximity_fear + darkness_fear - calm_bonus, 0.0, 1.0)

	player.set_fear(fear)
	ui.set_fear(fear)
	ui.set_stamina(player.stamina, player.max_stamina)
	ui.set_battery(player.battery, player.max_battery)
	ui.set_warning("RUN" if ghost_distance < 150.0 else "HIDE" if ghost_distance < 240.0 else "")
	ghost.set_flashlight_slowed(player.is_flashlight_affecting_point(ghost.global_position))

	_paranormal_timer -= delta
	if _paranormal_timer <= 0.0:
		_trigger_paranormal_event(fear)
		_paranormal_timer = _rng.randf_range(4.0, 8.0)


func _build_map() -> void:
	var floors := [
		Rect2(-680, -400, 340, 260),
		Rect2(-340, -90, 760, 180),
		Rect2(220, -400, 360, 260),
		Rect2(-680, 120, 340, 280),
		Rect2(220, 120, 360, 280),
		Rect2(560, -140, 220, 280),
	]

	for floor_rect in floors:
		_add_floor_rect(floor_rect, Color(0.09, 0.1, 0.13))

	var walls := [
		{ "position": Vector2(50, -430), "size": Vector2(1490, 26) },
		{ "position": Vector2(50, 430), "size": Vector2(1490, 26) },
		{ "position": Vector2(-705, 0), "size": Vector2(26, 860) },
		{ "position": Vector2(785, 0), "size": Vector2(26, 860) },
		{ "position": Vector2(-340, -275), "size": Vector2(26, 248) },
		{ "position": Vector2(220, -275), "size": Vector2(26, 248) },
		{ "position": Vector2(-340, 260), "size": Vector2(26, 280) },
		{ "position": Vector2(220, 260), "size": Vector2(26, 280) },
		{ "position": Vector2(560, -255), "size": Vector2(26, 290) },
		{ "position": Vector2(560, 255), "size": Vector2(26, 290) },
		{ "position": Vector2(520, 0), "size": Vector2(26, 190) },
		{ "position": Vector2(-515, -115), "size": Vector2(180, 26) },
		{ "position": Vector2(390, -115), "size": Vector2(180, 26) },
		{ "position": Vector2(-515, 115), "size": Vector2(180, 26) },
		{ "position": Vector2(390, 115), "size": Vector2(180, 26) },
	]

	for wall_data in walls:
		_add_wall(wall_data["position"], wall_data["size"])

	_add_prop_rect(Vector2(-550, -290), Vector2(90, 30), Color(0.18, 0.2, 0.24))
	_add_prop_rect(Vector2(-500, 235), Vector2(100, 44), Color(0.17, 0.16, 0.18))
	_add_prop_rect(Vector2(360, -300), Vector2(100, 36), Color(0.18, 0.2, 0.23))
	_add_prop_rect(Vector2(395, 245), Vector2(90, 90), Color(0.2, 0.12, 0.12))


func _spawn_gameplay() -> void:
	ui = UI_SCENE.instantiate()
	add_child(ui)
	ui.restart_requested.connect(_restart_game)

	player = PLAYER_SCENE.instantiate()
	player.global_position = Vector2(-555, -260)
	actors_root.add_child(player)
	player.noise_emitted.connect(_on_player_noise_emitted)
	player.hide_toggled.connect(_on_player_hide_toggled)

	ghost = GHOST_SCENE.instantiate()
	ghost.global_position = Vector2(610, 0)
	actors_root.add_child(ghost)
	ghost.setup(player, patrol_points)
	ghost.player_caught.connect(_on_player_caught)
	ghost.state_changed.connect(func(state_name: String) -> void: ui.set_ghost_state(state_name))

	exit_door = EXIT_SCENE.instantiate()
	exit_door.global_position = Vector2(700, 0)
	props_root.add_child(exit_door)
	exit_door.exit_reached.connect(_on_exit_reached)

	for key_position in [Vector2(390, -255), Vector2(-500, 245), Vector2(380, 250)]:
		var key := KEY_SCENE.instantiate()
		key.global_position = key_position
		props_root.add_child(key)
		key.collected.connect(_on_key_collected)

	for spot_position in [Vector2(-575, -205), Vector2(300, -255), Vector2(-610, 240), Vector2(470, 240)]:
		var hiding_spot := HIDING_SPOT_SCENE.instantiate()
		hiding_spot.global_position = spot_position
		props_root.add_child(hiding_spot)

	ui.set_key_count(collected_keys, TOTAL_KEYS)
	ui.set_ghost_state(ghost.get_state_name())
	ui.show_message("Find 3 keys. Avoid the ghost.", 3.0)


func _add_floor_rect(rect: Rect2, color: Color) -> void:
	var polygon := Polygon2D.new()
	polygon.polygon = PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.position + rect.size,
		rect.position + Vector2(0, rect.size.y),
	])
	polygon.color = color
	map_root.add_child(polygon)


func _add_wall(position: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	body.position = position

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, size.y * 0.5),
		Vector2(-size.x * 0.5, size.y * 0.5),
	])
	visual.color = Color(0.2, 0.22, 0.26)
	body.add_child(visual)

	map_root.add_child(body)


func _add_prop_rect(position: Vector2, size: Vector2, color: Color) -> void:
	var polygon := Polygon2D.new()
	polygon.position = position
	polygon.polygon = PackedVector2Array([
		Vector2(-size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, size.y * 0.5),
		Vector2(-size.x * 0.5, size.y * 0.5),
	])
	polygon.color = color
	map_root.add_child(polygon)


func _on_player_noise_emitted(position: Vector2, strength: float) -> void:
	ghost.hear_noise(position, strength)


func _on_player_hide_toggled(is_hiding: bool, hiding_spot: Node) -> void:
	if is_hiding and ghost.get_state_name() == "CHASE":
		ghost.mark_hiding_spot(hiding_spot.global_position)
		ui.show_message("You slipped into hiding.", 1.5)
	elif not is_hiding:
		ui.show_message("You left hiding.", 1.2)


func _on_key_collected() -> void:
	collected_keys += 1
	ui.set_key_count(collected_keys, TOTAL_KEYS)
	ui.show_message("Key found. %d left." % (TOTAL_KEYS - collected_keys), 1.4)
	if collected_keys >= TOTAL_KEYS:
		exit_door.set_unlocked(true)
		ui.show_message("The exit unlocked. Move.", 2.2)


func _on_player_caught() -> void:
	if game_finished:
		return
	game_finished = true
	player.set_process(false)
	player.set_physics_process(false)
	ghost.set_process(false)
	ghost.set_physics_process(false)
	ui.show_end_screen(false)


func _on_exit_reached() -> void:
	if game_finished:
		return
	game_finished = true
	player.set_process(false)
	player.set_physics_process(false)
	ghost.set_process(false)
	ghost.set_physics_process(false)
	ui.show_end_screen(true)


func _trigger_paranormal_event(fear: float) -> void:
	if fear < 0.28 and _rng.randf() < 0.55:
		return

	match _rng.randi_range(0, 3):
		0:
			ui.show_message("A whisper curls through the dark.", 1.8)
		1:
			ui.show_message("Something moved at the edge of your light.", 1.8)
			ui.flash_silhouette()
		2:
			ui.show_message("The lights flicker.", 1.3)
			ui.flash_flicker(0.85)
		_:
			ui.show_message("Cold air brushes past you.", 1.6)


func _restart_game() -> void:
	get_tree().reload_current_scene()
