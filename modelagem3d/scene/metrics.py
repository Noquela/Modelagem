"""
Sistema de Métricas e Logging
============================

Coleta e análise de dados de performance do simulador:
- Estatísticas de tráfego em tempo real
- Rolling averages e histórico
- Export para CSV para análise posterior
- Métricas de performance dos semáforos
"""

import os
import csv
import time
from datetime import datetime
from typing import Dict, List, Any, Optional
from collections import deque

class RollingAverage:
    """Calcula médias móveis com janela de tempo"""
    
    def __init__(self, window_size: int = 60):
        self.window_size = window_size
        self.values = deque(maxlen=window_size)
        self.sum_values = 0.0
    
    def add(self, value: float):
        """Adiciona valor ao cálculo da média"""
        if len(self.values) == self.window_size:
            self.sum_values -= self.values[0]
        
        self.values.append(value)
        self.sum_values += value
    
    def get_average(self) -> float:
        """Retorna média atual"""
        if not self.values:
            return 0.0
        return self.sum_values / len(self.values)
    
    def reset(self):
        """Limpa histórico"""
        self.values.clear()
        self.sum_values = 0.0

class PerformanceCounter:
    """Contador de performance com rate calculation"""
    
    def __init__(self):
        self.count = 0
        self.last_reset_time = time.time()
        self.rate_history = RollingAverage(30)  # 30 segundos
    
    def increment(self, amount: int = 1):
        """Incrementa contador"""
        self.count += amount
    
    def update(self, dt: float):
        """Atualiza cálculo de rate"""
        current_time = time.time()
        elapsed = current_time - self.last_reset_time
        
        if elapsed >= 1.0:  # Atualizar a cada segundo
            rate = self.count / elapsed
            self.rate_history.add(rate)
            
            self.count = 0
            self.last_reset_time = current_time
    
    def get_rate(self) -> float:
        """Retorna rate atual (eventos por segundo)"""
        return self.rate_history.get_average()
    
    def reset(self):
        """Reseta contador"""
        self.count = 0
        self.last_reset_time = time.time()
        self.rate_history.reset()

class TrafficMetrics:
    """Métricas específicas de tráfego por direção"""
    
    def __init__(self, direction: str):
        self.direction = direction
        
        # Contadores básicos
        self.vehicles_spawned = PerformanceCounter()
        self.vehicles_completed = PerformanceCounter()
        self.pedestrians_served = PerformanceCounter()
        
        # Métricas de tempo
        self.wait_times = RollingAverage(100)  # Últimos 100 veículos
        self.travel_times = RollingAverage(100)
        self.signal_efficiency = RollingAverage(60)  # 1 minuto
        
        # Estado atual
        self.current_queue_length = 0
        self.max_queue_length = 0
        self.current_waiting_time = 0.0
        
        # Histórico para análise
        self.hourly_throughput: List[int] = []
        self.signal_cycles: List[Dict] = []
    
    def record_vehicle_spawn(self):
        """Registra spawn de veículo"""
        self.vehicles_spawned.increment()
    
    def record_vehicle_completion(self, wait_time: float, travel_time: float):
        """Registra completamento de veículo"""
        self.vehicles_completed.increment()
        self.wait_times.add(wait_time)
        self.travel_times.add(travel_time)
    
    def record_queue_state(self, queue_length: int, waiting_time: float):
        """Registra estado atual da fila"""
        self.current_queue_length = queue_length
        self.max_queue_length = max(self.max_queue_length, queue_length)
        self.current_waiting_time = waiting_time
    
    def record_signal_cycle(self, cycle_data: Dict):
        """Registra ciclo completo do semáforo"""
        self.signal_cycles.append({
            'timestamp': time.time(),
            'green_time': cycle_data.get('green_time', 0),
            'vehicles_served': cycle_data.get('vehicles_served', 0),
            'extensions_used': cycle_data.get('extensions_used', 0),
            **cycle_data
        })
        
        # Calcular eficiência (veículos por segundo de verde)
        if cycle_data.get('green_time', 0) > 0:
            efficiency = cycle_data.get('vehicles_served', 0) / cycle_data['green_time']
            self.signal_efficiency.add(efficiency)
    
    def update(self, dt: float):
        """Atualiza métricas"""
        self.vehicles_spawned.update(dt)
        self.vehicles_completed.update(dt)
        self.pedestrians_served.update(dt)
    
    def get_summary(self) -> Dict:
        """Retorna resumo das métricas"""
        return {
            'direction': self.direction,
            'spawn_rate': self.vehicles_spawned.get_rate(),
            'completion_rate': self.vehicles_completed.get_rate(),
            'avg_wait_time': self.wait_times.get_average(),
            'avg_travel_time': self.travel_times.get_average(),
            'current_queue': self.current_queue_length,
            'max_queue': self.max_queue_length,
            'signal_efficiency': self.signal_efficiency.get_average(),
            'total_completed': sum(len(self.signal_cycles) for _ in [0]),  # Placeholder
        }

