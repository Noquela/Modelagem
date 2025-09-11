extends Node3D

# FEATURE 7: INTEGRAÇÃO COM BACKEND DISCRETO
# Visual igual ao traffic_simulator_3d original

var event_bus: Node
var discrete_simulation: Node
var traffic_lights = {}

func setup_backend_systems_deferred():
	print("🔧 Inicializando backend discreto...")
	
	# Criar todos os nós
	event_bus = preload("res://scripts/discrete/EventBus.gd").new()
	event_bus.name = "EventBus"
	get_tree().root.add_child(event_bus)
	
	var simulation_clock = preload("res://scripts/discrete/SimulationClock.gd").new()
	simulation_clock.name = "SimulationClock"
	get_tree().root.add_child(simulation_clock)
	
	var traffic_controller = preload("res://scripts/discrete/TrafficLightController.gd").new()
	traffic_controller.name = "TrafficLightController"
	get_tree().root.add_child(traffic_controller)
	
	var car_spawner = preload("res://scripts/discrete/CarSpawner.gd").new()
	car_spawner.name = "CarSpawner"
	get_tree().root.add_child(car_spawner)
	
	discrete_simulation = preload("res://scripts/discrete/DiscreteSimulation.gd").new()
	discrete_simulation.name = "DiscreteSimulation"
	get_tree().root.add_child(discrete_simulation)
	
	var traffic_analytics = preload("res://scripts/analytics/TrafficAnalytics.gd").new()
	traffic_analytics.name = "TrafficAnalytics"
	get_tree().root.add_child(traffic_analytics)
	
	# Conectar eventos
	connect_backend_events()
	
	# Aguardar e inicializar
	await get_tree().process_frame
	
	if discrete_simulation:
		discrete_simulation.initialize()
		discrete_simulation.start_simulation()
	
	print("✅ Backend discreto funcionando!")
	
	# Adicionar nova UI simples para o professor
	var simple_ui = preload("res://scripts/ui_nova/SimpleUI.gd").new()
	simple_ui.name = "SimpleUI"
	add_child(simple_ui)

func connect_backend_events():
	# Conectar eventos do backend com visual
	if event_bus:
		event_bus.subscribe("car_spawned", _on_car_spawned)
		event_bus.subscribe("car_position_updated", _on_car_position_updated)
		event_bus.subscribe("car_despawned", _on_car_despawned)
		event_bus.subscribe("traffic_light_changed", _on_traffic_light_changed)
		print("🔗 Eventos conectados!")

func _on_car_spawned(car_data):
	print("👁️ Visual recebeu spawn: ", car_data.id, " em ", car_data.position)
	
	# Criar carro visual
	var car_scene = preload("res://scripts/visual/Car.gd").new()
	car_scene.name = car_data.id
	add_child(car_scene)
	
	# Setup do carro com dados do spawn
	car_scene.setup_car(car_data.id, car_data.lane, car_data.position, car_data.direction)
	
	print("🚗 Carro visual criado: ", car_data.id, " na lane: ", car_data.lane)

func _on_traffic_light_changed(light_data):
	update_visual_traffic_light(light_data.light_id, light_data.state)
	print("👁️ Visual atualizou semáforo: ", light_data.light_id, " -> ", light_data.state)

