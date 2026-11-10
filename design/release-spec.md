# Release Spec: Progress, Replay, Graphics Quality, itch.io

Turns the finished campaign into something a stranger can buy on itch.io and come back to.
Builds on `design/expansion-spec.md` (campaign rules) and `design/art/art-bible.md` (look).
Chosen by the player-owner on 2026-11-10: itch.io first, with saves and replay value, a
graphics quality setting and a release kit. Ads and Steam are out of scope.

## 1. Overview

Progress is saved between sessions: which levels are unlocked, each level's best time,
which golden gears were found, and the best full-run score. The title gets a level
select, an options page and credits. Levels 1 to 4 each hide three golden gears. A
graphics setting gives stronger PCs anti-aliasing, glow and sharper shadows while the
development PC keeps its 60 FPS look, and small spark and dust effects make hits and
landings read better. The game ships as a Windows download and a browser build.

## 2. Player fantasy

"I beat it, but I didn't find everything." Each level gets a reason to replay: three
golden gears tucked behind the key, under the course or on a high ledge, plus a best time
to beat. Coming back the next day starts where you left off.

## 3. Detailed rules

**Saved progress** (`user://progress.cfg`, written on level clear and on victory):

| Value | Rule |
|---|---|
| Unlocked levels | Level 1 is always open. Clearing level *n* opens level *n + 1*. Never goes down. |
| Best time per level | Seconds of play from entering the level to the key, counting time lost to deaths. Lower wins. Not changed by a Game Over. |
| Golden gears per level | Which of the three were collected, by index. A gear counts only once its level is cleared. |
| Best run score | Final score of a won run that started on level 1. Runs started from the level select don't count, because they skip levels. |
| Campaign won | True after the first victory. |

**Level select:** shown on the title when more than level 1 is unlocked. Each unlocked
level is a button with its name, gears found and best time. Choosing one starts a fresh
run (full lives, no power) on that level, which then carries on through the campaign as
normal. "Restart run" in the pause menu goes back to the level the run started on.

**Golden gears:** three per level on levels 1 to 4, none in the boss arena. Positions live
in `assets/data/level_campaign.json` (`golden_gears`), so level 1's file stays exactly as it
shipped. Touching one collects it, scores `score.golden_gear` and plays the reveal sound.
A gear found on an earlier clear shows as a pale ghost: it can still be touched for score,
but it adds nothing to the saved count. A Game Over retry rebuilds the level, so gears
collected in the failed attempt must be found again.

**HUD:** a gear plaque shows found and total for the current level, hidden on the boss level.

**Clear screen:** adds "Golden gears X of 3" and "Time m:ss.s", with "New best!" when it is one.

**Graphics quality** (saved with the other settings): `Low` or `High`.

| Setting | Low | High |
|---|---|---|
| 3D anti-aliasing | Off | MSAA 4x |
| Glow on emissive objects | Off | On |
| Directional shadow map | 2048 | 4096 |
| Spark and dust particles per burst | Half | Full |

The first launch picks the default from the graphics adapter's name: integrated Intel
graphics and the browser build start on Low, everything else on High. The player can
change it at any time from Options, and the change applies at once.

**Effects:** brass sparks when Tock stomps an enemy, a gold glint when a cog or golden gear
is collected, and a dust puff on landing from a fall faster than `effects.landing.min_speed`.
Off when Reduced motion is on. Pooled, so play allocates nothing.

**Menus:**

| Screen | Buttons |
|---|---|
| Title | Start, Level select (when unlocked), Options, Credits, Quit (not in the browser) |
| Options | Graphics: Low/High, Fullscreen: On/Off (not in the browser), Reduced motion: On/Off, Back |
| Pause | Resume, Restart run, Options, Title screen |
| Credits | Back |

Back or B on a sub-page returns to the page that opened it. Fullscreen also toggles with F11.

## 4. Formulas

- `best_time[n] = min(best_time[n], level_elapsed)` on clear, where `level_elapsed` is the
  sum of `delta` over every physics tick in the PLAYING state on that level.
- `unlocked = max(unlocked, n + 2)` on clearing level index `n` (0-based), capped at the
  campaign size.
- Golden gear score: `score.golden_gear` = 1000, the value of 10 cogs, rewarding the
  detour without beating a no-retry bonus (5000).
- Particles per burst: `round(effects.<kind>.amount × quality.<level>.effects_scale)`.

## 5. Edge cases

- **Missing or broken save file:** treated as a new player. Unknown keys are ignored.
- **Save from a longer campaign:** level indices past the campaign size are ignored.
- **Collecting a gear while dying:** a dead Tock collects nothing, as with all pickups.
- **Gear collected, then Game Over, then New run:** the gear was never banked.
- **Browser build:** no Quit button and no Fullscreen setting, because the browser owns both.
  The save lives in the browser's storage for that site.
- **Headless runs** (tests and tools): progress is kept in memory only, so the test suite
  never touches a player's save.

## 6. Dependencies

Main (flow, levels), RunState (elapsed time), Level (gear placement, signals), Screens
(menu pages), Hud (gear plaque), UiSettings (quality and fullscreen), Look (quality data).

## 7. Tuning knobs

- `gameplay_tuning.json`: `score.golden_gear`.
- `level_campaign.json`: `golden_gears`, one list of three `[x, y, z]` per level.
- `visual_look.json`: `quality.low` and `quality.high` (msaa, glow, shadow_size,
  effects_scale), `effects` (amount, colors, speeds, `landing.min_speed`), and material rows
  `golden_gear`, `golden_gear_halo`, `golden_gear_found`, `spark` and `dust`. Golden gears have
  no light of their own: each extra light redraws everything it touches.

## 8. Acceptance criteria

1. Clearing a level writes its best time, gears and the next unlock; a new session reads them back.
2. The level select starts a fresh run on the chosen level, and only unlocked levels are offered.
3. Every golden gear sits over a floor no more than 3 m below it, outside every solid, and
   outside the goal key's trigger.
4. A ghost gear scores but does not change the saved count.
5. Switching quality changes MSAA, glow and shadow size at once, and the choice survives a restart.
6. With Low quality on the development PC, gameplay stays at its current frame rate.
7. Effects allocate no nodes during play and are off with Reduced motion.
8. Windows and browser builds export from the command line and run the title screen.
9. Every new menu works with keyboard, mouse and gamepad, and Back always returns.
