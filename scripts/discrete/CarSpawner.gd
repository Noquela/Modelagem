extends Node

# CONFIGURAÇÃO IGUAL AO PROJETO ORIGINAL
const SPAWN_CONFIG = {
	"base_spawn_rate": 0.005,   # REDUZIDO DRASTICAMENTE - era 0.02
	"min_spawn_distance": 8.0,  # REDUZIDO: 12.0 → 8.0 para spawns mais próximos e filas densas
	"max_queue_length": 10,     # AUMENTADO: 6 → 10 para filas muito maiores
	# TAXAS BALANCEADAS PARA SPAWN CONSISTENTE
	"west_east_rate": 0.008,    # REDUZIDO - era 0.055
	"east_west_rate": 0.008,    # REDUZIDO - era 0.055
	"south_north_rate": 0.025   # AUMENTADO: 0.012 → 0.025 para spawn mais frequente
}

# DIREÇÕES DO PROJETO ORIGINAL
enum Direction { LEFT_TO_RIGHT, RIGHT_TO_LEFT, TOP_TO_BOTTOM, BOTTOM_TO_TOP }

var spawn_points = []
var max_cars: int = 30  # PADRÃO AUMENTADO: 15 → 30
var current_cars: int = 0
var total_cars_spawned: int = 0

var event_bus: Node
var simulation_clock: Node

# Rush hour simulation
var simulation_time: float = 0.0
var rush_hour_multiplier: float = 1.0

func _ready():
	print("🚗 CarSpawner inicializado")
	event_bus = get_node("/root/EventBus")
	simulation_clock = get_node("/root/SimulationClock")
	
	setup_spawn_points()
	setup_spawn_timer()
	
	event_bus.subscribe("car_despawned", _on_car_despawned)
	
	print("SpawnSystem initialized with directional spawn rates:")
	print("  West→East: %.3f (%.1fx base)" % [SPAWN_CONFIG.west_east_rate, SPAWN_CONFIG.west_east_rate/SPAWN_CONFIG.base_spawn_rate])
	print("  East→West: %.3f (%.1fx base)" % [SPAWN_CONFIG.east_west_rate, SPAWN_CONFIG.east_west_rate/SPAWN_CONFIG.base_spawn_rate]) 
	print("  South→North: %.3f (%.1fx base)" % [SPAWN_CONFIG.south_north_rate, SPAWN_CONFIG.south_north_rate/SPAWN_CONFIG.base_spawn_rate])

func setup_spawn_points():
	# SPAWN POINTS CORRIGIDOS - carros aparecem virados para a direção certa
	spawn_points = [
		# LEFT_TO_RIGHT (West → East) - LADO SUL da rua horizontal, carros indo para LESTE
		{
			"direction": Direction.LEFT_TO_RIGHT,
			"lane": 0,
			"position": Vector3(-35, 0.5, -1.25),  # SPAWN OESTE, lado SUL
			"name": "West_Entry",
			"direction_vector": Vector3(1, 0, 0),  # Direção: LESTE (+X)
			"lane_name": "horizontal_east"
		},
		# RIGHT_TO_LEFT (East → West) - LADO NORTE da rua horizontal, carros indo para OESTE
		{
			"direction": Direction.RIGHT_TO_LEFT,
			"lane": 0,
			"position": Vector3(35, 0.5, 1.25),   # SPAWN LESTE, lado NORTE
			"name": "East_Entry",
			"direction_vector": Vector3(-1, 0, 0), # Direção: OESTE (-X)
			"lane_name": "horizontal_west"
		},
		# BOTTOM_TO_TOP (South → North) - Rua vertical, carros indo para NORTE
		{
			"direction": Direction.BOTTOM_TO_TOP,
			"lane": 0,
			"position": Vector3(0.0, 0.5, 35),    # SPAWN SUL
			"name": "South_Entry",
			"direction_vector": Vector3(0, 0, -1), # Direção: NORTE (-Z)
			"lane_name": "vertical_north"
		}
		# REMOVIDO: North_Entry - rua secundária é mão única (Sul → Norte apenas)
	]

func setup_spawn_timer():
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 0.1  # Verificar spawn 10x por segundo
	timer.timeout.connect(_on_spawn_timer_timeout)
	timer.start()

func _on_spawn_timer_timeout():
	simulation_time += 0.1
	update_rush_hour_effect()
	spawn_cars()

