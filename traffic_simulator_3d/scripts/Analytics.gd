extends Control

# UI Labels will be created programmatically
var fps_label: Label
var cars_label: Label 
var throughput_label: Label
var congestion_label: Label
var time_label: Label

# Chart data
var throughput_history: Array[float] = []
var congestion_history: Array[float] = []
var max_history_size: int = 300  # 5 minutes at 60 FPS

# UI Elements
var stats_panel: Panel
var throughput_chart: Control
var personality_breakdown: Control

func _ready():
	create_ui_elements()
	set_process(true)

func create_ui_elements():
	# Create modern dashboard layout
	create_modern_dashboard()

func create_styled_panel(bg_color: Color) -> Panel:
	# Create a panel with custom background color
	var panel = Panel.new()
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = bg_color
	panel.add_theme_stylebox_override("panel", style_box)
	return panel

var ui_visible: bool = true

func create_modern_dashboard():
	# Create compact UI that doesn't block game view
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_mouse_filter(Control.MOUSE_FILTER_IGNORE)  # Let clicks pass through
	
	# Create compact stats overlay (top-left)
	create_compact_stats_overlay()
	
	# Add toggle instruction
	create_toggle_instruction()

func create_compact_stats_overlay():
	var stats_overlay = create_styled_panel(Color(0.05, 0.05, 0.08, 0.8))
	stats_overlay.name = "StatsOverlay"
	stats_overlay.position = Vector2(10, 10)
	stats_overlay.size = Vector2(280, 160)
	stats_overlay.set_mouse_filter(Control.MOUSE_FILTER_STOP)  # This panel captures mouse
	add_child(stats_overlay)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	stats_overlay.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "🚦 Traffic Sim 3D"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color.CYAN)
	vbox.add_child(title)
	
	# Compact stats
	fps_label = create_compact_stat("FPS", "60", Color.LIME_GREEN, vbox)
	cars_label = create_compact_stat("Cars", "0", Color.ORANGE, vbox)
	throughput_label = create_compact_stat("Throughput", "0.0/s", Color.GREEN, vbox)
	congestion_label = create_compact_stat("Congestion", "0%", Color.RED, vbox)
	time_label = create_compact_stat("Time", "00:00", Color.LIGHT_BLUE, vbox)

func create_compact_stat(label_text: String, value_text: String, color: Color, parent: VBoxContainer) -> Label:
	var hbox = HBoxContainer.new()
	parent.add_child(hbox)
	
	var label = Label.new()
	label.text = label_text + ":"
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.custom_minimum_size.x = 80
	hbox.add_child(label)
	
	var value_label = Label.new()
	value_label.text = value_text
	value_label.add_theme_font_size_override("font_size", 11)
	value_label.add_theme_color_override("font_color", color)
	hbox.add_child(value_label)
	
	return value_label

func create_toggle_instruction():
	var instruction = Label.new()
	instruction.text = "Press [H] to hide/show stats"
	instruction.position = Vector2(10, 180)
	instruction.add_theme_font_size_override("font_size", 10)
	instruction.add_theme_color_override("font_color", Color.GRAY)
	add_child(instruction)

func create_stats_sidebar():
	var sidebar = create_styled_panel(Color(0.08, 0.08, 0.1, 0.9))
	sidebar.name = "StatsSidebar"
	sidebar.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	sidebar.offset_top = 60  # Below top bar
	sidebar.size.x = 300
	add_child(sidebar)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	sidebar.add_child(vbox)
	
	# Section title
	var section_title = Label.new()
	section_title.text = "📊 Live Statistics"
	section_title.add_theme_font_size_override("font_size", 18)
	section_title.add_theme_color_override("font_color", Color.CYAN)
	vbox.add_child(section_title)
	
	# Create metric cards
	cars_label = create_metric_card("🚗 Active Cars", "0", Color.ORANGE, vbox)
	throughput_label = create_metric_card("⚡ Throughput", "0.0 cars/sec", Color.GREEN, vbox)
	congestion_label = create_metric_card("🚥 Congestion", "0%", Color.RED, vbox)
	time_label = create_metric_card("⏱️ Sim Time", "00:00", Color.LIGHT_BLUE, vbox)

