extends Node3D
class_name SpawnSystem

var traffic_manager: Node
var car_scene = preload("res://scenes/Car.tscn")

# CONFIGURAÇÃO ANTI-TELEPORTE COM TAXAS DIFERENTES POR DIREÇÃO
const SPAWN_CONFIG = {
	"base_spawn_rate": 0.04,   # Taxa base
	"min_spawn_distance": 8.0,  # Distância mínima entre carros
	"randomness_factor": 0.5,   # Fator de aleatoriedade
	"max_queue_length": 8,      # Máximo de carros na fila
	# TAXAS ESPECÍFICAS POR DIREÇÃO
	"west_east_rate": 0.12,     # RUA PRINCIPAL: West→East (MUITO TRÁFEGO)
	"east_west_rate": 0.10,     # RUA PRINCIPAL: East→West (MUITO TRÁFEGO) 
	"south_north_rate": 0.02    # RUA SECUNDÁRIA: South→North (POUCO TRÁFEGO)
}

var spawn_points: Array[Dictionary] = []
var cars: Array = []
var total_cars_spawned: int = 0

# Rush hour simulation - baseado no HTML
var simulation_time: float = 0.0
var rush_hour_multiplier: float = 1.0

func _ready():
	traffic_manager = get_parent().get_node("TrafficManager")
	add_to_group("spawn_system")
	setup_spawn_points()
	create_spawn_visual_markers()  # DEBUG: visualizar spawn points
	set_process(true)
	print("SpawnSystem initialized with directional spawn rates:")
	print("  West→East: %.3f (%.1fx base)" % [SPAWN_CONFIG.west_east_rate, SPAWN_CONFIG.west_east_rate/SPAWN_CONFIG.base_spawn_rate])
	print("  East→West: %.3f (%.1fx base)" % [SPAWN_CONFIG.east_west_rate, SPAWN_CONFIG.east_west_rate/SPAWN_CONFIG.base_spawn_rate]) 
	print("  South→North: %.3f (%.1fx base)" % [SPAWN_CONFIG.south_north_rate, SPAWN_CONFIG.south_north_rate/SPAWN_CONFIG.base_spawn_rate])

func _process(delta):
	simulation_time += delta
	update_rush_hour_effect()
	spawn_cars()
	cleanup_invalid_cars()

func setup_spawn_points():
	# 3 SPAWN POINTS - RUA PRINCIPAL TEM 2 DIREÇÕES, RUA SECUNDÁRIA TEM 1 (SÓ SUL→NORTE)
	spawn_points = [
		# LEFT_TO_RIGHT (West → East) - FAIXA SUL DA RUA HORIZONTAL
		{
			"direction": 0,  
			"lane": 0,
			"position": Vector3(-35, 0.5, -1.25),  # SPAWN OESTE EM -35
			"name": "West_Entry"
		},
		# RIGHT_TO_LEFT (East → West) - FAIXA NORTE DA RUA HORIZONTAL
		{
			"direction": 1,
			"lane": 0,
			"position": Vector3(35, 0.5, 1.25),   # SPAWN LESTE EM +35
			"name": "East_Entry"
		},
		# TOP_TO_BOTTOM (South → North) - ÚNICA DIREÇÃO DA RUA VERTICAL (1 SEMÁFORO)
		{
			"direction": 2,
			"lane": 0,
			"position": Vector3(0.0, 0.5, 35),    # SPAWN SUL EM +35
			"name": "South_Entry"
		}
		# REMOVIDO: North_Entry - rua secundária é mão única (Sul → Norte apenas)
	]

func create_spawn_visual_markers():
	# DESABILITADO - Marcadores visuais removidos para evitar travamentos
	pass
	
	# LIMPAR QUALQUER MODELO DE CARRO ÓRFÃO
	cleanup_orphaned_car_models()

func cleanup_orphaned_car_models():
	# Procurar por modelos de carro órfãos que não foram removidos
	var main_scene = get_parent()
	for child in main_scene.get_children():
		if child.name.begins_with("CarModel") or child.name.contains("sedan") or child.name.contains("suv"):
			print("WARNING: Found orphaned car model: ", child.name, " at ", child.position)
			child.queue_free()  # Remover modelo órfão

