extends RefCounted
class_name TrafficQueue

var direction_name: String
var queued_cars: Array[DiscreteCar] = []
var max_queue_length: int = 10
var total_cars_processed: int = 0
var total_wait_time: float = 0.0

func _init(dir_name: String):
	direction_name = dir_name

func add_car(car: DiscreteCar):
	if queued_cars.size() >= max_queue_length:
		print("WARNING: %s queue full! Car %d may be delayed" % [direction_name, car.car_id])
		return
	
	# Adicionar na ordem de chegada (FIFO)
	queued_cars.append(car)
	car.start_waiting(car.wait_start_time if car.wait_start_time > 0 else 0.0)

func remove_car(car: DiscreteCar):
	var index = queued_cars.find(car)
	if index >= 0:
		queued_cars.remove_at(index)

func get_next_car() -> DiscreteCar:
	if queued_cars.is_empty():
		return null
	return queued_cars[0]

func process_next_car() -> DiscreteCar:
	if queued_cars.is_empty():
		return null
	
	var car = queued_cars.pop_front()
	total_cars_processed += 1
	
	# Calcular tempo de espera
	if car.wait_start_time > 0:
		var wait_time = car.wait_start_time  # Simplificado por agora
		total_wait_time += wait_time
	
	return car

func process_all_cars() -> int:
	var processed_count = 0
	
	while not queued_cars.is_empty():
		var car = process_next_car()
		if car:
			processed_count += 1
			print("🚗 Released Car %d from %s queue" % [car.car_id, direction_name])
		else:
			break
	
	return processed_count

func is_empty() -> bool:
	return queued_cars.is_empty()

func get_size() -> int:
	return queued_cars.size()

func get_waiting_time_for_car(car: DiscreteCar) -> float:
	var index = queued_cars.find(car)
	if index < 0:
		return 0.0
	
	# Tempo de espera baseado na posição na fila
	# Carros na frente processam primeiro
	return float(index) * 2.0  # 2s por carro na frente

func get_average_wait_time() -> float:
	if total_cars_processed == 0:
		return 0.0
	return total_wait_time / float(total_cars_processed)

func peek_next_cars(count: int) -> Array[DiscreteCar]:
	var result: Array[DiscreteCar] = []
	var limit = min(count, queued_cars.size())
	
	for i in range(limit):
		result.append(queued_cars[i])
	
	return result

func clear():
	queued_cars.clear()
	total_cars_processed = 0
	total_wait_time = 0.0

func get_debug_info() -> String:
	return "%s Queue: %d cars waiting, %d processed, %.1fs avg wait" % [
		direction_name,
		get_size(),
		total_cars_processed,
		get_average_wait_time()
	]