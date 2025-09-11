extends Node

var event_bus: Node
var simulation_clock: Node
var traffic_controller: Node
var car_spawner: Node

var is_running: bool = false
var active_cars = {}  # Track all cars in simulation

func _ready():
	print("🎛️ DiscreteSimulation inicializado")
	
func initialize():
	event_bus = get_node("/root/EventBus")
	simulation_clock = get_node("/root/SimulationClock")
	traffic_controller = get_node("/root/TrafficLightController")
	car_spawner = get_node("/root/CarSpawner")
	
	connect_events()
	print("🎛️ Sistema discreto conectado")

func connect_events():
	if simulation_clock:
		simulation_clock.tick_fast.connect(_on_fast_tick)  # Decisões mais frequentes
		simulation_clock.tick_second.connect(_on_second_tick)
		simulation_clock.tick_minute.connect(_on_minute_tick)
	
	if event_bus:
		event_bus.subscribe("car_spawned", _on_car_spawned)
		event_bus.subscribe("traffic_light_changed", _on_traffic_light_changed)

func start_simulation():
	if not is_running and simulation_clock:
		is_running = true
		simulation_clock.resume()
		print("▶️ Simulação discreta iniciada")

func pause_simulation():
	if is_running:
		is_running = false
		simulation_clock.pause()
		print("⏸️ Simulação discreta pausada")

func reset_simulation():
	simulation_clock.reset()
	car_spawner.current_cars = 0
	print("🔄 Simulação discreta resetada")

func _process(delta):
	if is_running:
		# MOVIMENTO VISUAL SUAVE - interpolar posições calculadas discretamente
		update_visual_positions(delta)

func _on_fast_tick():
	if is_running:
		# LÓGICA DISCRETA FREQUENTE - decisões mais fluidas
		update_discrete_decisions()

func _on_second_tick():
	if is_running:
		# Debug apenas
		if active_cars.size() > 0:
			print("🔄 Tick: ", active_cars.size(), " carros ativos")

func _on_minute_tick():
	if is_running:
		print("📊 Tempo simulação: ", int(simulation_clock.get_simulation_time() / 60), " minutos")

func _on_car_spawned(car_data):
	print("📡 Backend recebeu spawn: ", car_data.id)
	# Add car to tracking with DISCRETE IDM properties
	active_cars[car_data.id] = {
		"position": car_data.position,
		"target_position": car_data.position,  # Posição alvo calculada discretamente
		"direction": car_data.direction,
		"speed_state": "accelerating",  # Estados: "accelerating", "cruising", "decelerating", "stopped"
		"desired_speed": randf_range(8.0, 12.0),  # Velocidade desejada realista (8-12 m/s = ~30-45 km/h)
		"current_speed": 0.0,
		"lane": car_data.lane,
		"direction_enum": car_data.direction_enum,
		"last_update": simulation_clock.get_simulation_time(),
		"last_decision_time": 0.0,
		"stopped_at_light": false,
		# IDM-based DISCRETE parameters - FILAS DENSAS
		"personality": {
			"aggressiveness": randf_range(0.5, 1.5),  # Multiplicador de aceleração
			"following_distance": randf_range(0.8, 1.5),  # REDUZIDO: 2.0-4.0 → 0.8-1.5 para filas mais densas
			"reaction_time": randf_range(0.8, 1.5),  # Tempo de reação
			"patience": randf_range(0.5, 2.0)  # Paciência em semáforos
		}
	}

func _on_traffic_light_changed(light_data):
	print("📡 Backend recebeu mudança semáforo: ", light_data.light_id, " -> ", light_data.state)

