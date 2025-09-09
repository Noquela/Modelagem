extends Node
class_name DiscreteTrafficSimulator

# PASSO 5 - CONTROLADOR PRINCIPAL DOS EVENTOS DISCRETOS
# RESPONSABILIDADE: Conectar scheduler + systems + agendar eventos iniciais

@onready var scheduler: DiscreteEventScheduler = $DiscreteEventScheduler
@onready var traffic_light_system: TrafficLightSystem = $TrafficLightSystem
@onready var vehicle_system: VehicleSystem = $VehicleSystem

signal simulation_started()
signal simulation_paused()
signal simulation_reset()
signal event_executed(event: DiscreteEvent)

var is_initialized: bool = false

func _ready():
	print("🎮 DiscreteTrafficSimulator inicializando...")
	
	# Aguardar que todos os nós filhos sejam carregados
	await get_tree().process_frame
	
	initialize_systems()
	setup_initial_events()
	
	is_initialized = true
	print("✅ DiscreteTrafficSimulator pronto!")

func _process(_delta):
	# Atualizar timers dos semáforos em tempo real (mesmo em eventos discretos)
	if is_initialized and traffic_light_system and scheduler:
		traffic_light_system.update_timer_displays(scheduler.get_displayed_time())

func initialize_systems():
	print("🔗 Conectando sistemas...")
	
	# Conectar sinais do scheduler
	if scheduler:
		scheduler.event_processed.connect(_on_event_processed)
		print("  ✅ Scheduler conectado")
	else:
		push_error("❌ DiscreteEventScheduler não encontrado!")
	
	# Sistema de semáforos já inicializa sozinho
	if traffic_light_system:
		print("  ✅ TrafficLightSystem conectado")
	else:
		push_error("❌ TrafficLightSystem não encontrado!")
	
	# Conectar sistema de veículos
	if vehicle_system:
		vehicle_system.vehicle_despawned.connect(_on_vehicle_despawned)
		print("  ✅ VehicleSystem conectado")
	else:
		push_error("❌ VehicleSystem não encontrado!")

func setup_initial_events():
	if not scheduler:
		return
		
	print("📅 Agendando eventos iniciais do ciclo de semáforos...")
	
	# Começar com semáforos principais verdes (estado inicial)
	var start_time = 0.0
	
	# Ciclo completo: 20s + 3s + 1s + 10s + 3s + 1s = 38s
	var main_green_duration = traffic_light_system.CYCLE_TIMES["MAIN_GREEN"]      # 20s
	var main_yellow_duration = traffic_light_system.CYCLE_TIMES["MAIN_YELLOW"]    # 3s  
	var all_red_1_duration = traffic_light_system.CYCLE_TIMES["ALL_RED_1"]        # 1s
	var cross_green_duration = traffic_light_system.CYCLE_TIMES["CROSS_GREEN"]    # 10s
	var cross_yellow_duration = traffic_light_system.CYCLE_TIMES["CROSS_YELLOW"]  # 3s
	var all_red_2_duration = traffic_light_system.CYCLE_TIMES["ALL_RED_2"]        # 1s
	
	# Evento 1: Semáforos principais passam para amarelo
	var t1 = start_time + main_green_duration
	schedule_traffic_event(EventTypes.Type.SEMAFORO_MAIN_AMARELO, t1)
	
	# Evento 2: Todos vermelhos (transição)
	var t2 = t1 + main_yellow_duration
	schedule_traffic_event(EventTypes.Type.SEMAFORO_TODOS_VERMELHO_1, t2)
	
	# Evento 3: Semáforo transversal verde
	var t3 = t2 + all_red_1_duration
	schedule_traffic_event(EventTypes.Type.SEMAFORO_CROSS_VERDE, t3)
	
	# Evento 4: Semáforo transversal amarelo
	var t4 = t3 + cross_green_duration
	schedule_traffic_event(EventTypes.Type.SEMAFORO_CROSS_AMARELO, t4)
	
	# Evento 5: Todos vermelhos (transição)
	var t5 = t4 + cross_yellow_duration
	schedule_traffic_event(EventTypes.Type.SEMAFORO_TODOS_VERMELHO_2, t5)
	
	# Evento 6: Volta para semáforos principais verdes (reinicia ciclo)
	var t6 = t5 + all_red_2_duration
	schedule_traffic_event(EventTypes.Type.SEMAFORO_MAIN_VERDE, t6)
	
	print("📅 Eventos iniciais agendados:")
	print("  t=%.1fs: MAIN_AMARELO" % t1)
	print("  t=%.1fs: TODOS_VERMELHO_1" % t2) 
	print("  t=%.1fs: CROSS_VERDE" % t3)
	print("  t=%.1fs: CROSS_AMARELO" % t4)
	print("  t=%.1fs: TODOS_VERMELHO_2" % t5)
	print("  t=%.1fs: MAIN_VERDE (reinicia)" % t6)
	
	# Agendar primeiros spawns de veículos
	schedule_initial_vehicle_spawns()

