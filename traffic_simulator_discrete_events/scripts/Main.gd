extends Node3D

## Main.gd para Traffic Simulator com Eventos Discretos
## Gerencia o mundo 3D (idêntico ao simulator_3d) e coordena com o backend discreto

# Componentes do simulador
@onready var discrete_simulator = $DiscreteTrafficSimulator
@onready var spawn_system = $SpawnSystem
@onready var camera_controller = $CameraController
@onready var analytics = $Analytics
# UI integrado no Analytics

# Estado da simulação
var is_running: bool = true
var start_time: float = 0.0

func _ready():
	print("🎯 Main.gd initializing - Creating 3D world identical to simulator_3d")
	
	# Criar mundo 3D EXATAMENTE como o original
	setup_environment()
	setup_traffic_lights()
	
	# Aguardar alguns frames antes de inicializar sistemas complexos
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Conectar sistemas
	connect_systems()
	
	# Inicializar simulação
	start_time = Time.get_time_dict_from_system()["second"]
	
	print("🎯 Main initialized - Original 3D world + Discrete backend ready")

func _process(_delta):
	# Atualização contínua se necessário
	pass

func _input(event):
	# Controles globais
	if event.is_action_pressed("ui_pause"):
		toggle_pause()
	elif event.is_action_pressed("ui_camera_mode"):
		if camera_controller:
			camera_controller.cycle_camera_mode()

## ============================================================================
## MUNDO 3D EXATO DO ORIGINAL - SEM MODIFICAÇÕES
## ============================================================================

func setup_environment():
	# Create base ground first
	create_base_ground()
	# Create intersection geometry
	create_intersection()
	setup_lighting()
	print("🛣️ 3D Environment created - identical to simulator_3d")

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
	
	# Faixas de pedestres na intersecção
	create_crosswalks()
	
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

func create_lane_markings():
	# FAIXAS AMARELAS VISÍVEIS
	var line_material = StandardMaterial3D.new()
	line_material.albedo_color = Color.YELLOW
	line_material.emission = Color.YELLOW * 0.5  # Mais brilhante
	line_material.emission_energy = 2.0  # Mais energia para visibilidade
	
	# Linha central da rua horizontal (oeste-leste)
	for i in range(-36, 37, 4):  # De -36 a +36
		# PULAR onde há calçadas Norte/Sul (Z=±6 com margem)
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

func setup_traffic_lights():
	# APENAS 3 SEMÁFOROS com POSIÇÕES EXATAS DO HTML:
	
	# Semáforo 1: Rua principal - lado esquerdo
	create_traffic_light(Vector3(-5, 0, 5), 90, "main_road_west", "S1")
	
	# Semáforo 2: Rua principal - lado direito
	create_traffic_light(Vector3(5, 0, -5), -90, "main_road_east", "S2")
	
	# Semáforo 3: Rua de mão única
	create_traffic_light(Vector3(-5, 0, -5), 0, "cross_road_north", "S3")

func create_traffic_light(pos: Vector3, rotation_y: float, direction: String, label: String = "") -> Node3D:
	# Carregar a cena de semáforo se existir, senão criar placeholder
	var light_scene_path = "res://scenes/TrafficLight.tscn"
	
	var light: Node3D
	if ResourceLoader.exists(light_scene_path):
		var light_scene = load(light_scene_path)
		light = light_scene.instantiate()
	else:
		# Criar placeholder simples
		light = create_traffic_light_placeholder(pos, label)
	
	light.name = "TrafficLight_" + direction
	light.position = pos
	light.rotation_degrees.y = rotation_y
	add_child(light)
	
	return light

func create_traffic_light_placeholder(pos: Vector3, label: String) -> Node3D:
	var light_container = Node3D.new()
	
	# Poste
	var post = MeshInstance3D.new()
	var post_mesh = CylinderMesh.new()
	post_mesh.height = 6.0
	post_mesh.top_radius = 0.1
	post_mesh.bottom_radius = 0.15
	post.mesh = post_mesh
	post.position.y = 3.0
	
	var post_material = StandardMaterial3D.new()
	post_material.albedo_color = Color.DARK_GRAY
	post.material_override = post_material
	
	light_container.add_child(post)
	
	# Luz vermelha (placeholder)
	var red_light = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.3
	red_light.mesh = sphere_mesh
	red_light.position = Vector3(0, 5.5, 0)
	
	var red_material = StandardMaterial3D.new()
	red_material.albedo_color = Color.RED
	red_material.emission = Color.RED * 0.5
	red_light.material_override = red_material
	
	light_container.add_child(red_light)
	
	return light_container

## ============================================================================
## INTEGRAÇÃO COM SISTEMAS
## ============================================================================

func connect_systems():
	# Conectar sistemas entre si
	if discrete_simulator:
		# AGUARDAR setup completo do simulador
		await get_tree().process_frame
		await get_tree().process_frame
		
		# Fornecer referência do mundo 3D para o HybridRenderer
		var hybrid_renderer = discrete_simulator.get_hybrid_renderer()
		if hybrid_renderer:
			hybrid_renderer.set_visual_world(self)
			print("🎯 Connected discrete backend to 3D world")
		else:
			print("⚠️ HybridRenderer not found!")
		
		# Conectar outros sinais se necessário
		discrete_simulator.stats_updated.connect(_on_stats_updated)
		print("🎯 All systems connected")

func _on_stats_updated(stats: Dictionary):
	# Processar estatísticas se necessário
	pass

func toggle_pause():
	if discrete_simulator:
		if discrete_simulator.is_running:
			discrete_simulator.pause_simulation()
		else:
			discrete_simulator.resume_simulation()
	is_running = !is_running

func get_hybrid_renderer() -> HybridRenderer:
	# Fornecer acesso ao HybridRenderer para outros sistemas
	if discrete_simulator:
		return discrete_simulator.get_hybrid_renderer()
	return null

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("Hybrid Traffic Simulator - Shutting down...")
		get_tree().quit()