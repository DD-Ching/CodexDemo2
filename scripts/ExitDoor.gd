extends Area2D

signal exit_reached

var unlocked: bool = false

@onready var visual: Polygon2D = $Visual

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_refresh_visual()


func set_unlocked(value: bool) -> void:
	unlocked = value
	_refresh_visual()


func _refresh_visual() -> void:
	visual.color = Color(0.24, 0.75, 0.4, 1) if unlocked else Color(0.42, 0.14, 0.16, 1)


func _on_body_entered(body: Node) -> void:
	if unlocked and body.has_method("add_key"):
		exit_reached.emit()