func create_metric_card(title: String, value: String, color: Color, parent: VBoxContainer) -> Label:
	var card = create_styled_panel(Color(0.12, 0.12, 0.15, 0.8))
	card.custom_minimum_size.y = 60
	parent.add_child(card)
	
	var card_vbox = VBoxContainer.new()
	card_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(card_vbox)
	
	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	card_vbox.add_child(title_label)
	
	var value_label = Label.new()
	value_label.text = value
	value_label.add_theme_font_size_override("font_size", 18)
	value_label.add_theme_color_override("font_color", color)
	card_vbox.add_child(value_label)
	
	return value_label

func create_controls_panel():
	var controls = create_styled_panel(Color(0.08, 0.08, 0.1, 0.9))
	controls.name = "ControlsPanel"
	controls.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	controls.offset_top = 60
	controls.size = Vector2(250, 200)
	add_child(controls)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controls.add_child(vbox)
	
	var controls_title = Label.new()
	controls_title.text = "⚙️ Simulation Controls"
	controls_title.add_theme_font_size_override("font_size", 16)
	controls_title.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(controls_title)
	
	# Placeholder for future controls
	var status_label = Label.new()
	status_label.text = "Status: Running"
	status_label.add_theme_color_override("font_color", Color.LIME_GREEN)
	vbox.add_child(status_label)

func create_charts_area():
	var charts = create_styled_panel(Color(0.08, 0.08, 0.1, 0.9))
	charts.name = "ChartsArea"
	charts.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	charts.offset_top = -200
	charts.size.y = 200
	add_child(charts)
	
	var charts_title = Label.new()
	charts_title.text = "📈 Real-time Analytics"
	charts_title.position = Vector2(10, 10)
	charts_title.add_theme_font_size_override("font_size", 16)
	charts_title.add_theme_color_override("font_color", Color.MAGENTA)
	charts.add_child(charts_title)

func create_control_panel(parent: VBoxContainer):
	var control_panel = Panel.new()
	control_panel.name = "ControlPanel"
	control_panel.custom_minimum_size = Vector2(300, 80)
	parent.add_child(control_panel)
	
	var hbox = HBoxContainer.new()
	control_panel.add_child(hbox)
	
	# Pause button
	var pause_button = Button.new()
	pause_button.text = "Pause/Resume"
	pause_button.pressed.connect(_on_pause_pressed)
	hbox.add_child(pause_button)
	
	# Camera mode button
	var camera_button = Button.new()
	camera_button.text = "Camera Mode"
	camera_button.pressed.connect(_on_camera_mode_pressed)
	hbox.add_child(camera_button)
	
	# Spawn rate slider
	var spawn_label = Label.new()
	spawn_label.text = "Spawn Rate:"
	hbox.add_child(spawn_label)
	
	var spawn_slider = HSlider.new()
	spawn_slider.min_value = 0.1
	spawn_slider.max_value = 3.0
	spawn_slider.value = 1.0
	spawn_slider.step = 0.1
	spawn_slider.value_changed.connect(_on_spawn_rate_changed)
	hbox.add_child(spawn_slider)

func create_charts_panel(parent: VBoxContainer):
	var charts_panel = Panel.new()
	charts_panel.name = "ChartsPanel"
	charts_panel.custom_minimum_size = Vector2(400, 200)
	parent.add_child(charts_panel)
	
	throughput_chart = Control.new()
	throughput_chart.name = "ThroughputChart"
	throughput_chart.custom_minimum_size = Vector2(380, 180)
	charts_panel.add_child(throughput_chart)

func create_personality_panel(parent: VBoxContainer):
	personality_breakdown = Panel.new()
	personality_breakdown.name = "PersonalityPanel"
	personality_breakdown.custom_minimum_size = Vector2(300, 150)
	parent.add_child(personality_breakdown)
	
	var personality_label = Label.new()
	personality_label.text = "Driver Personalities Distribution"
	personality_label.position = Vector2(10, 10)
	personality_breakdown.add_child(personality_label)

func update_display(stats: Dictionary):
	# Update modern dashboard metrics
	if fps_label:
		fps_label.text = "FPS: %.0f" % stats.get("fps", 60.0)
	
	if cars_label:
		cars_label.text = "%d" % stats.get("active_cars", 0)
	
	if throughput_label:
		throughput_label.text = "%.1f cars/sec" % stats.get("throughput", 0.0)
	
	if congestion_label:
		var congestion_percent = stats.get("congestion", 0.0) * 100
		congestion_label.text = "%.0f%%" % congestion_percent
	
	if time_label:
		var sim_time = stats.get("simulation_time", 0.0)
		var minutes = int(sim_time / 60)
		var seconds = int(sim_time) % 60
		time_label.text = "Simulation Time: %02d:%02d" % [minutes, seconds]
	
	# Update chart data
	update_chart_data(stats)

