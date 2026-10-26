extends Node2D

const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/Projectile.tscn")
const ESSENCE_SCENE := preload("res://scenes/Essence.tscn")
const DEBUG_SCENE := preload("res://scenes/DebugPanel.tscn")
const SHOP_SCENE := preload("res://scenes/ShopPanel.tscn")
const TORNADO_SCENE := preload("res://scenes/Tornado.tscn")
const MUD_PATCH_SCENE := preload("res://scenes/MudPatch.tscn")
const AREA_EFFECT := preload("res://scripts/area_effect.gd")

@onready var player: Node2D = $Player

@export var min_spawn_interval: float = 1.8
@export var max_spawn_interval: float = 2.6
@export var belt_speed: float = 56.0
@export var wave_enemy_counts: Array[int] = [5, 7, 8, 10]
@export var wave_element_options: Array[String] = ["Agua", "Agua,Terra", "Fogo", "Fogo,Ar"]
@export var min_xp_per_kill := 13
@export var max_xp_per_kill := 20

var enemy_timer := 0.0
var spawn_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var essence_timer := 0.0
var belt_offset := 0.0
var bonus_timer := 0.0
var defeated_count := 0
var essence_count := 0
var game_over := false
var final_victory := false
var awaiting_next_wave := false
var current_wave := 0
var wave_spawned_count := 0
var wave_defeated_count := 0
var speed_index := 0
var speeds := [1.0, 2.0, 3.0]
var air_attack_counter := 0
var default_enemy_health := 45
# Definido pelo painel de debug; 0 usa a vida padrao do Enemy.tscn.
var enemy_health_override := 0

var health_bar: ProgressBar
var health_label: Label
var level_label: Label
var xp_bar: ProgressBar
var level_up_label: Label
var level_up_tween: Tween
var element_xp_label: Label
var stats_label: Label
var wave_label: Label
var element_label: Label
var cooldown_label: Label
var bonus_label: Label
var command_label: Label
var advantage_label: Label
var defeat_overlay: PanelContainer
var defeat_label: Label
var overlay_message: Label
var overlay_stats: Label
var overlay_button: Button
var debug_panel: PanelContainer
var shop_panel: PanelContainer
var hud_layer: CanvasLayer
var element_buttons: Array[Button] = []

func _ready() -> void:
	spawn_rng.randomize()
	var enemy_probe := ENEMY_SCENE.instantiate()
	default_enemy_health = enemy_probe.max_health
	enemy_probe.free()
	build_hud()
	debug_panel = DEBUG_SCENE.instantiate()
	add_child(debug_panel)
	debug_panel.position = Vector2(700, 160)
	debug_panel.z_index = 50
	debug_panel.setup(self)
	shop_panel = SHOP_SCENE.instantiate()
	hud_layer.add_child(shop_panel)
	shop_panel.setup(self, player)
	player.health_changed.connect(update_health)
	player.died.connect(handle_defeat)
	player.leveled_up.connect(show_level_up_message)
	start_wave(0)
	update_hud()
	update_debug()
	queue_redraw()

func _process(delta: float) -> void:
	if game_over or final_victory or awaiting_next_wave:
		return
	belt_offset = fmod(belt_offset + belt_speed * delta, 80.0)
	enemy_timer -= delta
	essence_timer -= delta
	bonus_timer = maxf(0.0, bonus_timer - delta)
	if bonus_timer == 0.0 and player.damage_bonus:
		player.damage_bonus = false
		update_hud()
	if enemy_timer <= 0.0 and wave_spawned_count < get_current_wave_total():
		spawn_enemy(choose_wave_element(), true)
		wave_spawned_count += 1
		enemy_timer = get_next_spawn_interval()
	if essence_timer <= 0.0:
		spawn_essence()
		essence_timer = 6.0
	move_entities_and_resolve_contacts()
	automatic_attack()
	check_wave_completion()
	update_hud()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_1 and not game_over and not final_victory:
		select_element("Fogo")
	elif event.keycode == KEY_2 and not game_over and not final_victory:
		select_element("Agua")
	elif event.keycode == KEY_3 and not game_over and not final_victory:
		select_element("Terra")
	elif event.keycode == KEY_4 and not game_over and not final_victory:
		select_element("Ar")
	elif event.keycode == KEY_E and not game_over:
		collect_nearby_essence()
	elif event.keycode == KEY_Q and not game_over:
		activate_bonus()
	update_hud()

