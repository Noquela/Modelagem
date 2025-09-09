extends Node3D

# WORLD VISUAL EXATAMENTE IGUAL AO TRAFFIC_SIMULATOR_3D
# Apenas com stubs temporários para discrete events

@onready var traffic_manager = $TrafficManager
@onready var camera_controller = $CameraController
@onready var spawn_system = $SpawnSystem      # STUB temporário
@onready var analytics = $Analytics          # STUB temporário

# DISCRETE EVENTS SYSTEM (FASE 5)
@onready var discrete_simulator = $DiscreteTrafficSimulator

var is_running: bool = true

func _ready():
	print("🌍 Main iniciando - mundo visual 100% igual ao traffic_simulator_3d")
	setup_environment()
	connect_signals()
	
	# Aguardar alguns frames antes de inicializar sistemas complexos
	await get_tree().process_frame
	await get_tree().process_frame
	
	# IMPORTANTE: Criar semáforos APÓS sistemas discretos serem inicializados
	setup_traffic_lights()
	
	# Inicializar sistema discreto após mundo visual e semáforos
	if discrete_simulator:
		print("🎮 Iniciando sistema de eventos discretos...")
		discrete_simulator.start_simulation()
	
	print("✅ Mundo visual 3D criado + Sistema discreto iniciado!")

func _process(_delta):
	pass

func _input(event):
	if event.is_action_pressed("ui_pause"):
		toggle_pause()
	elif event.is_action_pressed("ui_camera_mode"):
		camera_controller.cycle_camera_mode()

func setup_environment():
	# Create base ground first
	create_base_ground()
	# Create intersection geometry
	create_intersection()
	setup_lighting()
	# Prédios removidos - mapa sem obstáculos
	# create_urban_environment()  # DESATIVADO

func create_base_ground():
	# Create a large ground plane for the entire area
	var ground = Node3D.new()
	ground.name = "BaseGround"
	
	var ground_mesh = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(80, 80)  # Mapa reduzido para apenas um pouco além das ruas
	ground_mesh.mesh = plane_mesh
	
	# Ground material (grass/dirt)
	var ground_material = StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.3, 0.5, 0.2)  # Grass green
	ground_material.roughness = 0.8
	ground_material.metallic = 0.0
	ground_mesh.material_override = ground_material
	
	# Position ground slightly below roads
	ground.position = Vector3(0, -0.5, 0)
	ground.add_child(ground_mesh)
	add_child(ground)
	
	print("Base ground created")

func create_intersection():
	# RUAS ESTENDIDAS ATÉ O FINAL DO MAPA:
	# Rua PRINCIPAL (horizontal/East-West) - ATÉ O FINAL
	var road_main = create_road_segment(
		Vector3(-40, 0, 0), 
		Vector3(40, 0, 0), 
		10.0  # Largura mantida
	)
	road_main.name = "MainRoad_EastWest"
	add_child(road_main)
	
	# Rua TRANSVERSAL (vertical/North-South) - ATÉ O FINAL
	var road_cross = create_road_segment(
		Vector3(0, 0, -40),
		Vector3(0, 0, 40), 
		6.0  # Largura mantida
	)
	road_cross.name = "CrossRoad_NorthSouth"
	add_child(road_cross)
	
	# Calçadas apenas no perímetro (ao redor)
	create_perimeter_sidewalks()
	
	# Lane markings
	create_lane_markings()

func create_road_segment(start: Vector3, end: Vector3, width: float) -> Node3D:
	var road = Node3D.new()
	road.name = "Road"
	
	# Create road mesh
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	
	# Calculate dimensions based on direction
	var length = (end - start).length()
	if start.x != end.x:  # East-West road (horizontal)
		box_mesh.size = Vector3(length, 0.2, width)  # Thicker road
	else:  # North-South road (vertical)
		box_mesh.size = Vector3(width, 0.2, length)  # Thicker road
	
	mesh_instance.mesh = box_mesh
	
	# Position road at center
	road.position = (start + end) / 2
	
	# MATERIAL SIMPLES PARA PERFORMANCE
	var material = StandardMaterial3D.new()
	
	# Tentar carregar textura básica (sem normal maps nem roughness)
	var diffuse_texture = load("res://assets/textures/roads/asphalt_02_diff_2k.jpg")
	
	if diffuse_texture:
		material.albedo_texture = diffuse_texture
		material.albedo_color = Color.WHITE
		material.roughness = 0.8  # Valor fixo, sem textura
		
		# UV scaling baseado no tamanho real da textura (3m x 3m)
		# Ruas: Principal=10m largura, Transversal=6m largura  
		# Para rua de 10m: 10m ÷ 3m = 3.33 repetições na largura
		# Para comprimento: proporcional ao tamanho da rua
		if start.x != end.x:  # East-West road (horizontal)
			var road_length = (end - start).length()  # 80m total
			material.uv1_scale = Vector3(road_length/3.0, width/3.0, 1.0)  # ~27x3 para rua principal
		else:  # North-South road (vertical)
			var road_length = (end - start).length()  # 80m total  
			material.uv1_scale = Vector3(width/3.0, road_length/3.0, 1.0)  # ~2x27 para rua transversal
	else:
		# Fallback para cor sólida se textura não carregar
		material.albedo_color = Color(0.25, 0.25, 0.28)  # Cinza asfalto
		material.roughness = 0.8
	
	# Make sure road is visible
	material.metallic = 0.0
	material.emission = Color.BLACK
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Show both sides
	mesh_instance.material_override = material
	
	road.add_child(mesh_instance)
	return road

