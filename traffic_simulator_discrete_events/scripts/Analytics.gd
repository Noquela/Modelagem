extends Control

# ADAPTADO PARA EVENTOS DISCRETOS

# UI Labels will be created programmatically
var fps_label: Label
var cars_label: Label 
var throughput_label: Label
var time_label: Label

# Novas estatísticas descritivas
var avg_wait_label: Label
var total_spawned_label: Label  
var cars_passed_label: Label
var speed_avg_label: Label
var queue_length_label: Label

# Labels das personalidades
var aggressive_label: Label
var conservative_label: Label
var elderly_label: Label
var normal_label: Label

# Chart data
var throughput_history: Array[float] = []
var congestion_history: Array[float] = []
var max_history_size: int = 300  # 5 minutes at 60 FPS

# UI Elements
var stats_panel: Panel
var throughput_chart: Control
var personality_breakdown: Control

func _ready():
	create_ui_elements()
	set_process(true)

func create_ui_elements():
	# Create modern dashboard layout
	create_modern_dashboard()

func create_styled_panel(bg_color: Color) -> Panel:
	# Create a panel with custom background color
	var panel = Panel.new()
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = bg_color
	panel.add_theme_stylebox_override("panel", style_box)
	return panel

var ui_visible: bool = true

func create_modern_dashboard():
	create_controls_panel()  # NOVA: Painel de controles interativos
	# Create compact UI that doesn't block game view
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_mouse_filter(Control.MOUSE_FILTER_IGNORE)  # Let clicks pass through
	
	# Create compact stats overlay (top-left)
	create_compact_stats_overlay()
	
	# Add toggle instruction
	create_toggle_instruction()

func create_compact_stats_overlay():
	var stats_overlay = create_styled_panel(Color(0.05, 0.05, 0.08, 0.9))
	stats_overlay.name = "StatsOverlay"
	stats_overlay.position = Vector2(10, 10)
	stats_overlay.size = Vector2(350, 360)  # Aumentado para melhor acomodar todas as seções
	stats_overlay.set_mouse_filter(Control.MOUSE_FILTER_STOP)  # This panel captures mouse
	add_child(stats_overlay)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 3)
	stats_overlay.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "🚦 Traffic Simulator 3D - Analytics"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color.CYAN)
	vbox.add_child(title)
	
	# Seção: Sistema
	create_section_header("⚙️ Sistema", Color.YELLOW, vbox)
	fps_label = create_compact_stat("FPS", "60", Color.LIME_GREEN, vbox)
	time_label = create_compact_stat("Tempo Sim", "00:00", Color.LIGHT_BLUE, vbox)
	
	# Seção: Veículos  
	create_section_header("🚗 Veículos", Color.ORANGE, vbox)
	cars_label = create_compact_stat("Ativos", "0", Color.ORANGE, vbox)
	total_spawned_label = create_compact_stat("Total Criados", "0", Color.LIGHT_GRAY, vbox)
	cars_passed_label = create_compact_stat("Passaram", "0", Color.GREEN, vbox)
	
	# Seção: Tráfego
	create_section_header("📊 Desempenho do Tráfego", Color.GREEN, vbox)
	throughput_label = create_compact_stat("Throughput", "0.0/s", Color.GREEN, vbox)
	avg_wait_label = create_compact_stat("Esp. Média", "0.0s", Color.YELLOW, vbox)
	speed_avg_label = create_compact_stat("Vel. Média", "0.0 km/h", Color.CYAN, vbox)
	
	# Seção: Congestionamento
	create_section_header("🚥 Congestionamento", Color.RED, vbox)
	queue_length_label = create_compact_stat("Fila Máx", "0", Color.ORANGE, vbox)
	
	# Seção: Personalidades dos Motoristas
	create_section_header("👥 Personalidades", Color.PURPLE, vbox)
	aggressive_label = create_compact_stat("Agressivos", "0", Color.RED, vbox)
	normal_label = create_compact_stat("Normais", "0", Color.WHITE, vbox)
	conservative_label = create_compact_stat("Conservadores", "0", Color.BLUE, vbox)
	elderly_label = create_compact_stat("Idosos", "0", Color.GRAY, vbox)