func spawn_enemy(enemy_element: String, is_wave_enemy: bool) -> void:
	if game_over or final_victory:
		return
	var enemy := ENEMY_SCENE.instantiate()
	enemy.position = Vector2(1000, 430)
	enemy.element = enemy_element
	enemy.counts_for_wave = is_wave_enemy
	enemy.max_health = get_enemy_max_health()
	enemy.damage_modifier = player.get_damage_taken_multiplier
	add_child(enemy)
	enemy.add_to_group("runtime_entity")
	enemy.add_to_group("enemies")
	enemy.add_to_group("wave_enemies" if is_wave_enemy else "debug_enemies")
	enemy.defeated.connect(_on_enemy_defeated.bind(enemy, is_wave_enemy))

func get_next_spawn_interval() -> float:
	var safe_minimum: float = maxf(min_spawn_interval, 0.01)
	var safe_maximum: float = maxf(max_spawn_interval, safe_minimum)
	return spawn_rng.randf_range(safe_minimum, safe_maximum)

func get_current_wave_total() -> int:
	if current_wave < 0 or current_wave >= wave_enemy_counts.size():
		return 0
	return maxi(0, wave_enemy_counts[current_wave])

func get_current_wave_elements() -> Array[String]:
	var elements: Array[String] = []
	if current_wave < 0 or current_wave >= wave_element_options.size():
		return elements
	for element_name in wave_element_options[current_wave].split(","):
		var clean_name := element_name.strip_edges()
		if clean_name != "":
			elements.append(clean_name)
	return elements

func choose_wave_element() -> String:
	var elements := get_current_wave_elements()
	if elements.is_empty():
		return "Fogo"
	return elements[spawn_rng.randi_range(0, elements.size() - 1)]

func start_wave(wave_index: int) -> void:
	if wave_index < 0 or wave_index >= wave_enemy_counts.size():
		return
	current_wave = wave_index
	wave_spawned_count = 0
	wave_defeated_count = 0
	enemy_timer = 0.0
	awaiting_next_wave = false
	final_victory = false
	defeat_overlay.visible = false
	update_hud()

func has_active_enemies(group_name: String) -> bool:
	for enemy in get_tree().get_nodes_in_group(group_name):
		if is_instance_valid(enemy) and not enemy.already_defeated:
			return true
	return false

func check_wave_completion() -> void:
	if awaiting_next_wave or wave_spawned_count < get_current_wave_total():
		return
	if wave_defeated_count < get_current_wave_total():
		return
	if has_active_enemies("wave_enemies") or has_active_enemies("debug_enemies"):
		return
	if current_wave == wave_enemy_counts.size() - 1:
		show_final_victory()
	else:
		show_wave_complete()

func show_wave_complete() -> void:
	awaiting_next_wave = true
	defeat_overlay.visible = true
	defeat_label.text = "Wave concluida!"
	overlay_message.text = "A area foi superada."
	overlay_stats.text = "Wave %d/4  |  Inimigos derrotados: %d" % [current_wave + 1, wave_defeated_count]
	overlay_button.text = "Proxima wave"
	update_hud()

func show_final_victory() -> void:
	final_victory = true
	defeat_overlay.visible = true
	defeat_label.text = "Vitoria!"
	overlay_message.text = "Equilibrio restaurado nas quatro waves."
	overlay_stats.text = "Total de inimigos derrotados: %d\n%s mantido para a proxima partida" % [defeated_count, get_level_text()]
	overlay_button.text = "Jogar novamente"
	update_hud()

func handle_overlay_action() -> void:
	if awaiting_next_wave:
		start_wave(current_wave + 1)
	else:
		restart_game()