func update_rush_hour_effect():
	# Simulação simplificada de rush hour - 24 horas em 24 minutos
	var sim_hour = fmod(simulation_time / 60.0, 24.0)
	
	# Curva de tráfego baseada no HTML
	if sim_hour >= 7.0 and sim_hour <= 9.0:  # Rush matinal
		rush_hour_multiplier = 2.0
	elif sim_hour >= 17.0 and sim_hour <= 19.0:  # Rush vespertino
		rush_hour_multiplier = 2.5
	elif sim_hour >= 12.0 and sim_hour <= 14.0:  # Almoço
		rush_hour_multiplier = 1.5
	elif sim_hour >= 22.0 or sim_hour <= 6.0:  # Madrugada
		# EXCEÇÃO: No início da simulação (primeiros 2 minutos), usar taxa normal
		if simulation_time < 120.0:  # Primeiros 2 minutos = taxa normal para formar filas
			rush_hour_multiplier = 1.5
		else:
			rush_hour_multiplier = 0.3
	else:
		rush_hour_multiplier = 1.0

func spawn_cars():
	# SISTEMA SIMPLIFICADO - 1 SPAWN POINT POR RUA
	if not get_tree().get_first_node_in_group("traffic_manager"):
		return
	
	# Sistema de spawn mais aleatório com intervalos variáveis
	var _baseSpawnChance = SPAWN_CONFIG.base_spawn_rate  # Unused but kept for reference
	var _randomFactor = 0.5 + randf()  # entre 0.5 e 1.5 - unused but kept for reference
	
	# Para cada spawn point, tentar spawnar um carro
	for spawn_point in spawn_points:
		# Usar nova lógica com taxas específicas por direção (em should_spawn_car)
		
		# Escolher faixa dinamicamente para direções com 2 faixas (FORA do if para escopo correto)
		var primary_lane = choose_lane_for_direction(spawn_point.direction)
		
		# Usar should_spawn_car que agora tem lógica específica por direção
		if should_spawn_car(spawn_point):
			# SEMPRE tentar spawnar - formação de filas é DESEJADA
			if can_spawn_in_direction_lane(spawn_point.direction, primary_lane):
				var modified_spawn_point = spawn_point.duplicate()
				modified_spawn_point.lane = primary_lane
				modified_spawn_point.position = adjust_spawn_position_for_lane(spawn_point, primary_lane)
				create_car(modified_spawn_point)
		
		# SPAWN EXTRA para direções com 2 faixas (tentar ambas as faixas)
		# Também reduzido para a rua oeste-leste
		var extra_spawn_chance = 0.6 if spawn_point.direction == 2 else 0.3  # Norte: 60%, Oeste-Leste: 30%
		if spawn_point.direction in [0, 1] and randf() < 0.2 * extra_spawn_chance:
			# Tentar spawnar na outra faixa (0 ou 1)
			for alternative_lane in [0, 1]:
				if alternative_lane != primary_lane and can_spawn_in_direction_lane(spawn_point.direction, alternative_lane):
					var modified_spawn_point = spawn_point.duplicate()
					modified_spawn_point.lane = alternative_lane
					modified_spawn_point.position = adjust_spawn_position_for_lane(spawn_point, alternative_lane)
					create_car(modified_spawn_point)
					break  # Spawnar apenas um carro extra por ciclo

func should_spawn_car(spawn_point: Dictionary) -> bool:
	# ALGORITMO COM TAXAS ESPECÍFICAS POR DIREÇÃO
	
	# 1. Determinar taxa baseada na direção
	var spawn_probability: float
	var direction = spawn_point.direction
	
	match direction:
		0:  # West → East (LEFT_TO_RIGHT)
			spawn_probability = SPAWN_CONFIG.west_east_rate * rush_hour_multiplier
		1:  # East → West (RIGHT_TO_LEFT) 
			spawn_probability = SPAWN_CONFIG.east_west_rate * rush_hour_multiplier
		2:  # South → North (TOP_TO_BOTTOM)
			spawn_probability = SPAWN_CONFIG.south_north_rate * rush_hour_multiplier
		_:  # Fallback
			spawn_probability = SPAWN_CONFIG.base_spawn_rate * rush_hour_multiplier
	
	# 2. Verificar probabilidade
	if randf() > spawn_probability:
		return false
	
	# 3. Verificar se pode spawnar com segurança (FUNÇÃO CRÍTICA)
	if not can_spawn_safely(spawn_point):
		return false
	
	# 4. Verificar se há espaço para formação de fila
	if not has_space_for_queueing(spawn_point):
		return false
	
	return true

