extends Node2D

signal defeated

@export var max_health := 45
@export var speed := 48.0
@export var contact_damage := 12
@export var element := "Fogo"

var health := 45
var already_defeated := false
var counts_for_wave := false
var base_speed := 48.0
var slow_timer := 0.0
var stun_timer := 0.0
@onready var sprite: Sprite2D = $Sprite
var base_sprite_scale := Vector2.ONE
var damage_tween: Tween
var death_tween: Tween

func _ready() -> void:
	health = max_health
	base_speed = speed
	base_sprite_scale = sprite.scale
	apply_element_color()
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
	play_damage_feedback()
	if push_distance != 0.0:
		position.x = minf(position.x + push_distance, 920.0)
	if effect == "Agua":
		slow_timer = 2.0
	elif effect == "Terra":
		stun_timer = 1.0
	queue_redraw()
	if health == 0:
		die()

func apply_element_color() -> void:
	var color := Color("#ef654f")
	match element:
		"Agua": color = Color("#4bbbd8")
		"Terra": color = Color("#b07a4b")
		"Ar": color = Color("#a6dfe8")
	sprite.self_modulate = color

func play_damage_feedback() -> void:
	if damage_tween and damage_tween.is_valid():
		damage_tween.kill()
	sprite.scale = base_sprite_scale
	sprite.modulate = Color("#fff1c2")
	damage_tween = create_tween()
	damage_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	damage_tween.tween_property(sprite, "scale", base_sprite_scale * 1.06, 0.05)
	damage_tween.set_ease(Tween.EASE_IN)
	damage_tween.tween_property(sprite, "scale", base_sprite_scale, 0.1)
	damage_tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.12)

func die() -> void:
	if already_defeated:
		return
	already_defeated = true
	set_process(false)
	if damage_tween and damage_tween.is_valid():
		damage_tween.kill()
	defeated.emit()
	death_tween = create_tween()
	death_tween.set_parallel()
	death_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	death_tween.tween_property(sprite, "scale", base_sprite_scale * 0.72, 0.28)
	death_tween.tween_property(sprite, "modulate:a", 0.0, 0.28)
	death_tween.set_parallel(false)
	death_tween.tween_callback(queue_free)

