# CONFIGURAÇÕES EXATAS - BASEADAS NAS ESPECIFICAÇÕES DESENVOLVIDAS E TESTADAS

# Dimensões da janela - Suporte Ultrawide 21:9
WINDOW_WIDTH = 3440
WINDOW_HEIGHT = 1440

# Ruas - Dimensões exatas
MAIN_ROAD_WIDTH = 120  # Rua principal mais larga (2 faixas por direção)
CROSS_ROAD_WIDTH = 80  # Rua que corta (1 faixa)
LANE_WIDTH = 30        # Largura de cada faixa individual

# Sistema avançado de semáforos com hastes direcionais (Ultrawide)
TRAFFIC_LIGHTS = {
    'semaforo_1': {
        'pos': (1580, 600),  # Controla esquerda→direita (centralizado)
        'direction': 'horizontal_left',
        'controls': 'LEFT_TO_RIGHT',
        'state': 'red'
    },
    'semaforo_2': {
        'pos': (1860, 740),  # Controla direita→esquerda (centralizado) 
        'direction': 'horizontal_right', 
        'controls': 'RIGHT_TO_LEFT',
        'state': 'red'
    },
    'semaforo_3': {
        'pos': (1680, 600),  # Controla cima→baixo (centralizado)
        'direction': 'vertical_up',
        'controls': 'TOP_TO_BOTTOM',
        'state': 'red'
    }
}

# Posições legadas (manter compatibilidade)
SEMAFORO_1 = TRAFFIC_LIGHTS['semaforo_1']['pos']
SEMAFORO_2 = TRAFFIC_LIGHTS['semaforo_2']['pos']
SEMAFORO_3 = TRAFFIC_LIGHTS['semaforo_3']['pos']

# Sistema de cores premium - PALETA EXPANDIDA PARA VISUAL PROFISSIONAL
COLORS = {
    # === AMBIENTE ===
    'grass': (34, 139, 34),
    'grass_dark': (20, 100, 20),
    'grass_light': (45, 155, 45),
    'asphalt': (45, 45, 45),
    'asphalt_worn': (55, 55, 55),
    'concrete': (120, 120, 120),
    'dirt': (101, 67, 33),
    'sky': (135, 206, 235),
    
    # === MARCAÇÕES VIÁRIAS PREMIUM ===
    'yellow_line': (255, 215, 0),
    'white_line': (240, 240, 240),
    'crosswalk': (250, 250, 250),
    'crosswalk_worn': (220, 220, 220),
    'lane_divider': (255, 255, 255, 180),
    
    # === SEMÁFOROS COM BRILHO ===
    'red': (220, 0, 0),
    'red_glow': (255, 100, 100, 80),
    'red_dark': (80, 0, 0),
    'green': (0, 180, 0),
    'green_glow': (100, 255, 100, 80),
    'green_dark': (0, 80, 0),
    'yellow': (255, 200, 0),
    'yellow_glow': (255, 255, 100, 80),
    'yellow_dark': (100, 80, 0),
    'pole': (80, 80, 80),
    'pole_highlight': (120, 120, 120),
    
    # === CARROS PREMIUM ===
    'car_black': (15, 15, 15),
    'car_white': (245, 245, 245),
    'car_silver': (170, 170, 170),
    'car_blue': (30, 60, 120),
    'car_red': (140, 20, 20),
    'car_green': (20, 80, 20),
    'car_gold': (180, 140, 60),
    'car_purple': (80, 20, 80),
    'car_orange': (200, 100, 20),
    'car_navy': (20, 40, 80),
    
    # === DETALHES DOS CARROS ===
    'wheel_tire': (25, 25, 25),
    'wheel_rim': (120, 120, 120),
    'wheel_chrome': (180, 180, 180),
    'headlight': (255, 255, 200),
    'taillight': (200, 0, 0),
    'brake_light': (255, 0, 0, 180),
    'window_tint': (20, 25, 35),
    'window_reflection': (100, 120, 140, 80),
    
    # === EFEITOS VISUAIS ===
    'shadow': (0, 0, 0, 60),
    'shadow_light': (0, 0, 0, 30),
    'glow': (255, 255, 255, 40),
    'reflection': (255, 255, 255, 20),
    'dust_particle': (180, 160, 140, 60),
    'smoke': (100, 100, 100, 40),
    
    # === ELEMENTOS URBANOS ===
    'manhole_cover': (80, 80, 80),
    'manhole_rim': (100, 100, 100),
    'manhole_dark': (60, 60, 60),
    'tree_trunk': (101, 67, 33),
    'tree_leaves': (0, 120, 0),
    'tree_leaves_dark': (0, 100, 0),
    'tree_leaves_light': (0, 140, 0),
    
    # === INTERFACE ===
    'ui_background': (0, 0, 0, 160),
    'ui_border': (100, 150, 200, 120),
    'ui_text': (255, 255, 255),
    'ui_text_dim': (200, 200, 200),
    'ui_accent': (100, 200, 255),
    
    # === COMPATIBILIDADE ===
    'white': (255, 255, 255),
    'blue': (0, 0, 255),
    'dark_red': (100, 0, 0),
    'dark_green': (0, 100, 0),
    'dark_yellow': (100, 100, 0)
}

# Configurações dos carros - VALORES AJUSTADOS PARA 2D COMO HTML
CAR_CONFIG = {
    'width': 25,
    'height': 15,
    'max_speed': 2.0,               # REDUZIDO de 2.2 para 2.0 - mais controlado
    'acceleration': 0.035,          # REDUZIDO de 0.04 para 0.035 - mais suave  
    'deceleration': 0.055,          # REDUZIDO de 0.06 para 0.055 - mais gradual
    'min_following_distance': 28,  # REDUZIDO de 32 para 28 - CORRIGIDO
    'minimum_stop_distance': 45,   # Mantido
    'queue_distance': 18,           # REDUZIDO de 22 para 18 - CORRIGIDO
    'smooth_factor': 0.90           # AUMENTADO de 0.85 para 0.90 - mais suave
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

# Sistema de spawn - CONFIGURAÇÕES AJUSTADAS PARA 2D COMO HTML
SPAWN_CONFIG = {
    'base_spawn_rate': 0.055,      # AUMENTADO de 0.045 para 0.055 - CORRIGIDO
    'randomness_factor': 0.7,      # Mantido
    'min_spawn_distance': 20,      # REDUZIDO de 25 para 20 - CORRIGIDO
    'cross_road_multiplier': 0.75, # Mantido
    'rush_hour_multiplier': 1.6,   # REDUZIDO de 1.8 para 1.6 - mais controlado
    'queue_spawn_distance': 15     # REDUZIDO de 20 para 15 - CORRIGIDO
}

# Tempos dos semáforos - SISTEMA EXATO DE 37 SEGUNDOS
TRAFFIC_LIGHT_TIMING = {
    'green_time': 15,      # 15 segundos
    'yellow_time': 3,      # 3 segundos
    'safety_time': 1,      # 1 segundo todos vermelhos
    'total_cycle': 37      # 37 segundos total
}

# Cores premium dos carros - PALETA PROFISSIONAL
CAR_COLORS = [
    COLORS['car_black'],    # Preto premium
    COLORS['car_white'],    # Branco pérola
    COLORS['car_silver'],   # Prata metálico
    COLORS['car_blue'],     # Azul marinho
    COLORS['car_red'],      # Vermelho escuro
    COLORS['car_green'],    # Verde militar
    COLORS['car_gold'],     # Dourado
    COLORS['car_purple'],   # Roxo escuro
    COLORS['car_orange'],   # Laranja queimado
    COLORS['car_navy']      # Azul naval
]