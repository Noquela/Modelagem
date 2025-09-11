# scripts/discrete/DiscreteCarJourney.gd
class_name DiscreteCarJourney
extends RefCounted

var car: DiscreteCar
var scheduler: DiscreteEventScheduler
var traffic_manager: DiscreteTrafficManager
var spawn_system: DiscreteSpawnSystem
var journey_events: Array[Dictionary] = []

func _init(discrete_car: DiscreteCar, event_scheduler: DiscreteEventScheduler, traffic_mgr: DiscreteTrafficManager, spawn_sys: DiscreteSpawnSystem = null):
	car = discrete_car
	scheduler = event_scheduler
	traffic_manager = traffic_mgr
	spawn_system = spawn_sys

func plan_complete_journey():
	"""Planeja jornada RESPEITANDO SEMÁFOROS - como simulator_3d original"""
	var current_time = car.spawn_time
	var spawn_pos = car.position  # Usar posição atual, não constante
	
	print("🚗 Planning SMART journey for car %d (lane %d) from %s" % [car.id, car.lane, spawn_pos])
	
	# FASE 1: Movimento até a intersecção (respeita semáforos)
	var approach_distance = get_approach_distance(car.direction)  # ~28m
	var approach_time = car.calculate_travel_time(approach_distance)
	var intersection_arrival = current_time + approach_time
	
	schedule_intersection_arrival(intersection_arrival)
	
	print("📍 Car %d: Will arrive at intersection at %.2fs and check traffic light" % [car.id, intersection_arrival])

func get_total_journey_distance() -> float:
	"""Distância total da jornada: spawn → interseção → saída"""
	return get_approach_distance(car.direction) + get_crossing_distance(car.direction) + get_exit_distance(car.direction)

func schedule_intersection_arrival(arrival_time: float):
	"""Agenda movimento até intersecção COM VERIFICAÇÃO DE SEMÁFORO E CARROS"""
	
	# IDM DISCRETO: Verificar carros à frente e calcular posição segura
	var safe_position = calculate_idm_discrete_position(arrival_time)
	var approach_pos = get_intersection_approach_position(car.direction)
	
	# Se há carros à frente, ajustar posição baseado no IDM
	if safe_position != approach_pos:
		schedule_idm_queue_position(safe_position, arrival_time)
		return
	
	# VERIFICAR ESTADO DO SEMÁFORO no momento da chegada
	var light_state = traffic_manager.get_light_state_at_time(arrival_time, car.direction)
	var approach_duration = arrival_time - car.spawn_time
	
	print("🚦 Car %d: Light will be '%s' when arriving at %.2fs" % [car.id, light_state, arrival_time])
	
	if light_state == "green":
		# VERDE: Movimento direto até a saída (pode atravessar)
		schedule_green_light_passage(arrival_time)
	elif light_state == "red":
		# VERMELHO: Para antes da faixa e espera
		schedule_red_light_stop(arrival_time)
	else:  # yellow
		# AMARELO: Decisão baseada na personalidade + distância
		var distance_to_intersection = 5.0  # Chegada na intersecção
		if car.should_stop_at_yellow(distance_to_intersection):
			schedule_red_light_stop(arrival_time)  # Trata como vermelho
		else:
			schedule_green_light_passage(arrival_time)  # Acelera para passar

func schedule_green_light_passage(arrival_time: float):
	"""Movimento fluido: spawn → travessia → saída (semáforo verde)"""
	var final_position = get_map_exit_position(car.direction)
	var total_distance = get_total_journey_distance()
	var total_time = car.calculate_travel_time(total_distance)
	var smooth_total_time = total_time + 1.5  # Movimento mais suave
	
	# MOVIMENTO ÚNICO: spawn → saída (movimento fluido através da intersecção)
	scheduler.schedule_event(
		car.spawn_time + 0.1,
		DiscreteEventScheduler.EventType.CAR_START_CROSSING,
		car.id,
		{
			"car_id": car.id,
			"position": final_position,
			"crossing_duration": smooth_total_time,
			"movement_type": "green_passage"
		}
	)
	
	# Limpar no final
	scheduler.schedule_event(
		car.spawn_time + smooth_total_time + 1.0,
		DiscreteEventScheduler.EventType.CAR_EXIT_MAP,
		car.id,
		{"car_id": car.id, "final_position": final_position}
	)
	
	print("🟢 Car %d: GREEN passage - smooth %.2fs to %s" % [car.id, smooth_total_time, final_position])

