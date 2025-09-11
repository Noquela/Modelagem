extends Control

# SISTEMA DE UI COMPLETO PARA SIMULAÇÃO DE TRÁFEGO
# Baseado no EventBus e discrete simulation

var event_bus: Node
var discrete_simulation: Node
var simulation_clock: Node
var traffic_analytics: Node

# UI Panel references
var stats_panel: Control
var frequency_panel: Control
var events_panel: Control

# Statistics tracking
var statistics = {
	"total_cars_spawned": 0,
	"total_cars_despawned": 0,
	"current_active_cars": 0,
	"average_queue_length": 0.0,
	"traffic_light_changes": 0,
	"simulation_uptime": 0.0,
	"cars_per_direction": {
		"west_east": 0,
		"east_west": 0, 
		"south_north": 0
	},
	"average_speed": 0.0,
	"total_stops": 0,
	"rush_hour_multiplier": 1.0
}

# Event frequency tracking
var event_frequencies = {}
var event_history = []
var max_event_history = 100
var event_timeline = []  # Para gráfico temporal
var max_timeline_events = 200

# Advanced graph component
var frequency_graph: Control

# Real-time events
var recent_events = []
var max_recent_events = 20

# UI visibility and mode toggle
var ui_visible = true
var dashboard_mode = true  # true = dashboard completo por padrão

func _ready():
	print("📊 SimulationUI inicializado - MODO DASHBOARD COMPLETO")
	print("⌨️  CONTROLES: H=esconder UI")
	
	# Get system references - aguardar Main.gd criar os sistemas
	await get_tree().process_frame
	await get_tree().process_frame
	
	event_bus = get_node_or_null("/root/EventBus")
	discrete_simulation = get_node_or_null("/root/DiscreteSimulation") 
	simulation_clock = get_node_or_null("/root/SimulationClock")
	traffic_analytics = get_node_or_null("/root/TrafficAnalytics")
	
	# Setup UI panels
	setup_ui_layout()
	setup_event_subscriptions()
	
	# Start update timer
	var update_timer = Timer.new()
	add_child(update_timer)
	update_timer.wait_time = 0.5  # Update every 0.5 seconds
	update_timer.timeout.connect(_update_ui)
	update_timer.start()

func _input(event):
	if event.is_action_pressed("ui_toggle_ui"):
		# Temporariamente removendo Shift+H para debug
		toggle_ui_visibility()

func setup_ui_layout():
	# Configurar posicionamento baseado no modo
	setup_layout_for_mode()
	
	# Configurar layout baseado no modo
	if dashboard_mode:
		setup_dashboard_layout()
	else:
		setup_compact_layout()
	
func setup_compact_layout():
	# Background com transparência mais forte
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)  # Fundo mais escuro para legibilidade
	bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(bg)
	
	# Layout principal - só 1 coluna compacta
	var main_container = VBoxContainer.new()
	main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_theme_constant_override("separation", 5)
	add_child(main_container)
	
	# Abas compactas em vez de painéis lado a lado
	var tab_container = TabContainer.new()
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(tab_container)
	
	# Aba 1: Estatísticas Gerais
	stats_panel = create_compact_stats_panel()
	stats_panel.name = "📊 Stats"
	tab_container.add_child(stats_panel)
	
	# Aba 2: Gráfico de Frequência
	frequency_panel = create_compact_frequency_panel()
	frequency_panel.name = "📈 Eventos"
	tab_container.add_child(frequency_panel)
	
	# Aba 3: Lista de Eventos Recentes
	events_panel = create_compact_events_panel()
	events_panel.name = "⚡ Tempo Real"
	tab_container.add_child(events_panel)
	
	# Aba 4: Analytics Avançado
	var analytics_panel = create_compact_analytics_panel()
	analytics_panel.name = "🧠 Analytics"
	tab_container.add_child(analytics_panel)

