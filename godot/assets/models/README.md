# Dinosaur models

Living dinosaurs are CC0 Grab3D sculpts, decimated to about 11,000 triangles and rigged in this project. Each `<id>.glb` has clips named `idle`, `walk`, `eat`, and `roar`. `<id>_skeleton.glb` is the same sculpt split into puzzle regions (`skull__part`, `torso__part`, `leg_l__part`, and so on) for the museum.

`scripts/dino/dino_builder.gd` loads these files. If a file is missing, it falls back to the capsule builder.

Sources, the decimation note, and the Poly Haven terrain textures are in `docs/ASSET_LICENSES.md`.