func create_compact_stat(label_text: String, value_text: String, color: Color, parent: VBoxContainer) -> Label:
	var hbox = HBoxContainer.new()
	parent.add_child(hbox)
	
	var label = Label.new()
	label.text = label_text + ":"
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.custom_minimum_size.x = 80
	hbox.add_child(label)
	
	var value_label = Label.new()
	value_label.text = value_text
	value_label.add_theme_font_size_override("font_size", 11)
	value_label.add_theme_color_override("font_color", color)
	hbox.add_child(value_label)
	
	return value_label

func create_section_header(text: String, color: Color, parent: VBoxContainer):
	var header = Label.new()
	header.text = text
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", color)
	parent.add_child(header)

func create_toggle_instruction():
	var instruction = Label.new()
	instruction.text = "Press [H] to hide/show stats"
	instruction.position = Vector2(10, 385)  # Ajustado para ficar bem abaixo do painel de 360px + margem
	instruction.add_theme_font_size_override("font_size", 10)
	instruction.add_theme_color_override("font_color", Color.GRAY)
	add_child(instruction)

func create_stats_sidebar():
	var sidebar = create_styled_panel(Color(0.08, 0.08, 0.1, 0.9))
	sidebar.name = "StatsSidebar"
	sidebar.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	sidebar.offset_top = 60  # Below top bar
	sidebar.size.x = 300
	add_child(sidebar)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	sidebar.add_child(vbox)
	
	# Section title
	var section_title = Label.new()
	section_title.text = "📊 Live Statistics"
	section_title.add_theme_font_size_override("font_size", 18)
	section_title.add_theme_color_override("font_color", Color.CYAN)
	vbox.add_child(section_title)
	
	# Create metric cards
	cars_label = create_metric_card("🚗 Active Cars", "0", Color.ORANGE, vbox)
	throughput_label = create_metric_card("⚡ Throughput", "0.0 cars/sec", Color.GREEN, vbox)
	time_label = create_metric_card("⏱️ Sim Time", "00:00", Color.LIGHT_BLUE, vbox)

func create_metric_card(title: String, value: String, color: Color, parent: VBoxContainer) -> Label:
	var card = create_styled_panel(Color(0.12, 0.12, 0.15, 0.8))
	card.custom_minimum_size.y = 60
	parent.add_child(card)
	
	var card_vbox = VBoxContainer.new()
	card_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(card_vbox)
	
	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	card_vbox.add_child(title_label)
	
	var value_label = Label.new()
	value_label.text = value
	value_label.add_theme_font_size_override("font_size", 18)
	value_label.add_theme_color_override("font_color", color)
	card_vbox.add_child(value_label)
	
	return value_label

func create_controls_panel():
	var controls = create_styled_panel(Color(0.08, 0.08, 0.1, 0.9))
	controls.name = "ControlsPanel"
	controls.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	controls.offset_top = 60
	controls.size = Vector2(250, 200)
	add_child(controls)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controls.add_child(vbox)
	
	var controls_title = Label.new()
	controls_title.text = "⚙️ Simulation Controls"
	controls_title.add_theme_font_size_override("font_size", 16)
	controls_title.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(controls_title)
	
	# Placeholder for future controls
	var status_label = Label.new()
	status_label.text = "Status: Running"
	status_label.add_theme_color_override("font_color", Color.LIME_GREEN)
	vbox.add_child(status_label)

func create_charts_area():
	var charts = create_styled_panel(Color(0.08, 0.08, 0.1, 0.9))
	charts.name = "ChartsArea"
	charts.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	charts.offset_top = -200
	charts.size.y = 200
	add_child(charts)
	
	var charts_title = Label.new()
	charts_title.text = "📈 Real-time Analytics"
	charts_title.position = Vector2(10, 10)
	charts_title.add_theme_font_size_override("font_size", 16)
	charts_title.add_theme_color_override("font_color", Color.MAGENTA)
	charts.add_child(charts_title)