class SystemMetrics:
    """Métricas globais do sistema"""
    
    def __init__(self):
        # Performance do renderizador
        self.frame_rate = RollingAverage(60)  # 1 minuto
        self.frame_time = RollingAverage(60)
        self.draw_calls = PerformanceCounter()
        
        # Recursos do sistema
        self.memory_usage = RollingAverage(30)
        self.cpu_usage = RollingAverage(30)
        
        # Estado da simulação
        self.simulation_speed = 1.0
        self.total_runtime = 0.0
        self.paused_time = 0.0
        
        # Contadores globais
        self.total_vehicles = 0
        self.total_pedestrians = 0
        self.shader_fallbacks = 0
    
    def record_frame(self, fps: float, frame_time: float, draw_calls: int):
        """Registra métricas do frame"""
        self.frame_rate.add(fps)
        self.frame_time.add(frame_time)
        self.draw_calls.count = draw_calls
    
    def record_system_resources(self, memory_mb: float, cpu_percent: float):
        """Registra uso de recursos do sistema"""
        self.memory_usage.add(memory_mb)
        self.cpu_usage.add(cpu_percent)
    
    def update(self, dt: float, is_paused: bool):
        """Atualiza métricas do sistema"""
        self.draw_calls.update(dt)
        
        if not is_paused:
            self.total_runtime += dt
        else:
            self.paused_time += dt
    
    def get_summary(self) -> Dict:
        """Retorna resumo das métricas do sistema"""
        return {
            'avg_fps': self.frame_rate.get_average(),
            'avg_frame_time': self.frame_time.get_average() * 1000,  # ms
            'draw_calls_per_sec': self.draw_calls.get_rate(),
            'memory_usage_mb': self.memory_usage.get_average(),
            'cpu_usage_percent': self.cpu_usage.get_average(),
            'total_runtime': self.total_runtime,
            'total_vehicles': self.total_vehicles,
            'total_pedestrians': self.total_pedestrians,
            'shader_fallbacks': self.shader_fallbacks
        }