func create_perimeter_sidewalks():
	# CALÇADAS CORRETAS - SEM INVADIR INTERSEÇÕES, ATÉ O FINAL DAS RUAS
	print("Creating correct sidewalks - no intersection invasion, extending to road ends...")
	
	# 🎨 CRIAR MATERIAIS SEPARADOS PARA ORIENTAÇÕES DIFERENTES
	print("🔧 Loading floor_pattern_02 texture with correct orientations...")
	
	var floor_texture = load("res://assets/textures/sidewalks/floor_pattern_02_diff_2k.jpg")
	var floor_normal = load("res://assets/textures/sidewalks/floor_pattern_02_nor_gl_2k.jpg")  
	var floor_roughness = load("res://assets/textures/sidewalks/floor_pattern_02_rough_2k.jpg")
	
	# Material para calçadas LESTE-OESTE (horizontais) - orientação normal
	var sidewalk_material_horizontal = StandardMaterial3D.new()
	# Material para calçadas NORTE-SUL (verticais) - orientação rotacionada
	var sidewalk_material_vertical = StandardMaterial3D.new()
	
	if floor_texture:
		print("✅ Creating oriented floor materials!")
		
		# MATERIAL HORIZONTAL (Leste-Oeste)
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
		sidewalk_material_horizontal.uv1_scale = Vector3(15.0, 2.0, 1.0)  # Normal
		
		# MATERIAL VERTICAL (Norte-Sul) - UV offset para rotacionar textura 90°
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
		sidewalk_material_vertical.uv1_scale = Vector3(2.0, 15.0, 1.0)  # Invertido para rotação 90°
		sidewalk_material_vertical.uv1_offset = Vector3(0.25, 0.25, 0.0)  # Offset para rotacionar
		
		print("✅ Oriented floor materials ready!")
		
	else:
		print("⚠️ Floor texture not found, using gray fallback")
		sidewalk_material_horizontal.albedo_color = Color(0.4, 0.4, 0.4)
		sidewalk_material_horizontal.roughness = 0.6
		sidewalk_material_horizontal.metallic = 0.0
		
		sidewalk_material_vertical.albedo_color = Color(0.4, 0.4, 0.4)
		sidewalk_material_vertical.roughness = 0.6
		sidewalk_material_vertical.metallic = 0.0
	
	# Dimensões das ruas
	var road_main_width = 10.0   # Rua principal leste-oeste
	var road_cross_width = 6.0   # Rua transversal norte-sul
	var map_limit = 40.0         # Limites do mapa (-40 a +40)
	var sidewalk_width = 2.0     # Largura de 2m
	var sidewalk_height = 0.15   # Altura padrão
	
	# ===== CALÇADAS LESTE E OESTE - ACOMPANHAM RUA NORTE-SUL, DIVIDIDAS PELA RUA LESTE-OESTE =====
	
	# CALÇADA LESTE - duas partes separadas pela rua principal (leste-oeste)
	# Parte NORTE (acima da rua principal)
	var sidewalk_east_north = MeshInstance3D.new()
	var mesh_east_north = BoxMesh.new()
	var vertical_length = map_limit - road_main_width/2  # Comprimento vertical da calçada
	mesh_east_north.size = Vector3(sidewalk_width, sidewalk_height, vertical_length)
	sidewalk_east_north.mesh = mesh_east_north
	sidewalk_east_north.position = Vector3(road_cross_width/2 + sidewalk_width/2, sidewalk_height/2, road_main_width/2 + vertical_length/2)
	sidewalk_east_north.material_override = sidewalk_material_vertical  # Calçada vertical
	sidewalk_east_north.name = "Sidewalk_East_North"
	add_child(sidewalk_east_north)
	
	# Parte SUL (abaixo da rua principal)
	var sidewalk_east_south = MeshInstance3D.new()
	var mesh_east_south = BoxMesh.new()
	mesh_east_south.size = Vector3(sidewalk_width, sidewalk_height, vertical_length)
	sidewalk_east_south.mesh = mesh_east_south
	sidewalk_east_south.position = Vector3(road_cross_width/2 + sidewalk_width/2, sidewalk_height/2, -(road_main_width/2 + vertical_length/2))
	sidewalk_east_south.material_override = sidewalk_material_vertical  # Calçada vertical
	sidewalk_east_south.name = "Sidewalk_East_South"
	add_child(sidewalk_east_south)
	
	# CALÇADA OESTE - duas partes separadas pela rua principal (leste-oeste)
	# Parte NORTE (acima da rua principal)
	var sidewalk_west_north = MeshInstance3D.new()
	var mesh_west_north = BoxMesh.new()
	mesh_west_north.size = Vector3(sidewalk_width, sidewalk_height, vertical_length)
	sidewalk_west_north.mesh = mesh_west_north
	sidewalk_west_north.position = Vector3(-(road_cross_width/2 + sidewalk_width/2), sidewalk_height/2, road_main_width/2 + vertical_length/2)
	sidewalk_west_north.material_override = sidewalk_material_vertical  # Calçada vertical
	sidewalk_west_north.name = "Sidewalk_West_North"
	add_child(sidewalk_west_north)
	
	# Parte SUL (abaixo da rua principal)
	var sidewalk_west_south = MeshInstance3D.new()
	var mesh_west_south = BoxMesh.new()
	mesh_west_south.size = Vector3(sidewalk_width, sidewalk_height, vertical_length)
	sidewalk_west_south.mesh = mesh_west_south
	sidewalk_west_south.position = Vector3(-(road_cross_width/2 + sidewalk_width/2), sidewalk_height/2, -(road_main_width/2 + vertical_length/2))
	sidewalk_west_south.material_override = sidewalk_material_vertical  # Calçada vertical
	sidewalk_west_south.name = "Sidewalk_West_South"
	add_child(sidewalk_west_south)
	
	# ===== CALÇADAS NORTE E SUL - ACOMPANHAM RUA LESTE-OESTE, DIVIDIDAS PELA RUA NORTE-SUL =====
	
	# CALÇADA NORTE - duas partes separadas pela rua transversal
	# Parte OESTE (de -40 até a rua transversal)
	var sidewalk_north_west = MeshInstance3D.new()
	var mesh_north_west = BoxMesh.new()
	var west_length = map_limit - road_cross_width/2  # De -40 até -3 (rua começa em -3)
	mesh_north_west.size = Vector3(west_length, sidewalk_height, sidewalk_width)
	sidewalk_north_west.mesh = mesh_north_west
	sidewalk_north_west.position = Vector3(-(road_cross_width/2 + west_length/2), sidewalk_height/2, road_main_width/2 + sidewalk_width/2)
	sidewalk_north_west.material_override = sidewalk_material_horizontal  # Calçada horizontal
	sidewalk_north_west.name = "Sidewalk_North_West"
	add_child(sidewalk_north_west)
	
	# Parte LESTE (da rua transversal até +40)
	var sidewalk_north_east = MeshInstance3D.new()
	var mesh_north_east = BoxMesh.new()
	var east_length = map_limit - road_cross_width/2  # De +3 até +40 (rua termina em +3)
	mesh_north_east.size = Vector3(east_length, sidewalk_height, sidewalk_width)
	sidewalk_north_east.mesh = mesh_north_east
	sidewalk_north_east.position = Vector3(road_cross_width/2 + east_length/2, sidewalk_height/2, road_main_width/2 + sidewalk_width/2)
	sidewalk_north_east.material_override = sidewalk_material_horizontal  # Calçada horizontal
	sidewalk_north_east.name = "Sidewalk_North_East"
	add_child(sidewalk_north_east)
	
	# CALÇADA SUL - duas partes separadas pela rua transversal
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
	
	print("Sidewalks corrected - extending to road ends, no intersection invasion!")