func schedule_red_light_stop(arrival_time: float):
	"""Para antes da faixa, espera verde, depois atravessa"""
	var stop_position = get_stop_position(car.direction)
	var approach_time = arrival_time - car.spawn_time
	
	# FASE 1: Movimento até posição de parada (antes da faixa)
	scheduler.schedule_event(
		car.spawn_time + 0.1,
		DiscreteEventScheduler.EventType.CAR_START_CROSSING,
		car.id,
		{
			"car_id": car.id,
			"position": stop_position,
			"crossing_duration": approach_time,
			"movement_type": "approach_stop"
		}
	)
	
	# FASE 2: Começar a esperar
	scheduler.schedule_event(
		arrival_time,
		DiscreteEventScheduler.EventType.CAR_START_WAITING,
		car.id,
		{
			"car_id": car.id,
			"position": stop_position,
			"wait_duration": 0.0  # Será calculado
		}
	)
	
	# FASE 3: Calcular quando o semáforo fica verde e atravessar
	var wait_duration = traffic_manager.calculate_wait_time(arrival_time, car.direction)
	var crossing_start = arrival_time + wait_duration
	
	schedule_intersection_crossing(crossing_start)
	
	print("🔴 Car %d: RED stop - wait %.2fs at %s then cross" % [car.id, wait_duration, stop_position])
	print("  📍 Stop position for %s: %s (BEFORE crosswalk)" % [car.direction, stop_position])

func handle_intersection_arrival(event_data: Dictionary):
	"""Decide o que fazer na intersecção"""
	var arrival_time = event_data.arrival_time
	var direction = event_data.direction
	
	# Verificar estado do semáforo
	var light_state = traffic_manager.get_light_state_at_time(arrival_time, direction)
	print("🚦 Car %d arrives: light is %s" % [car.id, light_state])
	
	if light_state == "green":
		# Pode passar direto
		schedule_intersection_crossing(arrival_time)
	elif light_state == "red":
		# Deve parar e esperar
		var wait_time = traffic_manager.calculate_wait_time(arrival_time, direction)
		schedule_waiting_period(arrival_time, wait_time)
	else:  # yellow
		# Decisão baseada na personalidade
		var distance_to_intersection = 5.0  # Aproximação
		if car.should_stop_at_yellow(distance_to_intersection):
			var wait_time = traffic_manager.calculate_wait_time(arrival_time, direction) 
			schedule_waiting_period(arrival_time, wait_time)
		else:
			schedule_intersection_crossing(arrival_time)

func schedule_waiting_period(start_time: float, wait_duration: float):
	"""Agenda período de espera"""
	var end_waiting_time = start_time + wait_duration
	
	# Evento: começar a esperar
	scheduler.schedule_event(
		start_time,
		DiscreteEventScheduler.EventType.CAR_START_WAITING,
		car.id,
		{
			"car_id": car.id,
			"position": get_stop_position(car.direction),
			"wait_duration": wait_duration
		}
	)
	
	# Evento: terminar espera e começar a atravessar
	scheduler.schedule_event(
		end_waiting_time,
		DiscreteEventScheduler.EventType.CAR_START_CROSSING,
		car.id,
		{
			"car_id": car.id,
			"crossing_start_time": end_waiting_time
		}
	)
	
	print("⏳ Car %d: Will wait %.2fs (until %.2fs)" % [car.id, wait_duration, end_waiting_time])

func schedule_intersection_crossing(crossing_start_time: float):
	"""Agenda travessia da intersecção com movimento suave"""
	var total_remaining_distance = get_remaining_journey_distance()
	var total_time = car.calculate_travel_time(total_remaining_distance)
	var smooth_total_time = total_time + 1.5  # Movimento mais suave
	var final_exit_time = crossing_start_time + smooth_total_time
	
	# MOVIMENTO DIRETO: da posição atual → saída final (SEM PARADAS INTERMEDIÁRIAS)
	var final_position = get_map_exit_position(car.direction)
	
	scheduler.schedule_event(
		crossing_start_time,
		DiscreteEventScheduler.EventType.CAR_START_CROSSING,
		car.id,
		{
			"car_id": car.id,
			"position": final_position,  # Ir direto para a saída
			"crossing_duration": smooth_total_time,
			"movement_type": "crossing_to_exit"
		}
	)
	
	# Evento: sair do mapa
	scheduler.schedule_event(
		final_exit_time,
		DiscreteEventScheduler.EventType.CAR_EXIT_MAP,
		car.id,
		{
			"car_id": car.id,
			"final_position": final_position
		}
	)
	
	print("🟢 Car %d: Will cross and exit in %.2fs to %s" % [car.id, smooth_total_time, final_position])