class MetricsCollector:
    """Coletor principal de métricas"""
    
    def __init__(self):
        # Métricas por direção
        self.traffic_metrics = {
            'north': TrafficMetrics('north'),
            'south': TrafficMetrics('south'),
            'east': TrafficMetrics('east'),
            'west': TrafficMetrics('west')
        }
        
        # Métricas do sistema
        self.system_metrics = SystemMetrics()
        
        # Configuração de logging
        self.log_directory = "logs"
        self.log_filename = None
        self.csv_writer = None
        self.csv_file = None
        
        # Estado
        self.start_time = time.time()
        self.last_csv_write = 0.0
        self.csv_write_interval = 10.0  # Escrever a cada 10 segundos
        
        # Criar diretório de logs
        self._ensure_log_directory()
        
        print("Sistema de métricas inicializado")
    
    def _ensure_log_directory(self):
        """Garante que o diretório de logs existe"""
        if not os.path.exists(self.log_directory):
            os.makedirs(self.log_directory)
    
    def start_csv_logging(self):
        """Inicia logging para CSV"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.log_filename = os.path.join(self.log_directory, f"traffic_metrics_{timestamp}.csv")
        
        try:
            self.csv_file = open(self.log_filename, 'w', newline='', encoding='utf-8')
            
            # Cabeçalhos do CSV
            fieldnames = [
                'timestamp', 'elapsed_time',
                # Sistema
                'fps', 'frame_time_ms', 'memory_mb', 'paused',
                # Por direção
                'north_spawn_rate', 'north_completion_rate', 'north_avg_wait', 'north_queue',
                'south_spawn_rate', 'south_completion_rate', 'south_avg_wait', 'south_queue',
                'east_spawn_rate', 'east_completion_rate', 'east_avg_wait', 'east_queue',
                'west_spawn_rate', 'west_completion_rate', 'west_avg_wait', 'west_queue',
                # Totais
                'total_vehicles', 'total_completed', 'avg_system_wait_time'
            ]
            
            self.csv_writer = csv.DictWriter(self.csv_file, fieldnames=fieldnames)
            self.csv_writer.writeheader()
            
            print(f"CSV logging iniciado: {self.log_filename}")
            
        except Exception as e:
            print(f"Erro ao iniciar CSV logging: {e}")
    
    def record_event(self, event_type: str, data: Dict[str, Any]):
        """Registra evento específico"""
        if event_type == 'vehicle_spawn':
            direction = data.get('direction')
            if direction in self.traffic_metrics:
                self.traffic_metrics[direction].record_vehicle_spawn()
        
        elif event_type == 'vehicle_complete':
            direction = data.get('direction')
            if direction in self.traffic_metrics:
                wait_time = data.get('wait_time', 0)
                travel_time = data.get('travel_time', 0)
                self.traffic_metrics[direction].record_vehicle_completion(wait_time, travel_time)
        
        elif event_type == 'signal_cycle':
            direction = data.get('direction')
            if direction in self.traffic_metrics:
                self.traffic_metrics[direction].record_signal_cycle(data)
        
        elif event_type == 'frame':
            fps = data.get('fps', 0)
            frame_time = data.get('frame_time', 0)
            draw_calls = data.get('draw_calls', 0)
            self.system_metrics.record_frame(fps, frame_time, draw_calls)
    
    def update(self, dt: float, is_paused: bool = False):
        """Atualiza todas as métricas"""
        # Atualizar métricas de tráfego
        for metrics in self.traffic_metrics.values():
            metrics.update(dt)
        
        # Atualizar métricas do sistema
        self.system_metrics.update(dt, is_paused)
        
        # Escrever para CSV periodicamente
        current_time = time.time()
        if (self.csv_writer and 
            current_time - self.last_csv_write >= self.csv_write_interval):
            self._write_csv_row(current_time, is_paused)
            self.last_csv_write = current_time
    
    def _write_csv_row(self, current_time: float, is_paused: bool):
        """Escreve linha no CSV"""
        try:
            # Coletar dados de todas as métricas
            system_data = self.system_metrics.get_summary()
            
            row_data = {
                'timestamp': datetime.fromtimestamp(current_time).isoformat(),
                'elapsed_time': current_time - self.start_time,
                'fps': system_data['avg_fps'],
                'frame_time_ms': system_data['avg_frame_time'],
                'memory_mb': system_data['memory_usage_mb'],
                'paused': 1 if is_paused else 0,
                'total_vehicles': system_data['total_vehicles']
            }
            
            # Adicionar dados por direção
            total_completed = 0
            total_wait_time = 0.0
            wait_count = 0
            
            for direction, metrics in self.traffic_metrics.items():
                summary = metrics.get_summary()
                prefix = direction
                
                row_data[f'{prefix}_spawn_rate'] = summary['spawn_rate']
                row_data[f'{prefix}_completion_rate'] = summary['completion_rate']
                row_data[f'{prefix}_avg_wait'] = summary['avg_wait_time']
                row_data[f'{prefix}_queue'] = summary['current_queue']
                
                total_completed += summary['total_completed']
                if summary['avg_wait_time'] > 0:
                    total_wait_time += summary['avg_wait_time']
                    wait_count += 1
            
            row_data['total_completed'] = total_completed
            row_data['avg_system_wait_time'] = total_wait_time / max(wait_count, 1)
            
            self.csv_writer.writerow(row_data)
            self.csv_file.flush()  # Garantir que os dados sejam escritos
            
        except Exception as e:
            print(f"Erro ao escrever CSV: {e}")
    
    def get_current_stats(self) -> Dict:
        """Retorna estatísticas atuais consolidadas"""
        stats = {}
        
        # Estatísticas por direção
        for direction, metrics in self.traffic_metrics.items():
            stats[direction] = metrics.get_summary()
        
        # Estatísticas do sistema
        stats['system'] = self.system_metrics.get_summary()
        
        return stats
    
    def get_performance_report(self) -> str:
        """Gera relatório de performance legível"""
        stats = self.get_current_stats()
        system = stats['system']
        
        report = []
        report.append("=== RELATÓRIO DE PERFORMANCE ===")
        report.append(f"Tempo de execução: {system['total_runtime']:.1f}s")
        report.append(f"FPS médio: {system['avg_fps']:.1f}")
        report.append(f"Frame time: {system['avg_frame_time']:.1f}ms")
        report.append(f"Uso de memória: {system['memory_usage_mb']:.1f}MB")
        report.append("")
        
        report.append("=== ESTATÍSTICAS DE TRÁFEGO ===")
        for direction in ['north', 'south', 'east', 'west']:
            if direction in stats:
                dir_stats = stats[direction]
                report.append(f"{direction.upper()}:")
                report.append(f"  Spawn rate: {dir_stats['spawn_rate']:.2f} veículos/s")
                report.append(f"  Completion rate: {dir_stats['completion_rate']:.2f} veículos/s")
                report.append(f"  Tempo médio espera: {dir_stats['avg_wait_time']:.1f}s")
                report.append(f"  Fila atual: {dir_stats['current_queue']} veículos")
                report.append("")
        
        return "\n".join(report)
    
    def save_to_csv(self):
        """Força salvamento do CSV e fecha arquivo"""
        if self.csv_writer and self.csv_file:
            try:
                self.csv_file.close()
                print(f"Métricas salvas em: {self.log_filename}")
            except Exception as e:
                print(f"Erro ao salvar CSV: {e}")
    
    def reset(self):
        """Reseta todas as métricas"""
        for metrics in self.traffic_metrics.values():
            metrics.wait_times.reset()
            metrics.travel_times.reset()
            metrics.signal_efficiency.reset()
            metrics.current_queue_length = 0
            metrics.max_queue_length = 0
            metrics.signal_cycles.clear()
        
        self.system_metrics.frame_rate.reset()
        self.system_metrics.frame_time.reset()
        self.system_metrics.draw_calls.reset()
        self.system_metrics.total_runtime = 0.0
        self.system_metrics.paused_time = 0.0
        
        self.start_time = time.time()
        self.last_csv_write = 0.0
        
        # Reiniciar logging CSV
        if self.csv_file:
            self.csv_file.close()
        self.start_csv_logging()
        
        print("Métricas resetadas")

# Funções de utilidade para análise

def analyze_csv_file(filename: str) -> Dict:
    """Analisa arquivo CSV de métricas"""
    try:
        import pandas as pd
        
        df = pd.read_csv(filename)
        
        analysis = {
            'duration': df['elapsed_time'].max(),
            'avg_fps': df['fps'].mean(),
            'min_fps': df['fps'].min(),
            'max_fps': df['fps'].max(),
            'total_vehicles': df['total_vehicles'].max(),
            'avg_wait_time': df['avg_system_wait_time'].mean(),
            'max_queue_overall': max([
                df['north_queue'].max(),
                df['south_queue'].max(),
                df['east_queue'].max(),
                df['west_queue'].max()
            ])
        }
        
        return analysis
        
    except ImportError:
        print("pandas não disponível para análise avançada")
        return {}
    except Exception as e:
        print(f"Erro ao analisar CSV: {e}")
        return {}

def generate_performance_comparison(csv_files: List[str]) -> str:
    """Gera comparação entre múltiplas execuções"""
    # Implementação básica - pode ser expandida
    report = "=== COMPARAÇÃO DE PERFORMANCE ===\n"
    
    for i, filename in enumerate(csv_files):
        analysis = analyze_csv_file(filename)
        if analysis:
            report += f"\nExecução {i+1} ({filename}):\n"
            report += f"  FPS médio: {analysis.get('avg_fps', 0):.1f}\n"
            report += f"  Tempo médio espera: {analysis.get('avg_wait_time', 0):.1f}s\n"
            report += f"  Total veículos: {analysis.get('total_vehicles', 0)}\n"
    
    return report