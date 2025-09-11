# scripts/hybrid/HybridRenderer.gd
class_name HybridRenderer
extends Node

## Ponte entre sistema discreto e visualização 3D

var visual_world: Node3D
var active_visual_cars: Dictionary = {}  # car_id -> Node3D
var car_scene = preload("res://scenes/Car.tscn")

signal visual_car_created(car_id: int)
signal visual_car_destroyed(car_id: int)

func _ready():
	print("🌉 HybridRenderer initialized")

func setup_connections(world: Node3D, scheduler: DiscreteEventScheduler):
	"""Conecta o renderer ao mundo 3D e sistema discreto"""
	visual_world = world
	
	# Conectar eventos discretos
	if scheduler:
		scheduler.event_executed.connect(_on_discrete_event)
	
	print("🌉 HybridRenderer connected to world and scheduler")

func _on_discrete_event(event):
	"""Processa eventos discretos e cria ações visuais"""
	match event.type:
		DiscreteEventScheduler.EventType.CAR_SPAWN:
			handle_visual_car_spawn(event.data)
		DiscreteEventScheduler.EventType.CAR_ARRIVE_INTERSECTION:
			handle_visual_car_movement(event.data, "arrive_intersection")
		DiscreteEventScheduler.EventType.CAR_START_WAITING:
			handle_visual_car_movement(event.data, "start_waiting")
		DiscreteEventScheduler.EventType.CAR_START_CROSSING:
			handle_visual_car_movement(event.data, "start_crossing")
		DiscreteEventScheduler.EventType.CAR_EXIT_INTERSECTION:
			handle_visual_car_movement(event.data, "exit_intersection")
		DiscreteEventScheduler.EventType.CAR_EXIT_MAP:
			handle_visual_car_exit(event.data)
		DiscreteEventScheduler.EventType.LIGHT_CHANGE:
			handle_visual_light_change(event.data)

func handle_visual_car_spawn(event_data: Dictionary):
	"""Criar carro visual quando discreto spawna"""
	var car_id = event_data.car_id
	var direction = event_data.direction
	
	# Criar carro visual 3D
	var car_3d = car_scene.instantiate()
	
	# Configurar posição inicial ANTES de adicionar ao mundo
	var spawn_pos = get_spawn_position_3d(direction)
	print("🎯 Spawning car %d at position: %s" % [car_id, spawn_pos])
	car_3d.global_position = spawn_pos
	car_3d.rotation.y = get_spawn_rotation(direction)
	
	# Adicionar ao mundo 3D primeiro
	visual_world.add_child(car_3d)
	
	# Configurar propriedades APÓS adicionar ao mundo (quando _ready roda)
	call_deferred("configure_car_properties", car_3d, car_id, direction)
	active_visual_cars[car_id] = car_3d
	
	print("🚗 Visual car created: ID=%d (%s)" % [car_id, direction])
	visual_car_created.emit(car_id)

func configure_car_properties(car_3d: Node3D, car_id: int, direction: String):
	"""Configura propriedades do carro após _ready"""
	if not is_instance_valid(car_3d):
		print("❌ Car instance invalid for ID %d" % car_id)
		return
	
	# VERIFICAR se o script foi carregado corretamente
	if not car_3d.has_method("set_hybrid_mode"):
		print("❌ Car %d: Script not loaded correctly! Missing set_hybrid_mode method" % car_id)
		return
		
	# Verificar se as propriedades existem antes de atribuir
	if "car_id" in car_3d:
		car_3d.car_id = car_id
	else:
		print("❌ Car %d: car_id property not found!" % car_id)
		return
	
	if "direction" in car_3d:
		car_3d.direction = string_to_car_direction(direction)
	else:
		print("❌ Car %d: direction property not found!" % car_id)
		return
	
	# CRÍTICO: Colocar em modo híbrido
	car_3d.set_hybrid_mode(true)
	
	print("✅ Car %d configured: direction=%d, hybrid_mode=true" % [car_id, car_3d.direction])

func handle_visual_car_movement(event_data: Dictionary, movement_type: String):
	"""Animar movimento do carro visual"""
	var car_id = event_data.car_id
	
	if not car_id in active_visual_cars:
		print("⚠️ Car ID=%d not found for movement: %s" % [car_id, movement_type])
		return
	
	var car_3d = active_visual_cars[car_id]
	var target_position = event_data.get("position", car_3d.global_position)
	var duration = event_data.get("crossing_duration", event_data.get("wait_duration", 1.0))
	
	# Armazenar tipo de movimento para animação apropriada
	var actual_movement_type = event_data.get("movement_type", movement_type)
	car_3d.set_meta("movement_type", actual_movement_type)
	
	# Animar movimento suave
	animate_car_to_position(car_3d, target_position, duration)

