import pygame
import sys
import math
import os
from OpenGL.GL import *
from OpenGL.GLU import *
from PIL import Image
import numpy as np

from vehicle_system import VehicleManager

class Camera3D:
    def __init__(self):
        self.distance = 40.0
        self.azimuth = 45.0
        self.elevation = -35.0
        self.target_x = 0.0
        self.target_y = 0.0
        self.target_z = 0.0
        
    def apply_transform(self):
        azimuth_rad = math.radians(self.azimuth)
        elevation_rad = math.radians(self.elevation)
        cos_elevation = math.cos(elevation_rad)
        
        x = self.target_x + self.distance * cos_elevation * math.sin(azimuth_rad)
        y = self.target_y + self.distance * cos_elevation * math.cos(azimuth_rad)
        z = self.target_z + self.distance * math.sin(elevation_rad)
        
        glMatrixMode(GL_MODELVIEW)
        glLoadIdentity()
        gluLookAt(x, y, z, self.target_x, self.target_y, self.target_z, 0.0, 0.0, 1.0)
    
    def zoom(self, delta):
        self.distance += delta
        self.distance = max(10.0, min(100.0, self.distance))
    
    def orbit(self, delta_azimuth, delta_elevation):
        self.azimuth += delta_azimuth
        self.elevation += delta_elevation
        self.elevation = max(-80.0, min(10.0, self.elevation))

class TextureLoader:
    def __init__(self):
        self.textures = {}
    
    def load_texture(self, filepath):
        if filepath in self.textures:
            return self.textures[filepath]
        
        try:
            img = Image.open(filepath)
            img = img.transpose(Image.FLIP_TOP_BOTTOM)
            img_data = np.array(list(img.getdata()), np.uint8)
            
            texture_id = glGenTextures(1)
            glBindTexture(GL_TEXTURE_2D, texture_id)
            
            if img.mode == "RGB":
                glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, img.width, img.height, 0, GL_RGB, GL_UNSIGNED_BYTE, img_data)
            elif img.mode == "RGBA":
                glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, img.width, img.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, img_data)
            
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT)
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT)
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
            
            self.textures[filepath] = texture_id
            return texture_id
            
        except Exception as e:
            print(f"Erro ao carregar textura {filepath}: {e}")
            return None

