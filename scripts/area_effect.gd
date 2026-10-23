extends Node2D

# Anel visual que se expande e some (explosao, onda, tremor, ventania).

const DURATION := 0.3

var radius := 60.0
var color := Color.WHITE
var elapsed := 0.0

func setup(new_radius: float, new_color: Color) -> void:
	radius = new_radius
	color = new_color

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= DURATION:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var progress := elapsed / DURATION
	var ring_color := color
	ring_color.a = 1.0 - progress
	draw_arc(Vector2.ZERO, radius * lerpf(0.3, 1.0, progress), 0.0, TAU, 40, ring_color, 4.0)
