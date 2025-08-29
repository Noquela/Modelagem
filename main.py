#!/usr/bin/env python3
"""
Traffic Light Intersection Simulation
=====================================

A complete 3D traffic intersection simulation using Panda3D with:
- Synchronized traffic lights for main and secondary streets
- Realistic car spawning and movement with collision avoidance
- Queue formation and traffic flow statistics
- Interactive controls for pause, reset, and speed adjustment

Requirements:
- Python 3.6+
- panda3d

Installation:
    pip install panda3d

Usage:
    python main.py

Controls:
    P - Pause/Unpause simulation
    R - Reset simulation
    F - Fast forward toggle
    1-5 - Set spawn rate (1=low, 5=high)
    ESC - Exit

Author: Traffic Simulation System
"""

if __name__ == "__main__":
    try:
        from simulation_app import main
        main()
    except ImportError as e:
        print(f"Error importing required modules: {e}")
        print("Please install Panda3D: pip install panda3d")
    except KeyboardInterrupt:
        print("\nSimulation interrupted by user")
    except Exception as e:
        print(f"An error occurred: {e}")
        import traceback
        traceback.print_exc()