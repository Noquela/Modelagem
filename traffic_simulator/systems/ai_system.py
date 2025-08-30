"""
Sistema de IA para controle comportamental dos carros
Gerencia decisões coletivas, fluxo de tráfego e comportamentos emergentes
"""
import numpy as np
import time
from typing import List, Dict, Any, Optional, Tuple
from ..entities.car import Car, CarState, Direction
from ..utils.config import CAR_CONFIG


class TrafficAnalyzer:
    """Analisador de padrões de tráfego em tempo real."""
    
    def __init__(self):
        self.analysis_interval = 1.0  # Analisar a cada 1 segundo
        self.last_analysis = 0.0
        
        # Métricas de tráfego
        self.metrics = {
            'total_cars': 0,
            'average_speed': 0.0,
            'throughput': {'LEFT_TO_RIGHT': 0, 'RIGHT_TO_LEFT': 0, 'TOP_TO_BOTTOM': 0},
            'wait_times': [],
            'congestion_level': 0.0,
            'intersection_efficiency': 0.0,
        }
        
        # Histórico para análise temporal
        self.history = []
        self.max_history = 60  # 1 minuto de histórico
    
    def analyze(self, cars: List[Car], traffic_lights: List[Any]) -> Dict[str, Any]:
        """
        Analisa estado atual do tráfego.
        
        Returns:
            Métricas de tráfego atualizadas
        """
        current_time = time.time()
        
        if current_time - self.last_analysis < self.analysis_interval:
            return self.metrics
        
        # Análise básica
        self._analyze_basic_metrics(cars)
        
        # Análise de throughput
        self._analyze_throughput(cars)
        
        # Análise de congestionamento
        self._analyze_congestion(cars)
        
        # Análise da intersecção
        self._analyze_intersection_efficiency(cars, traffic_lights)
        
        # Salvar no histórico
        self.history.append({
            'timestamp': current_time,
            'metrics': dict(self.metrics)
        })
        
        if len(self.history) > self.max_history:
            self.history.pop(0)
        
        self.last_analysis = current_time
        return self.metrics
    
    def _analyze_basic_metrics(self, cars: List[Car]):
        """Análise de métricas básicas."""
        if not cars:
            self.metrics['total_cars'] = 0
            self.metrics['average_speed'] = 0.0
            return
        
        total_speed = sum(car.physics.velocity for car in cars)
        self.metrics['total_cars'] = len(cars)
        self.metrics['average_speed'] = total_speed / len(cars)
        
        # Tempos de espera
        wait_times = [car.get_total_wait_time() for car in cars]
        self.metrics['wait_times'] = wait_times
        self.metrics['average_wait_time'] = sum(wait_times) / len(wait_times) if wait_times else 0.0
    
    def _analyze_throughput(self, cars: List[Car]):
        """Análise de throughput por direção."""
        for direction in ['LEFT_TO_RIGHT', 'RIGHT_TO_LEFT', 'TOP_TO_BOTTOM']:
            # Contar carros que passaram da intersecção recentemente
            direction_enum = getattr(Direction, direction)
            passed_cars = [
                car for car in cars 
                if (car.direction == direction_enum and 
                    car.has_passed_intersection and
                    car.get_age() < 60.0)  # Últimos 60 segundos
            ]
            self.metrics['throughput'][direction] = len(passed_cars)
    
    def _analyze_congestion(self, cars: List[Car]):
        """Análise de nível de congestionamento."""
        if not cars:
            self.metrics['congestion_level'] = 0.0
            return
        
        # Contar carros parados ou muito lentos
        slow_cars = sum(1 for car in cars if car.physics.velocity < 0.01)
        self.metrics['congestion_level'] = slow_cars / len(cars)
    
    def _analyze_intersection_efficiency(self, cars: List[Car], traffic_lights: List[Any]):
        """Análise de eficiência da intersecção."""
        # Contar carros esperando na intersecção
        waiting_at_intersection = 0
        total_near_intersection = 0
        
        for car in cars:
            distance_to_intersection = car._get_distance_to_intersection()
            if distance_to_intersection < 15.0:  # Próximo à intersecção
                total_near_intersection += 1
                if car.state == CarState.WAITING:
                    waiting_at_intersection += 1
        
        if total_near_intersection > 0:
            efficiency = 1.0 - (waiting_at_intersection / total_near_intersection)
            self.metrics['intersection_efficiency'] = efficiency
        else:
            self.metrics['intersection_efficiency'] = 1.0