func create_lane_markings():
	# FAIXAS AMARELAS VISÍVEIS - linhas 224-230
	var line_material = StandardMaterial3D.new()
	line_material.albedo_color = Color.YELLOW
	line_material.emission = Color.YELLOW * 0.5  # Mais brilhante
	line_material.emission_energy = 2.0  # Mais energia para visibilidade
	
	# Linha central da rua horizontal (oeste-leste) - PARA onde há calçadas
	for i in range(-36, 37, 4):  # De -36 a +36
		# PULAR onde há calçadas Norte/Sul (Z=±6 com margem)
		# Calçadas estão em Z=±6, então não desenhar entre Z=-7 e Z=+7
		if i >= -7 and i <= 7:
			continue  # Pular esta posição (há calçada)
			
		var line_mesh = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3(2.0, 0.15, 0.3)  # Visível e bem definido
		line_mesh.mesh = box_mesh
		line_mesh.position = Vector3(i, 0.25, 0)  # Altura para ficar sobre o asfalto
		line_mesh.material_override = line_material
		line_mesh.name = "YellowLane_" + str(i)
		add_child(line_mesh)
	
	# Não fazer linhas na rua de mão única (como no HTML)
	
	# Criar faixas de pedestres na intersecção
	create_crosswalks()

func setup_lighting():
	# ILUMINAÇÃO OTIMIZADA PARA HARDWARE FRACO
	
	# Sol principal (luz direcional) - SEM SOMBRAS
	var sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.position = Vector3(20, 25, 15)
	sun.rotation_degrees = Vector3(-35, -45, 0)  # Ângulo mais natural
	sun.light_energy = 1.5  # Mais energia para compensar falta de sombras
	sun.light_color = Color(1.0, 0.95, 0.8)  # Luz solar levemente amarelada
	sun.shadow_enabled = false  # DESABILITADO para performance
	add_child(sun)
	
	# Luz ambiente suave
	var ambient_light = DirectionalLight3D.new()
	ambient_light.name = "AmbientLight"
	ambient_light.rotation_degrees = Vector3(45, 135, 0)  # Direção oposta
	ambient_light.light_energy = 0.3
	ambient_light.light_color = Color(0.7, 0.8, 1.0)  # Azul suave para sombras
	add_child(ambient_light)
	
	# Ambiente e céu
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	var sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_horizon_color = Color(0.64, 0.65, 0.67)  # Horizonte urbano
	sky_material.sky_top_color = Color(0.35, 0.46, 0.71)     # Céu azul
	sky_material.ground_bottom_color = Color(0.1, 0.1, 0.1)  # Solo escuro
	sky_material.ground_horizon_color = Color(0.37, 0.33, 0.31)  # Horizonte terroso
	sky_material.sun_angle_max = 50.0
	sky_material.sun_curve = 0.05
	env.sky.sky_material = sky_material
	
	# Configurações de ambiente
	env.ambient_light_color = Color(0.8, 0.9, 1.0)
	env.ambient_light_energy = 0.2
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	
	# FOG DESABILITADO para performance
	env.fog_enabled = false
	
	# Aplicar ambiente
	get_viewport().get_camera_3d().environment = env

