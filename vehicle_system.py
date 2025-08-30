"""
Sistema de veículos para a simulação de trânsito
"""
import math
import random
from OpenGL.GL import *

class Vehicle:
    def __init__(self, x, y, z, direction, speed=5.0, vehicle_type="car"):
        self.x = x
        self.y = y  
        self.z = z
        self.direction = direction  # Em graus
        self.speed = speed  # unidades por segundo
        self.vehicle_type = vehicle_type
        self.color = self._get_random_color()
        self.stopped = False
        self.stop_timer = 0.0
        
    def _get_random_color(self):
        """Cores realistas de carros"""
        colors = [
            (0.8, 0.8, 0.8),  # Prata
            (0.1, 0.1, 0.1),  # Preto
            (0.9, 0.9, 0.9),  # Branco
            (0.7, 0.1, 0.1),  # Vermelho
            (0.1, 0.3, 0.7),  # Azul
            (0.2, 0.5, 0.2),  # Verde
            (0.6, 0.4, 0.1),  # Marrom
        ]
        return random.choice(colors)
    
    def update(self, dt, traffic_light_state=None):
        """Atualiza posição do veículo"""
        if self.stopped:
            self.stop_timer -= dt
            if self.stop_timer <= 0:
                self.stopped = False
            return
            
        # Verificar se deve parar no semáforo
        if traffic_light_state and self._should_stop_at_light(traffic_light_state):
            self.stopped = True
            self.stop_timer = random.uniform(1.0, 3.0)
            return
            
        # Mover o veículo
        rad = math.radians(self.direction)
        dx = self.speed * math.cos(rad) * dt
        dy = self.speed * math.sin(rad) * dt
        
        self.x += dx
        self.y += dy
        
        # Remover veículos que saíram da área
        if abs(self.x) > 80 or abs(self.y) > 60:
            return False  # Marcar para remoção
        return True
    
    def _should_stop_at_light(self, traffic_light_state):
        """Verifica se deve parar baseado na posição e direção do veículo"""
        # Verificar proximidade da interseção
        distance_to_center = math.sqrt(self.x**2 + self.y**2)
        
        if distance_to_center > 20:  # Muito longe da interseção
            return False
            
        # Lógica baseada na direção do veículo
        if self.direction == 0:  # Indo para leste (→)
            # Parar se vermelho para EW e próximo da linha de parada
            return (traffic_light_state == 'red_ew' and 
                    8 < self.x < 12 and -4 < self.y < 0)
                    
        elif self.direction == 180:  # Indo para oeste (←)
            # Parar se vermelho para EW e próximo da linha de parada
            return (traffic_light_state == 'red_ew' and 
                    -12 < self.x < -8 and 0 < self.y < 4)
                    
        elif self.direction == 270:  # Indo para sul (↓)
            # Parar se vermelho para NS e próximo da linha de parada
            return (traffic_light_state == 'red_ns' and 
                    -4 < self.x < 4 and 8 < self.y < 12)
                    
        return False
    
    def render(self):
        """Renderiza o veículo"""
        glPushMatrix()
        glTranslatef(self.x, self.y, self.z)
        glRotatef(self.direction, 0, 0, 1)
        
        glColor3f(*self.color)
        
        if self.vehicle_type == "car":
            self._render_car()
        elif self.vehicle_type == "bus":
            self._render_bus()
        elif self.vehicle_type == "truck":
            self._render_truck()
            
        glPopMatrix()
    
    def _render_car(self):
        """Renderiza um carro 3D detalhado"""
        # Corpo principal do carro
        glBegin(GL_QUADS)
        
        # Base do carro
        glVertex3f(-1.5, -0.8, 0.0)
        glVertex3f(1.5, -0.8, 0.0)
        glVertex3f(1.5, 0.8, 0.0)
        glVertex3f(-1.5, 0.8, 0.0)
        
        # Topo do carro
        glVertex3f(-1.5, -0.8, 0.8)
        glVertex3f(1.5, -0.8, 0.8)
        glVertex3f(1.5, 0.8, 0.8)
        glVertex3f(-1.5, 0.8, 0.8)
        
        # Lados
        glVertex3f(-1.5, -0.8, 0.0)
        glVertex3f(-1.5, -0.8, 0.8)
        glVertex3f(-1.5, 0.8, 0.8)
        glVertex3f(-1.5, 0.8, 0.0)
        
        glVertex3f(1.5, -0.8, 0.0)
        glVertex3f(1.5, 0.8, 0.0)
        glVertex3f(1.5, 0.8, 0.8)
        glVertex3f(1.5, -0.8, 0.8)
        
        # Frente e trás
        glVertex3f(-1.5, -0.8, 0.0)
        glVertex3f(1.5, -0.8, 0.0)
        glVertex3f(1.5, -0.8, 0.8)
        glVertex3f(-1.5, -0.8, 0.8)
        
        glVertex3f(-1.5, 0.8, 0.0)
        glVertex3f(-1.5, 0.8, 0.8)
        glVertex3f(1.5, 0.8, 0.8)
        glVertex3f(1.5, 0.8, 0.0)
        
        glEnd()
        
        # Para-brisas (mais escuro)
        glColor3f(0.2, 0.2, 0.4)
        glBegin(GL_QUADS)
        glVertex3f(-1.2, -0.6, 0.8)
        glVertex3f(1.2, -0.6, 0.8)
        glVertex3f(1.2, 0.6, 0.8)
        glVertex3f(-1.2, 0.6, 0.8)
        glEnd()
        
        # Rodas
        glColor3f(0.1, 0.1, 0.1)
        self._render_wheel(-1.0, -0.9, 0.0)
        self._render_wheel(1.0, -0.9, 0.0)
        self._render_wheel(-1.0, 0.9, 0.0)
        self._render_wheel(1.0, 0.9, 0.0)
    
    def _render_bus(self):
        """Renderiza um ônibus"""
        # Ônibus é maior que carro
        glBegin(GL_QUADS)
        
        # Base 
        glVertex3f(-3.0, -1.2, 0.0)
        glVertex3f(3.0, -1.2, 0.0)
        glVertex3f(3.0, 1.2, 0.0)
        glVertex3f(-3.0, 1.2, 0.0)
        
        # Topo
        glVertex3f(-3.0, -1.2, 2.5)
        glVertex3f(3.0, -1.2, 2.5)
        glVertex3f(3.0, 1.2, 2.5)
        glVertex3f(-3.0, 1.2, 2.5)
        
        # Lados
        glVertex3f(-3.0, -1.2, 0.0)
        glVertex3f(-3.0, -1.2, 2.5)
        glVertex3f(-3.0, 1.2, 2.5)
        glVertex3f(-3.0, 1.2, 0.0)
        
        glVertex3f(3.0, -1.2, 0.0)
        glVertex3f(3.0, 1.2, 0.0)
        glVertex3f(3.0, 1.2, 2.5)
        glVertex3f(3.0, -1.2, 2.5)
        
        # Frente e trás
        glVertex3f(-3.0, -1.2, 0.0)
        glVertex3f(3.0, -1.2, 0.0)
        glVertex3f(3.0, -1.2, 2.5)
        glVertex3f(-3.0, -1.2, 2.5)
        
        glVertex3f(-3.0, 1.2, 0.0)
        glVertex3f(-3.0, 1.2, 2.5)
        glVertex3f(3.0, 1.2, 2.5)
        glVertex3f(3.0, 1.2, 0.0)
        
        glEnd()
        
        # Rodas do ônibus
        glColor3f(0.1, 0.1, 0.1)
        self._render_wheel(-2.0, -1.3, 0.0)
        self._render_wheel(0.0, -1.3, 0.0)
        self._render_wheel(2.0, -1.3, 0.0)
        self._render_wheel(-2.0, 1.3, 0.0)
        self._render_wheel(0.0, 1.3, 0.0)
        self._render_wheel(2.0, 1.3, 0.0)
    
    def _render_truck(self):
        """Renderiza um caminhão"""
        # Cabine
        glBegin(GL_QUADS)
        glVertex3f(-2.0, -1.0, 0.0)
        glVertex3f(-0.5, -1.0, 0.0)
        glVertex3f(-0.5, 1.0, 0.0)
        glVertex3f(-2.0, 1.0, 0.0)
        
        glVertex3f(-2.0, -1.0, 1.8)
        glVertex3f(-0.5, -1.0, 1.8)
        glVertex3f(-0.5, 1.0, 1.8)
        glVertex3f(-2.0, 1.0, 1.8)
        glEnd()
        
        # Carroceria
        glBegin(GL_QUADS)
        glVertex3f(-0.5, -1.0, 0.0)
        glVertex3f(2.5, -1.0, 0.0)
        glVertex3f(2.5, 1.0, 0.0)
        glVertex3f(-0.5, 1.0, 0.0)
        
        glVertex3f(-0.5, -1.0, 1.5)
        glVertex3f(2.5, -1.0, 1.5)
        glVertex3f(2.5, 1.0, 1.5)
        glVertex3f(-0.5, 1.0, 1.5)
        glEnd()
    
    def _render_wheel(self, x, y, z):
        """Renderiza uma roda"""
        glPushMatrix()
        glTranslatef(x, y, z)
        
        # Roda simples como cilindro baixo
        sides = 12
        radius = 0.3
        height = 0.2
        
        glBegin(GL_POLYGON)
        for i in range(sides):
            angle = 2.0 * math.pi * i / sides
            glVertex3f(radius * math.cos(angle), radius * math.sin(angle), height)
        glEnd()
        
        glPopMatrix()

