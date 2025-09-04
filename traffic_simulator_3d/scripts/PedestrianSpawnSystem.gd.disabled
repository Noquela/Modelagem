extends Node3D
class_name PedestrianSpawnSystem

# Configuração de spawn (variável para permitir ajustes)
var pedestrian_config = {
	"base_spawn_rate": 0.5,      # Taxa aumentada para testes
	"max_pedestrians": 25,       # Máximo de pedestres simultâneos
	"spawn_distance": 2.0,       # Distância mínima entre pedestres
	"cleanup_distance": 50.0     # Distância para remover pedestres
}

# Pedestrian scene/modelo
var pedestrian_scene: PackedScene
var pedestrian_models: Array[PackedScene] = []

# Controle de pedestres
var active_pedestrians: Array[Node] = []
var total_pedestrians_spawned: int = 0
var simulation_time: float = 0.0

# Pontos de spawn nas calçadas
var sidewalk_spawn_points: Array[Vector3] = []

func _ready():
	setup_spawn_points()
	load_pedestrian_models()
	
	# Limpar pedestres existentes (caso haja)
	cleanup_all_pedestrians()
	
	# TESTE: Spawnar um pedestre imediatamente para verificar
	await get_tree().process_frame
	await get_tree().process_frame
	force_spawn_test_pedestrian()
	
	set_process(true)
	print("PedestrianSpawnSystem initialized - Max: %d pedestrians" % pedestrian_config.max_pedestrians)

func setup_spawn_points():
	# PONTOS DE SPAWN NAS PONTAS DAS CALÇADAS (longe da intersecção)
	sidewalk_spawn_points = [
		# Calçadas horizontais - PONTAS EXTREMAS
		Vector3(-30, 0.5, 4.0),    # Norte Oeste - extremo
		Vector3(-35, 0.5, 4.0),    # Norte Oeste - mais longe
		Vector3(30, 0.5, 4.0),     # Norte Leste - extremo
		Vector3(35, 0.5, 4.0),     # Norte Leste - mais longe
		
		Vector3(-30, 0.5, -4.0),   # Sul Oeste - extremo
		Vector3(-35, 0.5, -4.0),   # Sul Oeste - mais longe
		Vector3(30, 0.5, -4.0),    # Sul Leste - extremo
		Vector3(35, 0.5, -4.0),    # Sul Leste - mais longe
		
		# Calçadas verticais - PONTAS EXTREMAS
		Vector3(-4.0, 0.5, -25),   # Oeste Sul - extremo
		Vector3(-4.0, 0.5, -30),   # Oeste Sul - mais longe
		Vector3(-4.0, 0.5, 25),    # Oeste Norte - extremo
		Vector3(-4.0, 0.5, 30),    # Oeste Norte - mais longe
		
		Vector3(4.0, 0.5, -25),    # Leste Sul - extremo
		Vector3(4.0, 0.5, -30),    # Leste Sul - mais longe
		Vector3(4.0, 0.5, 25),     # Leste Norte - extremo
		Vector3(4.0, 0.5, 30)      # Leste Norte - mais longe
	]

func load_pedestrian_models():
	# Carregar modelos de pedestres (começar com fallback básico)
	create_basic_pedestrian_scene()
	
	# Carregar modelos externos se disponíveis
	load_external_models()

func create_basic_pedestrian_scene():
	# Criar cena básica de pedestre SEM SCRIPT (só visual)
	var scene = PackedScene.new()
	var pedestrian = Node3D.new()  # Node3D simples, sem script
	pedestrian.name = "SimplePedestrian"
	
	# TESTE: USAR CUBO EM VEZ DE CAPSULE (igual o cubo teste que funcionou)
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "PedestrianCube"
	var cube_mesh = BoxMesh.new()
	cube_mesh.size = Vector3(1, 2, 1)  # Cubo pessoa (1x2x1)
	mesh_instance.mesh = cube_mesh
	
	# Material IDÊNTICO ao cubo teste que funcionou
	var material = StandardMaterial3D.new()
	var colors = [
		Color.BLUE,
		Color.GREEN, 
		Color.YELLOW,
		Color.MAGENTA,
		Color.CYAN,
		Color.ORANGE
	]
	material.albedo_color = colors[randi() % colors.size()]
	material.emission = material.albedo_color  # Mesma emissão do cubo teste
	material.emission_energy = 5.0  # Mesma energia do cubo teste
	
	mesh_instance.material_override = material
	
	# Posicionar mesh ACIMA do chão
	mesh_instance.position = Vector3(0, 1.0, 0)
	pedestrian.add_child(mesh_instance)
	
	# Adicionar texto label GIGANTE para debug
	var label = Label3D.new()
	label.text = "PEDESTRE"
	label.font_size = 100  # TEXTO GIGANTE
	label.position = Vector3(0, 4, 0)  # Bem acima da cabeça
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pedestrian.add_child(label)
	
	# Salvar como PackedScene
	scene.pack(pedestrian)
	pedestrian_models.append(scene)
	print("Created basic pedestrian model")

