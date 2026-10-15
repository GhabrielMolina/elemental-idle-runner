extends Node2D

const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/Projectile.tscn")
const ESSENCE_SCENE := preload("res://scenes/Essence.tscn")
const DEBUG_SCENE := preload("res://scenes/DebugPanel.tscn")

@onready var player: Node2D = $Player

@export var min_spawn_interval: float = 1.8
@export var max_spawn_interval: float = 2.6

var enemy_timer := 0.0
var spawn_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var essence_timer := 0.0
var belt_offset := 0.0
var bonus_timer := 0.0
var defeated_count := 0
var essence_count := 0
var game_over := false
var speed_index := 0
var speeds := [1.0, 2.0, 3.0]

var health_bar: ProgressBar
var health_label: Label
var stats_label: Label
var element_label: Label
var cooldown_label: Label
var bonus_label: Label
var command_label: Label
var defeat_overlay: PanelContainer
var defeat_label: Label
var debug_panel: PanelContainer
var element_buttons: Array[Button] = []

func _ready() -> void:
	spawn_rng.randomize()
	build_hud()
	debug_panel = DEBUG_SCENE.instantiate()
	add_child(debug_panel)
	debug_panel.position = Vector2(700, 250)
	debug_panel.setup(self)
	player.health_changed.connect(update_health)
	player.died.connect(handle_defeat)
	update_hud()
	update_debug()
	queue_redraw()

func _process(delta: float) -> void:
	if game_over:
		return
	belt_offset = fmod(belt_offset + 90.0 * delta, 80.0)
	enemy_timer -= delta
	essence_timer -= delta
	bonus_timer = maxf(0.0, bonus_timer - delta)
	if bonus_timer == 0.0 and player.damage_bonus:
		player.damage_bonus = false
		update_hud()
	if enemy_timer <= 0.0:
		spawn_enemy()
		enemy_timer = get_next_spawn_interval()
	if essence_timer <= 0.0:
		spawn_essence()
		essence_timer = 6.0
	move_entities_and_resolve_contacts()
	automatic_attack()
	update_hud()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_1 and not game_over:
		select_element("Fogo")
	elif event.keycode == KEY_2 and not game_over:
		select_element("Agua")
	elif event.keycode == KEY_3 and not game_over:
		select_element("Terra")
	elif event.keycode == KEY_4 and not game_over:
		select_element("Ar")
	elif event.keycode == KEY_E and not game_over:
		collect_nearby_essence()
	elif event.keycode == KEY_Q and not game_over:
		activate_bonus()
	update_hud()

func spawn_enemy() -> void:
	if game_over:
		return
	var enemy := ENEMY_SCENE.instantiate()
	enemy.position = Vector2(1000, 430)
	add_child(enemy)
	enemy.add_to_group("runtime_entity")
	enemy.add_to_group("enemies")
	enemy.defeated.connect(_on_enemy_defeated)

func get_next_spawn_interval() -> float:
	var safe_minimum: float = maxf(min_spawn_interval, 0.01)
	var safe_maximum: float = maxf(max_spawn_interval, safe_minimum)
	return spawn_rng.randf_range(safe_minimum, safe_maximum)

func debug_spawn_enemy() -> void:
	if not game_over:
		spawn_enemy()

func select_element(element: String) -> void:
	if game_over:
		return
	player.select_element(element)
	update_hud()

func spawn_essence() -> void:
	if game_over:
		return
	var essence := ESSENCE_SCENE.instantiate()
	essence.position = Vector2(1000, 370)
	add_child(essence)
	essence.add_to_group("runtime_entity")

func automatic_attack() -> void:
	if game_over or not player.is_attack_ready():
		return
	var target := find_closest_enemy()
	if target == null or player.global_position.distance_to(target.global_position) > player.get_attack_range():
		return
	var projectile := PROJECTILE_SCENE.instantiate()
	projectile.global_position = player.global_position + Vector2(22, -32)
	projectile.setup(target, player.get_attack_damage(), player.selected_element)
	add_child(projectile)
	projectile.add_to_group("runtime_entity")
	player.register_attack()

func find_closest_enemy() -> Node2D:
	var closest: Node2D
	var closest_distance := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			var distance := player.global_position.distance_to(enemy.global_position)
			if distance < closest_distance:
				closest = enemy
				closest_distance = distance
	return closest

func move_entities_and_resolve_contacts() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.already_defeated and enemy.global_position.x <= player.global_position.x + 24.0:
			player.take_damage(enemy.contact_damage)
			enemy.queue_free()
	for essence in get_tree().get_nodes_in_group("runtime_entity"):
		if not is_instance_valid(essence) or essence.is_in_group("enemies"):
			continue
		if essence.global_position.x < player.global_position.x - 40.0:
			essence.queue_free()

func collect_nearby_essence() -> void:
	var closest: Node2D
	var closest_distance := 70.0
	for essence in get_tree().get_nodes_in_group("runtime_entity"):
		if not is_instance_valid(essence) or essence.is_in_group("enemies"):
			continue
		var distance := player.global_position.distance_to(essence.global_position)
		if distance <= closest_distance:
			closest = essence
			closest_distance = distance
	if closest != null:
		closest.queue_free()
		essence_count += 1
		update_hud()

