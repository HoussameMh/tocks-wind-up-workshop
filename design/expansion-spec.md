# Expansion Spec: 5 Levels, Bolt Blaster, Baron Rust

Status: built, 2026-11-06, from the user-approved plan of 2026-11-05. Human playtesting from section 8 has not happened yet. Supersedes the "out of scope" boss and further-levels lines in `design/game-brief.md`.
Feel target (brief): quick, cheerful, skill-based. Every challenge is telegraphed, every joke comes from a situation, and every death is the player's own readable mistake.

**Conventions.** Course runs toward -z, centered on x = 0. "Top" is the walkable y; platforms are 2 thick (`center.y = top - 1`) unless a size is given. Toy-box center = floor top + 2.7 (base 2.2 above floor). Enemy y = floor top. `[A#]` marks an assumption listed in section 9.

## 0. Jump limits and rule for every required jump

Airtime `T(dh) = 0.490 + sqrt(2 * (3.6 - dh) / 46)`, small form, jump held (gravity 30 rising, 46 falling). dh = landing height minus takeoff height. dh = 0 is measured; others are derived `[A2]`.

| dh (m) | -1 | 0 | +1 | +2 |
|---|---|---|---|---|
| Walk 7 m/s limit | 6.56 | 6.20 | 5.78 | 5.28 |
| Run 11 m/s limit | 10.31 | 9.70 | 9.09 | 8.29 |

**Rules.** Margin = limit minus gap, with small-form numbers only, so a Coil is never required. Walk-jump margin at least 1.5 m. Run-jump margin at least 1.7 m with at least 5 m of dry runway. Required step up at most 2.6 by jump (margin 1.0), or by a spring pad with height margin at least 0.8. Spring height = `v^2 / 60`: v15 = 3.75, v17 = 4.82, v21 = 7.35.

## 1. Difficulty curve

| | L1 Workbench Run | L2 Junk Drawer Dash | L3 Paint Shelf Panic | L4 Toolbox Tumble | L5 Baron Rust's Vise |
|---|---|---|---|---|---|
| Course length (m) | 168 | 200 | 233 | 238 | arena 26 x 26 |
| Time limit (s, full on each life) | 300 | 280 | 280 | 270 | 300 |
| Seconds per m `[A4]` | 1.79 | 1.40 | 1.20 | 1.13 | n/a |
| Gear / armored beetles | 9 / 0 | 5 / 2 | 4 / 2 | 4 / 3 | 0 |
| Planes / ducks / teeth | 0 / 0 / 0 | 3 / 0 / 0 | 2 / 4 / 0 | 2 / 2 / 5 | up to 2 teeth at once |
| Enemy total | 9 | 10 | 12 | 16 | boss + up to 2 |
| Longest required gap, margin | 4.0, 2.2 | 5.0 walk, 1.56 | 7.0 run, 2.7 | 8.0 run, 1.7 | no pits |
| Smallest landing | 3 x 3 | 2.5 x 2.5 | 5 x 8, slick | 4 x 6, moving | n/a |
| New threat | base game | Blaster, planes, armor, tight pads, bands | slick paint, ducks, first run jump | moving wrenches, teeth | everything, in 3 phases |
| Checkpoints | 2 | 2 | 3 | 3 | current phase |
| Coil / Blaster boxes | 2 / 0 | 2 / 2 | 2 / 1 | 1 / 1 (secret only) | 1 / 1, re-arming |
| Re-arming coil boxes (within the count) | 0 | 1 | 1 | 1 | n/a |
| Hidden life / cogs | 1 / 54 | 1 / 50 | 1 / 45 | 1 / 40 | 0 / 12 |

L2 has more power boxes than L1 only because it teaches the Blaster; from L2 on the count falls 4, 3, 2. All 201 cogs give 5 lives; about 60% gives 3 `[A4]`.

