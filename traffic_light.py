from panda3d.core import *

class TrafficLight:
    def __init__(self, render, position, rotation=0):
        self.render = render
        self.position = position
        self.rotation = rotation
        
        self.state = "red"  # red, yellow, green
        self.state_time = 0.0
        
        self.green_duration = 10.0
        self.yellow_duration = 2.0
        self.red_duration = 12.0
        
        self.root_node = None
        self.lights = {}
        
        self.create_visual()
    
    def create_visual(self):
        self.root_node = self.render.attachNewNode("traffic_light")
        self.root_node.setPos(*self.position)
        self.root_node.setH(self.rotation)
        
        from panda3d.core import CardMaker
        
        cm_pole = CardMaker("pole")
        cm_pole.setFrame(-0.1, 0.1, 0, 4)
        pole = self.root_node.attachNewNode(cm_pole.generate())
        pole.setColor(0.4, 0.4, 0.4, 1)
        
        cm_box = CardMaker("light_box")
        cm_box.setFrame(-0.5, 0.5, -1.5, 1.5)
        light_box = self.root_node.attachNewNode(cm_box.generate())
        light_box.setZ(4.5)
        light_box.setColor(0.2, 0.2, 0.2, 1)
        
        self.create_light_bulbs()
        self.update_light_visual()
    
    def create_light_bulbs(self):
        from panda3d.core import CardMaker
        colors = [("red", (1, 0, 0, 1)), ("yellow", (1, 1, 0, 1)), ("green", (0, 1, 0, 1))]
        positions = [1, 0, -1]
        
        for i, (color_name, color) in enumerate(colors):
            cm = CardMaker(f"light_{color_name}")
            cm.setFrame(-0.3, 0.3, -0.3, 0.3)
            light_sphere = self.root_node.attachNewNode(cm.generate())
            
            light_sphere.setZ(4.5 + positions[i])
            light_sphere.setY(0.2)
            light_sphere.setColor(*color)
            self.lights[color_name] = light_sphere
    
    def update_light_visual(self):
        for color_name, light_node in self.lights.items():
            if color_name == self.state:
                light_node.setColorScale(1, 1, 1, 1)
            else:
                light_node.setColorScale(0.3, 0.3, 0.3, 1)
    
    def update(self, dt):
        self.state_time += dt
        
        if self.state == "green" and self.state_time >= self.green_duration:
            self.change_state("yellow")
        elif self.state == "yellow" and self.state_time >= self.yellow_duration:
            self.change_state("red")
        elif self.state == "red" and self.state_time >= self.red_duration:
            self.change_state("green")
    
    def change_state(self, new_state):
        self.state = new_state
        self.state_time = 0.0
        self.update_light_visual()
    
    def set_state(self, new_state):
        if new_state != self.state:
            self.change_state(new_state)
    
    def get_state(self):
        return self.state
    
    def is_go(self):
        return self.state == "green"
    
    def is_caution(self):
        return self.state == "yellow"
    
    def is_stop(self):
        return self.state == "red"
    
    def cleanup(self):
        if self.root_node:
            self.root_node.removeNode()