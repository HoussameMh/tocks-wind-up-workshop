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
| `world` | `spring_launch_speed` | Upward speed given by a spring pad unless the level gives its own |
| `run` | all | Starting lives, default timer (a level's `time_seconds` replaces it), cogs per extra life, score values, respawn delay, and `respawn_invulnerable_seconds`, the protection after a respawn |
| `paint` | `ground_acceleration`, `ground_deceleration` | Grip while standing in a paint spill. Safe 8 to 20 and 4 to 12. Above 12 deceleration stops feeling slick; below 4 breaks the stopping margins on level 3's pads |
| `paint` | `sloop_speed` | Tock must enter a spill faster than this to earn the sound |
| `boss` | `hp`, `stomp_damage`, `bolt_damage`, `window_cap` | Baron Rust's health, and damage per hit. A window takes at most `window_cap`, so a stomp and three bolts cost him the same. The three phases split `hp` into equal thirds |
| `boss` | `window_p1` to `window_p3`, `droop`, `raise` | How long the head stays down per phase (safe 3.5 to 6; under 3.5 removes the margin for running there), then how long it takes to sag and rise. The arena allows 3.0 s from the far corner |
| `boss` | `slam_p1` to `slam_p3`, `slam_recover` | Warning before a bench slam per phase (safe 0.8 to 1.5), and the pause after it |
| `boss` | `ring_speed`, `ring_radius`, `ring_height`, `ring_half_width` | The shockwave's speed and furthest reach, how high it hits and half its thickness |
| `boss` | `lob_windup`, `lob_gap`, `lob_flight`, `lob_radius`, `lob_linger`, `lob_lead_p3` | The wrench throw: warning, seconds between throws, flight time, hit radius on landing, how long it lies there harmless, and how far ahead of Tock phase 3 aims, in seconds of his speed |
| `boss` | `denture_tell`, `denture_flight`, `denture_recover` | The teeth attack: warning, flight to the landing marks, pause after |
| `boss` | `sweep_tell`, `sweep_speed`, `sweep_top`, `sweep_width` | The bar's warning, crossing speed, top height and width |
| `boss` | `phase_break`, `retry_grace`, `defeat_seconds` | Length of the break between phases, of the pause after Tock respawns, and from the last hit to the Golden Key rising |
| `boss` | `weak_spot_base_y`, `weak_spot_width`, `weak_spot_height` | The drooped head's hit box. A stomp needs feet above `weak_spot_base_y + enemy.stomp_margin` |
| `blaster` | `cooldown`, `bolt_speed`, `bolt_range`, `max_bolts` | Seconds between bolts (safe 0.25 to 0.5), bolt speed (safe 20 to 32), meters flown before a bolt is spent, and bolts alive at once |
| `blaster` | `aim_range`, `aim_yaw_degrees`, `aim_dy_min`, `aim_dy_max` | What can be targeted: horizontal distance, yaw either side of facing, and height of the target's aim point relative to Tock's feet |
| `blaster` | `steer_degrees`, `fire_grace`, `muzzle_height`, `aim_refresh` | Most a bolt turns per second toward its target; seconds the trigger is ignored after entering play, so B closing a menu fires nothing; bolt launch height above the feet; seconds between target refreshes (the ring shows the result) |
| `limits` | `max_enemy_shots`, `enemy_cull_distance` | Erasers and bubbles alive at once, shared by all enemies (at the cap an enemy skips its shot and enters cooldown); distance beyond which new enemies are not drawn |
| `plane` | `altitude`, `swoop_altitude` | Height above the rail's `a.y` when cruising and at the bottom of a swoop. Small Tock's jump peak is 3.6, so swoop 3.0 leaves a stomp margin of 0.25 |
| `plane` | `trigger_radius`, `windup`, `cooldown`, `turn_seconds` | Horizontal distance that starts an attack; telegraph length before the eraser falls (safe 0.4 to 0.9); seconds from one drop to the next attack; length of the U-turn at each rail end |
| `plane` | `eraser_gravity`, `swoop_down`, `swoop_hold`, `swoop_up` | Eraser fall acceleration; seconds of each part of the swoop that follows a drop |
| `plane`, `duck`, `teeth` | `hitbox_width`, `hitbox_height`, `hitbox_depth` | Contact box. Duck and teeth are square, so they have no depth |
| `duck` | `range`, `los_interval` | Sight distance, and seconds between line-of-sight checks while idle |
| `duck` | `squeak`, `aim_lock`, `deflate`, `cooldown` | Telegraph length (safe 0.7 to 1.2); how long before its end the aim freezes, which is the dodge window; deflate and cooldown lengths |
| `duck` | `bubble_speed`, `bubble_range`, `bubble_radius`, `turn_rate`, `inflate_scale` | Bubble flight and size; turn speed in radians per second while squeaking; model scale at the end of the squeak |
| `teeth` | `trigger`, `keep_chasing` | Distance that wakes them when dormant, and that keeps them going when tired |
| `teeth` | `wind`, `hop_seconds`, `land`, `tired`, `hops` | State lengths, and hop-and-land cycles per chase |
| `teeth` | `hop_distance`, `hop_height` | Length and arc height of one hop |
| `armored` | `panic_seconds`, `panic_speed_scale`, `stomp_immunity` | Length and speed multiplier of the sprint after the lid comes off; seconds after the lid comes off in which contact with the beetle does nothing, so the bounce away cannot hurt |
| `score` | `bolt_*`, `*_bolt` | Points for a bolt knockout; always at most half of the matching stomp, except the armored bolt (see `design/expansion-spec.md` section 4) |
| `score` | `armor_stomp_1`, `armor_stomp_2`, `*_stomp` | Points for a stomp. A gear beetle's stomp is `run.score_per_stomp`. `bubble_stomp` is for popping a bubble by stomping |
| `score` | `spare_power` | Points for a power-up that changes nothing |
| `score` | `boss_stomp`, `boss_bolt`, `boss_defeat` | Points for hitting Baron Rust and for finishing him |
| `score` | `per_life_at_win`, `no_rewind` | Paid at the end of the run: per life left, and once if no Game Over was ever retried |

## level_campaign.json

| Key | Meaning |
|---|---|
| `levels` | The level files in play order. The last one's key wins the game |
| `first_level_quip_clear`, `first_level_quip_over` | Level one's jokes, kept here because its level file does not change |

## level_workshop_01.json to level_workshop_05.json

Positions are `[x, y, z]`, and the course runs toward negative `z`. The layout rules behind levels 2 to 5 are in `design/expansion-spec.md`.

| Key | Meaning |
|---|---|
| `name` | Shown on the level banner and clear screen |
| `time_seconds` | Optional. The clock per life. Left out, `run.level_seconds` applies |
| `lamp_z` | Optional. Moves the lamp lights along the course, at most 3. Left out, the defaults in `visual_look.json` apply |
| `camera` | Optional. `pitch_degrees`, `focus_height` and `distance` replace the default framing |
| `quip_clear`, `quip_over` | Optional. Jokes for the clear (or victory) screen and for a Game Over on this level |
| `paint_spills` | Optional. Slick patches: `center` with `y` at floor height, and `size` as x and z |
| `arena_walls` | Optional. Solid boxes, given by `center` and `size`, that stop only Tock, so the camera and bolts pass through |
| `boss` | Optional. Puts Baron Rust in the level. `key_pos` and `key_area` place the Golden Key that rises when he falls, and `taunts` holds his lines: `droop`, `phase_2`, `phase_3`, `retry`, `defeat`. Such a level has no `goal` |
| `spawn` | Where Tock starts |
| `palette` | Platform looks, by the name in each platform's `color`. `material` is a row of `visual_look.json`, `edge` is the row for its edge strip (left out, the edge is a lighter `paint`), `paint` is a vertex color for shared painted rows, and `kind` is `bench` (gets legs and apron) or `block` (gets a steel rod unless it rests on a bench) |
| `platforms` | Solid boxes, given by `center` and `size` |
| `moving_platforms` | Boxes that travel between `a` and `b` at `speed`. Optional `screw: false` leaves out the lead screw, and `visual: "wrench"` draws a giant wrench over the same box |
| `blocks` | Toy boxes. `kind` is `cog`, `coil`, `bolt`, `life` or `crate`; `hidden` boxes appear only when bumped from below; `rearm` boxes turn fresh each time Tock respawns |
| `beetles` | Enemies patrolling between `a` and `b` at `speed`, with `y` at floor level. Optional `armored: true` adds the saucepan lid |
| `planes` | Optional. Paper-plane bombers flying the rail `a` to `b` at `speed` (5 to 6). `a.y` is the highest floor under the rail |
| `ducks`, `teeth` | Optional. Rubber-duck snipers and chattering teeth at `pos`, with `y` at floor level |
| `cog_lines`, `cogs` | Evenly spaced rows of cogs, and individually placed cogs |
| `springs`, `checkpoints`, `goal` | Spring pads, respawn points and the Golden Key trigger. A spring takes optional `speed` and `visual: "band"` for a rubber band |
| `decor` | Non-solid scenery, built and merged by `src/gameplay/workshop_scenery.gd`. `type` picks the prop: `room` (`min`, `max`), `window` (`pos`, `size`), `counter` (`x`, `z`, `top`, `floor`), `pegboard` (`x`, `y`, `z`), `batten` (`y`, `z`, `width`), `lamp` (`pos` of the shade, `base`), `jars` (`pos`, `count`), `wrench` (`pos`, `length`), `clock` (`pos`, `radius`). `hammer`, `handsaw`, `chisel`, `square`, `vise`, `oil_can`, `spool`, `tape_measure`, `tool_chest`, `stool` and `sawhorse` take only `pos`. Theme props: `pencil` and `battery` (`center`, `size` of the platform they dress), `ruler` (`pos`, `length`), `paint_can` (`pos`, `radius`, `height`, `color`), `stir_stick` (`pos`, `height`, `color`), `giant_battery`, `socket` and `giant_bolt` (`pos`, `radius`, `height`). Keep props out of \|x\| < 16 with -14 < y < 14: the camera reaches there |

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
| `materials` | `enemy_paint`, `enemy_paper`, `enemy_bubble` | Vertex-colored paint shared by duck, teeth and eraser; the plane's paper, with a little emission because its underside is what the player sees; the see-through bubble. Their colors are constants at the top of each enemy script and are provisional until the art pass |
| `materials` | one row per look | `tint`, `metallic`, `roughness`, `specular`, `emission`, `emission_energy`. Textures: `texture_set` plus `maps` (any of `d`, `n`, `r`), `normal_scale`. `uv_per_unit` is repeats per unit baked into merged meshes; `mesh_uv` scales a primitive's own UVs. Flags: `vertex_color`, `unshaded`, `alpha`, `additive`, `billboard`, `two_sided`, `no_fog`. `render_layer` (default 1) and `cull_distance` (default none) apply to merged scenery |
