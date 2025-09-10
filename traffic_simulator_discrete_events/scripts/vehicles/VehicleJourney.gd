extends RefCounted
class_name VehicleJourney

const SPAWN_RATES = {
	"west_east_rate": 0.055,
	"east_west_rate": 0.055, 
	"south_north_rate": 0.025
}

const RUSH_HOUR_MULTIPLIERS = {
	7: 2.0,   # 7-9h rush matinal
	8: 2.0,
	9: 2.0,
	12: 1.5,  # 12-14h almoço
	13: 1.5,
	14: 1.5,
	17: 2.5,  # 17-19h rush vespertino
	18: 2.5,
	19: 2.5,
	22: 0.3,  # 22-6h madrugada
	23: 0.3,
	0: 0.3,
	1: 0.3,
	2: 0.3,
	3: 0.3,
	4: 0.3,
	5: 0.3,
	6: 0.3
}

const TRAFFIC_LIGHT_CYCLE = {
	"main_road_green": 20.0,
	"cross_road_green": 10.0,
	"yellow_time": 3.0,
	"safety_time": 1.0,
	"total_cycle": 40.0
}

var journey_id: int
var car: DiscreteCar
var segments: Array[Dictionary] = []
var current_segment_index: int = 0
var total_journey_time: float = 0.0

func _init(id: int, discrete_car: DiscreteCar):
	journey_id = id
	car = discrete_car
	_calculate_journey_segments()

func _calculate_journey_segments():
	segments.clear()
	
	match car.direction:
		DiscreteCar.Direction.LEFT_TO_RIGHT:
			_create_west_east_journey()
		DiscreteCar.Direction.RIGHT_TO_LEFT:
			_create_east_west_journey()
		DiscreteCar.Direction.BOTTOM_TO_TOP:
			_create_south_north_journey()

func _create_west_east_journey():
	segments.append({
		"name": "spawn_to_intersection",
		"start_pos": Vector3(-35.0, 0.0, -1.25),
		"end_pos": Vector3(-7.0, 0.0, -1.25),
		"distance": 28.0,
		"segment_type": "approach"
	})
	
	segments.append({
		"name": "intersection_crossing",
		"start_pos": Vector3(-7.0, 0.0, -1.25),
		"end_pos": Vector3(7.0, 0.0, -1.25),
		"distance": 14.0,
		"segment_type": "crossing"
	})
	
	segments.append({
		"name": "intersection_to_exit",
		"start_pos": Vector3(7.0, 0.0, -1.25),
		"end_pos": Vector3(35.0, 0.0, -1.25),
		"distance": 28.0,
		"segment_type": "exit"
	})

func _create_east_west_journey():
	segments.append({
		"name": "spawn_to_intersection",
		"start_pos": Vector3(35.0, 0.0, 1.25),
		"end_pos": Vector3(7.0, 0.0, 1.25),
		"distance": 28.0,
		"segment_type": "approach"
	})
	
	segments.append({
		"name": "intersection_crossing",
		"start_pos": Vector3(7.0, 0.0, 1.25),
		"end_pos": Vector3(-7.0, 0.0, 1.25),
		"distance": 14.0,
		"segment_type": "crossing"
	})
	
	segments.append({
		"name": "intersection_to_exit",
		"start_pos": Vector3(-7.0, 0.0, 1.25),
		"end_pos": Vector3(-35.0, 0.0, 1.25),
		"distance": 28.0,
		"segment_type": "exit"
	})

func _create_south_north_journey():
	segments.append({
		"name": "spawn_to_intersection",
		"start_pos": Vector3(0.0, 0.0, 35.0),
		"end_pos": Vector3(0.0, 0.0, 7.0),
		"distance": 28.0,
		"segment_type": "approach"
	})
	
	segments.append({
		"name": "intersection_crossing",
		"start_pos": Vector3(0.0, 0.0, 7.0),
		"end_pos": Vector3(0.0, 0.0, -7.0),
		"distance": 14.0,
		"segment_type": "crossing"
	})
	
	segments.append({
		"name": "intersection_to_exit",
		"start_pos": Vector3(0.0, 0.0, -7.0),
		"end_pos": Vector3(0.0, 0.0, -35.0),
		"distance": 28.0,
		"segment_type": "exit"
	})

func calculate_travel_time_for_segment(segment_index: int, considering_traffic: bool = true) -> float:
	if segment_index >= segments.size():
		return 0.0
	
	var segment = segments[segment_index]
	var base_speed = car.personality_config.base_speed
	var distance = segment.distance
	
	match segment.segment_type:
		"approach":
			return _calculate_approach_time(distance, base_speed, considering_traffic)
		"crossing":
			return _calculate_crossing_time(distance, base_speed)
		"exit":
			return _calculate_exit_time(distance, base_speed)
		_:
			return distance / base_speed

