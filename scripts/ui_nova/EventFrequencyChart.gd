extends Control

# GRÁFICO DE FREQUÊNCIA DE EVENTOS PARA O PROFESSOR
# Simples e funcional - modo barras

var event_bus: Node
var discrete_simulation: Node
var simulation_clock: Node

# Event tracking
var event_frequencies = {}
var event_timeline = []  # Timeline list of events with timestamps
var chart_mode = "bars"  # "bars" or "timeline"

# UI components
var title_label: Label
var toggle_button: Button
var chart_area: Control

func _ready():
	setup_ui()
	# FORÇA recálculo de layout após setup
	await get_tree().process_frame
	await get_tree().process_frame
	force_layout_update()

func force_layout_update():
	# Força o Godot a recalcular o layout usando técnica de hide/show
	var was_visible = visible
	visible = false
	await get_tree().process_frame
	visible = was_visible
	# Força recálculo do tamanho
	queue_redraw()

func initialize_systems(eb: Node, ds: Node, sc: Node):
	event_bus = eb
	discrete_simulation = ds
	simulation_clock = sc
	
	# Subscribe to meaningful events only (avoid high-frequency ones)
	if event_bus:
		event_bus.subscribe("car_spawned", _on_car_spawned)
		event_bus.subscribe("car_despawned", _on_car_despawned)
		event_bus.subscribe("traffic_light_changed", _on_traffic_light_changed)
		event_bus.subscribe("car_stopped", _on_car_stopped)
		event_bus.subscribe("car_started", _on_car_started)
		event_bus.subscribe("car_entered_intersection", _on_car_entered_intersection)
		event_bus.subscribe("car_exited_intersection", _on_car_exited_intersection)
		# REMOVED: car_position_updated - happens too frequently and ruins scale

func setup_ui():
	# ESTRATÉGIA NOVA: Force absolute expansion using viewport coordinates
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	anchors_preset = Control.PRESET_FULL_RECT
	# FORÇA o tamanho para ocupar todo espaço disponível do parent
	custom_minimum_size = Vector2(0, 0)  # Remove minimum size constraints
	
	# Background panel - ABSOLUTE EXPANSION
	var panel = Panel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP  # Block camera rotation when over chart
	panel.anchors_preset = Control.PRESET_FULL_RECT
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)  # FORÇA posicionamento absoluto
	add_child(panel)
	
	# SEM MARGIN CONTAINER - direto no panel para ZERO margens
	# Container filho direto sem margens para usar TODO o espaço
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.anchors_preset = Control.PRESET_FULL_RECT  # OCUPA TODO espaço do panel
	panel.add_child(vbox)  # Direto no panel, sem margin container
	
	# Title and toggle button
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 15)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # FORÇA EXPANSÃO
	vbox.add_child(header)
	
	title_label = Label.new()
	title_label.text = "📈 FREQUÊNCIA DE EVENTOS"
	title_label.add_theme_font_size_override("font_size", 24)  # AUMENTADO: 16 → 24
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	
	toggle_button = Button.new()
	toggle_button.text = "🔄 Timeline"
	toggle_button.custom_minimum_size = Vector2(120, 35)  # AUMENTADO: 80→120, 25→35 para botão mais visível
	toggle_button.add_theme_font_size_override("font_size", 16)  # Fonte do botão maior
	toggle_button.pressed.connect(_on_toggle_mode)
	header.add_child(toggle_button)
	
	# Chart drawing area with maximum space usage
	chart_area = Control.new()
	chart_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart_area.custom_minimum_size = Vector2(0, 610)  # AUMENTADO: 550→610 para chart maior
	chart_area.draw.connect(_draw_chart)
	vbox.add_child(chart_area)
	
	# LEGENDA EXPLICATIVA DOS EVENTOS
	create_event_legend(vbox)

func _on_event_tracked(data):
	var event_type = ""
	
	# Determine event type from the event name (more reliable)
	# Since we're subscribing to specific events, we can track them by callback
	pass  # Will be handled by specific event handlers

func _on_car_spawned(_data):
	track_event("car_spawned")

func _on_car_despawned(_data):
	track_event("car_despawned")

