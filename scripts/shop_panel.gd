extends PanelContainer

const UpgradeCatalog := preload("res://scripts/upgrade_catalog.gd")
const SECTIONS := ["Fogo", "Agua", "Terra", "Ar", "Geral"]
const DEFAULT_DETAIL := "Passe o mouse sobre uma melhoria para ver os detalhes."

var main_controller: Node
var player: Node2D
var was_paused := false
var section_labels: Dictionary[String, Label] = {}
var upgrade_buttons: Dictionary[String, Button] = {}
var detail_label: Label

func setup(controller: Node, player_node: Node2D) -> void:
	main_controller = controller
	player = player_node
	build_interface()

func build_interface() -> void:
	position = Vector2(58, 30)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#162d42", 0.97)
	style.border_color = Color("#f3c969")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var title := Label.new()
	title.text = "LOJA DE MELHORIAS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#f3c969"))
	column.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	column.add_child(grid)
	for section in SECTIONS:
		var header := Label.new()
		header.custom_minimum_size = Vector2(150, 0)
		header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		header.add_theme_color_override("font_color", get_section_color(section))
		grid.add_child(header)
		section_labels[section] = header
		for id in UpgradeCatalog.get_for_element(section):
			var button := Button.new()
			button.custom_minimum_size = Vector2(212, 52)
			button.pressed.connect(_on_upgrade_pressed.bind(id))
			button.mouse_entered.connect(show_details.bind(id))
			button.focus_entered.connect(show_details.bind(id))
			grid.add_child(button)
			upgrade_buttons[id] = button
	detail_label = Label.new()
	detail_label.custom_minimum_size = Vector2(0, 66)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(detail_label)
	var hint := Label.new()
	hint.text = "P ou Esc fecha   |   Gerais usam o XP somado dos elementos (desconta do maior primeiro)"
	hint.add_theme_color_override("font_color", Color("#a7a39a"))
	column.add_child(hint)
	visible = false

func get_section_color(section: String) -> Color:
	match section:
		"Fogo": return Color("#ef654f")
		"Agua": return Color("#4bbbd8")
		"Terra": return Color("#c8925f")
		"Ar": return Color("#a6dfe8")
	return Color("#f3c969")

func refresh() -> void:
	if player == null:
		return
	for section in SECTIONS:
		var text := ""
		if section == UpgradeCatalog.GENERAL:
			text = "Geral\n%d XP (soma)" % player.get_total_element_xp()
		elif player.is_element_unlocked(section):
			text = "%s\n%d XP" % [section, player.get_element_xp(section)]
		else:
			text = "%s\nBloqueado (Nv%d)" % [section, player.get_element_unlock_level(section)]
		section_labels[section].text = text
	for id in upgrade_buttons:
		var level: int = player.get_upgrade_level(id)
		var status := "MAX"
		if not player.is_upgrade_unlocked(id):
			status = "Bloqueado"
		elif level < UpgradeCatalog.MAX_LEVEL:
			status = "%d XP" % player.get_upgrade_cost(id)
		upgrade_buttons[id].text = "%s  Nv %d/%d\n%s" % [UpgradeCatalog.get_upgrade_name(id), level, UpgradeCatalog.MAX_LEVEL, status]
		upgrade_buttons[id].disabled = not player.can_purchase(id)

func show_details(id: String) -> void:
	var level: int = player.get_upgrade_level(id)
	var current := UpgradeCatalog.describe(id, level) if level > 0 else "nao comprado"
	var next := UpgradeCatalog.describe(id, level + 1) if level < UpgradeCatalog.MAX_LEVEL else "nivel maximo"
	detail_label.text = "%s\nAtual: %s\nProximo: %s" % [UpgradeCatalog.get_upgrade_name(id), current, next]

func _on_upgrade_pressed(id: String) -> void:
	if player.purchase(id):
		main_controller.update_hud()
		show_details(id)

func open() -> void:
	was_paused = get_tree().paused
	get_tree().paused = true
	visible = true
	detail_label.text = DEFAULT_DETAIL
	refresh()
	main_controller.update_debug()

func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = was_paused
	main_controller.update_hud()
	main_controller.update_debug()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_P:
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and visible:
		close()
		get_viewport().set_input_as_handled()
