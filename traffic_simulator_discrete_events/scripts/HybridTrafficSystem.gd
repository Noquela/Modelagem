class_name HybridTrafficSystem
extends Node3D

## Sistema principal que integra eventos discretos com renderização 3D
## Combina precisão dos eventos discretos com fluidez visual do 3D contínuo

# Componentes do sistema híbrido
var discrete_simulator: DiscreteTrafficSimulator
var visual_renderer: VisualRenderer3D
var hybrid_bridge: HybridBridge

# Componentes 3D originais (mantém sua funcionalidade)
var traffic_manager: DiscreteTrafficManager
var camera_controller: Node3D
var analytics: Control

# Estado do sistema
var is_hybrid_mode: bool = true
var visual_entities: Dictionary = {}  # car_id -> Node3D
var is_initialized: bool = false

# Configurações
var enable_visual_effects: bool = true
var enable_lod_optimization: bool = true
var max_concurrent_animations: int = 50

# Signals para comunicação
signal car_spawned_visually(car_id: int)
signal car_removed_visually(car_id: int)
signal traffic_light_synced(main_state: String, cross_state: String)
signal system_ready()

func _ready():
	print("🔗 Iniciando Sistema Híbrido: Eventos Discretos + Renderização 3D")
	
	# Aguardar frame para garantir que nós estejam prontos
	await get_tree().process_frame
	
	# 1. Criar o mundo 3D visual (usa código similar ao original)
	setup_3d_environment()
	
	# 2. Criar ponte de comunicação
	hybrid_bridge = HybridBridge.new()
	hybrid_bridge.name = "HybridBridge"
	add_child(hybrid_bridge)
	
	# 3. Criar renderizador visual
	visual_renderer = VisualRenderer3D.new()
	visual_renderer.name = "VisualRenderer3D"
	add_child(visual_renderer)
	
	# 4. Criar simulador discreto
	discrete_simulator = DiscreteTrafficSimulator.new()
	discrete_simulator.name = "HybridDiscreteSimulator"
	discrete_simulator.set_hybrid_mode(true)
	add_child(discrete_simulator)
	
	# 5. Configurar conexões
	await setup_connections()
	
	# 6. Conectar eventos
	connect_hybrid_events()
	
	await get_tree().process_frame
	
	# 7. Iniciar simulação
	start_hybrid_simulation()
	
	is_initialized = true
	system_ready.emit()
	print("✅ Sistema híbrido integrado e funcionando!")

func setup_3d_environment():
	"""Cria o mundo 3D usando as funções existentes adaptadas"""
	print("🌍 Configurando ambiente 3D híbrido...")
	
	# Criar sistema de coordenadas
	var world_center = Vector3.ZERO
	
	# Criar estrada principal (West-East)
	_create_main_road()
	
	# Criar estrada transversal (North-South)
	_create_cross_road()
	
	# Criar interseção
	_create_intersection()
	
	# Criar semáforos
	_create_traffic_lights()
	
	# Criar calçadas e ambiente
	_create_sidewalks_and_environment()
	
	# Configurar iluminação
	_setup_lighting()
	
	print("✅ Ambiente 3D criado para sistema híbrido")

func _create_main_road():
	"""Cria estrada principal (West-East)"""
	var road_main = CSGBox3D.new()
	road_main.name = "RoadMain"
	road_main.size = Vector3(70, 0.1, 5)
	road_main.position = Vector3(0, 0, 0)
	
	var road_material = StandardMaterial3D.new()
	road_material.albedo_color = Color(0.3, 0.3, 0.3)
	road_main.material_override = road_material
	
	add_child(road_main)

func _create_cross_road():
	"""Cria estrada transversal (North-South)"""
	var road_cross = CSGBox3D.new()
	road_cross.name = "RoadCross"
	road_cross.size = Vector3(5, 0.1, 70)
	road_cross.position = Vector3(0, 0, 0)
	
	var road_material = StandardMaterial3D.new()
	road_material.albedo_color = Color(0.3, 0.3, 0.3)
	road_cross.material_override = road_material
	
	add_child(road_cross)

func _create_intersection():
	"""Cria interseção central"""
	var intersection = CSGBox3D.new()
	intersection.name = "Intersection"
	intersection.size = Vector3(14, 0.05, 14)
	intersection.position = Vector3(0, 0.05, 0)
	
	var intersection_material = StandardMaterial3D.new()
	intersection_material.albedo_color = Color(0.25, 0.25, 0.25)
	intersection.material_override = intersection_material
	
	add_child(intersection)

