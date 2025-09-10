class_name DiscreteTrafficSimulator
extends Node

## Sistema principal do simulador de tráfego baseado em eventos discretos
## Integra todos os componentes e coordena a simulação

# Componentes principais
var event_scheduler: DiscreteEventScheduler
var simulation_clock: SimulationClock
var vehicle_manager: VehicleEventManager
var traffic_manager: DiscreteTrafficManager
var hybrid_renderer: HybridRenderer
var hybrid_debug_ui: HybridDebugUI

# Componentes integrados do simulator_3d
var spawn_system: DiscreteSpawnSystem
var analytics: Control
var ui_controller: Control

# Estado da simulação
var is_running: bool = false
var simulation_speed: float = 1.0
var hybrid_mode: bool = false

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
	await get_tree().process_frame  # Aguardar components serem criados
	connect_external_components()
	create_test_events()  # Para validar Sprint 1
	
	# INICIAR SIMULAÇÃO AUTOMATICAMENTE
	start_simulation()
	print("🎯 DiscreteTrafficSimulator initialized and STARTED")

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
	
	# Configurar referência do scheduler para este simulador
	event_scheduler.traffic_simulator = self
	
	# Criar sistema híbrido de renderização (apenas se não estiver em modo híbrido)
	if not hybrid_mode:
		hybrid_renderer = HybridRenderer.new()
		hybrid_renderer.name = "HybridRenderer"
		add_child(hybrid_renderer)
		print("✅ HybridRenderer antigo criado (modo não-híbrido)")
	else:
		print("✅ Modo híbrido - usando HybridTrafficSystem em vez de HybridRenderer")
	
	# Criar traffic_manager com referência ao HybridRenderer (se existir)
	var renderer_for_manager = hybrid_renderer if not hybrid_mode else null
	traffic_manager = DiscreteTrafficManager.new(event_scheduler, simulation_clock, renderer_for_manager)
	
	# Criar vehicle_manager com referência ao traffic_manager
	vehicle_manager = VehicleEventManager.new(event_scheduler, simulation_clock)
	vehicle_manager.traffic_manager = traffic_manager
	
	# Conectar sinais
	event_scheduler.event_executed.connect(_on_event_executed)
	event_scheduler.entity_created.connect(_on_entity_created)
	event_scheduler.entity_destroyed.connect(_on_entity_destroyed)
	
	print("Simulation components created - Backend Discreto + Frontend Híbrido + Traffic Manager")

func connect_external_components():
	# Conectar componentes externos do simulator_3d adaptados para eventos discretos
	spawn_system = get_parent().get_node_or_null("SpawnSystem")
	analytics = get_parent().get_node_or_null("Analytics") 
	ui_controller = get_parent().get_node_or_null("Analytics")
	
	if spawn_system:
		print("✅ Connected to DiscreteSpawnSystem")
	else:
		print("⚠️ SpawnSystem not found")
		
	if analytics:
		print("✅ Connected to Analytics")
		# Conectar sinal de estatísticas
		stats_updated.connect(analytics.update_display)
	else:
		print("⚠️ Analytics not found")
		
	if ui_controller:
		print("✅ Connected to UI Controller")
	else:
		print("⚠️ UI Controller not found")
	
	# SINCRONIZAR SEMÁFOROS VISUAIS INICIAIS
	_sync_initial_traffic_lights()

func _sync_initial_traffic_lights():
	# Agendar sincronização após 0.1s para garantir que visual_scene esteja pronta
	var sync_event = DiscreteEvent.new(
		simulation_clock.get_time() + 0.1,
		DiscreteEvent.EventType.LIGHT_CHANGE,
		-1,
		{
			"change_id": -1,
			"main_road_state": traffic_manager.main_road_state,
			"cross_road_state": traffic_manager.cross_road_state,
			"cycle_time": 0.0,
			"initial_sync": true
		}
	)
	
	event_scheduler.schedule_event(sync_event)
	print("🚦 Initial traffic lights sync scheduled for +0.1s")

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

func get_hybrid_renderer() -> HybridRenderer:
	return hybrid_renderer

func get_active_car(car_id: int) -> DiscreteCar:
	if vehicle_manager and vehicle_manager.active_cars.has(car_id):
		return vehicle_manager.active_cars[car_id]
	return null