func debug_spawn_enemy() -> void:
	if not game_over and not final_victory and not awaiting_next_wave:
		spawn_enemy(choose_wave_element(), false)

func debug_add_xp() -> void:
	player.add_xp(100)
	update_hud()

func debug_add_element_xp() -> void:
	for element in ["Fogo", "Agua", "Terra", "Ar"]:
		player.add_element_xp(element, 100)
	update_hud()

func debug_reset_progress() -> void:
	player.reset_progress()
	air_attack_counter = 0
	update_hud()

func get_enemy_max_health() -> int:
	return enemy_health_override if enemy_health_override > 0 else default_enemy_health

# Vale para os proximos inimigos e ajusta os vivos mantendo a proporcao da vida atual.
func debug_set_enemy_health(value: float) -> void:
	enemy_health_override = maxi(1, roundi(value))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.already_defeated:
			continue
		var ratio := float(enemy.health) / float(maxi(1, enemy.max_health))
		enemy.max_health = enemy_health_override
		enemy.health = maxi(1, roundi(enemy_health_override * ratio))
		enemy.queue_redraw()

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
	essence.add_to_group("essences")

func automatic_attack() -> void:
	if game_over or not player.is_attack_ready():
		return
	var targets := get_enemies_near(player.global_position, player.get_attack_range())
	if targets.is_empty():
		return
	var element: String = player.selected_element
	var damage: int = player.get_attack_damage()
	var count: int = player.get_projectile_count()
	var bounces := roundi(player.get_upgrade_number("ar_ricochete", "bounces")) if element == "Ar" else 0
	for index in count:
		var offset := Vector2(22, -32 + (index - (count - 1) / 2.0) * 12.0)
		spawn_projectile(player.global_position + offset, targets[index % targets.size()], damage, element, true, bounces)
	if element == "Ar":
		try_launch_tornado(damage)
	player.register_attack()

func spawn_projectile(from: Vector2, target: Node2D, damage: int, element: String, is_primary: bool, bounces_left := 0, chain_hit_ids: Array[int] = []) -> void:
	var projectile := PROJECTILE_SCENE.instantiate()
	projectile.global_position = from
	projectile.setup(target, damage, element, is_primary)
	projectile.bounces_left = bounces_left
	projectile.chain_hit_ids = chain_hit_ids
	projectile.impacted.connect(_on_projectile_impacted)
	add_child(projectile)
	projectile.add_to_group("runtime_entity")

# Inimigos vivos ate o raio informado, do mais proximo ao mais distante.
func get_enemies_near(origin: Vector2, radius: float, exclude_ids: Array[int] = []) -> Array[Node2D]:
	var found: Array[Node2D] = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.already_defeated or exclude_ids.has(enemy.get_instance_id()):
			continue
		if origin.distance_to(enemy.global_position) <= radius:
			found.append(enemy)
	found.sort_custom(func(a: Node2D, b: Node2D) -> bool: return origin.distance_to(a.global_position) < origin.distance_to(b.global_position))
	return found

func _on_projectile_impacted(projectile: Node2D) -> void:
	var target: Node2D = projectile.target
	var impact_position := target.global_position
	if projectile.is_primary:
		trigger_primary_effects(target, projectile.damage, projectile.element, impact_position)
	apply_hit(target, projectile.damage, projectile.element)
	if projectile.bounces_left > 0:
		bounce_projectile(projectile, target, impact_position)