func _create_traffic_lights():
	"""Cria semáforos do sistema híbrido"""
	# Semáforo West (Main Road)
	var light_west = _create_traffic_light_node("TrafficLight_main_road_west", Vector3(-10, 4, -3))
	add_child(light_west)
	
	# Semáforo East (Main Road)
	var light_east = _create_traffic_light_node("TrafficLight_main_road_east", Vector3(10, 4, 3))
	add_child(light_east)
	
	# Semáforo North (Cross Road)
	var light_north = _create_traffic_light_node("TrafficLight_cross_road_north", Vector3(-3, 4, -10))
	add_child(light_north)

func _create_traffic_light_node(light_name: String, position: Vector3) -> Node3D:
	"""Cria um nó de semáforo com todas as luzes"""
	var light_group = Node3D.new()
	light_group.name = light_name
	light_group.position = position
	
	# Poste do semáforo
	var pole = CSGCylinder3D.new()
	pole.height = 4.0
	pole.position = Vector3(0, -2, 0)
	
	# Material do poste
	var pole_material = StandardMaterial3D.new()
	pole_material.albedo_color = Color(0.4, 0.4, 0.4)
	pole.material_override = pole_material
	
	light_group.add_child(pole)
	
	# Luzes do semáforo
	var light_red = _create_light_sphere(Vector3(0, 0.5, 0), Color.RED, false)
	var light_yellow = _create_light_sphere(Vector3(0, 0, 0), Color.YELLOW, false)
	var light_green = _create_light_sphere(Vector3(0, -0.5, 0), Color.GREEN, true)  # Inicia verde
	
	light_red.name = "RedLight"
	light_yellow.name = "YellowLight"
	light_green.name = "GreenLight"
	
	light_group.add_child(light_red)
	light_group.add_child(light_yellow)
	light_group.add_child(light_green)
	
	# Adicionar script de controle do semáforo
	var script_path = "res://scripts/TrafficLight.gd"
	if ResourceLoader.exists(script_path):
		var traffic_light_script = load(script_path)
		light_group.set_script(traffic_light_script)
	
	return light_group

func _create_light_sphere(pos: Vector3, color: Color, is_active: bool) -> MeshInstance3D:
	"""Cria esfera de luz do semáforo"""
	var sphere = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 0.2
	mesh.height = 0.4
	sphere.mesh = mesh
	sphere.position = pos
	
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission = color if is_active else Color.BLACK
	material.emission_energy = 2.0 if is_active else 0.0
	sphere.material_override = material
	
	return sphere

func _create_sidewalks_and_environment():
	"""Cria calçadas e elementos do ambiente"""
	# Calçadas principais
	_create_sidewalk("SidewalkNorth", Vector3(0, 0, -15), Vector3(80, 0.2, 10))
	_create_sidewalk("SidewalkSouth", Vector3(0, 0, 15), Vector3(80, 0.2, 10))
	_create_sidewalk("SidewalkWest", Vector3(-15, 0, 0), Vector3(10, 0.2, 80))
	_create_sidewalk("SidewalkEast", Vector3(15, 0, 0), Vector3(10, 0.2, 80))
	
	# Grama ao fundo
	_create_grass_area()

func _create_sidewalk(name: String, pos: Vector3, size: Vector3):
	"""Cria uma calçada"""
	var sidewalk = CSGBox3D.new()
	sidewalk.name = name
	sidewalk.size = size
	sidewalk.position = pos
	
	var sidewalk_material = StandardMaterial3D.new()
	sidewalk_material.albedo_color = Color(0.7, 0.7, 0.8)
	sidewalk.material_override = sidewalk_material
	
	add_child(sidewalk)

func _create_grass_area():
	"""Cria áreas de grama"""
	var grass = CSGBox3D.new()
	grass.name = "Grass"
	grass.size = Vector3(200, 0.1, 200)
	grass.position = Vector3(0, -0.1, 0)
	
	var grass_material = StandardMaterial3D.new()
	grass_material.albedo_color = Color(0.2, 0.6, 0.2)
	grass.material_override = grass_material
	
	add_child(grass)

func _setup_lighting():
	"""Configura iluminação da cena"""
	# Sol/luz direcional
	var sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-45, 45, 0)
	sun.light_energy = 1.0
	add_child(sun)
	
	# Luz ambiente
	var environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.4, 0.4, 0.5)
	environment.ambient_light_energy = 0.3
	
	var world_env = get_viewport().world_3d.environment
	if not world_env:
		get_viewport().world_3d.environment = environment