func update_visual_traffic_light(light_id: String, state):
	# Mapear IDs para nós visuais
	var visual_mapping = {
		"light_1": "TrafficLight_main_road_west",
		"light_2": "TrafficLight_main_road_east", 
		"light_3": "TrafficLight_cross_road_north"
	}
	
	if not visual_mapping.has(light_id):
		print("❌ Light ID não encontrado: ", light_id)
		return
		
	var light_node = get_node_or_null(visual_mapping[light_id])
	if not light_node:
		print("❌ Nó do semáforo não encontrado: ", visual_mapping[light_id])
		return
	
	print("🔍 Procurando luzes em: ", light_node.name)
	
	# Buscar luzes na estrutura correta (red_bulb, yellow_bulb, green_bulb)
	var red_light = light_node.get_node_or_null("red_bulb")
	var yellow_light = light_node.get_node_or_null("yellow_bulb")
	var green_light = light_node.get_node_or_null("green_bulb")
	
	print("🔍 Luzes encontradas - Red: ", red_light != null, " Yellow: ", yellow_light != null, " Green: ", green_light != null)
	
	# Desligar todas as luzes primeiro (igual ao original linha 234-236)
	set_light_emission_original(red_light, false, Color.RED)
	set_light_emission_original(yellow_light, false, Color.YELLOW)
	set_light_emission_original(green_light, false, Color.GREEN)
	
	# Acender luz correspondente (igual ao original linha 238-247)
	match state:
		0: # RED
			set_light_emission_original(red_light, true, Color.RED)
			print("🔴 Semáforo VERMELHO ativado: ", light_id)
		1: # YELLOW
			set_light_emission_original(yellow_light, true, Color.YELLOW)
			print("🟡 Semáforo AMARELO ativado: ", light_id)
		2: # GREEN
			set_light_emission_original(green_light, true, Color.GREEN)
			print("🟢 Semáforo VERDE ativado: ", light_id)

func set_light_emission_original(light: Node3D, active: bool, base_color: Color):
	# IGUAL AO ORIGINAL set_light_emission() linha 176-212
	if not light:
		return
		
	var mesh_instance = light.get_child(0) as MeshInstance3D
	var omni_light = light.get_child(1) as OmniLight3D
	
	if mesh_instance and mesh_instance.material_override:
		var material = mesh_instance.material_override as StandardMaterial3D
		
		if active:
			# LUZ ATIVA - SUPER BRILHANTE E LUMINOSA (original linha 187-195)
			material.albedo_color = base_color * 1.2        # Cor mais saturada
			material.emission = base_color * 3.0            # Emissão muito forte
			material.emission_energy = 8.0                  # Energia máxima
			material.rim = 1.0                              # Rim lighting total
			material.rim_tint = 1.0                         # Rim tint máximo
			material.metallic = 0.3                         # Menos metálico quando aceso
			material.roughness = 0.1                        # Mais polido
		else:
			# LUZ INATIVA - MUITO ESCURA E OPACA (original linha 197-204)
			material.albedo_color = base_color * 0.15       # Muito escuro
			material.emission = Color.BLACK                 # Sem emissão
			material.emission_energy = 0.0                  # Energia zero
			material.rim = 0.0                              # Sem rim lighting
			material.rim_tint = 0.0                         # Sem rim tint
			material.metallic = 0.9                         # Muito metálico quando apagado
			material.roughness = 0.4                        # Mais fosco
	
	if omni_light:
		if active:
			omni_light.light_energy = 4.0     # Luz ambiente muito forte
			omni_light.omni_range = 12.0      # Range maior quando aceso
		else:
			omni_light.light_energy = 0.0     # Totalmente apagado
			omni_light.omni_range = 0.0       # Sem range

func _on_car_position_updated(car_data):
	# Atualizar posição do carro visual com MOVIMENTO SUAVE
	var car_node = get_node_or_null(car_data.id)
	if car_node:
		# Usar movimento suave ao invés de teletransporte
		car_node.set_target_position(car_data.position)
		# Atualizar estado de parado se necessário
		if car_data.has("stopped"):
			car_node.set_stopped(car_data.stopped)

func _on_car_despawned(car_data):
	# Remover carro visual quando despawna no sistema discreto
	var car_node = get_node_or_null(car_data.id)
	if car_node:
		print("🗑️ Removendo carro visual: ", car_data.id)
		car_node.queue_free()

func _input(event):
	if event.is_action_pressed("ui_pause"):
		if discrete_simulation:
			if discrete_simulation.is_running:
				discrete_simulation.pause_simulation()
			else:
				discrete_simulation.start_simulation()
	
	if event.is_action_pressed("ui_reset"):
		if discrete_simulation:
			discrete_simulation.reset_simulation()
	
	if event.is_action_pressed("ui_camera_mode"):
		var camera_controller = get_node_or_null("CameraController")
		if camera_controller and camera_controller.has_method("cycle_camera_mode"):
			camera_controller.cycle_camera_mode()