func update_discrete_decisions():
	# SISTEMA DISCRETO - tomar decisões a cada tick baseadas em IDM
	var cars_to_remove = []
	var current_time = simulation_clock.get_simulation_time()
	
	for car_id in active_cars.keys():
		var car = active_cars[car_id]
		car["id"] = car_id
		
		# DECISÃO DISCRETA baseada em IDM
		var decision = make_driving_decision(car, current_time)
		apply_discrete_decision(car, decision)
		
		# Verificar se passou pela interseção (evento especial)
		check_intersection_crossing(car)
		
		# Verificar se chegou ao fim
		if has_reached_end(car):
			cars_to_remove.append(car_id)
		
		car.last_decision_time = current_time
	
	# Remove cars that reached the end
	for car_id in cars_to_remove:
		active_cars.erase(car_id)
		event_bus.emit_event("car_despawned", {"id": car_id})

func update_visual_positions(delta: float):
	# INTERPOLAÇÃO SUAVE - mover visualmente para posições calculadas discretamente
	for car_id in active_cars.keys():
		var car = active_cars[car_id]
		
		# Interpolar suavemente para target_position calculada discretamente
		var current_pos = car.position
		var target_pos = car.target_position
		var distance = current_pos.distance_to(target_pos)
		
		if distance > 0.1:
			# Velocidade de interpolação baseada no estado do carro
			var lerp_speed = get_visual_speed_for_state(car.speed_state)
			car.position = current_pos.move_toward(target_pos, lerp_speed * delta)
		else:
			car.position = target_pos
		
		# Emitir update visual apenas se posição mudou significativamente
		if current_pos.distance_to(car.position) > 0.05:
			event_bus.emit_event("car_position_updated", {
				"id": car_id,
				"position": car.position,
				"stopped": car.speed_state == "stopped"
			})

func make_driving_decision(car: Dictionary, _current_time: float) -> Dictionary:
	# DECISÃO DISCRETA baseada nos princípios do IDM
	var decision = {
		"action": "maintain",  # "accelerate", "maintain", "decelerate", "stop"
		"new_speed_state": car.speed_state,
		"target_distance": 2.0  # REDUZIDO: 4.0 → 2.0 para filas mais compactas
	}
	
	# 1. Analisar situação à frente
	var leader_car = find_leader_car(car)
	var gap_to_leader = INF
	if leader_car.size() > 0:  # Verificar se dictionary não está vazio
		gap_to_leader = calculate_gap_to_leader(car, leader_car)
	
	# 2. Analisar semáforos
	var traffic_situation = analyze_traffic_lights(car)
	
	# 3. Tomar decisão baseada na personalidade e situação
	if traffic_situation.must_stop:
		decision.action = "stop"
		decision.new_speed_state = "stopped"
		decision.target_distance = 0.0
	elif gap_to_leader < car.personality.following_distance:
		# Muito próximo do carro da frente - FILAS MAIS DENSAS
		if gap_to_leader < 0.8:  # REDUZIDO: 2.0 → 0.8 - parar apenas quando muito próximo
			decision.action = "stop"
			decision.new_speed_state = "stopped"
			decision.target_distance = 0.0
		else:  # Próximo mas não crítico - continuar devagar para formar fila
			decision.action = "decelerate"
			decision.new_speed_state = "decelerating" 
			decision.target_distance = 0.5  # REDUZIDO: 1.0 → 0.5 movimento muito pequeno para formar fila
	elif car.current_speed < car.desired_speed * 0.9:
		# Abaixo da velocidade desejada
		decision.action = "accelerate"
		decision.new_speed_state = "accelerating"
		decision.target_distance = min(6.0, 4.0 * car.personality.aggressiveness)  # Movimento maior
	else:
		# Velocidade adequada
		decision.action = "maintain"
		decision.new_speed_state = "cruising"
		decision.target_distance = 5.0  # Movimento contínuo maior
	
	return decision