func schedule_traffic_event(event_type: EventTypes.Type, time: float):
	var event = DiscreteEvent.new(time, event_type, {})
	scheduler.schedule_event(event)

func _on_event_processed(event: DiscreteEvent):
	print("🎯 Executando: %s em t=%.2f" % [EventTypes.get_event_name(event.type), event.time])
	
	# Processar evento baseado no tipo
	match event.type:
		# Eventos de semáforos
		EventTypes.Type.SEMAFORO_MAIN_VERDE, \
		EventTypes.Type.SEMAFORO_MAIN_AMARELO, \
		EventTypes.Type.SEMAFORO_TODOS_VERMELHO_1, \
		EventTypes.Type.SEMAFORO_CROSS_VERDE, \
		EventTypes.Type.SEMAFORO_CROSS_AMARELO, \
		EventTypes.Type.SEMAFORO_TODOS_VERMELHO_2:
			handle_traffic_light_event(event)
		
		# Eventos de veículos (FASE 6)
		EventTypes.Type.SPAWN_CARRO_WEST, \
		EventTypes.Type.SPAWN_CARRO_EAST, \
		EventTypes.Type.SPAWN_CARRO_NORTH:
			handle_vehicle_spawn_event(event)
		
		EventTypes.Type.CARRO_SAIU:
			handle_vehicle_exit_event(event)
			
		# Eventos de movimento de veículos
		EventTypes.Type.CARRO_MOVE_PARA_INTERSECAO, \
		EventTypes.Type.CARRO_ATRAVESSA_INTERSECAO, \
		EventTypes.Type.CARRO_RETOMA_MOVIMENTO, \
		EventTypes.Type.CARRO_AVANCA_FILA:
			handle_vehicle_movement_event(event)
			
		EventTypes.Type.CARRO_PARA_NO_SEMAFORO, \
		EventTypes.Type.CARRO_CHEGA_FILA:
			handle_vehicle_stop_event(event)
		
		EventTypes.Type.UPDATE_STATS:
			print("📊 Update stats (não implementado ainda)")
	
	# Atualizar timers dos semáforos
	if traffic_light_system and scheduler:
		traffic_light_system.update_timer_displays(scheduler.get_displayed_time())
	
	# Emitir sinal para UI
	event_executed.emit(event)
	
	# Reagendar próximo ciclo se necessário
	schedule_next_cycle_if_needed(event)

func handle_traffic_light_event(event: DiscreteEvent):
	if traffic_light_system:
		traffic_light_system.process_traffic_light_event(event.type)

func handle_vehicle_spawn_event(event: DiscreteEvent):
	if not vehicle_system:
		return
		
	var direction = ""
	match event.type:
		EventTypes.Type.SPAWN_CARRO_WEST:
			direction = "WEST"
		EventTypes.Type.SPAWN_CARRO_EAST:
			direction = "EAST"
		EventTypes.Type.SPAWN_CARRO_NORTH:
			direction = "NORTH"
	
	var vehicle_id = vehicle_system.spawn_vehicle(direction)
	if not vehicle_id.is_empty():
		# Agendar próximo spawn desta direção
		schedule_next_vehicle_spawn(direction, event.time)
		
		# Agendar primeiro movimento do carro
		schedule_vehicle_movement(vehicle_id, event.time)

func handle_vehicle_exit_event(event: DiscreteEvent):
	if not vehicle_system:
		return
		
	var vehicle_id = event.data.get("vehicle_id", "")
	if not vehicle_id.is_empty():
		vehicle_system.despawn_vehicle(vehicle_id)

