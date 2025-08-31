extends Node3D

@onready var traffic_manager = $TrafficManager
@onready var camera_controller = $CameraController
@onready var ui = $UI
@onready var spawn_system = $SpawnSystem
@onready var analytics = $Analytics

var is_running: bool = true

func _ready():
	print("Traffic Simulator 3D - Starting initialization...")
	setup_environment()
	setup_traffic_lights()
	setup_spawn_points()
	connect_signals()
	print("Traffic Simulator 3D - Ready!")

func _input(event):
	if event.is_action_pressed("ui_pause"):
		toggle_pause()
	elif event.is_action_pressed("ui_camera_mode"):
		camera_controller.cycle_camera_mode()

func setup_environment():
	# Create intersection geometry
	create_intersection()
	setup_lighting()

func create_intersection():
	# LAYOUT EXATO DO HTML:
	# Rua PRINCIPAL (horizontal/East-West) - LARGA (2 mãos, 4 faixas)
	var road_main = create_road_segment(
		Vector3(-50, 0, 0), 
		Vector3(50, 0, 0), 
		8.0  # 8 metros de largura (4 faixas: 2 para cada direção)
	)
	road_main.name = "MainRoad_EastWest"
	add_child(road_main)
	
	# Rua TRANSVERSAL (vertical/North-South) - ESTREITA (mão única)
	var road_cross = create_road_segment(
		Vector3(0, 0, -50),
		Vector3(0, 0, 50), 
		4.0  # 4 metros de largura (apenas TOP_TO_BOTTOM)
	)
	road_cross.name = "CrossRoad_NorthSouth"
	add_child(road_cross)
	
	# Lane markings
	create_lane_markings()

func create_road_segment(start: Vector3, end: Vector3, width: float) -> Node3D:
	var road = Node3D.new()
	road.name = "Road"
	
	# Create road mesh
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3((end - start).length(), 0.1, width)
	mesh_instance.mesh = box_mesh
	
	# Position road
	road.position = (start + end) / 2
	if start.x != end.x:  # East-West road
		road.rotation_degrees.y = 90
	
	# Add material (asphalt)
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.2, 0.2)
	material.roughness = 0.8
	mesh_instance.material_override = material
	
	road.add_child(mesh_instance)
	return road

func create_lane_markings():
	# Implementation for lane markings
	pass

func setup_lighting():
	# Directional light (sun)
	var sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.position = Vector3(10, 15, 10)
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 1.0
	add_child(sun)
	
	# Environment lighting
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = ProceduralSkyMaterial.new()
	
	var world_env = Node3D.new()
	world_env.name = "Environment"
	add_child(world_env)

func setup_traffic_lights():
	# APENAS 3 SEMÁFOROS como no HTML original:
	
	# Semáforo 1: Controla LEFT_TO_RIGHT (West → East)
	create_traffic_light(Vector3(-6, 0, 6), 90, "main_road_west")
	
	# Semáforo 2: Controla RIGHT_TO_LEFT (East → West)  
	create_traffic_light(Vector3(6, 0, -6), -90, "main_road_east")
	
	# Semáforo 3: Controla TOP_TO_BOTTOM (North → South, mão única)
	create_traffic_light(Vector3(-6, 0, -6), 0, "cross_road_north")

func create_traffic_light(pos: Vector3, rotation_y: float, direction: String) -> Node3D:
	var light_scene = preload("res://scenes/TrafficLight.tscn")
	var light = light_scene.instantiate()
	light.name = "TrafficLight_" + direction
	light.position = pos
	light.rotation_degrees.y = rotation_y
	add_child(light)
	
	traffic_manager.register_traffic_light(light)
	return light

func setup_spawn_points():
	# Create spawn points for each direction
	var spawn_points = [
		{"pos": Vector3(0, 0, -15), "dir": Vector3(0, 0, 1), "name": "North_Entry"},
		{"pos": Vector3(0, 0, 15), "dir": Vector3(0, 0, -1), "name": "South_Entry"},
		{"pos": Vector3(-15, 0, 0), "dir": Vector3(1, 0, 0), "name": "East_Entry"},
		{"pos": Vector3(15, 0, 0), "dir": Vector3(-1, 0, 0), "name": "West_Entry"}
	]
	
	for point in spawn_points:
		var spawn = Node3D.new()
		spawn.name = point.name
		spawn.position = point.pos
		spawn.set_meta("direction", point.dir)
		add_child(spawn)
		traffic_manager.register_spawn_point(spawn)

func connect_signals():
	traffic_manager.stats_updated.connect(_on_stats_updated)

func _on_stats_updated(stats: Dictionary):
	analytics.update_display(stats)

func toggle_pause():
	traffic_manager.pause_simulation()
	is_running = !is_running

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("Traffic Simulator 3D - Shutting down...")
		get_tree().quit()