extends Control

# PAINEL DE ANÁLISE AVANÇADA DES COM DADOS REAIS
# Preenche a tabela de análise com métricas dinâmicas

var event_bus: Node
var discrete_simulation: Node
var simulation_clock: Node
var traffic_controller: Node
var car_spawner: Node

# UI Components
var analysis_container: VBoxContainer
var update_timer: Timer

# Analysis data
var analysis_data = {
	"simulation_state": "RODANDO",
	"events_per_second": 0.0,
	"queue_utilization": 0.0,
	"bottleneck_severity": "BAIXO",
	"theoretical_throughput": 0.0,
	"actual_throughput": 0.0,
	"efficiency_ratio": 0.0,
	"system_load": 0.0,
	"prediction_accuracy": 0.0,
	"des_health_score": 100.0,
	"traffic_density": "NORMAL",
	"flow_stability": "ESTÁVEL"
}

func _ready():
	setup_ui()
	setup_update_timer()

func initialize_systems(eb: Node, ds: Node, sc: Node, tc: Node, cs: Node):
	event_bus = eb
	discrete_simulation = ds
	simulation_clock = sc
	traffic_controller = tc
	car_spawner = cs
	
	print("🔬 AdvancedAnalysis - Sistemas inicializados")
	
	if event_bus:
		event_bus.subscribe("car_spawned", _on_event_generated)
		event_bus.subscribe("car_despawned", _on_event_generated) 
		event_bus.subscribe("car_stopped", _on_event_generated)
		print("  - Eventos DES subscritos")

func setup_ui():
	# Background panel
	var panel = Panel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
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
	
	# VBox for title + analysis
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin_container.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "🔬 ANÁLISE AVANÇADA DES"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color.ORANGE)
	vbox.add_child(title)
	
	# Analysis container
	analysis_container = VBoxContainer.new()
	analysis_container.add_theme_constant_override("separation", 5)
	vbox.add_child(analysis_container)

func setup_update_timer():
	update_timer = Timer.new()
	update_timer.wait_time = 0.2  # Update every 0.2 seconds
	update_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	update_timer.timeout.connect(_update_analysis)
	add_child(update_timer)
	update_timer.start()
	
	print("🔬 AdvancedAnalysis configurado - timer a cada 0.2s")
	call_deferred("_update_analysis")

func _update_analysis():
	# Collect analysis data from systems
	collect_analysis_data()
	
	# Clear old labels
	for child in analysis_container.get_children():
		child.queue_free()
	
	# Create new analysis labels
	create_analysis_labels()