func can_spawn_safely(spawn_point: Dictionary) -> bool:
	# VERIFICAÇÃO EXATA DO HTML - evitar spawn muito próximo
	var spawn_pos = spawn_point.position
	var direction = spawn_point.direction
	var lane = spawn_point.lane
	
	# Buscar carros na mesma direção e lane
	for car in get_cars_in_same_lane(direction, lane):
		if not is_instance_valid(car):
			continue
			
		var distance = get_directional_distance_to_spawn(car, spawn_pos, direction)
		
		# LÓGICA DO HTML: se há um carro muito próximo do spawn, não spawnar
		if distance >= 0 and distance < SPAWN_CONFIG.min_spawn_distance * 1.5:  # Aumentado para evitar sobreposição
			return false
	
	return true

func has_space_for_queueing(spawn_point: Dictionary) -> bool:
	# FUNÇÃO EXATA DO HTML - linhas 597-618
	# Verificar se há espaço para formar fila, mesmo com semáforo vermelho
	var spawnPos = spawn_point.position
	var carsInLane = get_cars_in_same_lane(spawn_point.direction, spawn_point.lane)
	
	if carsInLane.is_empty():
		return true  # HTML linha 602
	
	# Encontrar o último carro da fila (mais próximo do spawn) - HTML linhas 604-614
	var lastCarInQueue = null
	var closestDistanceToSpawn = INF
	
	for car in carsInLane:
		var distanceToSpawn = calculateDirectionalDistance(spawnPos, car.global_position, spawn_point.direction)
		if distanceToSpawn >= 0 and distanceToSpawn < closestDistanceToSpawn:
			closestDistanceToSpawn = distanceToSpawn
			lastCarInQueue = car
	
	# Se há espaço de pelo menos 4 unidades atrás do último carro da fila, pode spawnar (HTML linha 617)
	return not lastCarInQueue or closestDistanceToSpawn >= SPAWN_CONFIG.min_spawn_distance

func calculateDirectionalDistance(spawnPos: Vector3, carPos: Vector3, direction: int) -> float:
	# FUNÇÃO EXATA DO HTML - linhas 620-631
	# Calcular distância na direção correta do movimento
	match direction:
		0:  # LEFT_TO_RIGHT (HTML linha 623-624)
			return carPos.x - spawnPos.x  # positivo se o carro está à frente
		1:  # RIGHT_TO_LEFT (HTML linha 625-626)
			return spawnPos.x - carPos.x  # positivo se o carro está à frente  
		2:  # TOP_TO_BOTTOM South→North (Z=25 para Z=-25) - única direção da rua vertical
			return spawnPos.z - carPos.z  # positivo se o carro está à frente (mais ao norte)
	
	return 0.0  # HTML linha 630

# Manter função antiga para compatibilidade
func calculate_directional_distance_to_spawn(car, spawn_point: Dictionary) -> float:
	return calculateDirectionalDistance(spawn_point.position, car.global_position, spawn_point.direction)

# FUNÇÕES AUXILIARES DO HTML

func choose_lane_for_direction(direction: int) -> int:
	# Escolher faixa baseado na direção
	match direction:
		0, 1:  # LEFT_TO_RIGHT, RIGHT_TO_LEFT (duas faixas)
			return chooseBestLane(direction)
		2:  # TOP_TO_BOTTOM (única direção da rua vertical)
			return 0
		_:
			return 0

