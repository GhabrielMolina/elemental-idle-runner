extends Node2D

signal defeated

@export var max_health := 45
@export var speed := 48.0
@export var contact_damage := 12

var health := 45
var already_defeated := false

func _ready() -> void:
	health = max_health
	queue_redraw()

func _process(delta: float) -> void:
	position.x -= speed * delta

func receive_damage(amount: int, push_distance := 0.0) -> void:
	if already_defeated:
		return
	health = maxi(0, health - amount)
	position.x += push_distance
	queue_redraw()
	if health == 0:
		already_defeated = true
		defeated.emit()
		queue_free()

func _draw() -> void:
	draw_rect(Rect2(-20, -42, 40, 42), Color("#8f4d78"))
	draw_rect(Rect2(-20, -42, 40, 42), Color("#f4f0e6"), false, 2.0)
	draw_circle(Vector2(-8, -26), 4.0, Color("#f3c969"))
	draw_circle(Vector2(8, -26), 4.0, Color("#f3c969"))