func get_remaining_journey_distance() -> float:
	"""Distância restante da jornada (da parada até a saída)"""
	return get_crossing_distance(car.direction) + get_exit_distance(car.direction)

# ===== IDM DISCRETO =====

func calculate_idm_discrete_position(arrival_time: float) -> Vector3:
	"""Calcula posição segura baseada no IDM discreto"""
	var cars_ahead = get_active_cars_in_same_direction()
	var approach_pos = get_intersection_approach_position(car.direction)
	
	if cars_ahead.is_empty():
		return approach_pos  # Nenhum carro à frente
	
	# Encontrar carro mais próximo à frente
	var closest_car = find_closest_car_ahead(cars_ahead)
	if not closest_car:
		return approach_pos
	
	# Calcular distância segura usando IDM
	var safe_distance = calculate_idm_safe_distance(closest_car)
	var queue_position = calculate_queue_position_from_car(closest_car, safe_distance)
	
	print("🚗 Car %d: IDM queue position %s (behind car %d)" % [car.id, queue_position, closest_car.id])
	return queue_position

func get_active_cars_in_same_direction() -> Array:
	"""Busca carros ativos na mesma direção E PISTA via SpawnSystem"""
	var active_cars = []
	
	if not spawn_system:
		print("❌ Car %d: No spawn_system reference available" % car.id)
		return active_cars
	
	if spawn_system.has_method("get_active_cars"):
		var all_cars = spawn_system.get_active_cars()
		print("🔍 Car %d: Found %d total active cars" % [car.id, all_cars.size()])
		
		for car_id in all_cars.keys():
			var car_data = all_cars[car_id]
			# CONSIDERAR MESMA DIREÇÃO E MESMA PISTA
			if car_data.direction == car.direction and car_data.lane == car.lane and car_data.id != car.id:
				active_cars.append(car_data)
				print("   → Same direction+lane car found: ID=%d lane=%d at %s" % [car_data.id, car_data.lane, car_data.position])
	
	print("🚗 Car %d: Found %d cars in same direction+lane (%s lane %d)" % [car.id, active_cars.size(), car.direction, car.lane])
	return active_cars

func find_closest_car_ahead(cars_ahead: Array) -> DiscreteCar:
	"""Encontra o carro mais próximo à frente na mesma direção"""
	var closest_car = null
	var closest_distance = INF
	var my_current_pos = car.position  # Usar posição atual, não spawn
	
	print("🔍 Car %d (lane %d) at %s: Looking for cars ahead..." % [car.id, car.lane, my_current_pos])
	
	for other_car in cars_ahead:
		if other_car.id == car.id:
			continue
			
		var other_pos = other_car.position  # Usar posição atual
		print("   🔎 Checking car %d (lane %d) at %s" % [other_car.id, other_car.lane, other_pos])
		
		# VERSÃO MELHORADA: detectar se está na mesma posição OU à frente
		var distance = calculate_directional_distance(my_current_pos, other_pos)
		var is_ahead = is_car_ahead_in_direction(my_current_pos, other_pos) or distance < 1.0  # Incluir carros muito próximos
		
		if is_ahead:
			print("   → Car %d is ahead by %.2fm" % [other_car.id, distance])
			
			if distance < closest_distance:
				closest_distance = distance
				closest_car = other_car
	
	if closest_car:
		print("✅ Car %d: Closest ahead is car %d at %.2fm" % [car.id, closest_car.id, closest_distance])
	else:
		print("❌ Car %d: No cars ahead found in same lane" % car.id)
	
	return closest_car

func is_car_ahead_in_direction(my_pos: Vector3, other_pos: Vector3) -> bool:
	"""Verifica se outro carro está à frente na direção de movimento"""
	match car.direction:
		"west_east": return other_pos.x > my_pos.x
		"east_west": return other_pos.x < my_pos.x
		"south_north": return other_pos.z < my_pos.z
	return false

