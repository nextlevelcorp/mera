<!--
Compiled for Mera on 2026-11-14 from general knowledge of glTF Transform (https://gltf-transform.dev,
Don McCurdy, MIT License). Check the installed version's CLI help before running commands.
-->

# glTF Transform: 3D model optimisation (.glb / .gltf)

Read for: importing, compressing, inspecting or fixing 3D models for the web build.

**Mera context.** Godot imports glTF 2.0 natively, so optimised GLB files serve the current Godot build
and a possible Three.js build alike. The CLI is a new tool dependency: run it with an exact pinned
version (`npx @gltf-transform/cli@<version>`), and add it to CI only with the owner's approval. Every
model's source and licence goes into `docs/reference_docs.md` before the file is committed.

## Inspect first

`gltf-transform inspect model.glb` lists meshes, vertex counts, materials, textures with sizes and
formats, and animations. Record the numbers before and after every step.

## Typical pipeline (one step at a time, re-inspect after each)

1. `dedup`: merge duplicate accessors, materials, meshes, textures.
2. `prune`: remove unused nodes, materials, textures, accessors.
3. `weld`, then `simplify --ratio <r> --error <e>` for over-dense meshes; check silhouettes after.
4. `resample` and drop static channels for animations.
5. `instance` for repeated meshes (rocks, bollards, bridge lamps).
6. Geometry compression: `meshopt` (fast decode, good for the web) or `draco` (smaller, slower
   decode, needs a decoder). Godot imports Draco and meshopt-compressed glTF only with the matching
   support; check the Godot version before choosing, or keep geometry uncompressed for Godot.
7. Textures: resize to the size actually seen on a phone (`resize --width 1024 --height 1024`),
   then `webp` or `ktx2` (`uastc` for normal maps, `etc1s` for colour) where the engine supports it.
8. `optimize` runs a sensible combination of the above in one command; still inspect the result.

## Budgets (mid-range phone, single-threaded web)

- Keep the whole scene's draw calls and triangle count measured; prefer few materials and atlases.
- Texture memory matters more than file size; a 4096 px texture is rarely justified on a phone.
- Measure frame time (average and worst 1%) before and after adding a model (CLAUDE.md).

## Rules

- Keep the original source file outside the export (or in a separate source folder) and commit only
  the optimised result plus the exact command used.
- Collision uses simple proxy shapes, never the visual mesh (see `rapier.md`).
- Units are metres, +Y up, consistent scale across models.