**Authoring limits (hard, checked by tests, sections 7 and 8):**
- At most **5 enemies** in any 40 m z-window. A plane counts at its rail midpoint. New enemies cull entirely at 45 m. At most 20 cogs in any 50 m.
- At most **4 enemy shots** (erasers + bubbles) and **3 bolts** alive. At the shot cap an enemy skips its shot and enters cooldown. Shots and bolts are pooled, unshadowed, 1 draw each.
- Dynamic draw budget per view: at most **38** (the art bible's 24 beetle + 14 margin rows). Worst case 5 x 6 + 4 + 3 + 1 aim marker = 38, so this uses the whole margin `[A1]`.
- New enemy draws, including shadow and blob: plane 2, duck 4, teeth 5, armored beetle 6 (as gear beetle, with lid replacing gear).
- No duck or teeth within 16 m of a spawn or respawn point.

## 2. Progression

Order: `assets/data/level_campaign.json` = `{"levels": [5 res:// paths]}`, using `level_workshop_01.json` (layout unchanged) to `_05.json`. `Tuning.num` is numeric only, hence a separate file.

| Event | Lives | Cogs and score | Form | Timer | Level state |
|---|---|---|---|---|---|
| Level clear | carry | carry; time bonus banked | **carry** | new level's full time | new level built |
| Death | -1 | keep | SMALL | full | respawn at last checkpoint; defeated enemies and used boxes stay, except `rearm` boxes; shots and bolts removed; **1.5 s invulnerability** |
| Game Over, **Retry level (default, recommended)** | reset to 3 | back to level-entry snapshot | SMALL | full | current level rebuilt; `rewinds` +1 |
| Game Over, New run | 3 | 0 | SMALL | full | level 1 |
| Pause, Restart run; or Title | as New run | | | | title always returns to level 1 (no save system) |

**Why retry level, not run:** a Game Over in L4 should not cost 10 minutes of cleared levels. The snapshot stops retries from farming score or cogs, and the rewinds count keeps a clean run worth chasing. This is the user's call (see report).

**Re-arm rule:** on each respawn, a used `rearm: true` box becomes fresh; any uncollected pickup it released is removed first.

**Per-level cogs:** add `RunState.level_cogs`. The clear summary `"Cogs %d of %d"` must use it, because `run_state.cogs` now spans levels and would exceed `level.total_cogs`.

**GameFlow additions.** New state VICTORY; new triggers NEXT, RETRY, WIN.
- PLAYING + WIN → VICTORY
- LEVEL_CLEAR + NEXT → PLAYING. Menu: Next level (default), Title.
- GAME_OVER + RETRY → PLAYING; START and QUIT stay. Menu: Retry level (default), New run, Title.
- VICTORY + START → PLAYING; VICTORY + QUIT → TITLE. Menu: New run, Title.

**Win:** touching the key in L5 fires WIN. Victory screen (placeholder copy, narrative may replace) shows score, cogs, lives, rewinds. Bonuses: `lives * 1000`, plus 5000 if rewinds = 0.

## 3. Bolt Blaster

**Obtained** only from toy boxes of kind `bolt` (L2 to L5), as a spinning steel hex nut on a stubby barrel (cylinder + hex cylinder). Bolts are short steel hex rods with a white core, with no flame, fire color or bounce. No ammo.

| Form | Coil pickup | Bolt pickup | Hit |
|---|---|---|---|
| SMALL | COILED | BLASTER | BROKEN (life lost) |
| COILED | no change, +500 | BLASTER | SMALL, 1.5 s invuln |
| BLASTER (coiled body + fire) | no change, +500 | no change, +500 | COILED, 1.5 s invuln |
| BROKEN | ignored | ignored | ignored |

One rule: each hit removes the top item. Code note: `Player.is_coiled()` must become "COILED or BLASTER"; `form_changed` must carry the form. BLASTER is shown by a barrel on Tock (1 draw) and by the HUD text.

**Input:** new action `fire`. Keyboard **F** and **left mouse button** (add a `_mouse` helper to `InputSetup`). Gamepad **RB** and **B** (B is menu-only today). Index finger on RB lets the thumb hold X and A together. Hold repeats at the fire rate. Ignored for 0.15 s after entering PLAYING, so B closing a menu fires nothing. `Player.Command` gains `fire_pressed` for bots.

**Numbers (feel knobs):** cooldown 0.35 s; speed 26 m/s; range 20 m (0.77 s); max 3 alive. Fires on the ground and in the air, with no recoil or slowdown.

**How a player aims in 3D: you face it; height is handled for you.**
1. Direction = move input if any (immediately, not the lerped model), else `(sin(model_yaw), 0, cos(model_yaw))`. Camera does not aim, so no reticle and no pitch control.
2. Target = from group `bolt_targets`, those with horizontal distance at most 18 m, yaw difference at most 30 degrees (horizontal only), height difference -5 to +9 m, and a clear `LAYER_WORLD` ray. Pick the lowest `yaw_deg/30 + dist/18`; an exposed boss weak spot scores x 0.5. Enemy shots are not targets.
3. A small ring (1 draw) sits above the current target while in BLASTER, refreshed every 0.1 s, so the player sees the result before firing.
4. With a target, the bolt launches at the target's `aim_point()` and steers at most 240 degrees/s toward it. If the target dies it flies straight. Without one, it flies flat at feet + 0.7.

**Bolt hits:** enemy = knockout. Bubble = pop. Crate = breaks, score 50. Toy box or hidden box = clink, nothing else (only head bumps open boxes). World or range end = gone, with a small clink. Contract: each target provides `aim_point() -> Vector3` and `bolt_hit() -> void`. Bolt step per tick is 0.43 m at 60 Hz; the thinnest target (plane, 0.5 m high) is larger, so no tunneling.

**Fair and fun:** a bolt knockout scores half of a stomp or less, so stomping stays the expert line (section 4). It outranges the duck (20 vs 16), which is the reward for holding it, paid for by scarcity and by losing it at the first hit. Nothing requires it.

## 4. New enemies

**Rules kept from the gear beetle (all four):** `StompRules.is_stomp` with `stomp_margin` 0.35 against the enemy's base y; contact checked each physics tick while touching; non-stomp contact calls `take_hit`; invulnerability honored; stomp calls `player.bounce()` (9, or 14 with jump held); defeated enemies stay gone until the level rebuilds; `Area3D`, layer 0, mask player. All are added to `Level.remove_enemies()`. Silhouettes: ember eyes only on enemies (art bible section 5). Colors go to art-director.

| | Armored beetle | Paper-plane bomber | Rubber-duck sniper | Chattering teeth |
|---|---|---|---|---|
| Silhouette | Gear beetle with a steel saucepan lid and knob replacing the gear | Two flat white wedge wings + keel (`PrismMesh`, merged), ember eyes on nose | Sphere body, smaller sphere head, flat box bill, sphere tail | Two pink half-boxes (jaws) with white tooth rows, two box feet, wind-up key on back |
| Hitbox W x H x D | 1.4 x 1.0 x 1.4 | 2.4 x 0.5 x 1.6 | 1.2 x 1.3 x 1.2 | 1.1 x 0.8 x 1.1 |
| Data | `beetles[]` + `armored: true` | `planes[]`: `a`, `b`, `speed` (5 to 6) | `ducks[]`: `pos` | `teeth[]`: `pos` |
| Stomp | First: lid pops off, 0.4 s stomp immunity, then gear beetle. Second: squash | Only reachable in SWOOP. One stomp | One stomp | One stomp, any state |
| Bolt | One bolt, armored or not | One bolt | One bolt | One bolt |
| Score stomp / bolt | 100 then 300 / 200 (100 after lid off) | 500 / 150 | 300 / 150 | 300 / 150 |

**Armored beetle** patrols exactly as `gear_beetle.gd`. States: ARMORED → (stomp) PANIC → (3 s) NORMAL → (stomp) squash; any bolt → gone. PANIC is 1.5 x speed. No attack, so no telegraph beyond its patrol. *Funny:* the lid clangs off and rolls away while the beetle sprints around in embarrassment.

**Paper-plane bomber** flies its rail at `a.y + 6.5` (`a.y` = highest floor on the rail), so a jump can never clip it at cruise.
- CRUISE: `speed` m/s, ping-pong with a 0.6 s U-turn at each end.
- CRUISE → WINDUP when Tock is within 6 m horizontally and cooldown (2.5 s from last drop) is 0.
- WINDUP 0.6 s: **telegraph**, nose dips, eraser appears under it, `plane_fwip` plays, landing blob shows on the floor below.
- DROP: eraser (0.9 x 0.5 x 0.5, gravity 20, about 0.8 s fall, straight down), blob freezes. Total warning about 1.4 s. On landing it boings and is gone, harmless. Max 1 per plane.
- SWOOP: dip to `a.y + 3.0` over 0.5 s, hold 0.8 s, climb 0.7 s, then CRUISE. Small Tock can stomp it (peak feet 3.6 vs 3.35 needed, tight on purpose: margin 0.25 is optional mastery, not required).
- *Funny:* a smug barrel roll during SWOOP; stomped, it crumples into a paper ball; bolted, it gets a hole and spirals down.

**Rubber-duck sniper** is stationary.
- IDLE: bobbing, LOS check every 0.2 s. → SQUEAK when Tock is within 16 m with clear LOS.
- SQUEAK 0.9 s: **telegraph**, turns to Tock at 6 rad/s, inflates 1.0 → 1.3, rising `duck_squeak`. Aim locks 0.25 s before the end.
- SHOOT: bubble (radius 0.45, 8 m/s, range 20 m, 2.5 s, straight) at locked torso position. Pops on world.
- DEFLATE 0.5 s with `duck_raspberry` and a small backward hop, then COOLDOWN 1.6 s → IDLE.
- Dodge: sidestep 1.2 m (0.17 s at walk). A bubble can be stomped: pops, bounces Tock, +50.
- *Funny:* stomped, it deflates and flaps around like a let-go balloon; bolted, it squeaks all the way up and away.

**Chattering teeth** hop on floors only.
- DORMANT: closed. → WIND when Tock is within 14 m.
- WIND 0.4 s: **telegraph**, stands still, key winds, loud `teeth_chatter`, turns to Tock.
- HOP 0.45 s: arc 1.2 high, 2.5 m toward Tock's position at takeoff; if a floor ray finds no floor at the landing point, it stays and chatters at the edge instead. LAND 0.35 s. Three HOP + LAND cycles (about 3.1 m/s).
- TIRED 1.4 s: jaw hangs open, key runs down. Contact still hurts unless stomped. → WIND if Tock is within 20 m, else DORMANT.
- *Funny:* laughs at the ledge edge instead of following; stomped, it bites itself shut; bolted, top and bottom jaws fly apart.

Gear beetle bolt score is 100; its stomp stays 200.

## 5. Levels 2 to 4

New level keys (read with `.get`, so L1's file stays unchanged): `time_seconds` (default `run.level_seconds`), `lamp_z` (max 3 spots), `springs[].speed`, `moving_platforms[].screw` (default true) and `.visual`, `beetles[].armored`, `blocks[].rearm`, block kind `bolt`, arrays `planes`, `ducks`, `teeth`, `paint_spills`. Decor reuses existing types inside each level's own `room`; L4 keep-out rises to y < 16 because of its top 6 course. Rail midpoints count in the window limit. Goal: plinth 4 x 1 x 4, key 1.6 above plinth top, area 5 x 4 x 5.

### L2 Junk Drawer Dash (280 s, spawn 0, 0.2, 4)
Theme: a messy open drawer of rulers, batteries, pencils, rubber bands. Mechanic: **rubber bands** are spring pads with `speed: 17`, height 4.82, one required climb. Teaches in order: Blaster on a slow beetle → narrow bridge → plane on a wide tray → band → armor on a wide shelf → all together.

| Seg | z range | x, width | Top | Gap, dh, margin (walk) | Contents | Cogs |
|---|---|---|---|---|---|---|
| A Lip | +8 to -30 | 0, 12 | 0 | start | Boxes z -12: cog x-2, **bolt** x0, cog x2. Beetle x +-4 z -24, speed 2.0 (target practice, 12 m from box) | 8 |
| B Pencil | -34 to -48 | 0, 2.5 | 0 | 4.0, 0, 2.2 | Beetle along z -38 to -46, speed 2.5. Hidden **life** (0, 2.7, -41) | 5 |
| C1 | -51 to -54 | -1.5, 3 | 1 | 3.0, +1, 2.78 | | 1 |
| C2 | -57 to -60 | 1.5, 3 | 2 | 3.0, +1, 2.78 | | 1 |
| C3 | -63 to -66 | -1.5, 3 | 2 | 3.0, 0, 3.2 | | 1 |
| D Tray | -70 to -100 | 0, 12 | 1 | 4.0, -1, 2.56 | **CP1** pos (-3.5, 1, -72), respawn (0, 1.2, -72). Boxes z -78: **bolt** x3, crate x-3. Plane 1 rail (-9, 1, -88) to (9, 1, -88), speed 5, alone | 8 |
| E1 Band floor | -104 to -110 | 0, 6 | 1 | 4.0, 0, 2.2 | Band (0, 1, -108) speed 17 | 8 in arc (with E2) |
| E2 Divider | -110 to -128 | 0, 10 | 5 | wall dh +4: band margin 0.82 (coiled jump 4.6 also works) | **Coil** (0, 7.7, -113). Beetle x +-4 z -116, 2.5. **Armored** x +-3 z -122, 2.0 | |
| F1 | -132 to -134.5 | 1.5, 2.5 | 4 | 4.0, -1, 2.56 | Plane 2 rail (0, 4, -130) to (0, 4, -158), speed 5 | 1 |
| F2 | -138.5 to -141 | -1.5, 2.5 | 4 | 4.03 diag, 0, 2.17 | | 1 |
| F3 | -145.5 to -148 | 1.5, 2.5 | 3 | 4.53 diag, -1, 2.03 | | 1 |
| F4 | -153 to -155.5 | 0, 2.5 | 2 | 5.0, -1, **1.56** | | 1 |
| G Finish | -159 to -192 | 0, 14 | 2 | 3.5, 0, 2.7 | **CP2** (-3.5, 2, -162), respawn (0, 2.2, -162). Boxes z -166: **coil rearm** x0, crate x-2, cog x2. Beetle x +-5 z -172, 3. Armored x +-4 z -176, 2.5. Beetle x +-5 z -180, 3. Plane 3 rail (-9, 2, -176) to (9, 2, -176), speed 5.5. Plinth (0, 2.5, -188), key (0, 4.6, -188) | 8 |

**Secret, cog shelf:** z -56 to -72, x 0, width 8, top -5, 6 cogs; spring (0, -5, -68) speed 21, dh +6 to D, height margin 1.35. Catches falls from C2 and C3 only. Total cogs 50, counting cog boxes.

### L3 Paint Shelf Panic (280 s, spawn 0, 0.2, 4)
Theme: a paint shelf with lids, stir sticks, drying rack. Mechanic: **slick paint.** `paint_spills: {center, size: [x, z]}` is a thin slab plus an Area with overlap counting. While `is_on_floor()` inside one, ground acceleration = **12** (normal 42) and deceleration = **6** (normal 52). Air and top speed are unchanged. Exact stops: walk with no input 4.08 m, run 10.08 m; holding the opposite direction walk 2.04 m, run 5.04 m. Reaching walk from rest takes 0.58 s and 2.04 m. No paint within 3 m of a respawn. *Funny:* `paint_sloop` on entry above 4 m/s; cogs laid in a curve that tempts a slide.

Order: paint alone → duck alone with cover → paint and duck → paint pads → first run jump → crossfire on paint.

| Seg | z range | x, width | Top | Gap, dh, margin (walk unless noted) | Contents | Cogs |
|---|---|---|---|---|---|---|
| A Lid | +8 to -24 | 0, 12 | 0 | start | Boxes z -7: **coil** x-2, cog x2. Paint center (0, 0, -16) 8 x 8, no threats, 4 m dry after | 6 |
| B | -28 to -64 | 0, 12 | 0 | 4.0, 0, 2.2 | Duck (3.5, 0, -54). Cover block center (0, 0.75, -44), 3 x 1.5 x 3 | 6 |
| C | -68 to -96 | 0, 12 | 0 | 4.0, 0, 2.2 | **CP1** (-3.5, 0, -71), respawn (0, 0.2, -71), 17.4 m from duck. **Bolt** (0, 2.7, -74). Paint (0, 0, -84) 12 x 14. Armored x +-5 z -92.5, 2.0. Duck (-4, 0, -95) | 6 |
| D1 | -99.5 to -107.5 | 0, 5 | 1 | 3.5, +1, 2.28 | Fully painted; run landing stops in 5.04 with back held, pad is 8 | 4 across D |
| D2 | -111 to -119 | 0, 5 | 1 | 3.5, 0, 2.7 | Fully painted. Hidden **life** (0, 3.7, -115) | |
| D3 | -122.5 to -130.5 | 0, 5 | 1 | 3.5, 0, 2.7 | Fully painted | |
| E Rack | -134 to -160 | 0, 12 | 0 | 3.5, -1, 3.06 | **CP2** (-3.5, 0, -137), respawn (0, 0.2, -137). Boxes z -141: **coil rearm** x0, cog x-2, crate x2. Beetle x +-5 z -147, 3. Plane 1 rail x +-9 z -151, y 0, speed 5. Beetle x +-5 z -154, 3 | 6 |
| F | -167 to -192 | 0, 10 | 0 | **7.0, 0, run 2.7**, walk fails by 0.8; runway 26 m | Cog arc of 3 over the gap shows the jump. **CP3** (-3.5, 0, -170), respawn (0, 0.2, -170). Armored x +-4 z -178, 2.5. Plane 2 rail (0, 0, -176) to (0, 0, -190), speed 5. Beetle x +-4 z -189, 3 | 3 + 4 |
| G | -195 to -225 | 0, 12 | 1 | 3.0, +1, 2.78 | Paint (0, 1, -204) 12 x 10. Cover center (0, 1.75, -211), 3 x 1.5 x 3. Ducks (-4, 1, -214), (4, 1, -214). Beetle x +-5 z -219, 3. Plinth (0, 1.5, -222), key (0, 3.6, -222) | 4 |

**Secret, cog shelf:** x -8 to -2, z -100 to -134, top -4, 6 cogs; spring (-5, -4, -132) speed 21, dh +4 to E, height margin 3.35. Reached by sliding off the left of a D pad. Falls near center still cost a life. Total cogs 45.

### L4 Toolbox Tumble (270 s, spawn 0, 0.2, 4)
Theme: an open toolbox with steel trays and giant wrenches on rails. Mechanic: **moving wrenches** are `MovingPlatform`s with `screw: false`, `visual: "wrench"` (box collider, decorative open jaw), and the existing smoothstep motion (peak speed = 1.5 x listed speed). Patterns: shuttle, lift, and **sweep** (a solid hurdle that does no damage and shoves Tock off the side, with a comic clank `[A3]`). No crush walls exist on any path.

Order: teeth alone → wrench over a safety tray → lift → sweep → relay over pit → run jump → final mix.

| Seg | z range | x, width | Top | Gap, dh, margin (walk unless noted) | Contents | Cogs |
|---|---|---|---|---|---|---|
| A Tray | +8 to -26 | 0, 12 | 0 | start | Boxes z -8: cog x-2, cog x2. Teeth (0, 0, -20), 24 m from spawn | 6 |
| W1 | shuttle | 0, size 3 x 0.5 x 6 | 0 | step-on gap 0.5 | a (0, -0.25, -29.5), b (0, -0.25, -32.5), speed 2. 10 m gap is too wide to jump. **Safety tray** z -26 to -36, width 12, top -4, spring (4, -4, -33.5) speed 21, dh +4, height margin 3.35 | |
| C | -36 to -60 | 0, 10 | 0 | step-off 0.5 | **CP1** (-3.5, 0, -39), respawn (0, 0.2, -39). Armored x +-4 z -48, 2. Teeth (0, 0, -56) | 5 |
| W2 lift | z -63 to -67 | 0, 4 x 4 | -> 6 | 3.0, 0, 3.2 | a y -0.25, b y 5.75, speed 2.5 (2.4 s per leg) | 2 |
| E Upper | -70 to -96 | 0, 10 | 6 | 3.0, 0, 3.2 at top of lift | **CP2** (-3.5, 6, -73), respawn (0, 6.2, -73). **Coil rearm** (0, 8.7, -78). Beetle x +-4 z -80, 3. W3 sweep size 1 x 1 x 6, a (-7, 6.5, -88), b (7, 6.5, -88), speed 4: jump over (top 1 above floor). Beetle x +-4 z -94, 3 | 6 |
| W4 | z -99 to -105 | size 4 x 0.5 x 6 | 6 | 3.0, 0, 3.2 | a x -3.5, b x 3.5, y 5.75, speed 3 (2.33 s per leg) | 3 across F |
| W5 | z -108 to -114 | size 4 x 0.5 x 6 | 6 | 3.0, 0, 3.2 when spans overlap: about 0.93 s of each 2.33 s leg | a x 3.5, b x -3.5 (mirror of W4). Timing test | |
| F3 | -117 to -120 | 0, 4 | 6 | 3.0, 0, 3.2 | Always overlaps W5. Hidden **life** (0, 8.7, -118.5) | |
| G | -123 to -150 | 0, 12 | 6 | 3.0, 0, 3.2 | Teeth (-3, 6, -132), (3, 6, -136). Plane 1 rail x +-9 z -138, y 6, speed 5.5. Duck (4, 6, -142). Armored x +-5 z -146, 2.5 | 5 |
| H | -158 to -186 | 0, 10 | 6 | **8.0, 0, run 1.7**, walk fails by 1.8; runway 27 m | **CP3** (-3.5, 6, -161), respawn (0, 6.2, -161), 19.4 m from duck. Boxes z -166: cog x-2, crate x2. Beetle x +-4 z -174, 3.5. Beetle x +-4 z -180, 3.5 | 5 |
| W6 lift | z -188 to -192 | 0, 4 x 4 | 6 -> 1 | 2.0, 0, 4.2 | a y 5.75, b y 0.75, speed 3 (1.67 s per leg) `[A3]` | |
| J | -195 to -230 | 0, 14 | 1 | 3.0, 0, 3.2 at bottom of lift | Teeth (0, 1, -208). Plane 2 rail x +-10 z -214, y 1, speed 6. Armored x +-5 z -215, 3. Duck (-5, 1, -222). Plinth (0, 1.5, -226), key (0, 3.6, -226) | 4 |

**Secret, side nook:** center (-11, 5, -82), size 6 x 2 x 8, top 6, 3.0 m west of E (dh 0, margin 3.2). Holds the level's only **bolt** box (-11, 8.7, -82) and 4 cogs. Total cogs 40.

## 6. Boss: Baron Rust's Vise (L5, 300 s per attempt)

**Arena:** floor center (0, -1, -13), size 26 x 2 x 26, top 0 (x +-13, z 0 to -26). Spawn (0, 0.2, -3). West, east and south edges have a visible rail 1.2 high plus a **player-only collider** up to y 8 on a new layer `LAYER_ARENA_WALL = 8`, added to the player's mask, so the camera ray ignores it and there are no pits. North: vise base z -26 to -34, top 6, solid. Toy boxes: **coil** (-9, 2.7, -9), **bolt** (9, 2.7, -9), re-armed at each phase start and each respawn. Cogs: 6 per line, x +-11, z -6 to -22, y 1.

**Baron Rust (max 12 parts, at most 14 draws, 2 shadows):** static vise casting + steel; screw handle; barrel torso; wide head with bar moustache and monocle; tiny top hat; 2 arms; ember eyes; glowing mainspring. Hazards at most 9 draws; 2 teeth at most 10. Dynamic total including Tock's bolts stays within 38.

**HP 18.** Phase 1: 18 to 13, Phase 2: 12 to 7, Phase 3: 6 to 1. Reaching 12 or 6 starts the next phase.

**Weak spot.** After each attack sequence: DROOP 0.8 s (head sags over the vise lip, hat tips up like a lid, `boss_droop`). Then **exposed** at center (0, 2.4, -24.5), trigger box 2.4 x 1.2 x 2.4, base y 1.8. Then raise 1 s with no attacks.
- **Stomp:** `is_stomp` against base 1.8, feet at least 2.15, small jump peak 3.6, margin 1.45. Deals **3** and ends the window. Bounces Tock.
- **Bolt:** deals **1**. A window takes at most **3** damage, then closes. Three bolts take at least 0.7 s.
- Damage clamps at the phase boundary (HP 12, 6) and ends the window there, so a stomp at HP 13 leaves HP 12, not 10.
- So one window = 3 damage either way, and 2 windows clear a phase: **6 clean windows win the fight, Blaster or not.**
- Touching the drooped head is harmless. The closed head is 8+ m up; bolts there clink for 0. No body contact damage.
- Window missed: he straightens with a smug `boss_grumble` and repeats the phase sequence with no penalty.
- Longest run to the weak spot: corner to spot 27.5 m, 2.5 s at run + 0.5 s jump = 3.0 s, under the shortest 4.0 s window (margin 1.0 s).

| Attack | Telegraph | Active | Dodge |
|---|---|---|---|
| **Bench Slam** | Fists rise, `boss_grumble`. 1.2 / 1.0 / 0.9 s by phase | Ring from (0, 0, -25) grows 9 m/s to radius 38, height 0.8, half-thick 0.6; hurts if feet < 0.8. Max 2 rings. Recover 1.5 s | Jump as it nears; passes in 0.13 s |
| **Wrench Lob** | Reaches back 0.8 s, `boss_lob` | 3 throws, 0.7 s apart. Marker ring locks at Tock's position on throw; flight 1.0 s; 1.5 radius hit on landing; stays 0.5 s harmless. Phase 3 leads by `velocity * 0.5`, clamped to the arena | Keep moving, 2 m clears |
| **Denture Launch** | Cheeks bulge, rattle, 1.0 s | 2 teeth land at (+-6, 0, -14) after 0.8 s (markers, landing harmless), then standard teeth AI. Skipped if 2 are alive. Recover 1 s | Stomp or bolt them |
| **Rust Sweep** | 3 ratchet clacks, 1.5 s, bar rises at the rail | Bar 26 long, 0.8 wide, top y 1.0, x -13 to 13 at 7 m/s (3.7 s), alternating sides. Area, not solid. Landing on it bounces Tock with no damage | Jump over |

| Phase | Sequence (then DROOP) | Window | Loop | Mood |
|---|---|---|---|---|
| 1 Tantrum | Slam x 3 | 5.0 s | 14.9 s | Grumpy, thumps the bench |
| 2 Junk Mail | Lob x 3, Denture, Slam | 4.5 s | 15.5 s | Throws things, spits his own teeth |
| 3 Full Rattle | Sweep, Lob x 3 (leading), Slam, Sweep | 4.0 s | 22.5 s | Moustache drooping, parts rattling |

Flawless fight about 112 s including two 3 s phase breaks. Phase break: Baron immune, hazards and teeth removed, screw handle spins as the vise tightens one notch, `boss_phase`, boxes re-arm.

**Retry.** On any death or timeout: respawn at spawn, phase kept, HP back to phase start (18, 12 or 6), hazards and teeth removed, boxes re-armed, timer full, 2 s grace with Baron laughing. Game Over → Retry level restarts at Phase 1, HP 18. Blaster loss never blocks progress: stomp deals the same damage per window and a bolt box is always in the arena.

**Win.** HP 0: hazards removed, timer stops and time bonus banks, Tock cannot be hurt. 0 to 2.5 s: Baron rattles, `boss_down`, hat launches, bolts fly, jaws spring open. 2.5 to 3.5 s: collapses into a heap. At 3.5 s the Golden Key rises at (0, 2.6, -13), area 5 x 4 x 5. Touching it fires WIN. Reduced motion: no shake, same timing. Cut-first joke: the hat lands on Tock on the victory screen. Score: stomp hit 1000, bolt hit 300, defeat 5000.

## 7. Sound, HUD, tuning

**Sfx.SOUNDS additions** `[start_hz, end_hz, seconds]`, tune by ear. Raise `VOICES` from 6 to 8.

| Sound | Notes | Sound | Notes |
|---|---|---|---|
| `bolt_fire` | [900,1500,.05],[1500,700,.06] | `teeth_wind` | [200,400,.1],[250,450,.1],[300,500,.1] |
| `bolt_hit` | [1200,400,.07] | `armor_clang` | [1300,700,.06],[1700,500,.18] |
| `bolt_clink` | [2200,1800,.04] | `paint_sloop` | [500,160,.22] |
| `blaster_get` | [523,523,.06],[784,784,.06],[1047,1047,.06],[1319,1319,.16] | `band_boing` | [160,520,.1],[520,240,.18] |
| `plane_fwip` | [700,1300,.1],[1300,500,.12] | `wrench_clank` | [260,180,.05],[340,240,.08] |
| `eraser_fall` | [600,200,.25] | `boss_grumble` | [110,80,.35],[80,120,.35] |
| `eraser_boing` | [180,320,.08],[320,140,.1] | `boss_slam` | [130,40,.4] |
| `duck_squeak` | [800,1500,.45],[1500,2100,.45] | `boss_lob` | [400,900,.2] |
| `duck_raspberry` | [140,90,.3],[90,130,.2] | `boss_spit` | [300,900,.1],[900,300,.15] |
| `bubble_pop` | [500,1600,.05] | `boss_ratchet` | [600,600,.04],[300,300,.06] x 3 |
| `teeth_chatter` | [1100,1100,.03],[600,600,.03] x 4 | `boss_droop` | [400,100,.7] |
| `boss_hit` | [900,300,.12],[1200,250,.16] | `boss_phase` | [200,800,.3],[800,300,.3] |
| `boss_down` | [800,60,1.4],[60,900,.3] | `win` | [523,523,.12],[659,659,.12],[784,784,.12],[1047,1047,.12],[1319,1319,.5] |

**HUD** (all text through `tr`, HUD only listens):
- Power plaque after cogs: `Small`, `Coil` or `Blaster`, driven by the form signal, so color is never the only cue.
- Level banner for 2.5 s on level entry: `Level %d of 5: %s` with the JSON `name`.
- Boss gauge at top center, L5 only: label + 18 pips in 3 groups of 6, driven by `Level.boss_hp_changed(hp, max_hp)`.
- Hint bar adds a Fire pair (`F`/`RB`) only while in BLASTER, and the hint re-shows on the first Blaster of a run. Existing hint tests only check `has`, so they still pass.

**`gameplay_tuning.json` additions** (safe ranges for the main knobs follow the block):
```json
"blaster": { "cooldown": 0.35, "bolt_speed": 26.0, "bolt_range": 20.0, "max_bolts": 3,
  "aim_range": 18.0, "aim_yaw_degrees": 30.0, "aim_dy_min": -5.0, "aim_dy_max": 9.0, "steer_degrees": 240.0, "fire_grace": 0.15 },
"paint": { "ground_acceleration": 12.0, "ground_deceleration": 6.0 },
"limits": { "max_enemy_shots": 4, "enemy_cull_distance": 45.0 },
"plane": { "altitude": 6.5, "trigger_radius": 6.0, "windup": 0.6, "cooldown": 2.5, "turn_seconds": 0.6, "eraser_gravity": 20.0,
  "swoop_altitude": 3.0, "swoop_down": 0.5, "swoop_hold": 0.8, "swoop_up": 0.7 },
"duck": { "range": 16.0, "squeak": 0.9, "aim_lock": 0.25, "deflate": 0.5, "cooldown": 1.6, "bubble_speed": 8.0, "bubble_range": 20.0, "turn_rate": 6.0 },
"teeth": { "trigger": 14.0, "keep_chasing": 20.0, "wind": 0.4, "hop_seconds": 0.45, "hop_distance": 2.5, "hop_height": 1.2, "land": 0.35, "hops": 3, "tired": 1.4 },
"armored": { "panic_seconds": 3.0, "panic_speed_scale": 1.5, "stomp_immunity": 0.4 },
"boss": { "hp": 18, "stomp_damage": 3, "bolt_damage": 1, "window_cap": 3, "window_p1": 5.0, "window_p2": 4.5, "window_p3": 4.0, "droop": 0.8, "raise": 1.0,
  "slam_p1": 1.2, "slam_p2": 1.0, "slam_p3": 0.9, "slam_recover": 1.5, "ring_speed": 9.0, "ring_radius": 38.0, "ring_height": 0.8, "ring_half_width": 0.6,
  "lob_windup": 0.8, "lob_gap": 0.7, "lob_flight": 1.0, "lob_radius": 1.5, "lob_lead_p3": 0.5, "denture_tell": 1.0, "denture_flight": 0.8,
  "sweep_tell": 1.5, "sweep_speed": 7.0, "sweep_top": 1.0, "phase_break": 3.0, "retry_grace": 2.0, "defeat_seconds": 3.5 },
"score": { "bolt_gear": 100, "armor_stomp_1": 100, "armor_stomp_2": 300, "bolt_armored": 200, "plane_stomp": 500, "plane_bolt": 150,
  "duck_stomp": 300, "duck_bolt": 150, "teeth_stomp": 300, "teeth_bolt": 150, "bubble_stomp": 50, "spare_power": 500,
  "boss_stomp": 1000, "boss_bolt": 300, "boss_defeat": 5000, "per_life_at_win": 1000, "no_rewind": 5000 }
```
Add to `run`: `respawn_invulnerable_seconds: 1.5`. Band speed lives in the level data (`springs[].speed`). Safe ranges: cooldown 0.25 to 0.5; bolt speed 20 to 32; paint accel 8 to 20, decel 4 to 12 (above 12 stops feeling slick; below 4 breaks pad stop margins); duck squeak 0.7 to 1.2; plane windup 0.4 to 0.9; boss windows 3.5 to 6 (below 3.5 removes the run margin); slam tell 0.8 to 1.5. Update `data_reference.md` with all of it.

## 8. Acceptance criteria and build order

**Automated (extend `tests/`):**
1. L1's JSON is byte-identical; existing L1 bot finish and all current tests still pass (check the new 1.5 s respawn invulnerability against existing respawn tests).
2. Bot with enemies removed finishes L2, L3 and L4 (as `test_full_course_can_be_finished_by_a_bot`), including walk-only through every non-run gap and the L3 and L4 run jumps at run speed.
3. Data test over all level files: at most 5 enemies per 40 m window; at most 20 cogs per 50 m; no duck or teeth within 16 m of spawn or respawn; cog totals 50, 45, 40, 12; enemy counts equal section 1.
4. Form table: each cell of section 3 by unit test. Hit in BLASTER → COILED with invulnerability; next → SMALL; next → BROKEN.
5. `fire` bound to F, LMB, RB, B and not to any existing action. Firing in SMALL or COILED spawns nothing. Bolts alive never exceed 3; cooldown holds.
6. Aim: target at 29 degrees and 17 m is selected, 31 degrees or 19 m is not; an elevated plane in the cone is hit with no pitch input; LOS blocked means no target.
7. Each enemy: stomp and bolt defeat as specified; armored takes exactly 2 stomps or 1 bolt; side contact hurts; each telegraph state lasts its tuned time before any shot; enemy shots never exceed 4.
8. Slick stop distance within 5% of 4.08 m (walk) and 10.08 m (run) on a test slab; normal floor unchanged after leaving; jump unaffected.
9. Moving lifts and sweep carry or push Tock with no fall-through or stuck state at 60 Hz.
10. Progression: L1 to L5 carries lives, cogs, score, form; death resets form and keeps checkpoint; Game Over retry restores snapshot with 3 lives and increments rewinds; clear summary uses per-level cogs; title resets to L1; the flow table refuses unlisted triggers.
11. Boss: bot with no Blaster wins by 6 stomps; bot in BLASTER wins with bolts; window damage never exceeds 3; closed head takes 0; death in Phase 2 restores HP 12; boxes re-arm; exactly 3 phases; win only through the key.
12. HUD: power plaque shows each form; banner and gauge appear only as specified.

**Performance gate (`tools/measure_fps.gd`, HD 520, 1280x720):** at least 60 FPS uncapped and at most 180 draws in the worst view of each new level and in Phase 3 with 2 teeth, 2 rings, 3 lobs, 3 bolts. Follow the art bible's cut order if not.

**Playtest (not automatable):** first plane, duck and teeth are each survived on first sight by a new player in at least 3 of 4 tries; players can say why they were hit; at least one laugh or comment per new enemy; players aim with the marker without being told how; L4 run jump lands within 3 tries; boss beaten within 3 attempts with 3 lives; times stay under limits.

**Build order, riskiest first:**
1. **Blaster and 3D aim** on a sandbox copy of L1, with the form ladder. It is the least proven idea; if aiming is not fun, change it before anything depends on it.
2. **Enemy base + all four enemies + performance gate** in a stress scene with 5 enemies, 4 shots, 3 bolts on the HD 520. If this fails, the limits shrink before levels are authored.
3. **Progression shell:** campaign list, flow table, carry-over, snapshot, retry, per-level cogs, level-switch hitch `[A5]`, using greybox levels.
4. **Boss** on a greybox arena, stomp-only bot first.
5. **L2, then L3, then L4,** data and mechanic together; bot reachability on each.
6. **HUD and sounds,** then art and comedy passes.
7. **Regression, README, `data_reference.md`, game brief.**

## 9. Assumptions (unverified)

- **A1** Draw costs are estimates from the art bible, not measurements. The gate in section 8 decides.
- **A2** Jump limits at dh other than 0 come from the tuning formula, not a measured run.
- **A3** `AnimatableBody3D` pushing Tock (sweep) and keeping him grounded on a descending lift (W6) is not tested in this project. If it fails, W3 becomes a damage-free ride-only platform and W6 slows to 2 m/s.
- **A4** Time limits, life economy and "about 60% of cogs" have no playtest data. Walking speed alone would clear each course many times over, so limits are likely generous.
- **A5** Rebuilding `Level` and `CourseDressing`'s static bake on level change has no measured hitch on the HD 520. Hide it behind the level-clear screen.
- **A6** Art calls for art-director: a lemon duck color that stays clear of brass-gold hue ownership, bolt and paint colors (no teal), wrench visuals, per-level `lamp_z` for courses longer than today's room (only 3 spots allowed), low-rail camera look at the arena edge.
