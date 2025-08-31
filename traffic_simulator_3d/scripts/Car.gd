extends CharacterBody3D
class_name Car

# ENUMS EXATOS DO HTML
enum Direction { LEFT_TO_RIGHT, RIGHT_TO_LEFT, TOP_TO_BOTTOM, BOTTOM_TO_TOP }
enum DriverPersonality { AGGRESSIVE, CONSERVATIVE, NORMAL, ELDERLY }

# PERSONALIDADES EXATAS DO HTML
const PERSONALITIES = {
	DriverPersonality.AGGRESSIVE: {
		"base_speed": 14.0,  # ~50 km/h
		"reaction_time": [0.5, 0.8],
		"following_distance_factor": 0.8,
		"yellow_light_probability": 0.8,
		"acceleration": 8.0,
		"deceleration": 10.0
	},
	DriverPersonality.CONSERVATIVE: {
		"base_speed": 9.0,   # ~32 km/h
		"reaction_time": [1.2, 1.5],
		"following_distance_factor": 1.3,
		"yellow_light_probability": 0.2,
		"acceleration": 4.0,
		"deceleration": 6.0
	},
	DriverPersonality.ELDERLY: {
		"base_speed": 7.0,   # ~25 km/h
		"reaction_time": [1.5, 2.0],
		"following_distance_factor": 1.5,
		"yellow_light_probability": 0.1,
		"acceleration": 3.0,
		"deceleration": 5.0
	},
	DriverPersonality.NORMAL: {
		"base_speed": 11.0,  # ~40 km/h
		"reaction_time": [0.8, 1.2],
		"following_distance_factor": 1.0,
		"yellow_light_probability": 0.5,
		"acceleration": 6.0,
		"deceleration": 8.0
	}
}

# Propriedades do carro
var direction: Direction
var lane: int = 0
var personality: DriverPersonality
var car_id: int

# Estados do movimento - CONVERSÃO 2D→3D CORRETA
var current_speed: float = 0.0
var target_speed: float = 0.0
var max_speed: float = 11.0
var position_in_direction: float = 0.0

# IA e comportamento
var should_stop: bool = false
var car_ahead = null
var distance_to_car_ahead: float = 999.0
var has_passed_intersection: bool = false
var reaction_time: float = 1.0
var following_distance: float = 4.0

# Referencias ao sistema
var traffic_manager: Node
var spawn_system: Node

# Timing para otimização
var update_interval: float = 0.016  # 60 FPS
var last_update: float = 0.0

# Analytics
var spawn_time: float = 0.0
var total_wait_time: float = 0.0
var is_waiting: bool = false

func _ready():
	traffic_manager = get_tree().get_first_node_in_group("traffic_manager")
	spawn_system = get_node("../SpawnSystem")
	
	setup_personality()
	setup_physics()
	create_car_geometry()
	set_spawn_position()
	
	spawn_time = Time.get_time_dict_from_system()["second"]
	add_to_group("cars")
	
	if traffic_manager:
		traffic_manager.register_car(self)

func setup_personality():
	# COPIAR EXATAMENTE do HTML
	personality = DriverPersonality.values()[randi() % DriverPersonality.size()]
	var p = PERSONALITIES[personality]
	
	max_speed = p.base_speed * randf_range(0.85, 1.15)  # ±15% variação
	reaction_time = randf_range(p.reaction_time[0], p.reaction_time[1])
	following_distance = 4.0 * p.following_distance_factor

func setup_physics():
	# Configuração leve para 100+ carros - CharacterBody3D é otimizado
	collision_layer = 1
	collision_mask = 1

func create_car_geometry():
	# Carro simples 3D
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(1.8, 0.8, 4.0)  # Proporções realísticas
	mesh_instance.mesh = box_mesh
	
	# Material com cor aleatória
	var material = StandardMaterial3D.new()
	var colors = [Color.WHITE, Color.BLACK, Color.RED, Color.BLUE, Color.SILVER, Color.GRAY]
	material.albedo_color = colors[randi() % colors.size()]
	mesh_instance.material_override = material
	
	add_child(mesh_instance)
	
	# Collision shape
	var collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = box_mesh.size
	collision.shape = box_shape
	add_child(collision)

