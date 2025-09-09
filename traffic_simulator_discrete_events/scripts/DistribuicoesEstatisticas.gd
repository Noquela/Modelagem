# Distribuições Estatísticas para Simulação
extends RefCounted
class_name DistribuicoesEstatisticas

# Distribuição Exponencial (para tempos entre chegadas)
static func exponencial(taxa: float) -> float:
	return -log(randf()) / taxa

# Distribuição Poisson (para número de chegadas em intervalo)
static func poisson(lambda: float) -> int:
	var l = exp(-lambda)
	var k = 0
	var p = 1.0
	
	while p > l:
		k += 1
		p *= randf()
	
	return k - 1

# Distribuição Normal/Gaussiana (para tempos de serviço)
static func normal(media: float, desvio_padrao: float) -> float:
	# Método Box-Muller
	var u1 = randf()
	var u2 = randf()
	
	var z0 = sqrt(-2.0 * log(u1)) * cos(2.0 * PI * u2)
	return media + desvio_padrao * z0

# Distribuição Uniforme
static func uniforme(minimo: float, maximo: float) -> float:
	return randf_range(minimo, maximo)

# Distribuição Geométrica (para número de tentativas até sucesso)
static func geometrica(probabilidade: float) -> int:
	return int(ceil(log(randf()) / log(1.0 - probabilidade)))

# Distribuições específicas para tráfego

# Tempo entre chegadas de carros (típico: λ=2 carros/min)
static func tempo_chegada_carros(carros_por_minuto: float = 2.0) -> float:
	return exponencial(carros_por_minuto)

# Tempo de processamento no semáforo (Normal: μ=3s, σ=1s)
static func tempo_processamento_semaforo(tempo_medio: float = 3.0, variabilidade: float = 1.0) -> float:
	var tempo = normal(tempo_medio, variabilidade)
	return max(tempo, 0.5)  # Mínimo de 0.5s

# Duração do ciclo do semáforo (Uniforme: 20-40s)
static func duracao_ciclo_semaforo(minimo: float = 20.0, maximo: float = 40.0) -> float:
	return uniforme(minimo, maximo)

# Número de carros em rush hour (Poisson com λ maior)
static func carros_rush_hour(lambda: float = 5.0) -> int:
	return poisson(lambda)

# Tempo de espera na fila (Exponencial modificada)
static func tempo_espera_fila(media_espera: float = 10.0) -> float:
	return exponencial(1.0 / media_espera)