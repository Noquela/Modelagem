extends Control

# TABELA DE ESTATÍSTICAS PARA O PROFESSOR
# Métricas em tempo real organizadas em tabela

var event_bus: Node
var discrete_simulation: Node
var simulation_clock: Node  
var traffic_controller: Node
var car_spawner: Node

# UI Components
var stats_container: VBoxContainer
var update_timer: Timer

# Statistics data
var stats_data = {
	"simulation_time": 0.0,
	"active_cars": 0,
	"total_spawned": 0,
	"total_despawned": 0,
	"average_speed": 0.0,
	"total_stops": 0,
	"throughput": 0.0,
	"s1_s2_state": "UNKNOWN",
	"s3_state": "UNKNOWN",
	"s1_s2_timer": 0.0,
	"s3_timer": 0.0,
	"s1_s2_color": Color.WHITE,
	"s3_color": Color.WHITE
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
	
	# DEBUG: Print system references
	print("📊 StatisticsTable - Sistemas inicializados:")
	print("  - EventBus: ", event_bus != null)
	print("  - DiscreteSimulation: ", discrete_simulation != null) 
	print("  - SimulationClock: ", simulation_clock != null)
	print("  - TrafficController: ", traffic_controller != null)
	print("  - CarSpawner: ", car_spawner != null)
	
	# Subscribe to relevant events
	if event_bus:
		event_bus.subscribe("car_spawned", _on_car_spawned)
		event_bus.subscribe("car_despawned", _on_car_despawned)
		event_bus.subscribe("car_stopped", _on_car_stopped)
		print("  - Eventos subscritos com sucesso")
	else:
		print("  ❌ EventBus é null - eventos não subscritos")

func setup_ui():
	# Background panel - IMPORTANT: Capture mouse events  
	var panel = Panel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP  # Block camera rotation when over stats
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
	
	# VBox for title + stats
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin_container.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "📊 ESTATÍSTICAS EM TEMPO REAL"
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Stats container
	stats_container = VBoxContainer.new()
	stats_container.add_theme_constant_override("separation", 5)
	vbox.add_child(stats_container)

func setup_update_timer():
	update_timer = Timer.new()
	update_timer.wait_time = 1.0  # Update every 1 second
	update_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS  # Use physics process (not affected by pause)
	update_timer.timeout.connect(_update_statistics)
	add_child(update_timer)
	update_timer.start()
	
	print("📊 StatisticsTable configurado - timer a cada 1s (independente)")
	
	# Call update immediately to show initial data
	call_deferred("_update_statistics")

func _update_statistics():
	# Collect fresh data from systems
	collect_statistics_data()
	
	# Clear old labels
	for child in stats_container.get_children():
		child.queue_free()
	
	# Create new labels with current data
	create_statistics_labels()

func collect_statistics_data():
	# DEBUG: Only print every 5 seconds to avoid spam
	var should_debug = int(stats_data.simulation_time) % 5 == 0
	if should_debug:
		print("🔍 Coletando dados (%.1fs)" % stats_data.simulation_time)
	
	# Simulation time
	if simulation_clock:
		stats_data.simulation_time = simulation_clock.get_simulation_time()
	else:
		stats_data.simulation_time = 0.0
	
	# Active cars and other metrics
	if discrete_simulation:
		var active_cars = discrete_simulation.get("active_cars")
		if active_cars:
			stats_data.active_cars = active_cars.size()
			
			# Calculate average speed - improved calculation
			var total_speed = 0.0
			var count = 0
			for car_id in active_cars.keys():
				var car = active_cars[car_id]
				if car.has("current_speed") and car.current_speed > 0:
					total_speed += car.current_speed * 3.6  # Convert m/s to km/h
					count += 1
			stats_data.average_speed = total_speed / max(count, 1) if count > 0 else 0.0
			
			if should_debug:
				print("  - Carros: ", stats_data.active_cars, ", Vel: %.1f km/h" % stats_data.average_speed)
		else:
			stats_data.active_cars = 0
			stats_data.average_speed = 0.0
	
	# Spawner stats
	if car_spawner:
		# Direct property access to total_cars_spawned
		stats_data.total_spawned = car_spawner.total_cars_spawned
		stats_data.total_despawned = stats_data.total_spawned - stats_data.active_cars
		
		if should_debug:
			print("  - Total spawned: ", stats_data.total_spawned, ", Despawned: ", stats_data.total_despawned)
	else:
		stats_data.total_spawned = 0
		stats_data.total_despawned = 0
	
	# Traffic light states and timers
	if traffic_controller:
		var s1_state = traffic_controller.get_light_state("light_1")
		var s2_state = traffic_controller.get_light_state("light_2") 
		var s3_state = traffic_controller.get_light_state("light_3")
		
		stats_data.s1_s2_state = get_state_name(s1_state)
		stats_data.s3_state = get_state_name(s3_state)
		
		# Get color for each state
		stats_data.s1_s2_color = get_state_color(s1_state)
		stats_data.s3_color = get_state_color(s3_state)
		
		# Get countdown timer from traffic controller
		if traffic_controller and traffic_controller.has_method("get_time_remaining"):
			var time_remaining = traffic_controller.get_time_remaining()
			stats_data.s1_s2_timer = time_remaining
			stats_data.s3_timer = time_remaining  # Both use same timer since they're synchronized
		else:
			stats_data.s1_s2_timer = 0.0
			stats_data.s3_timer = 0.0
	
	# Calculate throughput (cars per minute)
	if stats_data.simulation_time > 0:
		stats_data.throughput = (stats_data.total_spawned / stats_data.simulation_time) * 60.0

func create_statistics_labels():
	var stats_list = [
		["⏱️ Tempo de Simulação:", format_time(stats_data.simulation_time)],
		["🚗 Carros Ativos:", str(stats_data.active_cars)],
		["📊 Total Processados:", str(stats_data.total_spawned)],
		["🏁 Total Despawned:", str(stats_data.total_despawned)],
		["", ""],  # Separator
		["⚡ Velocidade Média:", "%.1f km/h" % stats_data.average_speed],
		["🛑 Total de Paradas:", str(stats_data.total_stops)],
		["📈 Throughput:", "%.1f carros/min" % stats_data.throughput]
	]
	
	# Regular stats
	for stat in stats_list:
		var label = Label.new()
		if stat[0] == "":
			label.text = stat[1]
		else:
			label.text = stat[0] + " " + stat[1]
		label.add_theme_font_size_override("font_size", 12)
		stats_container.add_child(label)
	
	# Add separator
	var separator = Label.new()
	separator.text = ""
	stats_container.add_child(separator)
	
	# SEMÁFOROS COM CONTADORES COLORIDOS
	create_traffic_light_display("🚦 Semáforos S1/S2:", stats_data.s1_s2_state, stats_data.s1_s2_timer, stats_data.s1_s2_color)
	create_traffic_light_display("🚦 Semáforo S3:", stats_data.s3_state, stats_data.s3_timer, stats_data.s3_color)

func create_traffic_light_display(title: String, state: String, timer: float, color: Color):
	# Title with state
	var state_label = Label.new()
	state_label.text = title + " " + state
	state_label.add_theme_font_size_override("font_size", 12)
	stats_container.add_child(state_label)
	
	# Countdown timer with color
	var timer_label = Label.new()
	timer_label.text = "   ⏱️ %.1fs" % timer
	timer_label.add_theme_font_size_override("font_size", 12)
	timer_label.add_theme_color_override("font_color", color)  # Color matches traffic light
	stats_container.add_child(timer_label)

func get_state_name(state_enum) -> String:
	match state_enum:
		0: return "🔴 VERMELHO"
		1: return "🟡 AMARELO"
		2: return "🟢 VERDE"
		_: return "❓ DESCONHECIDO"

func get_state_color(state_enum) -> Color:
	match state_enum:
		0: return Color.RED
		1: return Color.YELLOW
		2: return Color.GREEN
		_: return Color.WHITE

# Removed old complex calculation function - now using direct method from traffic controller

func format_time(seconds: float) -> String:
	var minutes = int(seconds / 60)
	var secs = int(seconds) % 60
	return "%02d:%02d" % [minutes, secs]

# Event handlers
func _on_car_spawned(_car_data):
	pass  # Stats updated by timer

func _on_car_despawned(_car_data):
	pass  # Stats updated by timer

func _on_car_stopped(_car_data):
	stats_data.total_stops += 1
