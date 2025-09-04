# Gerenciador de Eventos Discretos
extends Node
class_name GerenciadorEventos

# Fila de eventos ordenada por tempo
var fila_eventos: Array = []
var tempo_simulacao: float = 0.0
var velocidade_simulacao: float = 1.0
var simulacao_pausada: bool = false

# Tipos de eventos em português
enum TipoEvento {
	CHEGADA_CARRO,
	CARRO_NO_SEMAFORO,
	MUDANCA_SEMAFORO,
	SAIDA_CARRO,
	ATUALIZAR_ESTATISTICAS
}

# Estrutura de um evento
class Evento:
	var tempo: float
	var tipo: TipoEvento
	var dados: Dictionary
	
	func _init(t: float, tp: TipoEvento, d: Dictionary = {}):
		tempo = t
		tipo = tp
		dados = d

# Sinais para UI
signal evento_processado(evento: Evento)
signal tempo_simulacao_atualizado(tempo: float)
signal fila_eventos_atualizada(fila: Array)

func _ready():
	print("🎯 Gerenciador de Eventos Discretos iniciado")

# Adicionar evento à fila (mantendo ordem cronológica)
func agendar_evento(tempo_futuro: float, tipo: TipoEvento, dados: Dictionary = {}):
	var novo_evento = Evento.new(tempo_futuro, tipo, dados)
	
	# Inserir na posição correta (ordenado por tempo)
	var inserido = false
	for i in range(fila_eventos.size()):
		if fila_eventos[i].tempo > tempo_futuro:
			fila_eventos.insert(i, novo_evento)
			inserido = true
			break
	
	if not inserido:
		fila_eventos.append(novo_evento)
	
	# Notificar UI que fila mudou
	fila_eventos_atualizada.emit(fila_eventos)
	
	print("📅 Evento agendado: %s para tempo %.2f" % [nome_tipo_evento(tipo), tempo_futuro])

# Processar próximo evento da fila
func processar_proximo_evento():
	if fila_eventos.is_empty():
		print("⏹️ Não há mais eventos na fila")
		return false
	
	var evento = fila_eventos.pop_front()
	
	# PULAR NO TEMPO para o evento (característica de eventos discretos)
	tempo_simulacao = evento.tempo
	tempo_simulacao_atualizado.emit(tempo_simulacao)
	
	print("⏰ Tempo: %.2f - Processando: %s" % [tempo_simulacao, nome_tipo_evento(evento.tipo)])
	
	# Processar o evento específico
	match evento.tipo:
		TipoEvento.CHEGADA_CARRO:
			processar_chegada_carro(evento.dados)
		TipoEvento.CARRO_NO_SEMAFORO:
			processar_carro_semaforo(evento.dados)
		TipoEvento.MUDANCA_SEMAFORO:
			processar_mudanca_semaforo(evento.dados)
		TipoEvento.SAIDA_CARRO:
			processar_saida_carro(evento.dados)
		TipoEvento.ATUALIZAR_ESTATISTICAS:
			processar_estatisticas(evento.dados)
	
	# Notificar que evento foi processado
	evento_processado.emit(evento)
	fila_eventos_atualizada.emit(fila_eventos)
	
	return true

# Executar simulação automaticamente
func executar_simulacao():
	if simulacao_pausada:
		return
		
	if processar_proximo_evento():
		# Aguardar um pouco antes do próximo evento (para visualização)
		await get_tree().create_timer(1.0 / velocidade_simulacao).timeout
		call_deferred("executar_simulacao")
	else:
		print("🏁 Simulação finalizada!")

# Pausar/despausar simulação
func pausar_simulacao():
	simulacao_pausada = true

func continuar_simulacao():
	simulacao_pausada = false
	executar_simulacao()

func retomar_simulacao():
	continuar_simulacao()

# Funções específicas para cada tipo de evento
func processar_chegada_carro(dados: Dictionary):
	print("🚗 Novo carro chegando na via")
	# Criar próximo carro com distribuição estatística
	var proximo_tempo = tempo_simulacao + gerar_tempo_chegada()
	agendar_evento(proximo_tempo, TipoEvento.CHEGADA_CARRO)

func processar_carro_semaforo(dados: Dictionary):
	print("🚦 Carro chegou no semáforo")

func processar_mudanca_semaforo(dados: Dictionary):
	print("🔄 Semáforo mudou de estado")

func processar_saida_carro(dados: Dictionary):
	print("🏃 Carro saiu do sistema")

func processar_estatisticas(dados: Dictionary):
	print("📊 Atualizando estatísticas")

# Gerar tempo entre chegadas (distribuição exponencial simples)
func gerar_tempo_chegada() -> float:
	var lambda = 2.0  # carros por minuto
	return -log(randf()) / lambda

# Converter tipo de evento para string legível
func nome_tipo_evento(tipo: TipoEvento) -> String:
	match tipo:
		TipoEvento.CHEGADA_CARRO:
			return "Chegada de Carro"
		TipoEvento.CARRO_NO_SEMAFORO:
			return "Carro no Semáforo"
		TipoEvento.MUDANCA_SEMAFORO:
			return "Mudança do Semáforo"
		TipoEvento.SAIDA_CARRO:
			return "Saída de Carro"
		TipoEvento.ATUALIZAR_ESTATISTICAS:
			return "Atualizar Estatísticas"
		_:
			return "Evento Desconhecido"

# Obter próximos N eventos (para UI)
func obter_proximos_eventos(quantidade: int = 5) -> Array:
	var proximos = []
	for i in range(min(quantidade, fila_eventos.size())):
		proximos.append(fila_eventos[i])
	return proximos