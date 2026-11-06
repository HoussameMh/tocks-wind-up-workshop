# Spec: One Wind Left

GOAL: the viewer wants to run for Tock after the intro, and smiles at the Baron's fate after the outro.
OUTPUT: HyperFrames, 1920 x 1080, 30 fps. Two projects: `intro/` and `outro/`. Shots come from `tools/record_film.gd`.
TIME: intro about 38 s, outro about 29 s. No music clock: the action is the clock.
LOOK: the game itself, at dusk. No drawn characters. Type: Open Sans 800, matching the game's logo font, 84 px, brass gradient `#f6d77a` to `#c98a1c`, dark offset shadow 0 6 0 `#2a1a08` so it holds on wood. One line at a time, left aligned in the lower left, never centered, except the logo lockup.
OBJECTS: Tock, Baron Rust, the Golden Key, gear-beetles, the rubber duck, chattering teeth and the paper plane, all the game's real models.
MOTION: titles land with a per-word blur (6 px to 0, 0.13 s, 0.08 s apart) and then hold dead still. Exits: blur-out in 0.2 s. A cut comes on an action wherever one exists.

SHOTS, intro:
1. dusk, 0 to 4.2: Tock hops on the bench. "The workshop closes at dusk."
2. key, 4.2 to 8.8: push toward the Golden Key, toys playing round it. "One Golden Key winds every toy." Hard cut.
3. baron, 8.8 to 14: the Baron wakes, moustache flicks up, fists rise. "Nobody ever wound Baron Rust." Dip cut.
4. snatch, 14 to 18.8: neck lunges, key taken, Tock startled. "So he took it." Dip cut.
5. winddown, 18.8 to 27: Tock and a beetle slow to a stop as the room dims. "Every toy wound down." One click. "All but one."
6. montage, 27 to 33.8: real play, each about 1.1 s: stomp, pencil, paint, wrench, Blaster, boss ring. Hard cuts on action. "One wind left."
7. title, 33.8 to 38.4: Tock lands on the bench. The logo lands.

SHOTS, outro:
1. heap, 0 to 4.2: the Baron rattles, the hat launches, he collapses. "I seem to have come unscrewed."
2. hat, 4.2 to 7.8: the hat lands on Tock. His reaction carries it, with no caption.
3. rewind, 7.8 to 12.4: Tock jumps and spins the key. "The Golden Key turned again."
4. wake, 12.4 to 18.6: the toys dance as the room brightens. "Every toy woke up."
5. even_him, 18.6 to 25.4: Tock puts a key on the Baron, and his moustache rises. "Even him."
6. endcard, 25.4 to 30.2: Tock waves. "The End" and "Thanks for playing."

BANNED: the defaults in the skill's spec, plus drawn stand-ins for game models, text moving while it's read, centered captions, a voiceover, and synthesized music written in code.
QA: thumbnails at 0 s must show Tock. The snatch must read with the words covered. "All but one." must land after the click. Every line must be readable at phone width.