# Todo dano passa por aqui: aplica o dano e depois os efeitos de status do elemento.
# Por isso explosao, onda, tremor, ricochete e tufao tambem queimam, afogam, deixam lento etc.
func apply_hit(enemy: Node2D, damage: int, element: String) -> void:
	if not is_instance_valid(enemy) or enemy.already_defeated:
		return
	var was_slowed: bool = enemy.is_slowed()
	var push_distance: float = player.air_push_distance if element == "Ar" else 0.0
	var dealt: int = enemy.receive_damage(damage, element, push_distance)
	if player.has_element_advantage(element, enemy.element):
		spawn_floating_text(enemy.global_position + Vector2(randf_range(-16.0, 4.0), -96), "%d!" % dealt, Color("#f3c969"), 22)
	if enemy.already_defeated:
		return
	match element:
		"Fogo":
			if player.get_upgrade_level("fogo_queimadura") > 0:
				enemy.apply_burn(roundi(player.get_upgrade_number("fogo_queimadura", "tick_damage")), player.get_upgrade_number("fogo_queimadura", "duration"))
		"Agua":
			if player.get_upgrade_level("agua_afogamento") > 0:
				enemy.apply_drown(roundi(player.get_upgrade_number("agua_afogamento", "tick_damage")), player.get_upgrade_number("agua_afogamento", "duration"), player.get_upgrade_percent("agua_afogamento", "execute_pct"))
			if was_slowed and player.get_upgrade_level("agua_congelamento") > 0:
				enemy.apply_stun(player.get_upgrade_number("agua_congelamento", "duration"), true)
			enemy.apply_slow(player.water_slow_factor, player.water_slow_duration)
		"Terra":
			enemy.apply_stun(player.earth_stun_duration)

# Efeitos disparados so pelo impacto principal de um projetil (evita reacao em cadeia).
func trigger_primary_effects(target: Node2D, damage: int, element: String, at: Vector2) -> void:
	var target_ids: Array[int] = [target.get_instance_id()]
	match element:
		"Fogo":
			var radius: float = player.get_upgrade_number("fogo_explosao", "radius")
			if radius > 0.0:
				var splash_damage := roundi(damage * player.get_upgrade_percent("fogo_explosao", "damage_pct"))
				for enemy in get_enemies_near(at, radius, target_ids):
					apply_hit(enemy, splash_damage, "Fogo")
				spawn_area_effect(at, radius, Color("#ff8a3d"))
		"Agua":
			var length: float = player.get_upgrade_number("agua_onda", "length")
			if length > 0.0:
				var wave_damage := roundi(damage * player.get_upgrade_percent("agua_onda", "damage_pct"))
				for enemy in get_enemies_near(at, length, target_ids):
					if enemy.global_position.x >= at.x:
						apply_hit(enemy, wave_damage, "Agua")
				spawn_area_effect(at + Vector2(length / 2.0, 0), length / 2.0, Color("#4bbbd8"))
		"Terra":
			if player.get_upgrade_level("terra_lamacal") > 0:
				spawn_mud_patch(at)
			var radius: float = player.get_upgrade_number("terra_tremor", "radius")
			if radius > 0.0:
				var tremor_damage := roundi(damage * player.get_upgrade_percent("terra_tremor", "damage_pct"))
				for enemy in get_enemies_near(at, radius, target_ids):
					apply_hit(enemy, tremor_damage, "Terra")
				spawn_area_effect(at, radius, Color("#c8925f"))
		"Ar":
			var radius: float = player.get_upgrade_number("ar_ventania", "radius")
			if radius > 0.0 and target.has_spreadable_status():
				for enemy in get_enemies_near(at, radius, target_ids):
					target.copy_statuses_to(enemy)
				spawn_area_effect(at, radius, Color("#e8f4f8"))

func bounce_projectile(projectile: Node2D, target: Node2D, at: Vector2) -> void:
	var hit_ids: Array[int] = projectile.chain_hit_ids.duplicate()
	hit_ids.append(target.get_instance_id())
	var candidates := get_enemies_near(at, player.get_upgrade_number("ar_ricochete", "radius"), hit_ids)
	if candidates.is_empty():
		return
	var bounce_damage: int = projectile.damage
	if projectile.is_primary:
		bounce_damage = maxi(1, roundi(projectile.damage * player.get_upgrade_percent("ar_ricochete", "damage_pct")))
	spawn_projectile(projectile.global_position, candidates[0], bounce_damage, projectile.element, false, projectile.bounces_left - 1, hit_ids)

