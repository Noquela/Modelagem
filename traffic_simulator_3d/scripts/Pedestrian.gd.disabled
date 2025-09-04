extends CharacterBody3D
class_name Pedestrian

# Identificação única
var pedestrian_id: int = 0

# Movimento e navegação
var walking_speed: float = 1.5  # m/s - velocidade humana normal
var current_destination: Vector3
var path_points: Array[Vector3] = []
var current_path_index: int = 0

# Estados do pedestre
enum WalkState {
	IDLE,
	WALKING_SIDEWALK,
	WAITING_TO_CROSS,
	CROSSING_ROAD,
	FINISHED
}
var current_state: WalkState = WalkState.IDLE

# Referências
var traffic_manager: Node
@onready var animation_player: AnimationPlayer
@onready var navigation_agent: NavigationAgent3D

# Configuração de comportamento
var personality_patience: float = 5.0  # Segundos para esperar no semáforo
var crossing_probability: float = 0.3   # 30% chance de querer atravessar
var wait_timer: float = 0.0

# Animações disponíveis
var has_walk_animation: bool = false
var has_idle_animation: bool = false

func _ready():
	pedestrian_id = randi() % 10000
	
	# Configurar navegação
	if not navigation_agent:
		navigation_agent = NavigationAgent3D.new()
		add_child(navigation_agent)
	
	navigation_agent.target_desired_distance = 0.5
	navigation_agent.navigation_finished.connect(_on_navigation_finished)
	
	# Buscar TrafficManager
	traffic_manager = get_node("/root/Main/TrafficManager")
	
	# Configurar animações se disponíveis
	setup_animations()
	
	# Escolher comportamento inicial
	choose_initial_behavior()

func setup_animations():
	# Tentar encontrar AnimationPlayer
	animation_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	
	if animation_player:
		var animation_list = animation_player.get_animation_list()
		
		# Verificar animações disponíveis
		for anim_name in animation_list:
			var anim_lower = str(anim_name).to_lower()
			if "walk" in anim_lower or "run" in anim_lower:
				has_walk_animation = true
			elif "idle" in anim_lower or "stand" in anim_lower:
				has_idle_animation = true
	
	# Debug info
	print("Pedestrian #%d: Walk=%s, Idle=%s" % [pedestrian_id, has_walk_animation, has_idle_animation])

func choose_initial_behavior():
	# Decidir se o pedestre vai apenas andar pela calçada ou tentar atravessar
	if randf() < crossing_probability:
		current_state = WalkState.WALKING_SIDEWALK  # Pode tentar atravessar depois
	else:
		current_state = WalkState.WALKING_SIDEWALK  # Só vai andar pela calçada
	
	# Definir destino inicial na calçada
	set_sidewalk_destination()

func set_sidewalk_destination():
	# DESTINOS NAS CALÇADAS - baseado na estrutura das ruas
	var sidewalk_destinations = [
		# Calçada Norte (rua horizontal norte)
		Vector3(-20, 0.1, 3.5),
		Vector3(-10, 0.1, 3.5), 
		Vector3(10, 0.1, 3.5),
		Vector3(20, 0.1, 3.5),
		
		# Calçada Sul (rua horizontal sul)  
		Vector3(-20, 0.1, -3.5),
		Vector3(-10, 0.1, -3.5),
		Vector3(10, 0.1, -3.5),
		Vector3(20, 0.1, -3.5),
		
		# Calçada Oeste (rua vertical oeste)
		Vector3(-3.5, 0.1, -15),
		Vector3(-3.5, 0.1, -5),
		Vector3(-3.5, 0.1, 5),
		Vector3(-3.5, 0.1, 15),
		
		# Calçada Leste (rua vertical leste)
		Vector3(3.5, 0.1, -15),
		Vector3(3.5, 0.1, -5),
		Vector3(3.5, 0.1, 5),
		Vector3(3.5, 0.1, 15)
	]
	
	# Escolher destino aleatório
	current_destination = sidewalk_destinations[randi() % sidewalk_destinations.size()]
	navigation_agent.target_position = current_destination
	
	print("Pedestrian #%d walking to sidewalk: %v" % [pedestrian_id, current_destination])

func _physics_process(delta):
	match current_state:
		WalkState.IDLE:
			handle_idle_state(delta)
		WalkState.WALKING_SIDEWALK:
			handle_walking_state(delta)
		WalkState.WAITING_TO_CROSS:
			handle_waiting_state(delta)
		WalkState.CROSSING_ROAD:
			handle_crossing_state(delta)
		WalkState.FINISHED:
			handle_finished_state(delta)

func handle_idle_state(_delta):
	play_idle_animation()

