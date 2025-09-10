class_name Car
extends CharacterBody3D

## Carro com suporte a modo híbrido
## Pode funcionar tanto em modo contínuo quanto controlado por eventos discretos

# Propriedades básicas do carro
var car_id: int = 0
var direction: int = 0  # DiscreteCar.Direction
var lane: int = 0
var current_speed: float = 0.0
var target_speed: float = 0.0
var max_speed: float = 5.0

# Estado do carro
var is_moving: bool = false
var is_waiting: bool = false
var is_in_intersection: bool = false

# PROPRIEDADES HÍBRIDAS
var hybrid_mode: bool = false
var visual_speed: float = 0.0
var discrete_controlled: bool = false

# Componentes visuais
@onready var mesh_instance: MeshInstance3D
@onready var collision_shape: CollisionShape3D

# Efeitos visuais
var exhaust_particles: GPUParticles3D
var brake_lights: Array[MeshInstance3D] = []
var headlights: Array[SpotLight3D] = []

# Configurações de movimento
var acceleration: float = 5.0
var deceleration: float = 8.0
var turning_speed: float = 2.0

# Sinais
signal car_stopped()
signal car_started()
signal reached_destination()
signal speed_changed(new_speed: float)

func _ready():
	print("🚗 Car %d initialized" % car_id)
	
	# Configurar componentes visuais
	setup_visual_components()
	
	# Configurar física
	setup_physics()
	
	# Configurar efeitos
	setup_visual_effects()

func setup_visual_components():
	"""Configura componentes visuais do carro"""
	# Encontrar ou criar MeshInstance3D
	mesh_instance = get_node_or_null("MeshInstance3D")
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		add_child(mesh_instance)
		
		# Mesh padrão
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3(2.5, 1.0, 1.2)
		mesh_instance.mesh = box_mesh
		
		# Material padrão
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.2, 0.6, 1.0)  # Azul
		material.metallic = 0.8
		material.roughness = 0.2
		mesh_instance.material_override = material
	
	# Encontrar ou criar CollisionShape3D
	collision_shape = get_node_or_null("CollisionShape3D")
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		add_child(collision_shape)
		
		# Shape padrão
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(2.5, 1.0, 1.2)
		collision_shape.shape = box_shape

func setup_physics():
	"""Configura propriedades físicas"""
	# Configurar CharacterBody3D
	floor_stop_on_slope = true
	floor_block_on_wall = true
	floor_max_angle = deg_to_rad(45)

func setup_visual_effects():
	"""Configura efeitos visuais como partículas e luzes"""
	# Partículas de escapamento
	exhaust_particles = GPUParticles3D.new()
	exhaust_particles.name = "ExhaustParticles"
	exhaust_particles.position = Vector3(0, 0, 1.3)  # Atrás do carro
	exhaust_particles.amount = 100
	exhaust_particles.emitting = false
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0, 1)  # Para trás
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 5.0
	material.gravity = Vector3(0, -1, 0)
	material.scale_min = 0.1
	material.scale_max = 0.3
	
	exhaust_particles.process_material = material
	add_child(exhaust_particles)
	
	# Luzes de freio (placeholder)
	_create_brake_lights()
	
	# Faróis (placeholder)
	_create_headlights()

func _create_brake_lights():
	"""Cria luzes de freio"""
	for i in range(2):  # 2 luzes de freio
		var brake_light = MeshInstance3D.new()
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 0.1
		brake_light.mesh = sphere_mesh
		
		var material = StandardMaterial3D.new()
		material.albedo_color = Color.RED
		material.emission = Color.BLACK  # Apagado inicialmente
		brake_light.material_override = material
		
		brake_light.position = Vector3(-0.8 + i * 1.6, 0.2, 1.2)  # Traseira do carro
		brake_lights.append(brake_light)
		add_child(brake_light)

