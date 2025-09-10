class_name VisualRenderer3D
extends Node

## Responsável por efeitos visuais, partículas, e otimizações de rendering
## Gerencia LOD, culling, batching e performance do sistema híbrido

var main_system: HybridTrafficSystem
var bridge: HybridBridge
var camera: Camera3D

# Otimizações de performance
var lod_enabled: bool = true
var culling_enabled: bool = true
var max_visible_cars: int = 50
var lod_distance_near: float = 30.0
var lod_distance_far: float = 100.0

# Cache de materiais e meshes
var car_materials_cache: Dictionary = {}
var car_meshes_cache: Dictionary = {}

# Estatísticas de rendering
var visible_cars_count: int = 0
var culled_cars_count: int = 0
var lod_high_count: int = 0
var lod_medium_count: int = 0
var lod_low_count: int = 0

func setup(main: HybridTrafficSystem, br: HybridBridge):
	main_system = main
	bridge = br
	print("🎨 VisualRenderer3D configurado")

func _ready():
	# Encontrar câmera principal
	_find_main_camera()
	
	# Configurar otimizações
	setup_rendering_optimizations()
	
	# Conectar sinais
	connect_signals()
	
	# Timer para atualizações de LOD/culling
	var timer = Timer.new()
	timer.wait_time = 0.1  # Atualizar 10x por segundo
	timer.timeout.connect(_update_rendering_optimizations)
	timer.autostart = true
	add_child(timer)

func _find_main_camera():
	"""Encontra a câmera principal para cálculos de LOD"""
	camera = get_viewport().get_camera_3d()
	
	if not camera and main_system:
		# Tentar encontrar CameraController
		var cam_controller = main_system.get_node_or_null("CameraController")
		if cam_controller:
			camera = cam_controller.get_node_or_null("Camera3D")
	
	if camera:
		print("📷 Camera encontrada para LOD: %s" % camera.name)
	else:
		print("⚠️ Camera não encontrada - LOD desabilitado")
		lod_enabled = false

func setup_rendering_optimizations():
	"""Configura otimizações específicas para o modo híbrido"""
	print("🎨 Configurando otimizações de rendering:")
	print("  - LOD (Level of Detail): %s" % ("Enabled" if lod_enabled else "Disabled"))
	print("  - Culling: %s" % ("Enabled" if culling_enabled else "Disabled"))
	print("  - Max visible cars: %d" % max_visible_cars)
	
	# Precarregar materiais para diferentes LODs
	_preload_lod_materials()

func connect_signals():
	"""Conecta sinais para otimizações automáticas"""
	if bridge:
		bridge.movement_started.connect(_on_car_movement_started)
		bridge.animation_completed.connect(_on_car_animation_completed)

func _preload_lod_materials():
	"""Precarrega materiais para diferentes níveis de LOD"""
	car_materials_cache["high"] = _create_high_quality_material()
	car_materials_cache["medium"] = _create_medium_quality_material()  
	car_materials_cache["low"] = _create_low_quality_material()
	
	print("🎭 Materiais LOD carregados: High, Medium, Low")

func _create_high_quality_material() -> StandardMaterial3D:
	"""Material de alta qualidade para carros próximos"""
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.metallic = 0.8
	material.roughness = 0.2
	material.specular = 0.8
	# Texturas, normal maps, etc.
	return material

func _create_medium_quality_material() -> StandardMaterial3D:
	"""Material de qualidade média para carros distantes"""
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.metallic = 0.5
	material.roughness = 0.4
	material.specular = 0.4
	# Sem normal maps para performance
	return material

func _create_low_quality_material() -> StandardMaterial3D:
	"""Material de baixa qualidade para carros muito distantes"""
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.flags_unshaded = true  # Sem iluminação complexa
	material.specular = 0.0
	return material

func optimize_car_rendering(car_3d: Node3D):
	"""Aplica otimizações de LOD e culling a um carro"""
	if not camera or not car_3d:
		return
	
	var car_position = car_3d.global_position
	var camera_position = camera.global_position
	var distance = camera_position.distance_to(car_position)
	
	# LOD baseado na distância
	if lod_enabled:
		_apply_lod_to_car(car_3d, distance)
	
	# Culling baseado na frustum da câmera
	if culling_enabled:
		_apply_culling_to_car(car_3d, distance)

func _apply_lod_to_car(car_3d: Node3D, distance: float):
	"""Aplica Level of Detail baseado na distância"""
	var lod_level: String
	
	if distance < lod_distance_near:
		lod_level = "high"
		lod_high_count += 1
	elif distance < lod_distance_far:
		lod_level = "medium"
		lod_medium_count += 1
	else:
		lod_level = "low"
		lod_low_count += 1
	
	# Aplicar material LOD
	_apply_lod_material(car_3d, lod_level)
	
	# Reduzir geometria para LOD baixo
	if lod_level == "low":
		_reduce_car_geometry(car_3d)
	else:
		_restore_car_geometry(car_3d)