func create_crosswalks():
	print("🔄 CREATING CROSSWALKS WITH NEW POSITIONS!")
	print("🔄 Crosswalks will be SWAPPED between horizontal and vertical roads!")
	
	# DIMENSÕES REAIS DAS RUAS E CALÇADAS
	var road_main_width = 10.0  # Rua principal leste-oeste (dupla direção)
	var road_cross_width = 6.0  # Rua transversal norte-sul (mão única)
	var crosswalk_width = 3.0   # Largura da faixa (padrão mínimo)
	
	# FAIXAS PERPENDICULARES ÀS CALÇADAS, SEM ULTRAPASSAR A INTERSEÇÃO
	
	# FAIXAS CORRIGIDAS - NO LOCAL CERTO COM ORIENTAÇÃO CERTA
	
	# TROCANDO AS COORDENADAS COMPLETAMENTE!
	
	# TROCA SIMPLES: As que estavam em Z vão para X, e vice-versa
	
	# REFAZENDO TUDO! Rua Norte-Sul tem MAIS listras mas devem ser VERTICAIS
	
	# FAIXAS CENTRADAS ENTRE CALÇADAS - não no centro da rua!
	# Rua principal (leste-oeste) tem calçadas em Z=-3 e Z=+3, centro fica em Z=0
	# Rua transversal (norte-sul) tem calçadas em X=-5 e X=+5, centro fica em X=0
	
	# FAIXAS ALINHADAS COM AS CALÇADAS - baseado na imagem PNG
	# Vou corrigir o alinhamento para ficar exatamente entre as bordas das calçadas
	
	# FAIXAS NO MEIO DO ESPAÇO ENTRE CALÇADAS - SEM INVADIR
	# Rua principal: calçadas em Z=-3 e Z=+3, faixa no meio Z=0
	# Rua transversal: calçadas em X=-5 e X=+5, faixa no meio X=0
	
	# CÁLCULO PRECISO: Faixas exatamente entre calçadas SEM TOCAR
	# Calçadas Norte/Sul: Z = ±6 (centro), largura 2m = bordas em Z = ±5 a ±7
	# Calçadas Leste/Oeste: X = ±4 (centro), largura 2m = bordas em X = ±3 a ±5
	# FAIXAS devem ficar entre as bordas internas: Z entre -5 e +5, X entre -3 e +3
	
	# CÁLCULO CORRETO BASEADO NO CÓDIGO DAS CALÇADAS:
	# Calçadas Norte/Sul: Z = ±6 (centro), Leste/Oeste: X = ±4 (centro) 
	# Ruas: Principal Z=-5 a +5 (10m), Transversal X=-3 a +3 (6m)
	# FAIXAS: Entre calçadas, próximo mas SEM INVADIR interseção
	
	# LIMITE CORRETO: Faixas TERMINAM no limite das ruas normais (antes da interseção)
	# Rua transversal: -3 a +3, então faixas terminam em X = ±3.2 (fora da rua)
	# Rua principal: -5 a +5, então faixas terminam em Z = ±5.2 (fora da rua)
	# Centro: Z=0 (meio entre calçadas ±6), X=0 (meio entre calçadas ±4)
	
	# EXATAMENTE COMO SEU DESENHO: Faixas SÓ nas ruas, terminando no limite da interseção
	# Interseção central: X=-3 a +3, Z=-5 a +5
	# Faixas devem terminar EXATAMENTE nesses limites, não passar
	
	# CORREÇÃO: Faixas devem ficar ANTES da interseção, não no limite
	# Recuar para que não invadam a área central da interseção
	
	# AJUSTE FINO: Mais próximas da interseção mas sem invadir
	
	# FAIXAS TERMINAM **ANTES** DA INTERSEÇÃO - MUITO LONGE DELA!
	
	# FAIXAS ENTRE AS CALÇADAS com margem - como exemplo 2 a 9 numa rua de 1 a 10
	
	# CORREÇÃO: Norte/Sul atravessa rua Leste-Oeste, Leste/Oeste atravessa rua Norte-Sul
	
	# EXEMPLO 1.5 a 9.5: Faixas centralizadas com margem de 0.5 das calçadas
	
	# FAIXAS NORTE/SUL atravessam a RUA LESTE-OESTE (rua principal 10m)
	print("🔄 CENTRADO: North crosswalk no CENTRO entre calçadas")
	create_real_zebra_crossing(
		Vector3(-5.0, 0.05, 0),      # X=-5.0: longe interseção, Z=0: CENTRO perfeito
		road_main_width,             # 10m de largura da rua principal (leste-oeste)
		crosswalk_width,             
		"vertical",                  # LISTRAS VERTICAIS
		"North_Crosswalk"
	)
	
	print("🔄 CENTRADO: South crosswalk no CENTRO entre calçadas")
	create_real_zebra_crossing(
		Vector3(5.0, 0.05, 0),       # X=+5.0: longe interseção, Z=0: CENTRO perfeito
		road_main_width,             # 10m de largura da rua principal (leste-oeste)
		crosswalk_width,             
		"vertical",                  # LISTRAS VERTICAIS
		"South_Crosswalk"
	)
	
	# FAIXAS LESTE/OESTE atravessam a RUA NORTE-SUL (rua transversal 6m)
	print("🔄 CENTRADO: West crosswalk no CENTRO entre calçadas")
	create_real_zebra_crossing(
		Vector3(0, 0.05, -7.0),      # X=0: CENTRO perfeito, Z=-7.0: longe interseção
		road_cross_width,            # 6m de largura da rua transversal (norte-sul)
		crosswalk_width,             
		"horizontal",                # LISTRAS HORIZONTAIS
		"West_Crosswalk"
	)
	
	print("🔄 CENTRADO: East crosswalk no CENTRO entre calçadas")
	create_real_zebra_crossing(
		Vector3(0, 0.05, 7.0),       # X=0: CENTRO perfeito, Z=+7.0: longe interseção
		road_cross_width,            # 6m de largura da rua transversal (norte-sul)
		crosswalk_width,             
		"horizontal",                # LISTRAS HORIZONTAIS
		"East_Crosswalk"
	)
	
	print("Real crosswalks created - perpendicular to sidewalks, no intersection overlap!")
	

func create_real_zebra_crossing(center_pos: Vector3, road_width: float, crosswalk_width: float, orientation: String, crosswalk_name: String):
	# FAIXAS DE PEDESTRES REAIS - LISTRAS PERPENDICULARES ÀS CALÇADAS
	print("Creating real zebra crossing: " + crosswalk_name + " at position: " + str(center_pos))
	
	# Material SUPER VISÍVEL para listras brancas
	var white_material = StandardMaterial3D.new()
	white_material.albedo_color = Color.WHITE
	white_material.emission = Color.WHITE * 0.8  # MUITO BRILHANTE
	white_material.emission_energy = 3.0         # ENERGIA MÁXIMA
	white_material.metallic = 0.0
	white_material.roughness = 0.1
	white_material.flags_unshaded = true
	white_material.flags_do_not_receive_shadows = true
	white_material.flags_disable_ambient_light = true
	
	# Parâmetros de faixa REAL - mais listras menores
	var stripe_width = 0.4          # 40cm por listra (padrão real)
	var stripe_spacing = 0.4        # 40cm de espaço entre listras  
	var stripe_height = 0.08        # 8cm de altura (visível mas realista)
	var total_cycle = stripe_width + stripe_spacing  # 0.8m por ciclo
	
	# Calcular quantas listras cabem na largura da rua - REMOVER 1 só de um lado
	var stripe_count = int(road_width / total_cycle) - 1  # Tirar 1 listra (só de um lado)
	var start_position = -(road_width / 2.0) + (stripe_width / 2.0) + total_cycle  # Começar 1 listra mais dentro
	
	# Container para organizar a faixa
	var crosswalk_container = Node3D.new()
	crosswalk_container.name = crosswalk_name + "_Real"
	crosswalk_container.position = center_pos
	add_child(crosswalk_container)
	
	# Criar cada listra branca da faixa zebra
	for i in range(stripe_count):
		var stripe = MeshInstance3D.new()
		var stripe_mesh = BoxMesh.new()
		
		if orientation == "horizontal":
			# Faixa atravessa rua norte-sul: listras horizontais (perpendiculares à direção N-S)
			stripe_mesh.size = Vector3(stripe_width, stripe_height, crosswalk_width)
			stripe.position = Vector3(start_position + (i * total_cycle), stripe_height/2 + 0.1, 0)  # +0.1 acima do asfalto
		else:  # vertical
			# Faixa atravessa rua leste-oeste: listras verticais (perpendiculares à direção L-O) 
			stripe_mesh.size = Vector3(crosswalk_width, stripe_height, stripe_width)
			stripe.position = Vector3(0, stripe_height/2 + 0.1, start_position + (i * total_cycle))  # +0.1 acima do asfalto
		
		stripe.mesh = stripe_mesh
		stripe.material_override = white_material
		stripe.name = crosswalk_name + "_Stripe_" + str(i)
		crosswalk_container.add_child(stripe)
	
	print("Real zebra crossing '" + crosswalk_name + "' created with " + str(stripe_count) + " stripes!")









