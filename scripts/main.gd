extends Node2D

const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const PROJECTILE_SCENE := preload("res://scenes/Projectile.tscn")
const ESSENCE_SCENE := preload("res://scenes/Essence.tscn")
const DEBUG_SCENE := preload("res://scenes/DebugPanel.tscn")
const SHOP_SCENE := preload("res://scenes/ShopPanel.tscn")
const TORNADO_SCENE := preload("res://scenes/Tornado.tscn")
const MUD_PATCH_SCENE := preload("res://scenes/MudPatch.tscn")
const AREA_EFFECT := preload("res://scripts/area_effect.gd")
const MAP_BACKGROUNDS := {
	"water": preload("res://assets/environment/water/background.svg"),
	"earth": preload("res://assets/environment/earth/background.svg"),
	"fire": preload("res://assets/environment/fire/background.svg"),
	"air": preload("res://assets/environment/air/background.svg"),
	"equilibrium": preload("res://assets/environment/equilibrium/background.svg")
}
const MAP_GROUNDS := {
	"water": preload("res://assets/environment/water/ground.svg"),
	"earth": preload("res://assets/environment/earth/ground.svg"),
	"fire": preload("res://assets/environment/fire/ground.svg"),
	"air": preload("res://assets/environment/air/ground.svg"),
	"equilibrium": preload("res://assets/environment/equilibrium/ground.svg")
}
const REGION_NAMES := ["Floresta de Agua", "Montanha de Terra", "Vulcao de Fogo", "Templo do Ar", "Santuario do Equilibrio"]
const MAP_KEYS := ["water", "earth", "fire", "air", "equilibrium"]
const ELEMENT_TEXTURES := {
	"Fogo": preload("res://assets/elements/fire.svg"),
	"Agua": preload("res://assets/elements/water.svg"),
	"Terra": preload("res://assets/elements/earth.svg"),
	"Ar": preload("res://assets/elements/air.svg")
}
const SAVE_PATH := "user://progress.cfg"
const MENU_ART := preload("res://assets/ui/menu_art.svg")
const SHOP_ICON := preload("res://assets/ui/shop.svg")
const LEVEL_ICON := preload("res://assets/ui/level.svg")
const WAVE_ICON := preload("res://assets/ui/wave.svg")
const CYCLE_ICON := preload("res://assets/ui/cycle.svg")
const HELP_ICON := preload("res://assets/ui/help.svg")

@onready var player: Node2D = $Player
@onready var background: Sprite2D = $Background

@export var min_spawn_interval: float = 8.0
@export var max_spawn_interval: float = 10.0
@export var enemies_per_group: int = 4
@export var group_enemy_spacing: float = 100.0
@export var belt_speed: float = 56.0
@export var wave_enemy_counts: Array[int] = [12, 15, 18, 21, 24]
@export var wave_element_options: Array[String] = ["Agua", "Terra", "Fogo", "Ar", "Fogo,Agua,Terra,Ar"]
@export var enemy_health_per_wave: int = 50
@export var wave_enemy_count_per_cycle: int = 3
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
var campaign_started := false
var showing_instructions := false
var current_wave := 0
var selected_start_wave := 0
var unlocked_phase_count := 1
var farm_current_wave := false
var wave_spawned_count := 0
var wave_defeated_count := 0
var wave_start_essence_count := 0
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
var region_label: Label
var wave_progress: ProgressBar
var element_label: Label
var cooldown_label: Label
var bonus_label: Label
var command_label: Label
var advantage_label: Label
var defeat_overlay: PanelContainer
var defeat_label: Label
var overlay_message: Label
var overlay_stats: Label
var phase_selector_label: Label
var phase_selector: OptionButton
var overlay_button: Button
var overlay_secondary_button: Button
var overlay_art: TextureRect
var overlay_scroll: ScrollContainer
var debug_panel: PanelContainer
var shop_panel: PanelContainer
var hud_layer: CanvasLayer
var ground_tiles: Array[Sprite2D] = []
var transition_rect: ColorRect
var transition_tween: Tween
var wave_mode_button: Button
var essence_label: Label
var essence_counter: PanelContainer
var bonus_indicator: PanelContainer
var shop_button: Button
var interaction_label: Label
var last_selected_element := ""
var last_essence_count := 0
var last_bonus_active := false
var essence_tween: Tween
var selection_tween: Tween
var element_buttons: Array[Button] = []

