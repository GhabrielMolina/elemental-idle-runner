extends PanelContainer

var main_controller: Node
var state_label: Label
var speed_label: Label
var pause_button: Button
var speed_button: Button

func setup(controller: Node) -> void:
	main_controller = controller
	build_interface()

func build_interface() -> void:
	custom_minimum_size = Vector2(250, 0)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)
	var title := Label.new()
	title.text = "PAINEL DE DEBUG"
	title.add_theme_color_override("font_color", Color("#f3c969"))
	column.add_child(title)
	state_label = Label.new()
	column.add_child(state_label)
	speed_label = Label.new()
	column.add_child(speed_label)
	pause_button = Button.new()
	pause_button.custom_minimum_size = Vector2(220, 34)
	pause_button.pressed.connect(main_controller.toggle_pause)
	column.add_child(pause_button)
	speed_button = Button.new()
	speed_button.custom_minimum_size = Vector2(220, 34)
	speed_button.text = "Velocidade: 1×"
	speed_button.pressed.connect(main_controller.cycle_speed)
	column.add_child(speed_button)
	var spawn_button := Button.new()
	spawn_button.text = "Gerar inimigo"
	spawn_button.pressed.connect(main_controller.debug_spawn_enemy)
	column.add_child(spawn_button)
	var reset_button := Button.new()
	reset_button.text = "Reiniciar partida"
	reset_button.pressed.connect(main_controller.restart_game)
	column.add_child(reset_button)
	var hint := Label.new()
	hint.text = "F1 abre/fecha este painel"
	hint.add_theme_color_override("font_color", Color("#a7a39a"))
	column.add_child(hint)
	visible = false

func update_display(state: String, speed: float, is_paused: bool) -> void:
	if not is_instance_valid(state_label):
		return
	state_label.text = "Estado: " + state
	speed_label.text = "Simulacao: " + str(int(speed)) + "×"
	speed_button.text = "Velocidade: " + str(int(speed)) + "×"
	pause_button.text = "Continuar" if is_paused else "Pausar"

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		visible = not visible
		get_viewport().set_input_as_handled()
