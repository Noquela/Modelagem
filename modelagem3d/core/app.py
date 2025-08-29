"""
Aplicação principal - Loop, init Pygame/OpenGL, resize, input
==========================================================

Gerencia a janela, eventos, timing e coordena todos os sistemas.
Suporte para qualquer resolução incluindo ultrawide 3440×1440.
"""

import pygame
import sys
import time
from OpenGL.GL import *
from OpenGL.GLU import *

from core.camera import Camera3D
from core.glutils import GLUtils
from core.hud import HUD
from scene.renderer import Renderer
from scene.world import World
from scene.intersection import IntersectionController
from scene.traffic import TrafficManager
from scene.metrics import MetricsCollector

class TrafficApp:
    """Aplicação principal do simulador 3D"""
    
    def __init__(self, width=1920, height=1080, scale_factor=1.0):
        self.width = int(width * scale_factor)
        self.height = int(height * scale_factor)
        self.scale_factor = scale_factor
        
        # Estado da aplicação
        self.running = True
        self.paused = False
        self.show_debug = False
        
        # Timing
        self.clock = pygame.time.Clock()
        self.target_fps = 60
        self.delta_time = 0.0
        self.frame_count = 0
        self.last_fps_update = 0
        self.current_fps = 0
        
        # Input state
        self.keys_pressed = set()
        self.mouse_pressed = False
        self.last_mouse_pos = (0, 0)
        
        # Inicializar sistemas
        self._init_pygame()
        self._init_opengl()
        self._init_systems()
        
        print(f"Simulador 3D iniciado - Resolução: {self.width}×{self.height}")
        print("Controles: P=Pausa, R=Reset, Mouse=Câmera, 1-5=Carros, 8-9=Pedestres")
    
    def _init_pygame(self):
        """Inicializa Pygame com OpenGL"""
        pygame.init()
        
        # Configurar display com OpenGL
        flags = pygame.DOUBLEBUF | pygame.OPENGL | pygame.RESIZABLE
        self.screen = pygame.display.set_mode((self.width, self.height), flags)
        pygame.display.set_caption("Simulador 3D de Tráfego - Ultra Performance")
        
        # Configurar mouse para controle de câmera
        pygame.mouse.set_visible(True)
    
    def _init_opengl(self):
        """Configura OpenGL para performance e qualidade"""
        # Habilitar funcionalidades essenciais
        glEnable(GL_DEPTH_TEST)
        glDepthFunc(GL_LEQUAL)
        glEnable(GL_CULL_FACE)
        glCullFace(GL_BACK)
        glFrontFace(GL_CCW)
        
        # Blending para transparência (HUD)
        glEnable(GL_BLEND)
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
        
        # Configurar viewport e projeção
        self._setup_viewport()
        
        # Cor de fundo (céu azul)
        glClearColor(0.5, 0.7, 1.0, 1.0)
        
        # Configurar iluminação básica se shaders falharem
        self._setup_fixed_pipeline_lighting()
    
    def _setup_viewport(self):
        """Configura viewport e matriz de projeção"""
        glViewport(0, 0, self.width, self.height)
        
        # Configurar matriz de projeção
        glMatrixMode(GL_PROJECTION)
        glLoadIdentity()
        
        # Perspectiva com campo de visão ajustável
        aspect_ratio = self.width / self.height
        fov = 60.0
        near = 0.5
        far = 800.0
        
        gluPerspective(fov, aspect_ratio, near, far)
        
        # Voltar para modelview
        glMatrixMode(GL_MODELVIEW)
    
    def _setup_fixed_pipeline_lighting(self):
        """Configura iluminação do pipeline fixo como fallback"""
        glEnable(GL_LIGHTING)
        glEnable(GL_LIGHT0)
        
        # Luz ambiente
        ambient = [0.3, 0.3, 0.3, 1.0]
        glLightfv(GL_LIGHT0, GL_AMBIENT, ambient)
        
        # Luz difusa (sol)
        diffuse = [0.8, 0.8, 0.7, 1.0]
        glLightfv(GL_LIGHT0, GL_DIFFUSE, diffuse)
        
        # Posição da luz
        position = [50.0, 50.0, 100.0, 1.0]
        glLightfv(GL_LIGHT0, GL_POSITION, position)
        
        # Normalização automática
        glEnable(GL_NORMALIZE)
    
    def _init_systems(self):
        """Inicializa todos os sistemas do simulador"""
        try:
            # Utilitários OpenGL (shaders, VAO/VBO)
            self.gl_utils = GLUtils()
            shader_success = self.gl_utils.init_shaders()
            
            if not shader_success:
                print("AVISO: Shaders não carregaram, usando pipeline fixo")
            
            # Câmera
            self.camera = Camera3D()
            
            # Renderer
            self.renderer = Renderer(self.gl_utils, shader_success)
            
            # Mundo (estruturas estáticas)
            self.world = World(self.renderer)
            
            # Controlador de interseção (semáforos, lógica)
            self.intersection = IntersectionController()
            
            # Gerenciador de tráfego (carros, pedestres)
            self.traffic = TrafficManager(self.intersection)
            
            # Sistema de métricas
            self.metrics = MetricsCollector()
            
            # HUD (interface 2D)
            self.hud = HUD(self.width, self.height)
            
            # Configurar callbacks
            self.intersection.set_metrics_callback(self.metrics.record_event)
            
        except Exception as e:
            print(f"Erro ao inicializar sistemas: {e}")
            raise
    
    def handle_events(self):
        """Processa eventos de entrada"""
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                self.running = False
            
            elif event.type == pygame.VIDEORESIZE:
                self.width, self.height = event.w, event.h
                self._setup_viewport()
                self.hud.resize(self.width, self.height)
            
            elif event.type == pygame.KEYDOWN:
                self._handle_keydown(event.key)
            
            elif event.type == pygame.KEYUP:
                self.keys_pressed.discard(event.key)
            
            elif event.type == pygame.MOUSEBUTTONDOWN:
                if event.button == 1:  # Botão esquerdo
                    self.mouse_pressed = True
                    self.last_mouse_pos = event.pos
            
            elif event.type == pygame.MOUSEBUTTONUP:
                if event.button == 1:
                    self.mouse_pressed = False
            
            elif event.type == pygame.MOUSEMOTION:
                self._handle_mouse_motion(event)
    
    def _handle_keydown(self, key):
        """Processa teclas pressionadas"""
        self.keys_pressed.add(key)
        
        # Controles básicos
        if key == pygame.K_ESCAPE:
            self.running = False
        elif key == pygame.K_p:
            self.paused = not self.paused
            print(f"{'Pausado' if self.paused else 'Retomado'}")
        elif key == pygame.K_r:
            self._reset_simulation()
        elif key == pygame.K_F1:
            self.show_debug = not self.show_debug
        
        # Taxa de spawn de carros (1-5)
        elif pygame.K_1 <= key <= pygame.K_5:
            rate = (key - pygame.K_0) * 0.15
            self.traffic.set_car_spawn_rate(rate)
            print(f"Taxa carros: {rate:.2f}")
        
        # Taxa de spawn de pedestres (8-9)
        elif key == pygame.K_8:
            rate = max(0.05, self.traffic.pedestrian_spawn_rate - 0.05)
            self.traffic.set_pedestrian_spawn_rate(rate)
            print(f"Taxa pedestres: {rate:.2f}")
        elif key == pygame.K_9:
            rate = min(0.5, self.traffic.pedestrian_spawn_rate + 0.05)
            self.traffic.set_pedestrian_spawn_rate(rate)
            print(f"Taxa pedestres: {rate:.2f}")
        
        # Ajustes de timing de semáforo
        elif key == pygame.K_LEFTBRACKET:  # [
            self.intersection.adjust_min_green(-1.0)
        elif key == pygame.K_RIGHTBRACKET:  # ]
            self.intersection.adjust_min_green(1.0)
        elif key == pygame.K_MINUS:  # - (para diminuir max green)
            self.intersection.adjust_max_green(-2.0)
        elif key == pygame.K_EQUALS:  # = (para aumentar max green)
            self.intersection.adjust_max_green(2.0)
        elif key == pygame.K_SEMICOLON:  # ; (para diminuir yellow)
            self.intersection.adjust_yellow_time(-0.5)
        elif key == pygame.K_QUOTE:  # ' (para aumentar yellow)
            self.intersection.adjust_yellow_time(0.5)
        elif key == pygame.K_COMMA:  # ,
            self.intersection.adjust_all_red_time(-0.5)
        elif key == pygame.K_PERIOD:  # .
            self.intersection.adjust_all_red_time(0.5)
    
    def _handle_mouse_motion(self, event):
        """Processa movimento do mouse para controle de câmera"""
        if self.mouse_pressed:
            dx = event.pos[0] - self.last_mouse_pos[0]
            dy = event.pos[1] - self.last_mouse_pos[1]
            
            self.camera.rotate_by_mouse(dx, dy)
            self.last_mouse_pos = event.pos
    
    def _reset_simulation(self):
        """Reinicia toda a simulação"""
        self.intersection.reset()
        self.traffic.reset()
        self.metrics.reset()
        self.paused = False
        print("Simulação reiniciada")
    
    def update(self):
        """Atualiza todos os sistemas"""
        if not self.paused:
            # Atualizar sistemas de simulação
            self.intersection.update(self.delta_time)
            self.traffic.update(self.delta_time)
            self.metrics.update(self.delta_time)
        
        # Sempre atualizar câmera e input
        self._update_camera()
        self._update_fps_counter()
    
    def _update_camera(self):
        """Atualiza câmera baseada em input contínuo"""
        camera_speed = 50.0 * self.delta_time
        
        # Movimento por teclado
        if pygame.K_w in self.keys_pressed:
            self.camera.zoom(-camera_speed)
        if pygame.K_s in self.keys_pressed:
            self.camera.zoom(camera_speed)
        if pygame.K_a in self.keys_pressed:
            self.camera.rotate(-camera_speed * 2, 0)
        if pygame.K_d in self.keys_pressed:
            self.camera.rotate(camera_speed * 2, 0)
        if pygame.K_q in self.keys_pressed:
            self.camera.rotate(0, camera_speed)
        if pygame.K_e in self.keys_pressed:
            self.camera.rotate(0, -camera_speed)
    
    def _update_fps_counter(self):
        """Atualiza contador de FPS"""
        self.frame_count += 1
        current_time = time.time()
        
        if current_time - self.last_fps_update >= 1.0:
            self.current_fps = self.frame_count / (current_time - self.last_fps_update)
            self.frame_count = 0
            self.last_fps_update = current_time
    
    def render(self):
        """Renderiza toda a cena"""
        # Limpar buffers
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
        
        # Aplicar transformação da câmera
        self.camera.apply_transform()
        
        # Renderizar mundo 3D
        self.renderer.begin_frame()
        
        # Renderizar estruturas estáticas
        self.world.render()
        
        # Renderizar elementos dinâmicos
        self.intersection.render(self.renderer)
        self.traffic.render(self.renderer)
        
        self.renderer.end_frame()
        
        # Renderizar HUD 2D
        self._render_hud()
        
        # Swap buffers
        pygame.display.flip()
    
    def _render_hud(self):
        """Renderiza interface 2D"""
        # Coletar dados para o HUD
        stats = {
            'fps': self.current_fps,
            'paused': self.paused,
            'car_spawn_rate': self.traffic.car_spawn_rate,
            'pedestrian_spawn_rate': self.traffic.pedestrian_spawn_rate,
            'traffic_stats': self.metrics.get_current_stats(),
            'intersection_states': self.intersection.get_signal_states(),
            'timing_config': self.intersection.get_timing_config()
        }
        
        self.hud.render(stats, self.show_debug)
    
    def run(self):
        """Loop principal da aplicação"""
        last_time = time.time()
        
        while self.running:
            current_time = time.time()
            self.delta_time = min(current_time - last_time, 1.0/30.0)  # Cap para evitar jumps
            last_time = current_time
            
            # Processar eventos
            self.handle_events()
            
            # Atualizar lógica
            self.update()
            
            # Renderizar
            self.render()
            
            # Controlar framerate
            self.clock.tick(self.target_fps)
    
    def cleanup(self):
        """Limpeza de recursos"""
        try:
            if hasattr(self, 'metrics'):
                self.metrics.save_to_csv()
            
            if hasattr(self, 'gl_utils'):
                self.gl_utils.cleanup()
            
            pygame.quit()
            print("Simulador finalizado")
        except:
            pass