func create_dotted_crosswalk(center_pos: Vector3, direction: Vector3, road_width: float, material: StandardMaterial3D, crosswalk_name: String):
	# Criar 2 linhas pontilhadas finas para faixa de pedestres
	var line_spacing = 1.2  # Distância entre as 2 linhas
	var dot_size = 0.4  # Tamanho de cada ponto (mais fino)
	var dot_spacing = 1.0  # Espaçamento entre pontos
	
	# Criar 2 linhas pontilhadas
	for line_index in range(2):
		var line_offset = (line_index - 0.5) * line_spacing  # -0.6 e +0.6
		
		# Calcular quantos pontos cabem na largura da rua
		var dot_count = int(road_width / dot_spacing)
		var start_offset = -(road_width / 2.0) + (dot_spacing / 2.0)
		
		for dot_index in range(dot_count):
			var dot = MeshInstance3D.new()
			var box_mesh = BoxMesh.new()
			box_mesh.size = Vector3(dot_size, 0.02, dot_size)  # Pontos mais altos e visíveis
			
			if direction.x != 0:  # Linhas horizontais (West/East)
				dot.position = center_pos + Vector3(line_offset, 0, start_offset + dot_index * dot_spacing)
			else:  # Linhas verticais (North/South)
				dot.position = center_pos + Vector3(start_offset + dot_index * dot_spacing, 0, line_offset)
			
			dot.mesh = box_mesh
			dot.material_override = material
			dot.name = crosswalk_name + "_Line" + str(line_index) + "_Dot" + str(dot_index)
			add_child(dot)


func setup_traffic_lights():
	# APENAS 3 SEMÁFOROS com POSIÇÕES EXATAS DO HTML:
	
	# Semáforo 1: Rua principal - lado esquerdo (HTML linha 236)
	# HTML: createTrafficLight(-5, 0, 5, Math.PI / 2, 'main_road')
	create_traffic_light(Vector3(-5, 0, 5), 90, "main_road_west", "S1")
	
	# Semáforo 2: Rua principal - lado direito (HTML linha 240)  
	# HTML: createTrafficLight(5, 0, -5, -Math.PI / 2, 'main_road')
	create_traffic_light(Vector3(5, 0, -5), -90, "main_road_east", "S2")
	
	# Semáforo 3: Rua de mão única (HTML linha 244)
	# HTML: createTrafficLight(-5, 0, -5, 0, 'one_way_road')
	create_traffic_light(Vector3(-5, 0, -5), 0, "cross_road_north", "S3")

func create_traffic_light(pos: Vector3, rotation_y: float, direction: String, label: String = "") -> Node3D:
	var light_scene = preload("res://scenes/TrafficLight.tscn")
	var light = light_scene.instantiate()
	light.name = "TrafficLight_" + direction
	light.position = pos
	light.rotation_degrees.y = rotation_y
	add_child(light)
	
	# Adicionar label 3D acima do semáforo se especificado
	if label != "":
		create_traffic_light_label(pos, rotation_y, label)
	
	traffic_manager.register_traffic_light(light)
	
	# INTEGRAÇÃO: Registrar também no sistema de eventos discretos
	if discrete_simulator and discrete_simulator.traffic_light_system:
		# Mapear direction para light_id correto
		var light_id = ""
		match direction:
			"main_road_west":
				light_id = "S1"
			"main_road_east":
				light_id = "S2"
			"cross_road_north":
				light_id = "S3"
		
		if light_id != "":
			discrete_simulator.traffic_light_system.register_traffic_light_node(light_id, light)
			print("🔗 Semáforo %s registrado no sistema discrete events" % light_id)
	
	return light

func create_traffic_light_label(light_pos: Vector3, rotation_y: float, label_text: String):
	# Criar container para o label
	var label_container = Node3D.new()
	label_container.name = "TrafficLightLabel_" + label_text
	
	# Calcular posição da ponta da haste baseado na rotação específica
	var arm_end_position: Vector3
	
	# S1: main_road_west (rotação 90°) em (-5, 0, 5) - haste aponta para a rua
	# S2: main_road_east (rotação -90°) em (5, 0, -5) - haste aponta para a rua  
	# S3: cross_road_north (rotação 0°) em (-5, 0, -5) - haste aponta para a rua
	
	if rotation_y == 90:  # S1 - haste deve apontar para dentro da rua (para -Z)
		arm_end_position = light_pos + Vector3(0, 0, -3.0)  # Para -Z (para dentro da rua)
	elif rotation_y == -90:  # S2 - haste deve apontar para dentro da rua (para +Z)
		arm_end_position = light_pos + Vector3(0, 0, 3.0)  # Para +Z (para dentro da rua)
	else:  # S3 (0°) - haste aponta para +X (correto)
		arm_end_position = light_pos + Vector3(3.0, 0, 0)  # Para +X
	
	# Posicionar label acima da luz vermelha (Y=4.5) + margem (1.0) + 2 pixels = Y=7.5
	var label_position = arm_end_position + Vector3(0, 7.5, 0)
	label_container.position = label_position
	
	# Criar o texto 3D usando MeshInstance3D com TextMesh
	var text_mesh_instance = MeshInstance3D.new()
	var text_mesh = TextMesh.new()
	text_mesh.text = label_text
	text_mesh.font_size = 80
	text_mesh.depth = 0.1
	text_mesh_instance.mesh = text_mesh
	
	# Configurar material do texto para ser bem visível
	var text_material = StandardMaterial3D.new()
	text_material.albedo_color = Color.WHITE
	text_material.emission = Color.WHITE * 0.8
	text_material.emission_energy = 3.0
	text_material.flags_unshaded = true
	text_material.flags_do_not_receive_shadows = true
	text_material.flags_disable_ambient_light = true
	text_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	text_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	# Aplicar material
	text_mesh_instance.material_override = text_material
	
	# Não usar fundo - o TextMesh já tem boa visibilidade com o material
	
	# Adicionar o texto ao container
	label_container.add_child(text_mesh_instance)
	
	# Adicionar à cena
	add_child(label_container)

func create_label_background(parent_container: Node3D, label_text: String):
	# Criar um fundo escuro atrás do texto para melhor legibilidade
	var background = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	
	# Tamanho baseado no comprimento do texto
	var text_width = label_text.length() * 0.4  # Aproximação
	plane_mesh.size = Vector2(text_width + 0.5, 1.0)
	
	background.mesh = plane_mesh
	background.position = Vector3(0, 0, -0.1)  # Ligeiramente atrás do texto
	
	# Material escuro semi-transparente
	var bg_material = StandardMaterial3D.new()
	bg_material.albedo_color = Color(0, 0, 0, 0.7)  # Preto semi-transparente
	bg_material.flags_transparent = true
	background.material_override = bg_material
	
	parent_container.add_child(background)