func _apply_lod_material(car_3d: Node3D, lod_level: String):
	"""Aplica material baseado no nível LOD"""
	var material = car_materials_cache.get(lod_level)
	if not material:
		return
	
	# Encontrar MeshInstance3D no carro e aplicar material
	var mesh_instances = _find_mesh_instances(car_3d)
	for mesh_instance in mesh_instances:
		mesh_instance.material_override = material

func _reduce_car_geometry(car_3d: Node3D):
	"""Reduz geometria para LOD baixo"""
	# Implementar redução de polígonos, desabilitar detalhes pequenos, etc.
	var details = car_3d.find_children("*Detail*")
	for detail in details:
		detail.visible = false

func _restore_car_geometry(car_3d: Node3D):
	"""Restaura geometria completa"""
	var details = car_3d.find_children("*Detail*")
	for detail in details:
		detail.visible = true

func _apply_culling_to_car(car_3d: Node3D, distance: float):
	"""Aplica culling baseado na frustum e distância"""
	var should_be_visible = true
	
	# Culling por distância
	if distance > lod_distance_far * 2.0:
		should_be_visible = false
		culled_cars_count += 1
	# Culling por frustum (implementação básica)
	elif not _is_in_camera_frustum(car_3d.global_position):
		should_be_visible = false
		culled_cars_count += 1
	else:
		visible_cars_count += 1
	
	# Aplicar visibilidade
	car_3d.visible = should_be_visible

func _is_in_camera_frustum(position: Vector3) -> bool:
	"""Verifica se posição está no frustum da câmera (implementação básica)"""
	if not camera:
		return true
	
	# Implementação simplificada - verificar se está na frente da câmera
	var to_position = (position - camera.global_position)
	var camera_forward = -camera.global_transform.basis.z
	
	return to_position.dot(camera_forward) > 0

func _find_mesh_instances(node: Node) -> Array:
	"""Encontra todas as MeshInstance3D em um nó"""
	var mesh_instances = []
	
	if node is MeshInstance3D:
		mesh_instances.append(node)
	
	for child in node.get_children():
		mesh_instances.append_array(_find_mesh_instances(child))
	
	return mesh_instances

func _update_rendering_optimizations():
	"""Atualiza otimizações periodicamente"""
	if not main_system:
		return
	
	# Reset counters
	visible_cars_count = 0
	culled_cars_count = 0
	lod_high_count = 0
	lod_medium_count = 0
	lod_low_count = 0
	
	# Aplicar otimizações a todos os carros ativos
	for car_3d in main_system.visual_entities.values():
		if car_3d and is_instance_valid(car_3d):
			optimize_car_rendering(car_3d)

func add_particle_effect(position: Vector3, effect_type: String):
	"""Adiciona efeitos de partículas"""
	match effect_type:
		"spawn":
			_create_spawn_particles(position)
		"despawn":
			_create_despawn_particles(position)
		"exhaust":
			_create_exhaust_particles(position)

func _create_spawn_particles(position: Vector3):
	"""Cria partículas de spawn"""
	var particles = GPUParticles3D.new()
	particles.global_position = position
	particles.emitting = true
	particles.amount = 30
	particles.lifetime = 1.0
	
	# Configurar processo de material
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 1, 0)
	material.initial_velocity_min = 5.0
	material.initial_velocity_max = 10.0
	material.gravity = Vector3(0, -9.8, 0)
	material.scale_min = 0.1
	material.scale_max = 0.3
	
	particles.process_material = material
	
	main_system.add_child(particles)
	
	# Auto remover após término
	particles.finished.connect(particles.queue_free)

func _create_despawn_particles(position: Vector3):
	"""Cria partículas de despawn"""
	# Similar ao spawn mas com efeito diferente
	pass

func _create_exhaust_particles(position: Vector3):
	"""Cria partículas de escapamento"""
	# Partículas contínuas de escapamento
	pass

func _on_car_movement_started(car_id: int):
	"""Callback quando carro começa a se mover"""
	print("🎬 VisualRenderer: Car %d started moving" % car_id)

func _on_car_animation_completed(car_id: int):
	"""Callback quando animação de carro termina"""
	print("✅ VisualRenderer: Car %d animation completed" % car_id)

func get_rendering_stats() -> Dictionary:
	"""Retorna estatísticas de rendering"""
	return {
		"visible_cars": visible_cars_count,
		"culled_cars": culled_cars_count,
		"lod_high": lod_high_count,
		"lod_medium": lod_medium_count,
		"lod_low": lod_low_count,
		"lod_enabled": lod_enabled,
		"culling_enabled": culling_enabled
	}

func get_debug_info() -> String:
	"""Informações debug do renderizador"""
	return "VisualRenderer: %d visible, %d culled, LOD H:%d M:%d L:%d" % [
		visible_cars_count, culled_cars_count,
		lod_high_count, lod_medium_count, lod_low_count
	]