func _ready() -> void:
	spawn_rng.randomize()
	load_progress()
	var enemy_probe := ENEMY_SCENE.instantiate()
	default_enemy_health = enemy_probe.max_health
	enemy_probe.free()
	build_hud()
	debug_panel = DEBUG_SCENE.instantiate()
	add_child(debug_panel)
	debug_panel.position = Vector2(682, 8)
	debug_panel.custom_minimum_size = Vector2(270, 524)
	debug_panel.size = Vector2(270, 524)
	debug_panel.clip_contents = true
	debug_panel.z_index = 50
	debug_panel.setup(self)
	shop_panel = SHOP_SCENE.instantiate()
	hud_layer.add_child(shop_panel)
	shop_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	shop_panel.setup(self, player)
	shop_button.pressed.connect(shop_panel.open)
	player.health_changed.connect(update_health)
	player.died.connect(handle_defeat)
	player.leveled_up.connect(show_level_up_message)
	player.xp_changed.connect(func(_xp: int, _level: int) -> void: save_progress())
	player.set_process(false)
	apply_map(0)
	show_start_screen()
	update_hud()
	update_debug()
	queue_redraw()

func _process(delta: float) -> void:
	if not campaign_started or game_over:
		return
	belt_offset = fmod(belt_offset + belt_speed * delta, 80.0)
	enemy_timer -= delta
	essence_timer -= delta
	bonus_timer = maxf(0.0, bonus_timer - delta)
	if bonus_timer == 0.0 and player.damage_bonus:
		player.damage_bonus = false
		update_hud()
	if enemy_timer <= 0.0 and wave_spawned_count < get_current_wave_total():
		spawn_enemy_group()
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
	if event.keycode == KEY_1 and campaign_started and not game_over:
		select_element("Fogo")
	elif event.keycode == KEY_2 and campaign_started and not game_over:
		select_element("Agua")
	elif event.keycode == KEY_3 and campaign_started and not game_over:
		select_element("Terra")
	elif event.keycode == KEY_4 and campaign_started and not game_over:
		select_element("Ar")
	elif event.keycode == KEY_E and campaign_started and not game_over:
		collect_nearby_essence()
	elif event.keycode == KEY_Q and campaign_started and not game_over:
		activate_bonus()
	update_hud()

func spawn_enemy(enemy_element: String, is_wave_enemy: bool, spawn_position: Vector2 = Vector2(1000.0, 430.0)) -> void:
	if game_over:
		return
	var enemy := ENEMY_SCENE.instantiate()
	enemy.position = spawn_position
	enemy.element = enemy_element
	enemy.counts_for_wave = is_wave_enemy
	enemy.max_health = get_enemy_max_health()
	enemy.damage_modifier = player.get_damage_taken_multiplier
	add_child(enemy)
	enemy.add_to_group("runtime_entity")
	enemy.add_to_group("enemies")
	enemy.add_to_group("wave_enemies" if is_wave_enemy else "debug_enemies")
	enemy.defeated.connect(_on_enemy_defeated.bind(enemy, is_wave_enemy))

func spawn_enemy_group() -> void:
	var group_size: int = mini(maxi(1, enemies_per_group), get_current_wave_total() - wave_spawned_count)
	for index in group_size:
		var spawn_position := Vector2(1000.0 + index * maxf(0.0, group_enemy_spacing), 430.0)
		spawn_enemy(choose_wave_element(), true, spawn_position)
	wave_spawned_count += group_size

func get_next_spawn_interval() -> float:
	var safe_minimum: float = maxf(min_spawn_interval, 0.01)
	var safe_maximum: float = maxf(max_spawn_interval, safe_minimum)
	return spawn_rng.randf_range(safe_minimum, safe_maximum)

func get_current_wave_total() -> int:
	if current_wave < 0 or wave_enemy_counts.is_empty():
		return 0
	var config_index := posmod(current_wave, wave_enemy_counts.size())
	var cycle := floori(float(current_wave) / wave_enemy_counts.size())
	return maxi(0, wave_enemy_counts[config_index] + cycle * maxi(0, wave_enemy_count_per_cycle))

func get_current_wave_elements() -> Array[String]:
	var elements: Array[String] = []
	if current_wave < 0 or wave_element_options.is_empty():
		return elements
	var config_index := posmod(current_wave, wave_element_options.size())
	for element_name in wave_element_options[config_index].split(","):
		var clean_name := element_name.strip_edges()
		if clean_name != "":
			elements.append(clean_name)
	return elements