# FUNÇÃO REMOVIDA - SpawnSystem agora gerencia todos os spawn points
# func setup_spawn_points():
#	# Create spawn points for each direction
#	var spawn_points = [
#		{"pos": Vector3(0, 0, -15), "dir": Vector3(0, 0, 1), "name": "North_Entry"},
#		{"pos": Vector3(0, 0, 15), "dir": Vector3(0, 0, -1), "name": "South_Entry"},
#		{"pos": Vector3(-15, 0, 0), "dir": Vector3(1, 0, 0), "name": "East_Entry"},
#		{"pos": Vector3(15, 0, 0), "dir": Vector3(-1, 0, 0), "name": "West_Entry"}
#	]
#	
#	for point in spawn_points:
#		var spawn = Node3D.new()
#		spawn.name = point.name
#		spawn.position = point.pos
#		spawn.set_meta("direction", point.dir)
#		add_child(spawn)
#		traffic_manager.register_spawn_point(spawn)

func connect_signals():
	# Por enquanto stub - discrete events virão depois
	# traffic_manager.stats_updated.connect(_on_stats_updated)
	pass

func _on_stats_updated(stats: Dictionary):
	# Por enquanto stub - discrete events virão depois
	# analytics.update_display(stats)
	pass

func toggle_pause():
	if is_running:
		pause_simulation()
	else:
		start_simulation()

func pause_simulation():
	is_running = false
	if discrete_simulator:
		discrete_simulator.pause_simulation()
	print("⏸️ Simulation paused")

func start_simulation():
	is_running = true
	if discrete_simulator:
		discrete_simulator.start_simulation()
	print("▶️ Simulation started")

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("Traffic Simulator 3D - Shutting down...")
		get_tree().quit()

func create_urban_environment():
	# Ambiente urbano com prédios baixos e sem árvores
	print("Creating urban environment...")
	
	# APENAS prédios baixos nas áreas verdes (sem árvores)
	create_low_buildings_near_roads()
	
	print("Urban environment created!")

func create_corner_buildings():
	# PRÉDIOS NAS 4 ESQUINAS da interseção para dar contexto urbano
	var building_material = StandardMaterial3D.new()
	building_material.albedo_color = Color(0.8, 0.8, 0.9)  # Cor de concreto
	building_material.roughness = 0.7
	building_material.metallic = 0.0
	
	var window_material = StandardMaterial3D.new()
	window_material.albedo_color = Color(0.3, 0.4, 0.6)  # Azul escuro para janelas
	window_material.roughness = 0.1  # Vidro mais liso
	window_material.metallic = 0.2
	
	# PRÉDIOS BEM AFASTADOS DAS RUAS ESTENDIDAS (-50 a +50)
	# ESQUINA NORDESTE (+X, +Z) - bem longe das ruas
	create_building(Vector3(60, 0, 60), Vector3(12, 15, 12), building_material, window_material, "Building_NE")
	
	# ESQUINA NOROESTE (-X, +Z) - bem longe das ruas
	create_building(Vector3(-60, 0, 60), Vector3(12, 12, 12), building_material, window_material, "Building_NW")
	
	# ESQUINA SUDESTE (+X, -Z) - bem longe das ruas
	create_building(Vector3(60, 0, -60), Vector3(15, 18, 10), building_material, window_material, "Building_SE")
	
	# ESQUINA SUDOESTE (-X, -Z) - bem longe das ruas
	create_building(Vector3(-60, 0, -60), Vector3(10, 14, 15), building_material, window_material, "Building_SW")
	
	# Prédios de fundo (mais distantes)
	create_background_buildings()

func create_building(center_pos: Vector3, size: Vector3, building_mat: StandardMaterial3D, window_mat: StandardMaterial3D, building_name: String):
	var building = Node3D.new()
	building.name = building_name
	building.position = center_pos
	
	# Estrutura principal do prédio
	var main_building = MeshInstance3D.new()
	var building_mesh = BoxMesh.new()
	building_mesh.size = size
	main_building.mesh = building_mesh
	main_building.position.y = size.y / 2  # Centrar na altura
	main_building.material_override = building_mat
	building.add_child(main_building)
	
	# Adicionar janelas (pequenos cubos escuros)
	create_building_windows(building, size, window_mat)
	
	add_child(building)

func create_building_windows(building_parent: Node3D, building_size: Vector3, window_mat: StandardMaterial3D):
	# Criar padrão de janelas nas fachadas
	var window_size = Vector3(1.5, 1.8, 0.2)
	var floors = int(building_size.y / 4.0)  # Uma janela a cada 4 unidades de altura
	var windows_per_floor_x = max(1, int(building_size.x / 4.0))
	var _windows_per_floor_z = max(1, int(building_size.z / 4.0))  # Fixed unused warning
	
	# Janelas na fachada FRONTAL (virada para a rua)
	for floor_level in range(floors):  # Renamed from 'floor'
		for window_x in range(windows_per_floor_x):
			var window = MeshInstance3D.new()
			var window_mesh = BoxMesh.new()
			window_mesh.size = window_size
			window.mesh = window_mesh
			window.material_override = window_mat
			
			# Posicionar janela na fachada
			var window_pos = Vector3(
				-building_size.x/2 + (window_x + 1) * (building_size.x / (windows_per_floor_x + 1)),
				building_size.y/2 + (floor_level * 4.0) - building_size.y/2 + 2.0,
				building_size.z/2 + 0.1  # Ligeiramente para fora
			)
			window.position = window_pos
			building_parent.add_child(window)

func create_background_buildings():
	# Prédios mais distantes para dar profundidade
	var bg_material = StandardMaterial3D.new()
	bg_material.albedo_color = Color(0.6, 0.6, 0.7)  # Mais escuro, ao fundo
	bg_material.roughness = 0.8
	
	# Fileira de prédios ao Norte - moved beyond road area
	for i in range(5):
		var pos = Vector3(-40 + i * 20, 0, 80)  # Moved from 40 to 80 to clear road area
		var size = Vector3(15, randf_range(12, 35), 12)
		create_simple_building(pos, size, bg_material, "BG_North_" + str(i))
	
	# Fileira de prédios ao Sul - moved beyond road area
	for i in range(5):
		var pos = Vector3(-40 + i * 20, 0, -80)  # Moved from -40 to -80 to clear road area
		var size = Vector3(15, randf_range(15, 30), 12)
		create_simple_building(pos, size, bg_material, "BG_South_" + str(i))

