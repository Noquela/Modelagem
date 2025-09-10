class_name DiscreteTrafficSimulator
extends Node

## Sistema principal do simulador de tráfego baseado em eventos discretos
## Integra todos os componentes e coordena a simulação

# Componentes principais
var event_scheduler: DiscreteEventScheduler
var simulation_clock: SimulationClock
var vehicle_manager: VehicleEventManager
var traffic_manager: DiscreteTrafficManager

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
	vehicle_manager = VehicleEventManager.new(event_scheduler, simulation_clock)
	traffic_manager = DiscreteTrafficManager.new(event_scheduler, simulation_clock)
	
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
	# Handler para eventos de veículos e semáforos
	match event.event_type:
		DiscreteEvent.EventType.CAR_SPAWN:
			vehicle_manager.handle_car_spawn_event(event.data)
		DiscreteEvent.EventType.CAR_ARRIVAL:
			if event.data.has("arrival_position"):
				if event.data.arrival_position == "proceeding":
					vehicle_manager._handle_car_proceeding_through_intersection(
						vehicle_manager.active_cars.get(event.data.car_id),
						vehicle_manager.car_journeys.get(event.data.car_id),
						simulation_clock.get_time()
					)
				elif event.data.arrival_position == "exit_intersection":
					vehicle_manager.handle_car_exit_intersection_event(event.data)
				else:
					vehicle_manager.handle_car_arrival_event(event.data)
		DiscreteEvent.EventType.CAR_DEPARTURE:
			vehicle_manager.handle_car_departure_event(event.data)
		DiscreteEvent.EventType.LIGHT_CHANGE:
			traffic_manager.handle_light_change_event(event.data)
		DiscreteEvent.EventType.QUEUE_PROCESS:
			traffic_manager.handle_queue_processing_event(event.data)
		_:
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
	print("Creating test events for Sprint 2 validation...")
	
	# SPRINT 2: Testes de veículos reais com lógica completa
	print("Scheduling realistic vehicle spawns...")
	vehicle_manager.schedule_periodic_spawns(60.0)  # 1 minuto de spawns
	
	# Teste adicional: alguns veículos específicos para debug
	var test_spawn_times = [2.0, 15.0, 35.0]
	var test_directions = [DiscreteCar.Direction.LEFT_TO_RIGHT, DiscreteCar.Direction.RIGHT_TO_LEFT, DiscreteCar.Direction.BOTTOM_TO_TOP]
	var test_personalities = [DiscreteCar.DriverPersonality.AGGRESSIVE, DiscreteCar.DriverPersonality.NORMAL, DiscreteCar.DriverPersonality.CONSERVATIVE]
	
	for i in range(test_spawn_times.size()):
		vehicle_manager.schedule_vehicle_spawn(
			test_spawn_times[i],
			test_directions[i],
			test_personalities[i]
		)
	
	print("Created realistic vehicle test events")

func run_validation_test():
	print("=== SPRINT 3 VALIDATION TEST ===")
	
	# Test 1: Verificar sistema completo (veículos + semáforos)
	print("Test 1: Complete traffic system")
	start_simulation()
	
	# Test 2: Simular tráfego com semáforos
	print("\nTest 2: Traffic simulation with lights")
	for i in range(500):  # 500 frames = ~50 segundos (mais de 1 ciclo completo)
		update_simulation(0.1)
	
	# Test 3: Estatísticas de veículos
	print("\nTest 3: Vehicle statistics")
	print("Active cars: %d" % vehicle_manager.get_active_car_count())
	print("Total spawned: %d" % vehicle_manager.get_total_cars_spawned())
	print("Cars waiting: %d" % vehicle_manager.get_cars_waiting_count())
	print("Average wait time: %.2fs" % vehicle_manager.get_average_wait_time())
	
	# Test 4: Estatísticas de semáforos e filas
	print("\nTest 4: Traffic light and queue statistics")
	print(traffic_manager.get_debug_info())
	print("Queue sizes: %s" % traffic_manager.get_queue_sizes())
	print("Total queued cars: %d" % traffic_manager.get_total_queued_cars())
	
	# Test 5: Estados dos semáforos
	print("\nTest 5: Traffic light states")
	print("Main road (West/East): %s" % traffic_manager.main_road_state)
	print("Cross road (South/North): %s" % traffic_manager.cross_road_state)
	print("Cycle phase: %.1fs/40s" % traffic_manager.get_current_cycle_phase())
	
	# Test 6: Debug info completo
	print("\nTest 6: Complete system status")
	print(vehicle_manager.get_debug_info())
	event_scheduler.print_debug_info()
	
	print("\n=== SPRINT 3 VALIDATION COMPLETE ===")

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