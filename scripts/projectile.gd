extends Node2D

var target: Node2D
var damage := 1
var element := "Fogo"
var push_distance := 0.0
var speed := 520.0

func setup(new_target: Node2D, new_damage: int, new_element: String) -> void:
	target = new_target
	damage = new_damage
	element = new_element
	push_distance = 70.0 if element == "Ar" else 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	var direction := global_position.direction_to(target.global_position)
	global_position += direction * speed * delta
	if global_position.distance_to(target.global_position) < 18.0:
		target.receive_damage(damage, push_distance)
		queue_free()

func _draw() -> void:
	var color := Color("#f04f3e") if element == "Fogo" else Color("#8ed8e8")
	draw_circle(Vector2.ZERO, 8.0, color)
	draw_circle(Vector2.ZERO, 8.0, Color("#fff3c4"), false, 2.0)