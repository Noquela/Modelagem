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
	
	# POSIÇÃO INICIAL SEGURA ACIMA DO CHÃO
	camera.position = Vector3(0, 15, 20)  # Mais baixo e mais perto
	camera.look_at(Vector3(0, 0, 0), Vector3.UP)
	
	# Usar projeção perspectiva como no HTML
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 75.0  # HTML: PerspectiveCamera(75, ...)
	camera.near = 0.1
	camera.far = 1000.0  # HTML: far = 1000
	
	# Iniciar com modo orbital (controle de mouse)
	current_mode = CameraMode.ORBITAL

func _process(delta):
	update_camera(delta)
	apply_camera_shake(delta)

func _input(event):
	# CONTROLES DE MOUSE EXATOS DO HTML - linhas 382-423
	if event is InputEventMouseButton:
		handle_mouse_click(event)
	elif event is InputEventMouseMotion:
		handle_mouse_motion(event)
	elif event.is_action_pressed("ui_camera_mode"):
		cycle_camera_mode()
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:  # Reset camera como no HTML
				reset_camera()

func handle_mouse_click(event: InputEventMouseButton):
	if current_mode != CameraMode.ORBITAL:
		return
		
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# HTML: document.addEventListener('mousedown', ...)
			is_mouse_captured = true
			mouse_delta = event.position
		else:
			# HTML: document.addEventListener('mouseup', ...)
			is_mouse_captured = false
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
		# ZOOM COM SCROLL - HTML linhas 418-422
		zoom_camera_orbital(-2.0)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_camera_orbital(2.0)

func handle_mouse_motion(event: InputEventMouseMotion):
	if current_mode != CameraMode.ORBITAL or not is_mouse_captured:
		return
	
	# LÓGICA EXATA DO HTML - linhas 396-414
	var deltaX = event.position.x - mouse_delta.x
	var deltaY = event.position.y - mouse_delta.y
	
	# Rotacionar câmera em volta da origem (HTML linha 403)
	var distance = camera.position.length()
	var phi = atan2(camera.position.z, camera.position.x) - deltaX * 0.01    # HTML linha 404
	var theta = acos(camera.position.y / distance) + deltaY * 0.01           # HTML linha 405
	
	# Limitar theta para evitar flip
	theta = clamp(theta, 0.1, PI - 0.1)
	
	# HTML: linhas 407-409
	camera.position.x = distance * sin(theta) * cos(phi)
	camera.position.y = distance * cos(theta)
	camera.position.z = distance * sin(theta) * sin(phi)
	
	# HTML: camera.lookAt(0, 0, 0) - linha 411
	camera.look_at(Vector3.ZERO, Vector3.UP)
	
	# HTML: linhas 413-414
	mouse_delta = event.position

func zoom_camera_orbital(delta_zoom: float):
	# FUNÇÃO EXATA DO HTML - linhas 418-422
	var distance = camera.position.length()
	var newDistance = clamp(distance + delta_zoom, 10.0, 50.0)  # HTML linha 420
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
	# DESABILITAR ROTAÇÃO AUTOMÁTICA - apenas controle manual com mouse
	# orbit_angle += orbit_speed * delta
	
	# Manter posição fixa se não há input do mouse
	if not is_mouse_captured:
		return
	
	var intersection_center = Vector3.ZERO
	camera.look_at(intersection_center, Vector3.UP)

func update_free_look_camera(delta):
	# Mouse look - aplicar rotação apenas na câmera
	if mouse_delta.length() > 0:
		# Rotação horizontal (Y) no nó pai
		rotate_y(-mouse_delta.x * look_sensitivity * delta)
		
		# Rotação vertical (X) apenas na câmera
		camera.rotation.x += -mouse_delta.y * look_sensitivity * delta
		
		# Clamp vertical rotation para evitar gimbal lock
		camera.rotation.x = clamp(camera.rotation.x, -PI/2 + 0.1, PI/2 - 0.1)
		
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

func update_top_down_camera(_delta):
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
	# Reset rotações para evitar orientação estranha
	rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	
	# Posição inicial do modo livre
	global_position = Vector3(15, 10, 15)
	camera.position = Vector3.ZERO  # Câmera no centro do nó pai
	
	# Olhar para o centro da interseção
	look_at(Vector3.ZERO, Vector3.UP)
	
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

func apply_camera_shake(_delta: float):
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

func focus_on_position(target_position: Vector3, distance: float = 15.0):
	if current_mode == CameraMode.FREE_LOOK:
		var direction = (camera.global_position - target_position).normalized()
		camera.global_position = target_position + direction * distance
		camera.look_at(target_position, Vector3.UP)