func handle_walking_state(delta):
	if navigation_agent.is_navigation_finished():
		# Chegou ao destino - decidir próxima ação
		decide_next_action()
		return
	
	# Movimento para o destino
	var next_position = navigation_agent.get_next_path_position()
	var direction = (next_position - global_position).normalized()
	
	velocity = direction * walking_speed
	move_and_slide()
	
	# Rotacionar para a direção do movimento
	if direction.length() > 0.1:
		var target_rotation = atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, delta * 5.0)
	
	play_walk_animation()

func handle_waiting_state(delta):
	wait_timer += delta
	play_idle_animation()
	
	# Verificar se pode atravessar
	if can_cross_street():
		current_state = WalkState.CROSSING_ROAD
		set_crossing_destination()
		wait_timer = 0.0
	elif wait_timer > personality_patience:
		# Perdeu a paciência, volta a andar pela calçada
		current_state = WalkState.WALKING_SIDEWALK
		set_sidewalk_destination()
		wait_timer = 0.0

func handle_crossing_state(delta):
	# Similar ao walking, mas através da faixa
	if navigation_agent.is_navigation_finished():
		current_state = WalkState.WALKING_SIDEWALK
		set_sidewalk_destination()
		return
	
	var next_position = navigation_agent.get_next_path_position()
	var direction = (next_position - global_position).normalized()
	
	velocity = direction * walking_speed * 1.2  # Um pouco mais rápido ao atravessar
	move_and_slide()
	
	if direction.length() > 0.1:
		var target_rotation = atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, delta * 8.0)
	
	play_walk_animation()

func handle_finished_state(_delta):
	# Pedestre pode ser removido ou respawnado
	play_idle_animation()

func decide_next_action():
	# Chegou ao destino na calçada
	var action_roll = randf()
	
	if action_roll < 0.4:  # 40% - continuar andando pela calçada
		set_sidewalk_destination()
	elif action_roll < 0.7:  # 30% - tentar atravessar a rua
		if near_crosswalk():
			current_state = WalkState.WAITING_TO_CROSS
		else:
			set_sidewalk_destination()
	else:  # 30% - ficar parado (idle)
		current_state = WalkState.IDLE
		get_tree().create_timer(2.0 + randf() * 3.0).timeout.connect(func(): 
			if current_state == WalkState.IDLE:
				current_state = WalkState.WALKING_SIDEWALK
				set_sidewalk_destination()
		)

func near_crosswalk() -> bool:
	# Verificar se está perto de uma faixa de pedestres
	var crosswalk_positions = [
		Vector3(-5.0, 0, 0),    # North crosswalk
		Vector3(5.0, 0, 0),     # South crosswalk  
		Vector3(0, 0, -7.0),    # West crosswalk
		Vector3(0, 0, 7.0)      # East crosswalk
	]
	
	for crosswalk_pos in crosswalk_positions:
		if global_position.distance_to(crosswalk_pos) < 4.0:
			return true
	return false

func can_cross_street() -> bool:
	if not traffic_manager:
		return false
	
	# Verificar qual faixa está próxima e se pode atravessar
	var pos = global_position
	
	# Norte ou Sul (atravessar rua principal)
	if abs(pos.x + 5.0) < 2.0 or abs(pos.x - 5.0) < 2.0:
		return traffic_manager.can_pedestrian_cross_main_road()
	
	# Oeste ou Leste (atravessar rua transversal)
	if abs(pos.z + 7.0) < 2.0 or abs(pos.z - 7.0) < 2.0:
		return traffic_manager.can_pedestrian_cross_cross_road()
	
	return false

func set_crossing_destination():
	# Definir destino do outro lado da rua
	var pos = global_position
	
	# Determinar qual lado da rua atravessar
	if abs(pos.x + 5.0) < 2.0:  # North crosswalk
		current_destination = Vector3(-5.0, 0.1, -6.0 if pos.z > 0 else 6.0)
	elif abs(pos.x - 5.0) < 2.0:  # South crosswalk
		current_destination = Vector3(5.0, 0.1, -6.0 if pos.z > 0 else 6.0)
	elif abs(pos.z + 7.0) < 2.0:  # West crosswalk
		current_destination = Vector3(-4.0 if pos.x > 0 else 4.0, 0.1, -7.0)
	elif abs(pos.z - 7.0) < 2.0:  # East crosswalk
		current_destination = Vector3(-4.0 if pos.x > 0 else 4.0, 0.1, 7.0)
	
	navigation_agent.target_position = current_destination

func play_walk_animation():
	if has_walk_animation and animation_player:
		if not animation_player.is_playing() or animation_player.current_animation != "walk":
			animation_player.play("walk")

func play_idle_animation():
	if has_idle_animation and animation_player:
		if not animation_player.is_playing() or animation_player.current_animation != "idle":
			animation_player.play("idle")

func _on_navigation_finished():
	# Callback quando chega ao destino
	pass

func destroy():
	print("Pedestrian #%d destroyed" % pedestrian_id)
	queue_free()
