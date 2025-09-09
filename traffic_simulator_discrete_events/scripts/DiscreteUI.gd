extends Control
class_name DiscreteUI

# PASSO 7 - INTERFACE PARA EVENTOS DISCRETOS
# RESPONSABILIDADE: Mostrar eventos em tempo real + controles de simulação

@onready var event_log: RichTextLabel = $RightPanel/EventLogPanel/EventLog
@onready var current_time_label: Label = $TopPanel/StatusPanel/TimeInfo/CurrentTime
@onready var queue_info_label: Label = $TopPanel/StatusPanel/TimeInfo/QueueInfo
@onready var traffic_info_label: Label = $TopPanel/StatusPanel/TrafficInfo/TrafficLights
@onready var vehicle_info_label: Label = $TopPanel/StatusPanel/VehicleInfo/Vehicles
@onready var play_pause_button: Button = $BottomPanel/PlayPauseButton
@onready var reset_button: Button = $BottomPanel/ResetButton
@onready var step_button: Button = $BottomPanel/StepButton
@onready var frequency_chart: Control = $RightPanel/FrequencyPanel/FrequencyChart

var discrete_simulator: DiscreteTrafficSimulator
var max_log_lines: int = 50
var current_log_lines: int = 0
var ui_visible: bool = true

# Tracking de frequência de eventos
var event_frequency: Dictionary = {}
var total_events: int = 0

func _ready():
	print("🎮 DiscreteUI inicializando...")
	setup_ui()
	connect_signals()
	
	# Conectar sinal de desenho do gráfico
	if frequency_chart:
		frequency_chart.draw.connect(_draw_frequency_chart)

func setup_ui():
	# Configurar interface
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Encontrar o simulador discreto
	var main_scene = get_tree().current_scene
	discrete_simulator = main_scene.find_child("DiscreteTrafficSimulator")
	
	if discrete_simulator:
		print("✅ DiscreteUI conectado ao simulador")
	else:
		print("❌ DiscreteUI não conseguiu encontrar o simulador")
		return
	
	# Configurar log de eventos
	if event_log:
		event_log.bbcode_enabled = true
		event_log.add_theme_font_size_override("normal_font_size", 18)
		event_log.text = "[color=lightgreen]📋 Log de Eventos Discretos[/color]\n"
		event_log.text += "[color=gray]Aguardando eventos...[/color]\n"
	
	# Configurar botões
	if play_pause_button:
		play_pause_button.text = "⏸️ Pause"
		play_pause_button.pressed.connect(_on_play_pause_pressed)
	
	if reset_button:
		reset_button.text = "🔄 Reset"  
		reset_button.pressed.connect(_on_reset_pressed)
	
	if step_button:
		step_button.text = "⏭️ Step"
		step_button.pressed.connect(_on_step_pressed)

func connect_signals():
	if not discrete_simulator:
		return
		
	# Conectar sinais do simulador
	discrete_simulator.event_executed.connect(_on_event_executed)
	discrete_simulator.simulation_started.connect(_on_simulation_started)
	discrete_simulator.simulation_paused.connect(_on_simulation_paused)
	discrete_simulator.simulation_reset.connect(_on_simulation_reset)
	
	print("🔗 Sinais do simulador conectados à UI")

func _process(_delta):
	update_status_info()

func _input(event):
	# Toggle UI com tecla H
	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		toggle_ui_visibility()
	
	# Atalhos de teclado adicionais
	elif event.is_action_pressed("ui_accept"):  # Enter
		_on_step_pressed()
	elif event.is_action_pressed("ui_cancel"): # Escape
		_on_reset_pressed()

func toggle_ui_visibility():
	ui_visible = !ui_visible
	visible = ui_visible
	print("🎮 UI %s" % ("mostrada" if ui_visible else "oculta"))

