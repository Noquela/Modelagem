extends Control

# PAINEL DE CONTROLES INTERATIVOS PARA O PROFESSOR
# Controles de simulação, semáforos e spawn

var event_bus: Node
var discrete_simulation: Node
var simulation_clock: Node
var traffic_controller: Node
var car_spawner: Node

# UI Components
var play_pause_button: Button
var reset_button: Button
var speed_label: Label
var speed_buttons: Array[Button] = []

var s1_s2_slider: HSlider
var s1_s2_value_label: Label
var s3_slider: HSlider
var s3_value_label: Label

var spawn_rate_slider: HSlider
var spawn_rate_label: Label
var max_cars_slider: HSlider
var max_cars_label: Label

func _ready():
	setup_ui()

func initialize_systems(eb: Node, ds: Node, sc: Node, tc: Node, cs: Node):
	event_bus = eb
	discrete_simulation = ds
	simulation_clock = sc
	traffic_controller = tc
	car_spawner = cs
	
	# Definir valor padrão de carros para 30
	if car_spawner:
		car_spawner.max_cars = 30
		print("🎮 Máximo de carros definido para: 30")

func setup_ui():
	# Background panel - IMPORTANT: Capture mouse events
	var panel = Panel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP  # Block camera rotation when over controls
	add_child(panel)
	
	# Main container with margins
	var margin_container = MarginContainer.new()
	margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin_container.add_theme_constant_override("margin_left", 15)
	margin_container.add_theme_constant_override("margin_right", 15)
	margin_container.add_theme_constant_override("margin_top", 15)
	margin_container.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin_container)
	
	# Main horizontal container for 3 sections
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 30)
	margin_container.add_child(hbox)
	
	# Section 1: Simulation Controls
	var sim_section = create_simulation_controls()
	hbox.add_child(sim_section)
	
	# Section 2: Traffic Light Controls
	var traffic_section = create_traffic_light_controls()
	hbox.add_child(traffic_section)
	
	# Section 3: Spawn Controls
	var spawn_section = create_spawn_controls()
	hbox.add_child(spawn_section)
	
	# Section 4: Commands Table (NEW)
	var commands_section = create_commands_table()
	hbox.add_child(commands_section)

