extends RefCounted
class_name DiscreteCar

enum DriverPersonality {
	AGGRESSIVE,
	CONSERVATIVE, 
	ELDERLY,
	NORMAL
}

enum IntersectionState {
	APPROACHING,
	WAITING,
	PROCEEDING,
	CROSSING,
	CLEARING
}

enum Direction {
	LEFT_TO_RIGHT = 0,  # West→East
	RIGHT_TO_LEFT = 1,  # East→West
	BOTTOM_TO_TOP = 3   # South→North
}

const PERSONALITIES = {
	DriverPersonality.AGGRESSIVE: {
		"base_speed": 6.0,
		"reaction_time_min": 0.5,
		"reaction_time_max": 0.8,
		"following_distance_factor": 0.8,
		"yellow_light_probability": 0.8,
		"deceleration": 10.0
	},
	DriverPersonality.CONSERVATIVE: {
		"base_speed": 4.5,
		"reaction_time_min": 1.2,
		"reaction_time_max": 1.5,
		"following_distance_factor": 1.3,
		"yellow_light_probability": 0.2,
		"deceleration": 6.0
	},
	DriverPersonality.ELDERLY: {
		"base_speed": 3.5,
		"reaction_time_min": 1.5,
		"reaction_time_max": 2.0,
		"following_distance_factor": 1.5,
		"yellow_light_probability": 0.1,
		"deceleration": 5.0
	},
	DriverPersonality.NORMAL: {
		"base_speed": 5.0,
		"reaction_time_min": 0.8,
		"reaction_time_max": 1.2,
		"following_distance_factor": 1.0,
		"yellow_light_probability": 0.5,
		"deceleration": 8.0
	}
}

const SPAWN_POSITIONS = {
	Direction.LEFT_TO_RIGHT: Vector3(-35.0, 0.0, -1.25),
	Direction.RIGHT_TO_LEFT: Vector3(35.0, 0.0, 1.25),
	Direction.BOTTOM_TO_TOP: Vector3(0.0, 0.0, 35.0)
}

const STOP_POSITIONS = {
	Direction.LEFT_TO_RIGHT: -7.0,  # para em X=-7.0
	Direction.RIGHT_TO_LEFT: 7.0,   # para em X=7.0  
	Direction.BOTTOM_TO_TOP: 7.0    # para em Z=7.0
}

var car_id: int
var personality: DriverPersonality
var direction: Direction
var current_position: Vector3
var current_speed: float
var intersection_state: IntersectionState
var spawn_time: float
var wait_start_time: float = -1.0

var personality_config: Dictionary
var reaction_time: float

func _init(id: int, spawn_time_param: float, dir: Direction = Direction.LEFT_TO_RIGHT, personality_type: DriverPersonality = DriverPersonality.NORMAL):
	car_id = id
	spawn_time = spawn_time_param
	direction = dir
	personality = personality_type
	personality_config = PERSONALITIES[personality]
	current_position = SPAWN_POSITIONS[direction]
	current_speed = 0.0
	intersection_state = IntersectionState.APPROACHING
	
	reaction_time = randf_range(
		personality_config.reaction_time_min,
		personality_config.reaction_time_max
	)

func get_personality_string() -> String:
	match personality:
		DriverPersonality.AGGRESSIVE: return "Aggressive"
		DriverPersonality.CONSERVATIVE: return "Conservative" 
		DriverPersonality.ELDERLY: return "Elderly"
		DriverPersonality.NORMAL: return "Normal"
		_: return "Unknown"

func get_direction_string() -> String:
	match direction:
		Direction.LEFT_TO_RIGHT: return "West"
		Direction.RIGHT_TO_LEFT: return "East"
		Direction.BOTTOM_TO_TOP: return "South"
		_: return "Unknown"

func calculate_safe_following_distance() -> float:
	var base_distance = personality_config.following_distance_factor * 3.0
	var speed_factor = current_speed / personality_config.base_speed
	return base_distance + speed_factor * 5.0

func calculate_braking_distance() -> float:
	if current_speed <= 0.0:
		return 0.0
	var decel = personality_config.deceleration
	return (current_speed * current_speed) / (2.0 * decel)

