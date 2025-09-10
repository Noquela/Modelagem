class_name DiscreteTrafficSimulator
extends Node

## Sistema principal do simulador de tráfego baseado em eventos discretos
## Integra todos os componentes e coordena a simulação

# Componentes principais
var event_scheduler: DiscreteEventScheduler
var simulation_clock: SimulationClock

# Estado da simulação
var is_running: bool = false
var simulation_speed: float = 1.0

# Timer para updates regulares
var update_timer: float = 0.0
var update_interval: float = 0.016  # ~60 FPS

# Estatísticas
var frame_count: int = 0
var last_stats_time: float = 0.0

# Signals para UI
signal simulation_started()
signal simulation_stopped()
signal simulation_paused()
signal simulation_resumed()
signal stats_updated(stats: Dictionary)

func _ready():
	setup_simulation()
	create_test_events()  # Para validar Sprint 1
	print("DiscreteTrafficSimulator initialized")

func _process(delta):
	if not is_running:
		return
	
	update_timer += delta
	if update_timer >= update_interval:
		update_simulation(update_timer)
		update_timer = 0.0

func setup_simulation():
	# Criar componentes principais
	simulation_clock = SimulationClock.new(0.0)
	event_scheduler = DiscreteEventScheduler.new(simulation_clock)
	
	# Conectar sinais
	event_scheduler.event_executed.connect(_on_event_executed)
	event_scheduler.entity_created.connect(_on_entity_created)
	event_scheduler.entity_destroyed.connect(_on_entity_destroyed)
	
	print("Simulation components created")

func update_simulation(delta_time: float):
	# Atualizar relógio
	simulation_clock.update(delta_time)
	
	# Processar eventos até o tempo atual
	var current_time = simulation_clock.get_time()
	var events_processed = event_scheduler.process_events_until(current_time)
	
	# Atualizar estatísticas
	frame_count += 1
	if current_time - last_stats_time >= 1.0:  # A cada segundo
		emit_statistics()
		last_stats_time = current_time

func emit_statistics():
	var stats = get_simulation_statistics()
	stats_updated.emit(stats)

## ============================================================================
## CONTROLES DA SIMULAÇÃO
## ============================================================================

func start_simulation():
	if not is_running:
		is_running = true
		simulation_clock.resume()
		simulation_started.emit()
		print("Simulation STARTED at time %.2f" % simulation_clock.get_time())

func stop_simulation():
	if is_running:
		is_running = false
		simulation_clock.pause()
		simulation_stopped.emit()
		print("Simulation STOPPED at time %.2f" % simulation_clock.get_time())

func pause_simulation():
	if is_running:
		simulation_clock.pause()
		simulation_paused.emit()
		print("Simulation PAUSED")

func resume_simulation():
	if is_running:
		simulation_clock.resume()
		simulation_resumed.emit()
		print("Simulation RESUMED")

func reset_simulation():
	stop_simulation()
	event_scheduler.clear_all()
	simulation_clock.reset()
	frame_count = 0
	last_stats_time = 0.0
	print("Simulation RESET")

func set_simulation_speed(speed: float):
	simulation_speed = clamp(speed, 0.1, 10.0)
	simulation_clock.set_speed(simulation_speed)
	print("Simulation speed set to %.1fx" % simulation_speed)

## ============================================================================
## MÉTODOS PÚBLICOS PARA INTERFACE
## ============================================================================

func get_current_time() -> float:
	return simulation_clock.get_time()

func get_formatted_time() -> String:
	return simulation_clock.format_time()

func schedule_event(event: DiscreteEvent) -> void:
	event_scheduler.schedule_event(event)

func predict_entity_position(entity_id: int, target_time: float) -> Vector3:
	return event_scheduler.predict_entity_position_at_time(entity_id, target_time)

func get_future_events_for_entity(entity_id: int, time_window: float) -> Array[DiscreteEvent]:
	return event_scheduler.get_future_events_for_entity(entity_id, time_window)

## ============================================================================
## ESTATÍSTICAS
## ============================================================================

func get_simulation_statistics() -> Dictionary:
	var scheduler_stats = event_scheduler.get_statistics()
	var clock_stats = simulation_clock.get_status()
	
	return {
		"is_running": is_running,
		"frame_count": frame_count,
		"simulation_speed": simulation_speed,
		"scheduler": scheduler_stats,
		"clock": clock_stats
	}

