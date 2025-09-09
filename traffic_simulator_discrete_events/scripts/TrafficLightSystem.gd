extends Node
class_name TrafficLightSystem

# PASSO 4 - SISTEMA DE SEMÁFOROS
# RESPONSABILIDADE: APENAS gerenciar estados dos semáforos. NÃO agenda eventos.

signal traffic_light_changed(light_id: String, new_state: String)

enum State { RED, YELLOW, GREEN }

var CYCLE_TIMES = {
	"MAIN_GREEN": 20.0,      # S1+S2 verde
	"MAIN_YELLOW": 3.0,      # S1+S2 amarelo  
	"ALL_RED_1": 1.0,        # Todos vermelho
	"CROSS_GREEN": 10.0,     # S3 verde
	"CROSS_YELLOW": 3.0,     # S3 amarelo
	"ALL_RED_2": 1.0         # Todos vermelho
}

var traffic_lights = {}
var current_phase: String = "MAIN_GREEN"
var phase_start_time: float = 0.0
var timer_labels = {}  # Referencias para os labels 3D dos timers

func _ready():
	print("🚦 TrafficLightSystem inicializado")
	setup_traffic_lights()

func setup_traffic_lights():
	# S1: Main Road West (rua principal, lado esquerdo)
	traffic_lights["S1"] = {
		"state": State.GREEN,
		"position": Vector3(-5, 0, 5),
		"direction": "main_road_west",
		"node_ref": null,
		"timer_start": 0.0,
		"timer_label_ref": null
	}
	
	# S2: Main Road East (rua principal, lado direito)  
	traffic_lights["S2"] = {
		"state": State.GREEN,
		"position": Vector3(5, 0, -5), 
		"direction": "main_road_east",
		"node_ref": null,
		"timer_start": 0.0,
		"timer_label_ref": null
	}
	
	# S3: Cross Road North (rua transversal)
	traffic_lights["S3"] = {
		"state": State.RED,
		"position": Vector3(-5, 0, -5),
		"direction": "cross_road_north", 
		"node_ref": null,
		"timer_start": 0.0,
		"timer_label_ref": null
	}
	
	print("🚦 3 semáforos configurados: S1 (Main West), S2 (Main East), S3 (Cross North)")

func register_traffic_light_node(light_id: String, node: Node3D):
	if light_id in traffic_lights:
		traffic_lights[light_id]["node_ref"] = node
		update_visual_state(light_id)
		create_timer_label(light_id)
		print("🚦 Nó visual registrado para semáforo %s" % light_id)

func process_traffic_light_event(event_type: EventTypes.Type):
	match event_type:
		EventTypes.Type.SEMAFORO_MAIN_VERDE:
			set_main_lights_green()
			current_phase = "MAIN_GREEN"
			
		EventTypes.Type.SEMAFORO_MAIN_AMARELO:
			set_main_lights_yellow()
			current_phase = "MAIN_YELLOW"
			
		EventTypes.Type.SEMAFORO_TODOS_VERMELHO_1:
			set_all_lights_red()
			current_phase = "ALL_RED_1"
			
		EventTypes.Type.SEMAFORO_CROSS_VERDE:
			set_cross_light_green()
			current_phase = "CROSS_GREEN"
			
		EventTypes.Type.SEMAFORO_CROSS_AMARELO:
			set_cross_light_yellow()  
			current_phase = "CROSS_YELLOW"
			
		EventTypes.Type.SEMAFORO_TODOS_VERMELHO_2:
			set_all_lights_red()
			current_phase = "ALL_RED_2"

func set_main_lights_green():
	change_light_state("S1", State.GREEN)
	change_light_state("S2", State.GREEN) 
	change_light_state("S3", State.RED)
	print("🟢 Semáforos principais (S1+S2) VERDES, S3 vermelho")

func set_main_lights_yellow():
	change_light_state("S1", State.YELLOW)
	change_light_state("S2", State.YELLOW)
	change_light_state("S3", State.RED)
	print("🟡 Semáforos principais (S1+S2) AMARELOS, S3 vermelho")

func set_cross_light_green():
	change_light_state("S1", State.RED)
	change_light_state("S2", State.RED)
	change_light_state("S3", State.GREEN)
	print("🟢 Semáforo transversal (S3) VERDE, S1+S2 vermelhos")

func set_cross_light_yellow():
	change_light_state("S1", State.RED)
	change_light_state("S2", State.RED) 
	change_light_state("S3", State.YELLOW)
	print("🟡 Semáforo transversal (S3) AMARELO, S1+S2 vermelhos")

func set_all_lights_red():
	change_light_state("S1", State.RED)
	change_light_state("S2", State.RED)
	change_light_state("S3", State.RED)
	print("🔴 TODOS os semáforos VERMELHOS")

func change_light_state(light_id: String, new_state: State):
	if light_id in traffic_lights:
		var old_state = traffic_lights[light_id]["state"]
		traffic_lights[light_id]["state"] = new_state
		
		# Resetar timer quando estado muda
		var current_time = 0.0
		var scheduler = get_tree().current_scene.find_child("DiscreteTrafficSimulator")
		if scheduler and scheduler.scheduler:
			current_time = scheduler.scheduler.get_current_time()
		reset_timer(light_id, current_time)
		
		update_visual_state(light_id)
		
		var state_name = get_state_name(new_state)
		traffic_light_changed.emit(light_id, state_name)
		
		print("🚦 %s: %s -> %s" % [light_id, get_state_name(old_state), state_name])

