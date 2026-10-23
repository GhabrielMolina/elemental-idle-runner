extends Node2D

signal hit_enemy(enemy: Node2D, damage: int)

const AIR_TEXTURE := preload("res://assets/projectiles/air.svg")

var damage := 1
var max_x := 960.0
var speed := 300.0
var hit_ids: Array[int] = []
var sprite: Sprite2D

func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = AIR_TEXTURE
	sprite.position = Vector2(0, -34)
	sprite.scale = Vector2(1.7, 1.7)
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.85)
	add_child(sprite)

func setup(new_damage: int, new_max_x: float) -> void:
	damage = new_damage
	max_x = minf(new_max_x, 980.0)

func _process(delta: float) -> void:
	position.x += speed * delta
	sprite.rotation += 14.0 * delta
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.already_defeated or hit_ids.has(enemy.get_instance_id()):
			continue
		if absf(enemy.global_position.x - global_position.x) < 26.0:
			hit_ids.append(enemy.get_instance_id())
			hit_enemy.emit(enemy, damage)
	if position.x >= max_x:
		queue_free()
