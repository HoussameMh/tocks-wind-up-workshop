# Art Bible: Tock's Wind-Up Workshop

Status: approved directly by the user on 2026-11-05 and implemented. The tables below are the starting values; section 8 lists where the shipped values differ and is authoritative. Tune on screenshots at 1280x720.
Supersedes "chunky low-poly, saturated, bright" in `design/game-brief.md`.

**Verification tags.** `[R]` in `docs/engine-reference/godot/`. `[C]` already runs in this project's code. `[W]` **NOT VERIFIED** in engine-reference; Godot 4.7 web docs support it (read via search summary). `[NV]` **NOT VERIFIED** anywhere: confirm on first run, use the stated fallback. The engine reference has almost no Compatibility-specific feature data, so most renderer claims are `[W]`.

## 1. Visual identity
A tiny clockwork toy crossing a real craftsman's workshop at dusk, shot like a miniature under a warm bench lamp.

**Scale law: 1 u = 4 cm.** Bench top 23 u above floor (92 cm). Tock 1.15 u (4.6 cm). Every prop uses its true size; size is the joke, so nothing is enlarged.

**What this cannot achieve (say so, do not chase it):**
- Tock and beetles stay well-made toys: no sculpted face, cloth folds, skinned joints or painted wear. Close-ups read as turned wood and tin.
- Not photoreal. No bounce light, ambient occlusion, real reflections or soft area shadows.
- No true macro blur: depth of field unsupported in Compatibility `[W]`.
- Edges stay jagged: MSAA/TAA excluded by choice; FXAA and SMAA unsupported `[W]`. This is the largest remaining tell.
- Primitive tools read by silhouette at distance, not up close.

**Originality:** no question marks or symbols on any box, no yellow or gold boxes, no green tubes, no mushrooms or spotted domes, no pole-with-flag or pole-with-ball goal or checkpoint.

## 2. Mood and lighting
Dusk outside, workshop lights on. Warm foreground, cool recessive background (complementary contrast does the photographic work).

| Light | Type | Color | Energy | Other |
|---|---|---|---|---|
| Key | DirectionalLight3D `[C]` | `#ffd0a0` | 1.1 | Rot (-60,-60,0), from lamp side; shadow on, orthogonal `[C]` |
| Window fill | DirectionalLight3D, no shadow `[C]` | `#7f9fd6` | 0.22 | Rot (-18,100,0); cool edge on shadow sides |
| Lamp pools x3 | SpotLight3D, no shadow `[W]` | `#ffb56e` | 5.0 | Range 55, angle 55, attenuation 0.5, at z -18, -72, -142, y 24, x -14 |
| Tock follow | OmniLight3D, no shadow `[W]` | `#ffe2c0` | 0.6 | Range 3.5, attenuation 0.5, child of player, y +1.2 |
| Key glow | OmniLight3D, no shadow `[W]` | `#ffb020` | 1.5 | Range 8, attenuation 0.5, at Golden Key |
| Ambient | `AMBIENT_SOURCE_COLOR` `[C]` | `#4f4440` | 0.45 | Shadow floor |

