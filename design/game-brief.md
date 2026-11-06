# Game Brief: Tock's Wind-Up Workshop

**One-sentence pitch:** A pocket-sized clockwork kid races across a giant toy workshop in a bright 3D platformer, stomping rusty gear-beetles, cracking open toy boxes and hunting secrets before Baron Rust seizes every moving part.

## Core loop
- Run and jump along a course of workbenches, shelves and toy blocks.
- Stomp beetles, bump toy boxes from below, and collect brass cogs for extra lives.
- Grab the Coil Spring to grow, jump higher, smash crates and survive one extra hit.
- Reach the Golden Key, get scored, and go for a better run.

## Player goal & fail state — what "working" looks like
- **Win:** touch the Golden Key at the end of the course before the timer runs out.
- **Fail:** a beetle touches small Tock, Tock falls off the course, or the timer ends. Each costs a life and returns Tock to the last checkpoint. Zero lives is game over.

## MVP — what must exist to be the game
- Responsive 3D movement: walk, run, variable-height jump, with coyote time and jump buffering.
- Follow camera with mouse and gamepad control.
- One complete course: Workbench Run.
- Gear-beetles that can be stomped and can hurt Tock.
- Toy boxes (cog, Coil Spring, spare key), breakable crates and hidden boxes.
- Checkpoints, moving platform, spring pad, Golden Key goal.
- HUD, title, pause, game over and level-clear screens, and generated sound effects.

## Out of scope — not building this
- Any character, name, art, music or level taken from an existing game. Everything here is original.
- World map (next milestone). Levels 2 to 5, the Bolt Blaster, four new enemies and the Baron Rust fight were added later: see [the expansion spec](expansion-spec.md).
- Final art, music, save system, multiplayer and localization files.

## Build order
1. Movement, camera and jump feel: the riskiest part, and the fun depends on it.
2. Course geometry, proven reachable by an automated run-through.
3. Enemies, toy boxes, power-up, collectibles and goal.
4. HUD, menus, sound and playtest.

---
**Who it's for / what they feel:** Players who love classic mascot platformers and want a quick, cheerful, skill-based 10-minute run.

**Art & audio direction:** Chunky low-poly toys in saturated colors on warm wood, with simple synthesized blips; light enough for integrated graphics.

**Reference game:** The classic mascot platformer genre: run, stomp, power-up and secrets on a short course, with none of any existing game's characters or assets.

## Characters

| Name | Role | Notes |
|---|---|---|
| **Tock** | Hero | Clockwork kid: brass body, teal overalls, red cap, a spinning wind-up key on the back |
| **Gear-beetle** | Basic enemy | Rusty dome with a gear turning on its back |
| **Armored beetle** | Enemy | A gear-beetle hiding under a saucepan lid: two stomps, and it panics in between |
| **Paper-plane bomber** | Enemy | Drops erasers, then swoops low enough to stomp, looking smug |
| **Rubber-duck sniper** | Enemy | Squeaks, inflates and spits bubbles. Blows a raspberry after |
| **Chattering teeth** | Enemy | Wind up loudly, hop after Tock, and laugh at ledges they will not cross |
| **Baron Rust** | Final boss, level 5 | A vain old bench vise with a moustache, a monocle and a very small hat |
