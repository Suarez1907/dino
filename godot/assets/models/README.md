# Dinosaur models

Living dinosaurs and museum skeletons are glTF files in this folder. They are generated from `web/src/dino_rig.js`:

```bash
cd web
node scripts/export_dinos.mjs
```

Each `<id>.glb` is a skinned mesh with clips named `idle`, `walk`, `eat`, and `roar`, plus a `body_lod` mesh used on the Low graphics setting. `<id>_skeleton.glb` is the museum assembly. Mesh names start with the puzzle bone id (`skull__0`, `leg_l__3`, and so on).

`scripts/dino/dino_builder.gd` loads these files. If a file is missing, it falls back to the older capsule builder.

The meshes face -Z and stand on y = 0. They are original CC0 work. Sources and the Poly Haven terrain textures are in `docs/ASSET_LICENSES.md`.