func _process(delta):
	simulation_time += delta
	
	# Tentar spawnar novos pedestres
	try_spawn_pedestrians()
	
	# Limpar pedestres que saíram da área
	cleanup_distant_pedestrians()

func try_spawn_pedestrians():
	# Verificar se pode spawnar mais
	if active_pedestrians.size() >= pedestrian_config.max_pedestrians:
		return
	
	# Probabilidade de spawn
	var spawn_chance = randf()
	if spawn_chance > pedestrian_config.base_spawn_rate:
		return
	
	print("DEBUG: Attempting to spawn pedestrian (chance: %.3f)" % spawn_chance)
	
	# Escolher ponto de spawn aleatório
	var spawn_point = sidewalk_spawn_points[randi() % sidewalk_spawn_points.size()]
	
	# Verificar se há espaço para spawnar
	print("DEBUG: Checking spawn position: %v" % spawn_point)
	if not can_spawn_at_position(spawn_point):
		print("DEBUG: Cannot spawn at position (too close to other pedestrians)")
		return
	
	print("DEBUG: Position is clear, spawning pedestrian")
	# Spawnar pedestre
	spawn_pedestrian(spawn_point)

func can_spawn_at_position(spawn_pos: Vector3) -> bool:
	# Verificar distância mínima de outros pedestres
	for pedestrian in active_pedestrians:
		if not is_instance_valid(pedestrian):
			continue
		
		var distance = spawn_pos.distance_to(pedestrian.global_position)
		if distance < pedestrian_config.spawn_distance:
			return false
	
	return true

func spawn_pedestrian(spawn_pos: Vector3):
	print("DEBUG: spawn_pedestrian called at %v" % spawn_pos)
	
	if pedestrian_models.is_empty():
		print("ERROR: No pedestrian models available!")
		return
	
	print("DEBUG: Available pedestrian models: %d" % pedestrian_models.size())
	
	# Instanciar modelo aleatório
	var model = pedestrian_models[randi() % pedestrian_models.size()]
	var pedestrian = model.instantiate()
	
	if not pedestrian:
		print("ERROR: Failed to instantiate pedestrian!")
		return
	
	print("DEBUG: Pedestrian instantiated successfully")
	
	# Configurar posição e orientação
	pedestrian.global_position = spawn_pos
	pedestrian.rotation.y = randf() * TAU  # Rotação aleatória
	
	# Adicionar à cena
	get_parent().add_child(pedestrian)
	active_pedestrians.append(pedestrian)
	total_pedestrians_spawned += 1
	
	print("Spawned pedestrian #%d at %v (Total: %d)" % [total_pedestrians_spawned, spawn_pos, active_pedestrians.size()])

func cleanup_distant_pedestrians():
	for i in range(active_pedestrians.size() - 1, -1, -1):
		var pedestrian = active_pedestrians[i]
		
		if not is_instance_valid(pedestrian):
			active_pedestrians.remove_at(i)
			continue
		
		# Remover se muito distante do centro
		var distance_from_center = pedestrian.global_position.distance_to(Vector3.ZERO)
		if distance_from_center > pedestrian_config.cleanup_distance:
			print("Removing distant pedestrian at distance: %.1f" % distance_from_center)
			pedestrian.queue_free()
			active_pedestrians.remove_at(i)

func get_pedestrian_count() -> int:
	return active_pedestrians.size()

func get_total_spawned() -> int:
	return total_pedestrians_spawned

