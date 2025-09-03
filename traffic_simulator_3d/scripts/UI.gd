extends Control

# INTERFACE EXATA DO HTML - linhas 22-90
@onready var controls_panel = $ControlsPanel
@onready var info_panel = $InfoPanel

# Controles (HTML linha 69-78)
@onready var pause_button = $ControlsPanel/VBoxContainer/PauseButton
@onready var reset_camera_button = $ControlsPanel/VBoxContainer/ResetCameraButton
@onready var timer_label = $ControlsPanel/VBoxContainer/StatusContainer/TimerLabel
@onready var status_label = $ControlsPanel/VBoxContainer/StatusContainer/StatusLabel
@onready var car_count_label = $ControlsPanel/VBoxContainer/StatusContainer/CarCountLabel

# Referências do sistema
var traffic_manager: Node
var camera_controller: Node
var main_node: Node

var start_time: float = 0.0
var is_running: bool = true

func _ready():
	setup_ui_layout()
	connect_signals()
	find_system_references()
	start_time = Time.get_time_dict_from_system()["second"]

func setup_ui_layout():
	# PAINEL DE CONTROLES - HTML linhas 22-31 + 46-63
	controls_panel.position = Vector2(10, 10)  # HTML: top: 10px; left: 10px
	controls_panel.size = Vector2(250, 150)
	
	# Estilo do painel - HTML background: rgba(0, 0, 0, 0.8)
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0, 0, 0.8)
	style_box.corner_radius_top_left = 5
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5
	controls_panel.add_theme_stylebox_override("panel", style_box)
	
	# PAINEL DE INFORMAÇÕES - HTML linhas 33-44 + 80-90
	info_panel.position = Vector2(get_viewport().size.x - 220, 10)  # HTML: top: 10px; right: 10px
	info_panel.size = Vector2(200, 300)
	info_panel.add_theme_stylebox_override("panel", style_box)

func connect_signals():
	# BOTÕES - HTML funções toggleSimulation() e resetCamera()
	pause_button.pressed.connect(_on_pause_button_pressed)
	reset_camera_button.pressed.connect(_on_reset_camera_button_pressed)

func find_system_references():
	# Encontrar referências do sistema
	traffic_manager = get_tree().get_first_node_in_group("traffic_manager")
	camera_controller = get_node("../CameraController")
	main_node = get_node("..")

func _process(delta):
	update_ui()

func update_ui():
	# ATUALIZAÇÃO EM TEMPO REAL - HTML função updateUI() linhas 436-446
	if not traffic_manager:
		return
		
	# Timer - HTML linha 437
	var current_time = Time.get_time_dict_from_system()["second"]
	var elapsed = int(current_time - start_time)
	timer_label.text = "Tempo: " + str(elapsed) + "s"
	
	# Status - HTML linha 439
	status_label.text = "Status: " + ("Rodando" if is_running else "Pausado")
	
	# Contagem de carros - HTML linhas 441-445
	var stats = traffic_manager.get_current_stats()
	car_count_label.text = "Carros: " + str(stats.active_cars)

func _on_pause_button_pressed():
	# FUNÇÃO EXATA DO HTML - toggleSimulation() linhas 448-453
	if traffic_manager:
		traffic_manager.pause_simulation()
		is_running = !is_running
		# Atualizar texto do botão
		pause_button.text = "Continuar" if not is_running else "Pausar"

func _on_reset_camera_button_pressed():
	# FUNÇÃO EXATA DO HTML - resetCamera() linhas 455-458
	if camera_controller:
		camera_controller.reset_camera()

func _notification(what):
	# Ajustar layout quando a janela redimensiona
	if what == NOTIFICATION_RESIZED:
		if info_panel:
			info_panel.position = Vector2(get_viewport().size.x - 220, 10)