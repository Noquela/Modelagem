extends Node
class_name VehicleSystem

# SISTEMA DE VEÍCULOS DISCRETO
# LÓGICA: 100% eventos discretos
# VISUAL: Interpolação contínua para suavidade

signal vehicle_spawned(vehicle_id: String, spawn_point: String)
signal vehicle_despawned(vehicle_id: String, exit_point: String)
signal vehicle_moved(vehicle_id: String, from_pos: Vector3, to_pos: Vector3)

var discrete_cars: Dictionary = {}  # vehicle_id -> DiscreteCar
var visual_nodes: Dictionary = {}   # vehicle_id -> Node3D
var next_vehicle_id: int = 1
var car_scene: PackedScene
var spawn_rates = {
	"WEST": 0.15,    # Probabilidade por segundo de spawn West→East
	"EAST": 0.12,    # Probabilidade por segundo de spawn East→West
	"NORTH": 0.08    # Probabilidade por segundo de spawn South→North
}

# POSIÇÕES CORRIGIDAS - AGORA NÃO USADAS (DiscreteCar tem as posições)
var spawn_points = {
	"WEST": Vector3(-35, 0.5, -1.25),   # Entrada oeste (faixa sul)
	"EAST": Vector3(35, 0.5, 1.25),    # Entrada leste (faixa norte)
	"NORTH": Vector3(0.0, 0.5, 35)     # Entrada sul (rua transversal)
}

var exit_points = {
	"WEST": Vector3(35, 0.5, -1.25),    # Saída leste (West→East)
	"EAST": Vector3(-35, 0.5, 1.25),   # Saída oeste (East→West)
	"NORTH": Vector3(0.0, 0.5, -35)    # Saída norte (South→North)
}

func _ready():
	print("🚗 VehicleSystem inicializado")
	load_car_scene()

func load_car_scene():
	car_scene = load("res://scenes/Car.tscn")
	if car_scene:
		print("🚗 Cena de carro carregada")
	else:
		print("⚠️ Falha ao carregar cena do carro - usando cubo placeholder")

func process_vehicle_event(event_type: EventTypes.Type, event_data: Dictionary = {}):
	match event_type:
		EventTypes.Type.SPAWN_CARRO_WEST:
			spawn_vehicle("WEST")
			
		EventTypes.Type.SPAWN_CARRO_EAST:
			spawn_vehicle("EAST")
			
		EventTypes.Type.SPAWN_CARRO_NORTH:
			spawn_vehicle("NORTH")
			
		EventTypes.Type.CARRO_SAIU:
			var vehicle_id = event_data.get("vehicle_id", "")
			despawn_vehicle(vehicle_id)

func spawn_vehicle(direction: String) -> String:
	var vehicle_id = "CAR_%03d" % next_vehicle_id
	next_vehicle_id += 1
	
	# Converter direção string para enum
	var car_direction = convert_direction_to_enum(direction)
	if car_direction == -1:
		print("❌ Direção inválida: %s" % direction)
		return ""
	
	# Criar carro discreto (LÓGICA)
	var discrete_car = DiscreteCar.new(vehicle_id, car_direction, get_current_simulation_time())
	discrete_cars[vehicle_id] = discrete_car
	
	# Criar nó visual (VISUAL)
	var visual_node = create_vehicle_visual_node(vehicle_id, direction)
	if visual_node:
		visual_nodes[vehicle_id] = visual_node
		discrete_car.set_visual_node(visual_node)
		get_tree().current_scene.add_child(visual_node)
	
	print("🚗 Veículo discreto spawned: %s (%s) na posição %s" % [vehicle_id, direction, discrete_car.get_current_position()])
	vehicle_spawned.emit(vehicle_id, direction)
	
	return vehicle_id

func convert_direction_to_enum(direction: String) -> int:
	match direction:
		"WEST":
			return DiscreteCar.Direction.WEST_TO_EAST
		"EAST":
			return DiscreteCar.Direction.EAST_TO_WEST
		"NORTH":
			return DiscreteCar.Direction.SOUTH_TO_NORTH
		_:
			return -1

func get_current_simulation_time() -> float:
	# Pegar tempo atual do scheduler
	var scheduler = get_tree().current_scene.find_child("DiscreteTrafficSimulator")
	if scheduler and scheduler.scheduler:
		return scheduler.scheduler.get_current_time()
	return 0.0

func create_vehicle_visual_node(vehicle_id: String, direction: String) -> Node3D:
	var vehicle_node: Node3D
	
	if car_scene:
		vehicle_node = car_scene.instantiate()
	else:
		# Placeholder: cubo simples
		vehicle_node = create_placeholder_car()
	
	vehicle_node.name = vehicle_id
	
	# A rotação será definida pela DiscreteCar quando set_visual_node for chamado
	
	return vehicle_node

func create_placeholder_car() -> Node3D:
	var car = Node3D.new()
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(4, 1.5, 2)
	mesh_instance.mesh = box_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(randf(), randf(), randf())
	mesh_instance.material_override = material
	
	car.add_child(mesh_instance)
	return car

func setup_vehicle_movement(vehicle_node: Node3D, direction: String, start_pos: Vector3, end_pos: Vector3):
	# FUNÇÃO OBSOLETA - não usada no sistema discreto
	# O movimento agora é controlado pela DiscreteCar.update_visual_position()
	pass

func _on_vehicle_reached_exit(vehicle_id: String):
	# FUNÇÃO OBSOLETA - não usada no sistema discreto  
	# A saída agora é controlada por eventos discretos
	pass

