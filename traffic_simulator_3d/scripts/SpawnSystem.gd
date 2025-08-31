extends Node3D
class_name SpawnSystem

var traffic_manager: Node
var car_scene = preload("res://scenes/Car.tscn")

# CONFIGURAÇÃO EXATA DO HTML
const SPAWN_CONFIG = {
	"base_spawn_rate": 0.025,  # Probabilidade base de spawn por frame
	"min_spawn_distance": 4.0,  # Distância mínima entre carros
	"randomness_factor": 0.5,   # Fator de aleatoriedade
	"max_queue_length": 15      # Tamanho máximo da fila
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
	set_process(true)
	print("SpawnSystem initialized with HTML/2D logic")

func _process(delta):
	simulation_time += delta
	update_rush_hour_effect()
	spawn_cars()
	cleanup_invalid_cars()

func setup_spawn_points():
	# SPAWN POINTS EXATOS - baseados na conversão 2D→3D
	spawn_points = [
		{
			"direction": 0,  # LEFT_TO_RIGHT - West → East
			"lane": 0,
			"position": Vector3(-50, 0.5, -3),
			"name": "West_Lane0"
		},
		{
			"direction": 0,  # LEFT_TO_RIGHT - West → East
			"lane": 1, 
			"position": Vector3(-50, 0.5, 0),
			"name": "West_Lane1"
		},
		{
			"direction": 1,  # RIGHT_TO_LEFT - East → West
			"lane": 0,
			"position": Vector3(50, 0.5, 3),
			"name": "East_Lane0"
		},
		{
			"direction": 1,  # RIGHT_TO_LEFT - East → West
			"lane": 1,
			"position": Vector3(50, 0.5, 0), 
			"name": "East_Lane1"
		},
		{
			"direction": 2,  # TOP_TO_BOTTOM - North → South
			"lane": 0,
			"position": Vector3(-1.5, 0.5, -50),
			"name": "North_Lane0"
		},
		{
			"direction": 2,  # TOP_TO_BOTTOM - North → South  
			"lane": 1,
			"position": Vector3(1.5, 0.5, -50),
			"name": "North_Lane1"
		},
		{
			"direction": 3,  # BOTTOM_TO_TOP - South → North
			"lane": 0, 
			"position": Vector3(1.5, 0.5, 50),
			"name": "South_Lane0"
		},
		{
			"direction": 3,  # BOTTOM_TO_TOP - South → North
			"lane": 1,
			"position": Vector3(-1.5, 0.5, 50), 
			"name": "South_Lane1"
		}
	]

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
		rush_hour_multiplier = 0.3
	else:
		rush_hour_multiplier = 1.0

func spawn_cars():
	# LÓGICA EXATA DO HTML - spawn por spawn point
	for spawn_point in spawn_points:
		if should_spawn_car(spawn_point):
			create_car(spawn_point)

func should_spawn_car(spawn_point: Dictionary) -> bool:
	# ALGORITMO EXATO DO HTML
	
	# 1. Verificar probabilidade base
	var spawn_probability = SPAWN_CONFIG.base_spawn_rate * rush_hour_multiplier
	if randf() > spawn_probability:
		return false
	
	# 2. Verificar se pode spawnar com segurança (FUNÇÃO CRÍTICA)
	if not can_spawn_safely(spawn_point):
		return false
	
	# 3. Verificar se há espaço para formação de fila
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
		if distance >= 0 and distance < SPAWN_CONFIG.min_spawn_distance:
			return false
	
	return true

func has_space_for_queueing(spawn_point: Dictionary) -> bool:
	# FUNÇÃO CRÍTICA DO HTML - permite spawn mesmo no vermelho se há espaço para fila
	var direction = spawn_point.direction
	var lane = spawn_point.lane
	var cars_in_lane = get_cars_in_same_lane(direction, lane)
	
	# Se há menos carros que o máximo da fila, pode spawnar
	if cars_in_lane.size() < SPAWN_CONFIG.max_queue_length:
		return true
	
	return false

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
		2:  # TOP_TO_BOTTOM - North → South
			return spawn_pos.z - car_pos.z  # Positivo = carro antes do spawn
		3:  # BOTTOM_TO_TOP - South → North
			return car_pos.z - spawn_pos.z  # Positivo = carro antes do spawn
	
	return 0.0

func create_car(spawn_point: Dictionary):
	# CRIAR CARRO - lógica do HTML
	var car = car_scene.instantiate()
	car.direction = spawn_point.direction
	car.lane = spawn_point.lane
	car.car_id = total_cars_spawned
	
	# Adicionar ao mundo
	get_parent().add_child(car)
	cars.append(car)
	total_cars_spawned += 1
	
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