func set_spawn_position():
	# CONVERSÃO 2D→3D CORRETA - Y do HTML vira Z no Godot
	match direction:
		Direction.LEFT_TO_RIGHT:
			global_position = Vector3(-50, 0.5, -3 + lane * 3)  # Oeste para Leste
			rotation.y = 0
			
		Direction.RIGHT_TO_LEFT:
			global_position = Vector3(50, 0.5, 3 - lane * 3)   # Leste para Oeste
			rotation.y = PI
			
		Direction.TOP_TO_BOTTOM:
			global_position = Vector3(-1.5 + lane * 3, 0.5, -50)  # Norte para Sul
			rotation.y = PI/2
			
		Direction.BOTTOM_TO_TOP:
			global_position = Vector3(1.5 - lane * 3, 0.5, 50)   # Sul para Norte  
			rotation.y = -PI/2

func _physics_process(delta):
	# Otimização - nem todo carro precisa atualizar todo frame
	last_update += delta
	if last_update < update_interval:
		return
	last_update = 0.0
	
	check_obstacles()
	update_movement(delta)
	move_car()
	check_cleanup()

func check_obstacles():
	# PRIORIDADE 1: Carros à frente (ANTI-ENGAVETAMENTO DO HTML)
	should_stop = false
	car_ahead = get_car_ahead()
	
	if car_ahead:
		distance_to_car_ahead = global_position.distance_to(car_ahead.global_position)
		
		# LÓGICA EXATA DO HTML - seguir o carro da frente
		if distance_to_car_ahead < following_distance * 1.5:
			should_stop = true
			target_speed = min(max_speed, car_ahead.current_speed * 0.9)
		else:
			target_speed = max_speed
		return
	
	# PRIORIDADE 2: Semáforos (se não passou da intersecção)
	if not has_passed_intersection:
		check_traffic_lights()
	else:
		target_speed = max_speed

func get_car_ahead():
	# DETECÇÃO OTIMIZADA - buscar apenas carros próximos na mesma direção
	var cars = get_tree().get_nodes_in_group("cars")
	var closest_car = null
	var closest_distance = 999.0
	
	for car in cars:
		if car == self or not is_instance_valid(car):
			continue
			
		var other_car = car
		if other_car.direction != direction or other_car.lane != lane:
			continue
		
		# Verificar se está à frente baseado na direção
		var is_ahead = false
		var distance = global_position.distance_to(other_car.global_position)
		
		match direction:
			Direction.LEFT_TO_RIGHT:
				is_ahead = other_car.global_position.x > global_position.x
			Direction.RIGHT_TO_LEFT:
				is_ahead = other_car.global_position.x < global_position.x
			Direction.TOP_TO_BOTTOM:
				is_ahead = other_car.global_position.z > global_position.z
			Direction.BOTTOM_TO_TOP:
				is_ahead = other_car.global_position.z < global_position.z
		
		if is_ahead and distance < closest_distance:
			closest_distance = distance
			closest_car = other_car
	
	return closest_car

func check_traffic_lights():
	# LÓGICA DOS SEMÁFOROS - baseada no HTML
	if not traffic_manager:
		return
		
	var distance_to_intersection = get_distance_to_intersection()
	if distance_to_intersection > 15.0:  # Muito longe, ignorar
		target_speed = max_speed
		return
	
	var my_direction_name = get_direction_name()
	var light_state = traffic_manager.get_light_state_for_direction(my_direction_name)
	
	match light_state:
		"green":
			target_speed = max_speed
			should_stop = false
			
		"red":
			if distance_to_intersection < 8.0:  # Próximo da intersecção
				should_stop = true
				target_speed = 0.0
			else:
				target_speed = max_speed * 0.5  # Diminuir velocidade
				
		"yellow":
			# LÓGICA DO AMARELO - EXATA DO HTML
			var can_proceed = traffic_manager.can_proceed_on_yellow(my_direction_name, distance_to_intersection, current_speed)
			var personality_factor = PERSONALITIES[personality].yellow_light_probability
			
			if can_proceed and randf() < personality_factor:
				target_speed = max_speed  # Acelerar para passar
			else:
				should_stop = true
				target_speed = 0.0

