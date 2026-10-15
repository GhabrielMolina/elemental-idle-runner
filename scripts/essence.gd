extends Node2D

@export var speed := 42.0

func _process(delta: float) -> void:
	position.x -= speed * delta
	queue_redraw()

func _draw() -> void:
	var points := PackedVector2Array([Vector2(0, -13), Vector2(10, 0), Vector2(0, 13), Vector2(-10, 0)])
	draw_colored_polygon(points, Color("#f3c969"))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color("#fff3c4"), 2.0)