func _on_vehicle_despawned(vehicle_id: String, exit_point: String):
	# Agendar evento CARRO_SAIU quando veículo chega ao fim
	var current_time = scheduler.get_current_time()
	var exit_event = DiscreteEvent.new(current_time, EventTypes.Type.CARRO_SAIU, {"vehicle_id": vehicle_id})
	scheduler.schedule_event(exit_event)

func schedule_next_cycle_if_needed(event: DiscreteEvent):
	# Se chegou ao final do ciclo (SEMAFORO_MAIN_VERDE), agendar próximo ciclo
	if event.type == EventTypes.Type.SEMAFORO_MAIN_VERDE:
		var cycle_start_time = event.time
		schedule_full_cycle(cycle_start_time)

func schedule_full_cycle(start_time: float):
	# Agendar um ciclo completo a partir de start_time
	var main_green = traffic_light_system.CYCLE_TIMES["MAIN_GREEN"]
	var main_yellow = traffic_light_system.CYCLE_TIMES["MAIN_YELLOW"]
	var all_red_1 = traffic_light_system.CYCLE_TIMES["ALL_RED_1"]
	var cross_green = traffic_light_system.CYCLE_TIMES["CROSS_GREEN"]
	var cross_yellow = traffic_light_system.CYCLE_TIMES["CROSS_YELLOW"]
	var all_red_2 = traffic_light_system.CYCLE_TIMES["ALL_RED_2"]
	
	var t1 = start_time + main_green
	var t2 = t1 + main_yellow
	var t3 = t2 + all_red_1
	var t4 = t3 + cross_green
	var t5 = t4 + cross_yellow
	var t6 = t5 + all_red_2
	
	schedule_traffic_event(EventTypes.Type.SEMAFORO_MAIN_AMARELO, t1)
	schedule_traffic_event(EventTypes.Type.SEMAFORO_TODOS_VERMELHO_1, t2)
	schedule_traffic_event(EventTypes.Type.SEMAFORO_CROSS_VERDE, t3)
	schedule_traffic_event(EventTypes.Type.SEMAFORO_CROSS_AMARELO, t4)
	schedule_traffic_event(EventTypes.Type.SEMAFORO_TODOS_VERMELHO_2, t5)
	schedule_traffic_event(EventTypes.Type.SEMAFORO_MAIN_VERDE, t6)
	
	print("🔄 Próximo ciclo agendado iniciando em t=%.1fs" % start_time)

func schedule_initial_vehicle_spawns():
	# Primeiros spawns em momentos aleatórios nos primeiros 10 segundos
	var spawn_times = {
		"WEST": randf_range(2.0, 8.0),
		"EAST": randf_range(1.0, 6.0), 
		"NORTH": randf_range(3.0, 10.0)
	}
	
	for direction in spawn_times.keys():
		var spawn_time = spawn_times[direction]
		var event_type = get_spawn_event_type(direction)
		schedule_traffic_event(event_type, spawn_time)
		print("🚗 Primeiro spawn %s agendado para t=%.1fs" % [direction, spawn_time])

func schedule_next_vehicle_spawn(direction: String, last_spawn_time: float):
	if not vehicle_system:
		return
		
	# Intervalo baseado na taxa de spawn (mais realístico)
	var spawn_rate = vehicle_system.get_spawn_rate(direction)
	if spawn_rate <= 0:
		return
		
	# Intervalo médio = 1/taxa, com variação aleatória
	var avg_interval = 1.0 / spawn_rate
	var next_interval = randf_range(avg_interval * 0.5, avg_interval * 1.5)
	var next_spawn_time = last_spawn_time + next_interval
	
	var event_type = get_spawn_event_type(direction)
	schedule_traffic_event(event_type, next_spawn_time)

func get_spawn_event_type(direction: String) -> EventTypes.Type:
	match direction:
		"WEST":
			return EventTypes.Type.SPAWN_CARRO_WEST
		"EAST":
			return EventTypes.Type.SPAWN_CARRO_EAST
		"NORTH":
			return EventTypes.Type.SPAWN_CARRO_NORTH
		_:
			return EventTypes.Type.SPAWN_CARRO_WEST

