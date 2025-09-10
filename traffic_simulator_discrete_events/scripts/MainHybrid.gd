extends Node3D

## Main.gd para Sistema Híbrido
## Inicializa o HybridTrafficSystem que combina eventos discretos + renderização 3D

func _ready():
	print("🚀 Iniciando Sistema Híbrido via MainHybrid.gd")
	
	# Aguardar frame para garantir inicialização completa
	await get_tree().process_frame
	
	# Criar sistema híbrido
	var hybrid_system = HybridTrafficSystem.new()
	hybrid_system.name = "HybridTrafficSystem"
	add_child(hybrid_system)
	
	# Conectar sinais do sistema híbrido
	if hybrid_system.has_signal("system_ready"):
		hybrid_system.system_ready.connect(_on_hybrid_system_ready)
	
	print("✅ Sistema Híbrido iniciado!")

func _on_hybrid_system_ready():
	"""Callback quando sistema híbrido está pronto"""
	print("🎯 Sistema Híbrido totalmente inicializado e funcionando!")

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("🔌 Sistema Híbrido - Shutting down...")
		get_tree().quit()