func toggle_hybrid_debug_ui():
	if not hybrid_debug_ui:
		# Criar UI híbrida
		hybrid_debug_ui = HybridDebugUI.new()
		hybrid_debug_ui.name = "HybridDebugUI"
		
		# Adicionar como overlay full-screen
		var ui_node = get_node("UI")
		if ui_node:
			ui_node.add_child(hybrid_debug_ui)
			hybrid_debug_ui.anchors_preset = Control.PRESET_FULL_RECT
		
		print("🔧 Hybrid Debug UI ENABLED - Backend/Frontend separation visible")
	else:
		# Remover UI híbrida
		hybrid_debug_ui.queue_free()
		hybrid_debug_ui = null
		print("🔧 Hybrid Debug UI DISABLED")

## ============================================================================
## ESTATÍSTICAS
## ============================================================================

func get_simulation_statistics() -> Dictionary:
	var scheduler_stats = event_scheduler.get_statistics()
	var clock_stats = simulation_clock.get_status()
	
	# Estatísticas do sistema integrado
	var spawn_stats = {}
	if spawn_system:
		spawn_stats = spawn_system.get_spawn_statistics()
	
	# Estatísticas de personalidades dos motoristas
	var personality_stats = {}
	if vehicle_manager:
		personality_stats = vehicle_manager.get_personality_distribution()
	
	# Combinar todas as estatísticas
	var stats = {
		"is_running": is_running,
		"frame_count": frame_count,
		"simulation_speed": simulation_speed,
		"scheduler": scheduler_stats,
		"clock": clock_stats,
		"spawn": spawn_stats,
		"personality_stats": personality_stats,
		"fps": Engine.get_frames_per_second(),
		"active_cars": scheduler_stats.get("active_entities", 0),
		"total_cars_spawned": spawn_stats.get("total_spawned", 0),
		"throughput": 0.0,  # Calculado depois
		"average_wait_time": 0.0,  # Calculado pelo traffic_manager
		"max_queue_length": 0
	}
	
	# Dados do traffic manager se disponível
	if traffic_manager:
		var traffic_stats = traffic_manager.get_debug_info()
		stats["traffic_manager"] = traffic_stats
	
	return stats

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
			# Verificar se é sincronização inicial
			if event.data.get("initial_sync", false):
				_handle_initial_sync_event(event.data)
			else:
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

func _handle_initial_sync_event(event_data: Dictionary):
	# Sincronizar semáforos visuais no primeiro ciclo
	var main_state = event_data.main_road_state
	var cross_state = event_data.cross_road_state
	
	if traffic_manager:
		traffic_manager._update_visual_traffic_lights(main_state, cross_state)
		print("🚦 INITIAL SYNC completed: Main=%s Cross=%s" % [main_state, cross_state])
	else:
		print("⚠️ TrafficManager not found for initial sync")

## ============================================================================
## SISTEMA DE TESTES DO SPRINT 1
## ============================================================================

func create_test_events():
	print("Creating test events for Sprint 2 validation...")
	
	# SPAWN IMEDIATO para testar movimento
	var immediate_spawns = [0.5, 1.0, 1.5]  # Spawns imediatos após 0.5s
	var test_directions = [DiscreteCar.Direction.LEFT_TO_RIGHT, DiscreteCar.Direction.RIGHT_TO_LEFT, DiscreteCar.Direction.BOTTOM_TO_TOP]
	var test_personalities = [DiscreteCar.DriverPersonality.NORMAL, DiscreteCar.DriverPersonality.AGGRESSIVE, DiscreteCar.DriverPersonality.CONSERVATIVE]
	
	for i in range(immediate_spawns.size()):
		vehicle_manager.schedule_vehicle_spawn(
			immediate_spawns[i],
			test_directions[i],
			test_personalities[i]
		)
	
	# SPRINT 2: Testes de veículos reais com lógica completa
	print("Scheduling realistic vehicle spawns...")
	vehicle_manager.schedule_periodic_spawns(60.0)  # 1 minuto de spawns
	
	print("Created immediate test spawns + realistic vehicle events")

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

## ============================================================================
## TESTES E VALIDAÇÃO (comentados para versão final)
## ============================================================================

func debug_complete_validation():
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

func set_hybrid_mode(enabled: bool):
	"""Configura simulador para modo híbrido"""
	hybrid_mode = enabled
	print("🔗 DiscreteTrafficSimulator: Hybrid mode %s" % ("ENABLED" if enabled else "DISABLED"))

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
			KEY_H:
				toggle_hybrid_debug_ui()
