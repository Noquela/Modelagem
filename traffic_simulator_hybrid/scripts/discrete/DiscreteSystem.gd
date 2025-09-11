# scripts/discrete/DiscreteSystem.gd
class_name DiscreteSystem
extends Node

## Sistema discreto integrado

var scheduler: DiscreteEventScheduler
var spawn_system: DiscreteSpawnSystem  
var traffic_manager: DiscreteTrafficManager
var hybrid_renderer

var is_running: bool = false
var simulation_time: float = 0.0

func _ready():
	setup_discrete_system()

func setup_discrete_system():
	"""Inicializa sistema discreto completo"""
	print("⚙️ Setting up discrete system components...")
	
	# Criar componentes em ordem correta
	scheduler = DiscreteEventScheduler.new()
	traffic_manager = DiscreteTrafficManager.new(scheduler)
	spawn_system = DiscreteSpawnSystem.new(scheduler, traffic_manager)
	
	# Conectar eventos para spawn de carros
	scheduler.event_executed.connect(_on_discrete_event)
	
	print("✅ Discrete system initialized")

func connect_hybrid_renderer(renderer):
	"""Conecta renderer híbrido"""
	hybrid_renderer = renderer
	print("🔗 DiscreteSystem connected to HybridRenderer")

func start_simulation():
	"""Inicia simulação discreta"""
	is_running = true
	set_process(true)
	print("🚀 DiscreteSystem simulation started")

func _process(delta):
	if not is_running:
		return
		
	simulation_time += delta
	
	# Processar eventos até tempo atual
	if scheduler:
		scheduler.process_events_until(simulation_time)

func _on_discrete_event(event: DiscreteEvent):
	"""Handler para eventos discretos"""
	match event.type:
		DiscreteEventScheduler.EventType.CAR_SPAWN:
			if spawn_system:
				spawn_system.handle_spawn_event(event.data)
		DiscreteEventScheduler.EventType.CAR_ARRIVE_INTERSECTION:
			handle_car_intersection_arrival(event.data)
		DiscreteEventScheduler.EventType.CAR_START_WAITING:
			handle_car_start_waiting(event.data)
		DiscreteEventScheduler.EventType.CAR_START_CROSSING:
			handle_car_start_crossing(event.data)
		DiscreteEventScheduler.EventType.CAR_EXIT_INTERSECTION:
			handle_car_exit_intersection(event.data)
		DiscreteEventScheduler.EventType.CAR_EXIT_MAP:
			handle_car_exit_map(event.data)
		DiscreteEventScheduler.EventType.LIGHT_CHANGE:
			if traffic_manager:
				traffic_manager.handle_light_change_event(event.data)

func handle_car_intersection_arrival(event_data: Dictionary):
	"""Processa chegada na intersecção"""
	var car_id = event_data.car_id
	var car = spawn_system.get_car_by_id(car_id)
	if not car:
		return
	
	# Criar journey para processar decisão
	var journey = DiscreteCarJourney.new(car, scheduler, traffic_manager, spawn_system)
	journey.handle_intersection_arrival(event_data)

func handle_car_start_waiting(event_data: Dictionary):
	print("⏳ Car %d started waiting" % event_data.car_id)

func handle_car_start_crossing(event_data: Dictionary):
	print("🔄 Car %d started crossing intersection" % event_data.car_id)

func handle_car_exit_intersection(event_data: Dictionary):
	print("✅ Car %d exited intersection" % event_data.car_id)

func handle_car_exit_map(event_data: Dictionary):
	var car_id = event_data.car_id
	print("🏁 Car %d exited map" % car_id)
	
	# Remover carro da lista ativa
	if spawn_system:
		spawn_system.remove_car(car_id)