class RealisticShapes:
    @staticmethod
    def draw_road_segment(width, length, texture_id=None):
        """Desenha segmento de rua com textura"""
        if texture_id:
            glEnable(GL_TEXTURE_2D)
            glBindTexture(GL_TEXTURE_2D, texture_id)
        
        glBegin(GL_QUADS)
        glColor3f(0.3, 0.3, 0.35)  # Asfalto escuro
        
        # Repetir textura baseado no tamanho
        tex_repeat = max(1, int(length / 10))
        
        glTexCoord2f(0.0, 0.0)
        glVertex3f(-width/2, -length/2, 0.0)
        
        glTexCoord2f(1.0, 0.0)
        glVertex3f(width/2, -length/2, 0.0)
        
        glTexCoord2f(1.0, tex_repeat)
        glVertex3f(width/2, length/2, 0.0)
        
        glTexCoord2f(0.0, tex_repeat)
        glVertex3f(-width/2, length/2, 0.0)
        
        glEnd()
        
        if texture_id:
            glDisable(GL_TEXTURE_2D)
    
    @staticmethod
    def draw_sidewalk(width, length, height=0.15):
        """Calçada elevada com bordas"""
        # Base da calçada
        glColor3f(0.7, 0.7, 0.75)
        glBegin(GL_QUADS)
        # Topo
        glVertex3f(-width/2, -length/2, height)
        glVertex3f(width/2, -length/2, height)
        glVertex3f(width/2, length/2, height)
        glVertex3f(-width/2, length/2, height)
        glEnd()
        
        # Bordas da calçada
        glColor3f(0.6, 0.6, 0.65)
        glBegin(GL_QUADS)
        # Frente
        glVertex3f(-width/2, length/2, 0.0)
        glVertex3f(width/2, length/2, 0.0)
        glVertex3f(width/2, length/2, height)
        glVertex3f(-width/2, length/2, height)
        # Trás
        glVertex3f(-width/2, -length/2, 0.0)
        glVertex3f(-width/2, -length/2, height)
        glVertex3f(width/2, -length/2, height)
        glVertex3f(width/2, -length/2, 0.0)
        # Esquerda
        glVertex3f(-width/2, -length/2, 0.0)
        glVertex3f(-width/2, length/2, 0.0)
        glVertex3f(-width/2, length/2, height)
        glVertex3f(-width/2, -length/2, height)
        # Direita
        glVertex3f(width/2, -length/2, 0.0)
        glVertex3f(width/2, -length/2, height)
        glVertex3f(width/2, length/2, height)
        glVertex3f(width/2, length/2, 0.0)
        glEnd()

    @staticmethod
    def draw_traffic_light_pole():
        """Poste de semáforo realista"""
        # Poste principal - cilindro simulado com octágono
        glColor3f(0.4, 0.4, 0.45)
        sides = 8
        radius = 0.1
        height = 4.5
        
        glBegin(GL_QUAD_STRIP)
        for i in range(sides + 1):
            angle = 2.0 * math.pi * i / sides
            x = radius * math.cos(angle)
            y = radius * math.sin(angle)
            glVertex3f(x, y, 0.0)
            glVertex3f(x, y, height)
        glEnd()
        
        # Base do poste
        glColor3f(0.35, 0.35, 0.4)
        glBegin(GL_POLYGON)
        for i in range(sides):
            angle = 2.0 * math.pi * i / sides
            x = radius * 1.5 * math.cos(angle)
            y = radius * 1.5 * math.sin(angle)
            glVertex3f(x, y, 0.0)
        glEnd()
    
    @staticmethod
    def draw_traffic_light_head():
        """Cabeça do semáforo com 3 luzes"""
        # Caixa do semáforo
        glColor3f(0.2, 0.2, 0.2)
        
        width, height, depth = 0.4, 1.2, 0.3
        
        # Faces da caixa
        glBegin(GL_QUADS)
        # Frente
        glVertex3f(-width/2, -depth/2, 0)
        glVertex3f(width/2, -depth/2, 0)
        glVertex3f(width/2, -depth/2, height)
        glVertex3f(-width/2, -depth/2, height)
        # Trás  
        glVertex3f(-width/2, depth/2, 0)
        glVertex3f(-width/2, depth/2, height)
        glVertex3f(width/2, depth/2, height)
        glVertex3f(width/2, depth/2, 0)
        # Lados
        glVertex3f(-width/2, -depth/2, 0)
        glVertex3f(-width/2, -depth/2, height)
        glVertex3f(-width/2, depth/2, height)
        glVertex3f(-width/2, depth/2, 0)
        
        glVertex3f(width/2, -depth/2, 0)
        glVertex3f(width/2, depth/2, 0)
        glVertex3f(width/2, depth/2, height)
        glVertex3f(width/2, -depth/2, height)
        # Topo
        glVertex3f(-width/2, -depth/2, height)
        glVertex3f(width/2, -depth/2, height)
        glVertex3f(width/2, depth/2, height)
        glVertex3f(-width/2, depth/2, height)
        glEnd()
    
    @staticmethod
    def draw_traffic_light_bulb(color, active=False):
        """Lâmpada do semáforo"""
        if active:
            if color == 'red':
                glMaterialfv(GL_FRONT, GL_AMBIENT, [0.3, 0.1, 0.1, 1.0])
                glMaterialfv(GL_FRONT, GL_DIFFUSE, [1.0, 0.2, 0.2, 1.0])
                glMaterialfv(GL_FRONT, GL_EMISSION, [0.8, 0.1, 0.1, 1.0])  # Emissão forte
            elif color == 'yellow':
                glMaterialfv(GL_FRONT, GL_AMBIENT, [0.3, 0.3, 0.1, 1.0])
                glMaterialfv(GL_FRONT, GL_DIFFUSE, [1.0, 1.0, 0.2, 1.0])
                glMaterialfv(GL_FRONT, GL_EMISSION, [0.8, 0.8, 0.1, 1.0])  # Emissão forte
            else:  # green
                glMaterialfv(GL_FRONT, GL_AMBIENT, [0.1, 0.3, 0.1, 1.0])
                glMaterialfv(GL_FRONT, GL_DIFFUSE, [0.2, 1.0, 0.2, 1.0])
                glMaterialfv(GL_FRONT, GL_EMISSION, [0.1, 0.8, 0.1, 1.0])  # Emissão forte
        else:
            # Lâmpada apagada
            glMaterialfv(GL_FRONT, GL_AMBIENT, [0.1, 0.1, 0.1, 1.0])
            glMaterialfv(GL_FRONT, GL_DIFFUSE, [0.3, 0.3, 0.3, 1.0])
            glMaterialfv(GL_FRONT, GL_EMISSION, [0.0, 0.0, 0.0, 1.0])  # Sem emissão
        
        # Círculo simulado com polígono
        radius = 0.12
        sides = 16
        
        glBegin(GL_POLYGON)
        for i in range(sides):
            angle = 2.0 * math.pi * i / sides
            x = radius * math.cos(angle)
            z = radius * math.sin(angle)
            glVertex3f(x, -0.16, z)
        glEnd()

    @staticmethod
    def draw_crosswalk_stripes(width, length):
        """Faixa de pedestres zebrada realista"""
        stripe_width = 0.5
        num_stripes = int(width / stripe_width)
        
        for i in range(num_stripes):
            if i % 2 == 0:  # Listras brancas
                glColor3f(0.95, 0.95, 0.95)
                x_start = -width/2 + i * stripe_width
                
                glBegin(GL_QUADS)
                glVertex3f(x_start, -length/2, 0.01)
                glVertex3f(x_start + stripe_width * 0.8, -length/2, 0.01)
                glVertex3f(x_start + stripe_width * 0.8, length/2, 0.01)
                glVertex3f(x_start, length/2, 0.01)
                glEnd()