func create_control_panel(parent: VBoxContainer):
	var control_panel = Panel.new()
	control_panel.name = "ControlPanel"
	control_panel.custom_minimum_size = Vector2(300, 80)
	parent.add_child(control_panel)
	
	var hbox = HBoxContainer.new()
	control_panel.add_child(hbox)
	
	# Pause button
	var pause_button = Button.new()
	pause_button.text = "Pause/Resume"
	pause_button.pressed.connect(_on_pause_pressed)
	hbox.add_child(pause_button)
	
	# Camera mode button
	var camera_button = Button.new()
	camera_button.text = "Camera Mode"
	camera_button.pressed.connect(_on_camera_mode_pressed)
	hbox.add_child(camera_button)
	
	# Spawn rate slider
	var spawn_label = Label.new()
	spawn_label.text = "Spawn Rate:"
	hbox.add_child(spawn_label)
	
	var spawn_slider = HSlider.new()
	spawn_slider.min_value = 0.1
	spawn_slider.max_value = 3.0
	spawn_slider.value = 1.0
	spawn_slider.step = 0.1
	spawn_slider.value_changed.connect(_on_spawn_rate_changed)
	hbox.add_child(spawn_slider)

func create_charts_panel(parent: VBoxContainer):
	var charts_panel = Panel.new()
	charts_panel.name = "ChartsPanel"
	charts_panel.custom_minimum_size = Vector2(400, 200)
	parent.add_child(charts_panel)
	
	throughput_chart = Control.new()
	throughput_chart.name = "ThroughputChart"
	throughput_chart.custom_minimum_size = Vector2(380, 180)
	charts_panel.add_child(throughput_chart)

func create_personality_panel(parent: VBoxContainer):
	personality_breakdown = Panel.new()
	personality_breakdown.name = "PersonalityPanel"
	personality_breakdown.custom_minimum_size = Vector2(300, 150)
	parent.add_child(personality_breakdown)
	
	var personality_label = Label.new()
	personality_label.text = "Driver Personalities Distribution"
	personality_label.position = Vector2(10, 10)
	personality_breakdown.add_child(personality_label)

func update_display(stats: Dictionary):
	# Update modern dashboard metrics
	if fps_label:
		fps_label.text = "%.0f" % stats.get("fps", 60.0)
	
	if cars_label:
		cars_label.text = "%d" % stats.get("active_cars", 0)
	
	if throughput_label:
		throughput_label.text = "%.1f/s" % stats.get("throughput", 0.0)
	
	
	if time_label:
		var sim_time = stats.get("simulation_time", 0.0)
		var minutes = int(sim_time / 60)
		var seconds = int(sim_time) % 60
		time_label.text = "%02d:%02d" % [minutes, seconds]
	
	# Novas estatísticas descritivas
	if total_spawned_label:
		total_spawned_label.text = "%d" % stats.get("total_cars_spawned", 0)
		
	if cars_passed_label:
		cars_passed_label.text = "%d" % stats.get("cars_passed_through", 0)
		
	if avg_wait_label:
		avg_wait_label.text = "%.1fs" % stats.get("average_wait_time", 0.0)
		
	if speed_avg_label:
		var avg_speed = stats.get("average_speed", 0.0) * 3.6  # m/s para km/h
		speed_avg_label.text = "%.1f km/h" % avg_speed
		
	if queue_length_label:
		queue_length_label.text = "%d" % stats.get("max_queue_length", 0)
		
	# Atualizar personalidades dos motoristas
	var personality_stats = stats.get("personality_stats", {})
	if aggressive_label:
		aggressive_label.text = "%d" % personality_stats.get("Aggressive", 0)
	if normal_label:
		normal_label.text = "%d" % personality_stats.get("Normal", 0)
	if conservative_label:
		conservative_label.text = "%d" % personality_stats.get("Conservative", 0)
	if elderly_label:
		elderly_label.text = "%d" % personality_stats.get("Elderly", 0)
	
	# Update chart data
	update_chart_data(stats)