func despawn_vehicle(vehicle_id: String):
	# Remover lógica discreta
	if vehicle_id in discrete_cars:
		discrete_cars.erase(vehicle_id)
	
	# Remover visual
	if vehicle_id in visual_nodes:
		var visual_node = visual_nodes[vehicle_id]
		if visual_node and is_instance_valid(visual_node):
			visual_node.queue_free()
		visual_nodes.erase(vehicle_id)
	
	print("🗑️ Veículo discreto removido: %s" % vehicle_id)
	vehicle_despawned.emit(vehicle_id, "EXIT")

func get_vehicle_count() -> int:
	return discrete_cars.size()

func get_vehicles_by_direction(direction: String) -> Array:
	var result = []
	for vehicle_id in discrete_cars.keys():
		var car = discrete_cars[vehicle_id]
		if car.get_direction_name().begins_with(direction):
			result.append(vehicle_id)
	return result

func should_spawn_vehicle(direction: String, delta_time: float) -> bool:
	var rate = spawn_rates.get(direction, 0.0)
	var probability = rate * delta_time
	return randf() < probability

func get_spawn_rate(direction: String) -> float:
	return spawn_rates.get(direction, 0.0)

func set_spawn_rate(direction: String, rate: float):
	if direction in spawn_rates:
		spawn_rates[direction] = max(0.0, rate)
		print("🚗 Taxa de spawn %s: %.3f/s" % [direction, rate])

func get_vehicles_info() -> String:
	var info = "Veículos ativos: %d\n" % get_vehicle_count()
	
	for direction in ["WEST", "EAST", "NORTH"]:
		var count = get_vehicles_by_direction(direction).size()
		var rate = spawn_rates[direction]
		info += "  %s: %d carros (%.2f/s)\n" % [direction, count, rate]
	
	return info

func cleanup_all_vehicles():
	for vehicle_id in discrete_cars.keys():
		despawn_vehicle(vehicle_id)
	discrete_cars.clear()
	visual_nodes.clear()
	next_vehicle_id = 1
	print("🧹 Todos os veículos removidos")

# NOVAS FUNÇÕES PARA EVENTOS DISCRETOS

func can_vehicle_move(vehicle_id: String) -> bool:
	if not vehicle_id in discrete_cars:
		return false
		
	var car = discrete_cars[vehicle_id]
	
	# Verificar se não está na saída
	if car.is_at_exit():
		return false
	
	# Verificar semáforo se estiver na posição do semáforo
	if car.is_at_traffic_light_position():
		var light_direction = car.get_traffic_light_direction()
		var light_state = get_traffic_light_state(light_direction)
		var should_stop = car.should_stop_at_traffic_light(light_state)
		return not should_stop
	
	# Verificar se tem carro à frente
	return not has_car_ahead(vehicle_id)

func get_traffic_light_state(light_direction: String) -> String:
	# Pegar estado do sistema de semáforos
	var traffic_system = get_tree().current_scene.find_child("DiscreteTrafficSimulator")
	if traffic_system and traffic_system.traffic_light_system:
		var current_phase = traffic_system.traffic_light_system.get_current_phase()
		
		# Mapear fase para estado com mais robustez
		if light_direction == "main_road":
			match current_phase:
				"MAIN_GREEN":
					return "green"
				"MAIN_YELLOW":
					return "yellow"
				_:
					return "red"  # Incluindo ALL_RED_1, ALL_RED_2, CROSS_GREEN, CROSS_YELLOW
		else:  # cross_road
			match current_phase:
				"CROSS_GREEN":
					return "green" 
				"CROSS_YELLOW":
					return "yellow"
				_:
					return "red"  # Incluindo MAIN_GREEN, MAIN_YELLOW, ALL_RED_1, ALL_RED_2
	
	return "red"  # Default seguro

func has_car_ahead(vehicle_id: String) -> bool:
	if not vehicle_id in discrete_cars:
		return false
		
	var car = discrete_cars[vehicle_id]
	var car_direction = car.direction
	var car_position = car.current_position_index
	
	# Verificar se há outro carro na próxima posição
	for other_id in discrete_cars.keys():
		if other_id == vehicle_id:
			continue
			
		var other_car = discrete_cars[other_id]
		if other_car.direction == car_direction and other_car.current_position_index == car_position + 1:
			return true
	
	return false

func move_vehicle_to_next_position(vehicle_id: String) -> bool:
	if not vehicle_id in discrete_cars:
		return false
		
	var car = discrete_cars[vehicle_id]
	
	if not car.can_move_to_next_position():
		return false
	
	# Pegar posições antes e depois para movimento suave
	var old_pos = car.get_current_position()
	
	# Atualizar posição lógica
	car.advance_position()
	
	# Atualizar posição visual (suave) - da posição antiga para a nova
	if car.visual_node:
		var new_pos = car.get_current_position()
		# Garantir que está na posição antiga antes do tween
		car.visual_node.position = old_pos
		# Criar tween para movimento suave
		var tween = car.visual_node.create_tween()
		tween.tween_property(car.visual_node, "position", new_pos, car.speed_factor)
	
	# Emitir sinal
	vehicle_moved.emit(vehicle_id, car.get_current_position(), car.get_next_position())
	
	return true

func get_all_vehicles() -> Array:
	return discrete_cars.keys()

func get_vehicle_info(vehicle_id: String) -> Dictionary:
	if vehicle_id in discrete_cars:
		var car = discrete_cars[vehicle_id]
		return {
			"id": vehicle_id,
			"direction": car.get_direction_name(),
			"position_index": car.current_position_index,
			"position": car.get_current_position(),
			"state": car.state,
			"can_move": can_vehicle_move(vehicle_id)
		}
	return {}