func setup_dashboard_layout():
	# Background semitransparente para dashboard
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)  # Mais escuro para dashboard
	bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(bg)
	
	# Container principal com margins
	var main_container = MarginContainer.new()
	main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_theme_constant_override("margin_left", 15)
	main_container.add_theme_constant_override("margin_right", 15)
	main_container.add_theme_constant_override("margin_top", 15)
	main_container.add_theme_constant_override("margin_bottom", 15)
	add_child(main_container)
	
	# VBox principal para seções
	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 15)
	main_container.add_child(main_vbox)
	
	# SEÇÃO 1: Título e Comandos
	var header_section = create_dashboard_header()
	main_vbox.add_child(header_section)
	
	# SEÇÃO 2: Grid principal do dashboard
	var main_grid = GridContainer.new()
	main_grid.columns = 3  # 3 colunas principais
	main_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_grid.add_theme_constant_override("h_separation", 20)
	main_grid.add_theme_constant_override("v_separation", 20)
	main_vbox.add_child(main_grid)
	
	# COLUNA 1: Estatísticas e Métricas Principais
	var metrics_panel = create_dashboard_metrics_panel()
	main_grid.add_child(metrics_panel)
	
	# COLUNA 2: Visualizações Gráficas Centrais
	var visualizations_panel = create_dashboard_visualizations_panel()
	main_grid.add_child(visualizations_panel)
	
	# COLUNA 3: Analytics e Tendências
	var analytics_panel = create_dashboard_analytics_panel()
	main_grid.add_child(analytics_panel)
	
	# LINHA 2: Painéis de largura completa
	var timeline_panel = create_dashboard_timeline_panel()
	main_grid.add_child(timeline_panel)
	
	var intersection_visual = create_dashboard_intersection_panel()
	main_grid.add_child(intersection_visual)
	
	var performance_graphs = create_dashboard_performance_panel()
	main_grid.add_child(performance_graphs)

func create_compact_stats_panel() -> Control:
	var panel = Panel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	
	# Container das estatísticas
	var stats_container = VBoxContainer.new()
	stats_container.name = "StatsContainer"
	stats_container.add_theme_constant_override("separation", 2)
	scroll.add_child(stats_container)
	
	return panel

func create_compact_frequency_panel() -> Control:
	var panel = Panel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)
	
	# Botão para alternar modo do gráfico
	var toggle_button = Button.new()
	toggle_button.text = "🔄 Modo Gráfico"
	toggle_button.custom_minimum_size = Vector2(120, 25)
	toggle_button.pressed.connect(_on_toggle_graph_mode)
	vbox.add_child(toggle_button)
	
	# Gráfico avançado compacto
	frequency_graph = preload("res://scripts/ui/FrequencyGraph.gd").new()
	frequency_graph.name = "FrequencyGraph"
	frequency_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frequency_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frequency_graph.custom_minimum_size = Vector2(200, 150)
	vbox.add_child(frequency_graph)
	
	return panel

func create_compact_events_panel() -> Control:
	var panel = Panel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)
	
	# Estatísticas de eventos recentes compactas
	var recent_stats = VBoxContainer.new()
	recent_stats.name = "RecentStats"
	recent_stats.add_theme_constant_override("separation", 1)
	vbox.add_child(recent_stats)
	
	# Scroll container para lista de eventos
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	var events_list = VBoxContainer.new()
	events_list.name = "EventsList"
	events_list.add_theme_constant_override("separation", 1)
	scroll.add_child(events_list)
	
	return panel

func create_compact_analytics_panel() -> Control:
	var panel = Panel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.name = "AnalyticsPanel"
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	
	# Container para métricas compactas
	var metrics_container = VBoxContainer.new()
	metrics_container.add_theme_constant_override("separation", 5)
	scroll.add_child(metrics_container)
	
	# Seção Performance
	var perf_section = VBoxContainer.new()
	perf_section.name = "PerformanceColumn"
	metrics_container.add_child(perf_section)
	
	var perf_title = Label.new()
	perf_title.text = "⚡ PERFORMANCE"
	perf_title.add_theme_font_size_override("font_size", 11)
	perf_section.add_child(perf_title)
	
	# Seção Flow
	var flow_section = VBoxContainer.new()
	flow_section.name = "FlowColumn"
	metrics_container.add_child(flow_section)
	
	var flow_title = Label.new()
	flow_title.text = "🚗 FLUXO"
	flow_title.add_theme_font_size_override("font_size", 11)
	flow_section.add_child(flow_title)
	
	# Seção Congestion
	var congestion_section = VBoxContainer.new()
	congestion_section.name = "CongestionColumn"
	metrics_container.add_child(congestion_section)
	
	var congestion_title = Label.new()
	congestion_title.text = "🚦 FILAS"
	congestion_title.add_theme_font_size_override("font_size", 11)
	congestion_section.add_child(congestion_title)
	
	return panel

# ========== DASHBOARD HEADER ==========