func update_chart_data(stats: Dictionary):
	# Add to history arrays
	throughput_history.append(stats.get("throughput", 0.0))
	congestion_history.append(stats.get("congestion", 0.0))
	
	# Limit history size
	if throughput_history.size() > max_history_size:
		throughput_history.pop_front()
		congestion_history.pop_front()
	
	# Redraw charts
	if throughput_chart:
		throughput_chart.queue_redraw()

func _draw():
	if not throughput_chart or throughput_history.is_empty():
		return
	
	draw_throughput_chart()

func draw_throughput_chart():
	var chart_rect = throughput_chart.get_rect()
	var canvas_item = throughput_chart.get_canvas_item()
	
	# Clear background
	RenderingServer.canvas_item_add_rect(canvas_item, chart_rect, Color(0.1, 0.1, 0.1, 0.8))
	
	# Draw grid
	var grid_color = Color(0.3, 0.3, 0.3, 0.5)
	for i in range(5):
		var y = chart_rect.position.y + (chart_rect.size.y / 4) * i
		RenderingServer.canvas_item_add_line(canvas_item, 
			Vector2(chart_rect.position.x, y),
			Vector2(chart_rect.position.x + chart_rect.size.x, y),
			grid_color, 1.0)
	
	# Draw throughput line
	if throughput_history.size() > 1:
		var max_throughput = throughput_history.max()
		if max_throughput > 0:
			var points = PackedVector2Array()
			for i in range(throughput_history.size()):
				var x = chart_rect.position.x + (chart_rect.size.x / throughput_history.size()) * i
				var normalized_value = throughput_history[i] / max_throughput
				var y = chart_rect.position.y + chart_rect.size.y - (normalized_value * chart_rect.size.y)
				points.append(Vector2(x, y))
			
			# Draw line segments
			for i in range(points.size() - 1):
				RenderingServer.canvas_item_add_line(canvas_item, points[i], points[i + 1], Color.GREEN, 2.0)

func _on_pause_pressed():
	var traffic_manager = get_tree().get_first_node_in_group("traffic_manager")
	if traffic_manager and traffic_manager.has_method("pause_simulation"):
		traffic_manager.pause_simulation()

func _on_camera_mode_pressed():
	var camera_controller = get_tree().get_first_node_in_group("camera_controller")
	if camera_controller and camera_controller.has_method("cycle_camera_mode"):
		camera_controller.cycle_camera_mode()

func _on_spawn_rate_changed(value: float):
	var spawn_system = get_tree().get_first_node_in_group("spawn_system")
	if spawn_system and spawn_system.has_method("adjust_spawn_rate"):
		spawn_system.adjust_spawn_rate(value)

func get_personality_stats() -> Dictionary:
	var cars = get_tree().get_nodes_in_group("cars")
	var personality_counts = {
		"Aggressive": 0,
		"Conservative": 0,
		"Normal": 0,
		"Elderly": 0
	}
	
	for car in cars:
		if car.has_method("get_personality_string"):
			var personality = car.get_personality_string()
			if personality in personality_counts:
				personality_counts[personality] += 1
	
	return personality_counts

# FUNÇÃO PARA EVENTOS DISCRETOS
func update_discrete_event_stats(simulador: SimuladorTrafego):
	if not simulador or not simulador.gerenciador_eventos:
		return
	
	var stats = simulador.estatisticas
	var gerenciador = simulador.gerenciador_eventos
	
	# Atualizar labels com dados de eventos discretos
	if fps_label:
		fps_label.text = "Simulation Time: %.1f min" % (gerenciador.tempo_simulacao / 60.0)
	
	if cars_label:
		cars_label.text = "Cars in System: %d" % simulador.ambiente.obter_quantidade_carros_ativos()
	
	if throughput_label:
		var throughput = 0.0
		if gerenciador.tempo_simulacao > 0:
			throughput = stats.carros_atendidos / (gerenciador.tempo_simulacao / 60.0)
		throughput_label.text = "Throughput: %.1f cars/min" % throughput
	
	if time_label:
		time_label.text = "Events Processed: %d" % (stats.carros_chegados + stats.carros_atendidos)
	
	if avg_wait_label:
		avg_wait_label.text = "Avg Wait Time: %.1f s" % stats.tempo_espera_medio
	
	if total_spawned_label:
		total_spawned_label.text = "Total Spawned: %d" % stats.carros_chegados
	
	if cars_passed_label:
		cars_passed_label.text = "Cars Passed: %d" % stats.carros_atendidos
	
	if speed_avg_label:
		speed_avg_label.text = "Simulation Speed: %.1fx" % gerenciador.velocidade_simulacao
	
	if queue_length_label:
		queue_length_label.text = "Queue Length: %d (max: %d)" % [stats.carros_na_fila, stats.tamanho_fila_max]
	
	# Atualizar gráfico de throughput
	if Engine.get_process_frames() % 60 == 0:  # A cada segundo
		var current_throughput = 0.0
		if gerenciador.tempo_simulacao > 0:
			current_throughput = stats.carros_atendidos / (gerenciador.tempo_simulacao / 60.0)
		throughput_history.append(current_throughput)
		if throughput_history.size() > max_history_size:
			throughput_history.pop_front()
		update_chart_data({})

