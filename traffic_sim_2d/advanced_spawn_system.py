import random
import time
from car import Car, Direction
from spawn_system import SpawnSystem
from config import *

class AdvancedSpawnSystem(SpawnSystem):
    def __init__(self):
        super().__init__()
        self.rush_hour_active = False
        self.rush_hour_multiplier = 2.5
        self.rush_hour_start_times = [7, 17]  # 7AM e 5PM
        self.rush_hour_duration = 2  # 2 horas
        
        # Fatores dinâmicos
        self.congestion_factor = 1.0
        self.weather_factor = 1.0  # Para futuras expansões
        
    def update(self, cars):
        # Detectar rush hour baseado no tempo simulado
        self._update_rush_hour_status()
        
        # Calcular fator de congestionamento
        self._update_congestion_factor(cars)
        
        # Ajustar spawn rate baseado em condições
        original_rate = self.base_spawn_rate
        
        if self.rush_hour_active:
            self.base_spawn_rate *= self.rush_hour_multiplier
        
        # Reduzir spawn se muito congestionado
        self.base_spawn_rate *= (2.0 - self.congestion_factor)
        
        new_cars = super().update(cars)
        
        # Resetar taxa
        self.base_spawn_rate = original_rate
            
        return new_cars
    
    def _update_rush_hour_status(self):
        """Simular rush hour baseado no tempo real (acelerado)"""
        # Simular um dia em 10 minutos (144x mais rápido)
        current_time = time.time()
        simulated_hour = ((current_time * 144) % 86400) / 3600
        
        self.rush_hour_active = False
        for start_time in self.rush_hour_start_times:
            if start_time <= simulated_hour <= start_time + self.rush_hour_duration:
                self.rush_hour_active = True
                break
    
    def _update_congestion_factor(self, cars):
        """Calcular nível de congestionamento"""
        total_cars = len(cars)
        
        # Contar carros parados ou muito lentos
        slow_cars = len([car for car in cars if car.current_speed < 0.5])
        
        # Contar carros na intersecção
        intersection_cars = len([car for car in cars 
                               if 480 <= car.x <= 680 and 280 <= car.y <= 520])
        
        # Fórmula de congestionamento
        self.congestion_factor = min(2.0, 
            (total_cars / 50.0) * 0.4 + 
            (slow_cars / max(total_cars, 1)) * 0.3 +
            (intersection_cars / 10.0) * 0.3
        )
    
    def get_advanced_statistics(self):
        """Estatísticas avançadas do sistema"""
        base_stats = super().get_statistics()
        
        advanced_stats = {
            **base_stats,
            'rush_hour_active': self.rush_hour_active,
            'congestion_factor': self.congestion_factor,
            'effective_spawn_rate': self.base_spawn_rate * (2.0 - self.congestion_factor)
        }
        
        return advanced_stats
    
    def _can_spawn_safely(self, direction, lane, cars):
        """Sistema EXATO do HTML - sempre permitir spawn para formar filas"""
        
        # PRIMEIRA VERIFICAÇÃO: Espaço básico
        distance_to_nearest = self._get_distance_to_nearest_car(direction, lane, cars)
        
        # LÓGICA DO HTML: Se tem espaço mínimo, sempre spawnar
        if distance_to_nearest >= 30:  # Distância mínima pequena
            return True
        
        # LÓGICA DE FILA: Permitir spawn atrás da fila (como no HTML)
        return self._has_space_for_queueing(direction, lane, cars)
    
    def _should_spawn(self, direction, current_time, rate_factor):
        """Lógica melhorada que considera semáforos para formar filas"""
        # Reduzir intervalo mínimo para formar filas mais rapidamente
        min_interval = 0.8  # Era 1.0, agora 0.8 segundos
        
        if current_time - self.last_spawn_time[direction] < min_interval:
            return False
        
        # Aumentar chance de spawn no semáforo vermelho para formar filas
        base_chance = self.base_spawn_rate * rate_factor
        
        # Bonus para formar filas (simular tráfego chegando mesmo no vermelho)
        queue_formation_bonus = 1.3
        spawn_chance = base_chance * queue_formation_bonus
        
        return random.random() < spawn_chance
    
    def _has_space_for_queueing(self, direction, lane, cars):
        """Lógica EXATA do HTML"""
        spawn_pos = self._get_spawn_position(direction, lane)
        cars_in_lane = [car for car in cars if car.direction == direction and car.lane == lane]
        
        if not cars_in_lane:
            return True
        
        # Encontrar último carro da fila (EXATO como HTML)
        closest_distance_to_spawn = float('inf')
        last_car_in_queue = None
        
        for car in cars_in_lane:
            distance_to_spawn = self._calculate_directional_distance_to_spawn(car, direction)
            if distance_to_spawn >= 0 and distance_to_spawn < closest_distance_to_spawn:
                closest_distance_to_spawn = distance_to_spawn
                last_car_in_queue = car
        
        # REGRA DO HTML: Se há espaço de pelo menos 30 unidades, spawnar
        return not last_car_in_queue or closest_distance_to_spawn >= 30

    def _calculate_directional_distance_to_spawn(self, car, direction):
        """Cálculo EXATO do HTML"""
        spawn_pos = self._get_spawn_position(direction, 0)
        
        if direction == Direction.LEFT_TO_RIGHT:
            return car.x - spawn_pos[0]  # positivo se carro está à frente
        elif direction == Direction.RIGHT_TO_LEFT:
            return spawn_pos[0] - car.x  # positivo se carro está à frente
        elif direction == Direction.TOP_TO_BOTTOM:
            return car.y - spawn_pos[1]  # positivo se carro está à frente
        
        return 0
    
    def _get_spawn_position(self, direction, lane):
        """Obter posição de spawn para uma direção e faixa"""
        from config import WINDOW_WIDTH, WINDOW_HEIGHT
        
        # Calcular posições baseadas na intersecção centralizada
        center_y = WINDOW_HEIGHT // 2  # 720
        road_y = center_y - 80  # Posição da rua principal
        center_x = WINDOW_WIDTH // 2  # 1720
        cross_road_x = center_x - 40  # Posição da rua vertical
        
        if direction == Direction.LEFT_TO_RIGHT:
            x = -30  # Fora da tela à esquerda
            y = road_y + 10 + (lane * 35)  # Primeira e segunda faixa
        elif direction == Direction.RIGHT_TO_LEFT:
            x = WINDOW_WIDTH + 30  # Fora da tela à direita
            y = road_y + 125 - (lane * 35)  # Terceira e quarta faixa
        elif direction == Direction.TOP_TO_BOTTOM:
            x = cross_road_x + 20  # Centralizado na rua vertical
            y = -30  # Fora da tela DE CIMA
        
        return (x, y)