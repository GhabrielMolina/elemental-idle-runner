extends PanelContainer

# Tutorial progressivo: a HUD comeca vazia e cada parte aparece junto com uma dica que pausa o jogo.
# O main.gd consulta is_revealed() para montar a HUD e avisa os eventos (inicio de wave, derrota, novo elemento).

const FEATURES := ["progresso", "loja", "essencias", "modo", "fases"]
# Indice da wave (0 = Wave 1) -> dica mostrada no inicio dela.
const WAVE_STEPS := {0: "boas_vindas", 1: "progresso", 2: "essencias", 3: "estrategia"}
# "reveal" libera partes da HUD; "highlight" so faz pulsar controles que ja estao visiveis.
const STEPS := {
	"boas_vindas": {
		"title": "Bem-vindo, Avatar!",
		"text": "Voce ataca sozinho todo inimigo que entra no alcance. Nao deixe que eles encostem em voce: cada toque tira vida da barra acima da sua cabeca.",
		"button": "Comecar",
		"highlight": ["elemento_Fogo"],
	},
	"progresso": {
		"title": "Seu progresso",
		"text": "Aqui em cima ficam seu nivel, o XP e o progresso da wave atual. A cada wave os inimigos ficam mais resistentes.",
		"reveal": ["progresso"],
	},
	"loja": {
		"title": "Voce foi derrotado",
		"text": "Calma: o XP que voce ganhou continua seu. Cada elemento junta o proprio XP, que compra melhorias na Loja. Fortaleca seus ataques e tente de novo.",
		"reveal": ["loja"],
		"button": "Abrir loja",
		"secondary": "Depois",
	},
	"loja_sem_derrota": {
		"title": "Loja liberada",
		"text": "Cada elemento junta o proprio XP, que compra melhorias na Loja (tecla P). Use-as para encarar inimigos mais fortes.",
		"reveal": ["loja"],
		"button": "Abrir loja",
		"secondary": "Depois",
	},
	"essencias": {
		"title": "Essencias",
		"text": "Essencias aparecem no caminho. Aperte E quando uma estiver perto do Avatar. Com 3 essencias, aperte Q para causar dano dobrado por 5 segundos.",
		"reveal": ["essencias"],
	},
	"estrategia": {
		"title": "Ultima licao",
		"text": "Travou em uma fase? Troque o Modo para Farmar e repita a wave para juntar XP, ou volte a uma fase ja liberada no seletor. Agora voce conhece tudo. Boa jornada!",
		"reveal": ["modo", "fases"],
		"button": "Vamos la",
	},
}
# Dicas dos elementos liberados por nivel; a vantagem elemental vem de Player.element_advantages.
const ELEMENT_TIPS := {
	"Agua": {"key": 2, "effect": "deixa os inimigos lentos"},
	"Terra": {"key": 3, "effect": "bate forte, atordoa os inimigos"},
	"Ar": {"key": 4, "effect": "ataca rapido, empurra os inimigos"},
}
const DEFAULT_BUTTON := "Entendi"
const PULSE_SCALE := Vector2(1.1, 1.1)
const PULSE_TIME := 0.35

var main_controller: Node
var revealed: Dictionary[String, bool] = {}
var seen: Dictionary[String, bool] = {}
var completed := false
var pending: Array[String] = []
var current_step := ""
var was_paused := false
var pulse_tween: Tween
var pulsing: Array[Control] = []
var title_label: Label
var text_label: Label
var primary_button: Button
var secondary_button: Button

func setup(controller: Node) -> void:
	main_controller = controller
	build_interface()

