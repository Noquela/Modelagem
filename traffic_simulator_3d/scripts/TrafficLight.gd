extends Node3D

enum LightState {
	RED,
	YELLOW, 
	GREEN
}

@onready var red_light = $Pole/RedLight
@onready var yellow_light = $Pole/YellowLight  
@onready var green_light = $Pole/GreenLight

var current_state: LightState = LightState.RED
var state_timer: float = 0.0
var cycle_position: float = 0.0

# Traffic light timing (based on your HTML - 37s total cycle)
const CYCLE_DURATION = 37.0
const GREEN_DURATION = 15.0
const YELLOW_DURATION = 3.0
const RED_DURATION = 15.0
const ALL_RED_DURATION = 4.0  # Safety buffer

# Direction configuration
var direction: String = "North"
var is_main_road: bool = true  # North-South is main road

func _ready():
	create_traffic_light_geometry()
	set_physics_process(true)

func _physics_process(delta):
	update_light_cycle(delta)

func create_traffic_light_geometry():
	# Create pole
	var pole = Node3D.new()
	pole.name = "Pole"
	add_child(pole)
	
	var pole_mesh = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.1
	cylinder.bottom_radius = 0.1
	cylinder.height = 4.0
	pole_mesh.mesh = cylinder
	pole_mesh.position.y = 2.0
	
	var pole_material = StandardMaterial3D.new()
	pole_material.albedo_color = Color(0.3, 0.3, 0.3)
	pole_mesh.material_override = pole_material
	pole.add_child(pole_mesh)
	
	# Create light housing
	var housing = MeshInstance3D.new()
	var housing_mesh = BoxMesh.new()
	housing_mesh.size = Vector3(0.4, 1.2, 0.3)
	housing.mesh = housing_mesh
	housing.position = Vector3(0, 4.5, 0)
	
	var housing_material = StandardMaterial3D.new()
	housing_material.albedo_color = Color(0.1, 0.1, 0.1)
	housing.material_override = housing_material
	pole.add_child(housing)
	
	# Create individual lights
	red_light = create_light(Vector3(0, 5.0, 0), Color.RED)
	yellow_light = create_light(Vector3(0, 4.5, 0), Color.YELLOW)
	green_light = create_light(Vector3(0, 4.0, 0), Color.GREEN)
	
	pole.add_child(red_light)
	pole.add_child(yellow_light) 
	pole.add_child(green_light)

func create_light(pos: Vector3, color: Color) -> Node3D:
	var light_node = Node3D.new()
	light_node.position = pos
	
	# Light mesh (sphere)
	var mesh_instance = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.08
	mesh_instance.mesh = sphere
	
	# Light material
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission = color * 0.5
	mesh_instance.material_override = material
	
	# Actual light source
	var omni_light = OmniLight3D.new()
	omni_light.light_color = color
	omni_light.light_energy = 0.5
	omni_light.omni_range = 5.0
	
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
	# Main road (North-South) gets green first
	# Cross road (East-West) gets green second
	
	if is_main_road:
		if time < GREEN_DURATION:
			return LightState.GREEN
		elif time < GREEN_DURATION + YELLOW_DURATION:
			return LightState.YELLOW
		else:
			return LightState.RED
	else:
		# Cross road is offset by main road cycle + safety buffer
		var offset_time = time - (GREEN_DURATION + YELLOW_DURATION + 1.0)  # 1s safety
		if offset_time < 0:
			return LightState.RED
		elif offset_time < GREEN_DURATION:
			return LightState.GREEN
		elif offset_time < GREEN_DURATION + YELLOW_DURATION:
			return LightState.YELLOW
		else:
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
		if active:
			material.emission = material.albedo_color
			material.emission_energy = 2.0
		else:
			material.emission = Color.BLACK
			material.emission_energy = 0.0
	
	if omni_light:
		omni_light.light_energy = 2.0 if active else 0.0

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