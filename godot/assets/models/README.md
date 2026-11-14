# Model swap

Runtime dinosaurs are built in code from `shared/data/dinosaurs.json` (`build` block: body size, neck, tail, horns, plates, stance).

To replace a species with a real mesh later:

1. Export a glTF/GLB that faces -Z, stands on y = 0, and uses roughly the same height as the procedural model (about 1.5–3 m).
2. Put it at `res://assets/models/<dino_id>.glb` (for example `trex.glb`).
3. `scripts/dino/dino_builder.gd` already checks `res://assets/models/<id>.glb` and uses it for the living dinosaur. The dig clues and the museum ghost stay procedural so the puzzle bone ids (`skull`, `torso`, `tail`, `leg_l`, `leg_r`, and `frill` / `plates` / `neck` / `arm`) keep working. Give the glTF its own walk, eat, and roar animations if you want those to replace the procedural bob.

The web prototype mirrors the same JSON in `web/src/dino.js`. Update both builders, or generate the glTF once and load it in both engines.

No third-party meshes are shipped. Everything currently on screen is procedural.