func _ready():
	print("🎮 Feature 7: Backend discreto + Visual 3D")
	setup_environment()
	call_deferred("setup_backend_systems_deferred")

func setup_environment():
	create_base_ground()
	create_intersection()
	create_perimeter_sidewalks()
	create_crosswalks()
	setup_traffic_lights()
	setup_lighting()
	print("✅ Feature 7 completa - Sistema híbrido funcional!")

func create_base_ground():
	# Chão igual ao original
	var ground = Node3D.new()
	ground.name = "BaseGround"
	
	var ground_mesh = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(80, 80)
	ground_mesh.mesh = plane_mesh
	
	var ground_material = StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.3, 0.5, 0.2)  # Verde grama
	ground_material.roughness = 0.8
	ground_material.metallic = 0.0
	ground_mesh.material_override = ground_material
	
	ground.position = Vector3(0, -0.5, 0)
	ground.add_child(ground_mesh)
	add_child(ground)
	print("  📦 Chão base criado")

func create_intersection():
	# Rua PRINCIPAL (horizontal/East-West)
	var road_main = create_road_segment(
		Vector3(-40, 0, 0), 
		Vector3(40, 0, 0), 
		10.0
	)
	road_main.name = "MainRoad_EastWest"
	add_child(road_main)
	
	# Rua TRANSVERSAL (vertical/North-South)
	var road_cross = create_road_segment(
		Vector3(0, 0, -40),
		Vector3(0, 0, 40), 
		6.0
	)
	road_cross.name = "CrossRoad_NorthSouth"
	add_child(road_cross)
	
	# FAIXAS AMARELAS
	create_yellow_lines()
	print("  🛣️ Estradas e faixas amarelas criadas")

func create_yellow_lines():
	# FAIXAS AMARELAS TRACEJADAS COMO NO ORIGINAL
	var line_material = StandardMaterial3D.new()
	line_material.albedo_color = Color.YELLOW
	line_material.emission = Color.YELLOW * 0.5  # Mais brilhante
	line_material.emission_energy = 2.0  # Mais energia para visibilidade
	
	# Linha central da rua horizontal (oeste-leste) - TRACEJADA
	for i in range(-36, 37, 4):  # De -36 a +36, espaçados de 4 em 4
		# PULAR onde há interseção (Z=±5 com margem para a rua transversal)
		if i >= -7 and i <= 7:
			continue  # Pular esta posição (há interseção)
			
		var line_mesh = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3(2.0, 0.15, 0.3)  # Segmentos pequenos
		line_mesh.mesh = box_mesh
		line_mesh.position = Vector3(i, 0.25, 0)  # Altura para ficar sobre o asfalto
		line_mesh.material_override = line_material
		line_mesh.name = "YellowLane_H_" + str(i)
		add_child(line_mesh)
	
	# Não fazer linhas na rua de mão única (como no HTML original)


func create_road_segment(start: Vector3, end: Vector3, width: float) -> Node3D:
	var road = Node3D.new()
	road.name = "Road"
	
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	
	var length = (end - start).length()
	if start.x != end.x:  # East-West road
		box_mesh.size = Vector3(length, 0.2, width)
	else:  # North-South road
		box_mesh.size = Vector3(width, 0.2, length)
	
	mesh_instance.mesh = box_mesh
	road.position = (start + end) / 2
	
	# Material asfalto COM TEXTURA como no original
	var material = StandardMaterial3D.new()
	
	# Tentar carregar textura de asfalto
	var diffuse_texture = load("res://assets/textures/roads/asphalt_02_diff_2k.jpg")
	
	if diffuse_texture:
		material.albedo_texture = diffuse_texture
		material.albedo_color = Color.WHITE
		material.roughness = 0.8
		
		# UV scaling baseado no tamanho real da textura
		if start.x != end.x:  # East-West road (horizontal)
			var road_length = (end - start).length()
			material.uv1_scale = Vector3(road_length/3.0, width/3.0, 1.0)
		else:  # North-South road (vertical)
			var road_length = (end - start).length()
			material.uv1_scale = Vector3(width/3.0, road_length/3.0, 1.0)
	else:
		# Fallback para cor sólida se textura não carregar
		material.albedo_color = Color(0.25, 0.25, 0.28)  # Cinza asfalto
		material.roughness = 0.8
	
	material.metallic = 0.0
	mesh_instance.material_override = material
	
	road.add_child(mesh_instance)
	return road