func update_status_info():
	if not discrete_simulator:
		return
	
	var scheduler = discrete_simulator.scheduler
	var traffic_system = discrete_simulator.traffic_light_system  
	var vehicle_system = discrete_simulator.vehicle_system
	
	# Atualizar tempo atual (interpolado para visualização contínua)
	if current_time_label and scheduler:
		current_time_label.text = "⏱️ Tempo: %.2fs" % scheduler.get_displayed_time()
	
	# Atualizar info da fila (detalhada)
	if queue_info_label and scheduler:
		var queue_count = scheduler.get_events_count()
		var queue_details = scheduler.get_queue_info()
		var next_time = scheduler.get_next_event_time()
		
		var fila_text = "📋 Fila: %d eventos" % queue_count
		if next_time >= 0:
			fila_text += "\n⏳ Próximo: t=%.2fs" % next_time
		else:
			fila_text += "\n⏳ Próximo: --"
		
		# Adicionar detalhes dos próximos eventos
		if queue_details != "Fila vazia":
			fila_text += "\n" + queue_details
		
		queue_info_label.text = fila_text
	
	# Atualizar info dos semáforos
	if traffic_info_label and traffic_system:
		traffic_info_label.text = traffic_system.get_traffic_lights_info()
	
	# Atualizar info dos veículos
	if vehicle_info_label and vehicle_system:
		vehicle_info_label.text = vehicle_system.get_vehicles_info()
	
	# Atualizar gráfico de frequência
	update_frequency_chart()

func _on_event_executed(event: DiscreteEvent):
	add_event_to_log(event)
	track_event_frequency(event)

func add_event_to_log(event: DiscreteEvent):
	if not event_log:
		return
	
	# Obter cor do evento
	var color = EventTypes.get_event_color(event.type)
	var color_hex = color.to_html()
	var event_name = EventTypes.get_event_name(event.type)
	
	# Adicionar linha ao log
	var log_line = "[color=%s]t=%.2f: %s[/color]\n" % [color_hex, event.time, event_name]
	event_log.text += log_line
	
	# Limitar número de linhas
	current_log_lines += 1
	if current_log_lines > max_log_lines:
		var lines = event_log.text.split("\n")
		var new_lines = lines.slice(lines.size() - max_log_lines)
		event_log.text = "\n".join(new_lines)
		current_log_lines = max_log_lines
	
	# Auto-scroll para o final
	await get_tree().process_frame
	event_log.scroll_to_line(event_log.get_line_count() - 1)

func _on_play_pause_pressed():
	if not discrete_simulator:
		return
	
	var scheduler = discrete_simulator.scheduler
	if not scheduler:
		return
	
	if scheduler.is_running:
		discrete_simulator.pause_simulation()
		play_pause_button.text = "▶️ Play"
	else:
		discrete_simulator.start_simulation()
		play_pause_button.text = "⏸️ Pause"

func _on_reset_pressed():
	if not discrete_simulator:
		return
	
	discrete_simulator.reset_simulation()
	
	# Limpar log
	if event_log:
		event_log.text = "[color=lightgreen]📋 Log de Eventos Discretos[/color]\n"
		event_log.text += "[color=yellow]🔄 Simulação resetada[/color]\n"
		current_log_lines = 2
	
	# Resetar botão
	play_pause_button.text = "▶️ Play"

func _on_step_pressed():
	if not discrete_simulator:
		return
	
	var advanced = discrete_simulator.step_simulation()
	if not advanced:
		add_log_message("🏁 Não há mais eventos para processar", Color.ORANGE)

func _on_simulation_started():
	add_log_message("▶️ Simulação iniciada", Color.LIME_GREEN)
	if play_pause_button:
		play_pause_button.text = "⏸️ Pause"

func _on_simulation_paused():
	add_log_message("⏸️ Simulação pausada", Color.YELLOW)
	if play_pause_button:
		play_pause_button.text = "▶️ Play"

func _on_simulation_reset():
	add_log_message("🔄 Simulação resetada", Color.CYAN)
	if play_pause_button:
		play_pause_button.text = "▶️ Play"
	
	# Reset frequency tracking
	event_frequency.clear()
	total_events = 0

