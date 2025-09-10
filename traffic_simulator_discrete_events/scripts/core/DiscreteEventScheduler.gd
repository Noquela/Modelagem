class_name DiscreteEventScheduler
extends RefCounted

## Sistema de agendamento de eventos discretos com predição para renderização
## CHAVE: Este sistema permite que o frontend "veja o futuro" para interpolar movimento

# Fila de eventos futuros (ordenada por tempo)
var future_events: Array[DiscreteEvent] = []

# Relógio da simulação
var simulation_clock: SimulationClock

# Entidades ativas no sistema
var entities: Dictionary = {}

# Cache para predição visual (OTIMIZAÇÃO CRÍTICA)
var prediction_cache: Dictionary = {}
var cache_update_time: float = 0.0
var cache_duration: float = 0.1  # Cache válido por 100ms

# Estatísticas
var total_events_scheduled: int = 0
var total_events_executed: int = 0

signal event_executed(event: DiscreteEvent)
signal entity_created(entity_id: int)
signal entity_destroyed(entity_id: int)

func _init(clock: SimulationClock = null):
	if clock == null:
		simulation_clock = SimulationClock.new()
	else:
		simulation_clock = clock

## ============================================================================
## SISTEMA DE AGENDAMENTO DE EVENTOS
## ============================================================================

## Agenda um evento para execução futura
func schedule_event(event: DiscreteEvent) -> void:
	# Validação
	if event.event_time < simulation_clock.get_time():
		print("WARNING: Tentando agendar evento no passado! Time: %.2f, Current: %.2f" % 
			  [event.event_time, simulation_clock.get_time()])
		return
	
	# Inserir ordenado por tempo (binary search para performance)
	_insert_event_ordered(event)
	total_events_scheduled += 1
	
	# Invalidar cache de predição
	_invalidate_prediction_cache()
	
	print("Scheduled: %s" % event.get_debug_string())

## Insere evento mantendo ordenação por tempo
func _insert_event_ordered(event: DiscreteEvent) -> void:
	if future_events.is_empty():
		future_events.append(event)
		return
	
	# Binary search para inserção eficiente
	var left = 0
	var right = future_events.size()
	
	while left < right:
		var mid = (left + right) / 2
		if future_events[mid].compare_time(event):
			left = mid + 1
		else:
			right = mid
	
	future_events.insert(left, event)

## Processa próximo evento na fila
func process_next_event() -> bool:
	if future_events.is_empty():
		return false
	
	var next_event = future_events[0]
	
	# Avança tempo da simulação para o evento
	simulation_clock.advance_to(next_event.event_time)
	
	# Remove evento da fila
	future_events.pop_front()
	
	# Executa evento
	next_event.execute(self)
	
	# Estatísticas
	total_events_executed += 1
	simulation_clock.increment_event_count()
	
	# Emitir signal
	event_executed.emit(next_event)
	
	print("Executed: %s" % next_event.get_debug_string())
	return true

## Processa todos os eventos até um tempo específico
func process_events_until(target_time: float) -> int:
	var events_processed = 0
	
	while not future_events.is_empty() and future_events[0].event_time <= target_time:
		if process_next_event():
			events_processed += 1
		else:
			break
	
	# Avança tempo mesmo se não houve eventos
	simulation_clock.advance_to(target_time)
	
	return events_processed

## ============================================================================
## SISTEMA DE PREDIÇÃO PARA RENDERIZAÇÃO (INOVAÇÃO CHAVE!)
## ============================================================================

## Retorna todos os eventos futuros de uma entidade dentro de uma janela de tempo
func get_future_events_for_entity(entity_id: int, time_window: float) -> Array[DiscreteEvent]:
	var current_time = simulation_clock.get_time()
	var cutoff_time = current_time + time_window
	var entity_events: Array[DiscreteEvent] = []
	
	for event in future_events:
		if event.event_time > cutoff_time:
			break  # Eventos estão ordenados, podemos parar aqui
			
		if event.entity_id == entity_id:
			entity_events.append(event)
	
	return entity_events

## Prediz a posição de uma entidade em um tempo futuro específico
## ESTA É A FUNÇÃO MÁGICA que permite renderização fluida!
func predict_entity_position_at_time(entity_id: int, target_time: float) -> Vector3:
	# Verificar cache primeiro
	var cache_key = str(entity_id) + "_" + str(target_time)
	if _is_cache_valid() and prediction_cache.has(cache_key):
		return prediction_cache[cache_key]
	
	# Buscar eventos da entidade
	var current_time = simulation_clock.get_time()
	var entity_events = get_future_events_for_entity(entity_id, target_time - current_time + 1.0)
	
	var predicted_position = Vector3.ZERO
	
	if entity_events.is_empty():
		# Sem eventos futuros, usar posição atual ou extrapolação linear
		predicted_position = _extrapolate_current_position(entity_id, target_time)
	else:
		# Interpolar baseado em eventos agendados
		predicted_position = _interpolate_from_events(entity_id, target_time, entity_events)
	
	# Cachear resultado
	if _should_cache():
		prediction_cache[cache_key] = predicted_position
	
	return predicted_position

