<!--
Compiled for Mera on 2026-11-14 from general knowledge of Rapier (https://rapier.rs, Dimforge,
Apache License 2.0) and the physics reference of https://github.com/majidmanzarpour/threejs-game-skills
(skills/threejs-gameplay-systems/references/physics-engine-selection.md, commit 8286774, MIT,
paraphrased). Check the installed package version and its docs before writing code.
Not to be confused with the "Rapier" document-editor plugin in this environment.
-->

# Rapier physics (Three.js integration) and collisions

Read for: physics, rigid bodies, colliders, sensors, collisions, a physics-based line or lure.

**Mera context.** Mera runs on Godot 4.4, whose own physics (Godot Physics or Jolt) covers what Rapier
would do. Rapier only enters with an approved move to Three.js. Mera's catch and fight rules stay in
deterministic, seeded `game/sim/` code either way; a physics engine may only drive what is drawn
(line sag, lure splash, a lifted fish), never the outcome of a catch.

## When to use a physics engine

1. Custom collision first: triggers, pickups, simple overlap tests, authored arcs. Most of Mera
   (casting arc, line as a Verlet chain) belongs here.
2. Rapier: real rigid-body simulation, character controllers, fast bodies needing CCD, sensor-heavy
   scenes. Default choice for serious browser physics with Three.js.
3. cannon-es only when avoiding WASM matters and scenes are tiny; Jolt for specific needs; Matter.js
   is 2D only.

## Setup (Three.js)

- Package `@dimforge/rapier3d-compat` (WASM inlined, works on static hosting). Pin an exact version
  (security rule) and add it only with the owner's approval (new dependency).
- `await RAPIER.init()` once before creating the world; `new RAPIER.World({x: 0, y: -9.81, z: 0})`.
- Fixed timestep with an accumulator and a clamped frame time (for example 1/60 s steps, frame time
  clamped to 0.1 s); never step with the raw frame delta.

## Bodies and colliders

- Dynamic bodies for simulated objects, kinematic for scripted movers, fixed for the level.
- Collide against primitive, compound or convex-hull colliders, never detailed visual meshes. Imported
  GLB models get separate simple collision proxies.
- Set friction, restitution, damping, density, gravity scale and collision groups explicitly, in
  units that match the scene scale (metres).
- Fast small bodies (a lure in flight) need CCD enabled, or they tunnel.
- Sensors fire nothing unless active collision events are enabled on the collider; this is the most
  common trigger bug. Read events from an event queue after each step.

## Architecture

- Physics lives in one system (`PhysicsWorld`); render code never steps or edits bodies.
- Copy body transforms to meshes in exactly one place, after the step.
- Update order: input, fixed physics steps, game state, VFX and camera and UI, render.
- Remove bodies and colliders on restart; let idle bodies sleep.
- Keep a debug overlay: collider shapes, body and contact counts, velocities. Gate it out of release.

## Determinism

Rapier is deterministic for the same inputs, build and step order on one platform, but cross-platform
float determinism is not guaranteed. Never let a catch outcome depend on it.

## Report

Engine and version, body and collider counts, timestep, CCD bodies, sensors, collision groups, and
frame-time cost before and after on the test phones.