class RealisticIntersection:
    def __init__(self):
        self.texture_loader = TextureLoader()
        self.road_texture = None
        
        # Dimensões realistas
        self.road_width = 8.0
        self.intersection_size = 16.0
        self.sidewalk_width = 3.0
        
        # Semáforos
        self.traffic_lights = [
            {'pos': (-6, 6, 0), 'arm_dir': (1, 0, 0), 'state': 'red'},
            {'pos': (6, -6, 0), 'arm_dir': (-1, 0, 0), 'state': 'red'}, 
            {'pos': (6, 6, 0), 'arm_dir': (0, -1, 0), 'state': 'green'},
        ]
        
        self.timer = 0.0
        
        # Sistema de veículos
        self.vehicle_manager = VehicleManager()
        
    def load_textures(self):
        """Carrega texturas disponíveis"""
        self.road_texture = self.texture_loader.load_texture("assets/textures/roads/asphalt_02_diffuse.jpg")
        
    def update(self, dt):
        """Atualiza lógica dos semáforos e veículos"""
        self.timer += dt
        cycle_time = 8.0
        
        traffic_state = None
        if (self.timer % cycle_time) < 4.0:
            # NS verde, EW vermelho
            self.traffic_lights[0]['state'] = 'red'    # EW Oeste
            self.traffic_lights[1]['state'] = 'red'    # EW Leste  
            self.traffic_lights[2]['state'] = 'green'  # NS Norte
            traffic_state = 'red_ew'  # Vermelho para Leste-Oeste
        else:
            # EW verde, NS vermelho
            self.traffic_lights[0]['state'] = 'green'  # EW Oeste
            self.traffic_lights[1]['state'] = 'green'  # EW Leste
            self.traffic_lights[2]['state'] = 'red'    # NS Norte
            traffic_state = 'red_ns'  # Vermelho para Norte-Sul
            
        # Atualizar veículos com estado específico
        self.vehicle_manager.update(dt, traffic_state)
    
    def render(self):
        """Renderiza interseção realista"""
        if not self.road_texture:
            self.load_textures()
            
        self._render_ground()
        self._render_roads()
        self._render_sidewalks()
        self._render_crosswalks()
        self._render_road_markings()
        self._render_traffic_lights()
        self._render_vehicles()
        
    def _render_ground(self):
        """Grama de fundo"""
        glColor3f(0.2, 0.7, 0.2)
        glBegin(GL_QUADS)
        size = 150
        glVertex3f(-size, -size, -0.01)
        glVertex3f(size, -size, -0.01)
        glVertex3f(size, size, -0.01)
        glVertex3f(-size, size, -0.01)
        glEnd()
    
    def _render_roads(self):
        """Ruas com textura de asfalto"""
        # Rua principal (Leste-Oeste)
        glPushMatrix()
        glTranslatef(0, 0, 0)
        RealisticShapes.draw_road_segment(self.road_width, 120, self.road_texture)
        glPopMatrix()
        
        # Rua secundária (Norte-Sul) 
        glPushMatrix()
        glTranslatef(0, 0, 0)
        glRotatef(90, 0, 0, 1)
        RealisticShapes.draw_road_segment(self.road_width, 80, self.road_texture)
        glPopMatrix()
        
        # Interseção central
        glPushMatrix()
        glTranslatef(0, 0, 0)
        RealisticShapes.draw_road_segment(self.intersection_size, self.intersection_size, self.road_texture)
        glPopMatrix()
    
    def _render_sidewalks(self):
        """Calçadas elevadas"""
        positions = [
            # Cantos da interseção
            (-12, 12, 0), (12, 12, 0), (-12, -12, 0), (12, -12, 0),
            # Ao longo das ruas
            (-12, 30, 0), (12, 30, 0), (-12, -30, 0), (12, -30, 0),
            (-40, 12, 0), (-40, -12, 0), (40, 12, 0), (40, -12, 0),
        ]
        
        for x, y, z in positions:
            glPushMatrix()
            glTranslatef(x, y, z)
            RealisticShapes.draw_sidewalk(6, 6)
            glPopMatrix()
    
    def _render_crosswalks(self):
        """Faixas zebradas"""
        # Norte
        glPushMatrix()
        glTranslatef(0, 12, 0)
        RealisticShapes.draw_crosswalk_stripes(self.road_width, 4)
        glPopMatrix()
        
        # Sul
        glPushMatrix()
        glTranslatef(0, -12, 0)
        RealisticShapes.draw_crosswalk_stripes(self.road_width, 4)
        glPopMatrix()
        
        # Leste
        glPushMatrix()
        glTranslatef(12, 0, 0)
        glRotatef(90, 0, 0, 1)
        RealisticShapes.draw_crosswalk_stripes(self.road_width, 4)
        glPopMatrix()
        
        # Oeste
        glPushMatrix()
        glTranslatef(-12, 0, 0)
        glRotatef(90, 0, 0, 1)
        RealisticShapes.draw_crosswalk_stripes(self.road_width, 4)
        glPopMatrix()
    
    def _render_road_markings(self):
        """Linhas amarelas centrais"""
        glColor3f(1.0, 1.0, 0.0)
        glLineWidth(4.0)
        
        # Linha central EW
        glBegin(GL_LINES)
        for x in range(-50, 51, 4):
            if abs(x) > self.intersection_size/2:
                glVertex3f(x, 0, 0.02)
                glVertex3f(x + 2, 0, 0.02)
        glEnd()
        
        # Linha central NS
        glBegin(GL_LINES)
        for y in range(-35, 36, 4):
            if abs(y) > self.intersection_size/2:
                glVertex3f(0, y, 0.02)
                glVertex3f(0, y + 2, 0.02)
        glEnd()
        
        glLineWidth(1.0)
    
    def _render_traffic_lights(self):
        """Semáforos realistas"""
        for light in self.traffic_lights:
            x, y, z = light['pos']
            arm_x, arm_y, arm_z = light['arm_dir']
            state = light['state']
            
            glPushMatrix()
            glTranslatef(x, y, z)
            
            # Poste
            RealisticShapes.draw_traffic_light_pole()
            
            # Braço horizontal
            glPushMatrix()
            glTranslatef(0, 0, 4.2)
            glColor3f(0.4, 0.4, 0.45)
            
            # Braço do semáforo
            glBegin(GL_QUADS)
            glVertex3f(0, -0.05, -0.05)
            glVertex3f(arm_x * 3, arm_y * 3 - 0.05, -0.05)
            glVertex3f(arm_x * 3, arm_y * 3 + 0.05, 0.05)
            glVertex3f(0, 0.05, 0.05)
            glEnd()
            
            # Cabeça do semáforo
            glTranslatef(arm_x * 3, arm_y * 3, 0)
            RealisticShapes.draw_traffic_light_head()
            
            # Luzes
            glTranslatef(0, 0, 0.9)
            RealisticShapes.draw_traffic_light_bulb('red', state == 'red')
            
            glTranslatef(0, 0, -0.3)
            RealisticShapes.draw_traffic_light_bulb('yellow', state == 'yellow')
            
            glTranslatef(0, 0, -0.3)
            RealisticShapes.draw_traffic_light_bulb('green', state == 'green')
            
            glPopMatrix()
            glPopMatrix()
    
    def _render_vehicles(self):
        """Renderiza todos os veículos"""
        self.vehicle_manager.render()