func _on_traffic_light_changed(_data):
	track_event("traffic_light_changed")

func _on_car_stopped(_data):
	track_event("car_stopped")

func _on_car_started(_data):
	track_event("car_started")

func _on_car_entered_intersection(_data):
	track_event("car_entered_intersection")

func _on_car_exited_intersection(_data):
	track_event("car_exited_intersection")

func track_event(event_type: String):
	# Track frequency
	if not event_frequencies.has(event_type):
		event_frequencies[event_type] = 0
	event_frequencies[event_type] += 1
	
	# Add to timeline with timestamp
	var timestamp = simulation_clock.get_simulation_time() if simulation_clock else 0.0
	event_timeline.append({
		"type": event_type,
		"time": timestamp,
		"display_time": format_time(timestamp)
	})
	
	# Keep only last 50 events for performance
	if event_timeline.size() > 50:
		event_timeline = event_timeline.slice(-50)
	
	# Trigger redraw
	if chart_area:
		chart_area.queue_redraw()

func _draw_chart():
	if not chart_area:
		return
		
	if chart_mode == "timeline":
		_draw_timeline()
	else:
		_draw_bars()

func _draw_timeline():
	var rect = chart_area.get_rect()
	var margin = Vector2(10, 10)  # REDUCED timeline margins
	var available_rect = Rect2(
		margin.x,
		margin.y,
		rect.size.x - margin.x - 10,  # REDUCED right margin
		rect.size.y - margin.y - 10   # REDUCED bottom margin
	)
	
	if event_timeline.is_empty():
		var font = get_theme_default_font()
		var text = "Aguardando eventos..."
		var text_pos = Vector2(rect.size.x/2 - 80, rect.size.y/2)
		chart_area.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
		return
	
	# Draw background
	chart_area.draw_rect(available_rect, Color(0.05, 0.05, 0.05, 0.8))
	
	var font = get_theme_default_font()
	var colors = get_event_colors()
	var line_height = 20
	var max_lines = int(available_rect.size.y / line_height) - 1
	
	# Show most recent events (reverse order)
	var start_index = max(0, event_timeline.size() - max_lines)
	
	for i in range(start_index, event_timeline.size()):
		var event = event_timeline[i]
		var line_index = i - start_index
		var y_pos = available_rect.position.y + line_index * line_height + 15
		
		var color = colors.get(event.type, Color.WHITE)
		var formatted_name = format_event_name(event.type)
		var text = "[%s] %s" % [event.display_time, formatted_name]
		
		# Draw colored circle indicator
		var circle_pos = Vector2(available_rect.position.x + 10, y_pos - 3)
		chart_area.draw_circle(circle_pos, 4, color)
		
		# Draw event text
		var text_pos = Vector2(available_rect.position.x + 25, y_pos)
		chart_area.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

