import time
import pygame
from collections import deque
from car import Direction, DriverPersonality
from config import COLORS

class TrafficAnalytics:
    def __init__(self):
        self.metrics = {
            'throughput_by_direction': {dir: [] for dir in Direction},
            'wait_times_by_personality': {p: [] for p in DriverPersonality},
            'congestion_levels': deque(maxlen=300),  # 5 minutos a 60 FPS
            'light_efficiency': [],
            'near_miss_events': 0,
            'total_intersection_crossings': 0
        }
        
        # Histórico de throughput para gráfico
        self.throughput_history = deque(maxlen=180)  # 3 minutos a 60 FPS
        
        # Contadores por segundo
        self.last_second_count = int(time.time())
        self.cars_per_second = 0
        self.current_second_cars = 0
        
        # Estatísticas em tempo real
        self.real_time_stats = {
            'cars_in_intersection': 0,
            'average_speed': 0,
            'congestion_score': 0,
            'efficiency_rating': 100
        }
        
    def update(self, cars, traffic_lights):
        """Coletar métricas em tempo real"""
        current_second = int(time.time())
        
        # Resetar contadores por segundo
        if current_second != self.last_second_count:
            self.throughput_history.append(self.current_second_cars)
            self.current_second_cars = 0
            self.last_second_count = current_second
        
        # Calcular throughput por direção
        self._calculate_throughput(cars)
        
        # Analisar tempos de espera por personalidade
        self._analyze_wait_times(cars)
        
        # Calcular nível de congestionamento
        self._calculate_congestion(cars)
        
        # Analisar eficiência dos semáforos
        self._analyze_light_efficiency(traffic_lights)
        
        # Detectar eventos de quase-colisão
        self._detect_near_misses(cars)
        
        # Atualizar estatísticas em tempo real
        self._update_real_time_stats(cars)
    
    def _calculate_throughput(self, cars):
        """Calcular throughput por direção"""
        # Contar carros que passaram pela intersecção neste frame
        for car in cars:
            if not hasattr(car, '_counted_for_throughput'):
                car._counted_for_throughput = False
            
            if not car._counted_for_throughput and car.has_passed_intersection:
                self.metrics['throughput_by_direction'][car.direction].append(time.time())
                self.metrics['total_intersection_crossings'] += 1
                self.current_second_cars += 1
                car._counted_for_throughput = True
    
    def _analyze_wait_times(self, cars):
        """Analisar tempos de espera por personalidade"""
        for car in cars:
            if car.state.value == 'waiting' and car.total_wait_time > 0:
                if not hasattr(car, '_wait_time_recorded'):
                    car._wait_time_recorded = False
                
                if not car._wait_time_recorded and car.total_wait_time > 3.0:  # Mais de 3 segundos
                    self.metrics['wait_times_by_personality'][car.personality].append(car.total_wait_time)
                    car._wait_time_recorded = True
    
    def _calculate_congestion(self, cars):
        """Calcular nível de congestionamento"""
        total_cars = len(cars)
        if total_cars == 0:
            congestion = 0
        else:
            # Fatores de congestionamento
            stopped_cars = len([car for car in cars if car.current_speed < 0.1])
            slow_cars = len([car for car in cars if 0.1 <= car.current_speed < 1.0])
            intersection_cars = len([car for car in cars 
                                   if 480 <= car.x <= 680 and 280 <= car.y <= 520])
            
            # Fórmula de congestionamento (0-100)
            congestion = min(100, 
                (stopped_cars / total_cars) * 40 + 
                (slow_cars / total_cars) * 25 +
                (intersection_cars / 15) * 35
            )
        
        self.metrics['congestion_levels'].append(congestion)
    
    def _analyze_light_efficiency(self, traffic_lights):
        """Analisar eficiência dos semáforos"""
        # Calcular utilização do tempo verde
        cycle_progress = traffic_lights.get_cycle_progress()
        
        # Simples métrica de eficiência baseada no uso dos semáforos
        recent_congestion = list(self.metrics['congestion_levels'])[-10:] if self.metrics['congestion_levels'] else [0]
        efficiency = 85 + (15 * (1 - min(1.0, len(recent_congestion) / 10)))
        self.metrics['light_efficiency'].append(efficiency)
    
    def _detect_near_misses(self, cars):
        """Detectar eventos de quase-colisão"""
        for i, car1 in enumerate(cars):
            for car2 in cars[i+1:]:
                distance = ((car1.x - car2.x)**2 + (car1.y - car2.y)**2)**0.5
                
                # Diferentes direções e muito próximos = quase-colisão
                if (car1.direction != car2.direction and 
                    distance < 40 and 
                    car1.current_speed > 0.5 and car2.current_speed > 0.5):
                    self.metrics['near_miss_events'] += 1
    
    def _update_real_time_stats(self, cars):
        """Atualizar estatísticas em tempo real"""
        if cars:
            self.real_time_stats['cars_in_intersection'] = len([
                car for car in cars if 480 <= car.x <= 680 and 280 <= car.y <= 520
            ])
            
            speeds = [car.current_speed for car in cars if car.current_speed > 0]
            self.real_time_stats['average_speed'] = sum(speeds) / len(speeds) if speeds else 0
            
            if self.metrics['congestion_levels']:
                self.real_time_stats['congestion_score'] = self.metrics['congestion_levels'][-1]
            
            if self.metrics['light_efficiency']:
                self.real_time_stats['efficiency_rating'] = self.metrics['light_efficiency'][-1]
    
    def get_detailed_report(self):
        """Relatório completo de performance"""
        current_time = time.time()
        
        # Throughput médio por direção (últimos 60 segundos)
        avg_throughput = {}
        for direction, timestamps in self.metrics['throughput_by_direction'].items():
            recent_crossings = [t for t in timestamps if current_time - t <= 60]
            avg_throughput[direction.name] = len(recent_crossings)
        
        # Tempo de espera médio por personalidade
        avg_wait_times = {}
        for personality, times in self.metrics['wait_times_by_personality'].items():
            avg_wait_times[personality.name] = sum(times) / len(times) if times else 0
        
        return {
            'avg_throughput_by_direction': avg_throughput,
            'avg_wait_times_by_personality': avg_wait_times,
            'current_congestion': self.real_time_stats['congestion_score'],
            'efficiency_rating': self.real_time_stats['efficiency_rating'],
            'total_crossings': self.metrics['total_intersection_crossings'],
            'near_misses': self.metrics['near_miss_events'],
            'average_speed': self.real_time_stats['average_speed']
        }
    
    def draw_throughput_graph(self, screen, rect):
        """Desenhar gráfico de throughput em tempo real"""
        pygame.draw.rect(screen, (0, 0, 0, 128), rect)
        pygame.draw.rect(screen, COLORS['white'], rect, 2)
        
        if len(self.throughput_history) > 1:
            max_value = max(self.throughput_history) if self.throughput_history else 1
            points = []
            
            for i, value in enumerate(self.throughput_history):
                x = rect.left + (i * (rect.width / len(self.throughput_history)))
                y = rect.bottom - (value / max(max_value, 1)) * rect.height
                points.append((x, y))
            
            if len(points) > 1:
                pygame.draw.lines(screen, COLORS['green'], False, points, 2)
        
        # Labels
        font = pygame.font.Font(None, 16)
        title = font.render("Throughput (carros/s)", True, COLORS['white'])
        screen.blit(title, (rect.left + 5, rect.top + 5))
    
    def draw_congestion_heatmap(self, screen, cars, rect):
        """Desenhar mapa de calor de congestionamento"""
        # Criar grid de congestionamento
        grid_size = 20
        grid_width = rect.width // grid_size
        grid_height = rect.height // grid_size
        
        # Contar carros em cada célula do grid
        for i in range(grid_width):
            for j in range(grid_height):
                cell_cars = 0
                cell_x = rect.left + i * grid_size
                cell_y = rect.top + j * grid_size
                
                # Mapear para coordenadas do mundo
                world_x = (cell_x / rect.width) * 1200
                world_y = (cell_y / rect.height) * 800
                
                for car in cars:
                    if (world_x <= car.x <= world_x + (1200/grid_width) and
                        world_y <= car.y <= world_y + (800/grid_height)):
                        cell_cars += 1
                
                # Cor baseada na densidade
                if cell_cars > 0:
                    intensity = min(255, cell_cars * 60)
                    color = (intensity, 0, 255 - intensity)
                    pygame.draw.rect(screen, color, 
                                   (cell_x, cell_y, grid_size, grid_size))