func create_detailed_building(pos: Vector3, size: Vector3, base_color: Color, building_name: String):
	var building = Node3D.new()
	building.name = building_name
	building.position = pos
	
	# Material do prédio principal
	var building_material = StandardMaterial3D.new()
	building_material.albedo_color = base_color
	building_material.roughness = 0.8
	building_material.metallic = 0.1
	
	# Estrutura principal do prédio
	var main_structure = MeshInstance3D.new()
	var building_mesh = BoxMesh.new()
	building_mesh.size = size
	main_structure.mesh = building_mesh
	main_structure.position.y = size.y / 2
	main_structure.material_override = building_material
	building.add_child(main_structure)
	
	# Adicionar janelas detalhadas
	create_building_windows_detailed(building, size, base_color)
	
	# Adicionar telhado
	create_building_roof(building, size, base_color)
	
	# Adicionar detalhes arquitetônicos
	create_building_details(building, size, base_color)
	
	add_child(building)

func create_building_windows_detailed(building_parent: Node3D, building_size: Vector3, _base_color: Color):
	# Material das janelas - azul escuro com reflexo
	var window_material = StandardMaterial3D.new()
	window_material.albedo_color = Color(0.1, 0.2, 0.4)
	window_material.metallic = 0.3
	window_material.roughness = 0.1
	window_material.emission = Color(1.0, 0.9, 0.6) * 0.15  # Luz suave das janelas
	
	# Calcular grid de janelas
	var floors = max(1, int(building_size.y / 3.0))  # Uma janela a cada 3 unidades
	var windows_per_floor_x = max(1, int(building_size.x / 2.5))
	var windows_per_floor_z = max(1, int(building_size.z / 2.5))
	
	# Janelas nas 4 fachadas
	create_facade_windows(building_parent, building_size, floors, windows_per_floor_x, window_material, Vector3(0, 0, building_size.z/2 + 0.05), "front")
	create_facade_windows(building_parent, building_size, floors, windows_per_floor_x, window_material, Vector3(0, 0, -building_size.z/2 - 0.05), "back")
	create_facade_windows(building_parent, building_size, floors, windows_per_floor_z, window_material, Vector3(building_size.x/2 + 0.05, 0, 0), "right")
	create_facade_windows(building_parent, building_size, floors, windows_per_floor_z, window_material, Vector3(-building_size.x/2 - 0.05, 0, 0), "left")

func create_facade_windows(parent: Node3D, building_size: Vector3, floors: int, windows_per_row: int, material: StandardMaterial3D, facade_pos: Vector3, facade_name: String):
	var is_side_facade = facade_name in ["left", "right"]
	
	# Orientação correta das janelas baseado na fachada
	var window_size: Vector3
	if is_side_facade:
		window_size = Vector3(0.1, 1.5, 1.2)  # Janelas laterais: finas em X, altas em Y, largas em Z
	else:
		window_size = Vector3(1.2, 1.5, 0.1)  # Janelas frontais/traseiras: largas em X, altas em Y, finas em Z
	
	for floor_level in range(floors):
		for window_idx in range(windows_per_row):
			var window = MeshInstance3D.new()
			var window_mesh = BoxMesh.new()
			window_mesh.size = window_size
			window.mesh = window_mesh
			window.material_override = material
			
			# Posicionamento das janelas
			var floor_height = building_size.y/2 - building_size.y + (floor_level + 0.5) * (building_size.y / floors) + 1.0
			var window_spacing = (building_size.x if not is_side_facade else building_size.z) / (windows_per_row + 1)
			var window_offset = -(building_size.x if not is_side_facade else building_size.z)/2 + (window_idx + 1) * window_spacing
			
			if is_side_facade:
				window.position = Vector3(facade_pos.x, floor_height, window_offset)
			else:
				window.position = Vector3(window_offset, floor_height, facade_pos.z)
			
			window.name = facade_name + "_Window_F" + str(floor_level) + "_W" + str(window_idx)
			parent.add_child(window)

func create_building_roof(building_parent: Node3D, building_size: Vector3, base_color: Color):
	# Telhado mais escuro que o prédio
	var roof_material = StandardMaterial3D.new()
	roof_material.albedo_color = base_color * 0.7  # 30% mais escuro
	roof_material.roughness = 0.9
	roof_material.metallic = 0.0
	
	var roof = MeshInstance3D.new()
	var roof_mesh = BoxMesh.new()
	roof_mesh.size = Vector3(building_size.x + 0.5, 0.3, building_size.z + 0.5)  # Ligeiramente maior
	roof.mesh = roof_mesh
	roof.position.y = building_size.y + 0.15
	roof.material_override = roof_material
	roof.name = "Roof"
	building_parent.add_child(roof)

func create_building_details(building_parent: Node3D, building_size: Vector3, base_color: Color):
	# Detalhes arquitetônicos - borda na base
	var detail_material = StandardMaterial3D.new()
	detail_material.albedo_color = base_color * 1.2  # Ligeiramente mais claro
	detail_material.roughness = 0.6
	detail_material.metallic = 0.0
	
	# Borda decorativa na base
	var base_trim = MeshInstance3D.new()
	var trim_mesh = BoxMesh.new()
	trim_mesh.size = Vector3(building_size.x + 0.2, 0.5, building_size.z + 0.2)
	base_trim.mesh = trim_mesh
	base_trim.position.y = 0.25
	base_trim.material_override = detail_material
	base_trim.name = "BaseTrim"
	building_parent.add_child(base_trim)

func create_simple_building(pos: Vector3, size: Vector3, material: StandardMaterial3D, building_name: String):
	# Função mantida para compatibilidade, mas agora usa detailed_building
	create_detailed_building(pos, size, material.albedo_color, building_name)

# DETALHES URBANOS REMOVIDOS - sem árvores

# FUNÇÕES DE ÁRVORES REMOVIDAS - não utilizadas

