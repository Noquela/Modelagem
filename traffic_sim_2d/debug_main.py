#!/usr/bin/env python3
"""Debug version do main.py para identificar problema"""

import pygame
import sys
import time
from config import *

class TrafficSim2DDebug:
    def __init__(self):
        pygame.init()
        self.screen = pygame.display.set_mode((WINDOW_WIDTH, WINDOW_HEIGHT))
        pygame.display.set_caption("Traffic Simulator 2D - Debug")
        self.clock = pygame.time.Clock()
        self.running = True
        self.frame_count = 0
        
    def handle_events(self):
        """Processar eventos - versao debug"""
        for event in pygame.event.get():
            print(f"Evento recebido: {event.type}")
            if event.type == pygame.QUIT:
                print("Evento QUIT recebido")
                return False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    print("Tecla ESC pressionada")
                    return False
        return True
    
    def run(self):
        """Loop principal debug"""
        print("Iniciando simulacao debug...")
        start_time = time.time()
        
        while self.running:
            self.frame_count += 1
            dt = self.clock.tick(60) / 1000.0
            
            # Log a cada 60 frames (1 segundo)
            if self.frame_count % 60 == 0:
                elapsed = time.time() - start_time
                print(f"Frame {self.frame_count}, Elapsed: {elapsed:.1f}s")
            
            # Processar eventos
            continue_running = self.handle_events()
            if not continue_running:
                print("handle_events() retornou False, saindo do loop")
                break
            
            # Renderizar simples
            self.screen.fill((50, 50, 50))  # Fundo cinza
            
            # Desenhar um circulo no centro para mostrar que está funcionando
            center_x = WINDOW_WIDTH // 2
            center_y = WINDOW_HEIGHT // 2
            pygame.draw.circle(self.screen, (255, 0, 0), (center_x, center_y), 50)
            
            pygame.display.flip()
            
            # Sair após 5 segundos para teste
            if time.time() - start_time > 5:
                print("Tempo limite de 5 segundos atingido")
                break
        
        print(f"Loop finalizado após {self.frame_count} frames")
        pygame.quit()

if __name__ == "__main__":
    sim = TrafficSim2DDebug()
    sim.run()