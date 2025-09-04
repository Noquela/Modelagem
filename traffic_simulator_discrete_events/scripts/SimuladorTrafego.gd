# Simulador Principal de Tráfego por Eventos Discretos
extends Node3D
class_name SimuladorTrafego

@onready var gerenciador_eventos: GerenciadorEventos

# Configurações da simulação
var configuracao = {
	"taxa_chegada": 2.0,  # carros por minuto
	"tempo_semaforo_verde": 30.0,  # segundos
	"tempo_semaforo_vermelho": 25.0,  # segundos
	"velocidade_simulacao": 1.0
}

# Estatísticas da simulação
var estatisticas = {
	"carros_chegados": 0,
	"carros_atendidos": 0,
	"tempo_espera_total": 0.0,
	"tempo_espera_medio": 0.0,
	"tamanho_fila_max": 0,
	"carros_na_fila": 0
}

# Estado do semáforo
var semaforo_verde: bool = true
var fila_carros: Array = []

func _ready():
	print("🚦 Simulador de Tráfego por Eventos Discretos iniciado")
	
	# O ambiente 3D agora é gerenciado pelo Main.gd (sistema anterior)
	
	# Criar gerenciador de eventos
	gerenciador_eventos = GerenciadorEventos.new()
	add_child(gerenciador_eventos)
	
	# Conectar sinais
	gerenciador_eventos.evento_processado.connect(_on_evento_processado)
	gerenciador_eventos.tempo_simulacao_atualizado.connect(_on_tempo_atualizado)
	gerenciador_eventos.fila_eventos_atualizada.connect(_on_fila_atualizada)
	
	# Inicializar simulação
	iniciar_simulacao()

func iniciar_simulacao():
	print("🚀 Iniciando simulação de eventos discretos")
	
	# AGUARDAR SPAWN SYSTEM INICIALIZAR
	await get_tree().process_frame
	await get_tree().process_frame
	
	# FORÇAR PRIMEIRO SPAWN - garantir que sistema inicie
	gerenciador_eventos.agendar_evento(5.0, GerenciadorEventos.TipoEvento.CHEGADA_CARRO)
	print("🚗 Primeiro spawn agendado para t=5.0s")
	
	# Agendar primeira mudança de semáforo
	gerenciador_eventos.agendar_evento(configuracao.tempo_semaforo_verde, GerenciadorEventos.TipoEvento.MUDANCA_SEMAFORO)
	
	# Agendar primeira atualização de estatísticas
	gerenciador_eventos.agendar_evento(10.0, GerenciadorEventos.TipoEvento.ATUALIZAR_ESTATISTICAS)
	
	# Iniciar execução
	gerenciador_eventos.executar_simulacao()
	print("🎬 Simulação iniciada - eventos agendados!")

func processar_chegada_carro_basico():
	"""Fallback caso SpawnSystem não funcione"""
	estatisticas.carros_chegados += 1
	
	var dados_carro = {
		"id": estatisticas.carros_chegados,
		"tempo_chegada": gerenciador_eventos.tempo_simulacao,
		"tempo_espera_inicio": 0.0
	}
	
	# Sistema básico sem visual detalhado
	if semaforo_verde and fila_carros.is_empty():
		var tempo_saida = gerenciador_eventos.tempo_simulacao + DistribuicoesEstatisticas.tempo_processamento_semaforo()
		gerenciador_eventos.agendar_evento(tempo_saida, GerenciadorEventos.TipoEvento.SAIDA_CARRO, dados_carro)
		print("✅ Carro %d passa direto" % dados_carro.id)
	else:
		dados_carro.tempo_espera_inicio = gerenciador_eventos.tempo_simulacao
		fila_carros.append(dados_carro)
		estatisticas.carros_na_fila = fila_carros.size()
		print("🔴 Carro %d na fila" % dados_carro.id)
	
	# Reagendar próximo
	var proximo_tempo = gerenciador_eventos.tempo_simulacao + DistribuicoesEstatisticas.tempo_chegada_carros(configuracao.taxa_chegada)
	gerenciador_eventos.agendar_evento(proximo_tempo, GerenciadorEventos.TipoEvento.CHEGADA_CARRO)

# Callbacks dos eventos
func _on_evento_processado(evento: GerenciadorEventos.Evento):
	match evento.tipo:
		GerenciadorEventos.TipoEvento.CHEGADA_CARRO:
			processar_chegada_carro(evento)
		GerenciadorEventos.TipoEvento.MUDANCA_SEMAFORO:
			processar_mudanca_semaforo(evento)
		GerenciadorEventos.TipoEvento.CARRO_NO_SEMAFORO:
			processar_carro_no_semaforo(evento)
		GerenciadorEventos.TipoEvento.SAIDA_CARRO:
			processar_saida_carro(evento)
		GerenciadorEventos.TipoEvento.ATUALIZAR_ESTATISTICAS:
			processar_atualizacao_estatisticas(evento)

func processar_chegada_carro(evento: GerenciadorEventos.Evento):
	# DELEGAR PARA SPAWN SYSTEM (sistema anterior)
	var spawn_system = get_parent().get_node("SpawnSystem")
	if spawn_system and spawn_system.has_method("processar_evento_spawn"):
		spawn_system.processar_evento_spawn()
		estatisticas.carros_chegados += 1
	else:
		print("⚠️ SpawnSystem não encontrado - usando sistema básico")
		# Fallback para sistema básico
		processar_chegada_carro_basico()

