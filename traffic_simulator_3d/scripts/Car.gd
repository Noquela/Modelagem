extends CharacterBody3D
class_name Car

# DIRECTIONS FOR ALL LANES
enum Direction { LEFT_TO_RIGHT, RIGHT_TO_LEFT, TOP_TO_BOTTOM, BOTTOM_TO_TOP }
enum DriverPersonality { AGGRESSIVE, CONSERVATIVE, NORMAL, ELDERLY }

# PERSONALIDADES EXATAS DO HTML
const PERSONALITIES = {
	DriverPersonality.AGGRESSIVE: {
		"base_speed": 6.0,   # ~30 km/h - velocidade urbana realística
		"reaction_time": [0.5, 0.8],
		"following_distance_factor": 0.8,
		"yellow_light_probability": 0.8,
		"acceleration": 4.0,  # aceleração mais suave
		"deceleration": 6.0
	},
	DriverPersonality.CONSERVATIVE: {
		"base_speed": 4.5,   # ~25 km/h - cauteloso
		"reaction_time": [1.2, 1.5],
		"following_distance_factor": 1.3,
		"yellow_light_probability": 0.2,
		"acceleration": 2.5,
		"deceleration": 4.0
	},
	DriverPersonality.ELDERLY: {
		"base_speed": 3.5,   # ~20 km/h - bem devagar
		"reaction_time": [1.5, 2.0],
		"following_distance_factor": 1.5,
		"yellow_light_probability": 0.1,
		"acceleration": 2.0,
		"deceleration": 3.0
	},
	DriverPersonality.NORMAL: {
		"base_speed": 5.0,   # ~25-30 km/h - velocidade urbana normal
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
# PERFORMANCE: Cache car detection results
var car_detection_cache_timer: float = 0.0
var car_detection_cache_interval: float = 0.2  # Update every 0.2s instead of every frame
var has_passed_intersection: bool = false
var reaction_time: float = 1.0
var following_distance: float = 4.0
var following_distance_factor: float = 1.0

# INTERSECTION STATE MACHINE (Traffic Engineering Pattern)
enum IntersectionState { APPROACHING, WAITING, PROCEEDING, CROSSING, CLEARING }
var intersection_state: IntersectionState = IntersectionState.APPROACHING

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

# DEBUG: Performance monitoring
var debug_last_behavior_update: float = 0.0
var debug_behavior_update_count: int = 0

func _ready():
	traffic_manager = get_tree().get_first_node_in_group("traffic_manager")
	spawn_system = get_node("../SpawnSystem")
	
	setup_personality()
	setup_physics()
	create_car_geometry()
	# REMOVIDO: set_spawn_position() - agora usa posição do SpawnSystem
	
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
	following_distance_factor = p.following_distance_factor
	following_distance = 4.0 * following_distance_factor

func setup_physics():
	# Configuração ANTI-TELEPORT para 100+ carros
	collision_layer = 1
	collision_mask = 0  # NÃO colidir com outros carros - evita teleportes
	
	# Configurar propriedades do CharacterBody3D
	floor_stop_on_slope = false
	floor_constant_speed = true
	floor_block_on_wall = false

func create_car_geometry():
	# Use 3D car models for realistic appearance
	create_3d_car_model()
	
	# Collision shape (simplified) - MENOR para evitar colisões
	var collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(0.8, 0.4, 1.5)  # REDUZIDO: evitar sobreposições
	collision.shape = box_shape
	add_child(collision)

func create_fallback_car_mesh():
	# Simple fallback car using box mesh - MENOR para evitar colisões
	var car_body = MeshInstance3D.new()
	var body_mesh = BoxMesh.new()
	body_mesh.size = Vector3(0.8, 0.4, 1.5)  # REDUZIDO: evitar sobreposições visuais
	car_body.mesh = body_mesh
	
	var body_material = StandardMaterial3D.new()
	var car_colors = [
		Color.WHITE, Color.BLACK, Color.RED, Color.BLUE, 
		Color.SILVER, Color.GRAY
	]
	body_material.albedo_color = car_colors[randi() % car_colors.size()]
	body_material.metallic = 0.3
	body_material.roughness = 0.7
	car_body.material_override = body_material
	add_child(car_body)
	
	# Add a front indicator (small red box at the front)
	var front_indicator = MeshInstance3D.new()
	var indicator_mesh = BoxMesh.new()
	indicator_mesh.size = Vector3(0.8, 0.3, 0.2)
	front_indicator.mesh = indicator_mesh
	front_indicator.position = Vector3(0, 0.2, -0.9)  # Position at front (-Z)
	
	var indicator_material = StandardMaterial3D.new()
	indicator_material.albedo_color = Color.RED
	indicator_material.emission = Color.RED * 0.3
	front_indicator.material_override = indicator_material
	car_body.add_child(front_indicator)

func apply_random_color_to_car(car_node: Node3D):
	# CORES MAIS VARIADAS - menos branco
	var colors = [
		Color(0.8, 0.8, 0.8),          # Cinza claro (no lugar de branco puro)
		Color.BLACK,                    # Preto
		Color(0.2, 0.2, 0.2),          # Cinza escuro
		Color(0.7, 0.7, 0.7),          # Prata
		Color(0.9, 0.1, 0.1),          # Vermelho
		Color(0.1, 0.2, 0.8),          # Azul
		Color(0.8, 0.0, 0.0),          # Vermelho escuro
		Color(0.0, 0.4, 0.2),          # Verde escuro
		Color(0.6, 0.3, 0.1),          # Marrom
		Color(0.1, 0.4, 0.6),          # Azul petróleo
		Color(0.7, 0.6, 0.1),          # Amarelo dourado
		Color(0.5, 0.1, 0.5),          # Roxo
		Color(0.8, 0.4, 0.0),          # Laranja
		Color(0.4, 0.4, 0.4),          # Cinza médio
		Color(0.0, 0.6, 0.8),          # Azul céu
		Color(0.6, 0.0, 0.3),          # Vinho
		Color(0.3, 0.6, 0.0),          # Verde limão
		Color(0.5, 0.5, 0.0)           # Amarelo mostarda
	]
	var chosen_color = colors[randi() % colors.size()]
	
	# Debug print melhorado
	if car_id % 5 == 0:  # Debug mais frequente
		pass  # Debug print removed for performance
	
	# Verificar se o node é válido
	if not is_instance_valid(car_node):
		pass  # Debug print removed for performance
		return
	
	# Recursively find and update materials
	update_car_materials(car_node, chosen_color)

func update_car_materials(node: Node3D, color: Color):
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		
		# Create new material for car body (ignore wheels and small parts)
		var node_name = node.name.to_lower()
		var is_car_body = not ("wheel" in node_name or "tire" in node_name or 
							  "light" in node_name or "glass" in node_name or
							  "window" in node_name or "debris" in node_name or
							  "trim" in node_name or "chrome" in node_name)
		
		if mesh_instance.mesh:
			var material = StandardMaterial3D.new()
			
			# Apply different materials based on part type
			if is_car_body:
				# Car body - use chosen color
				material.albedo_color = color
				material.metallic = 0.4
				material.roughness = 0.2
			else:
				# Wheels/accessories - use dark colors
				material.albedo_color = Color(0.1, 0.1, 0.1)  # Dark gray/black
				material.metallic = 0.1
				material.roughness = 0.8
			
			material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			material.cull_mode = BaseMaterial3D.CULL_BACK
			
			# Debug print for car body only
			if is_car_body and car_id % 10 == 0:
				pass  # Debug print removed for performance
			
			# FORCE material application - multiple methods for compatibility
			mesh_instance.material_override = material
			
			# Apply to all surfaces individually
			for surface_idx in range(mesh_instance.mesh.get_surface_count()):
				mesh_instance.set_surface_override_material(surface_idx, material)
			
			# Force refresh
			if mesh_instance.get_surface_override_material_count() == 0:
				# If surface materials didn't work, force via material_override
				mesh_instance.material_override = material
	
	# Recursively process children
	for child in node.get_children():
		if child is Node3D:
			update_car_materials(child, color)

func create_3d_car_model() -> void:
	# Load 3D car models randomly from Kenney Car Kit
	var car_models = [
		"res://assets/vehicles/sedan.glb",
		"res://assets/vehicles/hatchback-sports.glb", 
		"res://assets/vehicles/suv.glb",
		"res://assets/vehicles/Models/GLB format/sedan.glb",
		"res://assets/vehicles/Models/GLB format/hatchback-sports.glb",
		"res://assets/vehicles/Models/GLB format/suv.glb",
		"res://assets/vehicles/Models/GLB format/sedan-sports.glb",
		"res://assets/vehicles/Models/GLB format/suv-luxury.glb",
		"res://assets/vehicles/Models/GLB format/police.glb",
		"res://assets/vehicles/Models/GLB format/taxi.glb",
		"res://assets/vehicles/Models/GLB format/van.glb"
	]
	
	# Choose random model
	var model_path = car_models[randi() % car_models.size()]
	var car_scene = load(model_path)
	
	if car_scene and car_scene.can_instantiate():
		var car_model = car_scene.instantiate()
		car_model.name = "CarModel"
		# Scale MENOR para evitar sobreposições visuais
		car_model.scale = Vector3(0.6, 0.6, 0.6)  # REDUZIDO de 0.8 para 0.6
		car_model.position = Vector3(0, -0.3, 0)
		
		# NOTE: Model orientation will be handled by the main car rotation
		# Models should face forward along -Z by default, car rotation handles final direction
		
		add_child(car_model)
		
		# Debug info
		if car_id % 10 == 0:
			pass  # Debug print removed for performance
		
		# Apply color after model is added to scene tree - with retry
		call_deferred("apply_random_color_to_car", car_model)
		# Double safety - apply again after a short delay
		get_tree().create_timer(0.1).timeout.connect(func(): apply_random_color_to_car(car_model))
	else:
		# Fallback to simple box mesh if models don't load
		if car_id % 5 == 0:  # Log fallback more frequently to debug
			pass  # Debug print removed for performance
		create_fallback_car_mesh()

func set_spawn_position():
	# SPAWN POSITIONS CORRETOS - MATCHING SpawnSystem.gd
	var startX: float
	var startZ: float  
	var rotationY: float
	
	match direction:
		Direction.LEFT_TO_RIGHT:
			# Spawn do OESTE - antes do início da rua
			startX = -35.0  # SPAWN OESTE
			startZ = -1.5 + (lane * -2.0)  # Lane 0: Z=-1.5, Lane 1: Z=-3.5 (dentro dos limites)
			rotationY = PI/2  # INVERTIDO: rotacionar +90° para apontar para +X (LESTE)
			
		Direction.RIGHT_TO_LEFT:
			# Spawn do LESTE - antes do início da rua
			startX = 35.0  # SPAWN LESTE
			startZ = 1.5 + (lane * 2.0)    # Lane 0: Z=1.5, Lane 1: Z=3.5 (dentro dos limites)
			rotationY = -PI/2  # INVERTIDO: rotacionar -90° para apontar para -X (OESTE)
			
		Direction.TOP_TO_BOTTOM:
			# Spawn do SUL - antes do início da rua
			startX = 0.0    # CENTRALIZADO na rua (meio da pista)
			startZ = 35.0   # SPAWN SUL
			rotationY = PI  # INVERTIDO: rotacionar 180° para apontar para -Z (NORTE)
			
		Direction.BOTTOM_TO_TOP:
			# Spawn do NORTE - antes do início da rua
			startX = 1.5    # Faixa esquerda (lado leste da rua)
			startZ = -35.0  # SPAWN NORTE
			rotationY = 0   # INVERTIDO: não rotacionar para apontar para +Z (SUL)
	
	global_position = Vector3(startX, 0.5, startZ)
	rotation.y = rotationY

func _physics_process(delta):
	# PERFORMANCE: Staggered updates - only 25% of cars update per frame
	var frame_offset = Engine.get_process_frames() % 4  # 4-frame cycle
	var car_frame_group = car_id % 4
	
	if frame_offset != car_frame_group:
		# Only essential movement on off-frames (lightweight)
		move_car()
		return
	
	# Full update every 4th frame for this car (maintains same logic frequency)
	check_obstacles()
	update_movement(delta * 4)  # Compensate delta for 4-frame cycle
	move_car()
	check_cleanup()

# CRAIG REYNOLDS STEERING BEHAVIORS - HIERARCHICAL APPROACH
func check_obstacles():
	# RESET STATE
	should_stop = false
	distance_to_car_ahead = INF
	
	# PERFORMANCE: Update car detection cache only periodically
	car_detection_cache_timer += get_physics_process_delta_time()
	if car_detection_cache_timer >= car_detection_cache_interval:
		car_ahead = get_car_ahead()  # Expensive operation - cache it
		car_detection_cache_timer = 0.0
	
	# STEERING BEHAVIORS HIERARCHY (Reynolds Pattern) - use cached car_ahead
	var steering_forces = apply_steering_behaviors()
	
	# DETERMINE FINAL ACTION
	should_stop = steering_forces.should_stop
	distance_to_car_ahead = steering_forces.following_distance
	
	# Update intersection status
	if hasPassedIntersection() and not has_passed_intersection:
		has_passed_intersection = true

# STEERING BEHAVIORS SYSTEM (Based on Academic Research)
func apply_steering_behaviors() -> Dictionary:
	var result = {"should_stop": false, "following_distance": INF, "steering_force": Vector3.ZERO}
	
	# PRIORITY 1: COLLISION AVOIDANCE (Highest Priority)
	var collision_behavior = collision_avoidance_behavior()
	if collision_behavior.should_stop:
		result.should_stop = true
		result.following_distance = collision_behavior.distance
		return result
	
	# PRIORITY 2: TRAFFIC LIGHT COMPLIANCE
	if not has_passed_intersection:
		var traffic_behavior = traffic_light_behavior()
		if traffic_behavior.should_stop:
			result.should_stop = true
			return result
	
	# PRIORITY 3: PATH FOLLOWING (Lowest Priority)
	var path_behavior = path_following_behavior()
	result.steering_force += path_behavior.force
	
	return result

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
				# CORREÇÃO: South→North, carro à frente tem Z MENOR (mais próximo da interseção)
				is_ahead = other_car.global_position.z < global_position.z
			Direction.BOTTOM_TO_TOP:
				# North→South, carro à frente tem Z MAIOR (mais próximo da interseção)
				is_ahead = other_car.global_position.z > global_position.z
		
		if is_ahead and distance < closest_distance:
			closest_distance = distance
			closest_car = other_car
	
	return closest_car

# PREDICTIVE COLLISION TIME CALCULATION (Fixed for CharacterBody3D)
func predict_collision_time(other_car) -> float:
	var relative_pos = other_car.global_position - global_position
	
	# Convert current_speed to velocity vectors
	var my_velocity = get_velocity_vector()
	var other_velocity = other_car.get_velocity_vector()
	var relative_vel = other_velocity - my_velocity
	
	# Check if cars are moving towards each other
	if relative_vel.length_squared() < 0.01:  # Nearly stationary relative motion
		return -1.0
		
	if relative_vel.dot(relative_pos) >= 0:
		return -1.0  # Moving away or parallel
	
	# Calculate time to closest approach
	var time_to_collision = -relative_pos.dot(relative_vel) / relative_vel.length_squared()
	
	# Check if collision will actually occur
	var closest_distance = (relative_pos + relative_vel * time_to_collision).length()
	var collision_threshold = 2.0  # Combined vehicle width
	
	if closest_distance > collision_threshold:
		return -1.0  # No collision
	
	return time_to_collision

# CONVERT SPEED TO VELOCITY VECTOR
func get_velocity_vector() -> Vector3:
	match direction:
		Direction.LEFT_TO_RIGHT:
			return Vector3(current_speed, 0, 0)
		Direction.RIGHT_TO_LEFT:
			return Vector3(-current_speed, 0, 0)
		Direction.TOP_TO_BOTTOM:
			return Vector3(0, 0, -current_speed)
		Direction.BOTTOM_TO_TOP:
			return Vector3(0, 0, current_speed)
	return Vector3.ZERO

# LANE CHECKING (Simplified)
func is_in_same_lane(other_car) -> bool:
	return other_car.direction == direction and other_car.lane == lane

# BRAKING DISTANCE CALCULATION
func get_braking_distance() -> float:
	var personality_data = PERSONALITIES[personality]
	var deceleration = personality_data.deceleration
	
	# Physics: v² = u² + 2as, where v=0 (stop), u=current_speed
	var braking_distance = (current_speed * current_speed) / (2 * deceleration)
	return braking_distance + 1.0  # Add safety margin

# SAFE STOPPING CHECK (Using front bumper position)
func can_stop_safely_at_stop_line() -> bool:
	var distance_to_stop = get_distance_front_to_stop_line()  # Use FRONT distance
	var braking_distance = get_braking_distance()
	
	return distance_to_stop >= braking_distance

# YELLOW LIGHT DECISION (Personality-Based)
func should_stop_on_yellow() -> bool:
	var personality_data = PERSONALITIES[personality]
	var probability = personality_data.yellow_light_probability
	
	# Random decision based on personality
	return randf() > probability  # Higher probability = more likely to go

func should_stop_at_traffic_light() -> bool:
	# FUNÇÃO AUXILIAR para lógica de semáforos
	if not traffic_manager:
		return false
		
	var my_direction_name = get_direction_name()
	var light_state = traffic_manager.get_light_state_for_direction(my_direction_name)
	
	match light_state:
		"green":
			return false
		"red":
			return true
		"yellow":
			# LÓGICA DO AMARELO - EXATA DO HTML
			var distance_to_intersection = getDistanceToIntersection()  # Usar função consistente
			var can_proceed = traffic_manager.can_proceed_on_yellow(my_direction_name, distance_to_intersection, current_speed)
			var personality_factor = PERSONALITIES[personality].yellow_light_probability
			
			if can_proceed and randf() < personality_factor:
				return false  # Acelerar para passar
			else:
				return true   # Parar com segurança
	
	return true

# FUNÇÕES SIMPLES PARA PARADA ANTES DAS FAIXAS

func get_my_traffic_light_state() -> String:
	# Pegar estado do semáforo para minha direção
	if not traffic_manager:
		return "red"
	return traffic_manager.get_light_state_for_direction(get_direction_name())

# COLLISION AVOIDANCE BEHAVIOR (Reynolds Pattern)
func collision_avoidance_behavior() -> Dictionary:
	var result = {"should_stop": false, "distance": INF, "force": Vector3.ZERO}
	
	# Use cached car_ahead instead of expensive detection every frame
	if not car_ahead:
		return result
	
	# Calculate safe following distance using IDM principles
	var distance = calculate_following_distance(car_ahead)
	var safe_distance = calculate_safe_following_distance_IDM(car_ahead)
	
	result.distance = distance
	
	# Apply emergency braking if too close
	if distance < safe_distance:
		result.should_stop = true
	
	return result

# TRAFFIC LIGHT BEHAVIOR (FSM Pattern - ENHANCED STOPPING)
func traffic_light_behavior() -> Dictionary:
	var result = {"should_stop": false, "force": Vector3.ZERO}
	
	# 🚨 REGRA CRÍTICA: Se está CROSSING (atravessando), NUNCA para por semáforo
	if intersection_state == IntersectionState.CROSSING or is_in_intersection():
		result.should_stop = false
		return result  # Continua atravessando, ignorando semáforos
	
	var light_state = get_my_traffic_light_state()
	var stop_distance_front = get_distance_front_to_stop_line()  # Use FRONT position
	var braking_distance = get_braking_distance()
	
	# 🚨 REGRA ADICIONAL: Se já passou da linha de parada, IGNORE o semáforo
	if stop_distance_front <= 0:
		result.should_stop = false
		if light_state != "green":  # Debug apenas quando não é verde
			pass  # Debug print removed for performance
		return result  # Já passou da linha, continua independente do semáforo
	
	# Enhanced traffic light FSM with front bumper precision
	match light_state:
		"red":
			# Stop if we can reach the stop line safely
			if stop_distance_front > 0 and stop_distance_front <= braking_distance + 1.0:
				result.should_stop = true
		"yellow":
			# Enhanced yellow light decision
			if stop_distance_front <= braking_distance + 2.0:
				# Perto da linha - decisão baseada na personalidade
				result.should_stop = should_stop_on_yellow()
				pass  # Debug print removed for performance
			else:
				# Longe da linha - continua (não consegue parar seguro)
				result.should_stop = false
				pass  # Debug print removed for performance
		"green":
			result.should_stop = false
	
	return result

# PATH FOLLOWING BEHAVIOR (Reynolds Pattern)
func path_following_behavior() -> Dictionary:
	var result = {"force": Vector3.ZERO}
	# Keep vehicle centered in lane and following direction
	# This is handled by the movement system
	return result

# ENHANCED CAR DETECTION (Replaces old get_car_ahead with predictive capabilities)
func get_car_ahead_enhanced() -> Node:
	var cars = get_tree().get_nodes_in_group("cars")
	var closest_car = null
	var closest_distance = INF
	
	for car in cars:
		if car == self or not is_instance_valid(car):
			continue
			
		if not is_in_same_lane(car):
			continue
			
		# Check if car is ahead in direction of travel
		if not is_car_ahead_in_direction(car):
			continue
			
		# Calculate distance in direction of travel
		var distance = calculate_following_distance(car)
		if distance > 0 and distance < closest_distance:
			closest_distance = distance
			closest_car = car
	
	return closest_car

# DIRECTION-AWARE CAR AHEAD CHECK
func is_car_ahead_in_direction(other_car) -> bool:
	match direction:
		Direction.LEFT_TO_RIGHT:
			return other_car.global_position.x > global_position.x
		Direction.RIGHT_TO_LEFT:
			return other_car.global_position.x < global_position.x
		Direction.TOP_TO_BOTTOM:
			return other_car.global_position.z < global_position.z
		Direction.BOTTOM_TO_TOP:
			return other_car.global_position.z > global_position.z
	return false

# IDM-BASED SAFE DISTANCE CALCULATION
func calculate_safe_following_distance_IDM(leader_car) -> float:
	var personality_data = PERSONALITIES[personality]
	
	# IDM Parameters (from literature)
	var s0 = 2.0  # Minimum spacing (m)
	var T = personality_data.reaction_time[1]  # Desired time gap
	var v = current_speed  # Current speed
	var delta_v = current_speed - leader_car.current_speed  # Speed difference
	var a = personality_data.acceleration  # Max acceleration
	var b = personality_data.deceleration  # Comfortable deceleration
	
	# IDM desired spacing formula
	var s_star = s0 + max(0, v * T + (v * delta_v) / (2 * sqrt(a * b)))
	
	return s_star

# TRAFFIC LIGHT STOP LINE DISTANCE (BEFORE CROSSWALK)
func get_distance_to_stop_line() -> float:
	# Distance to stop line - BEFORE crosswalk entrance (not ON crosswalk)
	# Adding 2.0m safety buffer to stop BEFORE the white stripes
	var safety_buffer = 2.0  # Stop 2 meters before crosswalk
	
	match direction:
		Direction.LEFT_TO_RIGHT:  # Stop BEFORE North crosswalk
			return max(0.0, (-5.0 - safety_buffer) - global_position.x)
		Direction.RIGHT_TO_LEFT:  # Stop BEFORE South crosswalk
			return max(0.0, global_position.x - (5.0 - safety_buffer))
		Direction.TOP_TO_BOTTOM:  # Stop BEFORE South crosswalk
			return max(0.0, global_position.z - (5.0 - safety_buffer))
		Direction.BOTTOM_TO_TOP:  # Stop BEFORE East crosswalk
			return max(0.0, (7.0 - safety_buffer) - global_position.z)
	
	return 0.0


func has_crossed_crosswalk() -> bool:
	# Verificar se o carro já passou da faixa de pedestres
	match direction:
		Direction.LEFT_TO_RIGHT:  # West→East (VOLTOU AO ORIGINAL)
			# Faixa North está em X=-5.0, passou se X > -5.0
			return global_position.x > -5.0
		Direction.RIGHT_TO_LEFT:  # East→West (VOLTOU AO ORIGINAL)
			# Faixa South está em X=+5.0, passou se X < +5.0
			return global_position.x < 5.0
		Direction.TOP_TO_BOTTOM:  # South→North (CORRIGIDO - faixa sul X=+5.0)
			# Passou se X < +5.0
			return global_position.x < 5.0
		Direction.BOTTOM_TO_TOP:  # North→South (VOLTOU AO ORIGINAL)
			# Faixa East está em Z=+7.0, passou se Z > +7.0
			return global_position.z > 7.0
	return false

func is_in_intersection() -> bool:
	# Verificar se o carro está dentro da área da intersecção
	# Intersecção: aproximadamente X=[-4, +4] e Z=[-4, +4]
	var in_x_intersection = abs(global_position.x) <= 4.0
	var in_z_intersection = abs(global_position.z) <= 4.0
	return in_x_intersection and in_z_intersection

func get_distance_to_crosswalk() -> float:
	# Distância até a faixa de pedestres para cada direção
	match direction:
		Direction.LEFT_TO_RIGHT:  # West→East (VOLTOU AO ORIGINAL)
			# Faixa North está em X=-5.0
			var crosswalk_x = -5.0
			return max(0.0, crosswalk_x - global_position.x)
		Direction.RIGHT_TO_LEFT:  # East→West (VOLTOU AO ORIGINAL)
			# Faixa South está em X=+5.0
			var crosswalk_x = 5.0
			return max(0.0, global_position.x - crosswalk_x)
		Direction.TOP_TO_BOTTOM:  # South→North (CORRIGIDO - para na faixa sul)
			# Faixa South está em X=+5.0
			var crosswalk_x = 5.0
			return max(0.0, global_position.x - crosswalk_x)
		Direction.BOTTOM_TO_TOP:  # North→South (VOLTOU AO ORIGINAL)
			# Faixa East está em Z=+7.0
			var crosswalk_z = 7.0
			return max(0.0, crosswalk_z - global_position.z)
	
	return 0.0

# FUNÇÕES AUXILIARES EXATAS DO HTML

func getDistanceBetweenCars(car1, car2) -> float:
	# FUNÇÃO DO HTML - linhas 786-797
	# Calcular distância real levando em conta a direção do movimento
	match car1.direction:
		Direction.LEFT_TO_RIGHT:
			return abs(car2.global_position.x - car1.global_position.x)
		Direction.RIGHT_TO_LEFT:
			return abs(car1.global_position.x - car2.global_position.x)
		Direction.TOP_TO_BOTTOM:
			return abs(car1.global_position.z - car2.global_position.z)
		Direction.BOTTOM_TO_TOP:
			return abs(car1.global_position.z - car2.global_position.z)
	return car1.global_position.distance_to(car2.global_position)

func getDistanceToIntersection() -> float:
	# FUNÇÃO DO HTML - linhas 799-809
	match direction:
		Direction.LEFT_TO_RIGHT:
			return max(0.0, -global_position.x)  # Distância até interseção em X=0
		Direction.RIGHT_TO_LEFT:
			return max(0.0, global_position.x)   # Distância até interseção em X=0
		Direction.TOP_TO_BOTTOM:
			return max(0.0, global_position.z)  # South→North: distância até interseção em Z=0
		Direction.BOTTOM_TO_TOP:
			return max(0.0, -global_position.z)  # North→South: distância até interseção em Z=0
	return 0.0

func hasPassedIntersection() -> bool:
	# FUNÇÃO DO HTML - linhas 811-821
	match direction:
		Direction.LEFT_TO_RIGHT:
			return global_position.x > 4.0    # HTML linha 814
		Direction.RIGHT_TO_LEFT:
			return global_position.x < -4.0   # HTML linha 816
		Direction.TOP_TO_BOTTOM:
			return global_position.z < -4.0   # HTML linha 818
		Direction.BOTTOM_TO_TOP:
			return global_position.z > 4.0    # North→South: passou quando Z > 4
	return false

func shouldStopAtTrafficLight() -> bool:
	# LÓGICA SIMPLIFICADA: verificar estado do semáforo
	if not traffic_manager:
		return false
	
	var my_direction_name = get_direction_name()
	var light_state = traffic_manager.get_light_state_for_direction(my_direction_name)
	
	# Debug menos frequente
	if car_id % 100 == 0 and fmod(Engine.get_process_frames(), 120) == 0:  # Debug a cada 2 segundos
		var _distance_to_intersection = getDistanceToIntersection()
		pass  # Debug print removed for performance
	
	# VERMELHO: sempre parar
	if light_state == "red":
		return true
	
	# AMARELO: lógica baseada na personalidade e distância
	elif light_state == "yellow":
		var distanceToIntersection = getDistanceToIntersection()
		var personality_factor = PERSONALITIES[personality].yellow_light_probability
		
		# Se está muito próximo (< 6.0), tentar passar
		if distanceToIntersection < 6.0:
			return randf() > personality_factor  # Chance baseada na personalidade
		else:
			return true  # Se está longe, parar
	
	# VERDE: não parar
	return false


# ENHANCED STOPPING SYSTEM - FRONT BUMPER CALCULATION
func get_car_front_position() -> Vector3:
	# Calculate front bumper position for accurate stopping
	var car_length = 1.5
	var front_offset = Vector3.ZERO
	
	match direction:
		Direction.LEFT_TO_RIGHT:
			front_offset = Vector3(car_length/2, 0, 0)
		Direction.RIGHT_TO_LEFT:
			front_offset = Vector3(-car_length/2, 0, 0)
		Direction.TOP_TO_BOTTOM:
			front_offset = Vector3(0, 0, -car_length/2)
		Direction.BOTTOM_TO_TOP:
			front_offset = Vector3(0, 0, car_length/2)
	
	return global_position + front_offset

# PRECISE STOP LINE DISTANCE (Using front bumper position)
func get_distance_front_to_stop_line() -> float:
	# Distance from car FRONT to stop line (BEFORE crosswalk)
	var front_pos = get_car_front_position()
	var safety_buffer = 2.0  # Stop 2m BEFORE crosswalk
	
	match direction:
		Direction.LEFT_TO_RIGHT:  # Moving West to East
			# Crosswalk at x=-5.0, want to stop at x=-7.0 (2m before)
			var target_stop_x = -5.0 - safety_buffer  # -7.0
			return max(0.0, target_stop_x - front_pos.x)  # Distance to reach -7.0
			
		Direction.RIGHT_TO_LEFT:  # Moving East to West  
			# Crosswalk at x=5.0, want to stop at x=7.0 (2m before)
			var target_stop_x = 5.0 + safety_buffer  # 7.0
			return max(0.0, front_pos.x - target_stop_x)  # Distance to reach 7.0
			
		Direction.TOP_TO_BOTTOM:  # Moving North to South
			# Crosswalk at z=5.0, want to stop at z=7.0 (2m before)
			var target_stop_z = 5.0 + safety_buffer  # 7.0
			return max(0.0, front_pos.z - target_stop_z)  # Distance to reach 7.0
			
		Direction.BOTTOM_TO_TOP:  # Moving South to North
			# Crosswalk at z=-5.0, want to stop at z=-7.0 (2m before)
			var target_stop_z = -5.0 - safety_buffer  # -7.0
			return max(0.0, target_stop_z - front_pos.z)  # Distance to reach -7.0
	
	return 0.0

func get_direction_name() -> String:
	# Mapear direção para nome do semáforo - LÓGICA DO HTML
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

# DUPLICATES REMOVED - Functions already exist above

# IDM (INTELLIGENT DRIVER MODEL) - ACADEMIC STANDARD
func update_movement(delta):
	# Get leader car for IDM calculation
	var leader_car = get_car_ahead()
	
	# Calculate acceleration using IDM
	var acceleration = calculate_IDM_acceleration(leader_car)
	
	# Apply traffic light constraints
	if should_stop:
		acceleration = min(acceleration, -PERSONALITIES[personality].deceleration)
	
	# Update speed using IDM acceleration
	current_speed = max(0.0, current_speed + acceleration * delta)
	current_speed = min(current_speed, max_speed)
	
	# Analytics - waiting detection
	update_waiting_state()

# IDM ACCELERATION CALCULATION (From SUMO/Academic Literature)
func calculate_IDM_acceleration(leader_car) -> float:
	var personality_data = PERSONALITIES[personality]
	
	# IDM Parameters
	var v0 = max_speed  # Desired speed
	var v = current_speed  # Current speed
	var a = personality_data.acceleration  # Max acceleration
	var b = personality_data.deceleration  # Comfortable deceleration
	var s0 = 2.0  # Minimum spacing
	var T = personality_data.reaction_time[1]  # Desired time gap
	
	# Free flow acceleration (when no leader)
	var free_flow_accel = a * (1.0 - pow(v / v0, 4))
	
	if not leader_car:
		return free_flow_accel
	
	# Interaction acceleration (when following leader)
	var s = calculate_following_distance(leader_car)  # Current spacing
	var delta_v = v - leader_car.current_speed  # Speed difference
	
	# IDM desired spacing
	var s_star = s0 + max(0.0, v * T + (v * delta_v) / (2.0 * sqrt(a * b)))
	
	# IDM acceleration formula
	var interaction_term = pow(s_star / max(s, 0.1), 2)
	var idm_acceleration = a * (1.0 - pow(v / v0, 4) - interaction_term)
	
	return idm_acceleration

# FOLLOWING DISTANCE CALCULATION (Euclidean but direction-aware)
func calculate_following_distance(leader_car) -> float:
	if not leader_car:
		return INF
	
	# Calculate distance in direction of travel
	match direction:
		Direction.LEFT_TO_RIGHT:
			return max(0.1, leader_car.global_position.x - global_position.x)
		Direction.RIGHT_TO_LEFT:
			return max(0.1, global_position.x - leader_car.global_position.x)
		Direction.TOP_TO_BOTTOM:
			return max(0.1, global_position.z - leader_car.global_position.z)
		Direction.BOTTOM_TO_TOP:
			return max(0.1, leader_car.global_position.z - global_position.z)
	
	return global_position.distance_to(leader_car.global_position)

# WAITING STATE UPDATE
func update_waiting_state():
	if current_speed < 0.5 and should_stop:
		if not is_waiting:
			is_waiting = true
	else:
		is_waiting = false

func move_car():
	# MOVIMENTO SUAVE SEM FÍSICA - evita teleportes
	if current_speed <= 0.01:
		return
	
	# Calcular movimento baseado na direção
	var movement = Vector3.ZERO
	match direction:
		Direction.LEFT_TO_RIGHT:
			movement = Vector3(current_speed, 0, 0)
		Direction.RIGHT_TO_LEFT:
			movement = Vector3(-current_speed, 0, 0)
		Direction.TOP_TO_BOTTOM:
			movement = Vector3(0, 0, -current_speed)  # South→North: Z negativo
		Direction.BOTTOM_TO_TOP:
			movement = Vector3(0, 0, current_speed)   # North→South: Z positivo
	
	# MOVIMENTO DIRETO sem colisões físicas - evita teleportes
	var delta = get_physics_process_delta_time()
	global_position += movement * delta
	
	# Marcar se passou da intersecção
	if not has_passed_intersection:
		check_intersection_passage()

# INTERSECTION STATE MACHINE UPDATE (Enhanced with Front Bumper)
func update_intersection_state():
	var distance_to_stop = get_distance_front_to_stop_line()  # Use FRONT distance
	var braking_distance = get_braking_distance()
	var light_state = get_my_traffic_light_state()
	
	# Enhanced FSM with precise stopping and crossing state
	match intersection_state:
		IntersectionState.APPROACHING:
			if distance_to_stop <= braking_distance + 2.0:  # Extra margin
				if light_state == "red" or (light_state == "yellow" and can_stop_safely_at_stop_line()):
					intersection_state = IntersectionState.WAITING
				else:
					intersection_state = IntersectionState.PROCEEDING
					
		IntersectionState.WAITING:
			if light_state == "green":
				intersection_state = IntersectionState.PROCEEDING
				
		IntersectionState.PROCEEDING:
			# Quando começar a entrar na interseção, muda para CROSSING
			if is_in_intersection():
				intersection_state = IntersectionState.CROSSING
				pass  # Debug print removed for performance
				
		IntersectionState.CROSSING:
			# 🚨 ESTADO CRÍTICO: Nunca para, só pode parar por carro à frente
			# Quando sai da interseção, vai para CLEARING
			if not is_in_intersection():
				intersection_state = IntersectionState.CLEARING
				
		IntersectionState.CLEARING:
			if hasPassedIntersection():
				has_passed_intersection = true
				# Reset state for next intersection
				intersection_state = IntersectionState.APPROACHING

func check_intersection_passage():
	# Update the intersection state machine
	update_intersection_state()

func check_cleanup():
	# Remover carro assim que sair das ruas (limites do mapa: -40 a +40)
	var should_cleanup = false
	var map_limit = 42.0  # Pequena margem além dos limites das ruas
	
	match direction:
		Direction.LEFT_TO_RIGHT:  # West → East
			should_cleanup = global_position.x > map_limit
		Direction.RIGHT_TO_LEFT:  # East → West  
			should_cleanup = global_position.x < -map_limit
		Direction.TOP_TO_BOTTOM:  # North → South
			should_cleanup = global_position.z > map_limit
		Direction.BOTTOM_TO_TOP:  # South → North
			should_cleanup = global_position.z < -map_limit
	
	if should_cleanup:
		pass  # Debug print removed for performance
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
