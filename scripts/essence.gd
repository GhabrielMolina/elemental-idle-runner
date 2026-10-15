extends Node2D

@export var speed := 42.0

func _process(delta: float) -> void:
	position.x -= speed * delta
	queue_redraw()