func activate_bonus() -> void:
	if essence_count < 3 or player.damage_bonus:
		return
	essence_count -= 3
	player.damage_bonus = true
	bonus_timer = 5.0
	update_hud()

func _on_enemy_defeated() -> void:
	defeated_count += 1
	update_hud()

func handle_defeat() -> void:
	game_over = true
	defeat_overlay.visible = true
	update_hud()
	update_debug()

func restart_game() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	speed_index = 0
	for entity in get_tree().get_nodes_in_group("runtime_entity"):
		if is_instance_valid(entity):
			entity.queue_free()
	player.reset()
	defeated_count = 0
	essence_count = 0
	bonus_timer = 0.0
	enemy_timer = get_next_spawn_interval()
	essence_timer = 3.0
	game_over = false
	defeat_overlay.visible = false
	update_hud()
	update_debug()
	queue_redraw()

func toggle_pause() -> void:
	if game_over:
		return
	get_tree().paused = not get_tree().paused
	update_debug()

func cycle_speed() -> void:
	speed_index = (speed_index + 1) % speeds.size()
	Engine.time_scale = speeds[speed_index]
	update_debug()

func build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)
	var top_bar := PanelContainer.new()
	top_bar.position = Vector2(18, 16)
	top_bar.size = Vector2(550, 145)
	canvas.add_child(top_bar)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	top_bar.add_child(column)
	health_label = Label.new()
	health_label.text = "Vida"
	column.add_child(health_label)
	health_bar = ProgressBar.new()
	health_bar.max_value = player.max_health
	health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_bar.show_percentage = false
	column.add_child(health_bar)
	stats_label = Label.new()
	column.add_child(stats_label)
	element_label = Label.new()
	column.add_child(element_label)
	cooldown_label = Label.new()
	column.add_child(cooldown_label)
	bonus_label = Label.new()
	column.add_child(bonus_label)
	command_label = Label.new()
	command_label.add_theme_color_override("font_color", Color("#a7a39a"))
	column.add_child(command_label)
	element_buttons.append(create_element_button(canvas, "1  Fogo", "Fogo", Vector2(590, 24)))
	element_buttons.append(create_element_button(canvas, "2  Agua", "Agua", Vector2(700, 24)))
	element_buttons.append(create_element_button(canvas, "3  Terra", "Terra", Vector2(590, 66)))
	element_buttons.append(create_element_button(canvas, "4  Ar", "Ar", Vector2(700, 66)))
	defeat_overlay = PanelContainer.new()
	defeat_overlay.position = Vector2(330, 205)
	defeat_overlay.size = Vector2(300, 130)
	canvas.add_child(defeat_overlay)
	var defeat_column := VBoxContainer.new()
	defeat_overlay.add_child(defeat_column)
	defeat_label = Label.new()
	defeat_label.text = "DERROTA\nO Avatar caiu."
	defeat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	defeat_column.add_child(defeat_label)
	var restart_button := Button.new()
	restart_button.text = "Reiniciar partida"
	restart_button.pressed.connect(restart_game)
	defeat_column.add_child(restart_button)
	defeat_overlay.visible = false

func create_element_button(canvas: CanvasLayer, label: String, element: String, button_position: Vector2) -> Button:
	var button := Button.new()
	button.text = label
	button.position = button_position
	button.size = Vector2(105, 36)
	button.pressed.connect(select_element.bind(element))
	canvas.add_child(button)
	return button

func update_health(current: int, maximum: int) -> void:
	if is_instance_valid(health_bar):
		health_bar.value = current
		health_label.text = "Vida: %d / %d" % [current, maximum]

func update_hud() -> void:
	if not is_instance_valid(health_bar):
		return
	update_health(player.health, player.max_health)
	stats_label.text = "Inimigos derrotados: %d   Essencias: %d / 3" % [defeated_count, essence_count]
	element_label.text = "Elemento ativo: %s" % player.selected_element
	var cooldown: float = player.get_cooldown_remaining(player.selected_element)
	cooldown_label.text = "Recarga: Pronto" if cooldown <= 0.0 else "Recarga: %.1f s" % cooldown
	bonus_label.text = "Bonus de dano: ATIVO (%.1fs)" % bonus_timer if player.damage_bonus else "Bonus de dano: inativo"
	command_label.text = "1-4 elemento   E coletar   Q consumir 3   F1 debug"
	var elements := ["Fogo", "Agua", "Terra", "Ar"]
	var labels := ["1  Fogo", "2  Agua", "3  Terra", "4  Ar"]
	for index in element_buttons.size():
		element_buttons[index].text = ("* " if elements[index] == player.selected_element else "") + labels[index]

func update_debug() -> void:
	if is_instance_valid(debug_panel):
		var state := "derrota" if game_over else ("pausado" if get_tree().paused else "em andamento")
		debug_panel.update_display(state, speeds[speed_index], get_tree().paused)

func _draw() -> void:
	for x in range(-80, 1040, 80):
		var belt_x := x - belt_offset
		draw_line(Vector2(belt_x, 458), Vector2(belt_x + 42, 500), Color("#53746b"), 5.0)
		draw_line(Vector2(belt_x + 42, 500), Vector2(belt_x + 80, 458), Color("#53746b"), 5.0)
	draw_line(Vector2(0, 456), Vector2(960, 456), Color("#f3c969"), 3.0)