class VehicleManager:
    def __init__(self):
        self.vehicles = []
        self.spawn_timer = 0.0
        self.spawn_interval = 2.0  # Segundos entre spawns
        
    def update(self, dt, traffic_lights_state=None):
        """Atualiza todos os veículos"""
        self.spawn_timer += dt
        
        # Spawnar novos veículos
        if self.spawn_timer >= self.spawn_interval:
            self.spawn_timer = 0.0
            self._spawn_vehicle()
        
        # Atualizar veículos existentes
        self.vehicles = [v for v in self.vehicles if v.update(dt, traffic_lights_state)]
    
    def _spawn_vehicle(self):
        """Cria novos veículos"""
        # Pontos de spawn corrigidos para mão correta
        spawn_points = [
            # Rua principal (Leste-Oeste) - MÃO DUPLA
            (-70, -2, 0, 0),    # Vindo do oeste, indo para leste (faixa sul)
            (70, 2, 0, 180),    # Vindo do leste, indo para oeste (faixa norte)
            
            # Rua secundária (Norte) - MÃO ÚNICA vindo do norte
            (-2, 50, 0, 270),   # Vindo do norte, indo para sul (faixa oeste)
            (2, 50, 0, 270),    # Vindo do norte, indo para sul (faixa leste)
        ]
        
        if len(self.vehicles) < 12:  # Limite de veículos
            x, y, z, direction = random.choice(spawn_points)
            
            # Tipo de veículo aleatório
            vehicle_types = ["car"] * 8 + ["bus"] * 1 + ["truck"] * 1
            vehicle_type = random.choice(vehicle_types)
            
            speed = random.uniform(8.0, 15.0)  # Velocidade variável
            
            vehicle = Vehicle(x, y, z, direction, speed, vehicle_type)
            self.vehicles.append(vehicle)
    
    def render(self):
        """Renderiza todos os veículos"""
        for vehicle in self.vehicles:
            vehicle.render()
    
    def get_vehicle_count(self):
        """Retorna número de veículos na cena"""
        return len(self.vehicles)