func update_rush_hour_effect():
	# Simulação simplificada de rush hour - 24 horas em 24 minutos
	var sim_hour = fmod(simulation_time / 60.0, 24.0)
	
	# Curva de tráfego baseada no original
	if sim_hour >= 7.0 and sim_hour <= 9.0:  # Rush matinal
		rush_hour_multiplier = 2.0
	elif sim_hour >= 17.0 and sim_hour <= 19.0:  # Rush vespertino
		rush_hour_multiplier = 2.5
	elif sim_hour >= 12.0 and sim_hour <= 14.0:  # Almoço
		rush_hour_multiplier = 1.5
	elif sim_hour >= 22.0 or sim_hour <= 6.0:  # Madrugada
		if simulation_time < 120.0:  # Primeiros 2 minutos = taxa normal
			rush_hour_multiplier = 1.5
		else:
			rush_hour_multiplier = 0.3
	else:
		rush_hour_multiplier = 1.0

func spawn_cars():
	if current_cars >= max_cars:
		return
	
	# SISTEMA INTELIGENTE: Verificar ocupação por direção antes de spawnar
	var direction_occupancy = calculate_direction_occupancy()
	
	# Ordenar spawn points por prioridade (menos ocupadas primeiro)
	var prioritized_spawns = prioritize_spawn_points(direction_occupancy)
	
	# SPAWN BALANCEADO: Tentar spawnar apenas onde há espaço
	for spawn_data in prioritized_spawns:
		var spawn_point = spawn_data.spawn_point
		var occupancy = spawn_data.occupancy
		
		# Se direção está muito cheia (>80% da fila máxima), pular
		if occupancy > 0.8:
			if total_cars_spawned % 10 == 0:  # Debug ocasional
				var dir_name = get_direction_name(spawn_point.direction)
				print("⏸️ Spawn pausado em %s: ocupação %.1f%%" % [dir_name, occupancy * 100])
			continue
		
		# Tentar spawnar apenas se probabilidade permitir E há espaço
		if should_spawn_car(spawn_point):
			var success = attempt_spawn_at_point(spawn_point)
			if success:
				break  # IMPORTANTE: Spawnar apenas 1 por tick para evitar sobrecarga
	
	# SPAWN EXTRA apenas para direções com baixa ocupação (<50%)
	attempt_extra_spawns(direction_occupancy)

func should_spawn_car(spawn_point: Dictionary) -> bool:
	# ALGORITMO COM TAXAS ESPECÍFICAS POR DIREÇÃO
	var spawn_probability: float
	var direction = spawn_point.direction
	
	match direction:
		Direction.LEFT_TO_RIGHT:  # West → East
			spawn_probability = SPAWN_CONFIG.west_east_rate * rush_hour_multiplier
		Direction.RIGHT_TO_LEFT:  # East → West
			spawn_probability = SPAWN_CONFIG.east_west_rate * rush_hour_multiplier
		Direction.BOTTOM_TO_TOP:  # South → North
			spawn_probability = SPAWN_CONFIG.south_north_rate * rush_hour_multiplier
		_:  # Fallback
			spawn_probability = SPAWN_CONFIG.base_spawn_rate * rush_hour_multiplier
	
	# Verificar probabilidade
	return randf() < spawn_probability

func choose_lane_for_direction(direction: int) -> int:
	# Escolher faixa baseado na direção
	match direction:
		Direction.LEFT_TO_RIGHT, Direction.RIGHT_TO_LEFT:  # duas faixas
			return randi() % 2  # Simplificado: escolher aleatoriamente entre 0 e 1
		Direction.BOTTOM_TO_TOP:  # única direção da rua vertical
			return 0
		_:
			return 0

func adjust_spawn_position_for_lane(spawn_point: Dictionary, lane: int) -> Vector3:
	# Ajustar posição do spawn baseado na faixa escolhida - CORRIGIDO PARA ORIENTAÇÃO CERTA
	match spawn_point.direction:
		Direction.LEFT_TO_RIGHT:  # LEFT_TO_RIGHT (West → East) - lado SUL da rua horizontal
			# Faixas no lado SUL (Z negativo), lane 0 mais ao norte, lane 1 mais ao sul
			var z_offset = -1.25 - (lane * 1.5)  # Lane 0: Z=-1.25, Lane 1: Z=-2.75
			return Vector3(-35, 0.5, z_offset)
		Direction.RIGHT_TO_LEFT:  # RIGHT_TO_LEFT (East → West) - lado NORTE da rua horizontal
			# Faixas no lado NORTE (Z positivo), lane 0 mais ao sul, lane 1 mais ao norte  
			var z_offset = 1.25 + (lane * 1.5)   # Lane 0: Z=1.25, Lane 1: Z=2.75
			return Vector3(35, 0.5, z_offset)
		Direction.BOTTOM_TO_TOP:  # BOTTOM_TO_TOP (South → North) - rua vertical única faixa
			return Vector3(0.0, 0.5, 35)
		_:
			return spawn_point.position

