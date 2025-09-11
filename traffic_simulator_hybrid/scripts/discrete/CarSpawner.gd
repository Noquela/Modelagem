extends Node

# CONFIGURAÇÃO IGUAL AO PROJETO ORIGINAL
const SPAWN_CONFIG = {
	"base_spawn_rate": 0.005,   # REDUZIDO DRASTICAMENTE - era 0.02
	"min_spawn_distance": 10.0,
	"max_queue_length": 4,
	# TAXAS REDUZIDAS PARA PERFORMANCE
	"west_east_rate": 0.008,    # REDUZIDO - era 0.055
	"east_west_rate": 0.008,    # REDUZIDO - era 0.055
	"south_north_rate": 0.025   # AUMENTADO para ser mais visível - igual às outras direções
}

# DIREÇÕES DO PROJETO ORIGINAL
enum Direction { LEFT_TO_RIGHT, RIGHT_TO_LEFT, TOP_TO_BOTTOM, BOTTOM_TO_TOP }

var spawn_points = []
var max_cars: int = 15  # REDUZIDO - era 50
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
	
	# Para cada spawn point, tentar spawnar um carro
	for spawn_point in spawn_points:
		if should_spawn_car(spawn_point):
			# Escolher faixa dinamicamente para direções com 2 faixas
			var primary_lane = choose_lane_for_direction(spawn_point.direction)
			
			# Ajustar posição para a faixa escolhida
			var modified_spawn_point = spawn_point.duplicate()
			modified_spawn_point.lane = primary_lane
			modified_spawn_point.position = adjust_spawn_position_for_lane(spawn_point, primary_lane)
			
			spawn_car_at_point(modified_spawn_point)
		
		# SPAWN EXTRA para direções com 2 faixas (tentar ambas as faixas)
		var extra_spawn_chance = 0.4
		if spawn_point.direction in [Direction.LEFT_TO_RIGHT, Direction.RIGHT_TO_LEFT] and randf() < extra_spawn_chance:
			for alternative_lane in [0, 1]:
				var primary_lane = choose_lane_for_direction(spawn_point.direction)
				if alternative_lane != primary_lane:
					var modified_spawn_point = spawn_point.duplicate()
					modified_spawn_point.lane = alternative_lane
					modified_spawn_point.position = adjust_spawn_position_for_lane(spawn_point, alternative_lane)
					spawn_car_at_point(modified_spawn_point)
					break

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
	
	# NOVA LÓGICA: Contar carros na mesma direção para permitir formação de filas
	var cars_in_direction = []
	for car_id in active_cars.keys():
		var car = active_cars[car_id]
		if car.direction_enum == direction:
			cars_in_direction.append(car)
	
	# Se não há carros na direção, pode spawnar
	if cars_in_direction.size() == 0:
		return true
	
	# LÓGICA DE FILA: Permitir até 4 carros enfileirados (max_queue_length)
	if cars_in_direction.size() >= SPAWN_CONFIG.max_queue_length:
		return false
	
	# Verificar distância mínima apenas do carro mais próximo ao spawn
	var closest_distance = INF
	for car in cars_in_direction:
		var distance = 0.0
		match direction:
			0:  # LEFT_TO_RIGHT
				if car.target_position.x > pos.x:  # Carro à frente
					distance = car.target_position.x - pos.x
			1:  # RIGHT_TO_LEFT  
				if car.target_position.x < pos.x:  # Carro à frente
					distance = pos.x - car.target_position.x
			3:  # BOTTOM_TO_TOP
				if car.target_position.z < pos.z:  # Carro à frente
					distance = pos.z - car.target_position.z
		
		if distance > 0 and distance < closest_distance:
			closest_distance = distance
	
	# DISTÂNCIA REDUZIDA para permitir filas mais densas
	var min_distance_for_queue = 3.0  # Menor que os 10.0 originais
	if closest_distance < min_distance_for_queue:
		return false
	
	return true

func generate_car_id() -> String:
	return "car_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000)

func set_max_cars(maximum: int):
	max_cars = clamp(maximum, 1, 200)