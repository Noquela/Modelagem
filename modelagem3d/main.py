#!/usr/bin/env python3
"""
Simulador 3D de Tráfego - Ultra Performance
==========================================

Simulador avançado de cruzamento com:
- Rendering moderno OpenGL (VAO/VBO, shaders, instancing)
- Lógica de semáforos por fases com extensão adaptativa
- Suporte ultrawide (3440×1440) com 60+ FPS
- Sistema de métricas avançado com logs CSV
- HUD resolution-independent

Requisitos:
    pip install pygame PyOpenGL PyOpenGL_accelerate

Controles:
    P - Pausar/Retomar
    R - Reiniciar
    1-5 - Taxa spawn carros
    8-9 - Taxa spawn pedestres
    [/] - Ajustar minGreen
    {/} - Ajustar maxGreen
    ;/' - Ajustar yellow time
    ,/. - Ajustar allRed time
    Mouse + Drag - Orbit camera
    W/S - Zoom
    A/D - Rotate yaw
    Q/E - Height
    ESC - Sair

Autor: Sistema de Simulação de Tráfego Ultra 3D
"""

import sys
import os

# Adiciona o diretório do projeto ao path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from core.app import TrafficApp

def main():
    """Ponto de entrada principal"""
    app = None
    try:
        app = TrafficApp()
        app.run()
    except KeyboardInterrupt:
        print("\nSimulador interrompido pelo usuário")
    except Exception as e:
        print(f"Erro crítico: {e}")
        import traceback
        traceback.print_exc()
    finally:
        if app:
            app.cleanup()
        sys.exit(0)

if __name__ == "__main__":
    main()