func setup_lighting():
	# Luz principal
	var sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.position = Vector3(20, 25, 15)
	sun.rotation_degrees = Vector3(-35, -45, 0)
	sun.light_energy = 1.5
	sun.light_color = Color(1.0, 0.95, 0.8)
	sun.shadow_enabled = false
	add_child(sun)
	
	# CameraController IGUAL ao traffic_simulator_3d original
	var camera_controller = preload("res://scripts/visual/CameraController.gd").new()
	camera_controller.name = "CameraController"
	
	# Criar câmera dentro do controller
	var camera = Camera3D.new()
	camera.name = "Camera3D"
	camera_controller.add_child(camera)
	
	add_child(camera_controller)
	print("  💡 Iluminação e CameraController criados")

func create_perimeter_sidewalks():
	# Calçadas EXATAMENTE como no original
	var road_main_width = 10.0   # Rua principal leste-oeste
	var road_cross_width = 6.0   # Rua transversal norte-sul
	var map_limit = 40.0         # Limites do mapa (-40 a +40)
	var sidewalk_width = 2.0     # Largura de 2m
	var sidewalk_height = 0.15   # Altura padrão
	
	# Material COM TEXTURA para calçadas como no original
	var sidewalk_material_horizontal = StandardMaterial3D.new()
	var sidewalk_material_vertical = StandardMaterial3D.new()
	
	# Tentar carregar texturas de calçada
	var floor_texture = load("res://assets/textures/sidewalks/floor_pattern_02_diff_2k.jpg")
	var floor_normal = load("res://assets/textures/sidewalks/floor_pattern_02_nor_gl_2k.jpg")
	var floor_roughness = load("res://assets/textures/sidewalks/floor_pattern_02_rough_2k.jpg")
	
	if floor_texture:
		print("✅ Texturas de calçada carregadas!")
		
		# Material HORIZONTAL (Leste-Oeste)
		sidewalk_material_horizontal.albedo_texture = floor_texture
		sidewalk_material_horizontal.albedo_color = Color.WHITE
		if floor_normal:
			sidewalk_material_horizontal.normal_texture = floor_normal
			sidewalk_material_horizontal.normal_enabled = true
		if floor_roughness:
			sidewalk_material_horizontal.roughness_texture = floor_roughness
		else:
			sidewalk_material_horizontal.roughness = 0.7
		sidewalk_material_horizontal.metallic = 0.0
		sidewalk_material_horizontal.uv1_scale = Vector3(15.0, 2.0, 1.0)
		
		# Material VERTICAL (Norte-Sul) - UV rotacionado 90°
		sidewalk_material_vertical.albedo_texture = floor_texture
		sidewalk_material_vertical.albedo_color = Color.WHITE
		if floor_normal:
			sidewalk_material_vertical.normal_texture = floor_normal
			sidewalk_material_vertical.normal_enabled = true
		if floor_roughness:
			sidewalk_material_vertical.roughness_texture = floor_roughness
		else:
			sidewalk_material_vertical.roughness = 0.7
		sidewalk_material_vertical.metallic = 0.0
		sidewalk_material_vertical.uv1_scale = Vector3(2.0, 15.0, 1.0)  # Invertido para rotação
		sidewalk_material_vertical.uv1_offset = Vector3(0.25, 0.25, 0.0)
	else:
		print("⚠️ Texturas de calçada não encontradas, usando fallback")
		sidewalk_material_horizontal.albedo_color = Color(0.4, 0.4, 0.4)
		sidewalk_material_horizontal.roughness = 0.6
		sidewalk_material_horizontal.metallic = 0.0
		
		sidewalk_material_vertical.albedo_color = Color(0.4, 0.4, 0.4)
		sidewalk_material_vertical.roughness = 0.6
		sidewalk_material_vertical.metallic = 0.0
	
	# CALÇADAS LESTE - divididas pela rua principal
	# Parte NORTE
	var sidewalk_east_north = MeshInstance3D.new()
	var mesh_east_north = BoxMesh.new()
	var vertical_length = map_limit - road_main_width/2
	mesh_east_north.size = Vector3(sidewalk_width, sidewalk_height, vertical_length)
	sidewalk_east_north.mesh = mesh_east_north
	sidewalk_east_north.position = Vector3(road_cross_width/2 + sidewalk_width/2, sidewalk_height/2, road_main_width/2 + vertical_length/2)
	sidewalk_east_north.material_override = sidewalk_material_vertical  # Calçada vertical
	sidewalk_east_north.name = "Sidewalk_East_North"
	add_child(sidewalk_east_north)
	
	# Parte SUL
	var sidewalk_east_south = MeshInstance3D.new()
	var mesh_east_south = BoxMesh.new()
	mesh_east_south.size = Vector3(sidewalk_width, sidewalk_height, vertical_length)
	sidewalk_east_south.mesh = mesh_east_south
	sidewalk_east_south.position = Vector3(road_cross_width/2 + sidewalk_width/2, sidewalk_height/2, -(road_main_width/2 + vertical_length/2))
	sidewalk_east_south.material_override = sidewalk_material_vertical  # Calçada vertical
	sidewalk_east_south.name = "Sidewalk_East_South"
	add_child(sidewalk_east_south)
	
	# CALÇADAS OESTE - divididas pela rua principal
	# Parte NORTE
	var sidewalk_west_north = MeshInstance3D.new()
	var mesh_west_north = BoxMesh.new()
	mesh_west_north.size = Vector3(sidewalk_width, sidewalk_height, vertical_length)
	sidewalk_west_north.mesh = mesh_west_north
	sidewalk_west_north.position = Vector3(-(road_cross_width/2 + sidewalk_width/2), sidewalk_height/2, road_main_width/2 + vertical_length/2)
	sidewalk_west_north.material_override = sidewalk_material_vertical  # Calçada vertical
	sidewalk_west_north.name = "Sidewalk_West_North"
	add_child(sidewalk_west_north)
	
	# Parte SUL
	var sidewalk_west_south = MeshInstance3D.new()
	var mesh_west_south = BoxMesh.new()
	mesh_west_south.size = Vector3(sidewalk_width, sidewalk_height, vertical_length)
	sidewalk_west_south.mesh = mesh_west_south
	sidewalk_west_south.position = Vector3(-(road_cross_width/2 + sidewalk_width/2), sidewalk_height/2, -(road_main_width/2 + vertical_length/2))
	sidewalk_west_south.material_override = sidewalk_material_vertical  # Calçada vertical
	sidewalk_west_south.name = "Sidewalk_West_South"
	add_child(sidewalk_west_south)
	
	# CALÇADAS NORTE - divididas pela rua transversal
	# Parte OESTE
	var sidewalk_north_west = MeshInstance3D.new()
	var mesh_north_west = BoxMesh.new()
	var west_length = map_limit - road_cross_width/2
	mesh_north_west.size = Vector3(west_length, sidewalk_height, sidewalk_width)
	sidewalk_north_west.mesh = mesh_north_west
	sidewalk_north_west.position = Vector3(-(road_cross_width/2 + west_length/2), sidewalk_height/2, road_main_width/2 + sidewalk_width/2)
	sidewalk_north_west.material_override = sidewalk_material_horizontal  # Calçada horizontal
	sidewalk_north_west.name = "Sidewalk_North_West"
	add_child(sidewalk_north_west)
	
	# Parte LESTE
	var sidewalk_north_east = MeshInstance3D.new()
	var mesh_north_east = BoxMesh.new()
	var east_length = map_limit - road_cross_width/2
	mesh_north_east.size = Vector3(east_length, sidewalk_height, sidewalk_width)
	sidewalk_north_east.mesh = mesh_north_east
	sidewalk_north_east.position = Vector3(road_cross_width/2 + east_length/2, sidewalk_height/2, road_main_width/2 + sidewalk_width/2)
	sidewalk_north_east.material_override = sidewalk_material_horizontal  # Calçada horizontal
	sidewalk_north_east.name = "Sidewalk_North_East"
	add_child(sidewalk_north_east)
	
	# CALÇADAS SUL - divididas pela rua transversal
	# Parte OESTE
	var sidewalk_south_west = MeshInstance3D.new()
	var mesh_south_west = BoxMesh.new()
	mesh_south_west.size = Vector3(west_length, sidewalk_height, sidewalk_width)
	sidewalk_south_west.mesh = mesh_south_west
	sidewalk_south_west.position = Vector3(-(road_cross_width/2 + west_length/2), sidewalk_height/2, -(road_main_width/2 + sidewalk_width/2))
	sidewalk_south_west.material_override = sidewalk_material_horizontal  # Calçada horizontal
	sidewalk_south_west.name = "Sidewalk_South_West"
	add_child(sidewalk_south_west)
	
	# Parte LESTE
	var sidewalk_south_east = MeshInstance3D.new()
	var mesh_south_east = BoxMesh.new()
	mesh_south_east.size = Vector3(east_length, sidewalk_height, sidewalk_width)
	sidewalk_south_east.mesh = mesh_south_east
	sidewalk_south_east.position = Vector3(road_cross_width/2 + east_length/2, sidewalk_height/2, -(road_main_width/2 + sidewalk_width/2))
	sidewalk_south_east.material_override = sidewalk_material_horizontal  # Calçada horizontal
	sidewalk_south_east.name = "Sidewalk_South_East"
	add_child(sidewalk_south_east)
	
	print("  🚶 Calçadas criadas")