func apply_discrete_decision(car: Dictionary, decision: Dictionary):
	# APLICAR decisão discreta calculando nova posição alvo
	var previous_state = car.get("speed_state", "cruising")
	car.speed_state = decision.new_speed_state
	
	# EMITIR EVENTOS quando estado muda
	if previous_state != decision.new_speed_state:
		if decision.new_speed_state == "stopped" and previous_state != "stopped":
			# Carro acabou de parar
			event_bus.emit_event("car_stopped", {
				"id": car.id,
				"position": car.position,
				"previous_state": previous_state
			})
		elif previous_state == "stopped" and decision.new_speed_state != "stopped":
			# Carro acabou de sair do estado parado
			event_bus.emit_event("car_started", {
				"id": car.id,
				"position": car.position,
				"new_state": decision.new_speed_state
			})
	
	# Atualizar velocidade conceitual baseada no estado
	match car.speed_state:
		"accelerating":
			car.current_speed = min(car.desired_speed, car.current_speed + 2.0 * car.personality.aggressiveness)
		"cruising":
			car.current_speed = car.desired_speed
		"decelerating":
			car.current_speed = max(0.0, car.current_speed - 3.0)
		"stopped":
			car.current_speed = 0.0
	
	# Calcular nova posição alvo baseada na direção e distância - COM VERIFICAÇÃO DE COLISÃO
	var movement_distance = decision.target_distance
	
	# Se carro está parado, NÃO mover para evitar sobreposição
	if car.speed_state == "stopped":
		movement_distance = 0.0
	else:
		# Verificar se o movimento causaria colisão com líder
		var safe_movement = calculate_safe_movement(car, movement_distance)
		movement_distance = safe_movement
	
	# Aplicar movimento apenas se seguro
	if movement_distance > 0:
		match car.direction_enum:
			0:  # LEFT_TO_RIGHT (West → East)
				car.target_position.x += movement_distance
			1:  # RIGHT_TO_LEFT (East → West)
				car.target_position.x -= movement_distance
			3:  # BOTTOM_TO_TOP (South → North)
				car.target_position.z -= movement_distance

func get_visual_speed_for_state(speed_state: String) -> float:
	# Velocidade de interpolação visual MUITO MAIS RÁPIDA para fluidez
	match speed_state:
		"accelerating":
			return 25.0  # Muito mais rápido
		"cruising":
			return 20.0  # Muito mais rápido
		"decelerating":
			return 15.0  # Mais rápido
		"stopped":
			return 8.0   # Mais rápido mesmo parado
		_:
			return 18.0

func check_intersection_crossing(car: Dictionary):
	# Detectar quando carro passa pela interseção (posição aproximadamente 0,0)
	var intersection_zone = 8.0  # Zona da interseção
	var current_pos = car.target_position
	var previous_pos = car.get("previous_intersection_check", current_pos)
	
	# Verificar se entrou na zona da interseção
	var in_intersection_now = (abs(current_pos.x) <= intersection_zone and abs(current_pos.z) <= intersection_zone)
	var was_in_intersection = (abs(previous_pos.x) <= intersection_zone and abs(previous_pos.z) <= intersection_zone)
	
	if in_intersection_now and not was_in_intersection:
		# Acabou de entrar na interseção
		event_bus.emit_event("car_entered_intersection", {
			"id": car.id,
			"position": car.position,
			"direction": car.direction_enum
		})
	elif not in_intersection_now and was_in_intersection:
		# Acabou de sair da interseção
		event_bus.emit_event("car_exited_intersection", {
			"id": car.id,
			"position": car.position,
			"direction": car.direction_enum
		})
	
	car.previous_intersection_check = current_pos

func has_reached_end(car: Dictionary) -> bool:
	# Verificar se carro chegou ao fim da pista - usar TARGET_POSITION para decisão discreta
	# A posição visual (car.position) pode estar atrasada devido à interpolação
	# LIMITES MAIORES para garantir que carros só despawnem bem longe do semáforo
	match car.direction_enum:
		0:  # LEFT_TO_RIGHT (spawna em -35, semáforo em -8, deve despawnar bem depois)
			return car.target_position.x > 80  # Bem depois do semáforo (+8)
		1:  # RIGHT_TO_LEFT (spawna em +35, semáforo em +8, deve despawnar bem antes)
			return car.target_position.x < -80  # Bem antes do semáforo (-8)
		3:  # BOTTOM_TO_TOP (spawna em +35, semáforo em +8, deve despawnar bem antes)
			return car.target_position.z < -80  # Bem antes do semáforo (+8)
	return false

