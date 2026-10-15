extends Node2D

signal health_changed(current: int, maximum: int)
signal died

@export var max_health := 100
@export var attack_range := 330.0
@export var fire_range := 330.0
@export var water_range := 310.0
@export var earth_range := 290.0
@export var air_range := 350.0
@export var fire_damage := 28
@export var fire_cooldown := 1.8
@export var air_damage := 12
@export var air_cooldown := 0.65
@export var water_damage := 18
@export var water_cooldown := 1.15
@export var earth_damage := 34
@export var earth_cooldown := 2.4

var health := 100
var selected_element := "Fogo"
var fire_timer := 0.0
var air_timer := 0.0
var water_timer := 0.0
var earth_timer := 0.0
var damage_bonus := false

func _ready() -> void:
	health = max_health
	queue_redraw()

func _process(delta: float) -> void:
	fire_timer = maxf(0.0, fire_timer - delta)
	air_timer = maxf(0.0, air_timer - delta)
	water_timer = maxf(0.0, water_timer - delta)
	earth_timer = maxf(0.0, earth_timer - delta)

func select_element(element: String) -> void:
	if element == "Fogo" or element == "Agua" or element == "Terra" or element == "Ar":
		selected_element = element
		queue_redraw()

func is_attack_ready() -> bool:
	return get_cooldown_remaining(selected_element) <= 0.0

func get_attack_damage() -> int:
	var damage := fire_damage
	match selected_element:
		"Agua": damage = water_damage
		"Terra": damage = earth_damage
		"Ar": damage = air_damage
	return damage * 2 if damage_bonus else damage

func get_attack_range() -> float:
	match selected_element:
		"Agua": return water_range
		"Terra": return earth_range
		"Ar": return air_range
	return fire_range

func register_attack() -> void:
	match selected_element:
		"Fogo": fire_timer = fire_cooldown
		"Agua": water_timer = water_cooldown
		"Terra": earth_timer = earth_cooldown
		"Ar": air_timer = air_cooldown

func get_cooldown_remaining(element: String) -> float:
	match element:
		"Agua": return water_timer
		"Terra": return earth_timer
		"Ar": return air_timer
	return fire_timer

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
	water_timer = 0.0
	earth_timer = 0.0
	damage_bonus = false
	health_changed.emit(health, max_health)
	queue_redraw()