func create_crosswalks():
	# Faixas de pedestres EXATAMENTE como no original
	var road_main_width = 10.0  # Rua principal leste-oeste 
	var road_cross_width = 6.0  # Rua transversal norte-sul
	var crosswalk_width = 3.0   # Largura da faixa
	
	# FAIXAS NORTE/SUL atravessam a RUA LESTE-OESTE
	create_zebra_crossing(
		Vector3(-5.0, 0.05, 0),      # Norte - longe da interseção
		road_main_width,             # 10m de largura
		crosswalk_width,             
		"vertical",                  # Listras verticais
		"North_Crosswalk"
	)
	
	create_zebra_crossing(
		Vector3(5.0, 0.05, 0),       # Sul - longe da interseção
		road_main_width,             # 10m de largura
		crosswalk_width,             
		"vertical",                  # Listras verticais
		"South_Crosswalk"
	)
	
	# FAIXAS LESTE/OESTE atravessam a RUA NORTE-SUL
	create_zebra_crossing(
		Vector3(0, 0.05, -7.0),      # Oeste - longe da interseção
		road_cross_width,            # 6m de largura
		crosswalk_width,             
		"horizontal",                # Listras horizontais
		"West_Crosswalk"
	)
	
	create_zebra_crossing(
		Vector3(0, 0.05, 7.0),       # Leste - longe da interseção
		road_cross_width,            # 6m de largura
		crosswalk_width,             
		"horizontal",                # Listras horizontais
		"East_Crosswalk"
	)
	
	print("  🚶‍♂️ Faixas de pedestres criadas")

