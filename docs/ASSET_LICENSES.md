# Asset licenses

The five living dinosaurs are CC0 sculpts from Grab3D, decimated to about 11,000 triangles and rigged in this project with idle, walk, eat, and roar. Museum pieces are the same meshes split by body region and shaded as fossils. Terrain colors and the sky are CC0 photographs and an HDRI from Poly Haven.

CC0 does not require credit. The in-game credits screen still names these sources.

## Grab3D dinosaurs

Each living file started as the publisher’s light GLB (about 1K textures, no rig). This project decimated it, added a skeleton, and authored the four clips. License: [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).

| File | Grab3D model | Page |
| --- | --- | --- |
| `godot/assets/models/trex.glb` | Realistic T-Rex | https://grab3d.com/models/creatures/realistic-t-rex/ |
| `godot/assets/models/triceratops.glb` | Triceratops | https://grab3d.com/models/creatures/triceratops/ |
| `godot/assets/models/stegosaurus.glb` | Stegosaurus | https://grab3d.com/models/creatures/stegosaurus/ |
| `godot/assets/models/brachiosaurus.glb` | Brachiosaurus | https://grab3d.com/models/creatures/brachiosaurus/ |
| `godot/assets/models/velociraptor.glb` | Velociraptor | https://grab3d.com/models/creatures/velociraptor/ |
| `godot/assets/models/*_skeleton.glb` | Same sculpt, split into the dig puzzle regions and shaded as fossil | same pages |

Downloaded 14 November 2026 with no login:

- `https://grab3d.com/dl/realistic-t-rex/realistic-t-rex-light.glb`
- `https://grab3d.com/dl/triceratops/triceratops-light.glb`
- `https://grab3d.com/dl/stegosaurus/stegosaurus-light.glb`
- `https://grab3d.com/dl/brachiosaurus/brachiosaurus-light.glb`
- `https://grab3d.com/dl/velociraptor/velociraptor-light.glb`

The source models are static. Idle, walk, eat, and roar were authored here so the animals keep the Grab3D silhouette while the reveal scene can play those four actions.

## Poly Haven terrain and sky

Poly Haven assets are CC0. Authors and files:

| File in `godot/assets/textures/` | Poly Haven asset | Maps | Author |
| --- | --- | --- | --- |
| `sand.jpg` | [aerial_sand](https://polyhaven.com/a/aerial_sand) | Diffuse, 1k JPG | Rob Tuytel |
| `sand_n.jpg` | [aerial_sand](https://polyhaven.com/a/aerial_sand) | Normal (GL), 1k JPG | Rob Tuytel |
| `grass.jpg` | [forest_floor](https://polyhaven.com/a/forest_floor) | Diffuse, 1k JPG | Dimitrios Savva |
| `rock.jpg` | [rocky_terrain_02](https://polyhaven.com/a/rocky_terrain_02) | Diffuse, 1k JPG | Rob Tuytel |
| `snow.jpg` | [snow_02](https://polyhaven.com/a/snow_02) | Diffuse, 1k JPG | Rob Tuytel |
| `sky.hdr` | [kloofendal_48d_partly_cloudy_puresky](https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky) | HDRI, 1k | Greg Zaal |

The ground shader blends sand, grass, rock, and snow from height, slope, and biome. Dig holes drop the heightmap so the pit floor reads as darker soil and the walls read as rock. `sand_n.jpg` is the matching normal map kept beside the diffuse; the runtime blend uses the diffuse maps plus roughness from slope.

Downloaded from `https://dl.polyhaven.org` on 14 November 2026. Poly Haven’s license page: https://polyhaven.com/license

## Still from the rest of the project

Nunito (SIL OFL 1.1), the MIT game code, and the CC0 procedural icons and runtime audio are listed in [LICENSES.md](LICENSES.md).