func animate_car_to_position(car_3d: Node3D, target_pos: Vector3, duration: float):
	"""Interpola movimento MUITO SUAVE com aceleração realista"""
	if duration <= 0.1:  # Durações muito pequenas = movimento imediato
		car_3d.global_position = target_pos
		return
	
	# DETECTAR E CORRIGIR TPs BUGADOS
	var distance = car_3d.global_position.distance_to(target_pos)
	if distance < 0.5:  # Movimento muito pequeno = TP bugado
		print("🚫 Car %d: SKIPPING buggy TP - distance %.2fm too small" % [car_3d.car_id, distance])
		return  # Não animar movimentos minúsculos
	
	# Calcular velocidade visual para analytics
	var visual_speed = distance / duration if duration > 0 else 0
	if car_3d.has_method("set_visual_speed"):
		car_3d.set_visual_speed(visual_speed)
	
	# MOVIMENTO SUPER FLUIDO com múltiplas etapas
	# Obter tipo de movimento do event_data armazenado
	var movement_type = car_3d.get_meta("movement_type", "normal")
	
	var tween = create_tween()
	tween.set_parallel(true)  # Permite múltiplas animações
	
	match movement_type:
		"green_passage":
			# Movimento contínuo suave (aceleração gradual)
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_QUART)
		"approach_stop":
			# Movimento com desaceleração (aproximando da parada)
			tween.set_ease(Tween.EASE_IN_OUT)
			tween.set_trans(Tween.TRANS_SINE)
		_:
			# Movimento padrão
			tween.set_ease(Tween.EASE_IN_OUT)
			tween.set_trans(Tween.TRANS_CUBIC)
	
	# Animar posição
	tween.tween_property(car_3d, "global_position", target_pos, duration)
	
	print("🎬 Animating car %d: %s → %s in %.2fs (%.1f m/s)" % [
		car_3d.car_id, 
		car_3d.global_position, 
		target_pos, 
		duration, 
		visual_speed
	])

func handle_visual_car_exit(event_data: Dictionary):
	"""Remove carro visual APENAS quando chega no final do mapa"""
	var car_id = event_data.car_id
	
	if car_id in active_visual_cars:
		var car_3d = active_visual_cars[car_id]
		var final_position = event_data.get("final_position", Vector3.ZERO)
		
		# DESPAWN RÁPIDO - apenas 0.1s para garantir que chegou
		await get_tree().create_timer(0.1).timeout
		
		if car_3d and is_instance_valid(car_3d):
			car_3d.queue_free()
			active_visual_cars.erase(car_id)
			
			print("🗑️ Visual car removed after reaching: ID=%d at %s" % [car_id, final_position])
			visual_car_destroyed.emit(car_id)

func handle_visual_light_change(event_data: Dictionary):
	"""Atualizar semáforos visuais"""
	var main_state = event_data.get("main", "red")
	var cross_state = event_data.get("cross", "red")
	
	print("🚦 Visual lights should update: Main=%s, Cross=%s" % [main_state, cross_state])
	# TODO: Encontrar TrafficManager visual e atualizar

# Funções auxiliares
func string_to_car_direction(direction_str: String) -> int:
	"""Converte string para enum Car.Direction"""
	match direction_str:
		"west_east": return 0   # Car.Direction.LEFT_TO_RIGHT
		"east_west": return 1   # Car.Direction.RIGHT_TO_LEFT  
		"south_north": return 3 # Car.Direction.BOTTOM_TO_TOP
	return 0

func get_spawn_position_3d(direction: String) -> Vector3:
	"""Posições 3D para spawn visual"""
	match direction:
		"west_east": return Vector3(-35, 0, -1.25)
		"east_west": return Vector3(35, 0, 1.25)
		"south_north": return Vector3(0, 0, 35)
	return Vector3.ZERO

func get_spawn_rotation(direction: String) -> float:
	"""Rotação inicial do carro - VERIFICAR DIREÇÕES"""
	match direction:
		"west_east": 
			print("🧭 Car west→east: rotating +90° to face +X")
			return deg_to_rad(90)     # Apontar para +X (leste)
		"east_west": 
			print("🧭 Car east→west: rotating -90° to face -X")
			return deg_to_rad(-90)    # Apontar para -X (oeste)
		"south_north": 
			print("🧭 Car south→north: rotating 180° to face -Z")
			return deg_to_rad(180)    # Apontar para -Z (norte)
	return 0.0
