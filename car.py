import random
from panda3d.core import *

class Car:
    def __init__(self, render, lane, spawn_pos, target_pos, color=None):
        self.render = render
        self.lane = lane  # "main_east", "main_west", "secondary"
        self.spawn_pos = Vec3(*spawn_pos)
        self.target_pos = Vec3(*target_pos)
        self.position = Vec3(*spawn_pos)
        
        self.base_speed = 12.0  # ~43 km/h mais realista
        self.current_speed = 0.0  # Começa parado
        self.max_speed = self.base_speed
        self.max_acceleration = 2.5  # m/s² - aceleração realista
        self.comfortable_deceleration = 3.5  # m/s² - desaceleração confortável
        self.emergency_deceleration = 8.0  # m/s² - frenagem de emergência
        
        self.length = 4.5  # metros - tamanho realista de carro
        self.width = 1.8   # metros
        self.safe_distance = 3.0  # metros - distância mínima de segurança
        self.reaction_time = 0.8  # segundos - tempo de reação humano
        
        self.waiting = False
        self.wait_start_time = 0.0
        self.total_wait_time = 0.0
        
        self.model = None
        self.active = True
        
        if color is None:
            colors = [(1, 0, 0, 1), (0, 0, 1, 1), (0, 1, 0, 1), (1, 1, 0, 1), (1, 0, 1, 1), (0, 1, 1, 1)]
            self.color = random.choice(colors)
        else:
            self.color = color
        
        self.direction = (self.target_pos - self.spawn_pos).normalized()
        
        self.create_visual()
    
    def create_visual(self):
        from panda3d.core import CardMaker
        
        # Create car as a simple 3D box
        self.model = self.render.attachNewNode("car_model")
        
        # Create main body (horizontal rectangle)
        cm = CardMaker("car_body")
        cm.setFrame(-self.length/2, self.length/2, -self.width/2, self.width/2)
        body = self.model.attachNewNode(cm.generate())
        body.setP(-90)  # Rotate to be horizontal
        body.setZ(0.25)  # Lift off ground
        
        # Add a top to make it look 3D
        cm_top = CardMaker("car_top")
        cm_top.setFrame(-self.length/2, self.length/2, -self.width/2, self.width/2)
        top = self.model.attachNewNode(cm_top.generate())
        top.setP(-90)
        top.setZ(0.7)
        
        # Add windshield indicator (front)
        cm_wind = CardMaker("windshield")
        cm_wind.setFrame(-self.width/2, self.width/2, 0.3, 0.6)
        windshield = self.model.attachNewNode(cm_wind.generate())
        windshield.setY(self.length/2 - 0.3)
        windshield.setColor(0.3, 0.3, 0.3, 1)
        
        self.model.setPos(self.position)
        self.model.setColor(*self.color)
        
        # Set orientation based on travel direction  
        if abs(self.direction.x) > abs(self.direction.y):
            if self.direction.x > 0:
                self.model.setH(0)  # Moving east
            else:
                self.model.setH(180)  # Moving west
        else:
            if self.direction.y > 0:
                self.model.setH(90)  # Moving north
            else:
                self.model.setH(-90)  # Moving south
    
    def update(self, dt, traffic_light_state, cars_ahead, current_time):
        if not self.active:
            return
        
        old_waiting = self.waiting
        self.waiting = False
        
        distance_to_intersection = self.get_distance_to_intersection()
        
        should_stop = False
        target_speed = self.max_speed
        
        # DETECÇÃO INTELIGENTE DE SEMÁFORO
        if distance_to_intersection > 0 and distance_to_intersection < 50.0:  # Só se não passou ainda
            if traffic_light_state == "red":
                # PARA OBRIGATORIAMENTE quando vermelho (mas só se não passou)
                should_stop = True
                target_speed = 0
            elif traffic_light_state == "yellow":
                # LÓGICA REALISTA DO AMARELO
                # Calcula se dá tempo de parar com segurança
                stopping_distance = (self.current_speed * self.current_speed) / (2 * self.comfortable_deceleration)
                
                if distance_to_intersection > stopping_distance + 5.0:
                    # Longe o suficiente para parar com segurança
                    should_stop = True
                    target_speed = 0
                else:
                    # Muito próximo, melhor passar (como no trânsito real)
                    target_speed = self.max_speed
            elif traffic_light_state == "green":
                # Verde = passa
                target_speed = self.max_speed
        elif distance_to_intersection <= 0:
            # JÁ PASSOU DO SEMÁFORO - não deve mais parar por causa dele
            target_speed = self.max_speed
        
        # Distância de segurança dinâmica baseada na velocidade
        dynamic_safe_distance = self.safe_distance + (self.current_speed * self.reaction_time)
        
        car_ahead_distance = self.get_distance_to_car_ahead(cars_ahead)
        if car_ahead_distance < dynamic_safe_distance:
            should_stop = True
            
            # Se está muito próximo (menos de 2 metros), para completamente
            if car_ahead_distance < 2.0:
                target_speed = 0
            # Se está a uma distância crítica, ajusta velocidade proporcionalmente
            elif car_ahead_distance < dynamic_safe_distance:
                # Velocidade proporcional à distância disponível
                speed_factor = max(0.1, car_ahead_distance / dynamic_safe_distance)
                target_speed = self.max_speed * speed_factor * 0.6
        
        if should_stop:
            self.waiting = True
            if not old_waiting:
                self.wait_start_time = current_time
        else:
            if old_waiting:
                self.total_wait_time += current_time - self.wait_start_time
        
        # Física realista de aceleração/desaceleração
        speed_diff = target_speed - self.current_speed
        
        if abs(speed_diff) > 0.1:  # Se há diferença significativa de velocidade
            if speed_diff > 0:
                # Acelerando
                acceleration = min(self.max_acceleration, speed_diff / dt)
                self.current_speed += acceleration * dt
                self.current_speed = min(self.current_speed, target_speed)
            else:
                # Desacelerando
                if car_ahead_distance < 1.5:  # Situação de emergência
                    deceleration = self.emergency_deceleration
                else:
                    deceleration = self.comfortable_deceleration
                
                deceleration_amount = min(deceleration, abs(speed_diff) / dt)
                self.current_speed -= deceleration_amount * dt
                self.current_speed = max(self.current_speed, target_speed)
        
        self.current_speed = max(0, self.current_speed)
        
        movement = self.direction * self.current_speed * dt
        self.position += movement
        self.model.setPos(self.position)
        
        if self.has_reached_target():
            self.active = False
    
    def get_distance_to_intersection(self):
        # Pontos de parada ANTES do cruzamento - linha de retenção
        if self.lane == "main_east":
            # Carros vindo do leste param em X = -10 
            stop_line = Vec3(-10, self.position.y, 0)
            # Se já passou do semáforo (X > -10), retorna distância negativa
            if self.position.x > -10:
                return -1.0  # Já passou, não deve parar mais
        elif self.lane == "main_west":
            # Carros vindo do oeste param em X = +10
            stop_line = Vec3(10, self.position.y, 0)
            # Se já passou do semáforo (X < 10), retorna distância negativa   
            if self.position.x < 10:
                return -1.0  # Já passou, não deve parar mais
        elif self.lane == "secondary":
            # Carros vindo do sul param em Y = -10
            stop_line = Vec3(self.position.x, -10, 0)
            # Se já passou do semáforo (Y > -10), retorna distância negativa  
            if self.position.y > -10:
                return -1.0  # Já passou, não deve parar mais
        else:
            return float('inf')
        
        return (self.position - stop_line).length()
    
    def get_distance_to_car_ahead(self, cars_ahead):
        min_distance = float('inf')
        closest_car = None
        
        for car in cars_ahead:
            if car.lane == self.lane and car != self and car.active:
                if self.is_car_ahead(car):
                    # Calcular distância entre as bordas dos carros, não centros
                    distance = (self.position - car.position).length()
                    # Subtrair o comprimento dos carros para distância bumper-to-bumper
                    bumper_distance = distance - (self.length/2 + car.length/2)
                    
                    if bumper_distance < min_distance:
                        min_distance = bumper_distance
                        closest_car = car
        
        return max(0, min_distance) if min_distance != float('inf') else float('inf')
    
    def is_car_ahead(self, other_car):
        to_other = other_car.position - self.position
        dot_product = to_other.dot(self.direction)
        
        # Verifica se está na mesma faixa (tolerância para Y ou X dependendo da direção)
        if self.lane in ["main_east", "main_west"]:
            # Rua horizontal - verifica se Y é similar
            same_lane = abs(self.position.y - other_car.position.y) < 3.0
        else:
            # Rua vertical - verifica se X é similar  
            same_lane = abs(self.position.x - other_car.position.x) < 3.0
        
        return dot_product > 0 and same_lane
    
    def has_reached_target(self):
        distance_to_target = (self.position - self.target_pos).length()
        return distance_to_target < 5.0  # Aumentei a distância para remover antes de chegar no final
    
    def get_total_wait_time(self):
        current_wait = 0
        if self.waiting and self.wait_start_time > 0:
            import time
            current_wait = time.time() - self.wait_start_time
        return self.total_wait_time + current_wait
    
    def cleanup(self):
        if self.model:
            self.model.removeNode()
            self.model = None
        self.active = False