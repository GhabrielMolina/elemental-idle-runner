extends Node2D

signal defeated(killed_by_attack: bool, killer_element: String)

const STATUS_TICK_INTERVAL := 0.5

@export var max_health := 45
@export var speed := 48.0
@export var contact_damage := 12
@export var element := "Fogo"

var health := 45
var already_defeated := false
var counts_for_wave := false
var base_speed := 48.0
# Lentidoes por origem ("golpe", "lama"): x = fator de velocidade, y = tempo restante.
var slow_effects: Dictionary[String, Vector2] = {}
var stun_timer := 0.0
var frozen_timer := 0.0
var burn_timer := 0.0
var burn_tick_timer := 0.0
var burn_tick_damage := 0
var drown_timer := 0.0
var drown_tick_timer := 0.0
var drown_tick_damage := 0
var drown_execute_ratio := 0.0
var last_damage_element := ""
# Definido pelo Main: devolve o multiplicador de dano recebido (Ressonancia, Rachadura).
var damage_modifier: Callable
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
	for source in slow_effects.keys():
		var effect: Vector2 = slow_effects[source]
		effect.y -= delta
		if effect.y <= 0.0:
			slow_effects.erase(source)
		else:
			slow_effects[source] = effect
	stun_timer = maxf(0.0, stun_timer - delta)
	frozen_timer = maxf(0.0, frozen_timer - delta)
	process_damage_over_time(delta)
	queue_redraw()
	if already_defeated or stun_timer > 0.0:
		return
	position.x -= base_speed * get_speed_multiplier() * delta

func process_damage_over_time(delta: float) -> void:
	if burn_timer > 0.0:
		burn_timer = maxf(0.0, burn_timer - delta)
		burn_tick_timer -= delta
		if burn_tick_timer <= 0.0:
			burn_tick_timer += STATUS_TICK_INTERVAL
			receive_damage(burn_tick_damage, "Fogo")
	if drown_timer > 0.0 and not already_defeated:
		drown_timer = maxf(0.0, drown_timer - delta)
		drown_tick_timer -= delta
		if drown_tick_timer <= 0.0:
			drown_tick_timer += STATUS_TICK_INTERVAL
			receive_damage(drown_tick_damage, "Agua")

# Retorna o dano final aplicado (depois de Ressonancia, Rachadura e vantagem elemental).
func receive_damage(amount: int, source_element := "", push_distance := 0.0) -> int:
	if already_defeated:
		return 0
	var final_amount := amount
	if damage_modifier.is_valid():
		final_amount = roundi(amount * float(damage_modifier.call(self, source_element)))
	if source_element != "":
		last_damage_element = source_element
	health = maxi(0, health - final_amount)
	play_damage_feedback()
	if push_distance != 0.0:
		position.x = minf(position.x + push_distance, 920.0)
	queue_redraw()
	if health == 0:
		die(true)
	else:
		check_drown_execution()
	return final_amount

func apply_burn(tick_damage: int, duration: float) -> void:
	if already_defeated or tick_damage <= 0 or duration <= 0.0:
		return
	if burn_timer <= 0.0:
		burn_tick_timer = STATUS_TICK_INTERVAL
		burn_tick_damage = tick_damage
	else:
		burn_tick_damage = maxi(burn_tick_damage, tick_damage)
	burn_timer = maxf(burn_timer, duration)

func apply_drown(tick_damage: int, duration: float, execute_ratio: float) -> void:
	if already_defeated or duration <= 0.0:
		return
	if drown_timer <= 0.0:
		drown_tick_timer = STATUS_TICK_INTERVAL
		drown_tick_damage = tick_damage
		drown_execute_ratio = execute_ratio
	else:
		drown_tick_damage = maxi(drown_tick_damage, tick_damage)
		drown_execute_ratio = maxf(drown_execute_ratio, execute_ratio)
	drown_timer = maxf(drown_timer, duration)
	check_drown_execution()

func check_drown_execution() -> void:
	if already_defeated or drown_timer <= 0.0 or health <= 0:
		return
	if float(health) <= max_health * drown_execute_ratio:
		health = 0
		last_damage_element = "Agua"
		die(true)

func apply_slow(factor: float, duration: float, source := "golpe") -> void:
	if already_defeated or duration <= 0.0:
		return
	var current: Vector2 = slow_effects.get(source, Vector2(1.0, 0.0))
	slow_effects[source] = Vector2(minf(current.x, factor), maxf(current.y, duration))

func apply_stun(duration: float, frozen := false) -> void:
	if already_defeated or duration <= 0.0:
		return
	stun_timer = maxf(stun_timer, duration)
	if frozen:
		frozen_timer = maxf(frozen_timer, duration)

func get_speed_multiplier() -> float:
	var multiplier := 1.0
	for effect in slow_effects.values():
		multiplier = minf(multiplier, effect.x)
	return multiplier

func is_slowed() -> bool:
	return not slow_effects.is_empty()

func is_stunned() -> bool:
	return stun_timer > 0.0

func has_any_status() -> bool:
	return burn_timer > 0.0 or drown_timer > 0.0 or is_slowed() or is_stunned()

func has_spreadable_status() -> bool:
	return burn_timer > 0.0 or drown_timer > 0.0 or is_slowed()

# Ventania: repassa queimadura, afogamento e lentidao para outro inimigo.
func copy_statuses_to(other: Node2D) -> void:
	if burn_timer > 0.0:
		other.apply_burn(burn_tick_damage, burn_timer)
	if drown_timer > 0.0:
		other.apply_drown(drown_tick_damage, drown_timer, drown_execute_ratio)
	for source in slow_effects:
		other.apply_slow(slow_effects[source].x, slow_effects[source].y, source)

func clear_statuses() -> void:
	slow_effects.clear()
	stun_timer = 0.0
	frozen_timer = 0.0
	burn_timer = 0.0
	drown_timer = 0.0

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

func die(killed_by_attack := false) -> void:
	if already_defeated:
		return
	already_defeated = true
	set_process(false)
	clear_statuses()
	queue_redraw()
	if damage_tween and damage_tween.is_valid():
		damage_tween.kill()
	defeated.emit(killed_by_attack, last_damage_element if killed_by_attack else "")
	death_tween = create_tween()
	death_tween.set_parallel()
	death_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	death_tween.tween_property(sprite, "scale", base_sprite_scale * 0.72, 0.28)
	death_tween.tween_property(sprite, "modulate:a", 0.0, 0.28)
	death_tween.set_parallel(false)
	death_tween.tween_callback(queue_free)

func _draw() -> void:
	if frozen_timer > 0.0:
		draw_circle(Vector2(0, -36), 36.0, Color(0.65, 0.92, 1.0, 0.4))
	var colors: Array[Color] = []
	if burn_timer > 0.0:
		colors.append(Color("#ff8a3d"))
	if drown_timer > 0.0:
		colors.append(Color("#2f7fd0"))
	if is_slowed():
		colors.append(Color("#a6dfe8"))
	if stun_timer > 0.0:
		colors.append(Color("#f3c969"))
	var start_x := -(colors.size() - 1) * 7.0
	for index in colors.size():
		draw_circle(Vector2(start_x + index * 14.0, -82.0), 5.0, colors[index])
		draw_arc(Vector2(start_x + index * 14.0, -82.0), 5.0, 0.0, TAU, 16, Color("#162d42"), 1.5)