func choose_wave_element() -> String:
	var elements := get_current_wave_elements()
	if elements.is_empty():
		return "Fogo"
	return elements[spawn_rng.randi_range(0, elements.size() - 1)]

func start_wave(wave_index: int, save_wave_resources := true) -> void:
	if wave_index < 0 or wave_enemy_counts.is_empty():
		return
	current_wave = wave_index
	wave_spawned_count = 0
	wave_defeated_count = 0
	enemy_timer = 0.0
	game_over = false
	if save_wave_resources:
		wave_start_essence_count = essence_count
	apply_map(current_wave)
	play_map_transition()
	defeat_overlay.visible = false
	save_progress()
	update_hud()

func select_start_wave(wave_index: int) -> void:
	if wave_index < 0 or wave_index >= unlocked_phase_count:
		return
	selected_start_wave = wave_index
	save_progress()
	if not campaign_started or game_over:
		return
	for entity in get_tree().get_nodes_in_group("runtime_entity"):
		if is_instance_valid(entity):
			entity.queue_free()
	player.reset()
	bonus_timer = 0.0
	air_attack_counter = 0
	start_wave(selected_start_wave)

func apply_map(wave_index: int) -> void:
	if wave_index < 0:
		return
	var map_key: String = MAP_KEYS[posmod(wave_index, MAP_KEYS.size())]
	background.texture = MAP_BACKGROUNDS[map_key]
	for tile_index in range(1, 7):
		var tile := get_node_or_null("GroundTile%02d" % tile_index) as Sprite2D
		if tile != null:
			tile.texture = MAP_GROUNDS[map_key]

func play_map_transition() -> void:
	if not is_instance_valid(transition_rect):
		return
	if transition_tween and transition_tween.is_valid():
		transition_tween.kill()
	transition_rect.color.a = 1.0
	transition_tween = create_tween()
	transition_tween.tween_property(transition_rect, "color:a", 0.0, 0.35)

func show_start_screen() -> void:
	campaign_started = false
	game_over = false
	showing_instructions = false
	player.set_process(false)
	defeat_overlay.visible = true
	defeat_overlay.position = Vector2(280, 70)
	defeat_overlay.custom_minimum_size = Vector2(400, 400)
	defeat_overlay.size = Vector2(400, 400)
	overlay_scroll.custom_minimum_size = Vector2(350, 42)
	overlay_art.visible = true
	defeat_label.text = "Elemental Idle Runner"
	overlay_message.text = "Quatro elementos. Um unico proposito."
	overlay_stats.text = "Escolha uma regiao para iniciar.\n1-4 elementos | E coleta | Q bonus | P loja"
	overlay_button.text = "Jogar"
	overlay_secondary_button.visible = true
	overlay_secondary_button.text = "Instrucoes"
	selected_start_wave = mini(selected_start_wave, unlocked_phase_count - 1)
	phase_selector.select(selected_start_wave)
	update_hud()

func show_instructions() -> void:
	showing_instructions = true
	defeat_overlay.visible = true
	defeat_overlay.position = Vector2(280, 18)
	defeat_overlay.custom_minimum_size = Vector2(400, 504)
	defeat_overlay.size = Vector2(400, 504)
	overlay_scroll.custom_minimum_size = Vector2(350, 240)
	overlay_art.visible = false
	defeat_label.text = "Instrucoes"
	overlay_message.text = "COMBATE\nO Avatar ataca automaticamente quando ha um alvo.\nUse 1-4 para escolher Fogo, Agua, Terra ou Ar.\n\nRECURSOS\nPressione E perto de uma essencia. Com 3 essencias, use Q para ativar o bonus por 5 segundos.\n\nPROGRESSAO\nProgredir avanca pelas fases. Farmar repete a fase selecionada para ganhar XP e comprar melhorias.\n\nCONTROLES\nP abre a loja | Esc fecha menus | F1 abre o debug"
	overlay_stats.text = "Fases desbloqueadas: %d/5" % unlocked_phase_count
	overlay_button.text = "Voltar"
	overlay_secondary_button.visible = false

func handle_secondary_overlay_action() -> void:
	show_instructions()

func begin_campaign() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	speed_index = 0
	var saved_element: String = player.selected_element
	player.reset()
	if player.is_element_unlocked(saved_element):
		player.selected_element = saved_element
	bonus_timer = 0.0
	game_over = false
	campaign_started = true
	overlay_art.visible = false
	player.set_process(true)
	start_wave(selected_start_wave)
	save_progress()
	update_debug()