class CollisionAvoidanceSystem:
    """Sistema de prevenção de colisões."""
    
    def __init__(self):
        self.collision_distance = CAR_CONFIG['min_distance']
        self.prediction_time = 2.0  # Prever colisões 2 segundos à frente
    
    def check_potential_collisions(self, cars: List[Car]) -> List[Tuple[Car, Car, float]]:
        """
        Verifica colisões potenciais entre carros.
        
        Returns:
            Lista de tuplas (car1, car2, time_to_collision)
        """
        potential_collisions = []
        
        for i, car1 in enumerate(cars):
            for car2 in cars[i+1:]:
                # Verificar apenas carros na mesma área
                if self._are_cars_nearby(car1, car2):
                    collision_time = self._calculate_collision_time(car1, car2)
                    if 0 < collision_time < self.prediction_time:
                        potential_collisions.append((car1, car2, collision_time))
        
        return potential_collisions
    
    def _are_cars_nearby(self, car1: Car, car2: Car) -> bool:
        """Verifica se carros estão próximos o suficiente para colidir."""
        distance = np.linalg.norm(car1.physics.position - car2.physics.position)
        return distance < 10.0  # 10 metros de raio de verificação
    
    def _calculate_collision_time(self, car1: Car, car2: Car) -> float:
        """
        Calcula tempo até colisão baseado em velocidades e posições.
        
        Returns:
            Tempo até colisão (negativo se não há colisão)
        """
        # Vetores de posição e velocidade relativos
        rel_pos = car2.physics.position - car1.physics.position
        
        # Simplificação: assumir movimento linear
        if car1.direction == car2.direction:
            # Mesmo direção - usar velocidade relativa
            rel_velocity = car2.physics.velocity - car1.physics.velocity
            if abs(rel_velocity) < 0.001:
                return float('inf')  # Velocidades iguais, sem colisão
            
            # Distância até colisão
            distance = np.linalg.norm(rel_pos)
            time_to_collision = distance / abs(rel_velocity)
            
            return time_to_collision if distance < self.collision_distance * 2 else -1.0
        
        return -1.0  # Direções diferentes, sem risco imediato


class TrafficFlowOptimizer:
    """Otimizador de fluxo de tráfego."""
    
    def __init__(self):
        self.optimization_interval = 5.0  # Otimizar a cada 5 segundos
        self.last_optimization = 0.0
        
        # Parâmetros de otimização
        self.target_density = 0.7  # Densidade ideal de tráfego
        self.speed_adjustment_factor = 0.1
    
    def optimize_flow(self, cars: List[Car], analyzer: TrafficAnalyzer) -> Dict[str, Any]:
        """
        Otimiza fluxo de tráfego baseado nas métricas atuais.
        
        Returns:
            Recomendações de otimização
        """
        current_time = time.time()
        
        if current_time - self.last_optimization < self.optimization_interval:
            return {}
        
        recommendations = {}
        
        # Analisar congestionamento por direção
        congestion_by_direction = self._analyze_directional_congestion(cars)
        
        # Recomendar ajustes de velocidade
        speed_adjustments = self._calculate_speed_adjustments(congestion_by_direction)
        
        # Recomendar ajustes de spawn
        spawn_adjustments = self._calculate_spawn_adjustments(congestion_by_direction)
        
        recommendations = {
            'speed_adjustments': speed_adjustments,
            'spawn_adjustments': spawn_adjustments,
            'congestion_analysis': congestion_by_direction,
        }
        
        self.last_optimization = current_time
        return recommendations
    
    def _analyze_directional_congestion(self, cars: List[Car]) -> Dict[str, Dict[str, Any]]:
        """Analisa congestionamento por direção."""
        analysis = {}
        
        for direction in Direction:
            direction_cars = [car for car in cars if car.direction == direction]
            
            if not direction_cars:
                analysis[direction.name] = {
                    'count': 0,
                    'avg_speed': 0.0,
                    'congestion': 0.0,
                    'stopped_ratio': 0.0,
                }
                continue
            
            total_speed = sum(car.physics.velocity for car in direction_cars)
            stopped_cars = sum(1 for car in direction_cars if car.physics.velocity < 0.001)
            
            analysis[direction.name] = {
                'count': len(direction_cars),
                'avg_speed': total_speed / len(direction_cars),
                'congestion': self._calculate_congestion_level(direction_cars),
                'stopped_ratio': stopped_cars / len(direction_cars),
            }
        
        return analysis
    
    def _calculate_congestion_level(self, cars: List[Car]) -> float:
        """Calcula nível de congestionamento (0.0 = livre, 1.0 = parado)."""
        if not cars:
            return 0.0
        
        # Baseado em velocidade média e densidade
        avg_speed = sum(car.physics.velocity for car in cars) / len(cars)
        max_speed = CAR_CONFIG['base_speed']
        
        speed_factor = 1.0 - (avg_speed / max_speed)
        
        # Fator de densidade (simplificado)
        density_factor = min(1.0, len(cars) / 20.0)  # 20 carros = densidade máxima
        
        return (speed_factor * 0.7) + (density_factor * 0.3)
    
    def _calculate_speed_adjustments(self, congestion_analysis: Dict[str, Dict[str, Any]]) -> Dict[str, float]:
        """Calcula ajustes de velocidade recomendados."""
        adjustments = {}
        
        for direction, analysis in congestion_analysis.items():
            congestion = analysis['congestion']
            
            if congestion > 0.8:  # Alto congestionamento
                adjustments[direction] = -0.2  # Reduzir velocidade 20%
            elif congestion < 0.3:  # Baixo congestionamento
                adjustments[direction] = 0.1   # Aumentar velocidade 10%
            else:
                adjustments[direction] = 0.0   # Manter velocidade
        
        return adjustments
    
    def _calculate_spawn_adjustments(self, congestion_analysis: Dict[str, Dict[str, Any]]) -> Dict[str, float]:
        """Calcula ajustes de spawn recomendados."""
        adjustments = {}
        
        for direction, analysis in congestion_analysis.items():
            congestion = analysis['congestion']
            count = analysis['count']
            
            if congestion > 0.7 or count > 15:  # Muito congestionado
                adjustments[direction] = -0.5  # Reduzir spawn 50%
            elif congestion < 0.2 and count < 5:  # Pouco tráfego
                adjustments[direction] = 0.3   # Aumentar spawn 30%
            else:
                adjustments[direction] = 0.0   # Manter spawn
        
        return adjustments


