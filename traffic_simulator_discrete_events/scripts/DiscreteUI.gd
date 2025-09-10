extends Control

## UI para o simulador de tráfego baseado em eventos discretos

# Referencias aos labels
@onready var time_label = $InfoPanel/VBoxContainer/TimeLabel
@onready var status_label = $InfoPanel/VBoxContainer/StatusLabel  
@onready var events_label = $InfoPanel/VBoxContainer/EventsLabel

# Referencia ao simulador
var simulator: DiscreteTrafficSimulator

func _ready():
	# Buscar o simulador na cena
	simulator = get_parent()
	
	if simulator:
		# Conectar sinais
		simulator.simulation_started.connect(_on_simulation_started)
		simulator.simulation_stopped.connect(_on_simulation_stopped)
		simulator.simulation_paused.connect(_on_simulation_paused)
		simulator.simulation_resumed.connect(_on_simulation_resumed)
		simulator.stats_updated.connect(_on_stats_updated)
	
	print("DiscreteUI initialized")

func _process(_delta):
	if simulator:
		update_display()

func update_display():
	# Atualizar tempo
	if time_label:
		time_label.text = "Simulation Time: %s" % simulator.get_formatted_time()
	
	# Atualizar status
	if status_label:
		var status = "Running" if simulator.is_running else "Stopped"
		if simulator.simulation_clock and simulator.simulation_clock.is_paused:
			status = "Paused"
		status_label.text = "Status: %s (Speed: %.1fx)" % [status, simulator.simulation_speed]
	
	# Atualizar eventos e veículos
	if events_label and simulator.event_scheduler:
		var pending = simulator.event_scheduler.get_pending_events_count()
		var total_executed = simulator.event_scheduler.total_events_executed
		var vehicles_info = ""
		
		if simulator.vehicle_manager:
			var active_cars = simulator.vehicle_manager.get_active_car_count()
			var total_spawned = simulator.vehicle_manager.get_total_cars_spawned()
			var avg_wait = simulator.vehicle_manager.get_average_wait_time()
			vehicles_info = " | Cars: %d/%d | Wait: %.1fs" % [active_cars, total_spawned, avg_wait]
		
		events_label.text = "Events - Pending: %d, Executed: %d%s" % [pending, total_executed, vehicles_info]

func _on_simulation_started():
	print("UI: Simulation started")

func _on_simulation_stopped():
	print("UI: Simulation stopped")

func _on_simulation_paused():
	print("UI: Simulation paused")

func _on_simulation_resumed():
	print("UI: Simulation resumed")

func _on_stats_updated(stats: Dictionary):
	# Atualizar estatísticas mais detalhadas se necessário
	pass