func try_launch_tornado(damage: int) -> void:
	var every := roundi(player.get_upgrade_number("ar_tufao", "every"))
	if every <= 0:
		return
	air_attack_counter += 1
	if air_attack_counter < every:
		return
	air_attack_counter = 0
	var tornado := TORNADO_SCENE.instantiate()
	tornado.position = player.position + Vector2(30, 0)
	tornado.setup(roundi(damage * player.get_upgrade_percent("ar_tufao", "damage_pct")), player.position.x + player.get_attack_range() + 80.0)
	tornado.hit_enemy.connect(_on_tornado_hit)
	add_child(tornado)
	tornado.add_to_group("runtime_entity")

func _on_tornado_hit(enemy: Node2D, damage: int) -> void:
	apply_hit(enemy, damage, "Ar")

func spawn_mud_patch(at: Vector2) -> void:
	var mud := MUD_PATCH_SCENE.instantiate()
	mud.position = Vector2(at.x, player.position.y + 2.0)
	mud.setup(player.get_upgrade_number("terra_lamacal", "duration"), player.get_upgrade_number("terra_lamacal", "radius"), player.get_upgrade_percent("terra_lamacal", "speed_pct"))
	add_child(mud)
	mud.add_to_group("runtime_entity")

func spawn_area_effect(at: Vector2, radius: float, color: Color) -> void:
	var effect: Node2D = AREA_EFFECT.new()
	effect.position = at + Vector2(0, -36)
	effect.setup(radius, color)
	add_child(effect)
	effect.add_to_group("runtime_entity")

func move_entities_and_resolve_contacts() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.already_defeated and enemy.global_position.x <= player.global_position.x + 24.0:
			player.take_damage(enemy.contact_damage)
			enemy.die()
	for essence in get_tree().get_nodes_in_group("essences"):
		if not is_instance_valid(essence):
			continue
		if essence.global_position.x < player.global_position.x - 40.0:
			essence.queue_free()

func collect_nearby_essence() -> void:
	var closest: Node2D
	var closest_distance := 70.0
	for essence in get_tree().get_nodes_in_group("essences"):
		if not is_instance_valid(essence):
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

func _on_enemy_defeated(killed_by_attack: bool, killer_element: String, enemy: Node2D, counts_for_wave: bool) -> void:
	defeated_count += 1
	if counts_for_wave:
		wave_defeated_count += 1
	if killed_by_attack:
		grant_kill_xp(enemy.global_position, killer_element)
	check_wave_completion()
	update_hud()

# O mesmo valor sorteado vai para o XP geral (ate o nivel MAX) e para o XP do elemento do golpe final.
func grant_kill_xp(at: Vector2, element: String) -> void:
	var amount := spawn_rng.randi_range(min_xp_per_kill, maxi(min_xp_per_kill, max_xp_per_kill))
	player.add_xp(amount)
	player.add_element_xp(element, amount)
	var text := "+%d XP %s" % [amount, element] if element != "" else "+%d XP" % amount
	spawn_floating_text(at + Vector2(-24, -110), text, get_element_color(element))