func setup_connections():
	"""Configura conexões entre componentes"""
	print("🔌 Configurando conexões híbridas...")
	
	# Usar traffic_manager do discrete_simulator se disponível
	if discrete_simulator and discrete_simulator.traffic_manager:
		traffic_manager = discrete_simulator.traffic_manager
		print("✅ Using DiscreteTrafficManager from simulator")
	else:
		# Criar TrafficManager básico (RefCounted, não precisa de add_child)
		traffic_manager = _create_basic_traffic_manager()
		print("✅ Created basic traffic manager")
	
	# Encontrar componentes de câmera e analytics se existirem
	camera_controller = get_parent().get_node_or_null("CameraController")
	analytics = get_parent().get_node_or_null("Analytics")
	
	# Configurar ponte
	hybrid_bridge.setup_connections(self, traffic_manager)
	
	# Configurar renderizador
	visual_renderer.setup(self, hybrid_bridge)
	
	print("✅ Conexões configuradas")

func _create_basic_traffic_manager() -> DiscreteTrafficManager:
	"""Cria TrafficManager básico se não existir"""
	var simulation_clock = SimulationClock.new(0.0)
	var event_scheduler = DiscreteEventScheduler.new(simulation_clock)
	
	var tm = DiscreteTrafficManager.new(event_scheduler, simulation_clock, null)
	tm.name = "BasicDiscreteTrafficManager"
	
	return tm

func connect_hybrid_events():
	"""Conecta eventos do simulador discreto com ações visuais"""
	print("🔗 Conectando eventos híbridos...")
	
	# Conectar sinais do simulador discreto
	if discrete_simulator:
		# Verificar se sinais existem antes de conectar
		if discrete_simulator.has_signal("simulation_started"):
			discrete_simulator.simulation_started.connect(_on_simulation_started)
		if discrete_simulator.has_signal("stats_updated"):
			discrete_simulator.stats_updated.connect(_on_stats_updated)
		
		# Conectar através do event_scheduler
		if discrete_simulator.event_scheduler:
			if discrete_simulator.event_scheduler.has_signal("entity_created"):
				discrete_simulator.event_scheduler.entity_created.connect(_on_discrete_car_spawned)
			if discrete_simulator.event_scheduler.has_signal("entity_destroyed"):
				discrete_simulator.event_scheduler.entity_destroyed.connect(_on_discrete_car_removed)
	
	# Conectar sinais da ponte
	if hybrid_bridge and hybrid_bridge.has_signal("animation_completed"):
		hybrid_bridge.animation_completed.connect(_on_animation_completed)
	
	print("✅ Eventos conectados")

func start_hybrid_simulation():
	"""Inicia a simulação híbrida"""
	print("🏁 Iniciando simulação híbrida...")
	
	if discrete_simulator:
		discrete_simulator.start_simulation()
		print("✅ Simulador discreto iniciado")
	
	print("🏁 Simulação híbrida iniciada!")

# =================================================================
# CALLBACKS DOS EVENTOS DISCRETOS → AÇÕES VISUAIS
# =================================================================

func _on_discrete_car_spawned(car_id: int):
	"""Evento discreto: novo carro → criar entidade visual 3D"""
	var car_data = _get_car_data_from_discrete_simulator(car_id)
	if not car_data:
		print("⚠️ Car data not found for ID=%d" % car_id)
		return
	
	print("🚗 EVENTO HÍBRIDO: Spawning visual car ID=%d at %s" % [car_id, car_data.position])
	
	# Criar carro visual 3D
	var car_3d = _create_visual_car(car_data)
	if not car_3d:
		print("❌ Failed to create visual car ID=%d" % car_id)
		return
	
	add_child(car_3d)
	visual_entities[car_id] = car_3d
	
	# Animação de spawn
	if enable_visual_effects and hybrid_bridge:
		hybrid_bridge.animate_car_spawn(car_3d, car_data.position)
	
	# Registrar no traffic manager se necessário
	if traffic_manager and traffic_manager.has_method("register_car"):
		traffic_manager.register_car(car_3d)
	
	car_spawned_visually.emit(car_id)

func _on_discrete_car_removed(car_id: int):
	"""Evento discreto: carro saiu → remover entidade visual"""
	print("🗑️ EVENTO HÍBRIDO: Removing visual car ID=%d" % car_id)
	
	if car_id in visual_entities:
		var car_3d = visual_entities[car_id]
		
		# Desregistrar do traffic manager
		if traffic_manager and traffic_manager.has_method("unregister_car"):
			traffic_manager.unregister_car(car_3d)
		
		# Animação de despawn
		if enable_visual_effects and hybrid_bridge:
			hybrid_bridge.animate_car_despawn(car_3d, func(): _remove_car_completely(car_id))
		else:
			_remove_car_completely(car_id)
		
		car_removed_visually.emit(car_id)

func _remove_car_completely(car_id: int):
	"""Remove carro completamente após animação"""
	if car_id in visual_entities:
		var car_3d = visual_entities[car_id]
		car_3d.queue_free()
		visual_entities.erase(car_id)

