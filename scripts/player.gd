extends Node2D

signal health_changed(current: int, maximum: int)
signal died

@export var max_health := 100
@export var attack_range := 330.0
@export var fire_damage := 28
@export var fire_cooldown := 1.8
@export var air_damage := 12
@export var air_cooldown := 0.65

var health := 100
var selected_element := "Fogo"
var fire_timer := 0.0
var air_timer := 0.0
var damage_bonus := false

func _ready() -> void:
	health = max_health
	queue_redraw()

func _process(delta: float) -> void:
	fire_timer = maxf(0.0, fire_timer - delta)
	air_timer = maxf(0.0, air_timer - delta)

func select_element(element: String) -> void:
	if element == "Fogo" or element == "Ar":
		selected_element = element
		queue_redraw()

func is_attack_ready() -> bool:
	return fire_timer <= 0.0 if selected_element == "Fogo" else air_timer <= 0.0

func get_attack_damage() -> int:
	var damage := fire_damage if selected_element == "Fogo" else air_damage
	return damage * 2 if damage_bonus else damage

func register_attack() -> void:
	if selected_element == "Fogo":
		fire_timer = fire_cooldown
	else:
		air_timer = air_cooldown

func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)
	queue_redraw()
	if health == 0:
		died.emit()

func reset() -> void:
	health = max_health
	selected_element = "Fogo"
	fire_timer = 0.0
	air_timer = 0.0
	damage_bonus = false
	health_changed.emit(health, max_health)
	queue_redraw()

func _draw() -> void:
	var color := Color("#e85d4a") if selected_element == "Fogo" else Color("#56b6d9")
	draw_rect(Rect2(-22, -48, 44, 48), color)
	draw_rect(Rect2(-22, -48, 44, 48), Color("#f4f0e6"), false, 3.0)
	draw_circle(Vector2(-9, -30), 4.0, Color("#f4f0e6"))
	draw_circle(Vector2(9, -30), 4.0, Color("#f4f0e6"))