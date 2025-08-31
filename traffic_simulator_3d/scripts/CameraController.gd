extends Node3D

enum CameraMode {
	ORBITAL,
	FREE_LOOK,
	FOLLOW_CAR,
	TOP_DOWN,
	CINEMATIC
}

@onready var camera = $Camera3D
var current_mode: CameraMode = CameraMode.ORBITAL
var target_car: Node3D = null

# Orbital camera parameters
var orbit_radius: float = 20.0
var orbit_height: float = 15.0
var orbit_speed: float = 0.5
var orbit_angle: float = 0.0

# Free look parameters
var look_sensitivity: float = 2.0
var move_speed: float = 15.0
var zoom_speed: float = 5.0

# Follow car parameters
var follow_offset: Vector3 = Vector3(0, 8, -12)
var follow_smoothing: float = 5.0

# Input tracking
var mouse_delta: Vector2 = Vector2.ZERO
var is_mouse_captured: bool = false

# Camera shake
var shake_intensity: float = 0.0
var shake_decay: float = 0.95

func _ready():
	setup_camera()
	add_to_group("camera_controller")
	set_process_input(true)

func setup_camera():
	if not camera:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		add_child(camera)
	
	camera.fov = 75.0
	camera.near = 0.1
	camera.far = 500.0
	
	set_orbital_mode()

func _process(delta):
	update_camera(delta)
	apply_camera_shake(delta)

