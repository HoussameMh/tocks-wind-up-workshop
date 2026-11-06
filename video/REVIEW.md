# Review: One Wind Left

**Creative calls**
- I built storyline A from `STORYLINES.md`, with footage from the real game engine (`tools/record_film.gd`) rather than drawn characters, so the films match what the player sees.
- No voiceover. The titles and the action carry the story.
- The clockwork tick is the story's sound: it slows, stops when the toys wind down, gives one click on "All but one", then races.

**Measured or looked at**
- `hyperframes check` passes on both films.
- I looked at the beat sheets and specific frames at each story moment.
- Sound was measured, not heard. Nobody has listened to the mix.
- No person has watched either film yet.

**Weakest shots**
- The wrench shot in the run montage is the least exciting, because Tock is small and the moment is quiet.
- Tock has no facial animation, since his model can't change expression, so his reactions rely on his body and key.

**Warnings kept on purpose**
- `nested_media_start_basis_ambiguous` on the montage clips: their times are meant to be local to the scene.

**Missing**
- No music: the free route needs a local MusicGen install and the catalog needs a HeyGen sign-in. Your own track can be added as one `<audio>` line.
