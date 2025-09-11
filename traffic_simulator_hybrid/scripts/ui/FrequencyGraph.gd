extends Control

# GRÁFICO AVANÇADO DE FREQUÊNCIA DE EVENTOS
# Desenha gráfico de barras e linha temporal

var event_frequencies = {}
var event_timeline = []
var max_timeline_points = 50

# Visual settings
var colors = {
	"car_spawned": Color.GREEN,
	"car_despawned": Color.RED,
	"car_stopped": Color.ORANGE,
	"car_started": Color.BLUE,
	"traffic_light_changed": Color.YELLOW,
	"car_position_updated": Color(0.5, 0.5, 0.5, 0.3)
}

var graph_mode = "bars"
var margin = Vector2(40, 30)

func _ready():
	custom_minimum_size = Vector2(300, 200)

func _draw():
	match graph_mode:
		"bars":
			draw_frequency_bars()
		"timeline":
			draw_timeline_graph()

func draw_frequency_bars():
	var area = get_rect()
	var available_area = Rect2(margin.x, margin.y, 
							  area.size.x - margin.x * 2, 
							  area.size.y - margin.y * 2)
	
	if event_frequencies.is_empty():
		var font = get_theme_default_font()
		var font_size = 14
		var text = "Sem dados"
		var text_pos = Vector2(area.size.x/2 - 40, area.size.y/2)
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
		return
	
	# Encontrar max frequency para normalização
	var max_freq = 0
	for event_type in event_frequencies.keys():
		if event_frequencies[event_type] > max_freq:
			max_freq = event_frequencies[event_type]
	
	if max_freq == 0:
		return
	
	# Filtrar eventos muito frequentes
	var filtered_events = {}
	for event_type in event_frequencies.keys():
		if event_type != "car_position_updated" or event_frequencies[event_type] < max_freq * 0.1:
			filtered_events[event_type] = event_frequencies[event_type]
	
	var event_count = filtered_events.size()
	if event_count == 0:
		return
	
	var bar_width = available_area.size.x / event_count
	var x_pos = margin.x
	
	# Draw bars
	for event_type in filtered_events.keys():
		var frequency = filtered_events[event_type]
		var bar_height = (frequency / float(max_freq)) * available_area.size.y
		var color = colors.get(event_type, Color.WHITE)
		
		# Barra
		var bar_rect = Rect2(x_pos, available_area.position.y + available_area.size.y - bar_height,
							bar_width - 2, bar_height)
		draw_rect(bar_rect, color)
		
		# Valor no topo
		var font = get_theme_default_font()
		var text = str(frequency)
		var text_pos = Vector2(x_pos + bar_width/2 - 10, bar_rect.position.y - 5)
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
		
		x_pos += bar_width

func draw_timeline_graph():
	var area = get_rect()
	var available_area = Rect2(margin.x, margin.y, 
							  area.size.x - margin.x * 2, 
							  area.size.y - margin.y * 2)
	
	if event_timeline.is_empty():
		var font = get_theme_default_font()
		var text = "Sem dados"
		var text_pos = Vector2(area.size.x/2 - 40, area.size.y/2)
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		return
	
	# Draw timeline background
	draw_rect(available_area, Color(0.1, 0.1, 0.1, 0.5))
	
	# Get time range
	var min_time = event_timeline[0].timestamp if event_timeline.size() > 0 else 0
	var max_time = event_timeline[-1].timestamp if event_timeline.size() > 0 else 1
	var time_range = max_time - min_time
	
	if time_range <= 0:
		time_range = 1
	
	# Draw events as points
	for event in event_timeline:
		var x_pos = margin.x + ((event.timestamp - min_time) / time_range) * available_area.size.x
		var y_pos = margin.y + available_area.size.y/2
		
		var color = colors.get(event.event_type, Color.WHITE)
		draw_circle(Vector2(x_pos, y_pos), 3, color)

func update_data(frequencies: Dictionary, timeline: Array):
	event_frequencies = frequencies.duplicate()
	event_timeline = timeline.duplicate()
	
	# Manter apenas os últimos N pontos
	if event_timeline.size() > max_timeline_points:
		event_timeline = event_timeline.slice(-max_timeline_points)
	
	queue_redraw()

func set_graph_mode(mode: String):
	if mode in ["bars", "timeline"]:
		graph_mode = mode
		queue_redraw()

func toggle_graph_mode():
	if graph_mode == "bars":
		graph_mode = "timeline"
	else:
		graph_mode = "bars"
	queue_redraw()