func calculate_directional_distance(pos1: Vector3, pos2: Vector3) -> float:
	"""Calcula distância na direção do movimento"""
	match car.direction:
		"west_east": return abs(pos2.x - pos1.x)
		"east_west": return abs(pos1.x - pos2.x)
		"south_north": return abs(pos1.z - pos2.z)
	return pos1.distance_to(pos2)

func calculate_idm_safe_distance(leader_car: DiscreteCar) -> float:
	"""Calcula distância segura usando princípios IDM - AUMENTADO PARA EVITAR SOBREPOSIÇÃO"""
	var personality_data = car.PERSONALITIES[car.personality]
	
	# Parâmetros IDM realistas AUMENTADOS
	var s0 = 5.0  # Distância mínima AUMENTADA (era 3.0m)
	var T = randf_range(personality_data.reaction[0], personality_data.reaction[1])  # Tempo de reação
	var v = car.base_speed  # Velocidade desejada do seguidor
	var v_leader = leader_car.base_speed  # Velocidade do líder
	
	# IDM discreto melhorado com diferencial de velocidade
	var delta_v = v - v_leader  # Diferença de velocidade
	var b = 2.0  # Desaceleração confortável (m/s²)
	
	# Termo de aproximação IDM
	var s_star = s0 + max(0, v * T + (v * delta_v) / (2 * sqrt(3.0 * b)))
	
	# Distância final ajustada por personalidade - FATORES MAIORES
	var personality_factor = 1.0
	match car.personality:
		"aggressive": personality_factor = 0.8  # Distância menor mas não muito (era 0.7)
		"conservative": personality_factor = 1.5  # Distância maior (era 1.3)
		"elderly": personality_factor = 1.7      # Distância maior ainda (era 1.4)
		_: personality_factor = 1.2              # Normal aumentado (era 1.0)
	
	var safe_distance = s_star * personality_factor
	
	# GARANTIA ABSOLUTA: nunca menor que 5m
	safe_distance = max(safe_distance, 5.0)
	
	print("🔢 IDM calc for car %d: s0=%.1f, T=%.2f, v=%.1f, v_leader=%.1f → safe_dist=%.2f" % [
		car.id, s0, T, v, v_leader, safe_distance
	])
	
	return safe_distance

func calculate_queue_position_from_car(leader_car: DiscreteCar, safe_distance: float) -> Vector3:
	"""Calcula posição na fila baseada no carro à frente"""
	var leader_pos = leader_car.position  # Usar posição atual do líder
	var queue_pos = leader_pos
	
	# Ajustar posição baseado na direção - FICAR ATRÁS do líder
	match car.direction:
		"west_east": queue_pos.x -= safe_distance  # Ficar atrás (menor X)
		"east_west": queue_pos.x += safe_distance   # Ficar atrás (maior X)
		"south_north": queue_pos.z += safe_distance # Ficar atrás (maior Z)
	
	print("🚗 Car %d: Queue position behind car %d: leader at %s → queue at %s (distance: %.2fm)" % [
		car.id, leader_car.id, leader_pos, queue_pos, safe_distance
	])
	
	return queue_pos

func schedule_idm_queue_position(queue_position: Vector3, arrival_time: float):
	"""Agenda movimento para posição da fila COM VERIFICAÇÃO DE COLISÃO"""
	
	# VERIFICAR SE A POSIÇÃO DA FILA NÃO VAI COLIDIR COM OUTROS CARROS
	var safe_queue_position = verify_collision_free_position(queue_position)
	
	var queue_distance = car.position.distance_to(safe_queue_position)
	var queue_time = car.calculate_travel_time(queue_distance)
	var queue_arrival = car.spawn_time + queue_time
	
	# Movimento para posição da fila SEGURA
	scheduler.schedule_event(
		car.spawn_time + 0.1,
		DiscreteEventScheduler.EventType.CAR_START_CROSSING,
		car.id,
		{
			"car_id": car.id,
			"position": safe_queue_position,
			"crossing_duration": queue_time,
			"movement_type": "queue_follow"
		}
	)
	
	# Aguardar na fila e depois verificar semáforo
	scheduler.schedule_event(
		queue_arrival,
		DiscreteEventScheduler.EventType.CAR_START_WAITING,
		car.id,
		{
			"car_id": car.id,
			"position": safe_queue_position,
			"wait_duration": 0.5  # Pequena espera para sincronizar
		}
	)
	
	print("🚗 Car %d: Joining queue at SAFE position %s, arrival %.2fs" % [car.id, safe_queue_position, queue_arrival])