func create_dashboard_header() -> Control:
	var header_panel = Panel.new()
	header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_panel.custom_minimum_size = Vector2(0, 120)
	
	var header_vbox = VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 10)
	header_panel.add_child(header_vbox)
	
	# Título principal GRANDE
	var title = Label.new()
	title.text = "🚦 TRAFFIC SIMULATOR 3D - DASHBOARD COMPLETO"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_vbox.add_child(title)
	
	# Container horizontal para comandos
	var commands_hbox = HBoxContainer.new()
	commands_hbox.add_theme_constant_override("separation", 30)
	header_vbox.add_child(commands_hbox)
	
	# Coluna 1: Controles básicos
	var basic_commands = VBoxContainer.new()
	var basic_title = Label.new()
	basic_title.text = "🎮 CONTROLES BÁSICOS"
	basic_title.add_theme_font_size_override("font_size", 14)
	basic_commands.add_child(basic_title)
	
	var basic_commands_list = [
		"H - Esconder/Mostrar UI",
		"ESPAÇO - Pausar/Despausar Simulação",
		"R - Reset Completo da Simulação",
		"C - Alternar Modo de Câmera"
	]
	
	for command in basic_commands_list:
		var cmd_label = Label.new()
		cmd_label.text = "  • " + command
		cmd_label.add_theme_font_size_override("font_size", 11)
		basic_commands.add_child(cmd_label)
	
	commands_hbox.add_child(basic_commands)
	
	# Coluna 2: Controles de camera
	var camera_commands = VBoxContainer.new()
	var camera_title = Label.new()
	camera_title.text = "📷 CONTROLES DE CÂMERA"
	camera_title.add_theme_font_size_override("font_size", 14)
	camera_commands.add_child(camera_title)
	
	var camera_commands_list = [
		"WASD - Mover Câmera",
		"MOUSE - Rotacionar Visão",
		"SCROLL - Zoom In/Out",
		"SHIFT+WASD - Movimento Rápido"
	]
	
	for command in camera_commands_list:
		var cmd_label = Label.new()
		cmd_label.text = "  • " + command
		cmd_label.add_theme_font_size_override("font_size", 11)
		camera_commands.add_child(cmd_label)
	
	commands_hbox.add_child(camera_commands)
	
	# Coluna 3: Status da simulação
	var status_commands = VBoxContainer.new()
	var status_title = Label.new()
	status_title.text = "📊 STATUS EM TEMPO REAL"
	status_title.add_theme_font_size_override("font_size", 14)
	status_commands.add_child(status_title)
	
	var status_info = VBoxContainer.new()
	status_info.name = "StatusInfo"
	status_commands.add_child(status_info)
	
	commands_hbox.add_child(status_commands)
	
	return header_panel

# ========== DASHBOARD PANELS ==========

func create_dashboard_metrics_panel() -> Control:
	var panel = Panel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(400, 500)
	
	var margin_container = MarginContainer.new()
	margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin_container.add_theme_constant_override("margin_left", 15)
	margin_container.add_theme_constant_override("margin_right", 15)
	margin_container.add_theme_constant_override("margin_top", 15)
	margin_container.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin_container)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin_container.add_child(vbox)
	
	# Título do painel MAIOR
	var title = Label.new()
	title.text = "📊 MÉTRICAS PRINCIPAIS"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Container para estatísticas principais
	stats_panel = VBoxContainer.new()
	stats_panel.name = "DashboardStatsContainer"
	stats_panel.add_theme_constant_override("separation", 8)
	vbox.add_child(stats_panel)
	
	return panel

func create_dashboard_visualizations_panel() -> Control:
	var panel = Panel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(500, 500)
	
	var margin_container = MarginContainer.new()
	margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin_container.add_theme_constant_override("margin_left", 15)
	margin_container.add_theme_constant_override("margin_right", 15)
	margin_container.add_theme_constant_override("margin_top", 15)
	margin_container.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin_container)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin_container.add_child(vbox)
	
	# Título MAIOR
	var title = Label.new()
	title.text = "📈 VISUALIZAÇÕES"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Controles de gráfico
	var controls = HBoxContainer.new()
	vbox.add_child(controls)
	
	var toggle_button = Button.new()
	toggle_button.text = "🔄 Alternar Modo"
	toggle_button.custom_minimum_size = Vector2(120, 30)
	toggle_button.pressed.connect(_on_toggle_graph_mode)
	controls.add_child(toggle_button)
	
	var clear_button = Button.new()
	clear_button.text = "🗑️ Limpar"
	clear_button.custom_minimum_size = Vector2(80, 30)
	clear_button.pressed.connect(_on_clear_graphs)
	controls.add_child(clear_button)
	
	# Gráfico principal expandido MUITO MAIOR
	frequency_graph = preload("res://scripts/ui/FrequencyGraph.gd").new()
	frequency_graph.name = "DashboardFrequencyGraph"
	frequency_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frequency_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frequency_graph.custom_minimum_size = Vector2(450, 400)
	vbox.add_child(frequency_graph)
	
	return panel

func create_dashboard_analytics_panel() -> Control:
	var panel = Panel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(400, 500)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)
	
	# Título MAIOR
	var title = Label.new()
	title.text = "🧠 ANALYTICS AVANÇADO"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Containers para diferentes seções
	var perf_section = VBoxContainer.new()
	perf_section.name = "DashboardPerformanceSection"
	perf_section.add_theme_constant_override("separation", 3)
	vbox.add_child(perf_section)
	
	var flow_section = VBoxContainer.new()
	flow_section.name = "DashboardFlowSection"
	flow_section.add_theme_constant_override("separation", 3)
	vbox.add_child(flow_section)
	
	var congestion_section = VBoxContainer.new()
	congestion_section.name = "DashboardCongestionSection"
	congestion_section.add_theme_constant_override("separation", 3)
	vbox.add_child(congestion_section)
	
	return panel

