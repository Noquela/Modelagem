extends Node3D

enum LightState {
	RED,
	YELLOW, 
	GREEN
}

# Light nodes will be created programmatically
var red_light: Node3D
var yellow_light: Node3D  
var green_light: Node3D

var current_state: LightState = LightState.RED
var state_timer: float = 0.0
var cycle_position: float = 0.0

# Traffic light timing - EXATO DO SISTEMA DISCRETO (40s total cycle)
const CYCLE_DURATION = 40.0
const MAIN_GREEN_DURATION = 20.0    # 0-20s
const MAIN_YELLOW_DURATION = 3.0    # 20-23s  
const SAFETY1_DURATION = 1.0        # 23-24s
const CROSS_GREEN_DURATION = 10.0   # 24-34s
const CROSS_YELLOW_DURATION = 3.0   # 34-37s
const SAFETY2_DURATION = 3.0        # 37-40s

# Direction configuration
var direction: String = "North"
var is_main_road: bool = true  # North-South is main road

func _ready():
	create_traffic_light_geometry()
	
	# INICIAR NO ESTADO CORRETO - Main road GREEN, Cross road RED
	if is_main_road:
		current_state = LightState.GREEN
	else:
		current_state = LightState.RED
	
	update_light_display()
	set_physics_process(true)

func _physics_process(delta):
	update_light_cycle(delta)

func create_traffic_light_geometry():
	# ESTRUTURA EXATA DO HTML - linhas 252-275
	var pole = Node3D.new()
	pole.name = "Pole"
	add_child(pole)
	
	# Poste principal (HTML linha 252-257)
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
	pole.add_child(pole_mesh)
	
	# Haste horizontal que se estende para a rua (HTML linha 259-266)
	var arm_mesh = MeshInstance3D.new()
	var arm_cylinder = CylinderMesh.new()
	arm_cylinder.top_radius = 0.05
	arm_cylinder.bottom_radius = 0.05
	arm_cylinder.height = 3.0
	arm_mesh.mesh = arm_cylinder
	arm_mesh.rotation_degrees.z = 90  # HTML: arm.rotation.z = Math.PI / 2
	arm_mesh.position = Vector3(1.5, 4.0, 0)  # HTML: arm.position.set(1.5, 4, 0)
	arm_mesh.material_override = pole_material
	pole.add_child(arm_mesh)
	
	# Caixa do semáforo na ponta da haste (HTML linha 268-274)
	var housing = MeshInstance3D.new()
	var housing_mesh = BoxMesh.new()
	housing_mesh.size = Vector3(0.6, 1.8, 0.3)  # HTML: BoxGeometry(0.6, 1.8, 0.3)
	housing.mesh = housing_mesh
	housing.position = Vector3(3.0, 4.0, 0)  # HTML: box.position.set(3, 4, 0)
	
	var housing_material = StandardMaterial3D.new()
	housing_material.albedo_color = Color(0.2, 0.2, 0.2)  # HTML: 0x333333
	housing.material_override = housing_material
	pole.add_child(housing)
	
	# Luzes na ponta da haste (HTML linha 277-280)
	red_light = create_light(Vector3(3.0, 4.5, 0.15), Color.RED)    # HTML: createLight(0xFF0000, 3, 4.5, 0.15)
	red_light.name = "RedLight"
	yellow_light = create_light(Vector3(3.0, 4.0, 0.15), Color.YELLOW) # HTML: createLight(0xFFFF00, 3, 4, 0.15)
	yellow_light.name = "YellowLight"
	green_light = create_light(Vector3(3.0, 3.5, 0.15), Color.GREEN)   # HTML: createLight(0x00FF00, 3, 3.5, 0.15)
	green_light.name = "GreenLight"
	
	pole.add_child(red_light)
	pole.add_child(yellow_light) 
	pole.add_child(green_light)

