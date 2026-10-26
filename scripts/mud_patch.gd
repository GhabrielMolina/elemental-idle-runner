extends Node2D

const FADE_TIME := 0.5

var remaining := 3.0
var radius := 70.0
var slow_factor := 0.5

func setup(duration: float, new_radius: float, new_slow_factor: float) -> void:
	remaining = duration
	radius = new_radius
	slow_factor = new_slow_factor
	queue_redraw()

func _process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0.0:
		queue_free()
		return
	modulate.a = clampf(remaining / FADE_TIME, 0.0, 1.0)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.already_defeated and absf(enemy.global_position.x - global_position.x) <= radius:
			enemy.apply_slow(slow_factor, 0.2, "lama")

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, radius, Color("#5a3d24", 0.8))
	draw_circle(Vector2(-radius * 0.35, -10.0), radius * 0.3, Color("#7a5534", 0.85))
	draw_circle(Vector2(radius * 0.4, 8.0), radius * 0.22, Color("#7a5534", 0.85))
