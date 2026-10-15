extends Node2D

signal defeated

@export var max_health := 45
@export var speed := 48.0
@export var contact_damage := 12

var health := 45
var already_defeated := false
var base_speed := 48.0
var slow_timer := 0.0
var stun_timer := 0.0

func _ready() -> void:
	health = max_health
	base_speed = speed
	queue_redraw()

func _process(delta: float) -> void:
	slow_timer = maxf(0.0, slow_timer - delta)
	stun_timer = maxf(0.0, stun_timer - delta)
	queue_redraw()
	if stun_timer > 0.0:
		return
	var movement_speed := base_speed * 0.45 if slow_timer > 0.0 else base_speed
	position.x -= movement_speed * delta

func receive_damage(amount: int, push_distance := 0.0, effect := "") -> void:
	if already_defeated:
		return
	health = maxi(0, health - amount)
	if push_distance != 0.0:
		position.x = minf(position.x + push_distance, 920.0)
	if effect == "Agua":
		slow_timer = 2.0
	elif effect == "Terra":
		stun_timer = 1.0
	queue_redraw()
	if health == 0:
		already_defeated = true
		defeated.emit()
		queue_free()