func spawn_car_at_point(spawn_point: Dictionary):
	if current_cars >= max_cars:
		return
	
	# VERIFICAR DISTÂNCIA MÍNIMA - não spawnar se há carros muito próximos
	if not can_spawn_at_position(spawn_point.position, spawn_point.direction):
		return
		
	var car_data = {
		"id": generate_car_id(),
		"position": spawn_point.position,
		"direction": spawn_point.direction_vector,
		"lane": spawn_point.lane_name,
		"speed": randf_range(5.0, 15.0),
		"spawn_time": simulation_clock.get_simulation_time(),
		"direction_enum": spawn_point.direction,
		"lane_index": spawn_point.lane
	}
	
	current_cars += 1
	total_cars_spawned += 1
	event_bus.emit_event("car_spawned", car_data)
	
	# Debug ocasional
	if total_cars_spawned % 10 == 0:
		var direction_names = ["West→East", "East→West", "North→South", "South→North"]
		var dir_name = direction_names[spawn_point.direction] if spawn_point.direction < 4 else "Unknown"
		print("Car spawned #%d | %s Lane: %d | Active: %d" % [total_cars_spawned, dir_name, spawn_point.lane, current_cars])

func _on_car_despawned(_car_data):
	current_cars -= 1
	# print("🚗 Carro despawned: ", car_data.id)

func can_spawn_at_position(pos: Vector3, direction: int) -> bool:
	# Verificar se há carros muito próximos na mesma direção/faixa
	var discrete_sim = get_node("/root/DiscreteSimulation")
	if not discrete_sim or not discrete_sim.has_method("get_active_cars"):
		return true  # Se não conseguir verificar, permitir spawn
	
	var active_cars = discrete_sim.get("active_cars")
	if not active_cars:
		return true
	
	# VERIFICAÇÃO RIGOROSA: Verificar TODAS as posições dos carros existentes
	for car_id in active_cars.keys():
		var car = active_cars[car_id]
		if not car or not car.has("target_position"):
			continue
			
		var car_pos = car.target_position
		
		# VERIFICAÇÃO GLOBAL: Distância mínima absoluta entre qualquer carro e spawn
		# Usar distância mínima mais permissiva para direção N-S devido à geometria da interseção
		var min_distance = SPAWN_CONFIG.min_spawn_distance
		if direction == Direction.BOTTOM_TO_TOP:
			min_distance = SPAWN_CONFIG.min_spawn_distance * 0.75  # 25% mais permissivo para N-S
		
		var distance_to_car = pos.distance_to(car_pos)
		if distance_to_car < min_distance:
			# Debug: mostrar quando bloqueia spawn por proximidade
			if total_cars_spawned % 5 == 0:  # Debug ocasional
				print("🚫 Spawn bloqueado: carro %s muito próximo (%.1fm < %.1fm)" % [car_id, distance_to_car, min_distance])
			return false
	
	# VERIFICAÇÃO ESPECÍFICA POR DIREÇÃO: Carros na mesma direção/faixa
	var cars_in_direction = []
	for car_id in active_cars.keys():
		var car = active_cars[car_id]
		if car.direction_enum == direction:
			cars_in_direction.append(car)
	
	# LÓGICA DE FILA: Limitar carros por direção
	if cars_in_direction.size() >= SPAWN_CONFIG.max_queue_length:
		if total_cars_spawned % 5 == 0:  # Debug ocasional
			print("🚫 Spawn bloqueado: muitos carros na direção (%d/%d)" % [cars_in_direction.size(), SPAWN_CONFIG.max_queue_length])
		return false
	
	# VERIFICAÇÃO DE FAIXA ESPECÍFICA: Carros na mesma linha de spawn
	for car in cars_in_direction:
		var car_pos = car.target_position
		var lateral_distance = 0.0
		var forward_distance = 0.0
		
		match direction:
			0:  # LEFT_TO_RIGHT (West → East)
				lateral_distance = abs(car_pos.z - pos.z)  # Distância lateral (norte-sul)
				forward_distance = car_pos.x - pos.x       # Distância frontal (leste-oeste)
			1:  # RIGHT_TO_LEFT (East → West)
				lateral_distance = abs(car_pos.z - pos.z)  # Distância lateral (norte-sul)
				forward_distance = pos.x - car_pos.x       # Distância frontal (oeste-leste)
			3:  # BOTTOM_TO_TOP (South → North)
				lateral_distance = abs(car_pos.x - pos.x)  # Distância lateral (leste-oeste)
				forward_distance = pos.z - car_pos.z       # Distância frontal (norte-sul)
		
		# Se o carro está na mesma faixa (lateral < 2m) e próximo na frente
		# Distâncias frontais específicas por direção - FILAS DENSAS
		var min_forward_distance = 6.0  # REDUZIDO: 15.0 → 6.0 para filas mais próximas
		if direction == Direction.BOTTOM_TO_TOP:
			min_forward_distance = 4.0  # REDUZIDO: 8.0 → 4.0 para N-S ainda mais denso
		
		if lateral_distance < 2.0 and forward_distance > 0 and forward_distance < min_forward_distance:
			if total_cars_spawned % 5 == 0:  # Debug ocasional
				print("🚫 Spawn bloqueado: carro na faixa a %.1fm à frente (min: %.1f)" % [forward_distance, min_forward_distance])
			return false
	
	return true

