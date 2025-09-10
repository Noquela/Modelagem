class_name HybridBridge
extends Node

## Ponte que traduz eventos discretos em ações visuais suaves
## Responsável por interpolar movimentos e sincronizar estados

var main_system: HybridTrafficSystem
var traffic_manager: DiscreteTrafficManager
var active_animations: Dictionary = {}

signal animation_completed(car_id: int)
signal movement_started(car_id: int)

func setup_connections(main: HybridTrafficSystem, tm: DiscreteTrafficManager):
	main_system = main
	traffic_manager = tm
	print("🌉 HybridBridge conectada aos sistemas")

func animate_car_movement(car_3d: Node3D, target_position: Vector3, duration: float):
	"""Interpola movimento do carro suavemente"""
	var car_id = car_3d.car_id
	
	# Cancelar animação anterior se existir
	if car_id in active_animations:
		active_animations[car_id].kill()
	
	print("🎬 BRIDGE: Animating car %d to %s in %.1fs" % [car_id, target_position, duration])
	
	# Criar nova interpolação suave
	var tween = create_tween()
	tween.set_parallel(true)  # Permite múltiplas propriedades
	
	# Interpolar posição com easing suave
	tween.tween_property(car_3d, "global_position", target_position, duration)
	tween.tween_property(car_3d, "global_position", target_position, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Calcular e interpolar rotação se necessário
	var target_rotation = calculate_rotation_for_movement(car_3d.global_position, target_position, car_3d.direction)
	var current_rotation = car_3d.rotation.y
	
	# Normalizar diferença de rotação
	var rotation_diff = target_rotation - current_rotation
	while rotation_diff > PI:
		rotation_diff -= 2 * PI
	while rotation_diff < -PI:
		rotation_diff += 2 * PI
	
	if abs(rotation_diff) > 0.1:  # Só animar se diferença significativa
		var rotation_duration = min(duration * 0.3, 1.0)  # Rotação mais rápida
		tween.tween_property(car_3d, "rotation:y", target_rotation, rotation_duration)
		tween.tween_property(car_3d, "rotation:y", target_rotation, rotation_duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	# Callback quando animação termina
	tween.tween_callback(func(): _on_animation_finished(car_id))
	
	active_animations[car_id] = tween
	
	# Atualizar velocidade visual do carro (para compatibilidade)
	var distance = car_3d.global_position.distance_to(target_position)
	var visual_speed = distance / duration if duration > 0 else 0
	
	if car_3d.has_method("set_visual_speed"):
		car_3d.set_visual_speed(visual_speed)
	
	# Emitir sinal de início do movimento
	movement_started.emit(car_id)

func animate_car_spawn(car_3d: Node3D, spawn_position: Vector3):
	"""Anima spawn do carro com efeito suave"""
	var car_id = car_3d.car_id
	
	# Posicionar carro na posição de spawn
	car_3d.global_position = spawn_position
	
	# Efeito apenas de scale (sem modulate que não existe em Node3D)
	car_3d.scale = Vector3.ZERO
	
	var tween = create_tween()
	
	# Scale up suavemente
	tween.tween_property(car_3d, "scale", Vector3.ONE, 0.5)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	print("✨ BRIDGE: Spawning car %d with scale effect" % car_id)

func animate_car_despawn(car_3d: Node3D, callback: Callable):
	"""Anima remoção do carro com efeito suave"""
	var car_id = car_3d.car_id
	
	var tween = create_tween()
	
	# Scale down suavemente
	tween.tween_property(car_3d, "scale", Vector3.ZERO, 0.4)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	# Callback para remoção
	tween.tween_callback(callback)
	
	print("🗑️ BRIDGE: Despawning car %d with scale effect" % car_id)

func calculate_rotation_for_movement(from: Vector3, to: Vector3, direction) -> float:
	"""Calcula rotação correta baseada na direção do movimento"""
	var movement_vector = (to - from).normalized()
	
	# Se não há movimento significativo, manter rotação baseada na direção
	if movement_vector.length() < 0.01:
		match direction:
			0: return 0.0      # LEFT_TO_RIGHT (West → East)
			1: return PI       # RIGHT_TO_LEFT (East → West) 
			3: return PI/2     # BOTTOM_TO_TOP (South → North)
			_: return 0.0
	
	# Converter direção do movimento em rotação Y
	if abs(movement_vector.x) > abs(movement_vector.z):
		# Movimento principalmente horizontal
		return 0.0 if movement_vector.x > 0 else PI
	else:
		# Movimento principalmente vertical  
		return PI/2 if movement_vector.z < 0 else -PI/2

func force_sync_traffic_lights(main_state: String, cross_state: String):
	"""Força sincronização dos semáforos visuais"""
	if traffic_manager and traffic_manager.has_method("force_set_light_states"):
		traffic_manager.force_set_light_states(main_state, cross_state)
		print("🚦 BRIDGE: Traffic lights synced - Main: %s, Cross: %s" % [main_state, cross_state])
	else:
		print("⚠️ BRIDGE: TrafficManager não encontrado ou método não disponível")

func stop_car_animation(car_id: int):
	"""Para animação de um carro específico"""
	if car_id in active_animations:
		active_animations[car_id].kill()
		active_animations.erase(car_id)
		print("⏹️ BRIDGE: Animation stopped for car %d" % car_id)

func stop_all_animations():
	"""Para todas as animações ativas"""
	for car_id in active_animations.keys():
		active_animations[car_id].kill()
	active_animations.clear()
	print("⏹️ BRIDGE: All animations stopped")

func _on_animation_finished(car_id: int):
	"""Callback quando animação de movimento termina"""
	active_animations.erase(car_id)
	animation_completed.emit(car_id)
	print("✅ BRIDGE: Animation finished for car %d" % car_id)

func get_animation_progress(car_id: int) -> float:
	"""Retorna progresso da animação (0.0 a 1.0)"""
	if car_id in active_animations:
		var tween = active_animations[car_id]
		if tween and tween.is_valid():
			# Aproximação do progresso baseado no tempo
			return 0.5  # Placeholder - Godot 4 não expõe progresso diretamente
	return 1.0  # Completa se não há animação

func is_car_animating(car_id: int) -> bool:
	"""Verifica se o carro está sendo animado"""
	return car_id in active_animations

func get_active_animations_count() -> int:
	"""Retorna número de animações ativas"""
	return active_animations.size()

func get_debug_info() -> String:
	"""Informações debug da ponte"""
	return "HybridBridge: %d active animations" % get_active_animations_count()