extends Node

enum TrafficState { RED, YELLOW, GREEN }

var traffic_lights = {}
var current_cycle_time: float = 0.0

# Different timing for different road types
var s1_s2_green_duration: float = 20.0    # S1/S2: 20s verde
var s1_s2_yellow_duration: float = 2.0    # S1/S2: 2s amarelo  
var s3_green_duration: float = 10.0       # S3: 10s verde
var s3_yellow_duration: float = 2.0       # S3: 2s amarelo

var time_in_current_state: float = 0.0
var current_phase: String = "s1_s2_green"  # Track which phase we're in

var event_bus: Node
var simulation_clock: Node
var is_paused: bool = false

func _ready():
	print("🚦 TrafficLightController inicializado")
	# Aguardar frame para garantir que EventBus existe
	await get_tree().process_frame
	event_bus = get_node("/root/EventBus")
	simulation_clock = get_node("/root/SimulationClock")
	
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
	# Start with S1/S2 green (20s)
	current_phase = "s1_s2_green"
	time_in_current_state = 0.0
	
	# Set initial states
	set_light_state("light_1", TrafficState.GREEN)
	set_light_state("light_2", TrafficState.GREEN)  
	set_light_state("light_3", TrafficState.RED)
	
	set_process(true)
	print("🚦 Ciclo iniciado - S1/S2: 20s verde + 2s amarelo, S3: 10s verde + 2s amarelo")

func _process(delta):
	# Only update timers if simulation is not paused
	if simulation_clock and not simulation_clock.is_paused:
		time_in_current_state += delta * simulation_clock.time_scale
		current_cycle_time += delta * simulation_clock.time_scale
		
		# Check phase transitions based on current phase
		var should_change = false
		match current_phase:
			"s1_s2_green":
				if time_in_current_state >= s1_s2_green_duration:
					should_change = true
			"s1_s2_yellow":
				if time_in_current_state >= s1_s2_yellow_duration:
					should_change = true
			"s3_green":
				if time_in_current_state >= s3_green_duration:
					should_change = true
			"s3_yellow":
				if time_in_current_state >= s3_yellow_duration:
					should_change = true
		
		if should_change:
			_on_cycle_timeout()

func _on_cycle_timeout():
	time_in_current_state = 0.0  # Reset timer for new state
	cycle_traffic_lights()

func cycle_traffic_lights():
	# New phase-based system
	match current_phase:
		"s1_s2_green":
			# S1/S2 green → yellow
			current_phase = "s1_s2_yellow"
			set_light_state("light_1", TrafficState.YELLOW)
			set_light_state("light_2", TrafficState.YELLOW)
			set_light_state("light_3", TrafficState.RED)
			print("🚦 Fase: S1/S2 AMARELO (2s)")
			
		"s1_s2_yellow":
			# S1/S2 yellow → red, S3 → green
			current_phase = "s3_green" 
			set_light_state("light_1", TrafficState.RED)
			set_light_state("light_2", TrafficState.RED)
			set_light_state("light_3", TrafficState.GREEN)
			print("🚦 Fase: S3 VERDE (10s)")
			
		"s3_green":
			# S3 green → yellow
			current_phase = "s3_yellow"
			set_light_state("light_1", TrafficState.RED)
			set_light_state("light_2", TrafficState.RED) 
			set_light_state("light_3", TrafficState.YELLOW)
			print("🚦 Fase: S3 AMARELO (2s)")
			
		"s3_yellow":
			# S3 yellow → red, S1/S2 → green
			current_phase = "s1_s2_green"
			set_light_state("light_1", TrafficState.GREEN)
			set_light_state("light_2", TrafficState.GREEN)
			set_light_state("light_3", TrafficState.RED)
			print("🚦 Fase: S1/S2 VERDE (20s)")

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

func set_light_state(light_id: String, new_state: TrafficState):
	if traffic_lights.has(light_id):
		var light = traffic_lights[light_id]
		light.state = new_state
		light.last_change = Time.get_ticks_msec() / 1000.0
		
		# Emit event for visual update
		event_bus.emit_event("traffic_light_changed", {
			"light_id": light_id,
			"state": new_state,
			"position": light.position
		})

func is_intersection_clear() -> bool:
	for light in traffic_lights.values():
		if light.state == TrafficState.GREEN:
			return false
	return true

func get_time_remaining() -> float:
	# Return time remaining in current phase
	var phase_duration = 0.0
	match current_phase:
		"s1_s2_green":
			phase_duration = s1_s2_green_duration
		"s1_s2_yellow":
			phase_duration = s1_s2_yellow_duration
		"s3_green":
			phase_duration = s3_green_duration
		"s3_yellow":
			phase_duration = s3_yellow_duration
	
	return max(0.0, phase_duration - time_in_current_state)

func get_cycle_info() -> Dictionary:
	return {
		"current_phase": current_phase,
		"current_cycle_time": current_cycle_time,
		"time_in_current_state": time_in_current_state,
		"time_remaining": get_time_remaining(),
		"s1_s2_green_duration": s1_s2_green_duration,
		"s1_s2_yellow_duration": s1_s2_yellow_duration,
		"s3_green_duration": s3_green_duration,
		"s3_yellow_duration": s3_yellow_duration
	}
