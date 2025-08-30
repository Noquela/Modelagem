import pygame
import sys
import time
from car import Car, Direction, DriverPersonality
from traffic_light import TrafficLightSystem
from spawn_system import SpawnSystem
from config import *

class TrafficSim2D:
    def __init__(self):
        pygame.init()
        self.screen = pygame.display.set_mode((WINDOW_WIDTH, WINDOW_HEIGHT))
        pygame.display.set_caption("Traffic Simulator 2D - Complete System")
        self.clock = pygame.time.Clock()
        
        # Sistemas principais
        self.cars = []
        self.traffic_lights = TrafficLightSystem()
        self.spawn_system = SpawnSystem()
        
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
        """Desenhar a intersecção EXATA baseada nas especificações"""
        # Fundo (grama)
        self.screen.fill(COLORS['grass'])
        
        # Rua principal horizontal (duas mãos)
        main_road_y = 340  # Centro vertical da tela
        pygame.draw.rect(self.screen, COLORS['asphalt'], 
                        (0, main_road_y, WINDOW_WIDTH, MAIN_ROAD_WIDTH))
        
        # Rua que corta vertical (mão única - BAIXO→CIMA)
        cross_road_x = 540  # Centro horizontal da intersecção
        pygame.draw.rect(self.screen, COLORS['asphalt'], 
                        (cross_road_x, 0, CROSS_ROAD_WIDTH, WINDOW_HEIGHT))
        
        # Seta indicando direção da rua de mão única (baixo→cima)
        arrow_points = [
            (cross_road_x + 40, 150),  # Ponta da seta
            (cross_road_x + 30, 170),  # Base esquerda
            (cross_road_x + 50, 170),  # Base direita
        ]
        pygame.draw.polygon(self.screen, COLORS['white'], arrow_points)
        
        # Linhas divisórias da rua principal
        # Linha central
        pygame.draw.rect(self.screen, COLORS['yellow_line'], 
                        (0, main_road_y + MAIN_ROAD_WIDTH//2 - 2, WINDOW_WIDTH, 4))
        
        # Linhas das faixas (esquerda→direita: 2 faixas)
        lane1_y = main_road_y + 15  # Primeira faixa
        lane2_y = main_road_y + 45  # Segunda faixa
        
        # Linhas tracejadas entre faixas (apenas fora da intersecção)
        for x in range(0, cross_road_x - 50, 30):
            pygame.draw.rect(self.screen, COLORS['white'], (x, lane1_y + 15, 20, 2))
        for x in range(cross_road_x + CROSS_ROAD_WIDTH + 50, WINDOW_WIDTH, 30):
            pygame.draw.rect(self.screen, COLORS['white'], (x, lane1_y + 15, 20, 2))
        
        # Linhas das faixas (direita→esquerda: 2 faixas)
        lane3_y = main_road_y + 75  # Terceira faixa
        lane4_y = main_road_y + 105 # Quarta faixa
        
        for x in range(0, cross_road_x - 50, 30):
            pygame.draw.rect(self.screen, COLORS['white'], (x, lane3_y + 15, 20, 2))
        for x in range(cross_road_x + CROSS_ROAD_WIDTH + 50, WINDOW_WIDTH, 30):
            pygame.draw.rect(self.screen, COLORS['white'], (x, lane3_y + 15, 20, 2))
    
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
    
    def draw_cars(self):
        """Desenhar todos os carros"""
        for car in self.cars:
            car.draw(self.screen)
    
    def draw_ui(self):
        """Interface EXATA baseada no que desenvolvemos"""
        if not self.show_debug:
            return
        
        # Fundo semi-transparente para o debug
        debug_surface = pygame.Surface((300, 400))
        debug_surface.set_alpha(180)
        debug_surface.fill((0, 0, 0))
        self.screen.blit(debug_surface, (10, 10))
        
        y = 20
        
        # Título
        text = self.font.render("=== TRAFFIC SIMULATOR DEBUG ===", True, COLORS['white'])
        self.screen.blit(text, (20, y))
        y += 35
        
        # Tempo de simulação
        elapsed = time.time() - self.start_time
        text = self.font.render(f"Tempo: {elapsed:.1f}s", True, COLORS['white'])
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
        self.spawn_system = SpawnSystem()
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