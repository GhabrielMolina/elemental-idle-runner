extends Node2D

signal impacted(projectile: Node2D)

const FIRE_TEXTURE := preload("res://assets/projectiles/fire.svg")
const WATER_TEXTURE := preload("res://assets/projectiles/water.svg")
const EARTH_TEXTURE := preload("res://assets/projectiles/earth.svg")
const AIR_TEXTURE := preload("res://assets/projectiles/air.svg")

var target: Node2D
var damage := 1
var element := "Fogo"
# Somente o impacto principal dispara explosao, onda, lama, tremor e ventania.
var is_primary := true
var bounces_left := 0
var chain_hit_ids: Array[int] = []
var speed := 520.0
var sprite: Sprite2D

func _ready() -> void:
	ensure_sprite()

func ensure_sprite() -> void:
	if sprite != null:
		return
	sprite = Sprite2D.new()
	add_child(sprite)

func setup(new_target: Node2D, new_damage: int, new_element: String, primary := true) -> void:
	target = new_target
	damage = new_damage
	element = new_element
	is_primary = primary
	var textures := {"Fogo": FIRE_TEXTURE, "Agua": WATER_TEXTURE, "Terra": EARTH_TEXTURE, "Ar": AIR_TEXTURE}
	ensure_sprite()
	sprite.texture = textures.get(element, FIRE_TEXTURE)
	if not is_primary:
		sprite.scale = Vector2(0.75, 0.75)

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	var direction := global_position.direction_to(target.global_position)
	global_position += direction * speed * delta
	if global_position.distance_to(target.global_position) < 18.0:
		impacted.emit(self)
		queue_free()
