extends Node

enum TrafficState { RED, YELLOW, GREEN }

var traffic_lights = {}
var current_cycle_time: float = 0.0
var cycle_duration: float = 30.0

var event_bus: Node

func _ready():
	print("🚦 TrafficLightController inicializado")
	# Aguardar frame para garantir que EventBus existe
	await get_tree().process_frame
	event_bus = get_node("/root/EventBus")
	
	setup_traffic_lights()
	start_cycle()

func setup_traffic_lights():
	# S1 e S2 (rua principal) começam com GREEN
	# S3 (rua transversal) começa com RED
	traffic_lights = {
		"light_1": {
			"position": Vector3(-5, 0, 5),
			"state": TrafficState.GREEN,  # Rua principal - oeste
			"last_change": 0.0,
			"road_type": "main"
		},
		"light_2": {
			"position": Vector3(5, 0, -5),
			"state": TrafficState.GREEN,  # Rua principal - leste
			"last_change": 0.0,
			"road_type": "main"
		},
		"light_3": {
			"position": Vector3(-5, 0, -5),
			"state": TrafficState.RED,    # Rua transversal - norte
			"last_change": 0.0,
			"road_type": "cross"
		}
	}
	
	# Emitir estado inicial para sincronizar visual
	emit_initial_states()

func start_cycle():
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = cycle_duration / 3.0
	timer.timeout.connect(_on_cycle_timeout)
	timer.start()

func _on_cycle_timeout():
	cycle_traffic_lights()

func cycle_traffic_lights():
	# S1 e S2 (main road) sempre iguais
	var main_road_lights = ["light_1", "light_2"]
	var cross_road_lights = ["light_3"]
	
	# Cicla semáforos da rua principal (S1 e S2)
	for light_id in main_road_lights:
		var light = traffic_lights[light_id]
		
		match light.state:
			TrafficState.RED:
				light.state = TrafficState.GREEN
			TrafficState.GREEN:
				light.state = TrafficState.YELLOW
			TrafficState.YELLOW:
				light.state = TrafficState.RED
		
		light.last_change = Time.get_ticks_msec() / 1000.0
		event_bus.emit_event("traffic_light_changed", {
			"light_id": light_id,
			"state": light.state,
			"position": light.position
		})
	
	# Cicla semáforo da rua transversal (S3) - OPOSTO aos da main
	for light_id in cross_road_lights:
		var light = traffic_lights[light_id]
		var main_state = traffic_lights["light_1"].state  # Pega estado da main road
		
		# S3 sempre oposto a S1/S2
		match main_state:
			TrafficState.RED:
				light.state = TrafficState.GREEN
			TrafficState.GREEN:
				light.state = TrafficState.RED
			TrafficState.YELLOW:
				light.state = TrafficState.RED  # Quando main está yellow, cross fica red
		
		light.last_change = Time.get_ticks_msec() / 1000.0
		event_bus.emit_event("traffic_light_changed", {
			"light_id": light_id,
			"state": light.state,
			"position": light.position
		})

func emit_initial_states():
	# Emitir o estado inicial de todos os semáforos
	print("🚦 FORÇANDO estados iniciais dos semáforos...")
	for light_id in traffic_lights.keys():
		var light = traffic_lights[light_id]
		print("🚦 Emitindo estado inicial: ", light_id, " -> ", light.state)
		event_bus.emit_event("traffic_light_changed", {
			"light_id": light_id,
			"state": light.state,
			"position": light.position
		})

func get_light_state(light_id: String) -> TrafficState:
	if traffic_lights.has(light_id):
		return traffic_lights[light_id].state
	return TrafficState.RED

func is_intersection_clear() -> bool:
	for light in traffic_lights.values():
		if light.state == TrafficState.GREEN:
			return false
	return true