func verify_collision_free_position(desired_position: Vector3) -> Vector3:
	"""Verifica se a posição desejada não colide com outros carros"""
	var all_cars = spawn_system.get_active_cars() if spawn_system else {}
	var min_separation = 6.0  # Separação mínima absoluta entre carros
	
	for car_id in all_cars.keys():
		var other_car = all_cars[car_id]
		if other_car.id == car.id or other_car.direction != car.direction or other_car.lane != car.lane:
			continue
			
		var distance = desired_position.distance_to(other_car.position)
		if distance < min_separation:
			# Posição muito próxima - ajustar para trás
			var adjustment = adjust_position_to_avoid_collision(desired_position, other_car.position, min_separation)
			print("⚠️ Car %d: Collision risk detected! Moving from %s to %s" % [car.id, desired_position, adjustment])
			return adjustment
	
	return desired_position

func adjust_position_to_avoid_collision(desired_pos: Vector3, obstacle_pos: Vector3, min_distance: float) -> Vector3:
	"""Ajusta posição para evitar colisão"""
	var safe_pos = desired_pos
	
	# Mover para trás baseado na direção
	match car.direction:
		"west_east": safe_pos.x = obstacle_pos.x - min_distance
		"east_west": safe_pos.x = obstacle_pos.x + min_distance
		"south_north": safe_pos.z = obstacle_pos.z + min_distance
	
	return safe_pos

func schedule_map_exit(exit_intersection_time: float):
	"""Agenda saída do mapa"""
	var exit_distance = get_exit_distance(car.direction)  # ~28m
	var exit_time = car.calculate_travel_time(exit_distance)
	var final_exit_time = exit_intersection_time + exit_time
	
	scheduler.schedule_event(
		final_exit_time,
		DiscreteEventScheduler.EventType.CAR_EXIT_MAP,
		car.id,
		{
			"car_id": car.id,
			"final_position": get_map_exit_position(car.direction)
		}
	)
	
	print("🏁 Car %d: Will exit map at %.2fs" % [car.id, final_exit_time])

# Funções auxiliares para posições e distâncias
func get_approach_distance(direction: String) -> float:
	match direction:
		"west_east", "east_west": return 28.0  # 35 → 7
		"south_north": return 28.0  # 35 → 7
	return 28.0

func get_crossing_distance(direction: String) -> float:
	match direction:
		"west_east", "east_west": return 14.0  # -7 → +7  
		"south_north": return 14.0  # +7 → -7
	return 14.0

func get_exit_distance(direction: String) -> float:
	match direction:
		"west_east", "east_west": return 28.0  # 7 → 35
		"south_north": return 28.0  # -7 → -35
	return 28.0

# Posições específicas para cada direção
func get_intersection_approach_position(direction: String) -> Vector3:
	match direction:
		"west_east": return Vector3(-7, 0, -1.25)
		"east_west": return Vector3(7, 0, 1.25)
		"south_north": return Vector3(0, 0, 7)
	return Vector3.ZERO

func get_stop_position(direction: String) -> Vector3:
	# Posição de parada ANTES da faixa de pedestres (2m de segurança)
	match direction:
		"west_east": return Vector3(-9, 0, -1.25)    # Para 2m antes da faixa em x=-7
		"east_west": return Vector3(9, 0, 1.25)      # Para 2m antes da faixa em x=+7
		"south_north": return Vector3(0, 0, 9)       # Para 2m antes da faixa em z=+7
	return Vector3.ZERO

func get_intersection_exit_position(direction: String) -> Vector3:
	match direction:
		"west_east": return Vector3(7, 0, -1.25)
		"east_west": return Vector3(-7, 0, 1.25)
		"south_north": return Vector3(0, 0, -7)
	return Vector3.ZERO

func get_map_exit_position(direction: String) -> Vector3:
	# POSIÇÕES MAIS LONGE - carro sai completamente do campo de visão
	match direction:
		"west_east": return Vector3(45, 0, -1.25)    # Mais longe no leste
		"east_west": return Vector3(-45, 0, 1.25)    # Mais longe no oeste
		"south_north": return Vector3(0, 0, -45)     # Mais longe no norte
	return Vector3.ZERO