func create_zebra_crossing(center_pos: Vector3, road_width: float, crosswalk_width: float, orientation: String, crosswalk_name: String):
	# Material SUPER VISÍVEL para listras brancas
	var white_material = StandardMaterial3D.new()
	white_material.albedo_color = Color.WHITE
	white_material.emission = Color.WHITE * 0.8
	white_material.emission_energy = 3.0
	white_material.metallic = 0.0
	white_material.roughness = 0.1
	
	# Parâmetros da faixa zebra
	var stripe_width = 0.4          # 40cm por listra
	var stripe_spacing = 0.4        # 40cm de espaço entre listras  
	var stripe_height = 0.08        # 8cm de altura
	var total_cycle = stripe_width + stripe_spacing
	
	# Calcular quantas listras cabem
	var stripe_count = int(road_width / total_cycle) - 1
	var start_position = -(road_width / 2.0) + (stripe_width / 2.0) + total_cycle
	
	# Container para organizar a faixa
	var crosswalk_container = Node3D.new()
	crosswalk_container.name = crosswalk_name
	crosswalk_container.position = center_pos
	add_child(crosswalk_container)
	
	# Criar cada listra branca
	for i in range(stripe_count):
		var stripe = MeshInstance3D.new()
		var stripe_mesh = BoxMesh.new()
		
		if orientation == "horizontal":
			# Listras horizontais (atravessam rua norte-sul)
			stripe_mesh.size = Vector3(stripe_width, stripe_height, crosswalk_width)
			stripe.position = Vector3(start_position + (i * total_cycle), stripe_height/2 + 0.1, 0)
		else:  # vertical
			# Listras verticais (atravessam rua leste-oeste)
			stripe_mesh.size = Vector3(crosswalk_width, stripe_height, stripe_width)
			stripe.position = Vector3(0, stripe_height/2 + 0.1, start_position + (i * total_cycle))
		
		stripe.mesh = stripe_mesh
		stripe.material_override = white_material
		stripe.name = crosswalk_name + "_Stripe_" + str(i)
		crosswalk_container.add_child(stripe)