## ============================================================================
## HANDLERS DE EVENTOS
## ============================================================================

func _on_event_executed(event: DiscreteEvent):
	# Handler para quando um evento é executado
	# Será expandido nos próximos sprints
	pass

func _on_entity_created(entity_id: int):
	# Handler para criação de entidade
	print("Entity created: %d" % entity_id)

func _on_entity_destroyed(entity_id: int):
	# Handler para destruição de entidade  
	print("Entity destroyed: %d" % entity_id)

## ============================================================================
## SISTEMA DE TESTES DO SPRINT 1
## ============================================================================

func create_test_events():
	print("Creating test events for Sprint 1 validation...")
	
	# Teste 1: Eventos de spawn de carros
	var spawn_times = [1.0, 2.5, 4.0, 6.2, 8.1]
	for i in range(spawn_times.size()):
		var spawn_event = DiscreteEvent.new(spawn_times[i], DiscreteEvent.EventType.CAR_SPAWN, i)
		spawn_event.data = {"spawn_point": "west", "position": Vector3(-30, 0, 0)}
		event_scheduler.schedule_event(spawn_event)
		event_scheduler.register_entity(i, {"type": "car", "spawn_time": spawn_times[i]})
	
	# Teste 2: Eventos de semáforo
	var light_times = [0.0, 20.0, 23.0, 24.0, 34.0, 37.0]  # Ciclo de 40s
	var light_states = ["green", "yellow", "red", "green", "yellow", "red"]
	for i in range(light_times.size()):
		var light_event = DiscreteEvent.new(light_times[i], DiscreteEvent.EventType.LIGHT_CHANGE, -1)
		light_event.data = {"light_id": "main_road", "state": light_states[i]}
		event_scheduler.schedule_event(light_event)
	
	# Teste 3: Eventos de chegada na intersecção
	var arrival_times = [8.5, 12.3, 15.7, 18.9, 22.4]
	for i in range(arrival_times.size()):
		var arrival_event = DiscreteEvent.new(arrival_times[i], DiscreteEvent.EventType.CAR_ARRIVAL, i)
		arrival_event.data = {"intersection": "main", "position": Vector3(-5, 0, 0)}
		event_scheduler.schedule_event(arrival_event)
	
	print("Created %d test events" % (spawn_times.size() + light_times.size() + arrival_times.size()))

func run_validation_test():
	print("=== SPRINT 1 VALIDATION TEST ===")
	
	# Test 1: Verificar agendamento
	print("Test 1: Event scheduling")
	var test_event = DiscreteEvent.new(10.0, DiscreteEvent.EventType.CAR_SPAWN, 999)
	event_scheduler.schedule_event(test_event)
	print("Events scheduled: %d" % event_scheduler.get_pending_events_count())
	
	# Test 2: Verificar execução de eventos
	print("\nTest 2: Event execution")
	start_simulation()
	
	# Simular por alguns segundos
	for i in range(100):  # 100 frames
		update_simulation(0.1)  # 0.1 segundos por frame
	
	var stats = get_simulation_statistics()
	print("Events executed: %d" % stats.scheduler.total_executed)
	
	# Test 3: Testar predição
	print("\nTest 3: Position prediction")
	var predicted_pos = event_scheduler.predict_entity_position_at_time(0, get_current_time() + 5.0)
	print("Predicted position for entity 0 in +5s: %s" % predicted_pos)
	
	# Test 4: Debug info
	print("\nTest 4: System status")
	event_scheduler.print_debug_info()
	
	print("\n=== SPRINT 1 VALIDATION COMPLETE ===")

## Input handling para testes
func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				start_simulation()
			KEY_2:
				stop_simulation()
			KEY_3:
				pause_simulation() if not simulation_clock.is_paused else resume_simulation()
			KEY_4:
				set_simulation_speed(simulation_speed * 2.0)
			KEY_5:
				set_simulation_speed(simulation_speed * 0.5)
			KEY_V:
				run_validation_test()
			KEY_R:
				reset_simulation()
				create_test_events()
			KEY_D:
				event_scheduler.print_debug_info()