func retry_current_wave() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	speed_index = 0
	for entity in get_tree().get_nodes_in_group("runtime_entity"):
		if is_instance_valid(entity):
			entity.queue_free()
	var saved_element: String = player.selected_element
	player.reset()
	if player.is_element_unlocked(saved_element):
		player.selected_element = saved_element
	essence_count = wave_start_essence_count
	bonus_timer = 0.0
	air_attack_counter = 0
	campaign_started = true
	player.set_process(true)
	start_wave(current_wave, false)
	update_debug()

func has_active_enemies(group_name: String) -> bool:
	for enemy in get_tree().get_nodes_in_group(group_name):
		if is_instance_valid(enemy) and not enemy.already_defeated:
			return true
	return false

func check_wave_completion() -> void:
	if wave_spawned_count < get_current_wave_total():
		return
	if wave_defeated_count < get_current_wave_total():
		return
	if has_active_enemies("wave_enemies") or has_active_enemies("debug_enemies"):
		return
	var next_phase := posmod(current_wave + 1, REGION_NAMES.size())
	if next_phase > 0:
		unlock_phase(next_phase)
	if farm_current_wave:
		start_wave(current_wave)
	else:
		current_wave += 1
		selected_start_wave = posmod(current_wave, REGION_NAMES.size())
		phase_selector.select(selected_start_wave)
		start_wave(current_wave)

func load_progress() -> void:
	var progress := ConfigFile.new()
	var error := progress.load(SAVE_PATH)
	if error == ERR_FILE_NOT_FOUND:
		return
	if error != OK:
		push_error("Nao foi possivel carregar o progresso: %s" % error_string(error))
		return
	var saved_count: Variant = progress.get_value("campaign", "unlocked_phase_count", 1)
	if typeof(saved_count) == TYPE_INT:
		unlocked_phase_count = clampi(int(saved_count), 1, REGION_NAMES.size())
	var saved_wave: Variant = progress.get_value("campaign", "current_wave", 0)
	if typeof(saved_wave) == TYPE_INT:
		current_wave = maxi(0, int(saved_wave))
	var saved_selected: Variant = progress.get_value("campaign", "selected_start_wave", 0)
	if typeof(saved_selected) == TYPE_INT:
		selected_start_wave = clampi(int(saved_selected), 0, unlocked_phase_count - 1)
	farm_current_wave = bool(progress.get_value("campaign", "farm_current_wave", false))
	essence_count = maxi(0, int(progress.get_value("resources", "essence_count", 0)))
	var saved_xp: Variant = progress.get_value("player", "xp", 0)
	var saved_level: Variant = progress.get_value("player", "level", 1)
	if typeof(saved_xp) == TYPE_INT:
		player.xp = maxi(0, int(saved_xp))
	if typeof(saved_level) == TYPE_INT:
		player.level = clampi(int(saved_level), 1, player.get_max_level())
	var saved_element: String = str(progress.get_value("player", "selected_element", "Fogo"))
	if player.is_element_unlocked(saved_element):
		player.selected_element = saved_element
	var saved_element_xp: Variant = progress.get_value("player", "element_xp", {})
	if saved_element_xp is Dictionary:
		for element in player.element_xp:
			player.element_xp[element] = maxi(0, int(saved_element_xp.get(element, 0)))
	var saved_upgrades: Variant = progress.get_value("player", "upgrade_levels", {})
	if saved_upgrades is Dictionary:
		player.upgrade_levels.clear()
		for upgrade_id in saved_upgrades:
			player.upgrade_levels[str(upgrade_id)] = maxi(0, int(saved_upgrades[upgrade_id]))
	player.update_health_bar()

func save_progress() -> void:
	var progress := ConfigFile.new()
	progress.set_value("campaign", "unlocked_phase_count", unlocked_phase_count)
	progress.set_value("campaign", "current_wave", current_wave)
	progress.set_value("campaign", "selected_start_wave", selected_start_wave)
	progress.set_value("campaign", "farm_current_wave", farm_current_wave)
	progress.set_value("player", "xp", player.xp)
	progress.set_value("player", "level", player.level)
	progress.set_value("player", "selected_element", player.selected_element)
	progress.set_value("player", "element_xp", player.element_xp)
	progress.set_value("player", "upgrade_levels", player.upgrade_levels)
	progress.set_value("resources", "essence_count", essence_count)
	var error := progress.save(SAVE_PATH)
	if error != OK:
		push_error("Nao foi possivel salvar o progresso: %s" % error_string(error))