func create_street_lighting():
	# Postes de luz para iluminação noturna
	var post_material = StandardMaterial3D.new()
	post_material.albedo_color = Color(0.3, 0.3, 0.3)  # Metal escuro
	post_material.metallic = 0.8
	post_material.roughness = 0.3
	
	# Posições dos postes nos cantos - moved beyond road area
	var light_positions = [
		Vector3(-52, 0, 52),  # NW corner - green area
		Vector3(52, 0, 52),   # NE corner - green area
		Vector3(-52, 0, -52), # SW corner - green area
		Vector3(52, 0, -52)   # SE corner - green area
	]
	
	for i in range(light_positions.size()):
		create_street_light(light_positions[i], post_material, "StreetLight_" + str(i))

func create_street_light(light_pos: Vector3, material: StandardMaterial3D, light_name: String):
	var light_post = Node3D.new()
	light_post.name = light_name
	light_post.position = light_pos
	
	# Poste
	var post = MeshInstance3D.new()
	var post_mesh = CylinderMesh.new()
	post_mesh.height = 8.0
	post_mesh.top_radius = 0.1
	post_mesh.bottom_radius = 0.15
	post.mesh = post_mesh
	post.position.y = 4.0
	post.material_override = material
	light_post.add_child(post)
	
	# Luminária
	var lamp = MeshInstance3D.new()
	var lamp_mesh = SphereMesh.new()
	lamp_mesh.radius = 0.4
	lamp.mesh = lamp_mesh
	lamp.position.y = 8.2
	
	var lamp_material = StandardMaterial3D.new()
	lamp_material.albedo_color = Color.YELLOW
	lamp_material.emission = Color.YELLOW * 0.5
	lamp_material.emission_energy = 2.0
	lamp.material_override = lamp_material
	light_post.add_child(lamp)
	
	# Luz ambiente
	var omni_light = OmniLight3D.new()
	omni_light.light_color = Color.YELLOW
	omni_light.light_energy = 0.8
	omni_light.omni_range = 15.0
	omni_light.position.y = 8.2
	light_post.add_child(omni_light)
	
	add_child(light_post)

func create_low_buildings_near_roads():
	# SISTEMA ORGANIZADO DE GRID PARA EVITAR SOBREPOSIÇÕES
	print("Creating organized building grid...")
	
	# Cores para diferentes tipos de prédios
	var building_colors = [
		Color(0.8, 0.6, 0.4),  # Marrom claro
		Color(0.7, 0.7, 0.8),  # Azul acinzentado  
		Color(0.8, 0.7, 0.5),  # Bege
		Color(0.6, 0.7, 0.6),  # Verde claro
		Color(0.8, 0.5, 0.5),  # Rosa claro
		Color(0.6, 0.6, 0.8),  # Lilás
		Color(0.7, 0.8, 0.6),  # Verde limão
		Color(0.8, 0.7, 0.7),  # Cinza rosado
	]
	
	# Tamanho padrão dos prédios (fixo para evitar sobreposições)
	var building_size = Vector3(6, 8, 6)  # Largura, Altura, Profundidade
	var spacing = 12.0  # Espaçamento entre prédios (maior que o tamanho)
	
	var building_count = 0
	
	# SETOR NORTE (ao norte da rua principal, Z > 8) - REDUZIDO
	create_building_grid(Vector3(-20, 0, 12), Vector3(20, 0, 22), spacing, building_size, building_colors, "North", building_count)
	building_count += 6  # Reduzido para mapa menor
	
	# SETOR SUL (ao sul da rua principal, Z < -8) - REDUZIDO
	create_building_grid(Vector3(-20, 0, -22), Vector3(20, 0, -12), spacing, building_size, building_colors, "South", building_count)
	building_count += 6  # Reduzido para mapa menor
	
	# SETOR OESTE (oeste da rua transversal, X < -8, evitando intersecção) - REDUZIDO
	create_building_grid(Vector3(-22, 0, -20), Vector3(-12, 0, -8), spacing, building_size, building_colors, "West_South", building_count)
	building_count += 3
	create_building_grid(Vector3(-22, 0, 8), Vector3(-12, 0, 20), spacing, building_size, building_colors, "West_North", building_count)
	building_count += 3
	
	# SETOR LESTE (leste da rua transversal, X > 8, evitando intersecção) - REDUZIDO
	create_building_grid(Vector3(12, 0, -20), Vector3(22, 0, -8), spacing, building_size, building_colors, "East_South", building_count)
	building_count += 3
	create_building_grid(Vector3(12, 0, 8), Vector3(22, 0, 20), spacing, building_size, building_colors, "East_North", building_count)
	
	print("Created organized building grid with proper spacing!")

func create_building_grid(start_pos: Vector3, end_pos: Vector3, spacing: float, size: Vector3, colors: Array, sector_name: String, start_index: int):
	# Criar prédios em grid organizado dentro da área especificada
	var current_x = start_pos.x
	var current_z = start_pos.z
	var building_index = start_index
	
	while current_z <= end_pos.z:
		current_x = start_pos.x
		while current_x <= end_pos.x:
			# Verificar se a posição está em área segura (longe das ruas e calçadas)
			if is_safe_building_position(Vector3(current_x, 0, current_z)):
				var color = colors[building_index % colors.size()]
				# Variar altura ligeiramente para mais realismo
				var varied_size = Vector3(size.x, size.y + randf_range(-1, 2), size.z)
				create_detailed_building(Vector3(current_x, 0, current_z), varied_size, color, "Grid_" + sector_name + "_" + str(building_index))
				building_index += 1
			
			current_x += spacing
		current_z += spacing

func is_safe_building_position(pos: Vector3) -> bool:
	# Verificar se a posição está segura para colocar um prédio
	
	# RUAS E CALÇADAS - áreas proibidas:
	# Rua principal (oeste-leste): Z entre -5 e +5
	# Calçadas da rua principal: Z entre -9 e -5 (sul) e Z entre +5 e +9 (norte)  
	if pos.z >= -9 and pos.z <= 9:
		return false  # Muito perto da rua principal
	
	# Rua transversal (norte-sul): X entre -3 e +3
	# Calçadas da rua transversal: X entre -7 e -3 (oeste) e X entre +3 e +7 (leste)
	if pos.x >= -7 and pos.x <= 7:
		return false  # Muito perto da rua transversal
		
	# ZONA DE INTERSECÇÃO - área crítica no centro
	# Evitar completamente a zona central (intersecção + margens de segurança)
	if pos.x >= -12 and pos.x <= 12 and pos.z >= -12 and pos.z <= 12:
		return false  # Zona de intersecção ampliada
	
	return true  # Posição segura

# ÁRVORES REMOVIDAS - função não utilizada