- **Attenuation trap:** default 1.0 loses nearly everything over 25 u (from memory `[NV]`); keep 0.5.
- **Zero shadowed omni/spot.** Each adds passes and blends differently in Compatibility `[W]` (Godot issue #90259: surfaces brighten when shadows enable). Tune with key shadow on.
- **Not used:** AreaLight3D (exists in 4.7 `[R]`, Compatibility support `[NV]`), LightmapGI (geometry is built in code), SSAO (a simplified one exists since 4.6 `[W]`; excluded by project decision), decals (unsupported `[W]`), ReflectionProbe.
- **Sky:** keep `BG_SKY` `[C]` purely as metal reflection source; room is sealed so it is never seen. Top `#1c2433`, horizon `#c4894e`, ground `#20160f`. Radiance size 64 `[NV]`.
- **Tonemap:** ACES `[W]`, exposure 1.0, white 6.0. Fallback Filmic if cap red or brass shift. Not AgX: slowest, and washes out toy color `[W]`.
- **Glow `[W]`:** on, intensity 0.5, bloom 0, HDR threshold 0.95 `[NV]`. Compatibility ignores levels, strength and blend mode `[W]`; processes before tonemap `[R]`. Only lamp bulbs, window, Golden Key, beetle eyes may exceed threshold. First thing cut if FPS falls.
- **Fog `[W]`:** depth, exponential, color `#3a2c26`, density 0.004, sky affect 0 (about 21% at 60 u). No height fog.
- **Adjustments `[W]`:** off in play. Game Over only: saturation to 0.35.
- **Fake occlusion (mandatory, no SSAO):** gradient quads (`GradientTexture2D` radial `[W]`, multiply-dark alpha) under props and along wall bases, merged per zone.
- **Luma targets (screenshot):** bench in pool 0.25-0.45; bench between pools at least 0.12; room floor under 0.10.

## 3. Materials
Rules: tint multiplies, so **never feed JSON palette colors as tints on textured sets** (they would crush the wood to black). `level.gd` maps palette key to material row. Roughness on `R` rows is a multiplier. Metal capped 0.85: reflection source is dim, full metal renders black. One cached material per row; stop allocating one per part as `MeshKit.part` does now. UV = repeats per unit, same meaning as `uv1_scale` in `plank_material` `[C]`.

Tints above 1.0 lift the very dark `wood_table_001` and `metal_plate` `[NV]`; fallback: brighten a copy with `Image.adjust_bcs` at load `[NV]`, or tint 1.0 and more light. **That wood is dark red-brown, so the bench is dark-stained; light oak is not reachable by tint.**

Maps: D diffuse, N normal, R roughness.

| Object (palette key) | Set | Tint | Metal | Rough | UV → u/repeat | Notes |
|---|---|---|---|---|---|---|
| Workbench (`oak`) | wood DNR | (1.5,1.35,1.2) | 0 | R x0.9 | 0.0625 → 16 | Normal 0.5; true furniture scale (64 cm). Random UV offset per bench |
| Light bench (`maple`) | wood DNR | (1.9,1.7,1.45) | 0 | R x0.9 | 0.0625 → 16 | As above |
| Shelf (`walnut`) | wood DNR | (.95,.9,.85) | 0 | R x0.8 | 0.0625 → 16 | Darkest wood |
| Bench edge strip | plain | `#b98a58` | 0 | 0.6 | n/a | 0.06 u worn arris; fakes bevel, marks walkable edge |
| Toy blocks (`red` `blue` `green` `yellow`) | wood N only | `#c8352b` `#2a62b8` `#2f9a58` `#e8b321` | 0 | 0.4 | 0.25 → 4 | Normal 0.25: grain under satin paint |
| Walls (`room_wall`) | plaster DN | `#9aa59b` | 0 | 0.85 | 0.025 → 40 | Muted sage recedes against warm wood |
| Ceiling | plaster D | `#5a564e` | 0 | 0.9 | 0.025 → 40 | New: must seal the sky |
| Room floor (`room_floor`) | concrete D | `#a89c8a` | 0 | 0.9 | 0.02 → 50 | Dark, so gaps read as drops |
| Moving platform (`steel`) | metal_plate DNR | (1.5,1.5,1.4) | 0.6 | R x1 | 0.125 → 8 | Mesh-local UV. Steel edge trim `#c9ced2` |
| Beetle shell | rust DNR | (1.35,1.1,.95) | 0.3 | R x1 | Mesh UV x(2,1) | Normal 0.8. Emission `#5a2410` e0.4 |
| Beetle gear / eyes / legs | plain | `#d8dde0` / `#ff7a1a` / `#2b2523` | .8 / 0 / 0 | .3 / .5 / .7 | n/a | Eyes emission e2.0 |
| Toy box | plain | Body `#b02a6e`, ribbon `#f4e8cf` | 0 | .3 / .6 | n/a | Lacquered gift box. Used: `#77706a`, rough .85, no ribbon |
| Crate | wood DN | Slats (2.1,1.8,1.5), frame (1,.9,.8) | 0 | 0.75 | 0.25 → 4 | Mesh-local UV: it bumps and would swim |
| Cog | plain | `#e8b13a` | 0.55 | 0.32 | n/a | Emission `#7a4a0c` e0.35, never goes dark |
| Tock brass (plate, arms, key) | plain | `#d8a93f` | 0.7 | 0.3 | n/a | Emission `#3a2408` e0.4 |
| Tock overalls | plain | `#25b3ae` | 0 | 0.75 | n/a | Reserved hue |
| Tock cap | plain | `#d43f35` | 0 | 0.4 | n/a | Lacquer |
| Tock head | plain | `#f0c98d` | 0 | 0.45 | n/a | Painted wood |
| Tock eyes | plain | `#f5f1e6`, pupil `#15161a` | 0 | .15 / .1 | n/a | Gloss beads |
| Tock legs | plain | `#aab2ba` | 0.6 | 0.35 | n/a | Replaces `#26282c`, lost on dark wood |
| Coil rings, Coil pickup | plain | `#c7d3dd` | 0.8 | 0.25 | n/a | |
| Spare key pickup | plain | `#4caf6a` | 0.3 | 0.35 | n/a | Emission same hue e0.5 |
| Golden Key | plain | `#ffc83a` | 0.85 | 0.22 | n/a | Emission `#ffb020` e0.8, plus Key glow light |
| Spring pad | plain | Base `#3a3d42`, coil `#c7d3dd`, top `#d9483b` | .5 / .8 / 0 | .5 / .25 / .35 | n/a | Flat top; top emission e0.2 |
| Checkpoint | plain | Base `#d8a93f`; off `#77706a`, on `#4caf6a` e1.5 | .7 / 0 | .3 / .5 | n/a | Stubby 1.6 u pilot lamp; on is also brighter |

**UV method:** world triplanar samples each map 3 times (9 fetches on wood) `[NV]` and swims on moving objects. Bake per-face world-scale UVs into merged box meshes with `SurfaceTool` `[C]` plus generated tangents `[NV]`: 3 fetches, and bench side grain can run lengthwise. Fallback: triplanar on static geometry only `[C]`.

## 4. Scenery
Replaces all current `decor` (giant pencils, pink/blue/red cubes, cylinders).

- **Room:** x -24 to +65, z +24 to -175, y -23 to +47 (3.6 x 8.0 x 2.8 m). Close pegboard wall on the left gives scale in every shot; open dim room and dusk window on the right give depth.
- **Keep-out:** no visual prop where |x| < 16 and -14 < y < +14. Decor has no collision, the camera reaches 15.5 (8.5 u arm past a 14-wide bench), and `kill_height` is -14. Exception: supports directly under platforms.
- **Nothing floats:** benches get legs inset at least 1 u; stair blocks sit on threaded steel rods to the floor; moving platform rides a lead screw (z -52 to -63, below plate); toy boxes and crates hang on dark twine (r 0.025, visual only, no shadow) to a ceiling batten. Hidden boxes show no twine until revealed. Goal plinth stays on the bench.

| Object | True size → u | Build | Draws |
|---|---|---|---|
| Room shell (counted separately) | see above | 4 walls, floor, ceiling | 6 |
| Dusk window (right wall) | 1.2 x 1.5 m → 30 x 38 | Unshaded gradient panel `#7fa4d8` to `#f2a45c`; frame and muntins merged | 2 |
| Rear counter (x -24 to -16, top y -1) | 32 cm deep | Long box, legs merged | 2 |
| Pegboard | wall panels | Boxes, generated 64px dot tile, 0.625 u pitch | 2 |
| Hung tools: hammer, handsaw, 3 wrenches, chisels, square | 8, 15, 6-8, 6, 8 u | Merged per zone: steel, handles | 4 |
| Anglepoise lamps x3 (2 visible) | arms 11 u, shade 5 u | Arms; shade; emissive bulb | 6 |
| Screw jars, 2 groups | 3 u tall, r 1.5 | Glass alpha 0.18; lids; steel screws merged (never brass) | 6 |
| Bench vise | 5 x 6 u | Casting `#4d5a4e`, steel screw | 2 |
| Oil can, spool, tape measure | 4, 2, 2 u | Merged | 3 |
| Bench legs, stair rods, lead screw | | Merged by material | 5 |
| Occlusion quads | | Merged per zone | 2 |
| Far props: tool chest, stool, sawhorse (floor, right) | 8-18 u | Merged, no shadow | 3 |
| Wall clock behind goal (far wall) | r 6 u | Face, hands | 2 |

**Scenery budget: 6 shell + 39 props, with 6 more shadow draws allowed.** Shadows off by default; allowed only on vise, lamp bases, jar lids, never over the course. Scenery color saturation under 35%. Merge by material per zone so frustum culling still works.

## 5. Readability (beats realism on any conflict)
- **Value:** Tock, beetles and pickups at least 2:1 luminance against the local surface in screenshots at z -18, -72, -142. Failing that, change the object, not the surface noise.
- **Saturated color is reserved** for what the player interacts with. Scenery stays muted.
- **Hue ownership:** teal only Tock. Brass-gold only collectibles and Tock; no brass within 16 u of the course. Ember eyes only enemies.
- **Beetle on brown wood is the worst case:** rust matches the bench hue. Fix with ember eyes (glow), bright steel gear on top, and shell emission lift, in that order.
- **Landing blob:** straight-down soft dark quad under Tock and beetles, opacity 0.45, radius 0.45 x model scale, raycast to floor. Decals are unavailable `[W]`. The angled key shadow does not show landing spot.
- **Surface noise:** course normal scale at most 0.5. No scenery shadow may fall on the course.
- **Edges:** every walkable top has a lighter edge strip or trim.
- **Emission:** nothing near the play plane glows except gameplay objects.
- **Color is never the only state cue:** used boxes lose the ribbon; a reached checkpoint gets brighter; cogs and beetles differ in shape.

## 6. Menu and UI
**Palette**

| Role | Hex |
|---|---|
| Ink (scrim, text on brass) | `#140D08` |
| Walnut panel / hover | `#2A1A10` / `#3A2416` |
| Brass highlight / face / deep | `#FFE9A8` / `#E3A42C` / `#8F5A16` |
| Lamp cream (body text) | `#F6E7C8` |
| Muted text | `#BFAE93` |
| Tock teal (sparing accent) | `#2FB8B0` |
| Signal red (danger, low time) | `#D8452F` |

Contrast checked: cream on walnut 13.7:1, muted on walnut 7.8:1, ink on brass 8.8:1.

**Font (decision for the user):** none in project, so default is Open Sans SemiBold `[W]`. Default-font plan below gets clean and premium, not characterful. **One OFL slab display face in `assets/fonts/` would lift the title more than any other single change;** licence check and choice are the user's.

**Title treatment (default font)**
- `FontVariation` `[W]` on `ThemeDB.fallback_font` `[W]`: embolden 0.9, glyph spacing +3, all caps.
- Stack, left aligned, margin 72, y 64-316: `T[cog]CK'S` 64 pt; `WIND-UP` 84 pt; `WORKSHOP` 84 pt. The cog replacing the O is what makes it a logo: a small `Control` drawing a gear in `_draw()`, sized to cap height. Accessible name via `tr()`.
- Cast-brass layers, back to front: shadow `#140D08` (0,6); edge `#8F5A16` (0,3); face vertical gradient `#FFE9A8` to `#E3A42C` to `#B9761A` (canvas shader `[NV]`; fallback flat `#E3A42C`); highlight `#FFF4CF` (0,-1) under the face. `LabelSettings` `[W]` for shadow.
- Tagline 20 pt cream, y 330. No outlines anywhere; the 8 px black outline is the current default look.

**Live 3D behind title**
- Real level, not a backdrop. Replace 360 orbit with a locked macro shot: FOV 38, distance 4.0, height 0.7, pitch 6, yaw sway +/-7 over 16 s, Tock in the right third (`h_offset` `[NV]`). Values go in `gameplay_tuning.json`.
- Pegboard, lamp and bench edge fill the frame behind him. Long lens compresses the background; it cannot blur it.
- Drop the full-screen 55% dim. Left scrim: `GradientTexture2D`, `#140D08` alpha 0.85 at x 0 to alpha 0 at 55% width. Radial vignette corners alpha 0.45.
- Dust motes in lamp light: 30 soft particles, title only, 1 draw (`CPUParticles3D` `[NV]`).
- Lamp energy drift +/-4% below 0.5 Hz.

**Buttons** (one `Theme` resource `[R]` with `StyleBoxFlat` `[NV]`; replace the focus stylebox too; no per-control overrides). 340 x 54, left aligned, 24 pt, corner radius 3 (machined, not pill), margin-left 20.

| State | Fill | Border | Text | Motion |
|---|---|---|---|---|
| Normal | `#2A1A10` alpha .88 | 2 px `#8F5A16` | `#F6E7C8` | Shadow 6 px, black alpha .5 |
| Mouse hover | `#3A2416` | 2 px `#E3A42C` | `#FFE9A8` | Shift +6 x |
| Keyboard/pad focus | `#E3A42C` | 2 px `#FFE9A8` | `#140D08` | Shift +6 x; cog marker left, ticks 45 degrees |
| Pressed | `#8F5A16` | 2 px `#FFE9A8` | `#140D08` | Shift +2 y |

- Hover and focus can sit on different controls `[R]`, so they must differ; test mouse and pad. Button motion via `offset_transform_*` `[R]`, which containers do not reset. Mouse, keyboard and gamepad all required.

**Other screens**
- Pause: same left column slides in over a frozen frame; left scrim only.
- Game Over: saturation falls to 0.35 over 400 ms; score in cream.
- Workshop Cleared: Golden Key stays lit behind; score ticks up in steps.
- HUD: `#140D08` alpha .6 plaques, corner 3, top corners; cream 28 pt emboldened, no outlines; cog glyph drawn beside count. Time turns `#D8452F` with one scale tick when low; digits also enlarge so color is not the only cue.

**Motion: clockwork, not floaty.** Stepped ticks and small overshoot (`TRANS_BACK`, ease out), 120-220 ms. Logo cog advances one tooth per second, never spins smoothly. Title intro 600 ms total, skipped by any input. A reduced-motion setting must disable sway, drift, ticks and motes (required by `.claude/rules/ui-code.md`; no setting exists yet). No flashes above 3 Hz.

## 7. Performance budget
Baseline worst case 67 FPS = 14.9 ms against 16.7 ms: **only 1.8 ms headroom.** Per-pixel additions (normal maps, glow, spots) must be paid for and measured one at a time. Gate: at least 60 FPS, uncapped, in the worst view, on the HD 520.

**Draw calls: at most 180 in worst view**, same metric as baseline.

| Group | Draws |
|---|---|
| Room shell | 6 |
| Course tops and edges (8 + 4) + shadow 8 | 20 |
| Scenery props + shadow | 39 + 6 |
| Tock: at most 10 + shadow 8 (merge by material; limbs and key stay separate) | 18 |
| Beetles: 4 visible x 6 (shell, legs, eyes, gear; shadow on shell and gear only) | 24 |
| Cogs: 20 visible x 1, no shadow, shared material; culled at 50 u `[NV]`; `MultiMesh` optional `[W]`, 16-bit packed | 20 |
| Boxes and crates: 6 x (2 + 1 shadow), merged | 18 |
| Moving platform, spring, checkpoints, key | 10 |
| Blobs | 5 |
| Margin | 14 |

**Lights:** 1 shadowed directional, 1 unshadowed directional, 3 spots, 2 omnis. Limit 8 omni + 8 spot per mesh `[W]`.

**Shadows:** orthogonal `[C]`, max distance 32 (from 45), atlas 2048 `[NV]`, blur 1.5 `[NV]`.

**Textures:** 1K maximum; no upscales. Load 12 of 15 maps: wood DNR, rust DNR, metal_plate DNR, plaster DN, concrete D. Files have no `.import` yet: set mipmaps on (mandatory without AA) and VRAM compressed `[NV]`. Anisotropic 2x `[NV]`. Generated textures at most 128 px. Normal maps are OpenGL, Godot's convention `[NV]`. Keep Poly Haven file names for traceability, an exception to the asset naming convention.

**Cut order if under 60 FPS:** glow; vignette; lamp spots to 2; wall normals; wood roughness maps; shadow distance to 20; bench normals.

## 8. As built (2026-11-05)
Live values are in `assets/data/visual_look.json`, documented in `assets/data/data_reference.md`.

**Decisions**
- "No yellow or gold boxes" applies to surprise boxes only. The mustard stair block and goal plinth stay.
- Glow is cut, as the user chose 60 FPS over effects. It measured 49 FPS with and 84 without at the worst spot. A small additive halo at the Golden Key stands in; lamp bulbs have none.
- Window fill is an unshadowed far `OmniLight3D`, not a directional, because `tools/measure_fps.gd` forces shadows on every `DirectionalLight3D`.
- Blobs and occlusion use vertex alpha instead of `GradientTexture2D`, which needs no texture fetch.
- Palette entries are material lookups instead of colors.
- Not in this section's budget but added: cull distances on beetles, boxes and small props, and the key light masked off the room shell.

**Values changed from sections 2 and 3**

| Item | Bible | As built | Why |
|---|---|---|---|
| Tonemap | ACES | Filmic | ACES pushed brass and yellow to orange: the bible's stated fallback |
| Wood | tint only | Copy softened with `adjust_bcs` (1.1, 0.8, 0.62), tints near neutral: oak (1.05, 1.15, 1.2), maple (1.2, 1.3, 1.35), walnut (.82, .88, .92) | Tints above 1.0 work but only made the wood redder |
| Lamp pools | `#ffb56e`, 5.0, angle 55, attenuation 0.5 | `#ffc48a`, 3.0, angle 42, attenuation 0.15 | At 0.5 the pools barely registered |
| Key | 1.1 | 0.5 | Let the pools show |
| Ambient | `#4f4440`, 0.45 | `#5f5650`, 0.62 | Scenery read as black |
| Window fill | 0.22 | 0.3 | Cool side was too faint |
| Tock follow, Key glow specular | not set | follow 0, key glow energy 0.4 | Follow light made a hot spot on the bench; plinth glowed |
| Beetle eyes, shell | e2.0, e0.4 | e1.1 `#ff5a10`, e0.6 `#7a3214` | Eyes clipped to yellow; shell needed lift |
| Beetle gear | `#d8dde0`, metal .8 | `#e6eaec`, metal .5 | Dark with a dim reflection source |
| Cog | metal .55, e0.35 `#7a4a0c` | metal .35, e0.55 `#c98a1c` | Faces went dark against wood |
| Room floor | `#a89c8a` | `#574f45` | Above the luma target |
| Yellow paint | `#e8b321` | `#c9971f` | Mustard, away from gold |
