extends Area2D

signal collected

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body.has_method("add_key"):
		body.add_key()
		collected.emit()
		queue_free()
