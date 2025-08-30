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

class FixedShapes:
    @staticmethod
    def set_material(ambient, diffuse, emission=[0,0,0,1]):
        """Define material usando apenas OpenGL materials"""
        glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT, ambient)
        glMaterialfv(GL_FRONT_AND_BACK, GL_DIFFUSE, diffuse)
        glMaterialfv(GL_FRONT_AND_BACK, GL_EMISSION, emission)
    
    @staticmethod
    def draw_ground():
        """Grama verde"""
        FixedShapes.set_material([0.1, 0.4, 0.1, 1.0], [0.2, 0.6, 0.2, 1.0])
        glBegin(GL_QUADS)
        size = 150
        glNormal3f(0, 0, 1)
        glVertex3f(-size, -size, -0.01)
        glVertex3f(size, -size, -0.01)
        glVertex3f(size, size, -0.01)
        glVertex3f(-size, size, -0.01)
        glEnd()
    
    @staticmethod
    def draw_road(width, length):
        """Rua de asfalto"""
        FixedShapes.set_material([0.15, 0.15, 0.15, 1.0], [0.3, 0.3, 0.35, 1.0])
        glBegin(GL_QUADS)
        glNormal3f(0, 0, 1)
        glVertex3f(-width/2, -length/2, 0.0)
        glVertex3f(width/2, -length/2, 0.0)
        glVertex3f(width/2, length/2, 0.0)
        glVertex3f(-width/2, length/2, 0.0)
        glEnd()
        
    @staticmethod
    def draw_crosswalk_stripe(width, length):
        """Listra branca da faixa"""
        FixedShapes.set_material([0.8, 0.8, 0.8, 1.0], [0.9, 0.9, 0.9, 1.0])
        glBegin(GL_QUADS)
        glNormal3f(0, 0, 1)
        glVertex3f(-width/2, -length/2, 0.01)
        glVertex3f(width/2, -length/2, 0.01)
        glVertex3f(width/2, length/2, 0.01)
        glVertex3f(-width/2, length/2, 0.01)
        glEnd()
    
    @staticmethod
    def draw_traffic_light_pole():
        """Poste cinza do semáforo"""
        FixedShapes.set_material([0.3, 0.3, 0.3, 1.0], [0.5, 0.5, 0.5, 1.0])
        
        # Poste vertical simples
        glBegin(GL_QUADS)
        # Frente
        glNormal3f(0, -1, 0)
        glVertex3f(-0.1, -0.1, 0.0)
        glVertex3f(0.1, -0.1, 0.0)
        glVertex3f(0.1, -0.1, 4.5)
        glVertex3f(-0.1, -0.1, 4.5)
        # Trás
        glNormal3f(0, 1, 0)
        glVertex3f(-0.1, 0.1, 0.0)
        glVertex3f(-0.1, 0.1, 4.5)
        glVertex3f(0.1, 0.1, 4.5)
        glVertex3f(0.1, 0.1, 0.0)
        # Lados
        glNormal3f(-1, 0, 0)
        glVertex3f(-0.1, -0.1, 0.0)
        glVertex3f(-0.1, -0.1, 4.5)
        glVertex3f(-0.1, 0.1, 4.5)
        glVertex3f(-0.1, 0.1, 0.0)
        
        glNormal3f(1, 0, 0)
        glVertex3f(0.1, -0.1, 0.0)
        glVertex3f(0.1, 0.1, 0.0)
        glVertex3f(0.1, 0.1, 4.5)
        glVertex3f(0.1, -0.1, 4.5)
        glEnd()
    
    @staticmethod
    def draw_traffic_light_arm(length, direction):
        """Braço horizontal do semáforo"""
        FixedShapes.set_material([0.3, 0.3, 0.3, 1.0], [0.5, 0.5, 0.5, 1.0])
        
        glPushMatrix()
        if direction == 'east':
            glRotatef(0, 0, 0, 1)  # Para leste
        elif direction == 'west':
            glRotatef(180, 0, 0, 1)  # Para oeste
        elif direction == 'south':
            glRotatef(270, 0, 0, 1)  # Para sul
        elif direction == 'north':
            glRotatef(90, 0, 0, 1)   # Para norte
            
        # Braço horizontal
        glBegin(GL_QUADS)
        glNormal3f(0, 0, 1)
        glVertex3f(0, -0.05, -0.05)
        glVertex3f(length, -0.05, -0.05)
        glVertex3f(length, 0.05, 0.05)
        glVertex3f(0, 0.05, 0.05)
        glEnd()
        glPopMatrix()
    
    @staticmethod
    def draw_traffic_light_box():
        """Caixa preta do semáforo"""
        FixedShapes.set_material([0.1, 0.1, 0.1, 1.0], [0.2, 0.2, 0.2, 1.0])
        
        w, h, d = 0.3, 1.0, 0.25
        glBegin(GL_QUADS)
        # Frente
        glNormal3f(0, -1, 0)
        glVertex3f(-w/2, -d/2, 0)
        glVertex3f(w/2, -d/2, 0)
        glVertex3f(w/2, -d/2, h)
        glVertex3f(-w/2, -d/2, h)
        # Outros lados...
        glEnd()
    
    @staticmethod
    def draw_traffic_light_bulb(color, is_on):
        """Lâmpada do semáforo"""
        if is_on:
            if color == 'red':
                FixedShapes.set_material([0.2, 0.05, 0.05, 1.0], [1.0, 0.2, 0.2, 1.0], [0.6, 0.1, 0.1, 1.0])
            elif color == 'yellow':
                FixedShapes.set_material([0.2, 0.2, 0.05, 1.0], [1.0, 1.0, 0.2, 1.0], [0.6, 0.6, 0.1, 1.0])
            elif color == 'green':
                FixedShapes.set_material([0.05, 0.2, 0.05, 1.0], [0.2, 1.0, 0.2, 1.0], [0.1, 0.6, 0.1, 1.0])
        else:
            # Apagada
            FixedShapes.set_material([0.1, 0.1, 0.1, 1.0], [0.2, 0.2, 0.2, 1.0])
        
        # Círculo da lâmpada
        radius = 0.08
        sides = 12
        glBegin(GL_POLYGON)
        glNormal3f(0, -1, 0)
        for i in range(sides):
            angle = 2.0 * math.pi * i / sides
            x = radius * math.cos(angle)
            z = radius * math.sin(angle)
            glVertex3f(x, -0.13, z)
        glEnd()

