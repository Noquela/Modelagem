extends Node3D

# MAIN LIMPO - APENAS MUNDO VISUAL
# Discrete events serão adicionados aos poucos conforme MASTER_PLAN.md

@onready var traffic_manager = $TrafficManager
@onready var camera_controller = $CameraController
@onready var spawn_system = $SpawnSystem      # STUB temporário
@onready var analytics = $Analytics          # STUB temporário

# Variáveis que serão adicionadas aos poucos
# var discrete_traffic_simulator: DiscreteTrafficSimulator  # FASE 3
# var discrete_ui: DiscreteUI                               # FASE 5

func _ready():
	print("🌍 Main iniciando - APENAS mundo visual (por enquanto)")
	
	# FASE 1-2: Apenas mundo visual
	setup_environment()
	setup_traffic_lights()
	
	print("✅ Mundo visual criado - discrete events virão depois")

func _input(event):
	if event.is_action_pressed("ui_pause"):
		toggle_pause()
	elif event.is_action_pressed("ui_camera_mode"):
		camera_controller.cycle_camera_mode()

func toggle_pause():
	# Por enquanto, apenas print
	print("⏸️ Pause pressionado (discrete events virão depois)")

func setup_environment():
	# Manter toda a lógica de ambiente 3D existente
	create_base_ground()
	create_intersection()
	setup_lighting()

func setup_traffic_lights():
	# Manter lógica de semáforos 3D
	# Semáforo 1: Rua principal - lado esquerdo
	create_traffic_light(Vector3(-5, 0, 5), 90, "main_road_west", "S1")
	
	# Semáforo 2: Rua principal - lado direito  
	create_traffic_light(Vector3(5, 0, -5), -90, "main_road_east", "S2")
	
	# Semáforo 3: Rua de mão única
	create_traffic_light(Vector3(-5, 0, -5), 0, "cross_road_north", "S3")

# Manter todas as funções de criação do mundo 3D...
# (copiando as principais para não quebrar)

func create_base_ground():
	var ground = Node3D.new()
	ground.name = "BaseGround"
	
	var ground_mesh = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(80, 80)
	ground_mesh.mesh = plane_mesh
	
	var ground_material = StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.3, 0.5, 0.2)
	ground_material.roughness = 0.8
	ground_material.metallic = 0.0
	ground_mesh.material_override = ground_material
	
	ground.position = Vector3(0, -0.5, 0)
	ground.add_child(ground_mesh)
	add_child(ground)
	
	print("Base ground created")

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
	
	# Calçadas (igual ao simulator 3D)
	create_perimeter_sidewalks()
	
	# Faixas de pedestres
	create_crosswalks()
	
	# Linhas amarelas
	create_lane_markings()
	
	print("Roads, sidewalks and crosswalks created")

func create_road_segment(start: Vector3, end: Vector3, width: float) -> Node3D:
	var road = Node3D.new()
	road.name = "Road"
	
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	
	var length = (end - start).length()
	if start.x != end.x:
		box_mesh.size = Vector3(length, 0.2, width)
	else:
		box_mesh.size = Vector3(width, 0.2, length)
	
	mesh_instance.mesh = box_mesh
	road.position = (start + end) / 2
	
	# USAR TEXTURAS DO SIMULATOR 3D ORIGINAL
	var material = StandardMaterial3D.new()
	
	# Carregar textura de asfalto do simulator 3D
	var diffuse_texture = load("res://assets/textures/roads/asphalt_02_diff_2k.jpg")
	
	if diffuse_texture:
		material.albedo_texture = diffuse_texture
		material.albedo_color = Color.WHITE
		material.roughness = 0.8
		
		# UV scaling baseado no tamanho (igual ao simulator 3D)
		if start.x != end.x:  # East-West road
			var road_length = (end - start).length()
			material.uv1_scale = Vector3(road_length/3.0, width/3.0, 1.0)
		else:  # North-South road
			var road_length = (end - start).length()
			material.uv1_scale = Vector3(width/3.0, road_length/3.0, 1.0)
	else:
		# Fallback caso textura não carregue
		material.albedo_color = Color(0.25, 0.25, 0.28)
		material.roughness = 0.8
	
	material.metallic = 0.0
	mesh_instance.material_override = material
	
	road.add_child(mesh_instance)
	return road

func setup_lighting():
	var sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.position = Vector3(20, 25, 15)
	sun.rotation_degrees = Vector3(-35, -45, 0)
	sun.light_energy = 1.5
	sun.light_color = Color(1.0, 0.95, 0.8)
	sun.shadow_enabled = false
	add_child(sun)
	
	print("Lighting setup")

func create_traffic_light(pos: Vector3, rotation_y: float, direction: String, label: String = "") -> Node3D:
	var light_scene = preload("res://scenes/TrafficLight.tscn")
	var light = light_scene.instantiate()
	light.name = "TrafficLight_" + direction
	light.position = pos
	light.rotation_degrees.y = rotation_y
	add_child(light)
	
	# Por enquanto não conecta com traffic_manager (virá depois)
	print("Traffic light created: %s" % direction)
	return light