func get_distance_to_intersection() -> float:
	# CONVERSÃO 2D→3D - calcular distância até intersecção
	match direction:
		Direction.LEFT_TO_RIGHT:
			return max(0.0, -global_position.x)
		Direction.RIGHT_TO_LEFT:
			return max(0.0, global_position.x)
		Direction.TOP_TO_BOTTOM:
			return max(0.0, -global_position.z)
		Direction.BOTTOM_TO_TOP:
			return max(0.0, global_position.z)
	return 0.0

func get_direction_name() -> String:
	# Mapear direção para nome do semáforo
	match direction:
		Direction.LEFT_TO_RIGHT:
			return "West"
		Direction.RIGHT_TO_LEFT:
			return "East"
		Direction.TOP_TO_BOTTOM:
			return "North"
		Direction.BOTTOM_TO_TOP:
			return "South"
	return "North"

func update_movement(delta):
	# FÍSICA SIMPLES E OTIMIZADA para 100+ carros
	var speed_diff = target_speed - current_speed
	var accel = PERSONALITIES[personality].acceleration if speed_diff > 0 else PERSONALITIES[personality].deceleration
	
	current_speed = move_toward(current_speed, target_speed, accel * delta)
	current_speed = max(0.0, current_speed)  # Não ir para trás
	
	# Analytics - detectar se está esperando
	if current_speed < 0.5 and target_speed > 0.5:
		if not is_waiting:
			is_waiting = true
	else:
		is_waiting = false

func move_car():
	# MOVIMENTO 3D - CONVERSÃO 2D→3D CORRETA
	if current_speed <= 0.01:
		return
		
	var movement = Vector3.ZERO
	
	match direction:
		Direction.LEFT_TO_RIGHT:
			movement.x = current_speed * get_physics_process_delta_time()
		Direction.RIGHT_TO_LEFT:
			movement.x = -current_speed * get_physics_process_delta_time()
		Direction.TOP_TO_BOTTOM:
			movement.z = current_speed * get_physics_process_delta_time()
		Direction.BOTTOM_TO_TOP:
			movement.z = -current_speed * get_physics_process_delta_time()
	
	# Usar move_and_slide do CharacterBody3D
	velocity = movement / get_physics_process_delta_time()
	move_and_slide()
	
	# Marcar se passou da intersecção
	if not has_passed_intersection:
		check_intersection_passage()

func check_intersection_passage():
	# Verificar se passou completamente pela intersecção
	var passed = false
	
	match direction:
		Direction.LEFT_TO_RIGHT:
			passed = global_position.x > 8.0
		Direction.RIGHT_TO_LEFT:
			passed = global_position.x < -8.0
		Direction.TOP_TO_BOTTOM:
			passed = global_position.z > 8.0
		Direction.BOTTOM_TO_TOP:
			passed = global_position.z < -8.0
	
	if passed and not has_passed_intersection:
		has_passed_intersection = true

func check_cleanup():
	# Remover carro se saiu da área de simulação
	var should_cleanup = false
	
	match direction:
		Direction.LEFT_TO_RIGHT:
			should_cleanup = global_position.x > 60.0
		Direction.RIGHT_TO_LEFT:
			should_cleanup = global_position.x < -60.0
		Direction.TOP_TO_BOTTOM:
			should_cleanup = global_position.z > 60.0
		Direction.BOTTOM_TO_TOP:
			should_cleanup = global_position.z < -60.0
	
	if should_cleanup:
		destroy()

func get_current_speed() -> float:
	return current_speed

func get_personality_string() -> String:
	match personality:
		DriverPersonality.AGGRESSIVE:
			return "Aggressive"
		DriverPersonality.CONSERVATIVE:
			return "Conservative"
		DriverPersonality.ELDERLY:
			return "Elderly"
		DriverPersonality.NORMAL:
			return "Normal"
	return "Unknown"

func destroy():
	if traffic_manager:
		traffic_manager.unregister_car(self)
	queue_free()