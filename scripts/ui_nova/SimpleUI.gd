extends Control

# NOVA UI SIMPLES PARA O PROFESSOR
# 3 seções: Estatísticas | Gráfico de Frequência | Controles Interativos

var event_bus: Node
var discrete_simulation: Node
var simulation_clock: Node
var traffic_controller: Node
var car_spawner: Node

# Componentes UI
var statistics_table: Control
var frequency_chart: Control  
var interactive_controls: Control

# UI visibility toggle
var ui_visible = true

func _ready():
	print("🎓 SimpleUI para o Professor - INICIANDO")
	
	# Wait for backend systems
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Get system references
	event_bus = get_node_or_null("/root/EventBus")
	discrete_simulation = get_node_or_null("/root/DiscreteSimulation") 
	simulation_clock = get_node_or_null("/root/SimulationClock")
	traffic_controller = get_node_or_null("/root/TrafficLightController")
	car_spawner = get_node_or_null("/root/CarSpawner")
	
	# Setup UI layout
	setup_ui_layout()
	setup_ui_components()
	
	print("✅ SimpleUI pronta para apresentação!")

func _input(event):
	if event.is_action_pressed("ui_toggle_ui"):
		toggle_ui_visibility()

func setup_ui_layout():
	# Set UI to cover full screen
	anchors_preset = Control.PRESET_FULL_RECT
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 1.0
	
	# Allow camera control in empty areas, but stop on UI elements
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Background with transparency - but allow mouse to pass through empty areas
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let empty areas pass mouse to camera
	add_child(bg)
	
	# Main container SEM MARGEM DIREITA para gráfico ir até a borda
	var main_container = MarginContainer.new()
	main_container.anchors_preset = Control.PRESET_FULL_RECT
	main_container.add_theme_constant_override("margin_left", 5)
	main_container.add_theme_constant_override("margin_right", 0)  # ZERO - gráfico vai até a borda
	main_container.add_theme_constant_override("margin_top", 5)
	main_container.add_theme_constant_override("margin_bottom", 5)
	add_child(main_container)
	
	# VBox for sections - ORIGINAL LAYOUT RESTORED
	var vbox = VBoxContainer.new()
	vbox.anchors_preset = Control.PRESET_FULL_RECT
	vbox.add_theme_constant_override("separation", 20)
	main_container.add_child(vbox)
	
	# TITLE for entire UI
	var main_title = Label.new()
	main_title.text = "🎓 TRAFFIC SIMULATOR - INTERFACE DO PROFESSOR"
	main_title.add_theme_font_size_override("font_size", 20)
	main_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(main_title)
	
	# TOP ROW: POSICIONAMENTO ABSOLUTO - CHART OCUPA TODO RESTO DA TELA
	var top_row = Control.new()  # Container pai absoluto
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_row.anchors_preset = Control.PRESET_FULL_RECT
	top_row.custom_minimum_size = Vector2(0, 850)
	vbox.add_child(top_row)
	
	# BOTTOM ROW: Interactive Controls (RESTORED ORIGINAL)
	var bottom_row = Control.new()
	bottom_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.size_flags_vertical = Control.SIZE_EXPAND_FILL  
	bottom_row.custom_minimum_size = Vector2(0, 400)  # BACK TO ORIGINAL: 400
	vbox.add_child(bottom_row)
	
	# Store references for component creation
	statistics_table = top_row
	frequency_chart = top_row  
	interactive_controls = bottom_row

