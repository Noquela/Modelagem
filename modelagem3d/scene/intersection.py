"""
Controlador de Interseção - Lógica avançada de semáforos
======================================================

Sistema de semáforos por fases com:
- Extensão adaptativa de verde baseada em demanda
- Lógica de pedestres com botões e janelas seguras
- Intergreens e all-red para segurança
- Métricas de performance
"""

import time
import math
from enum import Enum
from typing import Dict, List, Callable, Optional
from scene.types import Pos3, Color, Colors

class SignalPhase(Enum):
    """Estados dos semáforos"""
    GREEN = "green"
    YELLOW = "yellow"
    ALL_RED = "all_red"
    
class PedPhase(Enum):
    """Estados dos semáforos de pedestres"""
    DONT_WALK = "dont_walk"
    WALK = "walk"
    CLEARANCE = "clearance"

class TrafficSignal:
    """Semáforo veicular com lógica de fases"""
    
    def __init__(self, position: Pos3, direction: str):
        self.position = position
        self.direction = direction  # 'north', 'south', 'east', 'west'
        
        # Estado atual
        self.phase = SignalPhase.ALL_RED
        self.time_in_phase = 0.0
        self.time_remaining = 0.0
        
        # Configurações de tempo (segundos)
        self.min_green = 15.0 if direction in ['north', 'south'] else 10.0
        self.max_green = 35.0 if direction in ['north', 'south'] else 25.0
        self.yellow_time = 3.0
        self.all_red_time = 1.5
        
        # Extensão de verde
        self.extension_time = 0.5  # Extensão por detecção
        self.max_extensions = 10   # Máximo de extensões
        self.extensions_used = 0
        
        # Detecção de demanda
        self.vehicles_detected = 0
        self.queue_length = 0
        self.last_detection_time = 0.0
        
        # Estatísticas
        self.total_green_time = 0.0
        self.total_vehicles_served = 0
        self.total_extensions = 0
    
    def update(self, dt: float, vehicle_queue: int, approaching_vehicles: int):
        """Atualiza o estado do semáforo"""
        self.time_in_phase += dt
        self.time_remaining -= dt
        self.queue_length = vehicle_queue
        self.vehicles_detected = approaching_vehicles
        
        # Lógica de extensão no verde
        if self.phase == SignalPhase.GREEN:
            self.total_green_time += dt
            
            # Verificar se deve estender verde
            if self._should_extend_green():
                self._extend_green()
        
        # Verificar transições de fase
        if self.time_remaining <= 0:
            self._advance_phase()
    
    def _should_extend_green(self) -> bool:
        """Verifica se deve estender o verde"""
        if self.extensions_used >= self.max_extensions:
            return False
        
        if self.time_in_phase >= self.max_green:
            return False
        
        # Estender se há fila ou veículos se aproximando
        has_demand = (self.queue_length > 0 or 
                     self.vehicles_detected > 0 or
                     time.time() - self.last_detection_time < 2.0)
        
        return has_demand and self.time_remaining <= self.extension_time
    
    def _extend_green(self):
        """Estende o tempo de verde"""
        self.time_remaining += self.extension_time
        self.extensions_used += 1
        self.total_extensions += 1
    
    def _advance_phase(self):
        """Avança para a próxima fase"""
        if self.phase == SignalPhase.GREEN:
            self._start_yellow()
        elif self.phase == SignalPhase.YELLOW:
            self._start_all_red()
        elif self.phase == SignalPhase.ALL_RED:
            # Próxima fase determinada pelo controlador principal
            pass
    
    def start_green(self):
        """Inicia fase verde"""
        self.phase = SignalPhase.GREEN
        self.time_in_phase = 0.0
        self.time_remaining = self.min_green
        self.extensions_used = 0
    
    def _start_yellow(self):
        """Inicia fase amarela"""
        self.phase = SignalPhase.YELLOW
        self.time_in_phase = 0.0
        self.time_remaining = self.yellow_time
    
    def _start_all_red(self):
        """Inicia fase de tudo vermelho"""
        self.phase = SignalPhase.ALL_RED
        self.time_in_phase = 0.0
        self.time_remaining = self.all_red_time
    
    def can_vehicles_proceed(self) -> bool:
        """Verifica se veículos podem prosseguir"""
        return self.phase == SignalPhase.GREEN
    
    def should_vehicles_stop(self) -> bool:
        """Verifica se veículos devem parar"""
        return self.phase in [SignalPhase.ALL_RED]
    
    def should_vehicles_prepare_to_stop(self) -> bool:
        """Verifica se veículos devem se preparar para parar (amarelo)"""
        return self.phase == SignalPhase.YELLOW
    
    def get_display_color(self) -> Color:
        """Retorna cor para exibição"""
        if self.phase == SignalPhase.GREEN:
            return Colors.GREEN
        elif self.phase == SignalPhase.YELLOW:
            return Colors.YELLOW
        else:
            return Colors.RED
    
    def get_time_bar_progress(self) -> float:
        """Retorna progresso da barra de tempo (0-1)"""
        total_time = 0
        
        if self.phase == SignalPhase.GREEN:
            # Para verde, usar min_green como base
            total_time = max(self.min_green, self.time_in_phase + self.time_remaining)
        elif self.phase == SignalPhase.YELLOW:
            total_time = self.yellow_time
        elif self.phase == SignalPhase.ALL_RED:
            total_time = self.all_red_time
        
        if total_time > 0:
            return max(0.0, min(1.0, self.time_remaining / total_time))
        return 0.0