func _create_headlights():
	"""Cria faróis"""
	for i in range(2):  # 2 faróis
		var headlight = SpotLight3D.new()
		headlight.light_energy = 1.0
		headlight.spot_range = 20.0
		headlight.spot_angle = 45.0
		headlight.light_color = Color(1.0, 0.9, 0.8)  # Branco quente
		
		headlight.position = Vector3(-0.7 + i * 1.4, 0.5, -1.2)  # Frente do carro
		headlight.rotation_degrees = Vector3(0, 180, 0)  # Apontar para frente
		
		headlights.append(headlight)
		add_child(headlight)

# =================================================================
# MODO HÍBRIDO - INTERFACE PRINCIPAL
# =================================================================

func set_hybrid_mode(enabled: bool):
	"""Ativa/desativa controle por eventos discretos"""
	hybrid_mode = enabled
	discrete_controlled = enabled
	
	if hybrid_mode:
		print("🎯 Car %d: MODO HÍBRIDO ativado" % car_id)
		# Desabilitar física contínua para evitar conflitos
		set_physics_process(false)
		# Manter apenas visual e animações
		set_process(true)
		
		# Parar partículas de movimento contínuo
		if exhaust_particles:
			exhaust_particles.emitting = false
		
	else:
		print("🔄 Car %d: MODO CONTÍNUO ativado" % car_id)
		# Habilitar física contínua
		set_physics_process(true)

func set_visual_speed(speed: float):
	"""Define velocidade visual para compatibilidade com analytics"""
	visual_speed = speed
	
	# Atualizar current_speed para manter compatibilidade
	if hybrid_mode:
		current_speed = visual_speed
		
		# Atualizar efeitos visuais baseados na velocidade
		_update_speed_effects(speed)
		
		speed_changed.emit(speed)

func get_current_speed() -> float:
	"""Retorna velocidade atual (funciona em ambos os modos)"""
	return visual_speed if hybrid_mode else current_speed

# =================================================================
# PROCESSAMENTO POR MODO
# =================================================================

func _physics_process(delta):
	"""Processamento físico - apenas no modo contínuo"""
	if not hybrid_mode:
		# Lógica contínua original
		_process_continuous_movement(delta)

func _process(delta):
	"""Processamento sempre ativo - para efeitos visuais"""
	if hybrid_mode:
		# Atualizações visuais no modo híbrido
		update_visual_effects(delta)
	else:
		# Atualizações visuais no modo contínuo
		update_visual_effects(delta)

func _process_continuous_movement(delta):
	"""Movimento físico contínuo (modo tradicional)"""
	if not is_moving:
		return
	
	# Acelerar/desacelerar
	if current_speed < target_speed:
		current_speed = min(target_speed, current_speed + acceleration * delta)
	elif current_speed > target_speed:
		current_speed = max(target_speed, current_speed - deceleration * delta)
	
	# Aplicar movimento
	if current_speed > 0.1:
		var movement_direction = -transform.basis.z  # Forward do carro
		velocity = movement_direction * current_speed
		move_and_slide()
		
		# Atualizar efeitos
		_update_speed_effects(current_speed)
	else:
		velocity = Vector3.ZERO

func update_visual_effects(delta):
	"""Atualizações visuais (funciona em ambos os modos)"""
	var effective_speed = get_current_speed()
	
	# Partículas de escapamento
	if exhaust_particles:
		exhaust_particles.emitting = effective_speed > 0.5
		if exhaust_particles.emitting:
			# Ajustar intensidade baseada na velocidade
			var intensity = clamp(effective_speed / max_speed, 0.2, 1.0)
			exhaust_particles.amount = int(50 * intensity)
	
	# Rotação das rodas (se houver)
	_update_wheel_rotation(delta, effective_speed)
	
	# Faróis noturnos
	_update_headlights()

func _update_speed_effects(speed: float):
	"""Atualiza efeitos baseados na velocidade"""
	# Luzes de freio
	var is_braking = speed < current_speed - 0.1
	_set_brake_lights(is_braking)
	
	# Som do motor (placeholder)
	_update_engine_sound(speed)