func setup_ui_components():
	# Create Statistics Table - MAIS COMPACTO AINDA
	var stats_component = preload("res://scripts/ui_nova/StatisticsTable.gd").new()
	stats_component.name = "StatisticsTable"
	# POSICIONAMENTO ABSOLUTO - fica colado à esquerda
	stats_component.position = Vector2(5, 5)
	stats_component.size = Vector2(340, 840)  # REDUZIDO: 380→340
	statistics_table.add_child(stats_component)
	
	# Create ADDITIONAL Analysis Panel - AINDA MAIS COMPACTO
	var analysis_component = preload("res://scripts/ui_nova/AdvancedAnalysis.gd").new()
	analysis_component.name = "AdvancedAnalysis"
	# POSICIONAMENTO ABSOLUTO - ao lado do stats
	analysis_component.position = Vector2(350, 5)  # 340 + 10 margem
	analysis_component.size = Vector2(280, 840)  # REDUZIDO: 300→280
	statistics_table.add_child(analysis_component)
	
	# Create Frequency Chart - VAI ATÉ A BORDA ABSOLUTA
	var chart_component = preload("res://scripts/ui_nova/EventFrequencyChart.gd").new()
	chart_component.name = "EventFrequencyChart"
	# POSICIONAMENTO ABSOLUTO - começa após os componentes compactos
	chart_component.position = Vector2(635, 5)  # REDUZIDO: 340+280+15 = 635
	# TAMANHO DINÂMICO - vai até MARGEM ZERO na direita
	var viewport_width = get_viewport().size.x
	var chart_width = viewport_width - 635  # SEM MARGEM DIREITA - vai até borda absoluta
	chart_component.size = Vector2(chart_width, 840)
	frequency_chart.add_child(chart_component)
	
	# Create Interactive Controls (bottom full width)
	var controls_component = preload("res://scripts/ui_nova/InteractiveControls.gd").new()
	controls_component.name = "InteractiveControls"
	controls_component.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_component.size_flags_vertical = Control.SIZE_EXPAND_FILL
	interactive_controls.add_child(controls_component)
	
	# Initialize components with system references
	stats_component.initialize_systems(event_bus, discrete_simulation, simulation_clock, traffic_controller, car_spawner)
	analysis_component.initialize_systems(event_bus, discrete_simulation, simulation_clock, traffic_controller, car_spawner)
	chart_component.initialize_systems(event_bus, discrete_simulation, simulation_clock)  
	controls_component.initialize_systems(event_bus, discrete_simulation, simulation_clock, traffic_controller, car_spawner)
	
	# AJUSTE DINÂMICO QUANDO TELA REDIMENSIONA
	get_viewport().size_changed.connect(_on_viewport_resized.bind(chart_component))

func _on_viewport_resized(chart_component):
	# Reajusta o tamanho do chart quando a janela redimensiona
	var viewport_width = get_viewport().size.x
	var chart_width = viewport_width - 635  # SEM MARGEM - vai até borda direita
	chart_component.size = Vector2(max(200, chart_width), 840)  # Expande até borda ABSOLUTA

func create_analysis_panel() -> Control:
	# Advanced Analysis Panel with visual demonstrations
	var panel = Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "🔬 ANÁLISE AVANÇADA DES"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color.ORANGE)
	vbox.add_child(title)
	
	# Simulation State Analysis
	var state_label = Label.new()
	state_label.text = "📈 ESTADO DA SIMULAÇÃO"
	state_label.add_theme_font_size_override("font_size", 18)
	state_label.add_theme_color_override("font_color", Color.CYAN)
	vbox.add_child(state_label)
	
	# Performance Indicators
	var perf_label = Label.new()
	perf_label.text = "⚡ INDICADORES DE PERFORMANCE"
	perf_label.add_theme_font_size_override("font_size", 18)
	perf_label.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(perf_label)
	
	# Event Distribution
	var event_label = Label.new()
	event_label.text = "🎯 DISTRIBUIÇÃO DE EVENTOS"
	event_label.add_theme_font_size_override("font_size", 18)
	event_label.add_theme_color_override("font_color", Color.GREEN)
	vbox.add_child(event_label)
	
	# System Health
	var health_label = Label.new()
	health_label.text = "💚 SAÚDE DO SISTEMA"
	health_label.add_theme_font_size_override("font_size", 18)
	health_label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
	vbox.add_child(health_label)
	
	# Discrete Events Theory
	var theory_label = Label.new()
	theory_label.text = "📚 TEORIA DES EM TEMPO REAL"
	theory_label.add_theme_font_size_override("font_size", 18)
	theory_label.add_theme_color_override("font_color", Color.PINK)
	vbox.add_child(theory_label)
	
	# Traffic Flow Analysis
	var flow_label = Label.new()
	flow_label.text = "🚦 ANÁLISE DE FLUXO DE TRÁFEGO"
	flow_label.add_theme_font_size_override("font_size", 18)
	flow_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	vbox.add_child(flow_label)
	
	return panel

func toggle_ui_visibility():
	ui_visible = !ui_visible
	visible = ui_visible
	
	if ui_visible:
		print("👁️ SimpleUI mostrada - H=esconder")
	else:
		print("🚫 SimpleUI escondida - H=mostrar")
