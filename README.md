# Tock's Wind-Up Workshop

An original 3D platformer made with Godot 4.7. Play as Tock, a tiny clockwork toy racing across a real craftsman's workshop at dusk: stomp rusty gear-beetles, crack open toy boxes, hunt for secrets and reach the Golden Key before the clock runs out.

![Tock at the start of the Workbench Run course](docs/images/start_of_course.png)

> **Status: early playable.** One complete level works from start to finish, with realistic materials and lighting, a full menu and gamepad support. Four more levels, new enemies, a shooting power and a final boss are in progress.

## Play it

1. Install [Godot 4.7](https://godotengine.org/download). On Windows you can run `winget install GodotEngine.GodotEngine`.
2. Clone this repository.
3. From the project folder, run:

```bash
godot --path .
```

If `godot` isn't recognized, use the full path to the Godot executable instead. You can also open `project.godot` in the Godot editor and press F5.

## Controls

| Action | Keyboard and mouse | Gamepad (tested with simulated input only) |
|---|---|---|
| Move | WASD or arrow keys | Left stick |
| Jump (hold to jump higher) | Space | A |
| Run | Shift | X |
| Camera | Mouse, or Q and E | Right stick |
| Pause | Esc | Start |

## What's in the game

- **Movement:** walking, running and variable-height jumps, with forgiving jump timing at ledges and on landing.
- **Workbench Run:** one course of workbenches, a moving platform, a spring pad and toy-block steps, with two checkpoints.
- **Gear-beetles:** 9 patrolling enemies. Stomp them from above, because any other contact hurts.
- **Toy boxes:** bump them from below for cogs, a Coil Spring or a spare key. Two of them are hidden.
- **Coil Spring:** makes Tock bigger, lets him jump higher and break crates, and lets him survive one extra hit.
- **The workshop:** real wood, metal, plaster and concrete textures, warm lamp lighting, a dusk window, and a pegboard with hung tools. Tock and the beetles are well-made toy figures rather than photoreal characters, because everything is built in code without imported models.
- **Game systems:** cogs, lives, score, a timer, a HUD, menus and sound effects generated in code.

## What we did

This game was built with [Claude Code](https://claude.com/claude-code), on top of the [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios) template.

1. **Set up the tools.** Installed the template and the `find-skills` skill, and reviewed the template's automatic hooks before adding them.
2. **Chose an original concept.** Designed a new hero, world and enemies, written up in the [game brief](design/game-brief.md).
3. **Built the first playable.** Wrote the movement, camera, enemies, level, menus and sound in GDScript, with gameplay values kept in [data files](assets/data/data_reference.md) so they can be tuned without code changes.
4. **Tested it.** Added 31 automated tests that run the real game with real physics, including a bot that finishes the whole course. Breaking the jump height on purpose made the bot fail, which confirms that test can catch an impossible level.
5. **Tuned it for low-end hardware.** Measured frame rate on an Intel HD 520 and changed settings based on the results, reaching a steady 60 FPS on the title screen. Gameplay ran at about 90 FPS uncapped when measured, and is capped at 60.
6. **Upgraded the visuals with the studio's specialists.** Used `find-skills` to find and install the `godot-shaders` and `godot-ui-control` skills, and added free [CC0 textures](assets/textures/texture_sources.md). The studio's art director wrote the [art bible](design/art/art-bible.md), and its technical artist rebuilt the materials, lighting and scenery from it. Merging meshes also made the game faster: the slowest spot measured went from about 57 FPS to about 80 FPS uncapped. Glow was cut because it cost too much on this hardware, and edges remain jagged because anti-aliasing is off.
7. **Rebuilt the menus and added gamepad support.** The studio's UI programmer added a cast-brass title over the live 3D scene, restyled the other screens and HUD, and made menus and play work with a controller. Those controller tests use simulated events, so a real controller is still unproven. There are now 58 automated tests.
8. **Fixed a playtest bug.** Holding an arrow key made the 3-button menu spin so fast that it often stopped on the opposite button. Menus now stop at their ends, and one press moves one step.
9. **Now in progress.** Four more levels, new enemies, a shooting power and a final boss.

## Project layout

| Folder | Contents |
|---|---|
| `src/` | Game code: `core`, `gameplay`, `ui` and `audio` |
| `assets/` | Tuning data, the level layout and textures |
| `design/` | Game brief and design documents |
| `tests/` | Unit and integration tests |
| `tools/` | Screenshot and frame-rate tools |
| `.claude/` | Studio agents, skills, hooks and rules from the template |

## Run the tests

```bash
godot --headless --path . --import
```

```bash
godot --headless --path . --fixed-fps 60 -s res://tests/run_tests.gd
```

The test run exits with 0 if everything passed, 1 on failures, 2 if no tests were found and 3 if a test stalled.

## Roadmap

- Testing on a real controller
- Four more levels, new enemies, a shooting power and a boss fight against Baron Rust
- Music
- A standalone Windows build

## Credits and licenses

- **Studio template:** [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios) by Donchitos, under the [MIT License](LICENSE). Its original README is kept at [docs/studio-template-readme.md](docs/studio-template-readme.md).
- **Textures:** [Poly Haven](https://polyhaven.com), under CC0.
- **Engine:** [Godot Engine](https://godotengine.org), under the MIT License.