func can_spawn_in_direction_lane(direction: int, lane: int) -> bool:
	# SISTEMA PERMISSIVO - PERMITE FILAS GRANDES como no HTML
	var carsInLane = get_cars_in_same_lane(direction, lane)
	if carsInLane.is_empty():
		return true
	
	# Permitir até 10 carros por faixa para formar filas longas
	if carsInLane.size() >= 10:
		return false  # Só bloquear se há muitos carros
	
	# Verificar se o último carro está longe o suficiente do spawn
	var spawnPos = getSpawnPosition(direction, lane)
	var closestDistance = INF
	
	for car in carsInLane:
		var distance = calculateDirectionalDistance(spawnPos, car.global_position, direction)
		if distance >= 0 and distance < closestDistance:
			closestDistance = distance
	
	# Permitir spawn se o carro mais próximo está a pelo menos 5 unidades
	return closestDistance >= 5.0  # AUMENTADO: evitar sobreposições

func adjust_spawn_position_for_lane(spawn_point: Dictionary, lane: int) -> Vector3:
	# Ajustar posição do spawn baseado na faixa escolhida - USANDO POSIÇÕES DOS SPAWN_POINTS
	match spawn_point.direction:
		0:  # LEFT_TO_RIGHT - faixas mais para cima (Z menos negativo)
			var z_offset = -2.0 + (lane * -1.5)  # Lane 0: Z=-2.0, Lane 1: Z=-0.5 (mais para cima)
			return Vector3(-35, 0.5, z_offset)  # USAR -35 (spawn_point correto)
		1:  # RIGHT_TO_LEFT - faixas acima da linha central (Z positivo)  
			var z_offset = 3.0 - (lane * 2.0)     # Lane 0: Z=3.0, Lane 1: Z=1.0 (sem sobreposição com linha central Z=0)
			return Vector3(35, 0.5, z_offset)   # USAR +35 (spawn_point correto)
		2:  # TOP_TO_BOTTOM - única direção da rua vertical
			return Vector3(0.0, 0.5, 35)   # USAR +35 (spawn_point correto)
		_:
			return spawn_point.position

func get_spawn_point_for_direction_lane(direction: int, _lane: int) -> Dictionary:
	# Encontrar spawn point correspondente
	for sp in spawn_points:
		if sp.direction == direction:
			return sp
	
	# Fallback
	return spawn_points[0]

func chooseBestLane(direction: int) -> int:
	# FUNÇÃO DO HTML - linhas 633-660
	var maxLanes = 1 if direction == 2 else 2  # TOP_TO_BOTTOM só tem 1 faixa
	var bestLane = -1
	var maxDistance = 0.0
	
	# Verificar qual faixa tem mais espaço para spawnar (HTML linha 639-645)
	for lane in range(maxLanes):
		var distanceToNearestCar = getDistanceToNearestCarInLane(direction, lane)
		if distanceToNearestCar >= SPAWN_CONFIG.min_spawn_distance and distanceToNearestCar > maxDistance:
			maxDistance = distanceToNearestCar
			bestLane = lane
	
	# Se nenhuma faixa tem espaço ideal, escolher a menos congestionada (HTML linha 647-657)
	if bestLane == -1:
		var minCarsInLane = 99999
		for lane in range(maxLanes):
			var carsInLane = get_cars_in_same_lane(direction, lane).size()
			if carsInLane < minCarsInLane:
				minCarsInLane = carsInLane
				bestLane = lane
	
	return bestLane

func getDistanceToNearestCarInLane(direction: int, lane: int) -> float:
	# FUNÇÃO DO HTML - linhas 662-677
	var spawnPos = getSpawnPosition(direction, lane)
	var minDistance = INF
	
	var all_cars = get_tree().get_nodes_in_group("cars")
	for car in all_cars:
		if not is_instance_valid(car):
			continue
		if car.direction == direction and car.lane == lane:
			# Usar distância direcional em vez de euclidiana (HTML linha 668-669)
			var directionalDistance = calculateDirectionalDistance(spawnPos, car.global_position, direction)
			if directionalDistance >= 0 and directionalDistance < minDistance:
				minDistance = directionalDistance
	
	return 25.0 if minDistance == INF else minDistance  # distância padrão maior (HTML linha 676)

