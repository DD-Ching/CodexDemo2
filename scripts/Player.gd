extends CharacterBody2D

signal noise_emitted(position: Vector2, strength: float)
signal hide_toggled(is_hiding: bool, hiding_spot: Node)
signal flashlight_toggled(is_on: bool)

@export var walk_speed: float = 165.0
@export var sprint_speed: float = 255.0
@export var fear_speed_penalty: float = 0.22
@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 28.0
@export var stamina_regen_rate: float = 18.0
@export var max_battery: float = 100.0
@export var battery_drain_rate: float = 18.0
@export var battery_regen_rate: float = 9.0

var stamina: float = max_stamina
var battery: float = max_battery
var keys_collected: int = 0
var fear_level: float = 0.0
var noise_level: float = 0.0
var flashlight_on: bool = false
var is_hiding: bool = false
var nearby_hiding_spot: Node = null

var _flashlight_points: PackedVector2Array = PackedVector2Array()
var _noise_timer: float = 0.0
var _camera_trauma: float = 0.0
var _rng := RandomNumberGenerator.new()

@onready var flashlight_cone: Polygon2D = $FlashlightCone
@onready var personal_light: PointLight2D = $PersonalLight
@onready var interaction_area: Area2D = $InteractionArea
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	_rng.randomize()
	interaction_area.area_entered.connect(_on_interaction_area_entered)
	interaction_area.area_exited.connect(_on_interaction_area_exited)
	_flashlight_points = PackedVector2Array([
		Vector2.ZERO,
		Vector2(-48.0, -26.0),
		Vector2(-220.0, 0.0),
		Vector2(-48.0, 26.0),
	])
	_update_flashlight_visuals()
	_update_personal_light()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if battery > 2.0 or flashlight_on:
			flashlight_on = not flashlight_on
			flashlight_toggled.emit(flashlight_on)
			_update_flashlight_visuals()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if nearby_hiding_spot != null:
			if is_hiding:
				_exit_hiding()
			else:
				_enter_hiding()


func _physics_process(delta: float) -> void:
	look_at(get_global_mouse_position())

	if is_hiding:
		velocity = Vector2.ZERO
		move_and_slide()
		noise_level = 0.0
	else:
		var input_vector := _get_input_vector()
		var sprinting := input_vector != Vector2.ZERO and Input.is_key_pressed(KEY_SHIFT) and stamina > 0.0
		var fear_modifier := 1.0 - fear_level * fear_speed_penalty
		var move_speed := walk_speed
		if sprinting:
			move_speed = sprint_speed
			stamina = max(stamina - stamina_drain_rate * delta, 0.0)
		else:
			stamina = min(stamina + stamina_regen_rate * delta, max_stamina)

		velocity = input_vector * move_speed * fear_modifier
		move_and_slide()

		if input_vector == Vector2.ZERO:
			noise_level = 0.04
		elif sprinting:
			noise_level = 1.25
		else:
			noise_level = 0.45

		if input_vector != Vector2.ZERO:
			_noise_timer -= delta
			if _noise_timer <= 0.0:
				_noise_timer = 0.35 if sprinting else 0.7
				noise_emitted.emit(global_position, noise_level)

	if flashlight_on:
		battery = max(battery - battery_drain_rate * delta, 0.0)
		if battery <= 0.0:
			flashlight_on = false
			flashlight_toggled.emit(false)
	else:
		battery = min(battery + battery_regen_rate * delta, max_battery)

	_update_flashlight_visuals()
	_update_personal_light()


func _process(delta: float) -> void:
	var shake_strength := fear_level * fear_level
	if shake_strength > 0.0:
		_camera_trauma = min(_camera_trauma + shake_strength * delta * 1.6, 0.65)
	else:
		_camera_trauma = max(_camera_trauma - delta, 0.0)

	camera.offset = Vector2(
		_rng.randf_range(-1.0, 1.0),
		_rng.randf_range(-1.0, 1.0)
	) * 16.0 * _camera_trauma


func add_key() -> void:
	keys_collected += 1


func set_fear(value: float) -> void:
	fear_level = clampf(value, 0.0, 1.0)


func get_visibility_bonus() -> float:
	var bonus := 0.0
	if flashlight_on:
		bonus += 0.18
	if is_hiding:
		bonus -= 0.45
	return bonus


func is_flashlight_affecting_point(point: Vector2) -> bool:
	if not flashlight_on or battery <= 0.0:
		return false

	var to_point := point - global_position
	if to_point.length() > 230.0:
		return false

	var forward := Vector2.RIGHT.rotated(rotation)
	var angle := abs(forward.angle_to(to_point.normalized()))
	return angle <= deg_to_rad(22.0)


func _get_input_vector() -> Vector2:
	var input_vector := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	return input_vector.normalized()


func _enter_hiding() -> void:
	if nearby_hiding_spot == null:
		return
	is_hiding = true
	global_position = nearby_hiding_spot.global_position
	hide_toggled.emit(true, nearby_hiding_spot)


func _exit_hiding() -> void:
	is_hiding = false
	hide_toggled.emit(false, nearby_hiding_spot)


func _update_flashlight_visuals() -> void:
	flashlight_cone.visible = flashlight_on and battery > 0.0
	if flashlight_cone.visible:
		flashlight_cone.polygon = _flashlight_points
	else:
		flashlight_cone.polygon = PackedVector2Array()


func _update_personal_light() -> void:
	personal_light.enabled = true
	personal_light.energy = 1.15 + (0.85 if flashlight_on else 0.0)
	personal_light.color = Color(1.0, 0.94, 0.82)
	if personal_light.texture == null:
		personal_light.texture = _make_light_texture()


func _make_light_texture() -> Texture2D:
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in range(128):
		for x in range(128):
			var uv := Vector2(x - 64.0, y - 64.0) / 64.0
			var alpha := clampf(1.0 - uv.length(), 0.0, 1.0)
			alpha *= alpha
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(image)


func _on_interaction_area_entered(area: Area2D) -> void:
	if area.has_method("is_hiding_spot") and area.is_hiding_spot():
		nearby_hiding_spot = area


func _on_interaction_area_exited(area: Area2D) -> void:
	if nearby_hiding_spot == area:
		nearby_hiding_spot = null