class RealisticApp:
    def __init__(self):
        self.width = 1920
        self.height = 1080
        self.running = True
        self.camera = Camera3D()
        self.intersection = RealisticIntersection()
        self.clock = pygame.time.Clock()
        
    def init_pygame(self):
        pygame.init()
        self.screen = pygame.display.set_mode((self.width, self.height), pygame.DOUBLEBUF | pygame.OPENGL)
        pygame.display.set_caption("Simulação Realista de Trânsito 3D")
        
        # Fonte para UI
        self.font = pygame.font.Font(None, 36)
        
        # OpenGL
        glEnable(GL_DEPTH_TEST)
        glEnable(GL_LIGHTING)
        glEnable(GL_LIGHT0)
        
        # Luz ambiente
        glLightfv(GL_LIGHT0, GL_POSITION, [10, 10, 20, 1])
        glLightfv(GL_LIGHT0, GL_AMBIENT, [0.3, 0.3, 0.3, 1])
        glLightfv(GL_LIGHT0, GL_DIFFUSE, [0.8, 0.8, 0.8, 1])
        
        glMatrixMode(GL_PROJECTION)
        gluPerspective(45, self.width/self.height, 0.1, 200.0)
        
        glClearColor(0.5, 0.7, 1.0, 1.0)  # Céu azul
        
    def handle_events(self):
        for event in pygame.event.get():
            if event.type == pygame.QUIT or (event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE):
                self.running = False
            elif event.type == pygame.MOUSEBUTTONDOWN:
                if event.button == 4:  # Scroll up
                    self.camera.zoom(-2)
                elif event.button == 5:  # Scroll down
                    self.camera.zoom(2)
            elif event.type == pygame.MOUSEMOTION:
                if pygame.mouse.get_pressed()[0]:
                    dx, dy = event.rel
                    self.camera.orbit(dx * 0.5, dy * 0.5)
        
        keys = pygame.key.get_pressed()
        if keys[pygame.K_a]:
            self.camera.target_x -= 0.5
        if keys[pygame.K_d]:
            self.camera.target_x += 0.5
        if keys[pygame.K_w]:
            self.camera.target_y += 0.5
        if keys[pygame.K_s]:
            self.camera.target_y -= 0.5
            
    def render(self):
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
        self.camera.apply_transform()
        self.intersection.render()
        self._render_ui()
        pygame.display.flip()
    
    def _render_ui(self):
        """Renderiza informações na tela"""
        # Salvar estado OpenGL
        glMatrixMode(GL_PROJECTION)
        glPushMatrix()
        glLoadIdentity()
        glOrtho(0, self.width, self.height, 0, -1, 1)
        
        glMatrixMode(GL_MODELVIEW)
        glPushMatrix()
        glLoadIdentity()
        
        glDisable(GL_LIGHTING)
        glDisable(GL_DEPTH_TEST)
        
        # Contador de veículos
        vehicle_count = self.intersection.vehicle_manager.get_vehicle_count()
        
        # Texto em OpenGL
        glColor3f(1.0, 1.0, 1.0)
        glRasterPos2f(20, 40)
        
        text = f"Veículos: {vehicle_count}"
        for char in text:
            pygame.font.Font(None, 24)
        
        # Instruções
        instructions = [
            "Mouse: Rotacionar camera",
            "WASD: Mover foco",
            "Scroll: Zoom",
            "ESC: Sair"
        ]
        
        glColor3f(0.8, 0.8, 0.8)
        for i, instruction in enumerate(instructions):
            glRasterPos2f(20, 80 + i * 25)
        
        # Restaurar estado OpenGL
        glEnable(GL_DEPTH_TEST)
        glEnable(GL_LIGHTING)
        
        glPopMatrix()
        glMatrixMode(GL_PROJECTION)
        glPopMatrix()
        glMatrixMode(GL_MODELVIEW)
        
    def run(self):
        self.init_pygame()
        
        while self.running:
            dt = self.clock.tick(60) / 1000.0
            
            self.handle_events()
            self.intersection.update(dt)
            self.render()
            
        pygame.quit()
        sys.exit()

if __name__ == "__main__":
    app = RealisticApp()
    app.run()