# ========== FUNÇÕES DE MUNDO VISUAL (COPIADAS DO SIMULATOR 3D) ==========

func create_perimeter_sidewalks():
	"""Cria calçadas usando texturas do simulator 3D"""
	print("Creating sidewalks with original textures...")
	
	# Carregar texturas do simulator 3D
	var floor_texture = load("res://assets/textures/sidewalks/floor_pattern_02_diff_2k.jpg")
	var floor_normal = load("res://assets/textures/sidewalks/floor_pattern_02_nor_gl_2k.jpg")  
	var floor_roughness = load("res://assets/textures/sidewalks/floor_pattern_02_rough_2k.jpg")
	
	# Material para calçadas
	var sidewalk_material = StandardMaterial3D.new()
	if floor_texture:
		sidewalk_material.albedo_texture = floor_texture
		sidewalk_material.albedo_color = Color.WHITE
		if floor_normal:
			sidewalk_material.normal_texture = floor_normal
			sidewalk_material.normal_enabled = true
		if floor_roughness:
			sidewalk_material.roughness_texture = floor_roughness
		else:
			sidewalk_material.roughness = 0.7
		sidewalk_material.metallic = 0.0
		sidewalk_material.uv1_scale = Vector3(15.0, 2.0, 1.0)
	else:
		sidewalk_material.albedo_color = Color(0.4, 0.4, 0.4)
		sidewalk_material.roughness = 0.6
		sidewalk_material.metallic = 0.0
	
	# Criar calçadas principais (simplificado)
	var sidewalk_positions = [
		{"pos": Vector3(-7, 0.1, 0), "size": Vector3(2, 0.15, 70)},  # Oeste
		{"pos": Vector3(7, 0.1, 0), "size": Vector3(2, 0.15, 70)},   # Leste  
		{"pos": Vector3(0, 0.1, -7), "size": Vector3(70, 0.15, 2)},  # Norte
		{"pos": Vector3(0, 0.1, 7), "size": Vector3(70, 0.15, 2)}    # Sul
	]
	
	for i in range(sidewalk_positions.size()):
		var sidewalk_data = sidewalk_positions[i]
		var sidewalk = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		mesh.size = sidewalk_data.size
		sidewalk.mesh = mesh
		sidewalk.position = sidewalk_data.pos
		sidewalk.material_override = sidewalk_material
		sidewalk.name = "Sidewalk_" + str(i)
		add_child(sidewalk)

func create_crosswalks():
	"""Cria faixas de pedestres zebradas"""
	print("Creating crosswalks...")
	
	var white_material = StandardMaterial3D.new()
	white_material.albedo_color = Color.WHITE
	white_material.emission = Color.WHITE * 0.8
	white_material.emission_energy = 3.0
	white_material.metallic = 0.0
	white_material.roughness = 0.1
	
	# Faixas simplificadas
	var crosswalks = [
		{"pos": Vector3(-5, 0.05, 0), "size": Vector3(3, 0.08, 10), "name": "Crosswalk_West"},
		{"pos": Vector3(5, 0.05, 0), "size": Vector3(3, 0.08, 10), "name": "Crosswalk_East"},
		{"pos": Vector3(0, 0.05, -7), "size": Vector3(6, 0.08, 3), "name": "Crosswalk_North"},
		{"pos": Vector3(0, 0.05, 7), "size": Vector3(6, 0.08, 3), "name": "Crosswalk_South"}
	]
	
	for crosswalk_data in crosswalks:
		# Criar listras da zebra
		for stripe in range(3):
			var stripe_mesh = MeshInstance3D.new()
			var mesh = BoxMesh.new()
			mesh.size = Vector3(crosswalk_data.size.x * 0.8, crosswalk_data.size.y, crosswalk_data.size.z * 0.2)
			stripe_mesh.mesh = mesh
			stripe_mesh.position = crosswalk_data.pos + Vector3(0, 0, (stripe - 1) * crosswalk_data.size.z * 0.3)
			stripe_mesh.material_override = white_material
			stripe_mesh.name = crosswalk_data.name + "_Stripe_" + str(stripe)
			add_child(stripe_mesh)

func create_lane_markings():
	"""Cria linhas amarelas divisórias"""
	print("Creating lane markings...")
	
	var yellow_material = StandardMaterial3D.new()
	yellow_material.albedo_color = Color.YELLOW
	yellow_material.emission = Color.YELLOW * 0.5
	yellow_material.emission_energy = 2.0
	
	# Linha central da rua horizontal (tracejada)
	for i in range(-15, 16, 4):
		var line_mesh = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3(2.0, 0.15, 0.3)
		line_mesh.mesh = box_mesh
		line_mesh.position = Vector3(i, 0.25, 0)
		line_mesh.material_override = yellow_material
		line_mesh.name = "YellowLine_" + str(i)
		add_child(line_mesh)