func update_personality_display():
	# EVENTOS DISCRETOS: Mostrar distribuições de frequência
	if personality_breakdown:
		# Clear existing children (except label)
		var children = personality_breakdown.get_children()
		for i in range(1, children.size()):
			children[i].queue_free()
		
		# Mostrar distribuições de frequência
		var y_offset = 40
		
		# Título
		var titulo_dist = Label.new()
		titulo_dist.text = "📊 DISTRIBUIÇÕES DE FREQUÊNCIA"
		titulo_dist.position = Vector2(10, y_offset)
		titulo_dist.add_theme_font_size_override("font_size", 12)
		personality_breakdown.add_child(titulo_dist)
		y_offset += 30
		
		# Informações das distribuições
		var dist_info = [
			"🚗 Chegadas: Distribuição EXPONENCIAL",
			"⏱️ Intervalo: λ = 1.5-4.0 carros/min",
			"📈 Taxa varia: Distribuição UNIFORME",
			"🎯 Direções:",
			"   • West→East: 45%",
			"   • East→West: 40%", 
			"   • South→North: 15%",
			"🚦 Semáforo: Tempos FIXOS programáveis",
			"⚡ Processamento: EVENTOS PUROS"
		]
		
		for info in dist_info:
			var info_label = Label.new()
			info_label.text = info
			info_label.position = Vector2(10, y_offset)
			info_label.add_theme_font_size_override("font_size", 10)
			personality_breakdown.add_child(info_label)
			y_offset += 20

func _process(_delta):
	# EVENTOS DISCRETOS: Atualizar dados do SimuladorTrafego
	var simulador = get_parent().get_node_or_null("SimuladorTrafego")
	if not simulador:
		simulador = get_parent() as SimuladorTrafego
	
	if simulador:
		update_discrete_event_stats(simulador)
	
	# Handle UI toggle
	if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_H):
		toggle_ui_visibility()
	
	# Update personality display periodically
	if Engine.get_process_frames() % 60 == 0:  # Every second
		update_personality_display()

func toggle_ui_visibility():
	ui_visible = !ui_visible
	visible = ui_visible

# ========== PAINEL DE CONTROLES INTERATIVOS PARA EVENTOS DISCRETOS ==========

func create_controls_panel():
	"""Cria painel de controles interativos para distribuições"""
	var controls_panel = create_styled_panel(Color(0.05, 0.05, 0.08, 0.95))
	controls_panel.name = "ControlsPanel"
	controls_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	controls_panel.size = Vector2(350, 400)
	controls_panel.position.x = -360
	add_child(controls_panel)
	
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(10, 10)
	vbox.size = Vector2(330, 380)
	controls_panel.add_child(vbox)
	
	# Título
	var titulo = Label.new()
	titulo.text = "🎛️ CONTROLES DE DISTRIBUIÇÃO"
	titulo.add_theme_font_size_override("font_size", 14)
	titulo.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(titulo)
	
	# Separador
	vbox.add_child(HSeparator.new())
	
	# Controle de taxa de chegada
	create_arrival_rate_control(vbox)
	
	# Controle de distribuição por direção
	create_direction_distribution_control(vbox)
	
	# Controle de semáforo
	create_traffic_light_control(vbox)
	
	# Controle de velocidade da simulação
	create_simulation_speed_control(vbox)
	
	# Botões de ação
	create_action_buttons(vbox)

