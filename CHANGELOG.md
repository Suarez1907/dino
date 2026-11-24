# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-01-XX

### Added
- Full 3D redesign with Blender-generated assets (dinosaurs, tools, excavation layers, museum modules)
- Procedural excavation sites with 6-layer soil physics (grass, humus, clay, sand, rock, fossil layer)
- Real-time heightmap-based digging with voxel material removal
- 3D fossil puzzle assembly with snap-to-socket system
- Dinosaur animation system: skeleton → skin → living creature with AnimationTree state machine
- Tool upgrade system (4 tiers per tool: brush, chisel, detector, camera)
- Research tree unlocking new biomes, dinosaurs, and excavation bonuses
- Photo mode with depth-of-field, filters, and gallery sharing for science points
- Visitor AI in museum with navmesh navigation
- Mobile-optimized rendering: Triplanar PBR shaders, LOD, VRAM texture compression
- Save/load system preserving full game state (sites, progress, tools, research, photos)
- GitHub Actions CI pipeline: validation → Blender asset generation → Godot 4.8 export → APK

### Changed
- Migrated from Godot 4.7 to 4.8
- Complete 3D pipeline replacing 2D/3D hybrid scenes
- Main scene restructured: World3D root with Camera3D SpringArm follow
- Player controller rewritten for 3D movement (WASD + mouse look)
- Terrain system now shader-based with Triplanar mapping and runtime heightmap updates
- Audio bus layout expanded: Master/Tools/Ambient/UI/Voice

### Fixed
- Asset import pipeline now properly handles PBR materials, animations, and collision meshes
- Excavation performance optimized for >50 FPS on mid-range mobile devices