func create_light(pos: Vector3, color: Color) -> Node3D:
	var light_node = Node3D.new()
	light_node.position = pos
	
	# Light mesh - BOLA OVAL (elipsoide) em vez de esfera
	var mesh_instance = MeshInstance3D.new()
	var ellipsoid = SphereMesh.new()
	ellipsoid.radius = 0.18  # Maior
	ellipsoid.height = 0.24  # Mais alta que larga = formato oval
	mesh_instance.mesh = ellipsoid
	
	# Light material - COMEÇAR ESCURO (será controlado por set_light_emission)
	var material = StandardMaterial3D.new()
	material.albedo_color = color * 0.3  # Começar bem escuro
	material.emission = Color.BLACK      # Sem emissão inicialmente
	material.emission_energy = 0.0       # Sem energia
	material.rim = 0.1
	material.rim_tint = 0.1
	material.metallic = 0.8              # Mais metálico para reflexos
	material.roughness = 0.2             # Mais polido
	mesh_instance.material_override = material
	
	# Actual light source - COMEÇAR DESLIGADO
	var omni_light = OmniLight3D.new()
	omni_light.light_color = color
	omni_light.light_energy = 0.0        # Começar desligado
	omni_light.omni_range = 10.0         # Range maior
	omni_light.omni_attenuation = 0.7    # Atenuação suave
	
	light_node.add_child(mesh_instance)
	light_node.add_child(omni_light)
	
	return light_node

func update_light_cycle(delta: float):
	cycle_position += delta
	if cycle_position >= CYCLE_DURATION:
		cycle_position = 0.0
	
	# Determine current state based on cycle position and road type
	var new_state = get_state_for_time(cycle_position)
	
	if new_state != current_state:
		current_state = new_state
		update_light_display()

func get_state_for_time(time: float) -> LightState:
	# CICLO EXATO: Main road (west_east/east_west) vs Cross road (south_north)
	
	if is_main_road:
		# Rua principal (west_east, east_west)
		if time < 20.0:     # 0-20s: GREEN
			return LightState.GREEN
		elif time < 23.0:   # 20-23s: YELLOW
			return LightState.YELLOW
		else:               # 23-40s: RED
			return LightState.RED
	else:
		# Rua transversal (south_north)
		if time < 24.0:     # 0-24s: RED
			return LightState.RED
		elif time < 34.0:   # 24-34s: GREEN
			return LightState.GREEN
		elif time < 37.0:   # 34-37s: YELLOW
			return LightState.YELLOW
		else:               # 37-40s: RED (safety)
			return LightState.RED

func update_light_display():
	# Turn off all lights first
	set_light_emission(red_light, false)
	set_light_emission(yellow_light, false)
	set_light_emission(green_light, false)
	
	# Turn on current state light
	match current_state:
		LightState.RED:
			set_light_emission(red_light, true)
		LightState.YELLOW:
			set_light_emission(yellow_light, true)
		LightState.GREEN:
			set_light_emission(green_light, true)

func set_light_emission(light: Node3D, active: bool):
	if not light:
		return
		
	var mesh_instance = light.get_child(0) as MeshInstance3D
	var omni_light = light.get_child(1) as OmniLight3D
	
	if mesh_instance and mesh_instance.material_override:
		var material = mesh_instance.material_override as StandardMaterial3D
		var base_color = Color.RED if "Red" in light.name else (Color.YELLOW if "Yellow" in light.name else Color.GREEN)
		
		if active:
			# LUZ ATIVA - SUPER BRILHANTE E LUMINOSA
			material.albedo_color = base_color * 1.2        # Cor mais saturada
			material.emission = base_color * 3.0            # Emissão muito forte
			material.emission_energy = 8.0                  # Energia máxima
			material.rim = 1.0                              # Rim lighting total
			material.rim_tint = 1.0                         # Rim tint máximo
			material.metallic = 0.3                         # Menos metálico quando aceso
			material.roughness = 0.1                        # Mais polido
		else:
			# LUZ INATIVA - MUITO ESCURA E OPACA
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

func get_current_state() -> LightState:
	return current_state

func is_green() -> bool:
	return current_state == LightState.GREEN

func is_red() -> bool:
	return current_state == LightState.RED

func is_yellow() -> bool:
	return current_state == LightState.YELLOW

func set_direction(dir: String):
	direction = dir
	# North-South is main road, East-West is cross road
	is_main_road = (dir == "North" or dir == "South")

# FUNÇÃO CRÍTICA DO HTML - LINHA 360-380
func set_light_state(state_string: String):
	# Reset all lights (HTML linha 361-364)
	set_light_emission(red_light, false)
	set_light_emission(yellow_light, false) 
	set_light_emission(green_light, false)
	
	# Set active light (HTML linha 366-377)
	match state_string.to_lower():
		"red":
			current_state = LightState.RED
			set_light_emission(red_light, true)
		"yellow":
			current_state = LightState.YELLOW
			set_light_emission(yellow_light, true)
		"green":
			current_state = LightState.GREEN
			set_light_emission(green_light, true)