func create_arrival_rate_control(parent: VBoxContainer):
	"""Controle de taxa de chegada"""
	var grupo = VBoxContainer.new()
	parent.add_child(grupo)
	
	var label = Label.new()
	label.text = "🚗 Taxa de Chegada: 2.5 carros/min"
	label.add_theme_color_override("font_color", Color.CYAN)
	grupo.add_child(label)
	
	var slider = HSlider.new()
	slider.min_value = 0.5
	slider.max_value = 8.0
	slider.step = 0.1
	slider.value = 2.5
	slider.value_changed.connect(_on_arrival_rate_changed)
	grupo.add_child(slider)

func create_direction_distribution_control(parent: VBoxContainer):
	"""Controle de distribuição por direção"""
	var grupo = VBoxContainer.new()
	parent.add_child(grupo)
	
	var label = Label.new()
	label.text = "🎯 Distribuição por Direção:"
	label.add_theme_color_override("font_color", Color.GREEN)
	grupo.add_child(label)
	
	# West→East
	var we_label = Label.new()
	we_label.text = "   West→East: 45%"
	grupo.add_child(we_label)
	
	# East→West  
	var ew_label = Label.new()
	ew_label.text = "   East→West: 40%"
	grupo.add_child(ew_label)
	
	# South→North
	var sn_label = Label.new()
	sn_label.text = "   South→North: 15%"
	grupo.add_child(sn_label)

func create_traffic_light_control(parent: VBoxContainer):
	"""Controle do semáforo"""
	var grupo = VBoxContainer.new()
	parent.add_child(grupo)
	
	var label = Label.new()
	label.text = "🚦 Ciclo do Semáforo:"
	label.add_theme_color_override("font_color", Color.RED)
	grupo.add_child(label)
	
	var verde_label = Label.new()
	verde_label.text = "   Verde: 30s"
	grupo.add_child(verde_label)
	
	var vermelho_label = Label.new()
	vermelho_label.text = "   Vermelho: 25s"
	grupo.add_child(vermelho_label)

func create_simulation_speed_control(parent: VBoxContainer):
	"""Controle de velocidade da simulação"""
	var grupo = VBoxContainer.new()
	parent.add_child(grupo)
	
	var label = Label.new()
	label.text = "⚡ Velocidade: 1.0x"
	label.add_theme_color_override("font_color", Color.ORANGE)
	grupo.add_child(label)
	
	var slider = HSlider.new()
	slider.min_value = 0.1
	slider.max_value = 5.0
	slider.step = 0.1
	slider.value = 1.0
	slider.value_changed.connect(_on_simulation_speed_changed)
	grupo.add_child(slider)

func create_action_buttons(parent: VBoxContainer):
	"""Botões de ação"""
	var grupo = HBoxContainer.new()
	parent.add_child(grupo)
	
	var btn_reset = Button.new()
	btn_reset.text = "🔄 Reset"
	btn_reset.pressed.connect(_on_reset_pressed)
	grupo.add_child(btn_reset)
	
	var btn_pause = Button.new()
	btn_pause.text = "⏸️ Pause"
	btn_pause.pressed.connect(_on_pause_pressed)
	grupo.add_child(btn_pause)

# Callbacks dos controles
func _on_arrival_rate_changed(value: float):
	print("📈 Taxa de chegada alterada: %.1f carros/min" % value)
	# TODO: Alterar taxa no SpawnSystem

func _on_simulation_speed_changed(value: float):
	print("⚡ Velocidade da simulação: %.1fx" % value)
	# TODO: Alterar velocidade no GerenciadorEventos

func _on_reset_pressed():
	print("🔄 Resetando simulação...")
	get_tree().reload_current_scene()

func _on_pause_pressed():
	print("⏸️ Pausando simulação...")
	# TODO: Pausar GerenciadorEventos