func add_log_message(message: String, color: Color):
	if not event_log:
		return
	
	var color_hex = color.to_html()
	var log_line = "[color=%s]%s[/color]\n" % [color_hex, message]
	event_log.text += log_line
	
	current_log_lines += 1
	if current_log_lines > max_log_lines:
		var lines = event_log.text.split("\n")
		var new_lines = lines.slice(lines.size() - max_log_lines)
		event_log.text = "\n".join(new_lines)
		current_log_lines = max_log_lines

# TRACKING DE FREQUÊNCIA DE EVENTOS
func track_event_frequency(event: DiscreteEvent):
	var event_name = EventTypes.get_event_name(event.type)
	
	if event_name in event_frequency:
		event_frequency[event_name] += 1
	else:
		event_frequency[event_name] = 1
	
	total_events += 1

# GRÁFICO DE DISTRIBUIÇÃO DE FREQUÊNCIA
func update_frequency_chart():
	if not frequency_chart:
		return
	
	# Força redesenho do gráfico
	frequency_chart.queue_redraw()

func _draw_frequency_chart():
	if not frequency_chart or total_events == 0:
		return
	
	var chart_size = frequency_chart.size
	var margin = 30
	var bottom_margin = 60  # Margem maior para nomes dos eventos
	var bar_width = 60  # Barras muito mais largas
	var max_height = chart_size.y - margin - bottom_margin
	
	# Encontrar frequência máxima para escala
	var max_frequency = 0
	for freq in event_frequency.values():
		if freq > max_frequency:
			max_frequency = freq
	
	if max_frequency == 0:
		return
	
	# Desenhar barras
	var x_offset = margin
	var event_names = event_frequency.keys()
	var available_width = chart_size.x - margin * 2
	var min_bar_spacing = bar_width + 15  # Espaçamento mínimo entre barras
	var bar_spacing = max(min_bar_spacing, available_width / max(event_names.size(), 1))
	
	for i in event_names.size():
		if x_offset + bar_width > chart_size.x - margin:
			break  # Não cabem mais barras
			
		var event_name = event_names[i]
		var frequency = event_frequency[event_name]
		var percentage = float(frequency) / total_events * 100
		
		# Altura da barra proporcional
		var bar_height = (float(frequency) / max_frequency) * max_height
		
		# Cor baseada no tipo de evento
		var color = Color.CYAN
		if "SEMAFORO" in event_name:
			color = Color.YELLOW
		elif "SPAWN" in event_name:
			color = Color.LIME_GREEN
		elif "CARRO" in event_name:
			color = Color.DODGER_BLUE
		
		# Desenhar barra
		var rect = Rect2(x_offset, chart_size.y - bottom_margin - bar_height, bar_width, bar_height)
		frequency_chart.draw_rect(rect, color)
		
		# Desenhar borda
		frequency_chart.draw_rect(rect, Color.WHITE, false, 1)
		
		# Desenhar texto (frequência) acima da barra
		var font = ThemeDB.fallback_font
		var font_size = 16  # Fonte muito maior
		var freq_text = str(frequency)
		var freq_text_size = font.get_string_size(freq_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var freq_text_pos = Vector2(x_offset + bar_width/2 - freq_text_size.x/2, chart_size.y - bottom_margin - bar_height - 5)
		frequency_chart.draw_string(font, freq_text_pos, freq_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
		
		# Desenhar nome do evento abaixo da barra (rotacionado e truncado)
		var name_font_size = 14  # Fonte maior para nomes
		var short_name = event_name.substr(0, 12)  # Truncar nome se muito longo
		if event_name.length() > 12:
			short_name += "..."
		var name_text_size = font.get_string_size(short_name, HORIZONTAL_ALIGNMENT_CENTER, -1, name_font_size)
		var name_text_pos = Vector2(x_offset + bar_width/2 - name_text_size.x/2, chart_size.y - bottom_margin + 15)
		frequency_chart.draw_string(font, name_text_pos, short_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_font_size, Color.LIGHT_GRAY)
		
		x_offset += bar_spacing
	
	# Auto-scroll
	await get_tree().process_frame
	event_log.scroll_to_line(event_log.get_line_count() - 1)
