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
        """Sistema de fila realística - spawn mesmo no vermelho"""
        distance_to_nearest = self._get_distance_to_nearest_car(direction, lane, cars)
        
        # NOVA LÓGICA: Permitir spawn mais próximo para formar filas realísticas
        min_safe_distance = 40  # Distância menor para permitir filas
        
        # Se há espaço físico mínimo, sempre spawnar (mesmo no vermelho)
        if distance_to_nearest >= min_safe_distance:
            return True
        
        # Se a fila está muito longa, parar de spawnar temporariamente
        cars_in_lane = [car for car in cars 
                       if car.direction == direction and car.lane == lane]
        
        # Limitar fila a 15 carros por faixa para evitar travamento total
        if len(cars_in_lane) >= 15:
            return False
            
        return distance_to_nearest >= min_safe_distance
    
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