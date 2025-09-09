class_name EventTypes

# Tipos de eventos discretos - EXATAMENTE como no MASTER_PLAN.md

enum Type {
	# Semáforos (6 tipos - ciclo completo 40s)
	SEMAFORO_MAIN_VERDE,           # t=0, 40, 80...  → Sem. 1,2 VERDE
	SEMAFORO_MAIN_AMARELO,         # t=20, 60, 100.. → Sem. 1,2 AMARELO  
	SEMAFORO_TODOS_VERMELHO_1,     # t=23, 63, 103.. → TODOS VERMELHO
	SEMAFORO_CROSS_VERDE,          # t=24, 64, 104.. → Sem. 3 VERDE
	SEMAFORO_CROSS_AMARELO,        # t=34, 74, 114.. → Sem. 3 AMARELO
	SEMAFORO_TODOS_VERMELHO_2,     # t=37, 77, 117.. → TODOS VERMELHO
	
	# Veículos - Spawn/Despawn (4 tipos)
	SPAWN_CARRO_WEST,              # Criar carro West→East
	SPAWN_CARRO_EAST,              # Criar carro East→West  
	SPAWN_CARRO_NORTH,             # Criar carro North→South
	CARRO_SAIU,                    # Carro saiu do sistema
	
	# Veículos - Movimento (6 tipos)
	CARRO_MOVE_PARA_INTERSECAO,    # Carro se move para interseção
	CARRO_PARA_NO_SEMAFORO,        # Carro para no semáforo vermelho
	CARRO_ATRAVESSA_INTERSECAO,    # Carro atravessa interseção
	CARRO_RETOMA_MOVIMENTO,        # Carro volta a se mover (semáforo verde)
	CARRO_CHEGA_FILA,              # Carro chega atrás de outro carro
	CARRO_AVANCA_FILA,             # Carro avança na fila
	
	# Sistema (1 tipo)
	UPDATE_STATS                   # Atualizar estatísticas UI
}

# Nomes para UI - EXATOS do plano
static func get_event_name(type: Type) -> String:
	match type:
		# Semáforos
		Type.SEMAFORO_MAIN_VERDE:
			return "🟢 Semáforos 1,2 → Verde"
		Type.SEMAFORO_MAIN_AMARELO:
			return "🟡 Semáforos 1,2 → Amarelo"
		Type.SEMAFORO_TODOS_VERMELHO_1:
			return "🔴 Todos → Vermelho"
		Type.SEMAFORO_CROSS_VERDE:
			return "🟢 Semáforo 3 → Verde"
		Type.SEMAFORO_CROSS_AMARELO:
			return "🟡 Semáforo 3 → Amarelo"
		Type.SEMAFORO_TODOS_VERMELHO_2:
			return "🔴 Todos → Vermelho"
			
		# Veículos - Spawn/Despawn
		Type.SPAWN_CARRO_WEST:
			return "🚗 Spawn → West"
		Type.SPAWN_CARRO_EAST:
			return "🚗 Spawn → East"
		Type.SPAWN_CARRO_NORTH:
			return "🚗 Spawn → North"
		Type.CARRO_SAIU:
			return "🏁 Carro → Saiu"
			
		# Veículos - Movimento
		Type.CARRO_MOVE_PARA_INTERSECAO:
			return "🚗➡️ Move → Interseção"
		Type.CARRO_PARA_NO_SEMAFORO:
			return "🚗🛑 Para → Semáforo"
		Type.CARRO_ATRAVESSA_INTERSECAO:
			return "🚗⚡ Atravessa → Interseção"
		Type.CARRO_RETOMA_MOVIMENTO:
			return "🚗▶️ Retoma → Movimento"
		Type.CARRO_CHEGA_FILA:
			return "🚗📍 Chega → Fila"
		Type.CARRO_AVANCA_FILA:
			return "🚗⬆️ Avança → Fila"
			
		# Sistema
		Type.UPDATE_STATS:
			return "📊 Update Stats"
		_:
			return "❓ Desconhecido"

# Cores para UI
static func get_event_color(type: Type) -> Color:
	match type:
		# Semáforos verdes
		Type.SEMAFORO_MAIN_VERDE, Type.SEMAFORO_CROSS_VERDE:
			return Color.LIME_GREEN
		# Semáforos amarelos
		Type.SEMAFORO_MAIN_AMARELO, Type.SEMAFORO_CROSS_AMARELO:
			return Color.YELLOW
		# Semáforos vermelhos
		Type.SEMAFORO_TODOS_VERMELHO_1, Type.SEMAFORO_TODOS_VERMELHO_2:
			return Color.ORANGE_RED
		# Veículos - Spawn/Despawn
		Type.SPAWN_CARRO_WEST, Type.SPAWN_CARRO_EAST, Type.SPAWN_CARRO_NORTH:
			return Color.CYAN
		Type.CARRO_SAIU:
			return Color.LIGHT_BLUE
			
		# Veículos - Movimento
		Type.CARRO_MOVE_PARA_INTERSECAO, Type.CARRO_ATRAVESSA_INTERSECAO:
			return Color.DODGER_BLUE
		Type.CARRO_PARA_NO_SEMAFORO:
			return Color.ORANGE_RED
		Type.CARRO_RETOMA_MOVIMENTO:
			return Color.LIME_GREEN
		Type.CARRO_CHEGA_FILA, Type.CARRO_AVANCA_FILA:
			return Color.PURPLE
		# Sistema
		Type.UPDATE_STATS:
			return Color.LIGHT_PINK
		_:
			return Color.WHITE