func setup_traffic_lights():
	# APENAS 3 SEMÁFOROS com POSIÇÕES EXATAS DO ORIGINAL:
	
	# Semáforo 1: Rua principal - lado esquerdo 
	create_traffic_light(Vector3(-5, 0, 5), 90, "main_road_west", "S1")
	
	# Semáforo 2: Rua principal - lado direito
	create_traffic_light(Vector3(5, 0, -5), -90, "main_road_east", "S2")
	
	# Semáforo 3: Rua de mão única
	create_traffic_light(Vector3(-5, 0, -5), 0, "cross_road_north", "S3")
	
	print("  🚦 Semáforos criados")

func create_traffic_light(pos: Vector3, rotation_y: float, direction: String, label: String = "") -> Node3D:
	# ESTRUTURA EXATA DO ORIGINAL - traffic_simulator_3d/scripts/TrafficLight.gd
	var light_container = Node3D.new()
	light_container.name = "TrafficLight_" + direction
	light_container.position = pos
	light_container.rotation_degrees.y = rotation_y
	
	# Poste principal (igual ao original linha 42-54)
	var pole_mesh = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.1
	cylinder.bottom_radius = 0.1
	cylinder.height = 4.0
	pole_mesh.mesh = cylinder
	pole_mesh.position.y = 2.0
	
	var pole_material = StandardMaterial3D.new()
	pole_material.albedo_color = Color(0.4, 0.4, 0.4)  # HTML: 0x666666
	pole_mesh.material_override = pole_material
	light_container.add_child(pole_mesh)
	
	# Haste horizontal que se estende para a rua (original linha 56-66)
	var arm_mesh = MeshInstance3D.new()
	var arm_cylinder = CylinderMesh.new()
	arm_cylinder.top_radius = 0.05
	arm_cylinder.bottom_radius = 0.05
	arm_cylinder.height = 3.0
	arm_mesh.mesh = arm_cylinder
	arm_mesh.rotation_degrees.z = 90  # HTML: arm.rotation.z = Math.PI / 2
	arm_mesh.position = Vector3(1.5, 4.0, 0)  # HTML: arm.position.set(1.5, 4, 0)
	arm_mesh.material_override = pole_material
	light_container.add_child(arm_mesh)
	
	# Caixa do semáforo na ponta da haste (original linha 68-78)
	var housing = MeshInstance3D.new()
	var housing_mesh = BoxMesh.new()
	housing_mesh.size = Vector3(0.6, 1.8, 0.3)  # HTML: BoxGeometry(0.6, 1.8, 0.3)
	housing.mesh = housing_mesh
	housing.position = Vector3(3.0, 4.0, 0)  # HTML: box.position.set(3, 4, 0)
	
	var housing_material = StandardMaterial3D.new()
	housing_material.albedo_color = Color(0.2, 0.2, 0.2)  # HTML: 0x333333
	housing.material_override = housing_material
	light_container.add_child(housing)
	
	# Luzes na ponta da haste (original linha 81-90)
	var red_light = create_traffic_light_bulb_original(Vector3(3.0, 4.5, 0.15), Color.RED, "red")
	var yellow_light = create_traffic_light_bulb_original(Vector3(3.0, 4.0, 0.15), Color.YELLOW, "yellow")
	var green_light = create_traffic_light_bulb_original(Vector3(3.0, 3.5, 0.15), Color.GREEN, "green")
	
	light_container.add_child(red_light)
	light_container.add_child(yellow_light)
	light_container.add_child(green_light)
	
	# Label do semáforo
	if label != "":
		create_traffic_light_label(light_container, Vector3(3.0, 5.5, 0), label)
	
	add_child(light_container)
	return light_container