func update_chart_data(stats: Dictionary):
	# Add to history arrays
	throughput_history.append(stats.get("throughput", 0.0))
	congestion_history.append(stats.get("congestion", 0.0))
	
	# Limit history size
	if throughput_history.size() > max_history_size:
		throughput_history.pop_front()
		congestion_history.pop_front()
	
	# Redraw charts
	if throughput_chart:
		throughput_chart.queue_redraw()

func _draw():
	if not throughput_chart or throughput_history.is_empty():
		return
	
	draw_throughput_chart()

func draw_throughput_chart():
	var chart_rect = throughput_chart.get_rect()
	var canvas_item = throughput_chart.get_canvas_item()
	
	# Clear background
	RenderingServer.canvas_item_add_rect(canvas_item, chart_rect, Color(0.1, 0.1, 0.1, 0.8))
	
	# Draw grid
	var grid_color = Color(0.3, 0.3, 0.3, 0.5)
	for i in range(5):
		var y = chart_rect.position.y + (chart_rect.size.y / 4) * i
		RenderingServer.canvas_item_add_line(canvas_item, 
			Vector2(chart_rect.position.x, y),
			Vector2(chart_rect.position.x + chart_rect.size.x, y),
			grid_color, 1.0)
	
	# Draw throughput line
	if throughput_history.size() > 1:
		var max_throughput = throughput_history.max()
		if max_throughput > 0:
			var points = PackedVector2Array()
			for i in range(throughput_history.size()):
				var x = chart_rect.position.x + (chart_rect.size.x / throughput_history.size()) * i
				var normalized_value = throughput_history[i] / max_throughput
				var y = chart_rect.position.y + chart_rect.size.y - (normalized_value * chart_rect.size.y)
				points.append(Vector2(x, y))
			
			# Draw line segments
			for i in range(points.size() - 1):
				RenderingServer.canvas_item_add_line(canvas_item, points[i], points[i + 1], Color.GREEN, 2.0)

func _on_pause_pressed():
	var traffic_manager = get_tree().get_first_node_in_group("traffic_manager")
	if traffic_manager and traffic_manager.has_method("pause_simulation"):
		traffic_manager.pause_simulation()

func _on_camera_mode_pressed():
	var camera_controller = get_tree().get_first_node_in_group("camera_controller")
	if camera_controller and camera_controller.has_method("cycle_camera_mode"):
		camera_controller.cycle_camera_mode()

func _on_spawn_rate_changed(value: float):
	var spawn_system = get_tree().get_first_node_in_group("spawn_system")
	if spawn_system and spawn_system.has_method("adjust_spawn_rate"):
		spawn_system.adjust_spawn_rate(value)

func get_personality_stats() -> Dictionary:
	var cars = get_tree().get_nodes_in_group("cars")
	var personality_counts = {
		"Aggressive": 0,
		"Conservative": 0,
		"Normal": 0,
		"Elderly": 0
	}
	
	for car in cars:
		if car.has_method("get_personality_string"):
			var personality = car.get_personality_string()
			if personality in personality_counts:
				personality_counts[personality] += 1
	
	return personality_counts

func update_personality_display():
	var stats = get_personality_stats()
	var total_cars = 0
	for count in stats.values():
		total_cars += count
	
	# Update personality breakdown display
	if personality_breakdown:
		# Clear existing children (except label)
		var children = personality_breakdown.get_children()
		for i in range(1, children.size()):
			children[i].queue_free()
		
		# Add new personality stats
		var y_offset = 40
		for personality in stats.keys():
			var count = stats[personality]
			var percentage = 0.0
			if total_cars > 0:
				percentage = (count / float(total_cars)) * 100
			
			var stat_label = Label.new()
			stat_label.text = "%s: %d (%.1f%%)" % [personality, count, percentage]
			stat_label.position = Vector2(10, y_offset)
			personality_breakdown.add_child(stat_label)
			y_offset += 25

func _process(_delta):
	# Handle UI toggle
	if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_H):
		toggle_ui_visibility()
	
	# Update personality display periodically
	if Engine.get_process_frames() % 60 == 0:  # Every second
		update_personality_display()

func toggle_ui_visibility():
	ui_visible = !ui_visible
	visible = ui_visible