func build_interface() -> void:
	position = Vector2(340, 150)
	custom_minimum_size = Vector2(400, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#162d42", 0.96)
	style.border_color = Color("#f3c969")
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color("#f3c969"))
	column.add_child(title_label)
	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(364, 0)
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(text_label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	column.add_child(buttons)
	secondary_button = Button.new()
	secondary_button.custom_minimum_size = Vector2(120, 36)
	secondary_button.pressed.connect(close_message)
	buttons.add_child(secondary_button)
	primary_button = Button.new()
	primary_button.custom_minimum_size = Vector2(150, 36)
	primary_button.pressed.connect(_on_primary_pressed)
	buttons.add_child(primary_button)
	visible = false

func is_active() -> bool:
	return not completed

func is_revealed(feature: String) -> bool:
	return completed or revealed.get(feature, false)

func is_showing() -> bool:
	return visible

func on_wave_started(wave_index: int) -> void:
	if completed:
		return
	# Quem passa da Wave 2 sem perder ganha a loja no inicio da Wave 3.
	if wave_index >= 2 and not is_revealed("loja"):
		enqueue("loja_sem_derrota")
	for step_wave in WAVE_STEPS:
		if step_wave <= wave_index:
			enqueue(WAVE_STEPS[step_wave])
	try_show_next()

func on_defeat() -> void:
	if completed:
		return
	if not is_revealed("loja"):
		enqueue("loja")
		try_show_next()
	elif main_controller.player.has_affordable_upgrade():
		pulse(main_controller.get_tutorial_targets("loja"), 3)

func on_level_up(_level: int, unlocked_element: String) -> void:
	if not ELEMENT_TIPS.has(unlocked_element):
		return
	enqueue("elemento_" + unlocked_element)
	try_show_next()

func enqueue(step_id: String) -> void:
	if seen.has(step_id) or pending.has(step_id) or step_id == current_step:
		return
	pending.append(step_id)

# Mostra a proxima dica da fila; nunca abre por cima da loja nem fora da campanha.
func try_show_next() -> void:
	if visible or main_controller == null or not main_controller.campaign_started or main_controller.is_shop_open():
		return
	while not pending.is_empty():
		var step_id: String = pending.pop_front()
		var step := get_step(step_id)
		if step.is_empty() or seen.has(step_id):
			continue
		# A loja pode ter sido liberada por outra dica enquanto esta esperava na fila.
		if step_id.begins_with("loja") and is_revealed("loja"):
			seen[step_id] = true
			continue
		show_step(step_id, step)
		return

func get_step(step_id: String) -> Dictionary:
	if STEPS.has(step_id):
		return STEPS[step_id]
	var element := step_id.trim_prefix("elemento_")
	if not step_id.begins_with("elemento_") or not ELEMENT_TIPS.has(element):
		return {}
	var tip: Dictionary = ELEMENT_TIPS[element]
	var text := "Aperte %d ou clique no icone para usar. %s %s" % [tip["key"], element, tip["effect"]]
	var weak_elements := PackedStringArray()
	for weak_element in String(main_controller.player.element_advantages.get(element, "")).split(","):
		if weak_element.strip_edges() != "":
			weak_elements.append(weak_element.strip_edges())
	if weak_elements.is_empty():
		text += "."
	else:
		text += " e causa dano extra em inimigos de %s." % join_names(weak_elements)
	return {"title": "Novo elemento: %s" % element, "text": text, "highlight": [step_id]}

# "Fogo", "Fogo e Terra", "Fogo, Terra e Ar".
func join_names(names: PackedStringArray) -> String:
	if names.size() <= 1:
		return "".join(names)
	return "%s e %s" % [", ".join(names.slice(0, names.size() - 1)), names[names.size() - 1]]

func show_step(step_id: String, step: Dictionary) -> void:
	current_step = step_id
	seen[step_id] = true
	for feature in step.get("reveal", []):
		revealed[feature] = true
	if FEATURES.all(func(feature: String) -> bool: return revealed.get(feature, false)):
		completed = true
	title_label.text = step.get("title", "")
	text_label.text = step.get("text", "")
	primary_button.text = step.get("button", DEFAULT_BUTTON)
	secondary_button.text = step.get("secondary", "")
	secondary_button.visible = step.has("secondary")
	reset_size()
	was_paused = get_tree().paused
	get_tree().paused = true
	visible = true
	primary_button.grab_focus()
	main_controller.update_hud()
	main_controller.save_progress()
	main_controller.update_debug()
	var targets: Array[Control] = []
	for key in step.get("reveal", []) + step.get("highlight", []):
		targets.append_array(main_controller.get_tutorial_targets(key))
	pulse(targets, 0)

func close_message() -> void:
	if not visible or not is_inside_tree():
		return
	visible = false
	current_step = ""
	stop_pulse()
	get_tree().paused = was_paused
	main_controller.update_hud()
	main_controller.update_debug()
	call_deferred("try_show_next")

func _on_primary_pressed() -> void:
	var opens_shop := current_step.begins_with("loja")
	close_message()
	if opens_shop:
		main_controller.open_shop()

# loops = 0 pulsa ate a dica fechar. O tween e deste painel, entao roda mesmo com o jogo pausado.
func pulse(targets: Array[Control], loops: int) -> void:
	stop_pulse()
	for target in targets:
		if is_instance_valid(target) and target.visible:
			target.pivot_offset = target.size / 2.0
			pulsing.append(target)
	if pulsing.is_empty():
		return
	pulse_tween = create_tween().set_loops(loops).set_trans(Tween.TRANS_SINE)
	for target_scale in [PULSE_SCALE, Vector2.ONE]:
		for index in pulsing.size():
			if index > 0:
				pulse_tween.parallel()
			pulse_tween.tween_property(pulsing[index], "scale", target_scale, PULSE_TIME)

func stop_pulse() -> void:
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()
	for target in pulsing:
		if is_instance_valid(target):
			target.scale = Vector2.ONE
	pulsing.clear()

# Pula o tutorial: libera toda a HUD e marca todas as dicas como vistas.
func complete() -> void:
	close_message()
	pending.clear()
	completed = true
	for feature in FEATURES:
		revealed[feature] = true
	for step_id in STEPS:
		seen[step_id] = true
	for element in ELEMENT_TIPS:
		seen["elemento_" + element] = true

func reset_state() -> void:
	visible = false
	stop_pulse()
	current_step = ""
	pending.clear()
	revealed.clear()
	seen.clear()
	completed = false

func write_save(progress: ConfigFile) -> void:
	progress.set_value("tutorial", "completed", completed)
	progress.set_value("tutorial", "revealed", revealed.keys())
	progress.set_value("tutorial", "seen", seen.keys())

func read_save(progress: ConfigFile) -> void:
	reset_state()
	completed = bool(progress.get_value("tutorial", "completed", false))
	var saved_revealed: Variant = progress.get_value("tutorial", "revealed", [])
	if saved_revealed is Array:
		for feature in saved_revealed:
			if FEATURES.has(str(feature)):
				revealed[str(feature)] = true
	var saved_seen: Variant = progress.get_value("tutorial", "seen", [])
	if saved_seen is Array:
		for step_id in saved_seen:
			seen[str(step_id)] = true
