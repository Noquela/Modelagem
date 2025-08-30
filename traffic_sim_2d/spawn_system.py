import random
import time
import math
from car import Car, Direction
from config import *

class SpawnSystem:
    def __init__(self):
        # Configurações EXATAS que desenvolvemos
        self.base_spawn_rate = SPAWN_CONFIG['base_spawn_rate']
        self.randomness_factor = SPAWN_CONFIG['randomness_factor']
        self.min_distance = SPAWN_CONFIG['min_spawn_distance']
        self.cross_road_multiplier = SPAWN_CONFIG['cross_road_multiplier']
        
        # Estatísticas
        self.cars_spawned = 0
        self.spawn_attempts = 0
        
        # Para controle de timing
        self.last_spawn_time = {
            Direction.LEFT_TO_RIGHT: 0,
            Direction.RIGHT_TO_LEFT: 0,
            Direction.TOP_TO_BOTTOM: 0
        }
    
    def update(self, cars):
        """Sistema de spawn EXATO baseado no que desenvolvemos"""
        new_cars = []
        current_time = time.time()
        
        # Fator aleatório para variar spawn rate
        random_factor = 0.5 + random.random() * self.randomness_factor  # 0.5 a 1.0
        
        # Spawn rua principal (esquerda→direita)
        if self._should_spawn(Direction.LEFT_TO_RIGHT, current_time, random_factor):
            lane = self._choose_best_lane(Direction.LEFT_TO_RIGHT, cars)
            if lane != -1 and self._can_spawn_safely(Direction.LEFT_TO_RIGHT, lane, cars):
                new_car = Car(Direction.LEFT_TO_RIGHT, lane)
                new_cars.append(new_car)
                self.cars_spawned += 1
                self.last_spawn_time[Direction.LEFT_TO_RIGHT] = current_time
        
        # Spawn rua principal (direita→esquerda)
        if self._should_spawn(Direction.RIGHT_TO_LEFT, current_time, random_factor):
            lane = self._choose_best_lane(Direction.RIGHT_TO_LEFT, cars)
            if lane != -1 and self._can_spawn_safely(Direction.RIGHT_TO_LEFT, lane, cars):
                new_car = Car(Direction.RIGHT_TO_LEFT, lane)
                new_cars.append(new_car)
                self.cars_spawned += 1
                self.last_spawn_time[Direction.RIGHT_TO_LEFT] = current_time
        
        # Spawn rua que corta (cima→baixo) - 80% da chance das outras
        if self._should_spawn(Direction.TOP_TO_BOTTOM, current_time, 
                             random_factor * self.cross_road_multiplier):
            if self._can_spawn_safely(Direction.TOP_TO_BOTTOM, 0, cars):
                new_car = Car(Direction.TOP_TO_BOTTOM, 0)
                new_cars.append(new_car)
                self.cars_spawned += 1
                self.last_spawn_time[Direction.TOP_TO_BOTTOM] = current_time
        
        self.spawn_attempts += 1
        return new_cars
    
    def _should_spawn(self, direction, current_time, rate_factor):
        """Sistema inteligente de spawn com rush hour realístico"""
        # === TIMING ADAPTATIVO ===
        # Intervalo entre spawns baseado na densidade atual
        min_spawn_interval = 0.5  # Mais rápido para formar filas
        
        if current_time - self.last_spawn_time[direction] < min_spawn_interval:
            return False
        
        # === SIMULAÇÃO DE RUSH HOUR ===
        # Criar picos de tráfego baseados no tempo decorrido
        elapsed_minutes = (current_time % 600) / 10  # Ciclo de 10 minutos = 1 hora simulada
        
        # Picos de tráfego: início (0-2), meio (4-6), fim (8-10) do ciclo
        rush_factor = 1.0
        if elapsed_minutes < 2 or (4 < elapsed_minutes < 6) or elapsed_minutes > 8:
            rush_factor = SPAWN_CONFIG['rush_hour_multiplier']  # 1.8x mais tráfego
        
        # === TAXA ADAPTATIVA BASEADA EM DENSIDADE ===
        enhanced_rate = self.base_spawn_rate * rate_factor * rush_factor
        
        # === VARIAÇÃO ORGÂNICA ===
        # Variação suave e natural (não senoidal artificial)
        organic_variation = 0.8 + (random.random() * 0.4)  # Variação de 80% a 120%
        
        final_spawn_chance = enhanced_rate * organic_variation
        return random.random() < min(final_spawn_chance, 0.20)  # Limite aumentado para 20%
    
    def _choose_best_lane(self, direction, cars):
        """Escolher faixa menos congestionada (NOSSA LÓGICA)"""
        max_lanes = 2 if direction != Direction.TOP_TO_BOTTOM else 1
        
        # Encontrar faixa com mais espaço
        best_lane = -1
        max_distance = 0
        
        for lane in range(max_lanes):
            distance = self._get_distance_to_nearest_car(direction, lane, cars)
            if distance >= self.min_distance and distance > max_distance:
                max_distance = distance
                best_lane = lane
        
        # Se nenhuma tem espaço ideal, escolher menos ocupada
        if best_lane == -1:
            lane_counts = [self._count_cars_in_lane(direction, lane, cars) for lane in range(max_lanes)]
            if lane_counts:
                best_lane = lane_counts.index(min(lane_counts))
            else:
                best_lane = 0
        
        return best_lane
    
    def _can_spawn_safely(self, direction, lane, cars):
        """Sistema inteligente de formação de filas - OTIMIZADO"""
        
        # === CALCULAR DISTÂNCIAS E ESTADO DA FILA ===
        distance_to_nearest = self._get_distance_to_nearest_car(direction, lane, cars)
        cars_in_lane = [car for car in cars 
                       if car.direction == direction and car.lane == lane]
        
        # === LÓGICA BASEADA NO ESTADO DO TRÁFEGO ===
        queue_distance = SPAWN_CONFIG['queue_spawn_distance']  # 20 pixels
        normal_distance = SPAWN_CONFIG['min_spawn_distance']   # 25 pixels
        
        # Se há muito espaço livre, sempre spawnar
        if distance_to_nearest >= 80:
            return True
        
        # === DETECÇÃO DE FILA PARADA (SEMÁFORO VERMELHO) ===
        # Verificar se há carros parados (formando fila)
        stopped_cars = [car for car in cars_in_lane if car.current_speed < 0.2]
        queue_forming = len(stopped_cars) >= 2
        
        if queue_forming:
            # Durante formação de fila, permitir spawn mais próximo
            min_distance = queue_distance
            max_cars_in_queue = 12  # Permitir filas maiores
        else:
            # Tráfego normal, usar distâncias padrão
            min_distance = normal_distance
            max_cars_in_queue = 8
        
        # === VERIFICAÇÕES DE SEGURANÇA ===
        # Verificar espaço mínimo
        if distance_to_nearest < min_distance:
            return False
            
        # Verificar se faixa não está lotada
        if len(cars_in_lane) >= max_cars_in_queue:
            return False
        
        # === SPAWN BALANCEADO ===
        # Se há espaço adequado, permitir spawn
        return distance_to_nearest >= min_distance
    
    def _get_distance_to_nearest_car(self, direction, lane, cars):
        """Calcular distância até o carro mais próximo na faixa"""
        cars_in_lane = [car for car in cars 
                       if car.direction == direction and car.lane == lane]
        
        if not cars_in_lane:
            return float('inf')  # Faixa vazia
        
        # Encontrar carro mais próximo do ponto de spawn
        min_distance = float('inf')
        
        for car in cars_in_lane:
            distance = self._calculate_distance_to_spawn(car)
            if distance >= 0:  # Apenas carros que ainda não passaram do spawn
                min_distance = min(min_distance, distance)
        
        return min_distance if min_distance != float('inf') else float('inf')
    
    def _calculate_distance_to_spawn(self, car):
        """Calcular distância do carro até o ponto de spawn"""
        if car.direction == Direction.LEFT_TO_RIGHT:
            # Spawn à esquerda (-30), distância até o carro
            return car.x - (-30)
        elif car.direction == Direction.RIGHT_TO_LEFT:
            # Spawn à direita (WINDOW_WIDTH + 30), distância até o carro
            return (WINDOW_WIDTH + 30) - car.x
        elif car.direction == Direction.TOP_TO_BOTTOM:
            # Spawn em cima (-30), distância até o carro
            return car.y - (-30)
        
        return 0
    
    def _count_cars_in_lane(self, direction, lane, cars):
        """Contar carros em uma faixa específica"""
        return len([car for car in cars 
                   if car.direction == direction and car.lane == lane])
    
    def get_statistics(self):
        """Retornar estatísticas do sistema de spawn"""
        return {
            'cars_spawned': self.cars_spawned,
            'spawn_attempts': self.spawn_attempts,
            'spawn_success_rate': (self.cars_spawned / max(1, self.spawn_attempts)) * 100,
            'last_spawn_times': dict(self.last_spawn_time)
        }