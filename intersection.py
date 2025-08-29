import random
import time
from panda3d.core import *
from traffic_light import TrafficLight
from car import Car

class Intersection:
    def __init__(self, render):
        self.render = render
        
        self.traffic_lights = {}
        self.cars = []
        self.completed_cars = []
        
        # Inicia com rua principal verde e secundária vermelha
        self.main_street_cycle_time = 0.0
        
        self.green_time = 10.0
        self.yellow_time = 2.0  # Amarelo mais curto e realista
        self.cycle_time = self.green_time + self.yellow_time
        
        self.spawn_probability = 0.1  # MUITO menor para reduzir filas
        self.last_spawn_times = {
            "main_east": 0.0,
            "main_west": 0.0,
            "secondary": 0.0
        }
        self.spawn_interval = 4.0  # Mais tempo entre spawns
        
        self.stats = {
            "cars_passed": {"main_east": 0, "main_west": 0, "secondary": 0},
            "cars_waiting": {"main_east": 0, "main_west": 0, "secondary": 0},
            "max_queue_length": {"main_east": 0, "main_west": 0, "secondary": 0},
            "total_cars_spawned": 0,
            "total_cars_completed": 0
        }
        
        self.setup_traffic_lights()
        self.create_road_visual()
    
    def setup_traffic_lights(self):
        # Semáforo 1 - Controla tráfego vindo do LESTE (rua principal)
        self.traffic_lights["main_east"] = TrafficLight(
            self.render, 
            (-8, -2, 0), 
            rotation=90  # Olhando para oeste
        )
        
        # Semáforo 2 - Controla tráfego vindo do OESTE (rua principal)
        self.traffic_lights["main_west"] = TrafficLight(
            self.render, 
            (8, 2, 0), 
            rotation=-90  # Olhando para leste
        )
        
        # Semáforo 3 - Controla tráfego da rua secundária (mão única)
        self.traffic_lights["secondary"] = TrafficLight(
            self.render, 
            (2, -8, 0), 
            rotation=0  # Olhando para norte
        )
        
        # Inicializa todos em vermelho
        for light in self.traffic_lights.values():
            light.set_state("red")
    
    def create_road_visual(self):
        road_texture = None
        try:
            road_texture = loader.loadTexture("textures/road.png")
        except:
            pass
        
        from panda3d.core import CardMaker
        
        # Main street (East-West) - horizontal plane - MAIS COMPRIDA
        cm_main = CardMaker("main_street")
        cm_main.setFrame(-100, 100, -5, 5)  # Alongou de -30,30 para -100,100
        main_street = self.render.attachNewNode(cm_main.generate())
        main_street.setP(-90)  # Rotate to be horizontal
        main_street.setZ(-0.1)
        main_street.setColor(0.3, 0.3, 0.3, 1)
        if road_texture:
            main_street.setTexture(road_texture)
        
        # Secondary street (North-South) - horizontal plane - MAIS COMPRIDA
        cm_secondary = CardMaker("secondary_street")
        cm_secondary.setFrame(-5, 5, -100, 100)  # Alongou de -30,30 para -100,100
        secondary_street = self.render.attachNewNode(cm_secondary.generate())
        secondary_street.setP(-90)  # Rotate to be horizontal
        secondary_street.setZ(-0.1)
        secondary_street.setColor(0.3, 0.3, 0.3, 1)
        if road_texture:
            secondary_street.setTexture(road_texture)
        
        self.create_lane_markings()
    
    def create_lane_markings(self):
        line_positions = [
            # Linhas centrais das ruas
            ((-100, -2.5, 0.05), (200, 0.2, 0.1)),  # Linha central horizontal
            ((-100, 2.5, 0.05), (200, 0.2, 0.1)),   # Linha central horizontal
            ((-2.5, -100, 0.05), (0.2, 200, 0.1)),  # Linha central vertical
            ((2.5, -100, 0.05), (0.2, 200, 0.1)),   # Linha central vertical
            
            # Linhas de parada dos semáforos (mais visíveis)
            ((-10, -5, 0.06), (0.5, 10, 0.1)),      # Linha de parada leste
            ((10, -5, 0.06), (0.5, 10, 0.1)),       # Linha de parada oeste  
            ((-5, -10, 0.06), (10, 0.5, 0.1)),      # Linha de parada sul
        ]
        
        from panda3d.core import CardMaker
        
        for i, (pos, scale) in enumerate(line_positions):
            cm = CardMaker("line")
            cm.setFrame(-0.5, 0.5, -0.5, 0.5)
            line = self.render.attachNewNode(cm.generate())
            
            line.setPos(*pos)
            line.setScale(*scale)
            
            # Linhas centrais = amarelo, linhas de parada = branco
            if i < 4:
                line.setColor(1, 1, 0, 1)  # Amarelo para linhas centrais
            else:
                line.setColor(1, 1, 1, 1)  # Branco para linhas de parada
    
    def update(self, dt):
        current_time = time.time()
        
        self.update_traffic_lights(dt)
        self.spawn_cars(current_time)
        self.update_cars(dt, current_time)
        self.update_statistics()
    
    def update_traffic_lights(self, dt):
        self.main_street_cycle_time += dt
        
        # Ciclo total = verde + amarelo + verde + amarelo = 2 * (verde + amarelo)
        total_cycle = (self.green_time + self.yellow_time) * 2
        
        current_phase = self.main_street_cycle_time % total_cycle
        
        # PRIMEIRA METADE DO CICLO: Rua principal verde, secundária vermelha
        if current_phase < self.green_time:
            # Rua principal: VERDE
            main_state = "green"
            secondary_state = "red"
        elif current_phase < self.green_time + self.yellow_time:
            # Rua principal: AMARELO
            main_state = "yellow"
            secondary_state = "red"
        # SEGUNDA METADE DO CICLO: Rua principal vermelha, secundária verde
        elif current_phase < (self.green_time + self.yellow_time) + self.green_time:
            # Rua secundária: VERDE
            main_state = "red"
            secondary_state = "green"
        else:
            # Rua secundária: AMARELO
            main_state = "red"
            secondary_state = "yellow"
        
        # Atualiza os 3 semáforos de forma sincronizada
        self.traffic_lights["main_east"].set_state(main_state)
        self.traffic_lights["main_west"].set_state(main_state)
        self.traffic_lights["secondary"].set_state(secondary_state)
        
        # Semáforos atualizados silenciosamente
    
    def spawn_cars(self, current_time):
        spawn_configs = {
            "main_east": ((-80, -1, 0), (80, -1, 0)),  # Spawn bem longe do cruzamento
            "main_west": ((80, 1, 0), (-80, 1, 0)),     # Spawn bem longe do cruzamento  
            "secondary": ((1, -80, 0), (1, 80, 0))      # Spawn bem longe do cruzamento
        }
        
        for lane, (spawn_pos, target_pos) in spawn_configs.items():
            if (current_time - self.last_spawn_times[lane]) > self.spawn_interval:
                if random.random() < self.spawn_probability:
                    car = Car(self.render, lane, spawn_pos, target_pos)
                    self.cars.append(car)
                    self.last_spawn_times[lane] = current_time
                    self.stats["total_cars_spawned"] += 1
    
    def update_cars(self, dt, current_time):
        cars_to_remove = []
        
        for car in self.cars:
            if car.active:
                light_state = self.get_traffic_light_state_for_lane(car.lane)
                car.update(dt, light_state, self.cars, current_time)
            
            # Se o carro chegou no final, remove da simulação
            if not car.active:
                if car not in self.completed_cars:
                    self.completed_cars.append(car)
                    self.stats["cars_passed"][car.lane] += 1
                    self.stats["total_cars_completed"] += 1
                
                # Limpa o modelo visual do carro
                car.cleanup()
                cars_to_remove.append(car)
        
        # Remove carros inativos da lista principal
        for car in cars_to_remove:
            if car in self.cars:
                self.cars.remove(car)
    
    def get_traffic_light_state_for_lane(self, lane):
        if lane in ["main_east", "main_west"]:
            return self.traffic_lights["main_east"].get_state()
        else:
            return self.traffic_lights["secondary"].get_state()
    
    def update_statistics(self):
        for lane in self.stats["cars_waiting"].keys():
            waiting_count = 0
            for car in self.cars:
                if car.active and car.lane == lane and car.waiting:
                    waiting_count += 1
            
            self.stats["cars_waiting"][lane] = waiting_count
            self.stats["max_queue_length"][lane] = max(
                self.stats["max_queue_length"][lane], 
                waiting_count
            )
    
    def get_statistics(self):
        total_waiting = sum(self.stats["cars_waiting"].values())
        avg_wait_time = 0
        
        if self.completed_cars:
            total_wait = sum(car.get_total_wait_time() for car in self.completed_cars)
            avg_wait_time = total_wait / len(self.completed_cars)
        
        return {
            "cars_passed_by_lane": self.stats["cars_passed"],
            "cars_waiting_by_lane": self.stats["cars_waiting"],
            "total_cars_waiting": total_waiting,
            "max_queue_by_lane": self.stats["max_queue_length"],
            "average_wait_time": avg_wait_time,
            "total_spawned": self.stats["total_cars_spawned"],
            "total_completed": self.stats["total_cars_completed"]
        }
    
    def reset(self):
        for car in self.cars:
            car.cleanup()
        self.cars.clear()
        self.completed_cars.clear()
        
        # Reset para começar com rua principal verde
        self.main_street_cycle_time = 0.0
        
        self.stats = {
            "cars_passed": {"main_east": 0, "main_west": 0, "secondary": 0},
            "cars_waiting": {"main_east": 0, "main_west": 0, "secondary": 0},
            "max_queue_length": {"main_east": 0, "main_west": 0, "secondary": 0},
            "total_cars_spawned": 0,
            "total_cars_completed": 0
        }
        
        self.last_spawn_times = {
            "main_east": 0.0,
            "main_west": 0.0,
            "secondary": 0.0
        }
    
    def set_spawn_rate(self, probability):
        self.spawn_probability = max(0.0, min(1.0, probability))
    
    def set_timing(self, green_time, yellow_time):
        self.green_time = green_time
        self.yellow_time = yellow_time
        self.cycle_time = green_time + yellow_time
    
    def cleanup(self):
        for car in self.cars:
            car.cleanup()
        for light in self.traffic_lights.values():
            light.cleanup()