func canSpawnInLane(direction: int, lane: int) -> bool:
	# FUNÇÃO EXATA DO HTML - linhas 679-682
	# Critério mais flexível - pode spawnar se há pelo menos distância mínima
	return getDistanceToNearestCarInLane(direction, lane) >= SPAWN_CONFIG.min_spawn_distance

func hasSpaceForQueueing(direction: int, lane: int) -> bool:
	# FUNÇÃO EXATA DO HTML - linhas 597-618
	# CRÍTICO: Esta função DEVE permitir formação de filas mesmo com semáforo vermelho
	var spawnPos = getSpawnPosition(direction, lane)
	var carsInLane = get_cars_in_same_lane(direction, lane)
	
	if carsInLane.is_empty():
		return true  # HTML linha 602 - sempre pode spawnar se não há carros
	
	# Encontrar o último carro da fila (mais próximo do spawn) - HTML linhas 604-614
	var lastCarInQueue = null
	var closestDistanceToSpawn = INF
	
	for car in carsInLane:
		var distanceToSpawn = calculateDirectionalDistance(spawnPos, car.global_position, direction)
		if distanceToSpawn >= 0 and distanceToSpawn < closestDistanceToSpawn:
			closestDistanceToSpawn = distanceToSpawn
			lastCarInQueue = car
	
	# Se há espaço de pelo menos 4 unidades atrás do último carro da fila, pode spawnar (HTML linha 617)
	return not lastCarInQueue or closestDistanceToSpawn >= SPAWN_CONFIG.min_spawn_distance

func getSpawnPosition(direction: int, lane: int) -> Vector3:
	# SPAWN POSITIONS CORRETOS - USANDO AS POSIÇÕES DOS SPAWN_POINTS
	var pos = Vector3.ZERO
	match direction:
		0:  # LEFT_TO_RIGHT - spawn do OESTE - faixas mais para cima
			var z_offset = -2.0 + (lane * -1.5)  # Lane 0: Z=-2.0, Lane 1: Z=-0.5 (mais para cima)
			pos = Vector3(-35, 0.5, z_offset)  # USAR -35 (spawn_point correto)
		1:  # RIGHT_TO_LEFT - spawn do LESTE - faixas acima da linha central
			var z_offset = 3.0 - (lane * 2.0)     # Lane 0: Z=3.0, Lane 1: Z=1.0
			pos = Vector3(35, 0.5, z_offset)   # USAR +35 (spawn_point correto)
		2:  # TOP_TO_BOTTOM - spawn do SUL (única direção da rua vertical)
			pos = Vector3(0.0, 0.5, 35)    # USAR +35 (spawn_point correto)
	return pos

func get_cars_in_same_lane(direction, lane: int) -> Array:
	# OTIMIZAÇÃO - buscar apenas carros na mesma direção e lane
	var cars_in_lane: Array = []
	
	for car in get_tree().get_nodes_in_group("cars"):
		if not is_instance_valid(car):
			continue
			
		if car.direction == direction and car.lane == lane:
			cars_in_lane.append(car)
	
	return cars_in_lane

func get_directional_distance_to_spawn(car, spawn_pos: Vector3, direction) -> float:
	# FUNÇÃO CRÍTICA - calcular distância direcional correta (HTML → 3D)
	var car_pos = car.global_position
	
	match direction:
		0:  # LEFT_TO_RIGHT - West → East
			return spawn_pos.x - car_pos.x  # Positivo = carro antes do spawn
		1:  # RIGHT_TO_LEFT - East → West  
			return car_pos.x - spawn_pos.x  # Positivo = carro antes do spawn
		2:  # TOP_TO_BOTTOM - South → North (única direção da rua vertical)
			return spawn_pos.z - car_pos.z  # Positivo = carro antes do spawn
	
	return 0.0

func create_car(spawn_point: Dictionary):
	# CRIAR CARRO - lógica do HTML
	var car = car_scene.instantiate()
	car.direction = spawn_point.direction
	car.lane = spawn_point.lane
	car.car_id = total_cars_spawned
	
	# Adicionar ao mundo PRIMEIRO
	get_parent().add_child(car)
	
	# DEFINIR POSIÇÃO E ROTAÇÃO usando SpawnSystem (não Car.gd)
	set_car_spawn_position(car, spawn_point)
	
	# DEBUG: Log da criação do carro
	print("DEBUG: Creating car #", total_cars_spawned, " at spawn point ", spawn_point.name, " actual position: ", car.global_position)
	
	cars.append(car)
	total_cars_spawned += 1