class FixedIntersection:
    def __init__(self):
        # Dimensões
        self.road_width = 8.0
        self.intersection_size = 16.0
        
        # Semáforos CORRIGIDOS
        self.traffic_lights = [
            # Semáforo controlando tráfego Leste->Oeste (braço aponta sul sobre a pista)
            {'pos': (8, -8, 0), 'arm_dir': 'south', 'controls': 'ew', 'state': 'red'},
            # Semáforo controlando tráfego Oeste->Leste (braço aponta norte sobre a pista)  
            {'pos': (-8, 8, 0), 'arm_dir': 'north', 'controls': 'ew', 'state': 'red'},
            # Semáforo controlando tráfego Norte->Sul (braço aponta leste sobre a pista)
            {'pos': (-8, 8, 0), 'arm_dir': 'east', 'controls': 'ns', 'state': 'green'},
        ]
        
        self.timer = 0.0
        self.vehicle_manager = VehicleManager()
        
    def update(self, dt):
        self.timer += dt
        cycle_time = 8.0
        
        if (self.timer % cycle_time) < 4.0:
            # NS verde, EW vermelho
            traffic_state = 'red_ew'
            for light in self.traffic_lights:
                if light['controls'] == 'ew':
                    light['state'] = 'red'
                else:
                    light['state'] = 'green'
        else:
            # EW verde, NS vermelho
            traffic_state = 'red_ns'  
            for light in self.traffic_lights:
                if light['controls'] == 'ew':
                    light['state'] = 'green'
                else:
                    light['state'] = 'red'
        
        self.vehicle_manager.update(dt, traffic_state)
    
    def render(self):
        self._render_ground()
        self._render_roads()
        self._render_crosswalks()
        self._render_road_markings()
        self._render_traffic_lights()
        self._render_vehicles()
    
    def _render_ground(self):
        FixedShapes.draw_ground()
        
    def _render_roads(self):
        # Rua principal (Leste-Oeste)
        glPushMatrix()
        glTranslatef(0, 0, 0)
        FixedShapes.draw_road(self.road_width, 120)
        glPopMatrix()
        
        # Rua secundária (Norte-Sul)
        glPushMatrix()
        glTranslatef(0, 0, 0)
        glRotatef(90, 0, 0, 1)
        FixedShapes.draw_road(self.road_width, 80)
        glPopMatrix()
        
        # Interseção
        glPushMatrix()
        glTranslatef(0, 0, 0)
        FixedShapes.draw_road(self.intersection_size, self.intersection_size)
        glPopMatrix()
    
    def _render_crosswalks(self):
        """Faixas zebradas"""
        stripe_width = 0.8
        
        # Norte
        for i in range(8):
            if i % 2 == 0:
                glPushMatrix()
                glTranslatef(-self.road_width/2 + i * stripe_width, 12, 0)
                FixedShapes.draw_crosswalk_stripe(stripe_width * 0.7, 4)
                glPopMatrix()
        
        # Sul  
        for i in range(8):
            if i % 2 == 0:
                glPushMatrix()
                glTranslatef(-self.road_width/2 + i * stripe_width, -12, 0)
                FixedShapes.draw_crosswalk_stripe(stripe_width * 0.7, 4)
                glPopMatrix()
        
        # Leste
        for i in range(8):
            if i % 2 == 0:
                glPushMatrix()
                glTranslatef(12, -self.road_width/2 + i * stripe_width, 0)
                FixedShapes.draw_crosswalk_stripe(4, stripe_width * 0.7)
                glPopMatrix()
    
    def _render_road_markings(self):
        """Linhas amarelas centrais"""
        FixedShapes.set_material([0.3, 0.3, 0.0, 1.0], [1.0, 1.0, 0.0, 1.0])
        
        # EW
        for x in range(-50, 51, 4):
            if abs(x) > self.intersection_size/2:
                glPushMatrix()
                glTranslatef(x, 0, 0.01)
                glScalef(2.0, 0.2, 0.1)
                glBegin(GL_QUADS)
                glVertex3f(-1, -1, 0)
                glVertex3f(1, -1, 0)
                glVertex3f(1, 1, 0)
                glVertex3f(-1, 1, 0)
                glEnd()
                glPopMatrix()
        
        # NS
        for y in range(-35, 36, 4):
            if abs(y) > self.intersection_size/2:
                glPushMatrix()
                glTranslatef(0, y, 0.01)
                glScalef(0.2, 2.0, 0.1)
                glBegin(GL_QUADS)
                glVertex3f(-1, -1, 0)
                glVertex3f(1, -1, 0)
                glVertex3f(1, 1, 0)
                glVertex3f(-1, 1, 0)
                glEnd()
                glPopMatrix()
    
    def _render_traffic_lights(self):
        """Semáforos corrigidos"""
        for light in self.traffic_lights:
            x, y, z = light['pos']
            arm_dir = light['arm_dir']
            state = light['state']
            
            glPushMatrix()
            glTranslatef(x, y, z)
            
            # Poste
            FixedShapes.draw_traffic_light_pole()
            
            # Braço e caixa
            glPushMatrix()
            glTranslatef(0, 0, 4.2)
            
            # Braço
            FixedShapes.draw_traffic_light_arm(3.0, arm_dir)
            
            # Caixa do semáforo na ponta do braço
            if arm_dir == 'east':
                glTranslatef(3.0, 0, 0)
            elif arm_dir == 'west':
                glTranslatef(-3.0, 0, 0)
            elif arm_dir == 'south':
                glTranslatef(0, -3.0, 0)
            elif arm_dir == 'north':
                glTranslatef(0, 3.0, 0)
                
            FixedShapes.draw_traffic_light_box()
            
            # Lâmpadas
            glTranslatef(0, 0, 0.7)
            FixedShapes.draw_traffic_light_bulb('red', state == 'red')
            glTranslatef(0, 0, -0.25)
            FixedShapes.draw_traffic_light_bulb('yellow', state == 'yellow')
            glTranslatef(0, 0, -0.25)
            FixedShapes.draw_traffic_light_bulb('green', state == 'green')
            
            glPopMatrix()
            glPopMatrix()
    
    def _render_vehicles(self):
        self.vehicle_manager.render()

class FixedApp:
    def __init__(self):
        self.width = 1920
        self.height = 1080
        self.running = True
        self.camera = Camera3D()
        self.intersection = FixedIntersection()
        self.clock = pygame.time.Clock()
        
    def init_pygame(self):
        pygame.init()
        self.screen = pygame.display.set_mode((self.width, self.height), pygame.DOUBLEBUF | pygame.OPENGL)
        pygame.display.set_caption("Simulação de Trânsito 3D - CORRIGIDA")
        
        # OpenGL CORRIGIDO
        glEnable(GL_DEPTH_TEST)
        glEnable(GL_LIGHTING)
        glEnable(GL_LIGHT0)
        
        # Luz mais forte
        glLightfv(GL_LIGHT0, GL_POSITION, [20, 20, 30, 1])
        glLightfv(GL_LIGHT0, GL_AMBIENT, [0.5, 0.5, 0.5, 1])
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
        pygame.display.flip()
        
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
    app = FixedApp()
    app.run()