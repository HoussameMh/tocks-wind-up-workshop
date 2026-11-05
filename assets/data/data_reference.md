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
| `palette` | Named colors used by the other entries |
| `platforms` | Solid boxes, given by `center` and `size` |
| `moving_platforms` | Boxes that travel between `a` and `b` at `speed` |
| `blocks` | Toy boxes. `kind` is `cog`, `coil`, `life` or `crate`; `hidden` boxes appear only when bumped from below |
| `beetles` | Enemies patrolling between `a` and `b` at `speed`, with `y` at floor level |
| `cog_lines`, `cogs` | Evenly spaced rows of cogs, and individually placed cogs |
| `springs`, `checkpoints`, `goal` | Spring pads, respawn points and the Golden Key trigger |
| `decor` | Non-solid scenery: `pencil`, `box` or `cylinder` |