# NOVAS FUNÇÕES PARA EVENTOS DE MOVIMENTO

func handle_vehicle_movement_event(event: DiscreteEvent):
	if not vehicle_system:
		return
		
	var vehicle_id = event.data.get("vehicle_id", "")
	if vehicle_id.is_empty():
		return
	
	# Mover o carro para a próxima posição
	var moved = vehicle_system.move_vehicle_to_next_position(vehicle_id)
	if moved:
		print("🚗 %s moveu para próxima posição" % vehicle_id)
		
		# Verificar se carro chegou ao fim
		var car_info = vehicle_system.get_vehicle_info(vehicle_id)
		if car_info.has("position_index") and car_info.position_index >= 6:
			# Carro saiu - agendar evento de saída
			var exit_time = scheduler.get_current_time() + 0.1
			var exit_event = DiscreteEvent.new(exit_time, EventTypes.Type.CARRO_SAIU, {"vehicle_id": vehicle_id})
			scheduler.schedule_event(exit_event)
		else:
			# Agendar próximo movimento
			schedule_vehicle_movement(vehicle_id, event.time)

func handle_vehicle_stop_event(event: DiscreteEvent):
	if not vehicle_system:
		return
		
	var vehicle_id = event.data.get("vehicle_id", "")
	if vehicle_id.is_empty():
		return
	
	print("🚗🛑 %s parou (semáforo ou fila)" % vehicle_id)
	
	# Verificar periodicamente se pode retomar movimento
	var car = vehicle_system.discrete_cars.get(vehicle_id)
	var retry_interval = car.speed_factor if car else 2.0
	var retry_time = event.time + retry_interval  # Usar tempo baseado na velocidade do carro
	var retry_event = DiscreteEvent.new(retry_time, EventTypes.Type.CARRO_MOVE_PARA_INTERSECAO, {"vehicle_id": vehicle_id})
	scheduler.schedule_event(retry_event)

func schedule_vehicle_movement(vehicle_id: String, current_time: float):
	if not vehicle_system:
		return
		
	# Verificar se o carro pode se mover
	if vehicle_system.can_vehicle_move(vehicle_id):
		# Agendar movimento
		var car_info = vehicle_system.get_vehicle_info(vehicle_id)
		var car = vehicle_system.discrete_cars[vehicle_id]
		var move_time = current_time + car.speed_factor + 0.5  # Dar tempo extra para animação
		
		var movement_event = DiscreteEvent.new(move_time, EventTypes.Type.CARRO_MOVE_PARA_INTERSECAO, {"vehicle_id": vehicle_id})
		scheduler.schedule_event(movement_event)
	else:
		# Carro não pode se mover - agendar parada
		var stop_time = current_time + 0.5
		var stop_event = DiscreteEvent.new(stop_time, EventTypes.Type.CARRO_PARA_NO_SEMAFORO, {"vehicle_id": vehicle_id})
		scheduler.schedule_event(stop_event)

# Controles públicos da simulação
func start_simulation():
	if not is_initialized:
		print("⚠️ Simulação não inicializada ainda")
		return
		
	if scheduler:
		scheduler.start_simulation()
		simulation_started.emit()
		print("▶️ Simulação INICIADA")

func pause_simulation():
	if scheduler:
		scheduler.pause_simulation()
		simulation_paused.emit()
		print("⏸️ Simulação PAUSADA")

func reset_simulation():
	if scheduler:
		scheduler.reset_simulation()
		setup_initial_events()
		simulation_reset.emit()
		print("🔄 Simulação RESETADA")

func step_simulation():
	if scheduler:
		var advanced = scheduler.advance_to_next_event()
		if not advanced:
			print("🏁 Não há mais eventos para processar")
		return advanced

func get_simulation_info() -> String:
	var info = ""
	
	if scheduler:
		info += "⏱️ Tempo atual: %.2fs\n" % scheduler.get_current_time()
		info += "📋 Eventos na fila: %d\n" % scheduler.get_events_count()
		info += "▶️ Status: %s\n" % ("RODANDO" if scheduler.is_running else "PAUSADO")
		info += "\n"
	
	if traffic_light_system:
		info += traffic_light_system.get_traffic_lights_info()
	
	return info