func calculate_distance_to_intersection() -> float:
	var stop_position = STOP_POSITIONS[direction]
	
	match direction:
		Direction.LEFT_TO_RIGHT:
			return stop_position - current_position.x
		Direction.RIGHT_TO_LEFT:
			return current_position.x - stop_position
		Direction.BOTTOM_TO_TOP:
			return stop_position - current_position.z
		_:
			return 0.0

func should_stop_at_yellow(light_state: String) -> bool:
	if light_state != "yellow":
		return light_state == "red"
	
	var braking_distance = calculate_braking_distance()
	var distance_to_stop = calculate_distance_to_intersection()
	var yellow_prob = personality_config.yellow_light_probability
	
	if braking_distance > distance_to_stop:
		return false
	elif distance_to_stop > braking_distance * 2.0:
		return true
	else:
		return randf() < yellow_prob

func calculate_travel_time_to_intersection() -> float:
	var distance = calculate_distance_to_intersection()
	if distance <= 0.0:
		return 0.0
	
	var avg_speed = personality_config.base_speed * 0.8
	return distance / avg_speed

func calculate_travel_time_through_intersection() -> float:
	var intersection_length = 14.0
	var crossing_speed = personality_config.base_speed * 0.9
	return intersection_length / crossing_speed

func calculate_travel_time_to_exit() -> float:
	var intersection_center = Vector3.ZERO
	var exit_distance = 30.0
	var exit_speed = personality_config.base_speed
	return exit_distance / exit_speed

func get_target_position_for_state(state: IntersectionState) -> Vector3:
	match state:
		IntersectionState.WAITING:
			return get_stop_position()
		IntersectionState.CROSSING:
			return Vector3.ZERO
		IntersectionState.CLEARING:
			return get_exit_position()
		_:
			return current_position

func get_stop_position() -> Vector3:
	var stop_pos = STOP_POSITIONS[direction]
	match direction:
		Direction.LEFT_TO_RIGHT:
			return Vector3(stop_pos, 0.0, -1.25)
		Direction.RIGHT_TO_LEFT:
			return Vector3(stop_pos, 0.0, 1.25)
		Direction.BOTTOM_TO_TOP:
			return Vector3(0.0, 0.0, stop_pos)
		_:
			return current_position

func get_exit_position() -> Vector3:
	match direction:
		Direction.LEFT_TO_RIGHT:
			return Vector3(35.0, 0.0, -1.25)
		Direction.RIGHT_TO_LEFT:
			return Vector3(-35.0, 0.0, 1.25)
		Direction.BOTTOM_TO_TOP:
			return Vector3(0.0, 0.0, -35.0)
		_:
			return current_position

func update_position_for_time(target_time: float) -> Vector3:
	if target_time <= spawn_time:
		return SPAWN_POSITIONS[direction]
	
	var elapsed = target_time - spawn_time
	var travel_speed = personality_config.base_speed
	var distance_traveled = travel_speed * elapsed
	
	match direction:
		Direction.LEFT_TO_RIGHT:
			current_position.x = SPAWN_POSITIONS[direction].x + distance_traveled
		Direction.RIGHT_TO_LEFT:
			current_position.x = SPAWN_POSITIONS[direction].x - distance_traveled
		Direction.BOTTOM_TO_TOP:
			current_position.z = SPAWN_POSITIONS[direction].z - distance_traveled
	
	return current_position

func start_waiting(current_time: float):
	intersection_state = IntersectionState.WAITING
	wait_start_time = current_time
	current_speed = 0.0

func start_proceeding(current_time: float):
	intersection_state = IntersectionState.PROCEEDING
	current_speed = personality_config.base_speed * 0.5

func start_crossing(current_time: float):
	intersection_state = IntersectionState.CROSSING
	current_speed = personality_config.base_speed

func start_clearing(current_time: float):
	intersection_state = IntersectionState.CLEARING
	current_speed = personality_config.base_speed

func get_wait_time(current_time: float) -> float:
	if wait_start_time < 0.0:
		return 0.0
	return current_time - wait_start_time

func get_current_speed() -> float:
	return current_speed

func get_debug_info() -> String:
	return "Car %d (%s): %s at %.1f,%.1f,%.1f - %s - Speed:%.1f" % [
		car_id,
		get_personality_string(),
		get_direction_string(),
		current_position.x,
		current_position.y, 
		current_position.z,
		IntersectionState.keys()[intersection_state],
		current_speed
	]