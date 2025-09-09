extends RefCounted
class_name DiscreteCar

# CARRO DISCRETO - LÓGICA 100% EVENTOS, VISUALIZAÇÃO CONTÍNUA

# Estados discretos do carro
enum State {
	MOVING,           # Se movendo
	WAITING_TRAFFIC,  # Parado no semáforo
	WAITING_CAR,      # Parado atrás de outro carro
	CROSSING,         # Atravessando interseção
	EXITED            # Saiu do sistema
}

enum Direction {
	WEST_TO_EAST,     # West → East (rua principal)
	EAST_TO_WEST,     # East → West (rua principal)
	SOUTH_TO_NORTH    # South → North (rua transversal)
}

# Posições discretas pré-definidas na rua (CORRIGIDO baseado no simulator_3d)
var DISCRETE_POSITIONS = {
	Direction.WEST_TO_EAST: [  # LEFT_TO_RIGHT - FAIXA SUL
		Vector3(-35, 0.5, -1.25),  # Spawn OESTE
		Vector3(-20, 0.5, -1.25),  # Meio da rua
		Vector3(-8, 0.5, -1.25),   # Antes do semáforo
		Vector3(0, 0.5, -1.25),    # Interseção
		Vector3(8, 0.5, -1.25),    # Depois da interseção
		Vector3(20, 0.5, -1.25),   # Meio da rua
		Vector3(35, 0.5, -1.25)    # Saída LESTE
	],
	Direction.EAST_TO_WEST: [  # RIGHT_TO_LEFT - FAIXA NORTE  
		Vector3(35, 0.5, 1.25),    # Spawn LESTE
		Vector3(20, 0.5, 1.25),    # Meio da rua
		Vector3(8, 0.5, 1.25),     # Antes do semáforo
		Vector3(0, 0.5, 1.25),     # Interseção
		Vector3(-8, 0.5, 1.25),    # Depois da interseção
		Vector3(-20, 0.5, 1.25),   # Meio da rua
		Vector3(-35, 0.5, 1.25)    # Saída OESTE
	],
	Direction.SOUTH_TO_NORTH: [  # BOTTOM_TO_TOP - ÚNICA FAIXA
		Vector3(0.0, 0.5, 35),     # Spawn SUL
		Vector3(0.0, 0.5, 20),     # Meio da rua
		Vector3(0.0, 0.5, 8),      # Antes do semáforo
		Vector3(0.0, 0.5, 0),      # Interseção
		Vector3(0.0, 0.5, -8),     # Depois da interseção
		Vector3(0.0, 0.5, -20),    # Meio da rua
		Vector3(0.0, 0.5, -35)     # Saída NORTE
	]
}

# Propriedades do carro
var id: String
var direction: Direction
var current_position_index: int = 0
var state: State = State.MOVING
var visual_node: Node3D = null

# Timing para eventos
var speed_factor: float  # Tempo entre posições (personalidade)
var spawn_time: float

func _init(car_id: String, car_direction: Direction, spawn_t: float):
	id = car_id
	direction = car_direction
	spawn_time = spawn_t
	
	# Personalidade: tempo entre movimentos (1.5s a 3.0s) - mais lento para visualizar
	speed_factor = randf_range(1.5, 3.0)
	
	print("🚗 DiscreteCar criado: %s (%s) - speed: %.1fs" % [id, get_direction_name(), speed_factor])

func get_direction_name() -> String:
	match direction:
		Direction.WEST_TO_EAST:
			return "WEST→EAST"
		Direction.EAST_TO_WEST:
			return "EAST→WEST"
		Direction.SOUTH_TO_NORTH:
			return "SOUTH→NORTH"
	return "UNKNOWN"

func get_current_position() -> Vector3:
	var positions = DISCRETE_POSITIONS[direction]
	if current_position_index < positions.size():
		return positions[current_position_index]
	return positions[-1]  # Última posição (saída)

func get_next_position() -> Vector3:
	var positions = DISCRETE_POSITIONS[direction]
	var next_index = current_position_index + 1
	if next_index < positions.size():
		return positions[next_index]
	return positions[-1]  # Última posição (saída)

func can_move_to_next_position() -> bool:
	var positions = DISCRETE_POSITIONS[direction]
	return current_position_index < positions.size() - 1

func is_at_traffic_light_position() -> bool:
	# Posição 2 é sempre "antes do semáforo"
	return current_position_index == 2

func is_at_intersection() -> bool:
	# Posição 3 é sempre "interseção"
	return current_position_index == 3

func is_at_exit() -> bool:
	# Última posição é sempre saída
	var positions = DISCRETE_POSITIONS[direction]
	return current_position_index >= positions.size() - 1

func advance_position():
	if can_move_to_next_position():
		current_position_index += 1
		print("🚗 %s avança para posição %d" % [id, current_position_index])

func get_traffic_light_direction() -> String:
	# Mapear direção para semáforo correspondente
	match direction:
		Direction.WEST_TO_EAST:
			return "main_road"  # S1 + S2
		Direction.EAST_TO_WEST:
			return "main_road"  # S1 + S2
		Direction.SOUTH_TO_NORTH:
			return "cross_road" # S3
	return "main_road"

func should_stop_at_traffic_light(light_state: String) -> bool:
	# Decisão simples: vermelho = para, verde = passa
	if light_state == "red":
		return true
	elif light_state == "yellow":
		# Personalidade: 50% chance de parar no amarelo
		return randf() > 0.5
	return false

func get_move_time() -> float:
	# Tempo para se mover para próxima posição
	return speed_factor

func set_visual_node(node: Node3D):
	visual_node = node
	if visual_node:
		visual_node.position = get_current_position()
		# Rotacionar baseado na direção (CORRIGIDO do simulator_3d)
		match direction:
			Direction.WEST_TO_EAST:   # LEFT_TO_RIGHT
				visual_node.rotation_degrees.y = 90   # Apontando +X (East)
			Direction.EAST_TO_WEST:   # RIGHT_TO_LEFT  
				visual_node.rotation_degrees.y = -90  # Apontando -X (West)
			Direction.SOUTH_TO_NORTH: # BOTTOM_TO_TOP
				visual_node.rotation_degrees.y = 180  # Apontando -Z (North)

func update_visual_position_instant():
	# Atualizar posição visual instantaneamente (para correções)
	if visual_node:
		visual_node.position = get_current_position()
