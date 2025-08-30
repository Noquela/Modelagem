"""
Simulador de Tráfego 3D - Aplicação Principal
Sistema completo de simulação de tráfego com IA comportamental e renderização 3D
"""
import sys
import os

# Adicionar o diretório pai ao path para imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pygame
import numpy as np
import time
from typing import List, Dict, Any

# Importações do simulador
from traffic_simulator.core.engine import Engine3D
from traffic_simulator.core.camera import OrbitalCamera  
from traffic_simulator.core.scene import Scene3D
from traffic_simulator.core.simple_renderer import SimpleRenderer
from traffic_simulator.entities.car import Car
from traffic_simulator.entities.traffic_light import TrafficLightSystem
from traffic_simulator.systems.spawn_system import SpawnSystem
from traffic_simulator.systems.ai_system import AISystem
from traffic_simulator.utils.config import RENDER_CONFIG, UI_CONFIG


class TrafficSimulator3D:
    """Classe principal do simulador de tráfego 3D."""
    
    def __init__(self):
        """Inicializa o simulador."""
        print("Initializing Traffic Simulator 3D...")
        
        # Core systems
        self.engine = Engine3D(
            width=RENDER_CONFIG['window_width'],
            height=RENDER_CONFIG['window_height'],
            title="Traffic Simulator 3D - Python Edition"
        )
        
        self.camera = OrbitalCamera()
        self.scene = Scene3D(self.engine.ctx)
        self.simple_renderer = SimpleRenderer(self.engine.ctx)
        
        # Traffic systems
        self.traffic_lights = TrafficLightSystem()
        self.spawn_system = SpawnSystem()
        self.ai_system = AISystem()
        
        # Game state
        self.cars: List[Car] = []
        self.running = True
        self.paused = False
        self.show_debug = UI_CONFIG['show_debug_info']
        
        # Timing
        self.start_time = time.time()
        self.last_update = time.time()
        self.frame_count = 0
        
        # Statistics
        self.stats = {
            'cars_spawned': 0,
            'cars_despawned': 0,
            'total_simulation_time': 0.0,
            'average_fps': 0.0,
        }
        
        # UI font (simplified - would need proper font rendering)
        self.font_size = UI_CONFIG['font_size']
        
        print("Traffic Simulator 3D initialized successfully!")
        print("Controls:")
        print("  Mouse: Rotate camera around intersection")
        print("  Mouse Wheel: Zoom in/out")
        print("  WASD: Move camera target")
        print("  QE: Move camera up/down")  
        print("  SPACE: Pause/Resume simulation")
        print("  R: Reset camera")
        print("  F1: Toggle debug info")
        print("  ESC: Exit")
    
    def run(self):
        """Loop principal do simulador."""
        print("Starting simulation loop...")
        
        while self.running:
            dt = self._calculate_delta_time()
            
            # Handle events
            if not self._handle_events():
                break
            
            # Update simulation
            if not self.paused:
                self._update_simulation(dt)
            
            # Update camera
            self.camera.update(dt)
            
            # Render frame
            self._render_frame()
            
            # Update statistics
            self._update_statistics()
            
            # Present frame
            self.engine.present()
            
            self.frame_count += 1
        
        # Cleanup
        self._cleanup()
        print("Simulation ended.")
    
    def _calculate_delta_time(self) -> float:
        """Calcula delta time para frame independente."""
        current_time = time.time()
        dt = current_time - self.last_update
        self.last_update = current_time
        
        # Limitar delta time para evitar jumps grandes
        return min(dt, 1.0 / 30.0)  # Máximo 30 FPS mínimo
    
    def _handle_events(self) -> bool:
        """
        Processa eventos do sistema.
        
        Returns:
            False se deve sair do loop principal
        """
        # Eventos base do engine
        if not self.engine.handle_events():
            return False
        
        # Eventos específicos
        for event in pygame.event.get():
            # Camera events
            self.camera.handle_mouse_button(event)
            self.camera.handle_mouse_motion(event) 
            self.camera.handle_mouse_wheel(event)
            self.camera.handle_keyboard(event)
            
            # Keyboard events
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    return False
                elif event.key == pygame.K_SPACE:
                    self.paused = not self.paused
                    print(f"Simulation {'paused' if self.paused else 'resumed'}")
                elif event.key == pygame.K_r:
                    self.camera.reset()
                    print("Camera reset")
                elif event.key == pygame.K_F1:
                    self.show_debug = not self.show_debug
                    print(f"Debug info {'enabled' if self.show_debug else 'disabled'}")
                elif event.key == pygame.K_F2:
                    self._reset_simulation()
                    print("Simulation reset")
        
        return True
    
    def _update_simulation(self, dt: float):
        """Atualiza lógica da simulação."""
        # Update traffic lights
        self.traffic_lights.update(dt)
        
        # Update cars
        lights_for_cars = self.traffic_lights.get_lights()  # Convert for car AI
        for car in self.cars[:]:  # Copy list to allow removal during iteration
            car.update(dt, lights_for_cars, self.cars)
            
            # Remove cars that left the scene
            if car.is_out_of_bounds():
                self.cars.remove(car)
                self.stats['cars_despawned'] += 1
        
        # Spawn new cars
        new_cars = self.spawn_system.update(dt, self.cars, lights_for_cars)
        self.cars.extend(new_cars)
        self.stats['cars_spawned'] += len(new_cars)
        
        # AI system analysis
        self.ai_system.update(self.cars, lights_for_cars)
        
        # Apply AI recommendations (optional)
        if len(self.cars) > 20:  # Only optimize when there are many cars
            affected = self.ai_system.apply_recommendations(self.cars)
            if affected > 0 and self.show_debug:
                print(f"AI optimized {affected} cars")
    
    def _render_frame(self):
        """Renderiza frame atual."""
        # Clear buffers
        self.engine.clear()
        
        # Set camera matrices
        view_matrix = self.camera.get_view_matrix()
        self.engine.set_view_matrix(view_matrix)
        
        # Use simple renderer
        self.simple_renderer.render_roads(view_matrix, self.engine.projection_matrix)
        self.simple_renderer.render_traffic_lights(self.traffic_lights, view_matrix, self.engine.projection_matrix)
        self.simple_renderer.render_cars(self.cars, view_matrix, self.engine.projection_matrix)
        
        # Render UI
        if self.show_debug:
            self._render_debug_ui()
    
    def _render_traffic_lights(self):
        """Renderiza semáforos."""
        for light in self.traffic_lights.get_lights():
            # Get light data
            model_matrix = light.get_model_matrix()
            
            # For now, create simple shader uniforms
            uniforms = {
                'lightPos': self.scene.main_light['position'],
                'lightColor': self.scene.main_light['color'],
                'lightIntensity': self.scene.main_light['intensity'],
                'viewPos': self.camera.get_position(),
            }
            
            # Would need VAO creation here - simplified for now
            # self.engine.render_object(light_vao, model_matrix, 'basic', uniforms)
    
    def _render_cars(self):
        """Renderiza carros usando instanced rendering para performance."""
        if not self.cars:
            return
        
        # Preparar dados para instanced rendering
        instance_matrices = []
        instance_colors = []
        
        for car in self.cars:
            # Only render cars visible to camera
            if self.camera.is_point_visible(car.physics.position):
                instance_matrices.append(car.get_model_matrix().flatten())
                instance_colors.extend(car.get_color())
        
        if not instance_matrices:
            return
        
        # Convert to numpy arrays
        matrices_array = np.array(instance_matrices, dtype=np.float32)
        colors_array = np.array(instance_colors, dtype=np.float32).reshape(-1, 3)
        
        # For simplified implementation, render cars individually
        # In full implementation, would use instanced rendering
        for i, car in enumerate(self.cars):
            if not self.camera.is_point_visible(car.physics.position):
                continue
            
            model_matrix = car.get_model_matrix()
            
            uniforms = {
                'lightPos': self.scene.main_light['position'],
                'lightColor': self.scene.main_light['color'],
                'lightIntensity': self.scene.main_light['intensity'],
                'viewPos': self.camera.get_position(),
            }
            
            # Would render car VAO here
            # self.engine.render_object(car_vao, model_matrix, 'basic', uniforms)
    
    def _render_debug_ui(self):
        """Renderiza interface de debug."""
        # Get statistics
        ai_metrics = self.ai_system.global_metrics
        spawn_stats = self.spawn_system.get_statistics()
        traffic_debug = self.traffic_lights.get_debug_info()
        engine_stats = self.engine.get_render_stats()
        
        # Prepare debug text (simplified)
        debug_lines = [
            f"=== TRAFFIC SIMULATOR 3D DEBUG ===",
            f"Time: {time.time() - self.start_time:.1f}s",
            f"FPS: {engine_stats['fps']:.1f}",
            f"",
            f"=== TRAFFIC ===",
            f"Cars: {len(self.cars)}",
            f"Spawned: {self.stats['cars_spawned']}",
            f"Despawned: {self.stats['cars_despawned']}",
            f"",
            f"=== TRAFFIC LIGHTS ===",
            f"Main Road: {traffic_debug.get('main_road_state', 'N/A')}",
            f"One Way: {traffic_debug.get('one_way_state', 'N/A')}",
            f"Cycle Phase: {traffic_debug.get('cycle_phase', 0):.2f}",
            f"",
            f"=== AI SYSTEM ===",
        ]
        
        if ai_metrics:
            debug_lines.extend([
                f"Avg Speed: {ai_metrics.get('average_speed', 0):.3f}",
                f"Congestion: {ai_metrics.get('congestion_level', 0):.1%}",
                f"Efficiency: {ai_metrics.get('intersection_efficiency', 0):.1%}",
                f"Collisions: {ai_metrics.get('potential_collisions', 0)}",
            ])
        
        debug_lines.extend([
            f"",
            f"=== RENDERING ===",
            f"Draw Calls: {engine_stats['draw_calls']}",
            f"Vertices: {engine_stats['vertices_rendered']}",
            f"",
            f"=== CAMERA ===",
            f"Position: {self.camera.get_position()}",
            f"Distance: {self.camera.distance:.1f}",
        ])
        
        # In a full implementation, would render text to screen
        # For now, could print to console periodically
        if self.frame_count % 60 == 0:  # Every 60 frames
            print("\n" + "\n".join(debug_lines))
    
    def _update_statistics(self):
        """Atualiza estatísticas globais."""
        current_time = time.time()
        self.stats['total_simulation_time'] = current_time - self.start_time
        
        if self.frame_count > 0:
            self.stats['average_fps'] = self.frame_count / self.stats['total_simulation_time']
    
    def _reset_simulation(self):
        """Reseta simulação para estado inicial."""
        # Clear cars
        self.cars.clear()
        
        # Reset systems
        self.traffic_lights.reset_cycle()
        self.spawn_system.reset_statistics()
        self.ai_system.reset_history()
        
        # Reset stats
        self.stats = {
            'cars_spawned': 0,
            'cars_despawned': 0,
            'total_simulation_time': 0.0,
            'average_fps': 0.0,
        }
        
        self.start_time = time.time()
        self.frame_count = 0
        
        print("Simulation reset to initial state")
    
    def _cleanup(self):
        """Limpa recursos ao sair."""
        print("Cleaning up resources...")
        
        # Cleanup systems
        self.scene.cleanup()
        self.traffic_lights.cleanup()
        
        # Cleanup engine
        self.engine.cleanup()
        
        print("Cleanup completed")


def main():
    """Função principal."""
    print("=" * 50)
    print("Traffic Simulator 3D - Python Edition")
    print("Advanced 3D Traffic Simulation with AI")
    print("=" * 50)
    print()
    
    try:
        # Check dependencies
        print("Checking dependencies...")
        import moderngl
        import pygame
        import numpy
        print("OK All dependencies available")
        print()
        
        # Create and run simulator
        simulator = TrafficSimulator3D()
        simulator.run()
        
    except ImportError as e:
        print(f"ERROR Missing dependency: {e}")
        print()
        print("Please install required packages:")
        print("pip install moderngl pygame numpy pyrr")
        return 1
    
    except Exception as e:
        print(f"ERROR during simulation: {e}")
        import traceback
        traceback.print_exc()
        return 1
    
    print()
    print("Thank you for using Traffic Simulator 3D!")
    return 0


if __name__ == "__main__":
    exit(main())