func analyze_traffic_lights(car: Dictionary) -> Dictionary:
	# Analisar situação dos semáforos para decisão discreta
	var result = {"must_stop": false, "distance_to_stop": INF}
	
	# Se está na intersecção, nunca parar
	if is_in_intersection(car):
		return result
	
	var light_id = get_traffic_light_for_car(car)
	if light_id == "":
		return result
	
	var light_state = traffic_controller.get_light_state(light_id)
	var distance_to_stop = get_distance_to_intersection(car)
	
	result.distance_to_stop = distance_to_stop
	
	# Verde = pode continuar
	if light_state == 2:  # GREEN
		return result
	
	# Vermelho = deve parar se estiver na zona de influência (AJUSTADA para parar antes da faixa)
	if light_state == 0 and distance_to_stop > 0 and distance_to_stop < 8:  # RED
		result.must_stop = true
	
	# Amarelo = decidir baseado na personalidade e distância (AJUSTADA)
	if light_state == 1 and distance_to_stop > 0 and distance_to_stop < 6:  # YELLOW
		# Carros agressivos tentam passar, pacientes param
		if car.personality.patience > 1.0 or distance_to_stop > 4:
			result.must_stop = true
	
	return result

# REMOVIDO: check_can_move() - agora usamos IDM completo

func get_traffic_light_for_car(car: Dictionary) -> String:
	# Determine which traffic light affects this car
	match car.direction_enum:
		0, 1:  # LEFT_TO_RIGHT, RIGHT_TO_LEFT (horizontal road)
			if car.direction_enum == 0:  # West → East
				return "light_1"  # S1
			else:  # East → West  
				return "light_2"  # S2
		3:  # BOTTOM_TO_TOP (South → North, vertical road)
			return "light_3"  # S3
	return ""

func get_distance_to_intersection(car: Dictionary) -> float:
	# Calculate distance from car to STOP LINE (bem antes da faixa de pedestre)
	# Stop lines mais afastadas para evitar carros parando em cima das faixas
	var stop_line_offset = 5.0  # AUMENTADO: 2.5 → 5.0 metros do centro
	
	match car.direction_enum:
		0:  # LEFT_TO_RIGHT (West → East)
			var stop_line_x = -stop_line_offset  # Linha de parada em X = -5.0
			if car.position.x < stop_line_x:  # Before stop line
				return abs(car.position.x - stop_line_x)
			else:  # After stop line
				return -1  # Past stop line
		1:  # RIGHT_TO_LEFT (East → West)
			var stop_line_x = stop_line_offset   # Linha de parada em X = +5.0
			if car.position.x > stop_line_x:  # Before stop line
				return car.position.x - stop_line_x
			else:  # After stop line
				return -1  # Past stop line
		3:  # BOTTOM_TO_TOP (South → North)
			var stop_line_z = stop_line_offset + 2.0   # Linha de parada em Z = +7.0 (ainda mais antes)
			if car.position.z > stop_line_z:  # Before stop line
				return car.position.z - stop_line_z
			else:  # After stop line
				return -1  # Past stop line
	
	return -1  # Unknown direction

func is_in_intersection(car: Dictionary) -> bool:
	# Definir área da intersecção - zona central onde carros NUNCA podem parar
	# Ajustada para ser consistente com as novas linhas de parada mais afastadas
	var intersection_bounds = {
		"x_min": -5.0,  # EXPANDIDO: -2.5 → -5.0 para coincidir com stop lines
		"x_max": 5.0,   # EXPANDIDO: 2.5 → 5.0 para coincidir com stop lines
		"z_min": -5.0,  # EXPANDIDO: -2.5 → -5.0
		"z_max": 7.0    # EXPANDIDO: 2.5 → 7.0 (maior para direção sul-norte)
	}
	
	return (car.position.x >= intersection_bounds.x_min and 
			car.position.x <= intersection_bounds.x_max and
			car.position.z >= intersection_bounds.z_min and
			car.position.z <= intersection_bounds.z_max)

