import pygame
import sys
import time
from car import Car, Direction, DriverPersonality
from traffic_light import TrafficLightSystem
from advanced_spawn_system import AdvancedSpawnSystem
from traffic_analytics import TrafficAnalytics
from event_system import EventSystem
from config import *

class TrafficSim2D:
    def __init__(self):
        pygame.init()
        self.screen = pygame.display.set_mode((WINDOW_WIDTH, WINDOW_HEIGHT))
        pygame.display.set_caption("Traffic Simulator 2D - Sistema Completo Otimizado")
        self.clock = pygame.time.Clock()
        
        # Cache de superfícies para otimização
        self._intersection_surface = None
        self._intersection_dirty = True
        
        # Sistemas principais
        self.cars = []
        self.traffic_lights = TrafficLightSystem()
        self.spawn_system = AdvancedSpawnSystem()
        self.analytics = TrafficAnalytics()
        self.event_system = EventSystem()
        
        # Estado da simulação
        self.running = True
        self.paused = False
        self.show_debug = True
        
        # Estatísticas
        self.start_time = time.time()
        self.total_cars_spawned = 0
        self.total_cars_despawned = 0
        
        # Fonte para UI
        self.font = pygame.font.Font(None, 24)
        self.small_font = pygame.font.Font(None, 18)
        
        print("=== TRAFFIC SIMULATOR 2D - SISTEMA COMPLETO ===")
        print("Controles:")
        print("  SPACE: Pausar/Continuar")
        print("  F1: Toggle Debug Info")
        print("  ESC: Sair")
        print("  R: Reset simulação")
        print()
    
    def draw_intersection(self):
        """Intersecção otimizada com cache de superfície"""
        
        # Usar cache se disponível
        if self._intersection_surface is None or self._intersection_dirty:
            self._create_intersection_surface()
            self._intersection_dirty = False
        
        # Blit cached surface
        self.screen.blit(self._intersection_surface, (0, 0))
    
    def _create_intersection_surface(self):
        """Criar superfície cacheable da intersecção"""
        self._intersection_surface = pygame.Surface((WINDOW_WIDTH, WINDOW_HEIGHT))
        surface = self._intersection_surface
        
        # Fundo grama
        surface.fill(COLORS['grass'])
        
        # Posições centralizadas para ultrawide
        center_x = WINDOW_WIDTH // 2  # 1720 pixels do centro
        center_y = WINDOW_HEIGHT // 2  # 720 pixels do centro
        
        # Rua principal horizontal - MAIS LARGA
        road_y = center_y - 80  # Centralizar verticalmente
        main_road_rect = pygame.Rect(0, road_y, WINDOW_WIDTH, 160)  # 160px = 4 faixas de 40px
        pygame.draw.rect(surface, COLORS['asphalt'], main_road_rect)
        
        # Rua que corta vertical - mão única (centralizada)
        cross_road_x = center_x - 40  # Centralizar horizontalmente
        cross_road_rect = pygame.Rect(cross_road_x, 0, 80, WINDOW_HEIGHT)  # 80px = 2 faixas de 40px
        pygame.draw.rect(surface, COLORS['asphalt'], cross_road_rect)
        
        # FAIXAS INDIVIDUAIS bem marcadas
        
        # Rua principal - sentido esquerda→direita (2 faixas)
        for i in range(2):
            lane_y = road_y + 10 + (i * 35)  # Relativo à nova posição
            self._draw_lane_marking_on_surface(surface, 0, lane_y, WINDOW_WIDTH, 'horizontal', cross_road_x, road_y)
        
        # Rua principal - sentido direita→esquerda (2 faixas)
        for i in range(2):
            lane_y = road_y + 90 + (i * 35)  # Relativo à nova posição
            self._draw_lane_marking_on_surface(surface, 0, lane_y, WINDOW_WIDTH, 'horizontal', cross_road_x, road_y)
        
        # Linha divisória central (amarela sólida) - parar antes da intersecção
        # Antes da intersecção
        pygame.draw.rect(surface, COLORS['yellow_line'], 
                        (0, road_y + 75, cross_road_x - 50, 4))
        # Depois da intersecção
        pygame.draw.rect(surface, COLORS['yellow_line'], 
                        (cross_road_x + 80 + 50, road_y + 75, WINDOW_WIDTH - (cross_road_x + 80 + 50), 4))
        
        # Rua de mão única - 1 faixa centralizada
        lane_x = cross_road_x + 20  # Centralizada na rua vertical
        self._draw_lane_marking_on_surface(surface, lane_x, 0, WINDOW_HEIGHT, 'vertical', cross_road_x, road_y)
        
        # Faixas de pedestre na intersecção
        self._draw_crosswalks_on_surface(surface, cross_road_x, road_y)
    
    def _draw_lane_marking_on_surface(self, surface, start_x, start_y, length, orientation, cross_road_x=None, road_y=None):
        """Desenhar marcação de faixa na superfície cached - CORRIGIDO para não sobrepor intersecção"""
        # Calcular limites da intersecção se não fornecidos
        if cross_road_x is None:
            cross_road_x = WINDOW_WIDTH // 2 - 40
        if road_y is None:
            road_y = WINDOW_HEIGHT // 2 - 80
            
        if orientation == 'horizontal':
            # Antes da intersecção (parar 50px antes)
            intersection_start = cross_road_x - 50
            for x in range(start_x, min(intersection_start, start_x + length), 30):
                if x + 20 < intersection_start:  # Só desenhar se não vai sobrepor
                    pygame.draw.rect(surface, COLORS['white'], (x, start_y, 20, 2))
            
            # Depois da intersecção (começar 50px depois)
            intersection_end = cross_road_x + 80 + 50
            for x in range(max(intersection_end, start_x), start_x + length, 30):
                if x < start_x + length:
                    pygame.draw.rect(surface, COLORS['white'], (x, start_y, 20, 2))
        else:
            # Antes da intersecção (parar 50px antes) 
            intersection_start = road_y - 50
            for y in range(start_y, min(intersection_start, start_y + length), 30):
                if y + 20 < intersection_start:  # Só desenhar se não vai sobrepor
                    pygame.draw.rect(surface, COLORS['white'], (start_x, y, 2, 20))
            
            # Depois da intersecção (começar 50px depois)
            intersection_end = road_y + 160 + 50
            for y in range(max(intersection_end, start_y), start_y + length, 30):
                if y < start_y + length:
                    pygame.draw.rect(surface, COLORS['white'], (start_x, y, 2, 20))
    
    def _draw_crosswalks_on_surface(self, surface, cross_road_x, road_y):
        """Desenhar faixas de pedestre na superfície cached"""
        # Faixa horizontal (cruzando a rua vertical)
        for i in range(cross_road_x + 5, cross_road_x + 75, 8):
            pygame.draw.rect(surface, COLORS['white'], (i, road_y - 15, 4, 170))
        
        # Faixa vertical (cruzando a rua horizontal)  
        for i in range(road_y + 5, road_y + 155, 8):
            pygame.draw.rect(surface, COLORS['white'], (cross_road_x - 15, i, 160, 4))
    
    
    def update_simulation(self, dt):
        """Atualizar toda a simulação"""
        if self.paused:
            return
        
        # Atualizar semáforos
        self.traffic_lights.update()
        
        # Spawnar novos carros
        new_cars = self.spawn_system.update(self.cars)
        self.cars.extend(new_cars)
        self.total_cars_spawned += len(new_cars)
        
        # Atualizar carros
        for car in self.cars[:]:  # Cópia para poder remover
            car.update(self.cars, self.traffic_lights)
            
            # Remover carros que saíram da tela
            if car.is_out_of_bounds():
                self.cars.remove(car)
                self.total_cars_despawned += 1
        
        # Atualizar analytics
        self.analytics.update(self.cars, self.traffic_lights)
        
        # Atualizar eventos
        self.event_system.update(self.cars, self.traffic_lights)
    
    def draw_cars(self):
        """Desenhar carros otimizado por camadas (z-order)"""
        # Separar carros por layers para renderização correta
        cars_by_layer = self._sort_cars_by_render_order()
        
        for layer in cars_by_layer:
            for car in layer:
                car.draw(self.screen)
    
    def _sort_cars_by_render_order(self):
        """Separar carros em camadas de renderização para otimizar z-order"""
        # Carros indo para baixo (rua vertical) ficam atrás
        # Carros da rua horizontal ficam na frente
        
        vertical_cars = [car for car in self.cars if car.direction.name == 'TOP_TO_BOTTOM']
        horizontal_cars = [car for car in self.cars if car.direction.name in ['LEFT_TO_RIGHT', 'RIGHT_TO_LEFT']]
        
        # Ordenar horizontal cars por Y para sobreposição correta
        horizontal_cars.sort(key=lambda c: c.y)
        
        return [vertical_cars, horizontal_cars]
    
    def draw_ui(self):
        """Interface EXATA baseada no que desenvolvemos"""
        if not self.show_debug:
            return
        
        # Fundo semi-transparente para o debug (expandido para filas)
        debug_surface = pygame.Surface((340, 550))
        debug_surface.set_alpha(180)
        debug_surface.fill((0, 0, 0))
        self.screen.blit(debug_surface, (10, 10))
        
        y = 20
        
        # Título
        text = self.font.render("=== TRAFFIC SIMULATOR DEBUG ===", True, COLORS['white'])
        self.screen.blit(text, (20, y))
        y += 35
        
        # Tempo de simulação e FPS
        elapsed = time.time() - self.start_time
        fps = self.clock.get_fps()
        fps_color = COLORS['green'] if fps >= 55 else COLORS['yellow'] if fps >= 40 else COLORS['red']
        
        text = self.font.render(f"Tempo: {elapsed:.1f}s", True, COLORS['white'])
        self.screen.blit(text, (20, y))
        y += 20
        
        text = self.small_font.render(f"FPS: {fps:.1f}", True, fps_color)
        self.screen.blit(text, (20, y))
        y += 25
        
        # Contador de carros
        text = self.font.render(f"Carros na tela: {len(self.cars)}", True, COLORS['white'])
        self.screen.blit(text, (20, y))
        y += 20
        
        text = self.small_font.render(f"Spawnados: {self.total_cars_spawned}", True, COLORS['white'])
        self.screen.blit(text, (20, y))
        y += 15
        
        text = self.small_font.render(f"Despawnados: {self.total_cars_despawned}", True, COLORS['white'])
        self.screen.blit(text, (20, y))
        y += 25
        
        # Estado dos semáforos
        debug_info = self.traffic_lights.get_debug_info()
        
        text = self.font.render("=== SEMÁFOROS ===", True, COLORS['white'])
        self.screen.blit(text, (20, y))
        y += 25
        
        main_state = debug_info['main_road_state'].upper()
        main_color = COLORS['green'] if main_state == "GREEN" else \
                    COLORS['yellow'] if main_state == "YELLOW" else COLORS['red']
        text = self.small_font.render(f"Rua Principal: {main_state}", True, main_color)
        self.screen.blit(text, (20, y))
        y += 20
        
        cross_state = debug_info['cross_road_state'].upper()
        cross_color = COLORS['green'] if cross_state == "GREEN" else \
                     COLORS['yellow'] if cross_state == "YELLOW" else COLORS['red']
        text = self.small_font.render(f"Rua que Corta: {cross_state}", True, cross_color)
        self.screen.blit(text, (20, y))
        y += 20
        
        progress = debug_info['cycle_progress'] * 100
        text = self.small_font.render(f"Progresso do Ciclo: {progress:.1f}%", True, COLORS['white'])
        self.screen.blit(text, (20, y))
        y += 25
        
        # Estatísticas por personalidade
        text = self.font.render("=== PERSONALIDADES ===", True, COLORS['white'])
        self.screen.blit(text, (20, y))
        y += 25
        
        personalities = {}
        for car in self.cars:
            p = car.personality.value
            personalities[p] = personalities.get(p, 0) + 1
        
        personality_colors = {
            'aggressive': COLORS['red'],
            'normal': COLORS['green'],
            'conservative': COLORS['blue'],
            'elderly': COLORS['yellow']
        }
        
        for personality in ['aggressive', 'normal', 'conservative', 'elderly']:
            count = personalities.get(personality, 0)
            color = personality_colors.get(personality, COLORS['white'])
            text = self.small_font.render(f"{personality.title()}: {count}", True, color)
            self.screen.blit(text, (20, y))
            y += 18
        
        # === ANALYTICS AVANÇADOS ===
        y += 10
        text = self.font.render("=== ANALYTICS AVANÇADOS ===", True, COLORS['white'])
        self.screen.blit(text, (20, y))
        y += 25
        
        # Estatísticas do sistema de analytics
        analytics_report = self.analytics.get_detailed_report()
        
        # Throughput
        text = self.small_font.render(f"Throughput Total: {analytics_report['total_crossings']}", True, COLORS['white'])
        self.screen.blit(text, (20, y))
        y += 18
        
        # Velocidade média
        text = self.small_font.render(f"Velocidade Média: {analytics_report['average_speed']:.1f}", True, COLORS['white'])
        self.screen.blit(text, (20, y))
        y += 18
        
        # Congestionamento
        congestion_color = COLORS['green'] if analytics_report['current_congestion'] < 30 else \
                          COLORS['yellow'] if analytics_report['current_congestion'] < 60 else COLORS['red']
        text = self.small_font.render(f"Congestionamento: {analytics_report['current_congestion']:.0f}%", True, congestion_color)
        self.screen.blit(text, (20, y))
        y += 18
        
        # Eficiência
        efficiency_color = COLORS['green'] if analytics_report['efficiency_rating'] > 80 else \
                          COLORS['yellow'] if analytics_report['efficiency_rating'] > 60 else COLORS['red']
        text = self.small_font.render(f"Eficiência: {analytics_report['efficiency_rating']:.0f}%", True, efficiency_color)
        self.screen.blit(text, (20, y))
        y += 18
        
        # Quase-colisões
        if analytics_report['near_misses'] > 0:
            text = self.small_font.render(f"Quase-colisões: {analytics_report['near_misses']}", True, COLORS['red'])
            self.screen.blit(text, (20, y))
            y += 18
        
        # Status do rush hour
        if hasattr(self.spawn_system, 'rush_hour_active') and self.spawn_system.rush_hour_active:
            text = self.small_font.render("🚗 RUSH HOUR ATIVO", True, COLORS['yellow'])
            self.screen.blit(text, (20, y))
            y += 18
        
        # Na intersecção
        text = self.small_font.render(f"Na Intersecção: {analytics_report.get('cars_in_intersection', 0)}", True, COLORS['white'])
        self.screen.blit(text, (20, y))
        y += 18
        
        # === SISTEMA DE FILAS ===
        text = self.font.render("=== FILAS ===", True, COLORS['white'])
        self.screen.blit(text, (20, y))
        y += 20
        
        # Contar carros parados por direção
        stopped_cars = {
            'LEFT_TO_RIGHT': len([car for car in self.cars 
                                if car.direction.name == 'LEFT_TO_RIGHT' and car.current_speed < 0.1]),
            'RIGHT_TO_LEFT': len([car for car in self.cars 
                                if car.direction.name == 'RIGHT_TO_LEFT' and car.current_speed < 0.1]),
            'TOP_TO_BOTTOM': len([car for car in self.cars 
                                if car.direction.name == 'TOP_TO_BOTTOM' and car.current_speed < 0.1])
        }
        
        text = self.small_font.render(f"Fila Esq→Dir: {stopped_cars['LEFT_TO_RIGHT']}", True, COLORS['yellow'])
        self.screen.blit(text, (20, y))
        y += 15
        
        text = self.small_font.render(f"Fila Dir→Esq: {stopped_cars['RIGHT_TO_LEFT']}", True, COLORS['yellow'])
        self.screen.blit(text, (20, y))
        y += 15
        
        text = self.small_font.render(f"Fila Vertical: {stopped_cars['TOP_TO_BOTTOM']}", True, COLORS['yellow'])
        self.screen.blit(text, (20, y))
        y += 20
        
        # === GRÁFICO DE THROUGHPUT ===
        graph_rect = pygame.Rect(WINDOW_WIDTH - 220, 20, 200, 120)
        self.analytics.draw_throughput_graph(self.screen, graph_rect)
        
        # === NOTIFICAÇÕES DE EVENTOS ===
        self.event_system.draw_notifications(self.screen, self.font)
        
        # Estado de pausa
        if self.paused:
            pause_text = self.font.render("*** PAUSADO ***", True, COLORS['yellow'])
            self.screen.blit(pause_text, (WINDOW_WIDTH // 2 - 80, 50))
    
    def handle_events(self):
        """Processar eventos"""
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return False
            
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    return False
                elif event.key == pygame.K_SPACE:
                    self.paused = not self.paused
                    print(f"Simulação {'pausada' if self.paused else 'retomada'}")
                elif event.key == pygame.K_F1:
                    self.show_debug = not self.show_debug
                    print(f"Debug info {'habilitado' if self.show_debug else 'desabilitado'}")
                elif event.key == pygame.K_r:
                    self._reset_simulation()
                    print("Simulação reiniciada")
        
        return True
    
    def _reset_simulation(self):
        """Reiniciar simulação"""
        self.cars.clear()
        self.spawn_system = AdvancedSpawnSystem()
        self.traffic_lights = TrafficLightSystem()
        self.start_time = time.time()
        self.total_cars_spawned = 0
        self.total_cars_despawned = 0
    
    def run(self):
        """Loop principal"""
        print("Iniciando simulação...")
        
        while self.running:
            dt = self.clock.tick(60) / 1000.0  # 60 FPS
            
            # Processar eventos
            if not self.handle_events():
                break
            
            # Atualizar simulação
            self.update_simulation(dt)
            
            # Renderizar
            self.draw_intersection()
            self.traffic_lights.draw(self.screen)
            self.draw_cars()
            self.draw_ui()
            
            pygame.display.flip()
        
        # Estatísticas finais
        elapsed = time.time() - self.start_time
        print(f"\n=== ESTATÍSTICAS FINAIS ===")
        print(f"Tempo total: {elapsed:.1f}s")
        print(f"Carros spawnados: {self.total_cars_spawned}")
        print(f"Carros despawnados: {self.total_cars_despawned}")
        print(f"Taxa média de spawn: {self.total_cars_spawned/max(elapsed, 1):.2f} carros/s")
        
        pygame.quit()
        sys.exit()

if __name__ == "__main__":
    sim = TrafficSim2D()
    sim.run()