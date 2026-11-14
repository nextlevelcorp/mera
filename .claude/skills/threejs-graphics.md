<!--
Summary written for Mera from https://github.com/scottstts/Threejs-Awesome-Graphics-Agent-Skills at
commit 53eb5a2 (skills: threejs-skill-router, threejs-water-optics, threejs-spectral-ocean,
threejs-visual-validation, threejs-exposure-color-grading, threejs-bloom,
threejs-atmosphere-aerial-perspective, threejs-shadow-systems), and the core rule of
https://github.com/majidmanzarpour/threejs-game-skills (skills/threejs-aaa-graphics-builder) at commit
8286774, fetched 2026-11-14. Copyright (c) 2026 Scott Sun and (c) 2026 Majid Manzarpour, MIT License.
Paraphrased. Full skills: clone the repositories and read skills/<name>/SKILL.md.
See THIRD_PARTY_NOTICES.md.
-->

# Graphics: scene, materials, shaders, lighting, post-processing

Read for: 3D scenes, materials, shaders, water, sky, lighting, shadows, tone mapping, bloom.

**Mera context.** Mera is a Godot 4.4 project (GL Compatibility, single-threaded web export). The
principles below are written for Three.js but hold for Godot shaders too. A move of the renderer to
Three.js is an engine change and needs the owner's decision first (CLAUDE.md: scope and dependencies).

## Order of work

1. **Visual contract first**: subject, scale, camera distance, motion, frame budget.
2. **Authored form before effects**: silhouette and shapes, then materials, then lighting, then
   effects, then the final image treatment. Glow does not rescue primitive shapes.
3. **Camera**: decide framing, lens and transitions before shading details that depend on them.
4. **Lighting and shadows, atmosphere** only after silhouettes and material masks read without effects.
5. **Image pipeline last**: exposure, tone mapping, grading, bloom; load only the effects needed.
6. Never answer "make it prettier" with post-processing alone; find the missing authored system.
7. Prefer one strong, inspectable visual rule over several unrelated noise layers.
8. Keep object-space, world-space and screen-space systems separate unless the design couples them.

## Water (Mera's most visible surface)

- Define wave bands and evaluate displacement; derive normals analytically from the same waves, so
  the normal motion agrees with the crests.
- Say whether the water is displaced geometry or normal-only.
- Blend reflection and refraction with a Fresnel term; derive foam and glints from the same wave
  response, not from an unrelated scrolling texture.
- Filter wave bands too small for the pixel (derivative-based), or micro-waves alias into sparkle.
- Disclose approximations: heuristic refraction, absorption without true depth.
- Large oceans: spectrum-based (FFT) cascades with disjoint wavelength bands, breaking from the
  horizontal-displacement Jacobian. Expensive; check the phone budget before choosing it.

## Sky and atmosphere

- Small scene, ground camera: an analytic height and distance approximation is enough.
- Sky colour, sun colour and distance haze use the same sun direction and coefficients.
- Do not hide a wrong radiance scale with exposure.

## Shadows

- Snap shadow projections to their texel grid to stop shimmering; scale normal bias with texel size.
- Update distant cascades on a budget; refresh near ones continuously.

## Exposure, tone mapping, bloom

- Tone mapping happens once (materials or post, never both); sRGB encoding happens once.
- Exposure adaptation is asymmetric (eyes adapt faster to light than to dark).
- Bloom works on HDR values before tone mapping; choose which values bloom; calibrate threshold and
  radius independent of resolution; bloom never creates the only visible form of an effect.

## Validation (evidence, not taste)

- Fixed camera and seed for every comparison; capture a no-post baseline next to the final image.
- Near, design and far camera views; at least one stress seed or parameter extreme.
- Check motion and temporal stability with a short sequence, not one frame.
- Record frame time and render-target inventory; on Mera, measure average and worst 1% fps before and
  after every visual feature (CLAUDE.md).