func _input(event):
	if event is InputEventMouseMotion and is_mouse_captured:
		mouse_delta = event.relative
	
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			capture_mouse()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			release_mouse()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_camera(-zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_camera(zoom_speed)
	
	elif event.is_action_pressed("ui_camera_mode"):
		cycle_camera_mode()
	
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				set_camera_mode(CameraMode.ORBITAL)
			KEY_2:
				set_camera_mode(CameraMode.FREE_LOOK)
			KEY_3:
				set_camera_mode(CameraMode.FOLLOW_CAR)
			KEY_4:
				set_camera_mode(CameraMode.TOP_DOWN)
			KEY_5:
				set_camera_mode(CameraMode.CINEMATIC)

func update_camera(delta):
	match current_mode:
		CameraMode.ORBITAL:
			update_orbital_camera(delta)
		CameraMode.FREE_LOOK:
			update_free_look_camera(delta)
		CameraMode.FOLLOW_CAR:
			update_follow_camera(delta)
		CameraMode.TOP_DOWN:
			update_top_down_camera(delta)
		CameraMode.CINEMATIC:
			update_cinematic_camera(delta)

func update_orbital_camera(delta):
	orbit_angle += orbit_speed * delta
	
	var intersection_center = Vector3.ZERO
	var x = sin(orbit_angle) * orbit_radius
	var z = cos(orbit_angle) * orbit_radius
	
	camera.global_position = intersection_center + Vector3(x, orbit_height, z)
	camera.look_at(intersection_center, Vector3.UP)

func update_free_look_camera(delta):
	# Mouse look
	if mouse_delta.length() > 0:
		rotate_y(-mouse_delta.x * look_sensitivity * delta)
		camera.rotate_x(-mouse_delta.y * look_sensitivity * delta)
		
		# Clamp vertical rotation
		var x_rot = camera.rotation.x
		x_rot = clamp(x_rot, -PI/2 + 0.1, PI/2 - 0.1)
		camera.rotation.x = x_rot
		
		mouse_delta = Vector2.ZERO
	
	# WASD movement
	var input_dir = Vector3.ZERO
	if Input.is_action_pressed("ui_camera_forward"):
		input_dir -= camera.transform.basis.z
	if Input.is_action_pressed("ui_camera_back"):
		input_dir += camera.transform.basis.z
	if Input.is_action_pressed("ui_camera_left"):
		input_dir -= camera.transform.basis.x
	if Input.is_action_pressed("ui_camera_right"):
		input_dir += camera.transform.basis.x
	
	if input_dir.length() > 0:
		input_dir = input_dir.normalized()
		camera.global_position += input_dir * move_speed * delta

func update_follow_camera(delta):
	if not target_car or not is_instance_valid(target_car):
		find_random_car()
		if not target_car:
			return
	
	var target_position = target_car.global_position + follow_offset
	var target_look_at = target_car.global_position
	
	# Smooth camera movement
	camera.global_position = camera.global_position.lerp(target_position, follow_smoothing * delta)
	
	# Look at car
	var look_direction = (target_look_at - camera.global_position).normalized()
	if look_direction.length() > 0:
		var target_transform = camera.global_transform.looking_at(target_look_at, Vector3.UP)
		camera.global_transform = camera.global_transform.interpolate_with(target_transform, follow_smoothing * delta)

func update_top_down_camera(delta):
	var intersection_center = Vector3.ZERO
	camera.global_position = intersection_center + Vector3(0, 50, 0)
	camera.look_at(intersection_center, Vector3(0, 0, -1))

func update_cinematic_camera(delta):
	# Cycle between different cinematic angles
	var time = Time.get_time_dict_from_system()["second"]
	var angle_index = int(time / 10) % 4
	
	var cinematic_positions = [
		Vector3(25, 10, 25),
		Vector3(-25, 15, 25), 
		Vector3(25, 8, -25),
		Vector3(-25, 20, -25)
	]
	
	var target_pos = cinematic_positions[angle_index]
	camera.global_position = camera.global_position.lerp(target_pos, 2.0 * delta)
	camera.look_at(Vector3.ZERO, Vector3.UP)

func cycle_camera_mode():
	var modes = CameraMode.values()
	var current_index = modes.find(current_mode)
	var next_index = (current_index + 1) % modes.size()
	set_camera_mode(modes[next_index])

func set_camera_mode(mode: CameraMode):
	current_mode = mode
	release_mouse()
	
	match mode:
		CameraMode.ORBITAL:
			set_orbital_mode()
		CameraMode.FREE_LOOK:
			set_free_look_mode()
		CameraMode.FOLLOW_CAR:
			set_follow_car_mode()
		CameraMode.TOP_DOWN:
			set_top_down_mode()
		CameraMode.CINEMATIC:
			set_cinematic_mode()
	
	print("Camera mode changed to: ", CameraMode.keys()[mode])

func set_orbital_mode():
	orbit_angle = 0.0
	orbit_radius = 20.0
	orbit_height = 15.0

func set_free_look_mode():
	camera.global_position = Vector3(15, 10, 15)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	capture_mouse()

func set_follow_car_mode():
	find_random_car()

func set_top_down_mode():
	pass  # Handled in update

func set_cinematic_mode():
	pass  # Handled in update

func find_random_car():
	var cars = get_tree().get_nodes_in_group("cars")
	if cars.size() > 0:
		target_car = cars[randi() % cars.size()]
	else:
		target_car = null

func capture_mouse():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	is_mouse_captured = true

func release_mouse():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	is_mouse_captured = false

func zoom_camera(amount: float):
	match current_mode:
		CameraMode.ORBITAL:
			orbit_radius = clamp(orbit_radius + amount, 5.0, 50.0)
		CameraMode.TOP_DOWN:
			camera.global_position.y = clamp(camera.global_position.y + amount, 20.0, 100.0)

func shake_camera(intensity: float):
	shake_intensity = intensity

func apply_camera_shake(delta: float):
	if shake_intensity > 0.01:
		var shake_offset = Vector3(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		
		camera.position += shake_offset
		shake_intensity *= shake_decay
	else:
		shake_intensity = 0.0

func get_current_camera() -> Camera3D:
	return camera

func get_camera_mode_string() -> String:
	return CameraMode.keys()[current_mode]

func focus_on_position(position: Vector3, distance: float = 15.0):
	if current_mode == CameraMode.FREE_LOOK:
		var direction = (camera.global_position - position).normalized()
		camera.global_position = position + direction * distance
		camera.look_at(position, Vector3.UP)