func create_traffic_light_bulb_original(pos: Vector3, color: Color, bulb_name: String) -> Node3D:
	# IGUAL AO ORIGINAL create_light() linha 92-124
	var light_node = Node3D.new()
	light_node.position = pos
	light_node.name = bulb_name + "_bulb"
	
	# Light mesh - BOLA OVAL (elipsoide) em vez de esfera (original linha 96-101)
	var mesh_instance = MeshInstance3D.new()
	var ellipsoid = SphereMesh.new()
	ellipsoid.radius = 0.18  # Maior
	ellipsoid.height = 0.24  # Mais alta que larga = formato oval
	mesh_instance.mesh = ellipsoid
	
	# Light material - COMEÇAR ESCURO (original linha 103-112)
	var material = StandardMaterial3D.new()
	material.albedo_color = color * 0.15  # Começar bem escuro (original linha 198)
	material.emission = Color.BLACK      # Sem emissão inicialmente
	material.emission_energy = 0.0       # Sem energia
	material.rim = 0.0
	material.rim_tint = 0.0
	material.metallic = 0.9              # Muito metálico quando apagado (original linha 203)
	material.roughness = 0.4             # Mais fosco (original linha 204)
	mesh_instance.material_override = material
	
	# Actual light source - COMEÇAR DESLIGADO (original linha 114-119)
	var omni_light = OmniLight3D.new()
	omni_light.light_color = color
	omni_light.light_energy = 0.0        # Começar desligado
	omni_light.omni_range = 0.0          # Sem range inicialmente
	omni_light.omni_attenuation = 0.7    # Atenuação suave
	
	light_node.add_child(mesh_instance)
	light_node.add_child(omni_light)
	
	return light_node

func create_traffic_light_label(parent: Node3D, pos: Vector3, label_text: String):
	var text_mesh_instance = MeshInstance3D.new()
	var text_mesh = TextMesh.new()
	text_mesh.text = label_text
	text_mesh.font_size = 80
	text_mesh.depth = 0.1
	text_mesh_instance.mesh = text_mesh
	text_mesh_instance.position = pos
	
	var text_material = StandardMaterial3D.new()
	text_material.albedo_color = Color.WHITE
	text_material.emission = Color.WHITE * 0.8
	text_material.emission_energy = 3.0
	text_material.flags_unshaded = true
	text_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	text_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	text_mesh_instance.material_override = text_material
	
	parent.add_child(text_mesh_instance)