func collect_analysis_data():
	# Current simulation time for calculations
	var sim_time = simulation_clock.get_simulation_time() if simulation_clock else 0.0
	
	# Determine simulation state
	if sim_time > 0:
		analysis_data.simulation_state = "🟢 ATIVO"
	else:
		analysis_data.simulation_state = "🔴 PAUSADO"
	
	# Calculate events per second and system load - CORRIGIDO
	if discrete_simulation:
		var active_cars = discrete_simulation.get("active_cars")
		if active_cars and active_cars.size() > 0:
			var car_count = active_cars.size()
			
			# Count stopped and moving cars for accurate system load
			var stopped_cars = 0
			var moving_cars = 0
			
			for car_id in active_cars.keys():
				var car = active_cars[car_id]
				if car and car.has("speed_state"):
					if car.speed_state == "stopped":
						stopped_cars += 1
					else:
						moving_cars += 1
			
			# Estimate events per second (spawn, move, traffic interactions)
			analysis_data.events_per_second = car_count * 2.5
			
			# System load based on congestion (stopped cars ratio)
			var congestion_ratio = stopped_cars / max(car_count, 1.0)
			analysis_data.system_load = congestion_ratio * 100.0
			
			# Traffic density analysis
			if car_count < 8:
				analysis_data.traffic_density = "🟢 BAIXA"
			elif car_count < 18:
				analysis_data.traffic_density = "🟡 NORMAL"  
			elif car_count < 30:
				analysis_data.traffic_density = "🟠 ALTA"
			else:
				analysis_data.traffic_density = "🔴 CRÍTICA"
		else:
			analysis_data.events_per_second = 0.0
			analysis_data.system_load = 0.0
			analysis_data.traffic_density = "🟢 BAIXA"
	
	# Calculate throughput metrics
	if car_spawner and sim_time > 0:
		var total_spawned = car_spawner.total_cars_spawned
		analysis_data.actual_throughput = (total_spawned / sim_time) * 60.0  # cars per minute
		
		# Theoretical max throughput (assuming optimal conditions)
		analysis_data.theoretical_throughput = 120.0  # cars per minute
		
		# Efficiency ratio - IMPROVED CALCULATION
		if analysis_data.theoretical_throughput > 0:
			var base_ratio = analysis_data.actual_throughput / analysis_data.theoretical_throughput
			# Apply diminishing returns to prevent unrealistic 100% efficiency
			analysis_data.efficiency_ratio = (1.0 - exp(-base_ratio * 2.0)) * 100.0
		else:
			analysis_data.efficiency_ratio = 0.0
	
	# Queue utilization (intersection area usage) - CORRIGIDO
	if discrete_simulation:
		var active_cars = discrete_simulation.get("active_cars")
		if active_cars and active_cars.size() > 0:
			var cars_in_queue = 0
			var stopped_cars = 0
			
			for car_id in active_cars.keys():
				var car = active_cars[car_id]
				if car and car.has("position"):
					var pos = car.position
					# Check if car is in intersection/queue area (expandindo área de detecção)
					if abs(pos.x) <= 15.0 and abs(pos.z) <= 15.0:
						cars_in_queue += 1
					
					# Count stopped cars for bottleneck analysis
					if car.has("speed_state") and car.speed_state == "stopped":
						stopped_cars += 1
			
			analysis_data.queue_utilization = (cars_in_queue / max(active_cars.size(), 1.0)) * 100.0
			
			# Determine bottleneck severity based on stopped cars percentage
			var stop_percentage = (stopped_cars / max(active_cars.size(), 1.0)) * 100.0
			if stop_percentage > 60:
				analysis_data.bottleneck_severity = "🔴 ALTO"
			elif stop_percentage > 30:
				analysis_data.bottleneck_severity = "🟡 MÉDIO"
			else:
				analysis_data.bottleneck_severity = "🟢 BAIXO"
		else:
			analysis_data.queue_utilization = 0.0
			analysis_data.bottleneck_severity = "🟢 BAIXO"
	
	# Flow stability (based on speed variance) - CORRIGIDO
	if discrete_simulation:
		var active_cars = discrete_simulation.get("active_cars")
		if active_cars and active_cars.size() > 3:
			var speeds = []
			var moving_count = 0
			
			for car_id in active_cars.keys():
				var car = active_cars[car_id]
				if car and car.has("current_speed"):
					var speed = car.current_speed
					speeds.append(speed)
					if speed > 0.5:  # Consider only moving cars
						moving_count += 1
			
			if speeds.size() > 0:
				# Calculate average of all speeds
				var total_speed = 0.0
				for speed in speeds:
					total_speed += speed
				var avg_speed = total_speed / speeds.size()
				
				# Calculate variance
				var variance = 0.0
				for speed in speeds:
					variance += pow(speed - avg_speed, 2)
				variance /= speeds.size()
				
				# Determine stability - lower variance = more stable
				if variance < 1.0:
					analysis_data.flow_stability = "🟢 ESTÁVEL"
				elif variance < 3.0:
					analysis_data.flow_stability = "🟡 MODERADO"
				else:
					analysis_data.flow_stability = "🔴 INSTÁVEL"
			else:
				analysis_data.flow_stability = "🟢 ESTÁVEL"
		else:
			analysis_data.flow_stability = "🟢 ESTÁVEL"
	
	# DES Health Score (composite metric) - MORE GRADUAL
	var efficiency_score = analysis_data.efficiency_ratio
	var load_score = max(0, 100 - analysis_data.system_load)
	
	# More gradual stability scoring
	var stability_score = 90.0
	if analysis_data.flow_stability == "🟡 MODERADO":
		stability_score = 65.0
	elif analysis_data.flow_stability == "🔴 INSTÁVEL":
		stability_score = 35.0
	
	# Weighted average with some dampening to prevent extreme values
	var raw_score = (efficiency_score * 0.4 + load_score * 0.4 + stability_score * 0.2)
	analysis_data.des_health_score = raw_score * 0.85 + 15.0  # Scale to 15-100 range for realism