class PedestrianSignal:
    """Semáforo de pedestres com sistema de chamadas"""
    
    def __init__(self, position: Pos3, crossing_direction: str):
        self.position = position
        self.crossing_direction = crossing_direction  # 'horizontal' ou 'vertical'
        
        # Estado atual
        self.phase = PedPhase.DONT_WALK
        self.time_remaining = 0.0
        
        # Configurações
        self.walk_time = 8.0
        self.clearance_time = 12.0  # Tempo para completar travessia
        
        # Sistema de chamadas
        self.call_active = False
        self.pedestrians_waiting = 0
        self.pedestrians_crossing = 0
        
        # Estatísticas
        self.total_calls = 0
        self.total_pedestrians_served = 0
    
    def update(self, dt: float, waiting_peds: int, crossing_peds: int):
        """Atualiza estado do semáforo de pedestres"""
        self.pedestrians_waiting = waiting_peds
        self.pedestrians_crossing = crossing_peds
        
        self.time_remaining -= dt
        
        if self.time_remaining <= 0:
            if self.phase == PedPhase.WALK:
                self._start_clearance()
            elif self.phase == PedPhase.CLEARANCE:
                self._start_dont_walk()
    
    def request_crossing(self):
        """Solicita travessia (botão pressionado)"""
        if self.phase == PedPhase.DONT_WALK and not self.call_active:
            self.call_active = True
            self.total_calls += 1
    
    def start_walk_phase(self):
        """Inicia fase de travessia"""
        if self.call_active:
            self.phase = PedPhase.WALK
            self.time_remaining = self.walk_time
            self.call_active = False
            self.total_pedestrians_served += self.pedestrians_waiting
    
    def _start_clearance(self):
        """Inicia fase de clearance"""
        self.phase = PedPhase.CLEARANCE
        self.time_remaining = self.clearance_time
    
    def _start_dont_walk(self):
        """Volta para não andar"""
        # Só finalizar se não há pedestres na faixa
        if self.pedestrians_crossing == 0:
            self.phase = PedPhase.DONT_WALK
            self.time_remaining = 0.0
        else:
            # Estender clearance se ainda há pedestres
            self.time_remaining = 2.0
    
    def can_pedestrians_cross(self) -> bool:
        """Verifica se pedestres podem atravessar"""
        return self.phase == PedPhase.WALK
    
    def is_clearance_phase(self) -> bool:
        """Verifica se está em clearance"""
        return self.phase == PedPhase.CLEARANCE
    
    def get_display_color(self) -> Color:
        """Cor para exibição"""
        if self.phase == PedPhase.WALK:
            return Colors.GREEN
        else:
            return Colors.RED