func unlock_phase(phase_index: int) -> void:
	if phase_index != unlocked_phase_count or unlocked_phase_count >= REGION_NAMES.size():
		return
	unlocked_phase_count += 1
	refresh_phase_selector()
	save_progress()

func refresh_phase_selector() -> void:
	for index in REGION_NAMES.size():
		phase_selector.set_item_disabled(index, index >= unlocked_phase_count)

func toggle_wave_mode() -> void:
	farm_current_wave = not farm_current_wave
	save_progress()
	update_hud()

func handle_overlay_action() -> void:
	if showing_instructions:
		show_start_screen()
	elif not campaign_started:
		begin_campaign()
	elif game_over:
		retry_current_wave()
	else:
		begin_campaign()

func debug_spawn_enemy() -> void:
	if campaign_started and not game_over:
		spawn_enemy(choose_wave_element(), false)

func debug_add_xp() -> void:
	player.add_xp(100)
	update_hud()

func debug_add_element_xp() -> void:
	for element in ["Fogo", "Agua", "Terra", "Ar"]:
		player.add_element_xp(element, 100)
	save_progress()
	update_hud()

func debug_reset_progress() -> void:
	reset_all_progress()

func reset_all_progress() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	if is_instance_valid(shop_panel):
		shop_panel.close()
	if is_instance_valid(debug_panel):
		debug_panel.visible = false
	for entity in get_tree().get_nodes_in_group("runtime_entity"):
		if is_instance_valid(entity):
			entity.queue_free()
	player.reset_progress()
	player.reset()
	unlocked_phase_count = 1
	selected_start_wave = 0
	current_wave = 0
	farm_current_wave = false
	wave_spawned_count = 0
	wave_defeated_count = 0
	wave_start_essence_count = 0
	defeated_count = 0
	essence_count = 0
	bonus_timer = 0.0
	enemy_health_override = 0
	air_attack_counter = 0
	campaign_started = false
	game_over = false
	show_start_screen()
	refresh_phase_selector()
	var save_absolute_path := ProjectSettings.globalize_path(SAVE_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(save_absolute_path)
	save_progress()
	update_hud()

func get_enemy_max_health() -> int:
	if enemy_health_override > 0:
		return enemy_health_override
	return maxi(1, enemy_health_per_wave * (current_wave + 1))

# Vale para os proximos inimigos e ajusta os vivos mantendo a proporcao da vida atual.
func debug_set_enemy_health(value: float) -> void:
	enemy_health_override = maxi(1, roundi(value))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.already_defeated:
			continue
		var ratio := float(enemy.health) / float(maxi(1, enemy.max_health))
		enemy.max_health = enemy_health_override
		enemy.health = maxi(1, roundi(enemy_health_override * ratio))
		enemy.setup_health_bar()
		enemy.update_health_bar()
		enemy.queue_redraw()

func select_element(element: String) -> void:
	if not campaign_started or game_over:
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
		save_progress()
		update_hud()

func activate_bonus() -> void:
	if essence_count < 3 or player.damage_bonus:
		return
	essence_count -= 3
	player.damage_bonus = true
	bonus_timer = 5.0
	save_progress()
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
	call_deferred("retry_current_wave")

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
	selected_start_wave = 0
	phase_selector.select(selected_start_wave)
	begin_campaign()
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
	top_bar.size = Vector2(360, 132)
	apply_hud_panel_style(top_bar, Color("#162d42", 0.88), Color("#5c8f93"))
	canvas.add_child(top_bar)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	top_bar.add_child(column)
	health_label = Label.new()
	health_label.text = "Vida"
	health_label.visible = false
	column.add_child(health_label)
	health_bar = ProgressBar.new()
	health_bar.max_value = player.max_health
	health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_bar.show_percentage = false
	health_bar.visible = false
	column.add_child(health_bar)
	level_label = Label.new()
	var level_row := HBoxContainer.new()
	level_row.add_child(create_ui_icon(LEVEL_ICON, 22))
	level_row.add_child(level_label)
	column.add_child(level_row)
	xp_bar = ProgressBar.new()
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.show_percentage = false
	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = Color("#f3c969")
	xp_bar.add_theme_stylebox_override("fill", xp_fill)
	column.add_child(xp_bar)
	element_xp_label = Label.new()
	element_xp_label.visible = false
	column.add_child(element_xp_label)
	wave_label = Label.new()
	var wave_row := HBoxContainer.new()
	wave_row.add_child(create_ui_icon(WAVE_ICON, 22))
	wave_row.add_child(wave_label)
	column.add_child(wave_row)
	wave_progress = ProgressBar.new()
	wave_progress.custom_minimum_size = Vector2(0, 8)
	wave_progress.show_percentage = false
	var wave_fill := StyleBoxFlat.new()
	wave_fill.bg_color = Color("#4bbbd8")
	wave_progress.add_theme_stylebox_override("fill", wave_fill)
	column.add_child(wave_progress)
	region_label = Label.new()
	var region_row := HBoxContainer.new()
	region_row.add_child(create_ui_icon(CYCLE_ICON, 18))
	region_row.add_child(region_label)
	column.add_child(region_row)
	stats_label = Label.new()
	stats_label.visible = false
	column.add_child(stats_label)
	element_label = Label.new()
	element_label.visible = false
	column.add_child(element_label)
	cooldown_label = Label.new()
	cooldown_label.visible = false
	column.add_child(cooldown_label)
	bonus_label = Label.new()
	bonus_label.visible = false
	column.add_child(bonus_label)
	command_label = Label.new()
	command_label.visible = false
	command_label.add_theme_color_override("font_color", Color("#a7a39a"))
	column.add_child(command_label)
	advantage_label = Label.new()
	advantage_label.visible = false
	advantage_label.text = get_advantage_text()
	advantage_label.add_theme_color_override("font_color", Color("#a7a39a"))
	column.add_child(advantage_label)
	element_buttons.append(create_element_button(canvas, "1", "Fogo", Vector2(300, 482)))
	element_buttons.append(create_element_button(canvas, "2", "Agua", Vector2(390, 482)))
	element_buttons.append(create_element_button(canvas, "3", "Terra", Vector2(480, 482)))
	element_buttons.append(create_element_button(canvas, "4", "Ar", Vector2(570, 482)))
	var element_bar := PanelContainer.new()
	element_bar.position = Vector2(280, 474)
	element_bar.size = Vector2(430, 58)
	element_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	apply_hud_panel_style(element_bar, Color("#162d42", 0.78), Color("#5c8f93"))
	canvas.add_child(element_bar)
	element_bar.move_to_front()
	for button in element_buttons:
		button.move_to_front()
	interaction_label = Label.new()
	phase_selector_label = Label.new()
	phase_selector_label.text = "Selecionar fase"
	phase_selector_label.position = Vector2(18, 150)
	phase_selector_label.add_theme_color_override("font_color", Color("#d9e8df"))
	phase_selector_label.add_theme_color_override("font_outline_color", Color("#162d42"))
	phase_selector_label.add_theme_constant_override("outline_size", 3)
	canvas.add_child(phase_selector_label)
	phase_selector = OptionButton.new()
	phase_selector.position = Vector2(18, 172)
	phase_selector.size = Vector2(300, 34)
	for index in REGION_NAMES.size():
		phase_selector.add_item("Fase %d - %s" % [index + 1, REGION_NAMES[index]])
	phase_selector.select(selected_start_wave)
	refresh_phase_selector()
	phase_selector.item_selected.connect(select_start_wave)
	canvas.add_child(phase_selector)
	interaction_label.position = Vector2(18, 214)
	interaction_label.add_theme_color_override("font_color", Color("#d9e8df"))
	interaction_label.add_theme_color_override("font_outline_color", Color("#162d42"))
	interaction_label.add_theme_constant_override("outline_size", 3)
	canvas.add_child(interaction_label)
	shop_button = Button.new()
	shop_button.text = "P  Loja"
	shop_button.icon = SHOP_ICON
	shop_button.expand_icon = true
	shop_button.position = Vector2(690, 18)
	shop_button.size = Vector2(88, 42)
	shop_button.pivot_offset = shop_button.size / 2.0
	shop_button.tooltip_text = "Abrir loja de melhorias"
	canvas.add_child(shop_button)
	wave_mode_button = Button.new()
	wave_mode_button.position = Vector2(500, 18)
	wave_mode_button.size = Vector2(180, 42)
	wave_mode_button.tooltip_text = "Alternar entre avancar para a proxima wave e repetir esta wave para farmar"
	wave_mode_button.pressed.connect(toggle_wave_mode)
	canvas.add_child(wave_mode_button)
	var essence_panel := PanelContainer.new()
	essence_panel.position = Vector2(790, 18)
	essence_panel.custom_minimum_size = Vector2(150, 58)
	apply_hud_panel_style(essence_panel, Color("#162d42", 0.88), Color("#f3c969"))
	canvas.add_child(essence_panel)
	var essence_row := HBoxContainer.new()
	essence_row.add_theme_constant_override("separation", 8)
	essence_panel.add_child(essence_row)
	var essence_icon := TextureRect.new()
	essence_icon.texture = preload("res://assets/items/essence.svg")
	essence_icon.custom_minimum_size = Vector2(38, 38)
	essence_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	essence_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	essence_row.add_child(essence_icon)
	essence_label = Label.new()
	essence_label.add_theme_font_size_override("font_size", 20)
	essence_row.add_child(essence_label)
	essence_counter = essence_panel
	bonus_indicator = PanelContainer.new()
	bonus_indicator.position = Vector2(790, 82)
	bonus_indicator.custom_minimum_size = Vector2(150, 38)
	bonus_indicator.visible = false
	apply_hud_panel_style(bonus_indicator, Color("#714936", 0.9), Color("#f3c969"))
	canvas.add_child(bonus_indicator)
	var bonus_indicator_label := Label.new()
	bonus_indicator_label.text = "BONUS DE DANO"
	bonus_indicator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bonus_indicator.add_child(bonus_indicator_label)
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
	defeat_overlay.position = Vector2(280, 18)
	defeat_overlay.custom_minimum_size = Vector2(400, 504)
	defeat_overlay.size = Vector2(400, 504)
	defeat_overlay.clip_contents = true
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
	overlay_art = TextureRect.new()
	overlay_art.texture = MENU_ART
	overlay_art.custom_minimum_size = Vector2(320, 133)
	overlay_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	defeat_column.add_child(overlay_art)
	overlay_scroll = ScrollContainer.new()
	overlay_scroll.custom_minimum_size = Vector2(0, 190)
	overlay_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defeat_column.add_child(overlay_scroll)
	overlay_message = Label.new()
	overlay_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_message.custom_minimum_size = Vector2(350, 0)
	overlay_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_scroll.add_child(overlay_message)
	overlay_stats = Label.new()
	overlay_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	defeat_column.add_child(overlay_stats)
	overlay_button = Button.new()
	overlay_button.custom_minimum_size = Vector2(0, 38)
	overlay_button.pressed.connect(handle_overlay_action)
	defeat_column.add_child(overlay_button)
	overlay_secondary_button = Button.new()
	overlay_secondary_button.icon = HELP_ICON
	overlay_secondary_button.expand_icon = true
	overlay_secondary_button.custom_minimum_size = Vector2(0, 34)
	overlay_secondary_button.pressed.connect(handle_secondary_overlay_action)
	defeat_column.add_child(overlay_secondary_button)
	defeat_overlay.visible = false
	transition_rect = ColorRect.new()
	transition_rect.position = Vector2.ZERO
	transition_rect.size = Vector2(960, 540)
	transition_rect.color = Color(0.02, 0.04, 0.06, 0.0)
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_rect.z_index = 100
	canvas.add_child(transition_rect)

func create_ui_icon(texture: Texture2D, size: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(size, size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func apply_hud_panel_style(panel: PanelContainer, background_color: Color, border_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	panel.add_theme_stylebox_override("panel", style)

func create_element_button(canvas: CanvasLayer, label: String, element: String, button_position: Vector2) -> Button:
	var button := Button.new()
	button.text = label
	button.icon = ELEMENT_TEXTURES[element]
	button.expand_icon = true
	button.position = button_position
	button.size = Vector2(78, 48)
	button.pivot_offset = button.size / 2.0
	button.tooltip_text = element
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
	wave_label.text = "Wave %d   Progresso: %d/%d" % [current_wave + 1, wave_defeated_count, get_current_wave_total()]
	region_label.text = REGION_NAMES[posmod(current_wave, REGION_NAMES.size())].to_upper()
	wave_progress.max_value = maxi(1, get_current_wave_total())
	wave_progress.value = wave_defeated_count
	stats_label.text = "Inimigos derrotados: %d   Essencias: %d / 3" % [defeated_count, essence_count]
	if player.selected_element != last_selected_element:
		last_selected_element = player.selected_element
		animate_selection_feedback()
	essence_label.text = str(essence_count)
	if essence_count != last_essence_count:
		last_essence_count = essence_count
		animate_essence_feedback()
	bonus_indicator.visible = player.damage_bonus
	if player.damage_bonus and not last_bonus_active:
		animate_bonus_feedback()
	last_bonus_active = player.damage_bonus
	shop_button.disabled = not campaign_started or game_over
	wave_mode_button.text = "Modo: Farmar" if farm_current_wave else "Modo: Progredir"
	wave_mode_button.disabled = not campaign_started or game_over
	var elements := ["Fogo", "Agua", "Terra", "Ar"]
	var labels := ["1", "2", "3", "4"]
	for index in element_buttons.size():
		var unlocked: bool = player.is_element_unlocked(elements[index])
		var lock_text := "" if unlocked else "\nNv. %d" % player.get_element_unlock_level(elements[index])
		element_buttons[index].text = labels[index] + lock_text
		element_buttons[index].disabled = not unlocked
		element_buttons[index].scale = Vector2(1.08, 1.08) if elements[index] == player.selected_element else Vector2.ONE
		element_buttons[index].modulate = Color("#fff1b0") if elements[index] == player.selected_element else (Color("#8b9696") if not unlocked else Color.WHITE)
	interaction_label.text = get_interaction_hint()
	if is_instance_valid(shop_panel) and shop_panel.visible:
		shop_panel.refresh()

func animate_selection_feedback() -> void:
	if selection_tween and selection_tween.is_valid():
		selection_tween.kill()
	var element_index := ["Fogo", "Agua", "Terra", "Ar"].find(player.selected_element)
	if element_index < 0 or element_index >= element_buttons.size():
		return
	var selected_button := element_buttons[element_index]
	selection_tween = selected_button.create_tween()
	selection_tween.tween_property(selected_button, "scale", Vector2(1.16, 1.16), 0.1)
	selection_tween.tween_property(selected_button, "scale", Vector2(1.08, 1.08), 0.16)

func get_interaction_hint() -> String:
	var hints := PackedStringArray()
	if has_nearby_essence():
		hints.append("[E] Coletar essencia")
	else:
		hints.append("E coletar")
	if essence_count >= 3 and not player.damage_bonus:
		hints.append("[Q] Bonus pronto")
	else:
		hints.append("Q bonus")
	hints.append("F1 debug")
	return "   |   ".join(hints)

func has_nearby_essence() -> bool:
	for essence in get_tree().get_nodes_in_group("essences"):
		if is_instance_valid(essence) and player.global_position.distance_to(essence.global_position) <= 70.0:
			return true
	return false

func animate_essence_feedback() -> void:
	if essence_tween and essence_tween.is_valid():
		essence_tween.kill()
	essence_counter.scale = Vector2.ONE
	essence_tween = essence_counter.create_tween()
	essence_tween.tween_property(essence_counter, "scale", Vector2(1.12, 1.12), 0.1)
	essence_tween.tween_property(essence_counter, "scale", Vector2.ONE, 0.16)

func animate_bonus_feedback() -> void:
	bonus_indicator.scale = Vector2.ONE
	var tween := bonus_indicator.create_tween()
	tween.tween_property(bonus_indicator, "scale", Vector2(1.08, 1.08), 0.12)
	tween.tween_property(bonus_indicator, "scale", Vector2.ONE, 0.18)

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
		var cycle := floori(float(current_wave) / REGION_NAMES.size()) + 1
		var progress_text := "Fase %d/5 | Ciclo %d | Vida inimigo %d" % [posmod(current_wave, REGION_NAMES.size()) + 1, cycle, get_enemy_max_health()]
		debug_panel.update_display(state, speeds[speed_index], get_tree().paused, progress_text)

func _draw() -> void:
	for x in range(-80, 1040, 80):
		var belt_x := x - belt_offset
		draw_line(Vector2(belt_x, 458), Vector2(belt_x + 42, 500), Color("#53746b"), 5.0)
		draw_line(Vector2(belt_x + 42, 500), Vector2(belt_x + 80, 458), Color("#53746b"), 5.0)
	draw_line(Vector2(0, 456), Vector2(960, 456), Color("#f3c969"), 3.0)
