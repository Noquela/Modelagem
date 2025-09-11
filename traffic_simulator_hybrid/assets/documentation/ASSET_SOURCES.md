# 3D Traffic Simulator - Asset Sources & Acquisition Guide

## Overview
This document contains comprehensive information about high-quality CC0/free 3D assets for the traffic intersection simulator in Godot.

## 🚗 VEHICLES (CC0/Free Use)

### Primary Source: Kenney.nl Car Kit
- **URL**: https://kenney.nl/assets/car-kit
- **License**: Creative Commons CC0 (Public Domain)
- **Version**: 2.0 (Released 01/05/2024)
- **Contents**: 45 files including various car models
- **Format**: 3D models (compatible with Godot)
- **Attribution**: Not required but appreciated

### Secondary Source: Poly Haven Covered Car
- **URL**: https://polyhaven.com/a/covered_car  
- **License**: CC0
- **Polygons**: 12,592
- **Available Resolutions**: 1K, 2K, 4K, 8K
- **Format**: GLTF/GLB
- **Download Links**:
  - 2K: https://dl.polyhaven.org/file/ph-assets/Models/gltf/2k/covered_car/covered_car_2k.gltf
  - 4K: https://dl.polyhaven.org/file/ph-assets/Models/gltf/4k/covered_car/covered_car_4k.gltf

### Alternative: Sketchfab Free Low Poly Vehicles Pack
- **URL**: https://sketchfab.com/3d-models/free-low-poly-vehicles-pack-cb7640039e7a40679a53be705ebff50e
- **License**: CC Attribution (requires credit to RgsDev)
- **Contents**: 
  - 4 Police cars (Sedan, Sports, Muscle, SUV)
  - 1 Sedan, 1 SUV, 1 Hatchback
  - Additional: Pickup, Van, Ambulance, etc.
- **Specs**: 39.6k Triangles, 26k Vertices
- **Features**: Game-ready, separated wheels, customizable colors

## 🚦 TRAFFIC LIGHTS

### Primary Sources:
1. **Free3D** (Manual download required)
   - URL: https://free3d.com/3d-models/traffic-light
   - 11+ free traffic light models
   - Formats: .blend .obj .c4d .3ds .max .ma

2. **TurboSquid**
   - URL: https://www.turbosquid.com/Search/3D-Models/free/traffic-light
   - 1300+ free models
   - High quality for games/VFX

3. **RigModels**
   - Multiple formats including GLB
   - OBJ, FBX, STL, DAE, GLB formats
   - Unity/Blender/Maya ready

## 🛣️ ROAD TEXTURES & ENVIRONMENT

### Poly Haven - Asphalt Textures
- **Primary Asset**: Asphalt 02
- **URL**: https://polyhaven.com/a/asphalt_02
- **License**: CC0
- **Author**: Rob Tuytel  
- **Dimensions**: 3m x 3m
- **Resolutions**: 1K, 2K, 4K, 8K
- **PBR Maps Available**:
  - Diffuse
  - Normal (DirectX and OpenGL)
  - Roughness
  - Ambient Occlusion (AO)
  - Displacement
  - ARM (Ambient, Roughness, Metallic)
- **Formats**: EXR, PNG, JPG, Blender, glTF, MaterialX
- **Tags**: asphalt, cracked, road, weathered, grey

### Additional Poly Haven Resources
- **General Textures**: https://polyhaven.com/textures
- **Road Category**: https://polyhaven.com/textures/road
- **Asphalt Category**: https://polyhaven.com/textures/asphalt

## 🎨 UI ASSETS

### Kenney UI Pack
- **URL**: https://kenney.nl/assets/ui-pack
- **License**: Creative Commons CC0
- **Version**: 2.0 (Released 12/06/2024 - completely remade)
- **Contents**: 430+ PNG sprites
- **Includes**: 
  - Buttons, sliders, panels
  - 2 full TTF fonts
  - 6 UI sound effects
- **Attribution**: "Kenney.nl" or "www.kenney.nl" appreciated but not required

### Kenney Game Icons
- **URL**: https://kenney.nl/assets/game-icons
- **License**: Creative Commons CC0
- **Contents**: Various game interface icons
- **Format**: PNG sprites

## 📁 RECOMMENDED FOLDER STRUCTURE

```
assets/
├── vehicles/
│   ├── sedans/
│   ├── suvs/
│   └── hatchbacks/
├── environment/
│   ├── roads/
│   ├── traffic_lights/
│   └── signs/
├── textures/
│   ├── roads/
│   └── vehicles/
├── ui/
│   ├── icons/
│   └── panels/
└── audio/
    ├── engine/
    └── ui/
```

## 🎯 DOWNLOAD PRIORITIES

### Phase 1: Essential Assets
1. Kenney Car Kit (CC0 vehicles)
2. Poly Haven Asphalt 02 texture
3. Kenney UI Pack
4. Basic traffic light from Free3D/TurboSquid

### Phase 2: Enhancement Assets
1. Additional vehicle variations
2. More road/environment textures
3. Street signs and furniture
4. Sound effects

## ⚖️ LICENSE SUMMARY

### CC0 (No Attribution Required)
- Kenney.nl assets
- Poly Haven assets
- Selected Sketchfab CC0 models

### CC Attribution (Credit Required)
- Sketchfab RgsDev vehicle pack
- Some Free3D models

### Royalty-Free
- Most TurboSquid free models
- Some CGTrader free models

## 🔧 GODOT COMPATIBILITY NOTES

### Preferred Formats:
- **3D Models**: .gltf/.glb (best), .obj, .fbx
- **Textures**: .png, .jpg (diffuse), .exr (HDR)
- **Audio**: .ogg, .wav

### Optimization Recommendations:
- Keep car models under 10K triangles for performance
- Use 2K textures for most assets (4K for hero assets only)
- Implement LOD (Level of Detail) for distant objects
- Use texture atlases where possible

## 📝 ATTRIBUTION REQUIREMENTS

When using CC Attribution licensed assets, include in your project credits:
- "Vehicle models by RgsDev (Sketchfab)"
- Any other non-CC0 assets with their respective creators

## 🔄 UPDATES

Last updated: September 1, 2025
Asset research completed: All primary sources identified and verified