class IntersectionController:
    """Controlador principal da interseção"""
    
    def __init__(self):
        # Semáforos veiculares (4 direções x 2 faixas cada)
        self.vehicle_signals = {
            'north_1': TrafficSignal(Pos3(-3.5, 12, 0), 'north'),
            'north_2': TrafficSignal(Pos3(0, 12, 0), 'north'),
            'south_1': TrafficSignal(Pos3(3.5, -12, 0), 'south'),
            'south_2': TrafficSignal(Pos3(0, -12, 0), 'south'),
            'east_1': TrafficSignal(Pos3(12, -3.5, 0), 'east'),
            'east_2': TrafficSignal(Pos3(12, 0, 0), 'east'),
            'west_1': TrafficSignal(Pos3(-12, 3.5, 0), 'west'),
            'west_2': TrafficSignal(Pos3(-12, 0, 0), 'west'),
        }
        
        # Semáforos de pedestres (4 travessias)
        self.pedestrian_signals = {
            'north_crossing': PedestrianSignal(Pos3(-8, 8, 0), 'horizontal'),
            'south_crossing': PedestrianSignal(Pos3(8, -8, 0), 'horizontal'),
            'east_crossing': PedestrianSignal(Pos3(8, 8, 0), 'vertical'),
            'west_crossing': PedestrianSignal(Pos3(-8, -8, 0), 'vertical'),
        }
        
        # Controle de fases
        self.current_vehicle_phase = 'north_south'  # ou 'east_west'
        self.phase_change_pending = False
        self.all_red_complete = False
        
        # Métricas callback
        self.metrics_callback = None
        
        # Inicializar com fase norte-sul
        self._start_north_south_green()
        
        print("Controlador de interseção inicializado")
    
    def update(self, dt: float):
        """Atualiza todos os semáforos e lógica de fases"""
        # Atualizar semáforos veiculares
        for signal_id, signal in self.vehicle_signals.items():
            # Simular dados de tráfego (será fornecido pelo TrafficManager)
            queue_length = 0  # Placeholder
            approaching = 0   # Placeholder
            signal.update(dt, queue_length, approaching)
        
        # Atualizar semáforos de pedestres
        for ped_signal in self.pedestrian_signals.values():
            waiting = 0  # Placeholder
            crossing = 0  # Placeholder
            ped_signal.update(dt, waiting, crossing)
        
        # Verificar se precisa mudar de fase veicular
        self._check_phase_transitions()
        
        # Processar chamadas de pedestres
        self._process_pedestrian_calls()
    
    def _check_phase_transitions(self):
        """Verifica e executa transições entre fases veiculares"""
        current_signals = self._get_current_phase_signals()
        
        # Verificar se todos os sinais da fase atual estão em all-red
        all_red = all(signal.phase == SignalPhase.ALL_RED for signal in current_signals)
        
        if all_red and not self.phase_change_pending:
            # Iniciar próxima fase
            if self.current_vehicle_phase == 'north_south':
                self._start_east_west_green()
            else:
                self._start_north_south_green()
            
            self.phase_change_pending = True
        
        elif self.phase_change_pending and all_red:
            # Completar transição de fase
            self.phase_change_pending = False
    
    def _get_current_phase_signals(self) -> List[TrafficSignal]:
        """Retorna sinais da fase atual"""
        if self.current_vehicle_phase == 'north_south':
            return [self.vehicle_signals[key] for key in 
                   ['north_1', 'north_2', 'south_1', 'south_2']]
        else:
            return [self.vehicle_signals[key] for key in 
                   ['east_1', 'east_2', 'west_1', 'west_2']]
    
    def _start_north_south_green(self):
        """Inicia fase verde norte-sul"""
        self.current_vehicle_phase = 'north_south'
        
        # Verde para norte e sul
        for key in ['north_1', 'north_2', 'south_1', 'south_2']:
            self.vehicle_signals[key].start_green()
        
        # Vermelho para leste e oeste
        for key in ['east_1', 'east_2', 'west_1', 'west_2']:
            self.vehicle_signals[key]._start_all_red()
    
    def _start_east_west_green(self):
        """Inicia fase verde leste-oeste"""
        self.current_vehicle_phase = 'east_west'
        
        # Verde para leste e oeste
        for key in ['east_1', 'east_2', 'west_1', 'west_2']:
            self.vehicle_signals[key].start_green()
        
        # Vermelho para norte e sul
        for key in ['north_1', 'north_2', 'south_1', 'south_2']:
            self.vehicle_signals[key]._start_all_red()
    
    def _process_pedestrian_calls(self):
        """Processa chamadas de pedestres"""
        for crossing_id, ped_signal in self.pedestrian_signals.items():
            if ped_signal.call_active and self._can_serve_pedestrian_call(crossing_id):
                ped_signal.start_walk_phase()
    
    def _can_serve_pedestrian_call(self, crossing_id: str) -> bool:
        """Verifica se pode atender chamada de pedestre"""
        # Lógica simplificada: só permitir durante all-red das fases conflitantes
        if crossing_id in ['north_crossing', 'south_crossing']:
            # Travessia horizontal - verificar se norte-sul está em all-red
            conflicting_signals = ['north_1', 'north_2', 'south_1', 'south_2']
        else:
            # Travessia vertical - verificar se leste-oeste está em all-red
            conflicting_signals = ['east_1', 'east_2', 'west_1', 'west_2']
        
        return all(self.vehicle_signals[sig].phase == SignalPhase.ALL_RED 
                  for sig in conflicting_signals)
    
    def set_metrics_callback(self, callback: Callable):
        """Define callback para métricas"""
        self.metrics_callback = callback
    
    def get_signal_states(self) -> Dict:
        """Retorna estados de todos os semáforos"""
        states = {}
        
        for signal_id, signal in self.vehicle_signals.items():
            states[signal_id] = {
                'phase': signal.phase.value,
                'time_remaining': signal.time_remaining,
                'progress': signal.get_time_bar_progress(),
                'color': signal.get_display_color().as_tuple(),
                'queue_length': signal.queue_length,
                'extensions_used': signal.extensions_used
            }
        
        for ped_id, ped_signal in self.pedestrian_signals.items():
            states[ped_id] = {
                'phase': ped_signal.phase.value,
                'call_active': ped_signal.call_active,
                'color': ped_signal.get_display_color().as_tuple(),
                'pedestrians_waiting': ped_signal.pedestrians_waiting
            }
        
        return states
    
    def get_timing_config(self) -> Dict:
        """Retorna configurações de timing"""
        # Usar primeiro sinal de cada direção como referência
        north = self.vehicle_signals['north_1']
        east = self.vehicle_signals['east_1']
        
        return {
            'main_min_green': north.min_green,
            'main_max_green': north.max_green,
            'side_min_green': east.min_green,
            'side_max_green': east.max_green,
            'yellow_time': north.yellow_time,
            'all_red_time': north.all_red_time
        }
    
    def adjust_min_green(self, delta: float):
        """Ajusta tempo mínimo de verde"""
        for signal in self.vehicle_signals.values():
            signal.min_green = max(5.0, signal.min_green + delta)
        print(f"Min green: Principal={self.vehicle_signals['north_1'].min_green:.1f}s, "
              f"Secundária={self.vehicle_signals['east_1'].min_green:.1f}s")
    
    def adjust_max_green(self, delta: float):
        """Ajusta tempo máximo de verde"""
        for signal in self.vehicle_signals.values():
            signal.max_green = max(signal.min_green + 5, signal.max_green + delta)
        print(f"Max green: Principal={self.vehicle_signals['north_1'].max_green:.1f}s, "
              f"Secundária={self.vehicle_signals['east_1'].max_green:.1f}s")
    
    def adjust_yellow_time(self, delta: float):
        """Ajusta tempo de amarelo"""
        for signal in self.vehicle_signals.values():
            signal.yellow_time = max(2.0, min(5.0, signal.yellow_time + delta))
        print(f"Yellow time: {self.vehicle_signals['north_1'].yellow_time:.1f}s")
    
    def adjust_all_red_time(self, delta: float):
        """Ajusta tempo de tudo vermelho"""
        for signal in self.vehicle_signals.values():
            signal.all_red_time = max(0.5, min(4.0, signal.all_red_time + delta))
        print(f"All red time: {self.vehicle_signals['north_1'].all_red_time:.1f}s")
    
    def reset(self):
        """Reinicia o controlador"""
        # Resetar todos os sinais
        for signal in self.vehicle_signals.values():
            signal.extensions_used = 0
            signal.total_green_time = 0.0
            signal.total_vehicles_served = 0
            signal.total_extensions = 0
        
        for ped_signal in self.pedestrian_signals.values():
            ped_signal.call_active = False
            ped_signal.phase = PedPhase.DONT_WALK
            ped_signal.total_calls = 0
            ped_signal.total_pedestrians_served = 0
        
        # Reiniciar com norte-sul verde
        self.current_vehicle_phase = 'north_south'
        self.phase_change_pending = False
        self._start_north_south_green()
        
        print("Controlador de interseção reiniciado")
    
    def render(self, renderer):
        """Renderiza todos os semáforos"""
        # Renderizar semáforos veiculares
        for signal in self.vehicle_signals.values():
            self._render_traffic_signal(signal, renderer)
        
        # Renderizar semáforos de pedestres
        for ped_signal in self.pedestrian_signals.values():
            self._render_pedestrian_signal(ped_signal, renderer)
    
    def _render_traffic_signal(self, signal: TrafficSignal, renderer):
        """Renderiza um semáforo veicular"""
        pos = signal.position
        
        # Poste do semáforo
        renderer.draw_mesh('cylinder', 
                         transform_pos=Pos3(pos.x, pos.y, 2.0),
                         transform_scale=Pos3(0.2, 0.2, 4.0),
                         color=Colors.METAL.as_tuple())
        
        # Caixa do semáforo
        renderer.draw_mesh('cube',
                         transform_pos=Pos3(pos.x, pos.y, 4.5),
                         transform_scale=Pos3(0.8, 0.6, 1.5),
                         color=Colors.METAL.as_tuple())
        
        # Luzes do semáforo
        light_colors = [Colors.RED, Colors.YELLOW, Colors.GREEN]
        current_color = signal.get_display_color()
        
        for i, base_color in enumerate(light_colors):
            light_pos = Pos3(pos.x, pos.y - 0.35, 4.5 + 0.4 - i * 0.4)
            
            # Usar cor atual se for a luz ativa, senão cor escura
            if base_color.as_tuple() == current_color.as_tuple():
                light_color = current_color.as_tuple()
            else:
                light_color = (0.2, 0.2, 0.2)  # Cor escura
            
            renderer.draw_mesh('cylinder',
                             transform_pos=light_pos,
                             transform_scale=Pos3(0.15, 0.15, 0.1),
                             color=light_color)
        
        # Indicador de tempo (barra 3D)
        if signal.time_remaining > 0:
            progress = signal.get_time_bar_progress()
            bar_pos = Pos3(pos.x, pos.y, 5.8)
            
            # Fundo da barra
            renderer.draw_mesh('cube',
                             transform_pos=bar_pos,
                             transform_scale=Pos3(2.0, 0.3, 0.2),
                             color=(0.3, 0.3, 0.3))
            
            # Preenchimento da barra
            if progress > 0:
                fill_width = 2.0 * progress
                fill_pos = Pos3(pos.x - (2.0 - fill_width) * 0.5, pos.y, bar_pos.z + 0.05)
                
                renderer.draw_mesh('cube',
                               transform_pos=fill_pos,
                               transform_scale=Pos3(fill_width, 0.25, 0.25),
                               color=current_color.as_tuple())
    
    def _render_pedestrian_signal(self, ped_signal: PedestrianSignal, renderer):
        """Renderiza um semáforo de pedestres"""
        pos = ped_signal.position
        
        # Poste
        renderer.draw_mesh('cylinder',
                         transform_pos=Pos3(pos.x, pos.y, 1.25),
                         transform_scale=Pos3(0.1, 0.1, 2.5),
                         color=Colors.METAL.as_tuple())
        
        # Caixa do semáforo
        renderer.draw_mesh('cube',
                         transform_pos=Pos3(pos.x, pos.y, 2.0),
                         transform_scale=Pos3(0.4, 0.3, 0.6),
                         color=Colors.METAL.as_tuple())
        
        # Luz
        light_color = ped_signal.get_display_color()
        renderer.draw_mesh('cylinder',
                         transform_pos=Pos3(pos.x, pos.y - 0.2, 2.0),
                         transform_scale=Pos3(0.1, 0.1, 0.1),
                         color=light_color.as_tuple())
        
        # Botão
        button_color = Colors.YELLOW if ped_signal.call_active else Colors.CONCRETE
        renderer.draw_mesh('cylinder',
                         transform_pos=Pos3(pos.x, pos.y, 1.5),
                         transform_scale=Pos3(0.05, 0.05, 0.05),
                         color=button_color.as_tuple())