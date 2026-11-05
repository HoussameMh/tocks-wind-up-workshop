# Game Data

Every gameplay number lives here, so the game can be tuned without code changes.
JSON has no comments, so this file documents what the values mean.
Distances are meters, speeds are meters per second and times are seconds.

## gameplay_tuning.json

| Section | Keys | Meaning |
|---|---|---|
| `player` | `walk_speed`, `run_speed` | Top ground speed without and with the run button |
| `player` | `ground_acceleration`, `ground_deceleration`, `air_acceleration` | How quickly speed changes, in m/s² |
| `player` | `gravity_rise`, `gravity_fall`, `max_fall_speed` | Gravity going up and coming down. A stronger fall makes jumps feel snappy |
| `player` | `jump_height_small`, `jump_height_coiled` | Peak jump height for each form |
| `player` | `jump_cut_multiplier` | Upward speed kept when jump is released early (0 to 1) |
| `player` | `coyote_seconds`, `jump_buffer_seconds` | Grace time for jumping after leaving a ledge, and for pressing jump just before landing |
| `player` | `stomp_bounce_speed`, `stomp_bounce_speed_held`, `hurt_bounce_speed` | Upward speed after a stomp (jump released or held), and after being hurt |
| `player` | `capsule_*`, `kill_height` | Collision size per form, and the height below which Tock is lost |
| `camera` | all | Follow distance, pitch limits in degrees, input sensitivity and smoothing |
| `enemy` | `stomp_margin` | How far above a beetle's base Tock's feet must be to count as a stomp |
| `enemy` | `hitbox_width`, `hitbox_height` | Size of the beetle's contact area |
| `world` | `spring_launch_speed` | Upward speed given by a spring pad |
| `run` | all | Starting lives, timer, cogs per extra life, score values and respawn delay |

## level_workshop_01.json

Positions are `[x, y, z]`, and the course runs toward negative `z`.

| Key | Meaning |
|---|---|
| `spawn` | Where Tock starts |
| `palette` | Platform looks, by the name in each platform's `color`. `material` is a row of `visual_look.json`, `edge` is the row for its edge strip (left out, the edge is a lighter `paint`), `paint` is a vertex color for shared painted rows, and `kind` is `bench` (gets legs and apron) or `block` (gets a steel rod unless it rests on a bench) |
| `platforms` | Solid boxes, given by `center` and `size` |
| `moving_platforms` | Boxes that travel between `a` and `b` at `speed` |
| `blocks` | Toy boxes. `kind` is `cog`, `coil`, `life` or `crate`; `hidden` boxes appear only when bumped from below |
| `beetles` | Enemies patrolling between `a` and `b` at `speed`, with `y` at floor level |
| `cog_lines`, `cogs` | Evenly spaced rows of cogs, and individually placed cogs |
| `springs`, `checkpoints`, `goal` | Spring pads, respawn points and the Golden Key trigger |
| `decor` | Non-solid scenery, built and merged by `src/gameplay/workshop_scenery.gd`. `type` picks the prop: `room` (`min`, `max`), `window` (`pos`, `size`), `counter` (`x`, `z`, `top`, `floor`), `pegboard` (`x`, `y`, `z`), `batten` (`y`, `z`, `width`), `lamp` (`pos` of the shade, `base`), `jars` (`pos`, `count`), `wrench` (`pos`, `length`), `clock` (`pos`, `radius`). `hammer`, `handsaw`, `chisel`, `square`, `vise`, `oil_can`, `spool`, `tape_measure`, `tool_chest`, `stool` and `sawhorse` take only `pos`. Keep props out of \|x\| < 16 with -14 < y < 14: the camera reaches there |

## visual_look.json

The numbers behind the look, read through `src/gameplay/look.gd`. See `design/art/art-bible.md`.
Colors are `"#rrggbb"` text or `[r, g, b]` arrays; arrays may go above 1.0. Distances are world units (1 u = 4 cm in the fiction).

| Section | Keys | Meaning |
|---|---|---|
| `environment` | `sky` | Colors of the reflection source. The room is sealed, so the sky itself is never seen |
| `environment` | `ambient` | Flat light that sets the shadow floor |
| `environment` | `tonemap`, `fog` | Exposure and white point; `fog` is exponential with `density` per unit, and `enabled` is 1 or 0 |
| `environment` | `glow` | `enabled` is 1 or 0. **Off**: it cost about 8 ms per frame on the Intel HD 520 (49 FPS with it, 84 without) |
| `lights` | `key` | The one shadowed light: `rotation` in degrees, `shadow_max_distance`, `shadow_blur` |
| `lights` | `window_fill` | Cool fill from the window side. An unshadowed omni, far away with `attenuation` 0, not a directional, because `tools/measure_fps.gd` turns shadows on for every `DirectionalLight3D` |
| `lights` | `lamp` | One spot per entry in `positions`, aimed at (`aim_x`, `aim_y`, own z). `attenuation` is distance falloff: 1.0 removes nearly all of the lamp at this range |
| `lights` | `follow`, `key_glow` | Small unshadowed omnis on Tock (`height` above his origin) and at the Golden Key |
| `lights` | every group | `specular` scales highlights. `cull_mask` picks lit render layers: 1 is the course and actors, 2 is the room and props. Leaving the key off layer 2 skips its extra shadow pass on scenery |
| `readability` | `blob`, `edge` | Landing blob `opacity`, `radius`, `beetle_radius` and `lift`; width of the strip along walkable edges |
| `readability` | `cog`, `beetle`, `block` | `cull_distance` is how far from the camera they stop drawing. Beetle legs, gear and blob stop at `detail_cull_distance`. These keep draw calls within budget |
| `readability` | `halo` | Soft additive billboard at the Golden Key, the cheap stand-in for glow |
| `scenery` | `zones` | `length` of a merge zone along z. Smaller culls better; larger makes fewer draw calls |
| `scenery` | `twine`, `lead_screw`, `occlusion` | Twine `radius` and ceiling height `top_y`; how far the screw passes the plate's travel; strength and size of the fake shadow strips |
| `scenery` | `window`, `toy_box`, `prop_colors` | Vertex colors for the window gradient, boxes and muted props |
| `texture_adjust` | one entry per texture set | `[brightness, contrast, saturation]` applied to a copy of the diffuse map at load, because a tint cannot desaturate |
| `materials` | one row per look | `tint`, `metallic`, `roughness`, `specular`, `emission`, `emission_energy`. Textures: `texture_set` plus `maps` (any of `d`, `n`, `r`), `normal_scale`. `uv_per_unit` is repeats per unit baked into merged meshes; `mesh_uv` scales a primitive's own UVs. Flags: `vertex_color`, `unshaded`, `alpha`, `additive`, `billboard`, `two_sided`, `no_fog`. `render_layer` (default 1) and `cull_distance` (default none) apply to merged scenery |