func generate_car_id() -> String:
	return "car_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000)

func set_max_cars(maximum: int):
	max_cars = clamp(maximum, 1, 200)

# SISTEMA INTELIGENTE DE SPAWN - FUNÇÕES AUXILIARES

func calculate_direction_occupancy() -> Dictionary:
	# Calcular quantos carros há em cada direção
	var discrete_sim = get_node("/root/DiscreteSimulation")
	if not discrete_sim:
		return {}
	
	var active_cars = discrete_sim.get("active_cars")
	if not active_cars:
		return {}
	
	var direction_counts = {
		Direction.LEFT_TO_RIGHT: 0,
		Direction.RIGHT_TO_LEFT: 0,
		Direction.BOTTOM_TO_TOP: 0
	}
	
	# Contar carros por direção
	for car_id in active_cars.keys():
		var car = active_cars[car_id]
		if car.has("direction_enum"):
			var dir = car.direction_enum
			if direction_counts.has(dir):
				direction_counts[dir] += 1
	
	# Converter para percentual de ocupação (baseado na fila máxima)
	var occupancy = {}
	for direction in direction_counts.keys():
		occupancy[direction] = float(direction_counts[direction]) / float(SPAWN_CONFIG.max_queue_length)
	
	return occupancy

func prioritize_spawn_points(occupancy: Dictionary) -> Array:
	# Criar lista com spawn points e suas ocupações
	var spawn_list = []
	for spawn_point in spawn_points:
		var dir = spawn_point.direction
		var occ = occupancy.get(dir, 0.0)
		spawn_list.append({
			"spawn_point": spawn_point,
			"occupancy": occ
		})
	
	# Ordenar por ocupação (menos ocupadas primeiro)
	spawn_list.sort_custom(func(a, b): return a.occupancy < b.occupancy)
	
	return spawn_list

func attempt_spawn_at_point(spawn_point: Dictionary) -> bool:
	# Escolher faixa dinamicamente para direções com 2 faixas
	var primary_lane = choose_lane_for_direction(spawn_point.direction)
	
	# Ajustar posição para a faixa escolhida
	var modified_spawn_point = spawn_point.duplicate()
	modified_spawn_point.lane = primary_lane
	modified_spawn_point.position = adjust_spawn_position_for_lane(spawn_point, primary_lane)
	
	# Tentar spawnar (retorna true se bem-sucedido)
	var initial_count = current_cars
	spawn_car_at_point(modified_spawn_point)
	return current_cars > initial_count

func attempt_extra_spawns(occupancy: Dictionary):
	# SPAWN EXTRA apenas para direções com ocupação baixa
	for spawn_point in spawn_points:
		var dir = spawn_point.direction
		var occ = occupancy.get(dir, 0.0)
		
		# Só spawn extra se ocupação < 50% E direção tem 2 faixas
		if occ < 0.5 and spawn_point.direction in [Direction.LEFT_TO_RIGHT, Direction.RIGHT_TO_LEFT]:
			if randf() < 0.2:  # 20% chance (reduzido de 40%)
				for alternative_lane in [0, 1]:
					var primary_lane = choose_lane_for_direction(spawn_point.direction)
					if alternative_lane != primary_lane:
						var modified_spawn_point = spawn_point.duplicate()
						modified_spawn_point.lane = alternative_lane
						modified_spawn_point.position = adjust_spawn_position_for_lane(spawn_point, alternative_lane)
						spawn_car_at_point(modified_spawn_point)
						return  # Apenas 1 spawn extra por tick

func get_direction_name(direction: int) -> String:
	match direction:
		Direction.LEFT_TO_RIGHT: return "West→East"
		Direction.RIGHT_TO_LEFT: return "East→West"
		Direction.BOTTOM_TO_TOP: return "South→North"
		_: return "Unknown"