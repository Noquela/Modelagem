# CONFIGURAÇÕES EXATAS - BASEADAS NAS ESPECIFICAÇÕES DESENVOLVIDAS E TESTADAS

# Dimensões da janela
WINDOW_WIDTH = 1200
WINDOW_HEIGHT = 800

# Ruas - Dimensões exatas
MAIN_ROAD_WIDTH = 120  # Rua principal mais larga (2 faixas por direção)
CROSS_ROAD_WIDTH = 80  # Rua que corta (1 faixa)
LANE_WIDTH = 30        # Largura de cada faixa individual

# Posições dos semáforos (baseado no sistema desenvolvido)
SEMAFORO_1 = (450, 320)   # Rua principal - controla esquerda→direita
SEMAFORO_2 = (750, 480)   # Rua principal - controla direita→esquerda  
SEMAFORO_3 = (540, 520)   # Rua que corta - controla baixo→cima (posicionado mais embaixo)

# Cores
COLORS = {
    'grass': (34, 139, 34),
    'asphalt': (64, 64, 64),
    'yellow_line': (255, 255, 0),
    'white': (255, 255, 255),
    'red': (255, 0, 0),
    'green': (0, 255, 0),
    'yellow': (255, 255, 0),
    'blue': (0, 0, 255),
    'dark_red': (100, 0, 0),
    'dark_green': (0, 100, 0),
    'dark_yellow': (100, 100, 0),
    'pole': (80, 80, 80)
}

# Configurações dos carros - VALORES EXATOS
CAR_CONFIG = {
    'width': 25,
    'height': 15,
    'max_speed': 2.0,
    'acceleration': 0.05,
    'deceleration': 0.08,
    'min_following_distance': 120,
    'minimum_stop_distance': 200
}

# Personalidades dos motoristas - EXATO COMO DESENVOLVEMOS
DRIVER_PERSONALITIES = {
    'AGGRESSIVE': {
        'reaction_time': (0.5, 0.8),
        'following_distance_factor': 0.8,
        'aggression_level': 0.8,
        'speed_factor': 1.1
    },
    'CONSERVATIVE': {
        'reaction_time': (1.2, 1.5),
        'following_distance_factor': 1.4,
        'aggression_level': 0.2,
        'speed_factor': 0.9
    },
    'NORMAL': {
        'reaction_time': (0.8, 1.2),
        'following_distance_factor': 1.0,
        'aggression_level': 0.5,
        'speed_factor': 1.0
    },
    'ELDERLY': {
        'reaction_time': (1.5, 2.0),
        'following_distance_factor': 1.3,
        'aggression_level': 0.1,
        'speed_factor': 0.8
    }
}

# Sistema de spawn - CONFIGURAÇÕES EXATAS
SPAWN_CONFIG = {
    'base_spawn_rate': 0.025,
    'randomness_factor': 0.5,
    'min_spawn_distance': 120,
    'cross_road_multiplier': 0.8  # Rua que corta tem 80% da chance
}

# Tempos dos semáforos - SISTEMA EXATO DE 37 SEGUNDOS
TRAFFIC_LIGHT_TIMING = {
    'green_time': 15,      # 15 segundos
    'yellow_time': 3,      # 3 segundos
    'safety_time': 1,      # 1 segundo todos vermelhos
    'total_cycle': 37      # 37 segundos total
}

# Cores realísticas dos carros
CAR_COLORS = [
    (40, 40, 40),      # Preto
    (255, 255, 255),   # Branco
    (180, 180, 180),   # Prata
    (60, 60, 120),     # Azul escuro
    (120, 60, 60),     # Vermelho escuro
    (60, 120, 60),     # Verde escuro
    (80, 80, 80),      # Cinza escuro
]