func _set_brake_lights(active: bool):
	"""Ativa/desativa luzes de freio"""
	for brake_light in brake_lights:
		if brake_light and brake_light.material_override:
			var material = brake_light.material_override as StandardMaterial3D
			material.emission = Color.RED if active else Color.BLACK
			material.emission_energy = 2.0 if active else 0.0

func _update_headlights():
	"""Atualiza faróis (noturno/diurno)"""
	# Detectar se é noite (simplificado)
	var is_night = false  # TODO: Implementar detecção de tempo
	
	for headlight in headlights:
		if headlight:
			headlight.visible = is_night

func _update_wheel_rotation(delta: float, speed: float):
	"""Rotaciona rodas baseado na velocidade"""
	# TODO: Implementar rotação das rodas se houver meshes separados
	pass

func _update_engine_sound(speed: float):
	"""Atualiza som do motor"""
	# TODO: Implementar AudioStreamPlayer3D para som do motor
	pass

# =================================================================
# CONTROLES PÚBLICOS
# =================================================================

func start_moving(target_speed_value: float = -1.0):
	"""Inicia movimento do carro"""
	is_moving = true
	is_waiting = false
	
	if target_speed_value > 0:
		target_speed = target_speed_value
	else:
		target_speed = max_speed
	
	car_started.emit()
	print("🚗 Car %d started moving (target speed: %.1f)" % [car_id, target_speed])

func stop_car():
	"""Para o carro"""
	is_moving = false
	target_speed = 0.0
	
	if hybrid_mode:
		visual_speed = 0.0
		current_speed = 0.0
	
	car_stopped.emit()
	print("🚗 Car %d stopped" % car_id)

func set_target_speed(speed: float):
	"""Define velocidade alvo"""
	target_speed = clamp(speed, 0.0, max_speed)

func set_direction_rotation(new_direction: int):
	"""Define rotação baseada na direção"""
	direction = new_direction
	
	var target_rotation: float
	match direction:
		0: target_rotation = 0.0      # LEFT_TO_RIGHT
		1: target_rotation = PI       # RIGHT_TO_LEFT
		3: target_rotation = PI/2     # BOTTOM_TO_TOP
		_: target_rotation = 0.0
	
	rotation.y = target_rotation

func teleport_to(position: Vector3):
	"""Teleporta carro para posição"""
	global_position = position
	print("📍 Car %d teleported to %s" % [car_id, position])

func set_car_color(color: Color):
	"""Define cor do carro"""
	if mesh_instance and mesh_instance.material_override:
		var material = mesh_instance.material_override as StandardMaterial3D
		material.albedo_color = color

# =================================================================
# INFORMAÇÕES E DEBUG
# =================================================================

func get_car_info() -> Dictionary:
	"""Retorna informações do carro"""
	return {
		"car_id": car_id,
		"position": global_position,
		"rotation": rotation.y,
		"current_speed": get_current_speed(),
		"target_speed": target_speed,
		"is_moving": is_moving,
		"is_waiting": is_waiting,
		"hybrid_mode": hybrid_mode,
		"discrete_controlled": discrete_controlled
	}

func get_debug_info() -> String:
	"""Informações debug do carro"""
	return "Car %d: Pos(%.1f,%.1f,%.1f) Speed:%.1f %s" % [
		car_id,
		global_position.x, global_position.y, global_position.z,
		get_current_speed(),
		"HYBRID" if hybrid_mode else "CONTINUOUS"
	]

# =================================================================
# COMPATIBILIDADE COM SISTEMA ANTIGO
# =================================================================

func register_car():
	"""Compatibilidade com registro de carro"""
	print("🚗 Car %d registered" % car_id)

func unregister_car():
	"""Compatibilidade com desregistro de carro"""
	print("🚗 Car %d unregistered" % car_id)

# Propriedades adicionais para compatibilidade
func set_lane(lane_number: int):
	lane = lane_number

func get_lane() -> int:
	return lane