extends CharacterBody2D

signal player_caught
signal state_changed(state_name: String)

enum GhostState {
	PATROL,
	INVESTIGATE,
	CHASE,
	SEARCH,
}

@export var patrol_speed: float = 90.0
@export var investigate_speed: float = 125.0
@export var chase_speed: float = 205.0
@export var search_speed: float = 118.0
@export var vision_radius: float = 280.0
@export var hearing_radius: float = 230.0
@export var investigate_duration: float = 3.8
@export var search_duration: float = 5.2
@export var chase_memory_duration: float = 2.5

var player: Node = null
var patrol_points: Array[Vector2] = []
var state: GhostState = GhostState.PATROL
var investigate_target: Vector2 = Vector2.ZERO
var last_seen_position: Vector2 = Vector2.ZERO
var search_anchor: Vector2 = Vector2.ZERO
var search_target: Vector2 = Vector2.ZERO
var flashlight_slow_factor: float = 1.0

var _state_timer: float = 0.0
var _lost_sight_timer: float = 0.0
var _patrol_index: int = 0
var _facing := Vector2.RIGHT
var _rng := RandomNumberGenerator.new()

@onready var body_visual: Polygon2D = $Body

func _ready() -> void:
	_rng.randomize()
	_emit_state()


func setup(player_ref: Node, patrol_points_ref: Array[Vector2]) -> void:
	player = player_ref
	patrol_points = patrol_points_ref.duplicate()
	if not patrol_points.is_empty():
		investigate_target = patrol_points[0]


func hear_noise(position: Vector2, strength: float) -> void:
	if player == null or state == GhostState.CHASE:
		return

	var effective_hearing := hearing_radius * maxf(0.6, strength)
	if global_position.distance_to(position) <= effective_hearing:
		investigate_target = position
		_change_state(GhostState.INVESTIGATE)
		_state_timer = investigate_duration


func mark_hiding_spot(position: Vector2) -> void:
	last_seen_position = position
	search_anchor = position
	_change_state(GhostState.SEARCH)
	_state_timer = search_duration
	search_target = _random_search_point()


func get_state_name() -> String:
	match state:
		GhostState.PATROL:
			return "PATROL"
		GhostState.INVESTIGATE:
			return "INVESTIGATE"
		GhostState.CHASE:
			return "CHASE"
		_:
			return "SEARCH"


func _physics_process(delta: float) -> void:
	if player == null:
		return

	var sees_player := _can_see_player()
	if sees_player:
		last_seen_position = player.global_position
		_lost_sight_timer = 0.0
		_change_state(GhostState.CHASE)
	else:
		_lost_sight_timer += delta

	var target_velocity := Vector2.ZERO
	match state:
		GhostState.PATROL:
			target_velocity = _update_patrol()
		GhostState.INVESTIGATE:
			target_velocity = _update_investigate(delta)
		GhostState.CHASE:
			target_velocity = _update_chase(sees_player)
		GhostState.SEARCH:
			target_velocity = _update_search(delta)

	velocity = target_velocity * flashlight_slow_factor
	if velocity.length() > 0.0:
		_facing = velocity.normalized()
		rotation = _facing.angle() + PI / 2.0

	move_and_slide()
	body_visual.color = Color(0.82 + _rng.randf() * 0.08, 0.92, 1, 0.9)

	if global_position.distance_to(player.global_position) < 22.0:
		player_caught.emit()


func _update_patrol() -> Vector2:
	if patrol_points.is_empty():
		return Vector2.ZERO

	var current_target := patrol_points[_patrol_index % patrol_points.size()]
	if global_position.distance_to(current_target) < 16.0:
		_patrol_index = (_patrol_index + 1) % patrol_points.size()
		current_target = patrol_points[_patrol_index % patrol_points.size()]
	return global_position.direction_to(current_target) * patrol_speed


func _update_investigate(delta: float) -> Vector2:
	_state_timer -= delta
	if global_position.distance_to(investigate_target) < 18.0 or _state_timer <= 0.0:
		search_anchor = investigate_target
		search_target = _random_search_point()
		_change_state(GhostState.SEARCH)
		_state_timer = search_duration
	return global_position.direction_to(investigate_target) * investigate_speed


func _update_chase(sees_player: bool) -> Vector2:
	if sees_player:
		last_seen_position = player.global_position
	else:
		if _lost_sight_timer >= chase_memory_duration:
			search_anchor = last_seen_position
			search_target = _random_search_point()
			_change_state(GhostState.SEARCH)
			_state_timer = search_duration
			return Vector2.ZERO
	return global_position.direction_to(last_seen_position) * chase_speed


func _update_search(delta: float) -> Vector2:
	_state_timer -= delta
	if search_target == Vector2.ZERO or global_position.distance_to(search_target) < 18.0:
		search_target = _random_search_point()

	if _state_timer <= 0.0:
		_change_state(GhostState.PATROL)
		return Vector2.ZERO

	return global_position.direction_to(search_target) * search_speed


func _change_state(next_state: GhostState) -> void:
	if state == next_state:
		return
	state = next_state
	_emit_state()


func _emit_state() -> void:
	state_changed.emit(get_state_name())


func _random_search_point() -> Vector2:
	return search_anchor + Vector2(
		_rng.randf_range(-90.0, 90.0),
		_rng.randf_range(-90.0, 90.0)
	)


func _can_see_player() -> bool:
	if player == null:
		return false

	var to_player := player.global_position - global_position
	var distance := to_player.length()
	var bonus := player.get_visibility_bonus() if player.has_method("get_visibility_bonus") else 0.0
	var allowed_distance := vision_radius * (1.0 + bonus)
	if distance > allowed_distance:
		return false

	if player.is_hiding and state != GhostState.CHASE and distance > 62.0:
		return false

	var forward := _facing
	var vision_arc := deg_to_rad(130.0 if state == GhostState.CHASE else 100.0)
	var angle := abs(forward.angle_to(to_player.normalized()))
	if angle > vision_arc * 0.5:
		return false

	var query := PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = 2
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	return result.is_empty()


func set_flashlight_slowed(active: bool) -> void:
	flashlight_slow_factor = 0.68 if active else 1.0