func _draw_bars():
	var rect = chart_area.get_rect()
	var margin = Vector2(45, 5)   
	var bottom_margin = 25  
	var available_rect = Rect2(
		margin.x, 
		margin.y, 
		rect.size.x - margin.x - 2,   # MARGEM DIREITA QUASE ZERO: 5→2
		rect.size.y - margin.y - bottom_margin
	)
	
	if event_frequencies.is_empty():
		# Draw "no data" message
		var font = get_theme_default_font()
		var text = "Aguardando eventos..."
		var text_pos = Vector2(rect.size.x/2 - 80, rect.size.y/2)
		chart_area.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
		return
	
	# Draw background grid
	chart_area.draw_rect(available_rect, Color(0.1, 0.1, 0.1, 0.3))
	
	# Get all event types and sort by frequency
	var event_types = event_frequencies.keys()
	event_types.sort_custom(func(a, b): return event_frequencies[a] > event_frequencies[b])
	
	var max_freq = 0
	for freq in event_frequencies.values():
		if freq > max_freq:
			max_freq = freq
	
	if max_freq == 0:
		return
	
	var colors = get_event_colors()
	
	var font = get_theme_default_font()
	var bar_width = available_rect.size.x / event_types.size()
	
	for i in range(event_types.size()):
		var event_type = event_types[i]
		var frequency = event_frequencies[event_type]
		var bar_height = (frequency / float(max_freq)) * available_rect.size.y * 0.95  # 95% of available height - MAXIMUM usage
		var color = colors.get(event_type, Color.WHITE)
		
		var x_pos = available_rect.position.x + i * bar_width
		
		# Draw bar with border
		var bar_rect = Rect2(
			x_pos + bar_width * 0.1,  # 10% margin on each side
			available_rect.position.y + available_rect.size.y - bar_height,
			bar_width * 0.8,  # 80% width for bar
			bar_height
		)
		
		# Draw bar background (darker)
		chart_area.draw_rect(bar_rect, color * 0.7)
		# Draw bar highlight (brighter)
		var highlight_rect = Rect2(bar_rect.position, Vector2(bar_rect.size.x, bar_rect.size.y * 0.3))
		chart_area.draw_rect(highlight_rect, color * 1.3)
		
		# Draw frequency number on top - larger and better positioned
		var text = str(frequency)
		var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		var text_pos = Vector2(
			x_pos + bar_width/2 - text_size.x/2, 
			bar_rect.position.y - 8
		)
		chart_area.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
		
		# Draw event type at bottom - within margins
		var label_text = format_event_name(event_type)
		var label_size = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		var label_pos = Vector2(
			x_pos + bar_width/2 - label_size.x/2,
			available_rect.position.y + available_rect.size.y + 25  # Within bottom margin
		)
		chart_area.draw_string(font, label_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
	
	# Draw Y axis labels (frequency scale) - better positioned
	var y_steps = 4  # Less steps for cleaner look
	for i in range(y_steps + 1):
		var value = int((i / float(y_steps)) * max_freq)
		var y_pos = available_rect.position.y + available_rect.size.y - (i / float(y_steps)) * available_rect.size.y
		var label_pos = Vector2(margin.x - 45, y_pos + 4)
		chart_area.draw_string(font, label_pos, str(value), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.LIGHT_GRAY)

func format_event_name(event_type: String) -> String:
	# Better formatting for event names
	match event_type:
		"car_spawned": return "Spawned"
		"car_despawned": return "Despawned" 
		"traffic_light_changed": return "Lights"
		"car_stopped": return "Stopped"
		"car_started": return "Started"
		"car_entered_intersection": return "Enter↗"
		"car_exited_intersection": return "Exit↗"
		_: return event_type.replace("_", " ").capitalize().substr(0, 8)

func _on_toggle_mode():
	if chart_mode == "bars":
		chart_mode = "timeline"
		toggle_button.text = "📊 Barras"
		title_label.text = "📈 TIMELINE DE EVENTOS"
	else:
		chart_mode = "bars"
		toggle_button.text = "🔄 Timeline"
		title_label.text = "📈 FREQUÊNCIA DE EVENTOS"
	
	if chart_area:
		chart_area.queue_redraw()

func get_event_colors() -> Dictionary:
	return {
		"car_spawned": Color.GREEN,
		"car_despawned": Color.RED,
		"traffic_light_changed": Color.YELLOW,
		"car_stopped": Color.ORANGE,
		"car_started": Color.BLUE,
		"car_entered_intersection": Color.MAGENTA,
		"car_exited_intersection": Color.CYAN
	}

func format_time(seconds: float) -> String:
	var minutes = int(seconds / 60)
	var secs = int(seconds) % 60
	return "%02d:%02d" % [minutes, secs]

func create_event_legend(parent_container: VBoxContainer):
	# Container para a legenda - MAIS COMPACTO
	var legend_panel = Panel.new()
	legend_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legend_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	legend_panel.custom_minimum_size = Vector2(0, 140)  # REDUZIDO: 180→140 altura para mais espaço ao chart
	parent_container.add_child(legend_panel)
	
	# Margem interna
	var legend_margin = MarginContainer.new()
	legend_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legend_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	legend_margin.add_theme_constant_override("margin_left", 10)
	legend_margin.add_theme_constant_override("margin_right", 10)
	legend_margin.add_theme_constant_override("margin_top", 10)
	legend_margin.add_theme_constant_override("margin_bottom", 10)
	legend_panel.add_child(legend_margin)
	
	# VBox principal da legenda
	var legend_vbox = VBoxContainer.new()
	legend_vbox.add_theme_constant_override("separation", 8)
	legend_margin.add_child(legend_vbox)
	
	# Título da legenda - MAIS COMPACTO
	var legend_title = Label.new()
	legend_title.text = "🔍 EVENTOS DE SIMULAÇÃO DISCRETA (DES)"
	legend_title.add_theme_font_size_override("font_size", 16)  # REDUZIDO: 18→16
	legend_title.add_theme_color_override("font_color", Color.ORANGE)
	legend_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend_vbox.add_child(legend_title)
	
	# Container para os eventos em TRÊS colunas para mais compacto
	var events_hbox = HBoxContainer.new()
	events_hbox.add_theme_constant_override("separation", 15)  # REDUZIDO: 20→15
	legend_vbox.add_child(events_hbox)
	
	# Três colunas para layout mais compacto
	var left_column = VBoxContainer.new()
	left_column.add_theme_constant_override("separation", 2)  # REDUZIDO: 4→2
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	events_hbox.add_child(left_column)
	
	var middle_column = VBoxContainer.new()
	middle_column.add_theme_constant_override("separation", 2)
	middle_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	events_hbox.add_child(middle_column)
	
	var right_column = VBoxContainer.new()
	right_column.add_theme_constant_override("separation", 2)
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	events_hbox.add_child(right_column)
	
	# Eventos e suas explicações
	var event_explanations = get_event_explanations()
	var colors = get_event_colors()
	
	# Distribui eventos em 3 colunas para layout mais compacto
	var events_per_column = (event_explanations.size() + 2) / 3
	for i in range(event_explanations.size()):
		var event_info = event_explanations[i]
		var event_name = event_info.name
		var explanation = event_info.explanation
		var color = colors.get(event_name, Color.WHITE)
		
		# Criar label do evento - MAIS COMPACTO
		var event_container = HBoxContainer.new()
		event_container.add_theme_constant_override("separation", 6)  # REDUZIDO: 8→6
		
		# Círculo colorido menor
		var color_indicator = ColorRect.new()
		color_indicator.color = color
		color_indicator.custom_minimum_size = Vector2(10, 10)  # REDUZIDO: 12→10
		color_indicator.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		color_indicator.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		event_container.add_child(color_indicator)
		
		# Texto da explicação mais compacto
		var event_label = Label.new()
		event_label.text = "%s: %s" % [format_event_name(event_name), explanation]
		event_label.add_theme_font_size_override("font_size", 10)  # REDUZIDO: 12→10
		event_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		event_container.add_child(event_label)
		
		# Distribui em 3 colunas
		if i < events_per_column:
			left_column.add_child(event_container)
		elif i < events_per_column * 2:
			middle_column.add_child(event_container)
		else:
			right_column.add_child(event_container)
	
	# Explicação geral do sistema - MAIS COMPACTA
	var system_explanation = Label.new()
	system_explanation.text = "💡 DES: Cada ação gera eventos rastreáveis. Spawn/despawn controlam população, semáforos coordenam fluxo, stop/start mostram congestionamento. Frequência revela dinâmica do tráfego."
	system_explanation.add_theme_font_size_override("font_size", 10)  # REDUZIDO: 11→10
	system_explanation.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	system_explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	system_explanation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legend_vbox.add_child(system_explanation)

func get_event_explanations() -> Array:
	return [
		{"name": "car_spawned", "explanation": "Carro entra na simulação em um ponto de spawn"},
		{"name": "car_despawned", "explanation": "Carro sai da simulação ao atravessar completamente"},
		{"name": "traffic_light_changed", "explanation": "Semáforo muda de estado (verde/amarelo/vermelho)"},
		{"name": "car_stopped", "explanation": "Carro para devido a semáforo vermelho ou congestionamento"},
		{"name": "car_started", "explanation": "Carro retoma movimento após parada"},
		{"name": "car_entered_intersection", "explanation": "Carro entra na área central da interseção"},
		{"name": "car_exited_intersection", "explanation": "Carro sai completamente da área da interseção"}
	]