func processar_mudanca_semaforo(_evento: GerenciadorEventos.Evento):
	semaforo_verde = !semaforo_verde
	
	# ATUALIZAR SEMÁFOROS VISUAIS DO SISTEMA ANTERIOR
	atualizar_semaforos_visuais(semaforo_verde)
	
	if semaforo_verde:
		print("🟢 Semáforo VERDE - processando fila")
		processar_fila_carros()
		# Próxima mudança para vermelho
		gerenciador_eventos.agendar_evento(
			gerenciador_eventos.tempo_simulacao + configuracao.tempo_semaforo_verde, 
			GerenciadorEventos.TipoEvento.MUDANCA_SEMAFORO
		)
	else:
		print("🔴 Semáforo VERMELHO - carros param")
		# Próxima mudança para verde
		gerenciador_eventos.agendar_evento(
			gerenciador_eventos.tempo_simulacao + configuracao.tempo_semaforo_vermelho, 
			GerenciadorEventos.TipoEvento.MUDANCA_SEMAFORO
		)

func processar_fila_carros():
	# Processar todos os carros na fila enquanto semáforo está verde
	while not fila_carros.is_empty() and semaforo_verde:
		var carro = fila_carros.pop_front()
		
		# Calcular tempo de espera
		var tempo_espera = gerenciador_eventos.tempo_simulacao - carro.tempo_espera_inicio
		estatisticas.tempo_espera_total += tempo_espera
		
		# Agendar saída do carro
		var tempo_saida = gerenciador_eventos.tempo_simulacao + DistribuicoesEstatisticas.tempo_processamento_semaforo()
		gerenciador_eventos.agendar_evento(tempo_saida, GerenciadorEventos.TipoEvento.SAIDA_CARRO, carro)
		
		estatisticas.carros_na_fila = fila_carros.size()
		print("⏩ Carro %d saindo da fila (esperou %.2fs)" % [carro.id, tempo_espera])

func processar_carro_no_semaforo(_evento: GerenciadorEventos.Evento):
	# Já processado em processar_fila_carros
	pass

func processar_saida_carro(evento: GerenciadorEventos.Evento):
	estatisticas.carros_atendidos += 1
	print("🏁 Carro %d saiu do sistema" % evento.dados.id)

func processar_atualizacao_estatisticas(_evento: GerenciadorEventos.Evento):
	# Atualizar estatísticas
	if estatisticas.carros_atendidos > 0:
		estatisticas.tempo_espera_medio = estatisticas.tempo_espera_total / float(estatisticas.carros_atendidos)
	
	print("📊 === ESTATÍSTICAS (Tempo: %.1f) ===" % gerenciador_eventos.tempo_simulacao)
	print("   Carros chegados: %d" % estatisticas.carros_chegados)
	print("   Carros atendidos: %d" % estatisticas.carros_atendidos)
	print("   Tempo espera médio: %.2f segundos" % estatisticas.tempo_espera_medio)
	print("   Tamanho fila atual: %d" % estatisticas.carros_na_fila)
	print("   Tamanho fila máximo: %d" % estatisticas.tamanho_fila_max)
	
	# Agendar próxima atualização
	gerenciador_eventos.agendar_evento(
		gerenciador_eventos.tempo_simulacao + 60.0, 
		GerenciadorEventos.TipoEvento.ATUALIZAR_ESTATISTICAS
	)

func _on_tempo_atualizado(_tempo: float):
	# Atualizar UI com tempo atual
	pass

func _on_fila_atualizada(_fila: Array):
	# Atualizar UI com fila de eventos
	pass

# Controles públicos da simulação
func alterar_taxa_chegada(nova_taxa: float):
	configuracao.taxa_chegada = nova_taxa
	print("⚙️ Taxa de chegada alterada para: %.2f carros/min" % nova_taxa)

func alterar_tempo_semaforo(verde: float, vermelho: float):
	configuracao.tempo_semaforo_verde = verde
	configuracao.tempo_semaforo_vermelho = vermelho
	print("⚙️ Tempos do semáforo: Verde=%.1fs, Vermelho=%.1fs" % [verde, vermelho])

func alterar_velocidade_simulacao(velocidade: float):
	gerenciador_eventos.velocidade_simulacao = velocidade
	print("⚙️ Velocidade da simulação: %.1fx" % velocidade)

# INTEGRAÇÃO COM SISTEMA ANTERIOR
func atualizar_semaforos_visuais(verde: bool):
	"""Atualiza semáforos visuais do sistema anterior"""
	var traffic_manager = get_tree().get_first_node_in_group("traffic_manager")
	if traffic_manager and traffic_manager.has_method("set_all_lights_state"):
		# Ativar controle por eventos discretos
		traffic_manager.discrete_event_control = true
		traffic_manager.set_all_lights_state(verde)
		print("🚦 Eventos discretos controlando semáforos: %s" % ("VERDE" if verde else "VERMELHO"))
	else:
		# Buscar semáforos diretamente na árvore
		var lights = get_tree().get_nodes_in_group("traffic_lights")
		for light in lights:
			if light.has_method("set_state"):
				light.set_state("green" if verde else "red")