func _get_car_data_from_discrete_simulator(car_id: int) -> Dictionary:
	"""Obtém dados do carro do simulador discreto"""
	if not discrete_simulator:
		return {}
	
	var car = discrete_simulator.get_active_car(car_id)
	if not car:
		return {}
	
	return {
		"id": car_id,
		"position": car.current_position,
		"direction": car.direction,
		"personality": car.personality,
		"rotation": _calculate_rotation_from_direction(car.direction)
	}

func _calculate_rotation_from_direction(direction) -> float:
	"""Calcula rotação Y baseada na direção"""
	match direction:
		0: return 0.0      # LEFT_TO_RIGHT
		1: return PI       # RIGHT_TO_LEFT
		3: return PI/2     # BOTTOM_TO_TOP
		_: return 0.0

func _create_visual_car(car_data: Dictionary) -> Node3D:
	"""Cria carro visual 3D"""
	# Tentar carregar cena de carro existente
	var car_scene_path = "res://scenes/Car.tscn"
	var car_3d: Node3D
	
	if ResourceLoader.exists(car_scene_path):
		var car_scene = load(car_scene_path)
		car_3d = car_scene.instantiate()
	else:
		# Criar carro placeholder
		car_3d = _create_placeholder_car()
	
	# Configurar propriedades
	car_3d.car_id = car_data.id
	car_3d.global_position = car_data.position
	car_3d.rotation.y = car_data.rotation
	
	# Configurar modo híbrido
	if car_3d.has_method("set_hybrid_mode"):
		car_3d.set_hybrid_mode(true)
	
	return car_3d

func _create_placeholder_car() -> Node3D:
	"""Cria carro placeholder se cena não existir"""
	var car_3d = CharacterBody3D.new()
	car_3d.name = "PlaceholderCar"
	
	# Mesh do carro
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(2.5, 1.0, 1.2)
	mesh_instance.mesh = box_mesh
	
	# Material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.BLUE
	mesh_instance.material_override = material
	
	car_3d.add_child(mesh_instance)
	
	# Collision shape
	var collision = CollisionShape3D.new()
	var collision_shape = BoxShape3D.new()
	collision_shape.size = Vector3(2.5, 1.0, 1.2)
	collision.shape = collision_shape
	car_3d.add_child(collision)
	
	# Adicionar propriedades básicas
	car_3d.car_id = 0
	
	return car_3d

func _on_simulation_started():
	"""Callback quando simulação inicia"""
	print("🏁 Sistema híbrido: Simulação iniciada")

func _on_stats_updated(stats: Dictionary):
	"""Callback quando estatísticas são atualizadas"""
	if analytics and analytics.has_method("update_display"):
		analytics.update_display(stats)

func _on_animation_completed(car_id: int):
	"""Callback quando animação é completada"""
	print("✅ Sistema híbrido: Animation completed for car %d" % car_id)

# =================================================================
# INTERFACE PÚBLICA
# =================================================================

func get_visual_car(car_id: int) -> Node3D:
	"""Retorna carro visual por ID"""
	return visual_entities.get(car_id)

func get_visual_car_count() -> int:
	"""Retorna número de carros visuais ativos"""
	return visual_entities.size()

func is_car_visual_active(car_id: int) -> bool:
	"""Verifica se carro visual está ativo"""
	return car_id in visual_entities

func force_sync_traffic_lights(main_state: String, cross_state: String):
	"""Força sincronização dos semáforos"""
	if hybrid_bridge:
		hybrid_bridge.force_sync_traffic_lights(main_state, cross_state)
	traffic_light_synced.emit(main_state, cross_state)

func get_system_stats() -> Dictionary:
	"""Retorna estatísticas do sistema híbrido"""
	var stats = {
		"is_initialized": is_initialized,
		"visual_cars": visual_entities.size(),
		"hybrid_mode": is_hybrid_mode,
		"visual_effects": enable_visual_effects,
		"lod_optimization": enable_lod_optimization
	}
	
	if discrete_simulator:
		stats["discrete_simulator"] = discrete_simulator.get_simulation_statistics()
	
	if visual_renderer:
		stats["visual_renderer"] = visual_renderer.get_rendering_stats()
	
	if hybrid_bridge:
		stats["hybrid_bridge"] = {
			"active_animations": hybrid_bridge.get_active_animations_count()
		}
	
	return stats

func get_debug_info() -> String:
	"""Informações debug do sistema híbrido"""
	return "HybridTrafficSystem: %d visual cars, initialized: %s" % [
		visual_entities.size(),
		"Yes" if is_initialized else "No"
	]
