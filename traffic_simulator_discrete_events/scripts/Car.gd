extends CharacterBody3D
class_name Car

# EVENTOS DISCRETOS COM MOVIMENTO VISUAL
enum Direction { LEFT_TO_RIGHT, RIGHT_TO_LEFT, TOP_TO_BOTTOM, BOTTOM_TO_TOP }
enum DriverPersonality { AGGRESSIVE, CONSERVATIVE, NORMAL, ELDERLY }

# Personalidades simplificadas para eventos discretos
const PERSONALITIES = {
	DriverPersonality.NORMAL: {
		"base_speed": 5.0,
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
var car_id: int
var personality: DriverPersonality = DriverPersonality.NORMAL

# Estados do movimento para eventos discretos + movimento visual
var current_speed: float = 0.0
var target_speed: float = 5.0
var max_speed: float = 11.0
var should_stop: bool = false
var car_ahead = null
var distance_to_car_ahead: float = 999.0
var has_passed_intersection: bool = false

# Estados dos eventos discretos
var estado_evento: String = "spawning"  # spawning, moving, waiting, crossing, exiting
var tempo_spawn: float = 0.0

# Visual
var mesh_instance: MeshInstance3D
var material: StandardMaterial3D

# Referencias ao sistema
var traffic_manager: Node

func _ready():
	print("🚗 Carro %d criado para EVENTOS DISCRETOS com movimento visual" % car_id)
	
	traffic_manager = get_tree().get_first_node_in_group("traffic_manager")
	
	setup_personality()
	create_car_geometry()
	add_to_group("cars")
	
	# Registrar no traffic manager
	if traffic_manager and traffic_manager.has_method("register_car"):
		traffic_manager.register_car(self)
	
	# Inicializar estado
	mudar_estado_evento("moving")

# ========== FUNÇÕES DE SETUP ==========

func setup_personality():
	"""Setup personalidade simplificada"""
	var config = PERSONALITIES[personality]
	target_speed = config.base_speed
	max_speed = config.base_speed * 1.2

func create_car_geometry():
	"""Cria geometria do carro usando assets 3D como o simulador original"""
	# Usar modelos 3D reais
	create_3d_car_model()
	
	# Collision shape (simplificado)
	var collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(0.8, 0.4, 1.5)
	collision.shape = box_shape
	add_child(collision)

func create_3d_car_model() -> void:
	"""Carrega modelos 3D de carros como no simulador original"""
	# Mesmos modelos do simulador 3D original
	var car_models = [
		"res://assets/vehicles/sedan.glb",
		"res://assets/vehicles/hatchback-sports.glb", 
		"res://assets/vehicles/suv.glb",
		"res://assets/vehicles/police.glb"
	]
	
	# Escolher modelo aleatório
	var model_path = car_models[randi() % car_models.size()]
	var car_scene = load(model_path)
	
	if car_scene and car_scene.can_instantiate():
		var car_model = car_scene.instantiate()
		car_model.name = "CarModel"
		# Escala igual ao simulador original
		car_model.scale = Vector3(0.4, 0.4, 0.4)
		car_model.position = Vector3(0, -0.3, 0)
		
		add_child(car_model)
		
		# Aplicar cor aleatória ao modelo
		apply_random_color_to_car(car_model)
		
		print("✅ Modelo 3D carregado: %s para carro %d" % [model_path, car_id])
	else:
		print("❌ Falha ao carregar modelo, usando fallback")
		create_fallback_car_mesh()

func create_fallback_car_mesh():
	"""Fallback caso os modelos 3D não carreguem"""
	var car_body = MeshInstance3D.new()
	var body_mesh = BoxMesh.new()
	body_mesh.size = Vector3(0.8, 0.4, 1.5)
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
	
	# Indicador frontal
	var front_indicator = MeshInstance3D.new()
	var indicator_mesh = BoxMesh.new()
	indicator_mesh.size = Vector3(0.8, 0.3, 0.2)
	front_indicator.mesh = indicator_mesh
	front_indicator.position = Vector3(0, 0.2, -0.9)
	
	var indicator_material = StandardMaterial3D.new()
	indicator_material.albedo_color = Color.RED
	indicator_material.emission = Color.RED * 0.3
	front_indicator.material_override = indicator_material
	car_body.add_child(front_indicator)

func apply_random_color_to_car(car_node: Node3D):
	"""Aplica cor aleatória ao carro como no simulador original"""
	# Mesmas cores do simulador 3D original
	var colors = [
		Color(0.8, 0.8, 0.8),          # Cinza claro
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
	
	# Verificar se o node é válido
	if not is_instance_valid(car_node):
		return
	
	# Aplicar cor recursivamente
	update_car_materials(car_node, chosen_color)

func update_car_materials(node: Node3D, color: Color):
	"""Atualiza materiais do carro como no simulador original"""
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		
		# Identificar partes do carro
		var node_name = node.name.to_lower()
		var is_car_body = not ("wheel" in node_name or "tire" in node_name or 
							  "light" in node_name or "glass" in node_name or
							  "window" in node_name or "debris" in node_name or
							  "trim" in node_name or "chrome" in node_name)
		
		if mesh_instance.mesh:
			var material = StandardMaterial3D.new()
			
			# Aplicar materiais diferentes baseado no tipo de parte
			if is_car_body:
				# Carroceria - usar cor escolhida
				material.albedo_color = color
				material.metallic = 0.4
				material.roughness = 0.2
			else:
				# Rodas/acessórios - usar cores escuras
				material.albedo_color = Color(0.1, 0.1, 0.1)
				material.metallic = 0.1
				material.roughness = 0.8
			
			material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			material.cull_mode = BaseMaterial3D.CULL_BACK
			
			# Aplicar material
			mesh_instance.material_override = material
			
			# Aplicar a todas as superfícies
			for surface_idx in range(mesh_instance.mesh.get_surface_count()):
				mesh_instance.set_surface_override_material(surface_idx, material)
	
	# Processar filhos recursivamente
	for child in node.get_children():
		if child is Node3D:
			update_car_materials(child, color)

# ========== MOVIMENTO VISUAL + EVENTOS DISCRETOS ==========

func _physics_process(delta):
	"""Movimento visual contínuo controlado por eventos discretos"""
	if estado_evento == "moving":
		update_ai_behavior(delta)
		move_car(delta)
	elif estado_evento == "waiting":
		# Parado no semáforo
		current_speed = 0.0

func update_ai_behavior(delta):
	"""Atualiza comportamento de IA"""
	detect_car_ahead()
	check_traffic_lights()
	update_target_speed()

func detect_car_ahead():
	"""Detecta carro à frente"""
	car_ahead = null
	distance_to_car_ahead = 999.0
	
	var cars = get_tree().get_nodes_in_group("cars")
	for car in cars:
		if car == self or not is_instance_valid(car):
			continue
		
		if is_car_in_front(car):
			var dist = global_position.distance_to(car.global_position)
			if dist < distance_to_car_ahead:
				distance_to_car_ahead = dist
				car_ahead = car

func is_car_in_front(car) -> bool:
	"""Verifica se carro está à frente"""
	if car.direction != direction or car.lane != lane:
		return false
	
	match direction:
		Direction.LEFT_TO_RIGHT:
			return car.global_position.x > global_position.x
		Direction.RIGHT_TO_LEFT:
			return car.global_position.x < global_position.x
		Direction.BOTTOM_TO_TOP:
			return car.global_position.z < global_position.z
		Direction.TOP_TO_BOTTOM:
			return car.global_position.z > global_position.z
	
	return false

func check_traffic_lights():
	"""Verifica semáforos"""
	should_stop = false
	
	if not traffic_manager:
		return
	
	var light_state = get_traffic_light_state()
	var distance_to_intersection = get_distance_to_intersection()
	
	if distance_to_intersection < 15.0:
		if light_state == "red":
			should_stop = true
			mudar_estado_evento("waiting")
		elif light_state == "green":
			if estado_evento == "waiting":
				mudar_estado_evento("moving")

func get_traffic_light_state() -> String:
	"""Obtém estado do semáforo para esta direção"""
	if not traffic_manager:
		return "green"
	
	# USAR A MESMA LÓGICA DO SIMULADOR 3D ORIGINAL
	var direction_name = get_direction_name()
	return traffic_manager.get_light_state_for_direction(direction_name)

func get_direction_name() -> String:
	"""Mapear direção para nome do semáforo - LÓGICA DO HTML ORIGINAL"""
	match direction:
		Direction.LEFT_TO_RIGHT:
			return "West"
		Direction.RIGHT_TO_LEFT:
			return "East"
		Direction.TOP_TO_BOTTOM:
			return "North"
		Direction.BOTTOM_TO_TOP:
			return "South"
		_:
			return "West"

func get_distance_to_intersection() -> float:
	"""Calcula distância até a intersecção"""
	var intersection_pos = Vector3(0, 0, 0)  # Centro da intersecção
	
	match direction:
		Direction.LEFT_TO_RIGHT:
			return max(0, intersection_pos.x - global_position.x)
		Direction.RIGHT_TO_LEFT:
			return max(0, global_position.x - intersection_pos.x)
		Direction.BOTTOM_TO_TOP:
			return max(0, global_position.z - intersection_pos.z)
		Direction.TOP_TO_BOTTOM:
			return max(0, intersection_pos.z - global_position.z)
	
	return 0.0

func update_target_speed():
	"""Atualiza velocidade alvo"""
	if should_stop:
		target_speed = 0.0
	elif car_ahead and distance_to_car_ahead < 8.0:
		# Seguir carro à frente
		target_speed = min(car_ahead.current_speed, max_speed * 0.8)
	else:
		target_speed = max_speed

func move_car(delta):
	"""Move o carro fisicamente"""
	# Acelerar/desacelerar suavemente
	if current_speed < target_speed:
		current_speed = min(target_speed, current_speed + 8.0 * delta)
	else:
		current_speed = max(target_speed, current_speed - 12.0 * delta)
	
	# Calcular direção de movimento
	var move_direction = get_movement_direction()
	velocity = move_direction * current_speed
	
	# Usar CharacterBody3D movement
	move_and_slide()
	
	# Verificar se saiu do mapa
	if is_out_of_bounds():
		destruir_carro()

func get_movement_direction() -> Vector3:
	"""Obtém direção de movimento baseada na direção do carro"""
	match direction:
		Direction.LEFT_TO_RIGHT:
			return Vector3(1, 0, 0)
		Direction.RIGHT_TO_LEFT:
			return Vector3(-1, 0, 0)
		Direction.BOTTOM_TO_TOP:
			return Vector3(0, 0, -1)
		Direction.TOP_TO_BOTTOM:
			return Vector3(0, 0, 1)
	
	return Vector3.ZERO

func is_out_of_bounds() -> bool:
	"""Verifica se carro saiu dos limites do mapa"""
	var pos = global_position
	var margin = 50.0
	
	# Verificar limites baseado na direção de movimento
	match direction:
		Direction.LEFT_TO_RIGHT:
			return pos.x > margin  # Saiu pela direita
		Direction.RIGHT_TO_LEFT:
			return pos.x < -margin  # Saiu pela esquerda
		Direction.BOTTOM_TO_TOP:
			return pos.z < -margin  # Saiu pelo norte
		Direction.TOP_TO_BOTTOM:
			return pos.z > margin   # Saiu pelo sul
	
	# Fallback: qualquer direção fora dos limites
	return abs(pos.x) > margin or abs(pos.z) > margin

# ========== EVENTOS DISCRETOS ==========

func mudar_estado_evento(novo_estado: String):
	"""Muda estado do carro"""
	estado_evento = novo_estado
	
	# Atualizar cor visual baseado no estado
	if material:
		match novo_estado:
			"spawning":
				material.emission = Color.CYAN * 0.3
			"moving":
				material.emission = Color.BLACK
			"waiting":
				material.emission = Color.RED * 0.3
			"crossing":
				material.emission = Color.GREEN * 0.3

func destruir_carro():
	"""Remove carro do sistema"""
	print("🏁 Carro #%d saindo do sistema (t=%.1fs)" % [car_id, Time.get_unix_time_from_system()])
	
	# Notificar traffic manager
	if traffic_manager and traffic_manager.has_method("unregister_car"):
		traffic_manager.unregister_car(self)
	
	# Notificar gerenciador de eventos (opcional)
	var gerenciador = get_tree().get_first_node_in_group("simulador_trafego")
	if gerenciador and gerenciador.gerenciador_eventos:
		# Agendar evento de saída
		var tempo_saida = gerenciador.gerenciador_eventos.tempo_simulacao + 0.1
		gerenciador.gerenciador_eventos.agendar_evento(
			tempo_saida, 
			gerenciador.gerenciador_eventos.TipoEvento.SAIDA_CARRO,
			{"car_id": car_id}
		)
	
	queue_free()