# Funções para ajuste dinâmico
func set_max_pedestrians(new_max: int):
	pedestrian_config.max_pedestrians = clamp(new_max, 1, 100)
	print("Max pedestrians set to: %d" % pedestrian_config.max_pedestrians)

func set_spawn_rate(new_rate: float):
	# Permitir ajuste da taxa de spawn (0.0 - 1.0)
	pedestrian_config.base_spawn_rate = clamp(new_rate, 0.0, 1.0)
	print("Pedestrian spawn rate set to: %.3f" % pedestrian_config.base_spawn_rate)

func cleanup_all_pedestrians():
	# Remover todos os pedestres existentes
	for pedestrian in active_pedestrians:
		if is_instance_valid(pedestrian):
			pedestrian.queue_free()
	active_pedestrians.clear()
	print("Cleared all existing pedestrians")

func force_spawn_test_pedestrian():
	# TESTE DRÁSTICO: Criar um cubo GIGANTE VERMELHO que é IMPOSSÍVEL não ver
	print("=== TESTE DRÁSTICO: CUBO GIGANTE ===")
	
	var test_cube = MeshInstance3D.new()
	var cube_mesh = BoxMesh.new()
	cube_mesh.size = Vector3(5, 5, 5)  # CUBO GIGANTE 5x5x5
	test_cube.mesh = cube_mesh
	
	# Material VERMELHO BRILHANTE
	var red_material = StandardMaterial3D.new()
	red_material.albedo_color = Color.RED
	red_material.emission = Color.RED
	red_material.emission_energy = 5.0  # MUITO BRILHANTE
	test_cube.material_override = red_material
	
	# Posição CENTRAL bem alta
	test_cube.position = Vector3(0, 10, 0)  # CENTRO, 10 metros de altura
	test_cube.name = "CUBO_TESTE_GIGANTE"
	
	get_parent().add_child(test_cube)
	print("TESTE: CUBO GIGANTE VERMELHO criado no centro (0,10,0)")
	
	# TESTE 2: Criar cubo pedestre DIRETAMENTE (sem PackedScene)
	var direct_cube = MeshInstance3D.new()
	var direct_cube_mesh = BoxMesh.new()  # Nome diferente para evitar conflito
	direct_cube_mesh.size = Vector3(2, 3, 2)  # Cubo pessoa maior
	direct_cube.mesh = direct_cube_mesh
	
	# Material AZUL BRILHANTE
	var blue_material = StandardMaterial3D.new()
	blue_material.albedo_color = Color.BLUE
	blue_material.emission = Color.BLUE
	blue_material.emission_energy = 5.0
	direct_cube.material_override = blue_material
	
	# Posição bem próxima da câmera
	direct_cube.position = Vector3(8, 3, 8)  # Mais longe da intersecção
	direct_cube.name = "CUBO_PEDESTRE_DIRETO"
	
	get_parent().add_child(direct_cube)
	print("TESTE: CUBO PEDESTRE AZUL criado diretamente em (8,3,8)")
	print("TESTE: Este cubo deve ser visível - se não for, há problema com hierarquia")

func load_external_models():
	# Carregar modelo FBX do humano animado
	print("Loading external human model...")
	
	var fbx_path = "res://assets/pedestrians/FBX/Animated Human.fbx"
	
	# Verificar se o arquivo existe
	if not FileAccess.file_exists(fbx_path):
		print("FBX file not found: ", fbx_path)
		return
	
	# Carregar como recurso
	var human_resource = load(fbx_path)
	if not human_resource:
		print("Failed to load FBX resource: ", fbx_path)
		return
	
	# Criar PackedScene do modelo
	if human_resource is PackedScene:
		pedestrian_models.append(human_resource)
		print("✅ Loaded human FBX model successfully!")
	else:
		print("⚠️ FBX loaded but not as PackedScene, type: ", type_string(typeof(human_resource)))
		
		# Tentar criar PackedScene a partir do recurso
		var scene = PackedScene.new()
		var instance = human_resource.instantiate() if human_resource.has_method("instantiate") else null
		if instance:
			scene.pack(instance)
			pedestrian_models.append(scene)
			print("✅ Created PackedScene from FBX resource!")