# REMOVIDO: funções IDM antigas - agora usamos sistema discreto

func find_leader_car(current_car: Dictionary) -> Dictionary:
	# Encontrar o carro mais próximo à frente na mesma direção/faixa
	var closest_leader = {}
	var min_distance = INF
	
	for other_car_id in active_cars.keys():
		var other_car = active_cars[other_car_id]
		
		# Pular se for o mesmo carro
		if other_car_id == current_car.get("id", ""):
			continue
		
		# Verificar apenas carros na mesma direção
		if other_car.direction_enum != current_car.direction_enum:
			continue
		
		# Verificar se estão na mesma faixa (proximidade lateral) - USAR TARGET_POSITION
		var lateral_distance = 0.0
		match current_car.direction_enum:
			0, 1:  # Horizontal roads
				lateral_distance = abs(other_car.target_position.z - current_car.target_position.z)
			3:  # Vertical road
				lateral_distance = abs(other_car.target_position.x - current_car.target_position.x)
		
		if lateral_distance > 1.5:  # Faixas diferentes - mais restritivo
			continue
		
		# Verificar se está à frente - USAR TARGET_POSITION para posição real
		var is_ahead = false
		var distance = 0.0
		
		match current_car.direction_enum:
			0:  # LEFT_TO_RIGHT (West → East)
				if other_car.target_position.x > current_car.target_position.x:
					is_ahead = true
					distance = other_car.target_position.x - current_car.target_position.x
			1:  # RIGHT_TO_LEFT (East → West)
				if other_car.target_position.x < current_car.target_position.x:
					is_ahead = true
					distance = current_car.target_position.x - other_car.target_position.x
			3:  # BOTTOM_TO_TOP (South → North)
				if other_car.target_position.z < current_car.target_position.z:
					is_ahead = true
					distance = current_car.target_position.z - other_car.target_position.z
		
		if is_ahead and distance < min_distance:
			min_distance = distance
			closest_leader = other_car
	
	return closest_leader

func calculate_safe_movement(car: Dictionary, intended_movement: float) -> float:
	# Calcular quanto o carro pode se mover sem colidir com o líder
	if intended_movement <= 0:
		return 0.0
	
	var leader_car = find_leader_car(car)
	if leader_car.is_empty():
		return intended_movement  # Sem líder, movimento livre
	
	var gap_to_leader = calculate_gap_to_leader(car, leader_car)
	var min_safe_distance = 1.0  # Distância mínima de segurança entre carros
	
	# Calcular posição futura após movimento
	var future_gap = gap_to_leader - intended_movement
	
	# Se movimento causaria aproximação demais, reduzir movimento
	if future_gap < min_safe_distance:
		var safe_movement = max(0.0, gap_to_leader - min_safe_distance)
		return safe_movement
	else:
		return intended_movement

func calculate_gap_to_leader(current_car: Dictionary, leader_car: Dictionary) -> float:
	# Calcular distância real entre carros (gap) - USAR TARGET_POSITION
	var car_length = 3.0  # Tamanho mais realista do carro
	match current_car.direction_enum:
		0:  # LEFT_TO_RIGHT
			return max(0.0, leader_car.target_position.x - current_car.target_position.x - car_length)
		1:  # RIGHT_TO_LEFT
			return max(0.0, current_car.target_position.x - leader_car.target_position.x - car_length)
		3:  # BOTTOM_TO_TOP
			return max(0.0, current_car.target_position.z - leader_car.target_position.z - car_length)
	return 0.0

# REMOVIDO: funções IDM antigas desnecessárias

func get_simulation_stats() -> Dictionary:
	return {
		"time": simulation_clock.get_simulation_time(),
		"cars": car_spawner.current_cars,
		"is_running": is_running
	}
