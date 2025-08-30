"""
Configurações globais do simulador de tráfego 3D
Baseado nas especificações e valores testados no protótipo HTML
"""
import numpy as np

# =================== CONFIGURAÇÕES DOS CARROS ===================
CAR_CONFIG = {
    'base_speed': 0.02,
    'min_distance': 4.0,
    'intersection_stop_line': 6.0,
    'minimum_safe_stop_distance': 8.0,
    'acceleration': 0.001,
    'deceleration': 0.002,
    'spawn_distance_check': 12.0,
    'visibility_range': 15.0,
    
    # Variações físicas
    'speed_variation_range': (0.8, 1.2),  # ±20% velocidade base
    'length': 4.0,
    'width': 1.8,
    'height': 1.2,
}

# =================== SPAWN SYSTEM ===================
SPAWN_CONFIG = {
    'base_rate': 0.025,
    'randomness_factor': 0.5,  # 0.5x a 1.5x da taxa base
    'main_road_multiplier': 1.0,
    'cross_road_multiplier': 0.8,
    'rush_hour_multiplier': 1.5,
    'min_spawn_distance': 4.0,
}

# =================== SEMÁFOROS ===================
LIGHT_TIMING = {
    'green_time': 15000,  # ms
    'yellow_time': 3000,
    'safety_time': 1000,  # todos vermelhos
    'total_cycle': 37000,
}

# Estados dos semáforos
LIGHT_STATE = {
    'RED': 0,
    'YELLOW': 1,
    'GREEN': 2
}

# =================== GEOMETRIA DA CENA ===================
SCENE_CONFIG = {
    'world_size': 50.0,
    'main_road_width': 10.0,
    'cross_road_width': 6.0,
    'lane_width': 2.5,
    'intersection_size': 8.0,
    'grass_color': (0.133, 0.545, 0.133),  # Forest Green
    'road_color': (0.2, 0.2, 0.2),  # Dark Gray
    'line_color': (1.0, 1.0, 0.0),  # Yellow
}

# =================== TIPOS DE MOTORISTA ===================
DRIVER_PERSONALITIES = {
    'AGGRESSIVE': {
        'reaction_time': (0.5, 0.8),
        'following_distance_factor': 0.8,
        'aggression_level': 0.9,
        'yellow_light_probability': 0.8,  # 80% chance de acelerar no amarelo
        'speed_factor': 1.1,
    },
    'CONSERVATIVE': {
        'reaction_time': (1.2, 2.0),
        'following_distance_factor': 1.4,
        'aggression_level': 0.2,
        'yellow_light_probability': 0.1,  # 10% chance de acelerar no amarelo
        'speed_factor': 0.9,
    },
    'NORMAL': {
        'reaction_time': (0.8, 1.2),
        'following_distance_factor': 1.0,
        'aggression_level': 0.5,
        'yellow_light_probability': 0.4,  # 40% chance de acelerar no amarelo
        'speed_factor': 1.0,
    },
    'ELDERLY': {
        'reaction_time': (1.5, 2.5),
        'following_distance_factor': 1.5,
        'aggression_level': 0.1,
        'yellow_light_probability': 0.05,  # 5% chance de acelerar no amarelo
        'speed_factor': 0.8,
    }
}

# =================== DIREÇÕES ===================
CAR_DIRECTIONS = {
    'LEFT_TO_RIGHT': 0,
    'RIGHT_TO_LEFT': 1,
    'TOP_TO_BOTTOM': 2,
}

# =================== ESTADOS DOS CARROS ===================
CAR_STATES = {
    'DRIVING': "driving",
    'STOPPING': "stopping", 
    'WAITING': "waiting",
    'ACCELERATING': "accelerating",
}

# =================== CORES DOS CARROS ===================
REALISTIC_CAR_COLORS = [
    (0.8, 0.0, 0.0),    # Vermelho
    (0.0, 0.0, 0.8),    # Azul
    (0.1, 0.1, 0.1),    # Preto
    (0.9, 0.9, 0.9),    # Branco
    (0.5, 0.5, 0.5),    # Cinza
    (0.6, 0.3, 0.0),    # Marrom
    (0.0, 0.5, 0.0),    # Verde escuro
    (0.4, 0.0, 0.4),    # Roxo
    (0.0, 0.3, 0.5),    # Azul marinho
    (0.7, 0.7, 0.0),    # Dourado
]

# =================== RENDERIZAÇÃO ===================
RENDER_CONFIG = {
    'target_fps': 60,
    'window_width': 3440,    # Ultrawide support
    'window_height': 1440,   # Ultrawide support
    'fov': 45.0,
    'near_plane': 0.1,
    'far_plane': 1000.0,
    'msaa_samples': 4,
    
    # LOD (Level of Detail)
    'high_detail_distance': 20.0,
    'medium_detail_distance': 40.0,
    'low_detail_distance': 60.0,
    
    # Instanced rendering
    'max_cars_per_batch': 100,
    'enable_frustum_culling': True,
}

# =================== CÂMERA ===================
CAMERA_CONFIG = {
    'default_position': (0.0, 35.0, 15.0),
    'default_target': (0.0, 0.0, 0.0),
    'movement_speed': 0.1,
    'rotation_speed': 0.01,
    'zoom_speed': 1.0,
    'min_distance': 10.0,
    'max_distance': 80.0,
    'min_elevation': 0.1,
    'max_elevation': 1.5,
}

# =================== UI/ESTATÍSTICAS ===================
UI_CONFIG = {
    'stats_update_interval': 100,  # ms
    'show_debug_info': True,
    'show_car_paths': False,
    'show_collision_boxes': False,
    'overlay_alpha': 0.8,
    'font_size': 12,
    'stats_position': (10, 10),
}

# =================== FÍSICA ===================
PHYSICS_CONFIG = {
    'gravity': -9.81,
    'friction': 0.8,
    'collision_margin': 0.1,
    'max_simulation_step': 1.0/60.0,
    'solver_iterations': 10,
}