func set_car_spawn_position(car: Node3D, spawn_point: Dictionary):
	# DEFINIR POSIÇÃO E ROTAÇÃO CORRETAS baseadas no SpawnSystem
	var rotationY: float
	
	match spawn_point.direction:
		0:  # LEFT_TO_RIGHT (West→East)
			rotationY = PI/2  # +90° para apontar para +X (LESTE)
		1:  # RIGHT_TO_LEFT (East→West)  
			rotationY = -PI/2  # -90° para apontar para -X (OESTE)
		2:  # TOP_TO_BOTTOM (South→North)
			rotationY = PI  # 180° para apontar para -Z (NORTE)
		3:  # BOTTOM_TO_TOP (North→South) - caso exista
			rotationY = 0  # 0° para apontar para +Z (SUL)
	
	car.global_position = spawn_point.position
	car.rotation.y = rotationY
	
	# Debug apenas para marcos de spawn com informação sobre frequência
	if total_cars_spawned % 10 == 0:
		var direction_names = ["West→East", "East→West", "South→North"]
		var dir_name = direction_names[spawn_point.direction] if spawn_point.direction < 3 else "Unknown"
		print("Car spawned #%d | %s Lane: %d | Active: %d" % [total_cars_spawned, dir_name, spawn_point.lane, cars.size()])
	
	# Registrar no traffic manager
	if traffic_manager:
		traffic_manager.register_car(car)
	
	# Debug ocasional
	if total_cars_spawned % 20 == 0:
		print("Spawned %d cars | Active: %d | Rush: %.1fx" % [total_cars_spawned, cars.size(), rush_hour_multiplier])

func cleanup_invalid_cars():
	# LIMPEZA OTIMIZADA - remover referências de carros que foram destruídos
	for i in range(cars.size() - 1, -1, -1):
		if not is_instance_valid(cars[i]):
			cars.remove_at(i)

func get_spawn_statistics() -> Dictionary:
	# ESTATÍSTICAS para debug/analytics
	var stats = {
		"total_spawned": total_cars_spawned,
		"active_cars": cars.size(),
		"rush_hour_multiplier": rush_hour_multiplier,
		"simulation_time": simulation_time,
		"spawn_points": spawn_points.size()
	}
	
	# Estatísticas por direção
	var cars_by_direction = {}
	for car in cars:
		if not is_instance_valid(car):
			continue
		var direction_names = ["LEFT_TO_RIGHT", "RIGHT_TO_LEFT", "TOP_TO_BOTTOM", "BOTTOM_TO_TOP"]
		var dir_name = direction_names[car.direction]
		if not cars_by_direction.has(dir_name):
			cars_by_direction[dir_name] = 0
		cars_by_direction[dir_name] += 1
	
	stats["cars_by_direction"] = cars_by_direction
	return stats

func adjust_spawn_rate(multiplier: float):
	# Permitir ajuste manual da taxa de spawn
	rush_hour_multiplier = clamp(multiplier, 0.1, 5.0)
	print("Spawn rate adjusted to %.1fx" % rush_hour_multiplier)

func pause_spawning():
	set_process(false)

func resume_spawning():
	set_process(true)

# FUNÇÃO DE DEBUG
func debug_spawn_system():
	print("=== SPAWN SYSTEM DEBUG ===")
	var stats = get_spawn_statistics()
	print("Total spawned: %d" % stats.total_spawned)
	print("Active cars: %d" % stats.active_cars) 
	print("Rush hour: %.1fx" % stats.rush_hour_multiplier)
	print("Cars by direction: %s" % stats.cars_by_direction)
	
	# Verificar spawn points
	for i in range(spawn_points.size()):
		var sp = spawn_points[i]
		var can_spawn = can_spawn_safely(sp)
		var has_queue_space = has_space_for_queueing(sp)
		print("Spawn %s: Safe=%s, Queue=%s" % [sp.name, can_spawn, has_queue_space])