func create_dashboard_timeline_panel() -> Control:
	var panel = Panel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(200, 150)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "⏱️ TIMELINE DE EVENTOS"
	title.add_theme_font_size_override("font_size", 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Lista de eventos recentes expandida
	events_panel = VBoxContainer.new()
	events_panel.name = "DashboardEventsContainer"
	events_panel.add_theme_constant_override("separation", 2)
	vbox.add_child(events_panel)
	
	return panel

func create_dashboard_intersection_panel() -> Control:
	var panel = Panel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(200, 150)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "🚦 ESTADO DA INTERSEÇÃO"
	title.add_theme_font_size_override("font_size", 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Visual simplificado da interseção
	var intersection_visual = Control.new()
	intersection_visual.name = "IntersectionVisual"
	intersection_visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intersection_visual.size_flags_vertical = Control.SIZE_EXPAND_FILL
	intersection_visual.custom_minimum_size = Vector2(150, 100)
	vbox.add_child(intersection_visual)
	
	return panel

func create_dashboard_performance_panel() -> Control:
	var panel = Panel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(200, 150)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "📊 PERFORMANCE EM TEMPO REAL"
	title.add_theme_font_size_override("font_size", 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Container para gráficos de performance
	var performance_container = VBoxContainer.new()
	performance_container.name = "PerformanceGraphsContainer"
	performance_container.add_theme_constant_override("separation", 5)
	vbox.add_child(performance_container)
	
	return panel

func _on_clear_graphs():
	event_frequencies.clear()
	event_timeline.clear()
	recent_events.clear()
	event_history.clear()
	print("🗑️ Gráficos e dados limpos")

func setup_event_subscriptions():
	# Subscrever todos os eventos do sistema
	event_bus.subscribe("car_spawned", _on_car_spawned)
	event_bus.subscribe("car_despawned", _on_car_despawned)
	event_bus.subscribe("car_stopped", _on_car_stopped)
	event_bus.subscribe("car_started", _on_car_started)
	event_bus.subscribe("traffic_light_changed", _on_traffic_light_changed)
	event_bus.subscribe("car_position_updated", _on_car_position_updated)

func _on_car_spawned(car_data):
	statistics.total_cars_spawned += 1
	statistics.current_active_cars += 1
	
	# Contar por direção
	match car_data.direction_enum:
		0: statistics.cars_per_direction.west_east += 1
		1: statistics.cars_per_direction.east_west += 1
		3: statistics.cars_per_direction.south_north += 1
	
	add_event("car_spawned", "🚗 Carro spawned: " + str(car_data.id))
	track_event_frequency("car_spawned")

func _on_car_despawned(car_data):
	statistics.total_cars_despawned += 1
	statistics.current_active_cars -= 1
	
	add_event("car_despawned", "🏁 Carro despawned: " + str(car_data.id))
	track_event_frequency("car_despawned")

func _on_car_stopped(car_data):
	statistics.total_stops += 1
	add_event("car_stopped", "🛑 Carro parou: " + str(car_data.id))
	track_event_frequency("car_stopped")

func _on_car_started(car_data):
	add_event("car_started", "▶️ Carro moveu: " + str(car_data.id))
	track_event_frequency("car_started")

func _on_traffic_light_changed(data):
	statistics.traffic_light_changes += 1
	var state_names = ["🔴 VERMELHO", "🟡 AMARELO", "🟢 VERDE"]
	var state_name = state_names[data.state] if data.state < 3 else "?"
	add_event("traffic_light_changed", "🚦 Semáforo: " + state_name)
	track_event_frequency("traffic_light_changed")

func _on_car_position_updated(car_data):
	# Atualizar velocidade média (simplificado)
	if car_data.has("speed"):
		statistics.average_speed = car_data.speed
	track_event_frequency("car_position_updated")

func add_event(event_type: String, description: String):
	var timestamp = simulation_clock.get_simulation_time() if simulation_clock else Time.get_ticks_msec() / 1000.0
	var event_data = {
		"type": event_type,
		"description": description,
		"timestamp": timestamp,
		"sim_time": format_simulation_time(timestamp),
		"event_type": event_type  # Para o gráfico
	}
	
	recent_events.push_front(event_data)
	if recent_events.size() > max_recent_events:
		recent_events.pop_back()
	
	event_history.push_front(event_data)
	if event_history.size() > max_event_history:
		event_history.pop_back()
	
	# Adicionar ao timeline do gráfico
	event_timeline.append(event_data)
	if event_timeline.size() > max_timeline_events:
		event_timeline.pop_front()

func track_event_frequency(event_type: String):
	if not event_frequencies.has(event_type):
		event_frequencies[event_type] = 0
	event_frequencies[event_type] += 1

func format_simulation_time(time: float) -> String:
	var minutes = int(time / 60)
	var seconds = int(time) % 60
	return "%02d:%02d" % [minutes, seconds]

func _update_ui():
	if dashboard_mode:
		update_dashboard_panels()
	else:
		update_compact_panels()

func update_compact_panels():
	update_statistics_panel()
	update_frequency_panel()
	update_events_panel()
	update_analytics_panel()

func update_dashboard_panels():
	update_dashboard_header_status()
	update_dashboard_statistics()
	update_dashboard_visualizations()
	update_dashboard_analytics()
	update_dashboard_timeline()
	update_dashboard_performance()

func update_statistics_panel():
	var stats_container = stats_panel.find_child("StatsContainer")
	if not stats_container:
		return
	update_stats_data(stats_container, 9)

func update_dashboard_statistics():
	var stats_container = stats_panel.find_child("DashboardStatsContainer")
	if not stats_container:
		return
	update_stats_data(stats_container, 16)  # Fonte MAIOR para dashboard

func update_stats_data(stats_container: VBoxContainer, font_size: int):
	
	# Limpar labels antigos
	for child in stats_container.get_children():
		child.queue_free()
	
	# Atualizar dados dinâmicos
	if simulation_clock:
		statistics.simulation_uptime = simulation_clock.get_simulation_time()
	
	if discrete_simulation and discrete_simulation.has_method("get_active_cars"):
		var active_cars = discrete_simulation.get("active_cars")
		if active_cars:
			statistics.current_active_cars = active_cars.size()
			
			# Calcular velocidade média
			var total_speed = 0.0
			var count = 0
			for car_id in active_cars.keys():
				var car = active_cars[car_id]
				if car.has("speed"):
					total_speed += car.speed
					count += 1
			statistics.average_speed = total_speed / max(count, 1)
	
	# Criar labels das estatísticas
	var stats_data = [
		["⏱️ Tempo de Simulação", format_simulation_time(statistics.simulation_uptime)],
		["🚗 Carros Ativos", str(statistics.current_active_cars)],
		["📊 Total Spawned", str(statistics.total_cars_spawned)],
		["🏁 Total Despawned", str(statistics.total_cars_despawned)],
		["📈 Velocidade Média", "%.1f km/h" % statistics.average_speed],
		["🛑 Total de Paradas", str(statistics.total_stops)],
		["🚦 Mudanças de Semáforo", str(statistics.traffic_light_changes)],
		["⚡ Rush Hour Multi.", "%.1fx" % statistics.rush_hour_multiplier],
		["", ""],  # Separador
		["📍 POR DIREÇÃO:", ""],
		["   Oeste → Leste", str(statistics.cars_per_direction.west_east)],
		["   Leste → Oeste", str(statistics.cars_per_direction.east_west)],
		["   Sul → Norte", str(statistics.cars_per_direction.south_north)]
	]
	
	for stat in stats_data:
		var label = Label.new()
		if stat[0] == "":
			label.text = stat[1]
		else:
			label.text = stat[0] + ": " + stat[1]
		label.add_theme_font_size_override("font_size", font_size)
		stats_container.add_child(label)

# ========== DASHBOARD UPDATE FUNCTIONS ==========

func update_dashboard_visualizations():
	if frequency_graph:
		frequency_graph.update_data(event_frequencies, event_timeline)

func update_dashboard_analytics():
	if not traffic_analytics:
		return
	
	var perf_section = find_child("DashboardPerformanceSection")
	var flow_section = find_child("DashboardFlowSection") 
	var congestion_section = find_child("DashboardCongestionSection")
	
	if not perf_section or not flow_section or not congestion_section:
		return
	
	# Limpar seções
	clear_dashboard_section(perf_section, "⚡ PERFORMANCE")
	clear_dashboard_section(flow_section, "🚗 FLUXO")
	clear_dashboard_section(congestion_section, "🚦 CONGESTIONAMENTO")
	
	# Obter dados do analytics
	var analytics_summary = traffic_analytics.get_analytics_summary()
	var analytics_data = traffic_analytics.traffic_data
	
	# SEÇÃO PERFORMANCE
	add_dashboard_metric(perf_section, "Duração:", analytics_summary.session_duration)
	add_dashboard_metric(perf_section, "Carros:", str(analytics_summary.total_cars_processed))
	add_dashboard_metric(perf_section, "Tempo Viagem:", analytics_summary.average_travel_time)
	add_dashboard_metric(perf_section, "Paradas:", analytics_summary.average_stops)
	add_dashboard_metric(perf_section, "Throughput:", analytics_summary.throughput)
	add_dashboard_metric(perf_section, "Eficiência:", analytics_summary.efficiency)
	
	# SEÇÃO FLUXO
	var flow_data = analytics_data.flow_rates
	add_dashboard_metric(flow_section, "O→L:", "%.1f/min" % flow_data.west_east.cars_per_minute)
	add_dashboard_metric(flow_section, "L→O:", "%.1f/min" % flow_data.east_west.cars_per_minute)
	add_dashboard_metric(flow_section, "S→N:", "%.1f/min" % flow_data.south_north.cars_per_minute)
	
	# Dados do semáforo
	var light_data = analytics_data.traffic_light_data
	var total_light_time = light_data.red_time + light_data.yellow_time + light_data.green_time
	if total_light_time > 0:
		add_dashboard_metric(flow_section, "🔴 Vermelho:", "%.0f%%" % (light_data.red_time / total_light_time * 100))
		add_dashboard_metric(flow_section, "🟢 Verde:", "%.0f%%" % (light_data.green_time / total_light_time * 100))
	
	# SEÇÃO CONGESTIONAMENTO
	add_dashboard_metric(congestion_section, "Fila Pico:", str(analytics_summary.peak_queue))
	add_dashboard_metric(congestion_section, "Fila Média:", analytics_summary.avg_queue)
	add_dashboard_metric(congestion_section, "Parada Max:", "%.1fs" % analytics_data.congestion_analysis.longest_stop_duration)
	add_dashboard_metric(congestion_section, "Mudanças:", str(light_data.total_changes))

func update_dashboard_timeline():
	var events_container = find_child("DashboardEventsContainer")
	if not events_container:
		return
	
	# Limpar eventos antigos
	for child in events_container.get_children():
		child.queue_free()
	
	# Mostrar mais eventos no dashboard (últimos 15)
	var display_events = recent_events.slice(0, min(15, recent_events.size()))
	
	var event_colors = {
		"car_spawned": Color.GREEN,
		"car_despawned": Color.RED,
		"car_stopped": Color.ORANGE,
		"car_started": Color.BLUE,
		"traffic_light_changed": Color.YELLOW,
		"car_position_updated": Color.GRAY
	}
	
	for event_data in display_events:
		var event_container = HBoxContainer.new()
		events_container.add_child(event_container)
		
		# Indicador colorido maior
		var indicator = ColorRect.new()
		indicator.size = Vector2(12, 20)
		indicator.color = event_colors.get(event_data.type, Color.WHITE)
		event_container.add_child(indicator)
		
		# Texto do evento com fonte maior
		var event_label = Label.new()
		event_label.text = "[%s] %s" % [event_data.sim_time, event_data.description]
		event_label.add_theme_font_size_override("font_size", 11)
		event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		event_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		event_container.add_child(event_label)

func update_dashboard_header_status():
	var status_info = find_child("StatusInfo")
	if not status_info:
		return
	
	# Limpar status antigo
	for child in status_info.get_children():
		child.queue_free()
	
	# Status em tempo real
	var sim_time = simulation_clock.get_simulation_time() if simulation_clock else 0.0
	var time_label = Label.new()
	time_label.text = "⏱️ Tempo: " + format_simulation_time(sim_time)
	time_label.add_theme_font_size_override("font_size", 12)
	status_info.add_child(time_label)
	
	var cars_label = Label.new()
	cars_label.text = "🚗 Carros Ativos: " + str(statistics.current_active_cars)
	cars_label.add_theme_font_size_override("font_size", 12)
	status_info.add_child(cars_label)
	
	if traffic_analytics:
		var analytics_data = traffic_analytics.traffic_data
		var light_data = analytics_data.traffic_light_data
		var light_states = ["🔴 VERMELHO", "🟡 AMARELO", "🟢 VERDE"]
		var current_state = light_states[light_data.current_state] if light_data.current_state < 3 else "❓ DESCONHECIDO"
		
		var traffic_light_label = Label.new()
		traffic_light_label.text = "🚦 " + current_state
		traffic_light_label.add_theme_font_size_override("font_size", 12)
		status_info.add_child(traffic_light_label)

func update_dashboard_performance():
	var performance_container = find_child("PerformanceGraphsContainer")
	if not performance_container:
		return
	
	# Limpar gráficos antigos
	for child in performance_container.get_children():
		child.queue_free()
	
	# Adicionar métricas de performance em tempo real
	if traffic_analytics:
		var analytics_data = traffic_analytics.traffic_data
		
		# Throughput atual
		var throughput_label = Label.new()
		throughput_label.text = "🚗 Throughput: %.1f carros/min" % analytics_data.performance_metrics.throughput
		throughput_label.add_theme_font_size_override("font_size", 14)
		performance_container.add_child(throughput_label)
		
		# Score de eficiência
		var efficiency_label = Label.new()
		efficiency_label.text = "📈 Eficiência: %.1f%%" % analytics_data.performance_metrics.efficiency_score
		efficiency_label.add_theme_font_size_override("font_size", 14)
		performance_container.add_child(efficiency_label)
		
		# Velocidade média
		var speed_label = Label.new()
		speed_label.text = "⚡ Velocidade: %.1f km/h" % statistics.average_speed
		speed_label.add_theme_font_size_override("font_size", 14)
		performance_container.add_child(speed_label)

func clear_dashboard_section(section: VBoxContainer, title: String):
	# Manter apenas o título
	for child in section.get_children():
		if child is Label and child.text != title:
			child.queue_free()

func add_dashboard_metric(section: VBoxContainer, label: String, value: String):
	var metric_label = Label.new()
	metric_label.text = label + " " + value
	metric_label.add_theme_font_size_override("font_size", 14)  # Fonte MAIOR
	section.add_child(metric_label)

func update_frequency_panel():
	if frequency_graph:
		frequency_graph.update_data(event_frequencies, event_timeline)

func update_events_panel():
	update_recent_stats()
	
	var events_list = events_panel.find_child("EventsList")
	if not events_list:
		return
	
	# Limpar eventos antigos
	for child in events_list.get_children():
		child.queue_free()
	
	# Adicionar eventos recentes com cores por tipo
	var event_colors = {
		"car_spawned": Color.GREEN,
		"car_despawned": Color.RED,
		"car_stopped": Color.ORANGE,
		"car_started": Color.BLUE,
		"traffic_light_changed": Color.YELLOW,
		"car_position_updated": Color.GRAY
	}
	
	for event_data in recent_events:
		var event_container = HBoxContainer.new()
		events_list.add_child(event_container)
		
		# Indicador colorido
		var indicator = ColorRect.new()
		indicator.size = Vector2(8, 16)
		indicator.color = event_colors.get(event_data.type, Color.WHITE)
		event_container.add_child(indicator)
		
		# Texto do evento
		var event_label = Label.new()
		event_label.text = "[%s] %s" % [event_data.sim_time, event_data.description]
		event_label.add_theme_font_size_override("font_size", 8)
		event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		event_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		event_container.add_child(event_label)
	
	if recent_events.size() == 0:
		var no_events_label = Label.new()
		no_events_label.text = "Aguardando eventos..."
		no_events_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		events_list.add_child(no_events_label)

func update_recent_stats():
	var recent_stats = events_panel.find_child("RecentStats")
	if not recent_stats:
		return
	
	# Limpar stats antigos
	for child in recent_stats.get_children():
		child.queue_free()
	
	# Calcular estatísticas dos últimos 10 eventos
	var last_10_events = recent_events.slice(0, min(10, recent_events.size()))
	var event_types_count = {}
	var time_span = 0.0
	
	for event in last_10_events:
		var event_type = event.type
		if not event_types_count.has(event_type):
			event_types_count[event_type] = 0
		event_types_count[event_type] += 1
	
	if last_10_events.size() > 1:
		time_span = last_10_events[0].timestamp - last_10_events[-1].timestamp
	
	# Mostrar estatísticas
	var stats_title = Label.new()
	stats_title.text = "📊 Últimos 10:"
	stats_title.add_theme_font_size_override("font_size", 9)
	recent_stats.add_child(stats_title)
	
	for event_type in event_types_count.keys():
		var count = event_types_count[event_type]
		var rate = count / max(time_span, 1.0) if time_span > 0 else 0.0
		
		var stat_label = Label.new()
		stat_label.text = "  %s: %d (%.1f/s)" % [event_type.replace("_", " ").capitalize(), count, rate]
		stat_label.add_theme_font_size_override("font_size", 8)
		recent_stats.add_child(stat_label)
	
	# Taxa total de eventos
	if time_span > 0:
		var total_rate = last_10_events.size() / time_span
		var total_label = Label.new()
		total_label.text = "📈 Taxa Total: %.1f eventos/s" % total_rate
		total_label.add_theme_font_size_override("font_size", 8)
		recent_stats.add_child(total_label)

func _on_toggle_graph_mode():
	if frequency_graph:
		frequency_graph.toggle_graph_mode()

func update_analytics_panel():
	var analytics_panel = find_child("AnalyticsPanel")
	if not analytics_panel or not traffic_analytics:
		return
	
	var perf_column = analytics_panel.find_child("PerformanceColumn")
	var flow_column = analytics_panel.find_child("FlowColumn")
	var congestion_column = analytics_panel.find_child("CongestionColumn")
	
	if not perf_column or not flow_column or not congestion_column:
		return
	
	# Limpar dados antigos
	clear_column_data(perf_column, "⚡ PERFORMANCE")
	clear_column_data(flow_column, "🚗 FLUXO DE TRÁFEGO")
	clear_column_data(congestion_column, "🚦 CONGESTIONAMENTO")
	
	# Obter dados do analytics
	var analytics_summary = traffic_analytics.get_analytics_summary()
	var analytics_data = traffic_analytics.traffic_data
	
	# COLUNA PERFORMANCE
	add_metric_to_column(perf_column, "Duração Sessão:", analytics_summary.session_duration)
	add_metric_to_column(perf_column, "Carros Processados:", str(analytics_summary.total_cars_processed))
	add_metric_to_column(perf_column, "Tempo Médio Viagem:", analytics_summary.average_travel_time)
	add_metric_to_column(perf_column, "Paradas Médias:", analytics_summary.average_stops)
	add_metric_to_column(perf_column, "Throughput:", analytics_summary.throughput)
	add_metric_to_column(perf_column, "Score Eficiência:", analytics_summary.efficiency)
	
	# COLUNA FLUXO
	var flow_data = analytics_data.flow_rates
	add_metric_to_column(flow_column, "Oeste → Leste:", "%.1f/min" % flow_data.west_east.cars_per_minute)
	add_metric_to_column(flow_column, "Leste → Oeste:", "%.1f/min" % flow_data.east_west.cars_per_minute)
	add_metric_to_column(flow_column, "Sul → Norte:", "%.1f/min" % flow_data.south_north.cars_per_minute)
	
	# Dados do semáforo
	var light_data = analytics_data.traffic_light_data
	var total_light_time = light_data.red_time + light_data.yellow_time + light_data.green_time
	if total_light_time > 0:
		add_metric_to_column(flow_column, "Tempo Vermelho:", "%.1f%%" % (light_data.red_time / total_light_time * 100))
		add_metric_to_column(flow_column, "Tempo Verde:", "%.1f%%" % (light_data.green_time / total_light_time * 100))
	
	# COLUNA CONGESTIONAMENTO
	add_metric_to_column(congestion_column, "Fila Pico:", str(analytics_summary.peak_queue))
	add_metric_to_column(congestion_column, "Fila Média:", analytics_summary.avg_queue)
	add_metric_to_column(congestion_column, "Parada Máxima:", "%.1fs" % analytics_data.congestion_analysis.longest_stop_duration)
	add_metric_to_column(congestion_column, "Mudanças Semáforo:", str(light_data.total_changes))

func clear_column_data(column: VBoxContainer, title: String):
	# Manter apenas o título
	for child in column.get_children():
		if child.text != title:
			child.queue_free()

func add_metric_to_column(column: VBoxContainer, label: String, value: String):
	var metric_label = Label.new()
	metric_label.text = label + " " + value
	metric_label.add_theme_font_size_override("font_size", 8)
	column.add_child(metric_label)

func setup_layout_for_mode():
	if dashboard_mode:
		# Dashboard MUITO MAIOR - ocupa quase toda a tela
		anchors_preset = Control.PRESET_FULL_RECT
		anchor_left = 0.0
		anchor_right = 1.0
		anchor_top = 0.0
		anchor_bottom = 1.0
		offset_left = 5
		offset_top = 5
		offset_right = -5
		offset_bottom = -5
	else:
		# UI compacta - só canto superior direito
		anchors_preset = Control.PRESET_TOP_RIGHT
		anchor_left = 0.7
		anchor_right = 1.0
		anchor_top = 0.0
		anchor_bottom = 0.4
		offset_left = -10
		offset_top = 10
		offset_right = -10
		offset_bottom = 10

func toggle_dashboard_mode():
	dashboard_mode = !dashboard_mode
	var mode_text = "DASHBOARD COMPLETO" if dashboard_mode else "COMPACTO"
	print("🔄 Modo alterado: ", mode_text)
	print("⌨️  H=esconder | Shift+H=alternar modo")
	
	# Rebuild UI with new layout
	for child in get_children():
		child.queue_free()
	
	# Aguardar um frame para garantir que os nodes foram removidos
	await get_tree().process_frame
	
	setup_ui_layout()
	
	print("✅ Layout ", mode_text, " aplicado!")
	
	if dashboard_mode:
		setup_dashboard_layout()
	else:
		setup_compact_layout()

func toggle_ui_visibility():
	ui_visible = !ui_visible
	visible = ui_visible
	
	var mode_text = "DASHBOARD COMPLETO" if dashboard_mode else "COMPACTO"
	if ui_visible:
		print("👁️  UI mostrada (", mode_text, ") - H=esconder | Shift+H=alternar modo")
	else:
		print("🚫 UI escondida - H=mostrar")