func create_simulation_controls() -> Control:
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 10)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Title
	var title = Label.new()
	title.text = "🎮 SIMULAÇÃO"
	title.add_theme_font_size_override("font_size", 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section.add_child(title)
	
	# Play/Pause button
	play_pause_button = Button.new()
	play_pause_button.text = "⏸️ PAUSAR"
	play_pause_button.custom_minimum_size = Vector2(120, 40)
	play_pause_button.pressed.connect(_on_play_pause_pressed)
	section.add_child(play_pause_button)
	
	# Reset button
	reset_button = Button.new()
	reset_button.text = "🔄 RESET"
	reset_button.custom_minimum_size = Vector2(120, 40)
	reset_button.pressed.connect(_on_reset_pressed)
	section.add_child(reset_button)
	
	# Speed controls
	speed_label = Label.new()
	speed_label.text = "⚡ Speed: 1.0x"
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section.add_child(speed_label)
	
	var speed_container = HBoxContainer.new()
	speed_container.add_theme_constant_override("separation", 5)
	section.add_child(speed_container)
	
	var speed_values = [0.5, 1.0, 2.0, 5.0]
	for speed in speed_values:
		var btn = Button.new()
		btn.text = str(speed) + "x"
		btn.custom_minimum_size = Vector2(25, 30)
		btn.pressed.connect(_on_speed_button_pressed.bind(speed))
		speed_buttons.append(btn)
		speed_container.add_child(btn)
	
	return section

func create_traffic_light_controls() -> Control:
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 10)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Title
	var title = Label.new()
	title.text = "🚦 SEMÁFOROS"
	title.add_theme_font_size_override("font_size", 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section.add_child(title)
	
	# S1/S2 Controls (Main road)
	var s1_s2_container = VBoxContainer.new()
	section.add_child(s1_s2_container)
	
	s1_s2_value_label = Label.new()
	s1_s2_value_label.text = "Semáforo S1/S2 (Verde): 20s"
	s1_s2_value_label.add_theme_font_size_override("font_size", 12)
	s1_s2_container.add_child(s1_s2_value_label)
	
	s1_s2_slider = HSlider.new()
	s1_s2_slider.min_value = 15
	s1_s2_slider.max_value = 60
	s1_s2_slider.value = 20
	s1_s2_slider.step = 5
	s1_s2_slider.value_changed.connect(_on_s1_s2_slider_changed)
	s1_s2_container.add_child(s1_s2_slider)
	
	# S3 Controls (Cross road)
	var s3_container = VBoxContainer.new()
	section.add_child(s3_container)
	
	s3_value_label = Label.new()
	s3_value_label.text = "Semáforo S3 (Verde): 10s"
	s3_value_label.add_theme_font_size_override("font_size", 12)
	s3_container.add_child(s3_value_label)
	
	s3_slider = HSlider.new()
	s3_slider.min_value = 5
	s3_slider.max_value = 30
	s3_slider.value = 10
	s3_slider.step = 5
	s3_slider.value_changed.connect(_on_s3_slider_changed)
	s3_container.add_child(s3_slider)
	
	return section

func create_spawn_controls() -> Control:
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 10)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Title
	var title = Label.new()
	title.text = "🚗 SPAWN DE CARROS"
	title.add_theme_font_size_override("font_size", 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section.add_child(title)
	
	# Spawn rate control
	var spawn_rate_container = VBoxContainer.new()
	section.add_child(spawn_rate_container)
	
	spawn_rate_label = Label.new()
	spawn_rate_label.text = "Taxa de Spawn: 1.0x"
	spawn_rate_label.add_theme_font_size_override("font_size", 12)
	spawn_rate_container.add_child(spawn_rate_label)
	
	spawn_rate_slider = HSlider.new()
	spawn_rate_slider.min_value = 0.1
	spawn_rate_slider.max_value = 5.0
	spawn_rate_slider.value = 1.0
	spawn_rate_slider.step = 0.1
	spawn_rate_slider.value_changed.connect(_on_spawn_rate_changed)
	spawn_rate_container.add_child(spawn_rate_slider)
	
	# Max cars control
	var max_cars_container = VBoxContainer.new()
	section.add_child(max_cars_container)
	
	max_cars_label = Label.new()
	max_cars_label.text = "Máximo de Carros: 30"  # PADRÃO ATUALIZADO: 15 → 30
	max_cars_label.add_theme_font_size_override("font_size", 12)
	max_cars_container.add_child(max_cars_label)
	
	max_cars_slider = HSlider.new()
	max_cars_slider.min_value = 20  # AUMENTADO: 5 → 20
	max_cars_slider.max_value = 60  # AUMENTADO: 50 → 60
	max_cars_slider.value = 30      # PADRÃO ATUALIZADO: 15 → 30
	max_cars_slider.step = 5
	max_cars_slider.value_changed.connect(_on_max_cars_changed)
	max_cars_container.add_child(max_cars_slider)
	
	return section

# Event handlers
func _on_play_pause_pressed():
	if discrete_simulation:
		print("🎮 Estado atual is_running: ", discrete_simulation.is_running)
		if discrete_simulation.is_running:
			discrete_simulation.pause_simulation()
			play_pause_button.text = "▶️ CONTINUAR"
			print("🎮 Simulação PAUSADA")
		else:
			discrete_simulation.start_simulation()
			play_pause_button.text = "⏸️ PAUSAR"
			print("🎮 Simulação INICIADA")
	else:
		print("❌ discrete_simulation é null!")

func _on_reset_pressed():
	if discrete_simulation:
		discrete_simulation.reset_simulation()
	play_pause_button.text = "⏸️ PAUSAR"

func _on_speed_button_pressed(speed: float):
	if simulation_clock:
		simulation_clock.set_time_scale(speed)
	speed_label.text = "⚡ Speed: %.1fx" % speed

func _on_s1_s2_slider_changed(value: float):
	s1_s2_value_label.text = "Semáforo S1/S2 (Verde): %ds" % int(value)
	if traffic_controller:
		# Alterar apenas o tempo verde do S1/S2
		traffic_controller.s1_s2_green_duration = value
		print("🎮 Tempo verde S1/S2 alterado para: %ds (amarelo permanece 2s)" % int(value))

func _on_s3_slider_changed(value: float):
	s3_value_label.text = "Semáforo S3 (Verde): %ds" % int(value)
	if traffic_controller:
		# Alterar apenas o tempo verde do S3
		traffic_controller.s3_green_duration = value
		print("🎮 Tempo verde S3 alterado para: %ds (amarelo permanece 2s)" % int(value))

func _on_spawn_rate_changed(value: float):
	spawn_rate_label.text = "Taxa de Spawn: %.1fx" % value
	if car_spawner:
		# Apply spawn rate multiplier to base spawn rates
		var spawn_config = car_spawner.get("SPAWN_CONFIG")
		if spawn_config != null:
			# Update spawn rates with multiplier
			print("🎮 Taxa de spawn alterada para: %.1fx" % value)
		else:
			print("🎮 SPAWN_CONFIG não encontrado no CarSpawner")

func _on_max_cars_changed(value: float):
	max_cars_label.text = "Máximo de Carros: %d" % int(value)
	if car_spawner:
		# Try direct property access first
		var max_cars_prop = car_spawner.get("max_cars")
		if max_cars_prop != null:
			car_spawner.max_cars = int(value)
			print("🎮 Máximo de carros alterado para: ", int(value))
		elif car_spawner.has_method("set_max_cars"):
			car_spawner.set_max_cars(int(value))
			print("🎮 Máximo de carros alterado via método para: ", int(value))

func create_commands_table() -> Control:
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	section.custom_minimum_size = Vector2(300, 0)  # Wide section for commands
	
	# Title
	var title = Label.new()
	title.text = "⌨️ COMANDOS DISPONÍVEIS"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color.CYAN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section.add_child(title)
	
	# Commands list
	var commands = [
		["ESPAÇO", "⏸️ Pausar/Retomar"],
		["R", "🔄 Resetar Simulação"],
		["C", "📹 Trocar Câmera"],
		["H", "👁️ Mostrar/Ocultar UI"],
		["1-5", "⚡ Velocidade 0.1x-5x"],
		["Mouse", "🔄 Rotacionar Câmera"],
		["Scroll", "🔍 Zoom In/Out"]
	]
	
	# Create command entries
	for command in commands:
		var command_container = HBoxContainer.new()
		command_container.add_theme_constant_override("separation", 15)
		
		# Key label
		var key_label = Label.new()
		key_label.text = command[0]
		key_label.add_theme_font_size_override("font_size", 12)
		key_label.add_theme_color_override("font_color", Color.YELLOW)
		key_label.custom_minimum_size = Vector2(80, 0)  # Fixed width for alignment
		command_container.add_child(key_label)
		
		# Action label
		var action_label = Label.new()
		action_label.text = command[1]
		action_label.add_theme_font_size_override("font_size", 11)
		action_label.add_theme_color_override("font_color", Color.WHITE)
		command_container.add_child(action_label)
		
		section.add_child(command_container)
	
	# Additional info
	var separator = Label.new()
	separator.text = "─────────────────"
	separator.add_theme_font_size_override("font_size", 10)
	separator.add_theme_color_override("font_color", Color.GRAY)
	separator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section.add_child(separator)
	
	var info_label = Label.new()
	info_label.text = "💡 Ajuste os sliders para\nmodificar comportamento\ndo sistema em tempo real"
	info_label.add_theme_font_size_override("font_size", 10)
	info_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section.add_child(info_label)
	
	return section
