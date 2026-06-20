extends CanvasLayer

signal restart_requested

@onready var keys_label: Label = $HUD/TopLeft/KeysLabel
@onready var ghost_state_label: Label = $HUD/TopLeft/GhostStateLabel
@onready var warning_label: Label = $HUD/TopLeft/WarningLabel
@onready var fear_label: Label = $HUD/TopLeft/FearLabel
@onready var stamina_bar: ProgressBar = $HUD/TopLeft/StaminaBar
@onready var battery_bar: ProgressBar = $HUD/TopLeft/BatteryBar
@onready var center_message: Label = $HUD/CenterMessage
@onready var heartbeat_overlay: ColorRect = $HUD/HeartbeatOverlay
@onready var flicker_overlay: ColorRect = $HUD/FlickerOverlay
@onready var silhouette: ColorRect = $HUD/Silhouette
@onready var end_screen: Panel = $HUD/EndScreen
@onready var end_title: Label = $HUD/EndScreen/EndVBox/EndTitle
@onready var end_body: Label = $HUD/EndScreen/EndVBox/EndBody
@onready var restart_button: Button = $HUD/EndScreen/EndVBox/RestartButton

var _message_timer: float = 0.0

func _ready() -> void:
	restart_button.pressed.connect(func() -> void: restart_requested.emit())


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		center_message.modulate.a = minf(_message_timer, 1.0)
	else:
		center_message.modulate.a = maxf(center_message.modulate.a - delta, 0.0)


func set_key_count(current: int, total: int) -> void:
	keys_label.text = "Keys: %d / %d" % [current, total]


func set_stamina(value: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = value


func set_battery(value: float, maximum: float) -> void:
	battery_bar.max_value = maximum
	battery_bar.value = value


func set_ghost_state(state_name: String) -> void:
	ghost_state_label.text = "Ghost: %s" % state_name


func set_warning(text: String) -> void:
	warning_label.text = text


func set_fear(value: float) -> void:
	var percent := int(round(value * 100.0))
	fear_label.text = "Fear: %d%%" % percent
	heartbeat_overlay.color.a = clampf(value * 0.22, 0.0, 0.22)


func flash_flicker(strength: float = 0.7) -> void:
	flicker_overlay.color.a = strength
	var tween := create_tween()
	tween.tween_property(flicker_overlay, "color:a", 0.0, 0.35)


func flash_silhouette() -> void:
	silhouette.color.a = 0.75
	var tween := create_tween()
	tween.tween_property(silhouette, "color:a", 0.0, 0.45)


func show_message(text: String, duration: float = 2.0) -> void:
	center_message.text = text
	center_message.modulate.a = 1.0
	_message_timer = duration


func show_end_screen(victory: bool) -> void:
	end_screen.visible = true
	if victory:
		end_title.text = "You Escaped"
		end_body.text = "All three keys collected. The exit is open."
	else:
		end_title.text = "Game Over"
		end_body.text = "The ghost caught you before you could escape."