func update_visual_state(light_id: String):
	if light_id in traffic_lights:
		var light_data = traffic_lights[light_id]
		var node = light_data["node_ref"]
		
		if node and node.has_method("set_light_state"):
			var state_name = get_state_name(light_data["state"])
			node.set_light_state(state_name.to_lower())

func get_state_name(state: State) -> String:
	match state:
		State.RED: return "RED"
		State.YELLOW: return "YELLOW"
		State.GREEN: return "GREEN"
		_: return "UNKNOWN"

func get_light_state(light_id: String) -> State:
	if light_id in traffic_lights:
		return traffic_lights[light_id]["state"]
	return State.RED

func get_current_phase() -> String:
	return current_phase

func get_phase_duration(phase: String) -> float:
	match phase:
		"MAIN_GREEN": return CYCLE_TIMES["MAIN_GREEN"]
		"MAIN_YELLOW": return CYCLE_TIMES["MAIN_YELLOW"] 
		"ALL_RED_1": return CYCLE_TIMES["ALL_RED_1"]
		"CROSS_GREEN": return CYCLE_TIMES["CROSS_GREEN"]
		"CROSS_YELLOW": return CYCLE_TIMES["CROSS_YELLOW"]
		"ALL_RED_2": return CYCLE_TIMES["ALL_RED_2"]
		_: return 1.0

func get_traffic_lights_info() -> String:
	var info = "Estados dos semáforos:\n"
	for light_id in traffic_lights.keys():
		var state = get_state_name(traffic_lights[light_id]["state"])
		var direction = traffic_lights[light_id]["direction"]
		info += "  %s (%s): %s\n" % [light_id, direction, state]
	info += "Fase atual: %s" % current_phase
	return info

func create_timer_label(light_id: String):
	if not light_id in traffic_lights:
		return
		
	var light_data = traffic_lights[light_id]
	var light_pos = light_data["position"]
	
	# Calcular posição do timer label (abaixo do S1/S2/S3 label)
	var timer_position: Vector3
	
	# Baseado nas rotações dos semáforos (igual ao código do Main.gd) - MAIS ALTO
	if light_id == "S1":  # rotation_y = 90
		timer_position = light_pos + Vector3(0, 6.5, -3.0)  # Mais alto que S1
	elif light_id == "S2":  # rotation_y = -90  
		timer_position = light_pos + Vector3(0, 6.5, 3.0)   # Mais alto que S2
	else:  # S3, rotation_y = 0
		timer_position = light_pos + Vector3(3.0, 6.5, 0)   # Mais alto que S3
	
	# Criar container para o timer
	var timer_container = Node3D.new()
	timer_container.name = "TimerLabel_" + light_id
	timer_container.position = timer_position
	
	# Criar o texto 3D para o timer
	var timer_mesh_instance = MeshInstance3D.new()
	var timer_mesh = TextMesh.new()
	timer_mesh.text = "0.0s"
	timer_mesh.font_size = 60  # Menor que o label S1/S2/S3
	timer_mesh.depth = 0.1
	timer_mesh_instance.mesh = timer_mesh
	
	# Material inicial (vermelho para estado inicial RED do S3)
	var timer_material = StandardMaterial3D.new()
	timer_material.albedo_color = get_state_color(light_data["state"])
	timer_material.emission = get_state_color(light_data["state"]) * 0.7
	timer_material.emission_energy = 2.5
	timer_material.flags_unshaded = true
	timer_material.flags_do_not_receive_shadows = true
	timer_material.flags_disable_ambient_light = true
	timer_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	timer_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	timer_mesh_instance.material_override = timer_material
	timer_container.add_child(timer_mesh_instance)
	
	# Registrar referência
	traffic_lights[light_id]["timer_label_ref"] = timer_mesh_instance
	
	# Adicionar à cena principal
	get_tree().current_scene.add_child(timer_container)
	
	print("⏰ Timer label criado para semáforo %s" % light_id)

func get_state_color(state: State) -> Color:
	match state:
		State.RED: return Color.RED
		State.YELLOW: return Color.YELLOW  
		State.GREEN: return Color.LIME_GREEN
		_: return Color.WHITE

func update_timer_displays(current_time: float):
	# Atualizar os displays dos timers com o tempo corrido desde a mudança
	for light_id in traffic_lights.keys():
		var light_data = traffic_lights[light_id]
		var timer_label = light_data["timer_label_ref"]
		
		if timer_label and is_instance_valid(timer_label):
			var elapsed_time = current_time - light_data["timer_start"]
			var timer_text = "%.1fs" % elapsed_time
			
			# Atualizar texto
			var timer_mesh = timer_label.mesh as TextMesh
			if timer_mesh:
				timer_mesh.text = timer_text
			
			# Atualizar cor baseado no estado atual
			var current_color = get_state_color(light_data["state"])
			var timer_material = timer_label.material_override as StandardMaterial3D
			if timer_material:
				timer_material.albedo_color = current_color
				timer_material.emission = current_color * 0.7

func reset_timer(light_id: String, current_time: float):
	# Resetar o timer quando o semáforo muda de estado
	if light_id in traffic_lights:
		traffic_lights[light_id]["timer_start"] = current_time
		print("⏰ Timer resetado para %s em t=%.1fs" % [light_id, current_time])