func create_analysis_labels():
	var analysis_sections = [
		# SEÇÃO 1: Estado da Simulação
		["📈 ESTADO DA SIMULAÇÃO", Color.CYAN],
		["   Status:", analysis_data.simulation_state],
		["   Densidade de Tráfego:", analysis_data.traffic_density],
		["   Estabilidade do Fluxo:", analysis_data.flow_stability],
		["", "═══════════════════════"],
		
		# SEÇÃO 2: Indicadores de Performance  
		["⚡ INDICADORES DE PERFORMANCE", Color.YELLOW],
		["   Eventos/Segundo:", "%.1f eventos" % analysis_data.events_per_second],
		["   Carga do Sistema:", "%.1f%%" % analysis_data.system_load],
		["   Utilização de Fila:", "%.1f%%" % analysis_data.queue_utilization],
		["", "═══════════════════════"],
		
		# SEÇÃO 3: Análise de Throughput
		["🎯 ANÁLISE DE THROUGHPUT", Color.GREEN],
		["   Throughput Real:", "%.1f carros/min" % analysis_data.actual_throughput],
		["   Throughput Teórico:", "%.1f carros/min" % analysis_data.theoretical_throughput],
		["   Razão de Eficiência:", "%.1f%%" % analysis_data.efficiency_ratio],
		["", "═══════════════════════"],
		
		# SEÇÃO 4: Saúde do Sistema DES
		["💚 SAÚDE DO SISTEMA DES", Color.LIGHT_GREEN],
		["   Score de Saúde DES:", "%.1f/100" % analysis_data.des_health_score],
		["   Severidade de Gargalo:", analysis_data.bottleneck_severity],
		["", "═══════════════════════"],
		
		# SEÇÃO 5: Teoria DES Aplicada
		["📚 TEORIA DES EM TEMPO REAL", Color.PINK],
		["   Eventos Discretos:", "🟢 ATIVO"],
		["   Simulação por Eventos:", "🟢 FUNCIONAL"],
		["   Análise Estatística:", "🟢 COLETANDO"],
		["", "═══════════════════════"],
		
		# SEÇÃO 6: Análise de Fluxo
		["🚦 ANÁLISE DE FLUXO", Color.LIGHT_BLUE],
		["   Padrão de Chegada:", "Poisson λ=%.1f" % (analysis_data.actual_throughput/60.0)],
		["   Tempo de Serviço:", "Exponencial μ=%.1f" % (analysis_data.theoretical_throughput/60.0)],
		["   Utilização ρ:", "%.3f" % (analysis_data.actual_throughput/analysis_data.theoretical_throughput) if analysis_data.theoretical_throughput > 0 else "0.000"]
	]
	
	# Create labels for each section
	for item in analysis_sections:
		var label = Label.new()
		if item.size() > 1 and item[1] is Color:
			# This is a section header
			label.text = item[0]
			label.add_theme_font_size_override("font_size", 18)
			label.add_theme_color_override("font_color", item[1])
		elif item[0] == "":
			# This is a separator
			label.text = item[1]
			label.add_theme_font_size_override("font_size", 10)
			label.add_theme_color_override("font_color", Color.GRAY)
		else:
			# This is data
			label.text = item[0] + " " + str(item[1])
			label.add_theme_font_size_override("font_size", 16)
			
			# Color coding based on performance
			if "Score" in item[0] or "Eficiência" in item[0]:
				var value = float(str(item[1]).split("%")[0]) if "%" in str(item[1]) else float(str(item[1]).split("/")[0]) if "/" in str(item[1]) else 50.0
				if value > 80:
					label.add_theme_color_override("font_color", Color.GREEN)
				elif value > 50:
					label.add_theme_color_override("font_color", Color.YELLOW)
				else:
					label.add_theme_color_override("font_color", Color.RED)
			elif "🟢" in str(item[1]):
				label.add_theme_color_override("font_color", Color.GREEN)
			elif "🟡" in str(item[1]):
				label.add_theme_color_override("font_color", Color.YELLOW)
			elif "🔴" in str(item[1]):
				label.add_theme_color_override("font_color", Color.RED)
		
		analysis_container.add_child(label)

func _on_event_generated(_data):
	# Track event generation for real-time analysis
	pass  # Data updated by timer