func spawn_floating_text(at: Vector2, text: String, color: Color, font_size := 0) -> void:
	var popup := Label.new()
	popup.text = text
	if font_size > 0:
		popup.add_theme_font_size_override("font_size", font_size)
	popup.add_theme_color_override("font_color", color)
	popup.add_theme_color_override("font_outline_color", Color("#162d42"))
	popup.add_theme_constant_override("outline_size", 4)
	popup.z_index = 10
	popup.position = at
	add_child(popup)
	var tween := popup.create_tween()
	tween.set_parallel()
	tween.tween_property(popup, "position:y", popup.position.y - 40.0, 0.8)
	tween.tween_property(popup, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(popup.queue_free)

func show_level_up_message(new_level: int, unlocked_element: String) -> void:
	if unlocked_element != "":
		var element_keys := {"Fogo": 1, "Agua": 2, "Terra": 3, "Ar": 4}
		var unlocked_word := "liberado" if unlocked_element == "Ar" else "liberada"
		level_up_label.text = "NIVEL %d! %s %s (tecla %d)" % [new_level, unlocked_element, unlocked_word, element_keys.get(unlocked_element, 0)]
	elif new_level >= player.get_max_level():
		level_up_label.text = "NIVEL MAX! +%d%% de dano" % roundi((player.max_level_damage_multiplier - 1.0) * 100.0)
	else:
		level_up_label.text = "NIVEL %d!" % new_level
	if level_up_tween and level_up_tween.is_valid():
		level_up_tween.kill()
	level_up_label.visible = true
	level_up_label.modulate.a = 1.0
	level_up_tween = level_up_label.create_tween()
	level_up_tween.tween_interval(2.0)
	level_up_tween.tween_property(level_up_label, "modulate:a", 0.0, 0.5)
	level_up_tween.tween_callback(level_up_label.hide)
	update_hud()

func handle_defeat() -> void:
	game_over = true
	awaiting_next_wave = false
	defeat_overlay.visible = true
	defeat_label.text = "Game Over"
	overlay_message.text = "O Avatar foi derrotado na wave %d." % (current_wave + 1)
	overlay_stats.text = "Inimigos derrotados nesta wave: %d\n%s mantido para a proxima partida" % [wave_defeated_count, get_level_text()]
	overlay_button.text = "Tentar novamente"
	update_hud()
	update_debug()

func restart_game() -> void:
	shop_panel.close()
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
	essence_timer = 3.0
	air_attack_counter = 0
	game_over = false
	start_wave(0)
	update_hud()
	update_debug()
	queue_redraw()

func toggle_pause() -> void:
	if game_over or shop_panel.visible:
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
	hud_layer = canvas
	var top_bar := PanelContainer.new()
	top_bar.position = Vector2(18, 16)
	top_bar.size = Vector2(550, 175)
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
	level_label = Label.new()
	column.add_child(level_label)
	xp_bar = ProgressBar.new()
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.show_percentage = false
	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = Color("#f3c969")
	xp_bar.add_theme_stylebox_override("fill", xp_fill)
	column.add_child(xp_bar)
	element_xp_label = Label.new()
	column.add_child(element_xp_label)
	wave_label = Label.new()
	column.add_child(wave_label)
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
	advantage_label = Label.new()
	advantage_label.text = get_advantage_text()
	advantage_label.add_theme_color_override("font_color", Color("#a7a39a"))
	column.add_child(advantage_label)
	element_buttons.append(create_element_button(canvas, "1  Fogo", "Fogo", Vector2(590, 24)))
	element_buttons.append(create_element_button(canvas, "2  Agua", "Agua", Vector2(725, 24)))
	element_buttons.append(create_element_button(canvas, "3  Terra", "Terra", Vector2(590, 66)))
	element_buttons.append(create_element_button(canvas, "4  Ar", "Ar", Vector2(725, 66)))
	level_up_label = Label.new()
	level_up_label.position = Vector2(590, 112)
	level_up_label.add_theme_font_size_override("font_size", 20)
	level_up_label.add_theme_color_override("font_color", Color("#f3c969"))
	level_up_label.add_theme_color_override("font_outline_color", Color("#162d42"))
	level_up_label.add_theme_constant_override("outline_size", 5)
	level_up_label.visible = false
	canvas.add_child(level_up_label)
	defeat_overlay = PanelContainer.new()
	defeat_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	defeat_overlay.position = Vector2(300, 175)
	defeat_overlay.custom_minimum_size = Vector2(360, 190)
	canvas.add_child(defeat_overlay)
	var overlay_margin := MarginContainer.new()
	overlay_margin.add_theme_constant_override("margin_left", 22)
	overlay_margin.add_theme_constant_override("margin_right", 22)
	overlay_margin.add_theme_constant_override("margin_top", 18)
	overlay_margin.add_theme_constant_override("margin_bottom", 18)
	defeat_overlay.add_child(overlay_margin)
	var defeat_column := VBoxContainer.new()
	defeat_column.add_theme_constant_override("separation", 10)
	overlay_margin.add_child(defeat_column)
	defeat_label = Label.new()
	defeat_label.text = "Game Over"
	defeat_label.add_theme_font_size_override("font_size", 26)
	defeat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	defeat_column.add_child(defeat_label)
	overlay_message = Label.new()
	overlay_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	defeat_column.add_child(overlay_message)
	overlay_stats = Label.new()
	overlay_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	defeat_column.add_child(overlay_stats)
	overlay_button = Button.new()
	overlay_button.custom_minimum_size = Vector2(0, 38)
	overlay_button.pressed.connect(handle_overlay_action)
	defeat_column.add_child(overlay_button)
	defeat_overlay.visible = false

func create_element_button(canvas: CanvasLayer, label: String, element: String, button_position: Vector2) -> Button:
	var button := Button.new()
	button.text = label
	button.position = button_position
	button.size = Vector2(125, 36)
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
	if player.is_max_level():
		level_label.text = "Nivel MAX   +%d%% de dano" % roundi((player.max_level_damage_multiplier - 1.0) * 100.0)
		xp_bar.min_value = 0
		xp_bar.max_value = 1
		xp_bar.value = 1
	else:
		level_label.text = "%s   XP %d / %d" % [get_level_text(), player.xp, player.get_next_level_xp()]
		xp_bar.min_value = player.get_level_start_xp()
		xp_bar.max_value = player.get_next_level_xp()
		xp_bar.value = player.xp
	element_xp_label.text = "XP elemental   Fogo %d   Agua %d   Terra %d   Ar %d" % [player.get_element_xp("Fogo"), player.get_element_xp("Agua"), player.get_element_xp("Terra"), player.get_element_xp("Ar")]
	wave_label.text = "Wave %d/4   Progresso: %d/%d" % [current_wave + 1, wave_defeated_count, get_current_wave_total()]
	stats_label.text = "Inimigos derrotados: %d   Essencias: %d / 3" % [defeated_count, essence_count]
	element_label.text = "Elemento ativo: %s" % player.selected_element
	var cooldown: float = player.get_cooldown_remaining(player.selected_element)
	cooldown_label.text = "Recarga: Pronto" if cooldown <= 0.0 else "Recarga: %.1f s" % cooldown
	bonus_label.text = "Bonus de dano: ATIVO (%.1fs)" % bonus_timer if player.damage_bonus else "Bonus de dano: inativo"
	command_label.text = "1-4 elemento   E coletar   Q consumir 3   P loja   F1 debug"
	var elements := ["Fogo", "Agua", "Terra", "Ar"]
	var labels := ["1  Fogo", "2  Agua", "3  Terra", "4  Ar"]
	for index in element_buttons.size():
		var unlocked: bool = player.is_element_unlocked(elements[index])
		var lock_text := "" if unlocked else " (Nv%d)" % player.get_element_unlock_level(elements[index])
		element_buttons[index].text = ("* " if elements[index] == player.selected_element else "") + labels[index] + lock_text
		element_buttons[index].disabled = not unlocked
	if is_instance_valid(shop_panel) and shop_panel.visible:
		shop_panel.refresh()

func get_advantage_text() -> String:
	var parts := PackedStringArray()
	for attacker in player.element_advantages:
		var defenders: String = player.element_advantages[attacker]
		parts.append("%s > %s" % [attacker, defenders.replace(" ", "").replace(",", ", ")])
	var bonus_min := roundi((player.advantage_multiplier_min - 1.0) * 100.0)
	var bonus_max := roundi((player.advantage_multiplier_max - 1.0) * 100.0)
	return "Vantagem +%d-%d%%: %s" % [bonus_min, bonus_max, " | ".join(parts)]

func get_element_color(element: String) -> Color:
	match element:
		"Fogo": return Color("#ef654f")
		"Agua": return Color("#4bbbd8")
		"Terra": return Color("#c8925f")
		"Ar": return Color("#a6dfe8")
	return Color("#f3c969")

func get_level_text() -> String:
	return "Nivel MAX" if player.is_max_level() else "Nivel %d" % player.level

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
