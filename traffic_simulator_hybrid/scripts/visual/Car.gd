extends Node3D

var car_id: String = ""
var lane: String = ""
var spawn_position: Vector3
var direction: Vector3 = Vector3.ZERO
var speed: float = 5.0
var current_position: Vector3

# MOVIMENTO SUAVE
var target_position: Vector3
var is_moving_to_target: bool = false
var move_speed: float = 8.0  # velocidade de interpolação

# Car 3D model
var car_model: Node3D

# Available car models
var car_models = [
	"res://assets/vehicles/sedan.glb",
	"res://assets/vehicles/hatchback-sports.glb", 
	"res://assets/vehicles/suv.glb",
	"res://assets/vehicles/police.glb"
]

func _ready():
	create_car_visual()

func setup_car(id: String, lane_name: String, pos: Vector3, dir: Vector3):
	car_id = id
	lane = lane_name
	spawn_position = pos
	direction = dir.normalized()
	current_position = pos
	target_position = pos  # inicializar target
	
	global_position = pos
	
	# Orient car based on direction - TESTANDO ROTAÇÕES INVERTIDAS
	if dir.x > 0:  # Moving east (LEFT_TO_RIGHT)
		rotation_degrees.y = 90   # INVERTIDO: Testar se modelos estão invertidos
	elif dir.x < 0:  # Moving west (RIGHT_TO_LEFT)
		rotation_degrees.y = -90  # INVERTIDO: Testar se modelos estão invertidos
	elif dir.z > 0:  # Moving south (TOP_TO_BOTTOM) - não usado
		rotation_degrees.y = 0    # INVERTIDO: Testar se modelos estão invertidos
	elif dir.z < 0:  # Moving north (BOTTOM_TO_TOP)
		rotation_degrees.y = 180  # INVERTIDO: Testar se modelos estão invertidos
	
	print("🚗 Carro visual 3D criado: ", car_id, " em ", pos, " direção ", dir)

func create_car_visual():
	# Load random car model from assets
	var random_model = car_models[randi() % car_models.size()]
	var packed_scene = load(random_model)
	
	if packed_scene:
		car_model = packed_scene.instantiate()
		car_model.name = "CarModel"
		add_child(car_model)
		
		# Scale the car to appropriate size (assets may be different scales)
		car_model.scale = Vector3(0.4, 0.4, 0.4)  # REDUZIDO igual ao original
		
		# Apply random car color like original
		apply_car_color()
		
		print("🚗 Modelo 3D carregado: ", random_model.get_file())
	else:
		print("❌ Erro ao carregar modelo: ", random_model)

func apply_car_color():
	# CORES EXATAS DO PROJETO ORIGINAL
	var colors = [
		Color(0.8, 0.1, 0.1),          # Vermelho
		Color(0.1, 0.1, 0.8),          # Azul
		Color(0.1, 0.6, 0.1),          # Verde
		Color(0.9, 0.9, 0.9),          # Branco
		Color(0.1, 0.1, 0.1),          # Preto
		Color(0.8, 0.8, 0.1),          # Amarelo
		Color(0.5, 0.1, 0.5),          # Roxo
		Color(0.8, 0.4, 0.0),          # Laranja
		Color(0.4, 0.4, 0.4),          # Cinza médio
		Color(0.0, 0.6, 0.8),          # Azul céu
		Color(0.6, 0.0, 0.3),          # Vinho
		Color(0.3, 0.6, 0.0),          # Verde limão
		Color(0.5, 0.5, 0.0)           # Amarelo mostarda
	]
	var chosen_color = colors[randi() % colors.size()]
	
	# Apply color to car model
	if car_model:
		update_car_materials(car_model, chosen_color)

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
			
			mesh_instance.material_override = material
	
	# Recursively update children
	for child in node.get_children():
		if child is Node3D:
			update_car_materials(child, color)

func create_fallback_car():
	# Fallback simple car if 3D models fail
	var car_body = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(1.8, 0.8, 4.0)
	car_body.mesh = box_mesh
	car_body.position.y = 0.4
	
	var car_material = StandardMaterial3D.new()
	car_material.albedo_color = Color.RED
	car_body.material_override = car_material
	
	add_child(car_body)

func _process(delta):
	# MOVIMENTO SUAVE: interpolar para target_position
	if is_moving_to_target:
		var distance = global_position.distance_to(target_position)
		if distance > 0.1:  # ainda está longe do target
			global_position = global_position.move_toward(target_position, move_speed * delta)
			current_position = global_position
		else:
			# chegou no target
			global_position = target_position
			current_position = target_position
			is_moving_to_target = false

func remove_car():
	print("🚗 Removendo carro: ", car_id)
	queue_free()

func get_car_id() -> String:
	return car_id

func set_target_position(new_pos: Vector3):
	# Define nova posição alvo para movimento suave
	target_position = new_pos
	is_moving_to_target = true

func set_stopped(stopped: bool):
	# Controlar estado de parado do carro (visual feedback)
	if car_model:
		if stopped:
			# Carro parado - pode adicionar efeito visual
			pass
		else:
			# Carro em movimento
			pass