from direct.showbase.ShowBase import ShowBase
from direct.task import Task
from panda3d.core import *
from direct.gui.OnscreenText import OnscreenText
from direct.gui.DirectGui import *
import sys
import math

from intersection import Intersection

class SimulationApp(ShowBase):
    def __init__(self):
        ShowBase.__init__(self)
        
        self.paused = False
        self.fast_forward = False
        self.time_scale = 1.0
        
        self.intersection = Intersection(self.render)
        
        self.setup_camera()
        self.setup_lighting()
        self.setup_keyboard()
        self.setup_ui()
        
        self.taskMgr.add(self.update_simulation, "update_simulation")
        
        print("Traffic Light Intersection Simulation")
        print("Controls:")
        print("  P - Pause/Unpause")
        print("  R - Reset simulation")
        print("  F - Fast forward toggle")
        print("  C - Toggle free camera")
        print("  WASD - Move camera (when enabled)")
        print("  Mouse - Look around (when enabled)")
        print("  Q/E - Move up/down")
        print("  Shift - Fast movement")
        print("  1-5 - Spawn rate")
        print("  ESC - Exit")
    
    def setup_camera(self):
        # Create camera orbit system
        self.camera_pivot = self.render.attachNewNode("camera_pivot")
        self.camera_pivot.setPos(0, 0, 5)  # Center of intersection, slightly elevated
        
        # Set initial camera position relative to pivot
        self.cam.reparentTo(self.camera_pivot)
        self.cam.setPos(0, -50, 30)
        self.cam.lookAt(self.camera_pivot)
        
        self.camLens.setFov(60)
        
        # Camera orbit variables
        self.camera_distance = 50.0
        self.camera_height = 30.0
        self.camera_rotation_h = 0
        self.camera_rotation_p = -35
        
        # Mouse control state
        self.mouse_enabled = False
        self.right_mouse_down = False
        self.middle_mouse_down = False
        
        # Movement speed
        self.orbit_speed = 100.0
        self.pan_speed = 20.0
        self.zoom_speed = 20.0
        
        # Disable default mouse controls
        self.disableMouse()
        
        # Hide mouse cursor when controlling
        from panda3d.core import WindowProperties
        self.win_props = WindowProperties()
        
        # Start camera control task
        self.taskMgr.add(self.camera_control_task, "camera_control")
    
    def setup_lighting(self):
        # Clear any existing lights
        self.render.clearLight()
        
        # Set sky blue background color
        self.setBackgroundColor(0.5, 0.7, 1.0, 1.0)
        
        # Add fog for depth
        fog = Fog("fog")
        fog.setColor(0.6, 0.7, 0.8)
        fog.setExpDensity(0.002)
        self.render.setFog(fog)
        
        # Stronger ambient light for better visibility
        alight = AmbientLight('ambientLight')
        alight.setColor((0.6, 0.6, 0.6, 1))
        alightNP = self.render.attachNewNode(alight)
        self.render.setLight(alightNP)
        
        # Main sun light
        dlight = DirectionalLight('sun')
        dlight.setDirection(Vec3(-0.5, -0.5, -1))
        dlight.setColor((1.0, 0.95, 0.8, 1))
        dlight.setShadowCaster(True, 2048, 2048)
        dlightNP = self.render.attachNewNode(dlight)
        self.render.setLight(dlightNP)
        
        # Secondary fill light
        dlight2 = DirectionalLight('fill')
        dlight2.setDirection(Vec3(0.5, 0.5, -0.3))
        dlight2.setColor((0.3, 0.35, 0.4, 1))
        dlightNP2 = self.render.attachNewNode(dlight2)
        self.render.setLight(dlightNP2)
        
        # Enable auto shader for better graphics
        self.render.setShaderAuto()
        
        # Add a ground plane for better visual reference
        self.create_ground_plane()
    
    def setup_keyboard(self):
        # Simulation controls
        self.accept('p', self.toggle_pause)
        self.accept('r', self.reset_simulation)
        self.accept('f', self.toggle_fast_forward)
        self.accept('escape', self.exit_simulation)
        
        self.accept('1', self.set_spawn_rate, [0.1])
        self.accept('2', self.set_spawn_rate, [0.3])
        self.accept('3', self.set_spawn_rate, [0.5])
        self.accept('4', self.set_spawn_rate, [0.7])
        self.accept('5', self.set_spawn_rate, [0.9])
        
        # Mouse controls for camera
        self.accept('mouse2', self.set_right_mouse, [True])  # Right mouse button
        self.accept('mouse2-up', self.set_right_mouse, [False])
        self.accept('mouse3', self.set_middle_mouse, [True])  # Middle mouse button
        self.accept('mouse3-up', self.set_middle_mouse, [False])
        self.accept('wheel_up', self.zoom_in)
        self.accept('wheel_down', self.zoom_out)
        
        # Arrow keys for camera rotation
        self.accept('arrow_left', self.rotate_camera_left)
        self.accept('arrow_right', self.rotate_camera_right)
        self.accept('arrow_up', self.rotate_camera_up)
        self.accept('arrow_down', self.rotate_camera_down)
    
    def setup_ui(self):
        self.title_text = OnscreenText(
            text="Traffic Light Intersection Simulation",
            pos=(0, 0.9),
            scale=0.06,
            fg=(1, 1, 1, 1),
            align=TextNode.ACenter,
            mayChange=1
        )
        
        self.controls_text = OnscreenText(
            text="P: Pause | R: Reset | F: Fast Forward | 1-5: Spawn Rate | ESC: Exit",
            pos=(0, -0.9),
            scale=0.04,
            fg=(0.8, 0.8, 0.8, 1),
            align=TextNode.ACenter,
            mayChange=1
        )
        
        self.camera_help_text = OnscreenText(
            text="Camera: Right Mouse + Drag = Orbit | Middle Mouse + Drag = Pan | Scroll = Zoom | Arrows = Rotate",
            pos=(0, -0.95),
            scale=0.03,
            fg=(0.6, 0.8, 1, 1),
            align=TextNode.ACenter,
            mayChange=1
        )
        
        self.stats_text = OnscreenText(
            text="",
            pos=(-0.95, 0.8),
            scale=0.04,
            fg=(1, 1, 1, 1),
            align=TextNode.ALeft,
            mayChange=1
        )
        
        self.status_text = OnscreenText(
            text="Running",
            pos=(0.95, 0.9),
            scale=0.05,
            fg=(0, 1, 0, 1),
            align=TextNode.ARight,
            mayChange=1
        )
    
    def update_simulation(self, task):
        if not self.paused:
            dt = globalClock.getDt() * self.time_scale
            self.intersection.update(dt)
        
        self.update_ui()
        
        return task.cont
    
    def update_ui(self):
        stats = self.intersection.get_statistics()
        
        status = "PAUSED" if self.paused else ("FAST FORWARD" if self.fast_forward else "RUNNING")
        color = (1, 1, 0, 1) if self.paused else ((0, 1, 1, 1) if self.fast_forward else (0, 1, 0, 1))
        self.status_text.setText(status)
        self.status_text.setFg(color)
        
        stats_text = f"""TRAFFIC STATISTICS:

Cars Passed:
  Main St East: {stats['cars_passed_by_lane']['main_east']}
  Main St West: {stats['cars_passed_by_lane']['main_west']}
  Secondary St: {stats['cars_passed_by_lane']['secondary']}

Currently Waiting:
  Main St East: {stats['cars_waiting_by_lane']['main_east']}
  Main St West: {stats['cars_waiting_by_lane']['main_west']}
  Secondary St: {stats['cars_waiting_by_lane']['secondary']}

Max Queue Lengths:
  Main St East: {stats['max_queue_by_lane']['main_east']}
  Main St West: {stats['max_queue_by_lane']['main_west']}
  Secondary St: {stats['max_queue_by_lane']['secondary']}

Total Statistics:
  Cars Spawned: {stats['total_spawned']}
  Cars Completed: {stats['total_completed']}
  Total Waiting: {stats['total_cars_waiting']}
  Avg Wait Time: {stats['average_wait_time']:.1f}s"""
        
        self.stats_text.setText(stats_text)
    
    def toggle_pause(self):
        self.paused = not self.paused
        print(f"Simulation {'paused' if self.paused else 'resumed'}")
    
    def reset_simulation(self):
        self.intersection.reset()
        self.paused = False
        self.fast_forward = False
        self.time_scale = 1.0
        print("Simulation reset")
    
    def toggle_fast_forward(self):
        self.fast_forward = not self.fast_forward
        self.time_scale = 3.0 if self.fast_forward else 1.0
        print(f"Fast forward {'enabled' if self.fast_forward else 'disabled'}")
    
    def set_spawn_rate(self, rate):
        self.intersection.set_spawn_rate(rate)
        print(f"Spawn rate set to {rate}")
    
    def exit_simulation(self):
        print("Exiting simulation...")
        self.intersection.cleanup()
        sys.exit()
    
    def set_right_mouse(self, state):
        self.right_mouse_down = state
        if state:
            self.win_props.setCursorHidden(True)
            self.win.requestProperties(self.win_props)
        else:
            self.win_props.setCursorHidden(False)
            self.win.requestProperties(self.win_props)
    
    def set_middle_mouse(self, state):
        self.middle_mouse_down = state
        if state:
            self.win_props.setCursorHidden(True)
            self.win.requestProperties(self.win_props)
        else:
            self.win_props.setCursorHidden(False)
            self.win.requestProperties(self.win_props)
    
    def zoom_in(self):
        self.camera_distance = max(10, self.camera_distance - 2)
        self.update_camera_position()
    
    def zoom_out(self):
        self.camera_distance = min(100, self.camera_distance + 2)
        self.update_camera_position()
    
    def rotate_camera_left(self):
        self.camera_rotation_h -= 5
        self.update_camera_position()
    
    def rotate_camera_right(self):
        self.camera_rotation_h += 5
        self.update_camera_position()
    
    def rotate_camera_up(self):
        self.camera_rotation_p = min(-10, self.camera_rotation_p + 2)
        self.update_camera_position()
    
    def rotate_camera_down(self):
        self.camera_rotation_p = max(-80, self.camera_rotation_p - 2)
        self.update_camera_position()
    
    def update_camera_position(self):
        # Convert spherical coordinates to cartesian
        rad_h = self.camera_rotation_h * (3.14159 / 180)
        rad_p = self.camera_rotation_p * (3.14159 / 180)
        
        x = self.camera_distance * math.sin(rad_h) * math.cos(rad_p)
        y = -self.camera_distance * math.cos(rad_h) * math.cos(rad_p)
        z = -self.camera_distance * math.sin(rad_p)
        
        self.cam.setPos(x, y, z)
        self.cam.lookAt(self.camera_pivot)
    
    def create_ground_plane(self):
        from panda3d.core import CardMaker
        
        # Create a large ground plane
        cm = CardMaker("ground")
        cm.setFrame(-100, 100, -100, 100)
        ground = self.render.attachNewNode(cm.generate())
        ground.setP(-90)  # Rotate to be horizontal
        ground.setZ(-0.5)  # Place below roads
        ground.setColor(0.3, 0.5, 0.3, 1)  # Green grass color
        
        # Add some surrounding area cards for visual interest
        for x in [-50, 50]:
            for y in [-50, 50]:
                cm_area = CardMaker(f"area_{x}_{y}")
                cm_area.setFrame(-20, 20, -20, 20)
                area = self.render.attachNewNode(cm_area.generate())
                area.setPos(x, y, -0.4)
                area.setP(-90)
                area.setColor(0.35, 0.55, 0.35, 1)
    
    def camera_control_task(self, task):
        if self.mouseWatcherNode.hasMouse():
            mouse_x = self.mouseWatcherNode.getMouseX()
            mouse_y = self.mouseWatcherNode.getMouseY()
            
            # Orbit camera with right mouse button
            if self.right_mouse_down:
                if hasattr(self, 'last_mouse_x'):
                    delta_x = mouse_x - self.last_mouse_x
                    delta_y = mouse_y - self.last_mouse_y
                    
                    self.camera_rotation_h += delta_x * self.orbit_speed
                    self.camera_rotation_p -= delta_y * self.orbit_speed * 0.5
                    
                    # Clamp vertical rotation
                    self.camera_rotation_p = max(-80, min(-10, self.camera_rotation_p))
                    
                    self.update_camera_position()
                
                self.last_mouse_x = mouse_x
                self.last_mouse_y = mouse_y
            
            # Pan camera with middle mouse button  
            elif self.middle_mouse_down:
                if hasattr(self, 'last_mouse_x'):
                    delta_x = mouse_x - self.last_mouse_x
                    delta_y = mouse_y - self.last_mouse_y
                    
                    # Move the pivot point
                    right = self.cam.getNetTransform().getMat().getRow3(0)
                    forward = self.cam.getNetTransform().getMat().getRow3(1)
                    
                    pivot_pos = self.camera_pivot.getPos()
                    pivot_pos -= right * delta_x * self.pan_speed
                    pivot_pos -= forward * delta_y * self.pan_speed
                    self.camera_pivot.setPos(pivot_pos)
                
                self.last_mouse_x = mouse_x
                self.last_mouse_y = mouse_y
            
            else:
                # Reset last mouse position when no button is pressed
                if hasattr(self, 'last_mouse_x'):
                    del self.last_mouse_x
                if hasattr(self, 'last_mouse_y'):
                    del self.last_mouse_y
        
        return task.cont

def main():
    app = SimulationApp()
    app.run()