## Interpola posição baseado em eventos futuros agendados
func _interpolate_from_events(entity_id: int, target_time: float, events: Array[DiscreteEvent]) -> Vector3:
	# Por agora, retorna posição placeholder
	# Será implementado completamente no Sprint 2 com lógica de veículos
	
	# Buscar evento mais próximo antes e depois do target_time
	var before_event: DiscreteEvent = null
	var after_event: DiscreteEvent = null
	
	for event in events:
		if event.event_time <= target_time:
			before_event = event
		elif event.event_time > target_time and after_event == null:
			after_event = event
			break
	
	# Interpolação linear simples por agora
	if before_event != null and after_event != null:
		var t = (target_time - before_event.event_time) / (after_event.event_time - before_event.event_time)
		
		var pos_before = before_event.data.get("position", Vector3.ZERO)
		var pos_after = after_event.data.get("position", Vector3.ZERO)
		
		return pos_before.lerp(pos_after, t)
	elif before_event != null:
		return before_event.data.get("position", Vector3.ZERO)
	elif after_event != null:
		return after_event.data.get("position", Vector3.ZERO)
	
	return Vector3.ZERO

## Extrapola posição atual quando não há eventos futuros
func _extrapolate_current_position(entity_id: int, target_time: float) -> Vector3:
	# Placeholder - será implementado no Sprint 2
	return Vector3.ZERO

## ============================================================================
## SISTEMA DE CACHE PARA PERFORMANCE
## ============================================================================

func _is_cache_valid() -> bool:
	return (simulation_clock.get_time() - cache_update_time) < cache_duration

func _should_cache() -> bool:
	return not simulation_clock.is_paused

func _invalidate_prediction_cache() -> void:
	prediction_cache.clear()
	cache_update_time = simulation_clock.get_time()

func _update_cache_if_needed() -> void:
	if not _is_cache_valid():
		prediction_cache.clear()
		cache_update_time = simulation_clock.get_time()

## ============================================================================
## GERENCIAMENTO DE ENTIDADES
## ============================================================================

func register_entity(entity_id: int, initial_data: Dictionary = {}) -> void:
	entities[entity_id] = initial_data
	entity_created.emit(entity_id)
	print("Entity registered: %d" % entity_id)

func unregister_entity(entity_id: int) -> void:
	if entities.has(entity_id):
		entities.erase(entity_id)
		_remove_entity_events(entity_id)
		entity_destroyed.emit(entity_id)
		print("Entity unregistered: %d" % entity_id)

func _remove_entity_events(entity_id: int) -> void:
	for i in range(future_events.size() - 1, -1, -1):
		if future_events[i].entity_id == entity_id:
			future_events.remove_at(i)

## ============================================================================
## INFORMAÇÕES E DEBUG
## ============================================================================

func get_next_event_time() -> float:
	if future_events.is_empty():
		return -1.0
	return future_events[0].event_time

func get_pending_events_count() -> int:
	return future_events.size()

func get_entity_count() -> int:
	return entities.size()

func get_statistics() -> Dictionary:
	return {
		"current_time": simulation_clock.get_time(),
		"formatted_time": simulation_clock.format_time(),
		"pending_events": get_pending_events_count(),
		"total_scheduled": total_events_scheduled,
		"total_executed": total_events_executed,
		"active_entities": get_entity_count(),
		"next_event_time": get_next_event_time(),
		"events_per_second": simulation_clock.get_events_per_second(),
		"cache_size": prediction_cache.size()
	}

func print_debug_info() -> void:
	print("=== DISCRETE EVENT SCHEDULER DEBUG ===")
	var stats = get_statistics()
	for key in stats.keys():
		print("%s: %s" % [key, str(stats[key])])
	
	print("\nNext 5 events:")
	for i in range(min(5, future_events.size())):
		print("  %d: %s" % [i+1, future_events[i].get_debug_string()])

func clear_all() -> void:
	future_events.clear()
	entities.clear()
	prediction_cache.clear()
	total_events_scheduled = 0
	total_events_executed = 0
	simulation_clock.reset()
	print("Event scheduler cleared")