func _calculate_approach_time(distance: float, speed: float, considering_traffic: bool) -> float:
	var base_time = distance / speed
	
	if not considering_traffic:
		return base_time
	
	var personality_factor = 1.0
	match car.personality:
		DiscreteCar.DriverPersonality.AGGRESSIVE:
			personality_factor = 0.9
		DiscreteCar.DriverPersonality.CONSERVATIVE:
			personality_factor = 1.2
		DiscreteCar.DriverPersonality.ELDERLY:
			personality_factor = 1.4
		DiscreteCar.DriverPersonality.NORMAL:
			personality_factor = 1.0
	
	return base_time * personality_factor

func _calculate_crossing_time(distance: float, speed: float) -> float:
	var crossing_speed = speed * 0.8
	return distance / crossing_speed

func _calculate_exit_time(distance: float, speed: float) -> float:
	var exit_speed = speed * 1.1
	return distance / exit_speed

func calculate_total_journey_time(considering_traffic: bool = true) -> float:
	total_journey_time = 0.0
	
	for i in range(segments.size()):
		total_journey_time += calculate_travel_time_for_segment(i, considering_traffic)
	
	return total_journey_time

func get_spawn_rate_for_direction(direction: DiscreteCar.Direction, current_hour: int) -> float:
	var base_rate = 0.0
	
	match direction:
		DiscreteCar.Direction.LEFT_TO_RIGHT:
			base_rate = SPAWN_RATES.west_east_rate
		DiscreteCar.Direction.RIGHT_TO_LEFT:
			base_rate = SPAWN_RATES.east_west_rate
		DiscreteCar.Direction.BOTTOM_TO_TOP:
			base_rate = SPAWN_RATES.south_north_rate
	
	var multiplier = RUSH_HOUR_MULTIPLIERS.get(current_hour, 1.0)
	return base_rate * multiplier

func get_current_segment() -> Dictionary:
	if current_segment_index >= segments.size():
		return {}
	return segments[current_segment_index]

func advance_to_next_segment():
	current_segment_index += 1

func is_journey_complete() -> bool:
	return current_segment_index >= segments.size()

func get_position_in_segment(progress_ratio: float) -> Vector3:
	var segment = get_current_segment()
	if segment.is_empty():
		return car.current_position
	
	var start_pos = segment.start_pos as Vector3
	var end_pos = segment.end_pos as Vector3
	
	return start_pos.lerp(end_pos, clamp(progress_ratio, 0.0, 1.0))

func predict_arrival_at_intersection(spawn_time: float, current_time: float) -> float:
	if current_segment_index > 0:
		return spawn_time
	
	var approach_time = calculate_travel_time_for_segment(0)
	return spawn_time + approach_time

func will_need_to_wait_for_light(arrival_time: float) -> bool:
	var cycle_phase = fmod(arrival_time, TRAFFIC_LIGHT_CYCLE.total_cycle)
	var light_state = get_light_state_at_time(arrival_time)
	
	if light_state == "green":
		return false
	elif light_state == "yellow":
		return car.should_stop_at_yellow("yellow")
	else:
		return true

func get_light_state_at_time(time: float) -> String:
	var cycle_phase = fmod(time, TRAFFIC_LIGHT_CYCLE.total_cycle)
	var phase_ratio = cycle_phase / TRAFFIC_LIGHT_CYCLE.total_cycle
	
	match car.direction:
		DiscreteCar.Direction.LEFT_TO_RIGHT, DiscreteCar.Direction.RIGHT_TO_LEFT:
			if phase_ratio < (20.0/40.0):
				return "green"
			elif phase_ratio < (23.0/40.0):
				return "yellow" 
			else:
				return "red"
		DiscreteCar.Direction.BOTTOM_TO_TOP:
			if phase_ratio < (24.0/40.0):
				return "red"
			elif phase_ratio < (34.0/40.0):
				return "green"
			elif phase_ratio < (37.0/40.0):
				return "yellow"
			else:
				return "red"
		_:
			return "red"

func calculate_wait_time_if_needed(arrival_time: float) -> float:
	if not will_need_to_wait_for_light(arrival_time):
		return 0.0
	
	var cycle_phase = fmod(arrival_time, TRAFFIC_LIGHT_CYCLE.total_cycle)
	var next_green_time = 0.0
	
	match car.direction:
		DiscreteCar.Direction.LEFT_TO_RIGHT, DiscreteCar.Direction.RIGHT_TO_LEFT:
			if cycle_phase > 20.0:
				next_green_time = TRAFFIC_LIGHT_CYCLE.total_cycle - cycle_phase
			else:
				next_green_time = 0.0
		DiscreteCar.Direction.BOTTOM_TO_TOP:
			if cycle_phase < 24.0:
				next_green_time = 24.0 - cycle_phase
			else:
				next_green_time = (TRAFFIC_LIGHT_CYCLE.total_cycle + 24.0) - cycle_phase
	
	return max(0.0, next_green_time)

func get_debug_info() -> String:
	var segment_name = "completed"
	if current_segment_index < segments.size():
		segment_name = segments[current_segment_index].name
	
	return "Journey %d: Car %d - Segment %d/%d (%s)" % [
		journey_id,
		car.car_id,
		current_segment_index + 1,
		segments.size(),
		segment_name
	]