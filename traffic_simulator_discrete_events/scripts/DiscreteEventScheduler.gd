extends Node
class_name DiscreteEventScheduler

# PASSO 3 - SCHEDULER DE EVENTOS DISCRETOS
# RESPONSABILIDADE: APENAS manter fila ordenada + avançar tempo. NÃO sabe o que cada evento faz.

signal event_processed(event: DiscreteEvent)

var event_queue: Array[DiscreteEvent] = []
var current_time: float = 0.0
var displayed_time: float = 0.0  # Tempo mostrado na UI (interpolado)
var is_running: bool = false
var time_scale: float = 1.0
var event_timer: float = 0.0
var event_interval: float = 0.5  # Intervalo entre eventos (em segundos) - mais rápido

func _ready():
	print("📅 DiscreteEventScheduler inicializado")

func _process(delta):
	# Interpolar tempo para visualização contínua
	if is_running:
		# Interpolar displayed_time continuamente em direção ao próximo evento
		if not event_queue.is_empty():
			var next_event_time = event_queue[0].time
			displayed_time = move_toward(displayed_time, next_event_time, delta * time_scale)
		else:
			# Sem eventos - continuar contando normalmente
			displayed_time += delta * time_scale
		
		# Processar eventos automaticamente quando a simulação está rodando
		if not event_queue.is_empty():
			# Atualizar timer baseado na velocidade
			event_timer += delta * time_scale
			
			# Processar evento quando o timer atingir o intervalo
			if event_timer >= event_interval:
				advance_to_next_event()
				event_timer = 0.0  # Reset timer para próximo evento

func schedule_event(event: DiscreteEvent):
	if event.time < current_time:
		push_warning("Tentativa de agendar evento no passado! Evento: %s, Tempo atual: %.2f, Tempo do evento: %.2f" % [
			EventTypes.get_event_name(event.type), current_time, event.time
		])
		return
	
	# Inserir evento na posição correta (fila ordenada por tempo)
	var inserted = false
	for i in range(event_queue.size()):
		if event.is_before(event_queue[i]):
			event_queue.insert(i, event)
			inserted = true
			break
	
	if not inserted:
		event_queue.append(event)
	
	print("📅 Evento agendado: %s em t=%.2f" % [EventTypes.get_event_name(event.type), event.time])

func process_next_event():
	if event_queue.is_empty():
		return null
	
	var next_event = event_queue.pop_front()
	current_time = next_event.time
	displayed_time = current_time  # Sincronizar tempo mostrado
	
	print("⚡ Processando evento: %s em t=%.2f" % [EventTypes.get_event_name(next_event.type), current_time])
	event_processed.emit(next_event)
	
	return next_event

func start_simulation():
	is_running = true
	print("▶️ Simulação iniciada em t=%.2f" % current_time)

func pause_simulation():
	is_running = false
	print("⏸️ Simulação pausada em t=%.2f" % current_time)

func reset_simulation():
	event_queue.clear()
	current_time = 0.0
	displayed_time = 0.0  # Resetar tempo mostrado também
	is_running = false
	print("🔄 Simulação resetada")

func advance_to_next_event():
	if not is_running or event_queue.is_empty():
		return false
	
	return process_next_event() != null

func get_next_event_time() -> float:
	if event_queue.is_empty():
		return -1.0
	return event_queue[0].time

func get_events_count() -> int:
	return event_queue.size()

func get_current_time() -> float:
	return current_time

func get_displayed_time() -> float:
	return displayed_time

func set_time_scale(scale: float):
	time_scale = max(0.1, scale)

func set_event_interval(interval: float):
	event_interval = max(0.1, interval)  # Mínimo 0.1s entre eventos

func get_queue_info() -> String:
	if event_queue.is_empty():
		return "Fila vazia"
	
	var info = "Próximos eventos:\n"
	var max_show = min(5, event_queue.size())
	
	for i in range(max_show):
		var event = event_queue[i]
		info += "  t=%.2f: %s\n" % [event.time, EventTypes.get_event_name(event.type)]
	
	if event_queue.size() > max_show:
		info += "  ... e mais %d eventos" % (event_queue.size() - max_show)
	
	return info
