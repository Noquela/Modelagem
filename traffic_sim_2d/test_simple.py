#!/usr/bin/env python3
"""Teste simples para identificar problema de inicializacao"""

print("Iniciando teste de importacoes...")

try:
    import pygame
    print("OK - pygame importado com sucesso")
    
    import sys
    import time
    import random
    import math
    print("OK - Modulos basicos importados")
    
    from car import Car, Direction, DriverPersonality
    print("OK - car.py importado")
    
    from traffic_light import TrafficLightSystem
    print("OK - traffic_light.py importado")
    
    from advanced_spawn_system import AdvancedSpawnSystem
    print("OK - advanced_spawn_system.py importado")
    
    from traffic_analytics import TrafficAnalytics
    print("OK - traffic_analytics.py importado")
    
    from event_system import EventSystem
    print("OK - event_system.py importado")
    
    from config import *
    print("OK - config.py importado")
    
    print("\nTentando inicializar pygame...")
    pygame.init()
    print("OK - pygame inicializado")
    
    print("Tentando criar tela...")
    screen = pygame.display.set_mode((800, 600))  # Resolucao menor para teste
    pygame.display.set_caption("Teste")
    print("OK - Tela criada")
    
    print("Tentando inicializar sistemas...")
    traffic_lights = TrafficLightSystem()
    spawn_system = AdvancedSpawnSystem()
    analytics = TrafficAnalytics()
    event_system = EventSystem()
    print("OK - Sistemas inicializados")
    
    print("Testando loop basico...")
    clock = pygame.time.Clock()
    running = True
    frames = 0
    
    while running and frames < 60:  # So 1 segundo de teste
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
        
        screen.fill((50, 50, 50))  # Fundo cinza
        pygame.display.flip()
        clock.tick(60)
        frames += 1
    
    print(f"OK - Loop executado por {frames} frames")
    
    pygame.quit()
    print("OK - Teste completo com sucesso!")

except Exception as e:
    print(f"ERRO: {e}")
    import traceback
    traceback.print_exc()