class AISystem:
    """Sistema principal de IA para gerenciamento de tráfego."""
    
    def __init__(self):
        self.analyzer = TrafficAnalyzer()
        self.collision_system = CollisionAvoidanceSystem()
        self.flow_optimizer = TrafficFlowOptimizer()
        
        # Estado do sistema
        self.is_active = True
        self.update_interval = 0.1  # Atualizar a cada 100ms
        self.last_update = 0.0
        
        # Métricas globais
        self.global_metrics = {}
        self.optimization_recommendations = {}
    
    def update(self, cars: List[Car], traffic_lights: List[Any]) -> Dict[str, Any]:
        """
        Atualização principal do sistema de IA.
        
        Returns:
            Métricas e recomendações atualizadas
        """
        if not self.is_active:
            return {}
        
        current_time = time.time()
        
        if current_time - self.last_update < self.update_interval:
            return {
                'metrics': self.global_metrics,
                'recommendations': self.optimization_recommendations,
            }
        
        # Análise de tráfego
        traffic_metrics = self.analyzer.analyze(cars, traffic_lights)
        
        # Verificação de colisões
        potential_collisions = self.collision_system.check_potential_collisions(cars)
        
        # Otimização de fluxo
        flow_recommendations = self.flow_optimizer.optimize_flow(cars, self.analyzer)
        
        # Consolidar resultados
        self.global_metrics = {
            **traffic_metrics,
            'potential_collisions': len(potential_collisions),
            'collision_details': potential_collisions[:5],  # Apenas as 5 mais críticas
        }
        
        self.optimization_recommendations = flow_recommendations
        
        self.last_update = current_time
        
        return {
            'metrics': self.global_metrics,
            'recommendations': self.optimization_recommendations,
        }
    
    def apply_recommendations(self, cars: List[Car]) -> int:
        """
        Aplica recomendações de otimização aos carros.
        
        Returns:
            Número de carros afetados
        """
        if not self.optimization_recommendations:
            return 0
        
        affected_cars = 0
        speed_adjustments = self.optimization_recommendations.get('speed_adjustments', {})
        
        for car in cars:
            direction_name = car.direction.name
            if direction_name in speed_adjustments:
                adjustment = speed_adjustments[direction_name]
                
                # Aplicar ajuste de velocidade
                old_max_speed = car.physics.max_speed
                car.physics.max_speed *= (1.0 + adjustment)
                
                # Limitar velocidade máxima
                car.physics.max_speed = max(
                    CAR_CONFIG['base_speed'] * 0.5,  # Mínimo 50% da velocidade base
                    min(car.physics.max_speed, CAR_CONFIG['base_speed'] * 1.5)  # Máximo 150%
                )
                
                if abs(car.physics.max_speed - old_max_speed) > 0.001:
                    affected_cars += 1
        
        return affected_cars
    
    def get_performance_metrics(self) -> Dict[str, Any]:
        """Retorna métricas de performance do sistema de IA."""
        return {
            'analyzer_history_size': len(self.analyzer.history),
            'last_analysis_time': self.analyzer.last_analysis,
            'optimization_active': bool(self.optimization_recommendations),
            'system_active': self.is_active,
        }
    
    def reset_history(self):
        """Reseta histórico de análises."""
        self.analyzer.history.clear()
        self.global_metrics.clear()
        self.optimization_recommendations.clear()
    
    def pause(self):
        """Pausa sistema de IA."""
        self.is_active = False
    
    def resume(self):
        """Resume sistema de IA."""
        self.is_active = True
    
    def get_traffic_summary(self) -> str:
        """Retorna resumo textual do tráfego atual."""
        if not self.global_metrics:
            return "No traffic data available"
        
        total_cars = self.global_metrics.get('total_cars', 0)
        avg_speed = self.global_metrics.get('average_speed', 0.0)
        congestion = self.global_metrics.get('congestion_level', 0.0)
        efficiency = self.global_metrics.get('intersection_efficiency', 0.0)
        
        # Classificar condições
        if congestion > 0.7:
            condition = "Heavy Traffic"
        elif congestion > 0.4:
            condition = "Moderate Traffic"
        else:
            condition = "Light Traffic"
        
        return (f"{condition}: {total_cars} cars, "
               f"avg speed {avg_speed:.2f}, "
               f"congestion {congestion:.1%}, "
               f"efficiency {efficiency:.1%}")