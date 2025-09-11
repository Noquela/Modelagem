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

# Orbital camera parameters
var intersection_center = Vector3.ZERO
var mouse_sensitivity = 0.001
var zoom_sensitivity = 2.0
var min_distance = 5.0
var max_distance = 100.0

# Mouse control
var is_mouse_captured = false
var last_mouse_position = Vector2.ZERO

# Free look parameters
var move_speed = 10.0
var look_sensitivity = 2.0

# Follow camera parameters
var follow_target = null
var follow_distance = 10.0
var follow_height = 5.0
var follow_smoothing = 5.0

# Camera shake
var shake_intensity = 0.0
var shake_duration = 0.0

func _ready():
	setup_camera()
	add_to_group("camera_controller")

func setup_camera():
	if not camera:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		add_child(camera)
	
	camera.position = Vector3(0, 15, 20)  # Mais baixo e mais perto
	camera.look_at(Vector3(0, 0, 0), Vector3.UP)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 75.0  # HTML: PerspectiveCamera(75, ...)
	camera.near = 0.1
	camera.far = 1000.0  # HTML: far = 1000
	
	current_mode = CameraMode.ORBITAL

func _process(delta):
	update_camera(delta)
	apply_camera_shake(delta)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_mouse_captured = true
				last_mouse_position = event.position
			else:
				is_mouse_captured = false
		elif event.is_action_pressed("ui_camera_mode"):
			cycle_camera_mode()
	
	elif event is InputEventMouseMotion and is_mouse_captured:
		if current_mode == CameraMode.ORBITAL:
			var deltaX = event.position.x - last_mouse_position.x
			var deltaY = event.position.y - last_mouse_position.y
			orbit_camera_mouse(deltaX, deltaY)
		last_mouse_position = event.position
	
	elif event is InputEventKey:
		if event.pressed:
			match event.keycode:
				KEY_R:  # Reset camera como no HTML
					reset_camera()

func _unhandled_input(event):
	if current_mode != CameraMode.ORBITAL:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_camera_orbital(-2.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_camera_orbital(2.0)

func orbit_camera_mouse(deltaX: float, deltaY: float):
	if current_mode != CameraMode.ORBITAL or not is_mouse_captured:
		return
	
	# HTML equivalente - linhas 404-411
	var distance = camera.position.length()
	var phi = atan2(camera.position.z, camera.position.x) - deltaX * 0.01    # HTML linha 404
	var theta = acos(camera.position.y / distance) + deltaY * 0.01           # HTML linha 405
	
	# Clamp theta para evitar inversão
	theta = clamp(theta, 0.1, PI - 0.1)
	
	# Atualizar posição da câmera
	camera.position.x = distance * sin(theta) * cos(phi)
	camera.position.y = distance * cos(theta)
	camera.position.z = distance * sin(theta) * sin(phi)
	
	# HTML: camera.lookAt(0, 0, 0) - linha 411
	camera.look_at(Vector3.ZERO, Vector3.UP)

func zoom_camera_orbital(delta_zoom: float):
	var distance = camera.position.length()
	var newDistance = clamp(distance + delta_zoom, min_distance, max_distance)
	camera.position = camera.position * (newDistance / distance)  # HTML linha 421

func reset_camera():
	# FUNÇÃO DO HTML - função resetCamera() linhas 455-458
	camera.position = Vector3(0, 25, 25)  # HTML: camera.position.set(0, 25, 25)
	camera.look_at(Vector3.ZERO, Vector3.UP)  # HTML: camera.lookAt(0, 0, 0)

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

func update_orbital_camera(_delta):
	# Mantém a câmera sempre olhando para o centro
	camera.look_at(intersection_center, Vector3.UP)

func update_free_look_camera(delta):
	if is_mouse_captured:
		var mouse_delta = Input.get_last_mouse_velocity() * mouse_sensitivity
		rotation.y += -mouse_delta.x * look_sensitivity * delta
		camera.rotation.x += -mouse_delta.y * look_sensitivity * delta
		camera.rotation.x = clamp(camera.rotation.x, -PI/2 + 0.1, PI/2 - 0.1)
	
	var input_dir = Vector3()
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
	if not follow_target:
		return
	
	var target_position = follow_target.global_position + Vector3(0, follow_height, follow_distance)
	var target_look_at = follow_target.global_position
	
	# Smooth camera movement
	camera.global_position = camera.global_position.lerp(target_position, follow_smoothing * delta)
	var look_direction = (target_look_at - camera.global_position).normalized()
	if look_direction.length() > 0.1:
		var target_transform = camera.global_transform.looking_at(target_look_at, Vector3.UP)
		camera.global_transform = camera.global_transform.interpolate_with(target_transform, follow_smoothing * delta)

func update_top_down_camera(_delta):
	camera.global_position = intersection_center + Vector3(0, 50, 0)
	camera.look_at(intersection_center, Vector3(0, 0, -1))

func update_cinematic_camera(delta):
	var time = Time.get_time_dict_from_system()["second"] + Time.get_time_dict_from_system()["millisecond"] / 1000.0
	var radius = 30.0
	var height = 20.0
	var target_pos = Vector3(sin(time * 0.5) * radius, height, cos(time * 0.5) * radius)
	
	camera.global_position = camera.global_position.lerp(target_pos, 2.0 * delta)
	camera.look_at(Vector3.ZERO, Vector3.UP)

func cycle_camera_mode():
	var modes = CameraMode.values()
	var current_index = modes.find(current_mode)
	var next_index = (current_index + 1) % modes.size()
	set_camera_mode(modes[next_index])

func set_camera_mode(mode: CameraMode):
	current_mode = mode
	is_mouse_captured = false
	
	match mode:
		CameraMode.ORBITAL:
			reset_camera()
		CameraMode.FREE_LOOK:
			pass
		CameraMode.FOLLOW_CAR:
			pass
		CameraMode.TOP_DOWN:
			pass
		CameraMode.CINEMATIC:
			pass
	
	print("Camera mode changed to: ", CameraMode.keys()[mode])

func center_camera_on_node(node: Node3D):
	if not node:
		return
	
	camera.rotation = Vector3.ZERO
	camera.position = Vector3.ZERO  # Câmera no centro do nó pai

func zoom_camera(amount: float):
	match current_mode:
		CameraMode.ORBITAL:
			zoom_camera_orbital(amount)
		CameraMode.TOP_DOWN:
			camera.global_position.y = clamp(camera.global_position.y + amount, 20.0, 100.0)

func shake_camera(intensity: float):
	shake_intensity = intensity
	shake_duration = 0.5

func apply_camera_shake(_delta: float):
	if shake_intensity > 0:
		var shake_offset = Vector3(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity), 0)
		camera.position += shake_offset
		shake_intensity *= 0.9
		if shake_intensity < 0.01:
			shake_intensity = 0

func get_current_camera() -> Camera3D:
	return camera

func get_camera_mode_string() -> String:
	return CameraMode.keys()[current_mode]

func set_follow_target(target: Node3D):
	follow_target = target
	if current_mode == CameraMode.FREE_LOOK:
		var distance = 15.0
		var target_position = target.global_position + Vector3(0, 8, distance)
		var direction = (camera.global_position - target_position).normalized()
		camera.global_position = target_position + direction * distance
		camera.look_at(target_position, Vector3.UP)