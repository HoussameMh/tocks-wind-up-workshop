# Intro and outro films

The story is in [STORYLINES.md](STORYLINES.md), and the shot plan is in [SPEC.md](SPEC.md). The game plays `assets/video/tocks_workshop_intro.ogv` on launch and `tocks_workshop_outro.ogv` after the final key. Any button skips them, and the Reduced motion setting turns them off.

To change a film, work through these steps from the project root. `$FILM` is any folder outside the project for the raw frames. Each film is a [HyperFrames](https://hyperframes.heygen.com) project in `intro/` or `outro/`.

1. **Record the shots** from the real game with `tools/record_film.gd`. It needs a real window. Leave out the shot names you don't need:

```bash
godot --path . --resolution 640x360 --fixed-fps 30 --audio-driver Dummy -s res://tools/record_film.gd -- "$FILM" dusk key baron snatch winddown run_bench run_pencil run_paint run_wrench run_blaster run_boss title heap hat rewind wake even_him endcard
```

2. **Export the game's sound effects:**

```bash
godot --headless --path . --audio-driver Dummy -s res://tools/record_film.gd -- "$FILM" sfx
```

3. **Encode each shot** to `video/<film>/assets/shots/<shot>.mp4`:

```bash
ffmpeg -y -framerate 30 -i "$FILM/dusk/%05d.jpg" -c:v libx264 -crf 17 -g 10 -pix_fmt yuv420p video/intro/assets/shots/dusk.mp4
```

4. **Rebuild the projects.** This overwrites their HTML and adds the sound:

```bash
node video/tools/build_films.mjs "$FILM" video
```

5. **Render a film**, running this inside its project folder:

```bash
npx hyperframes render -o ../tocks_workshop_intro.mp4
```

6. **Convert it for Godot**, which can't play MP4:

```bash
ffmpeg -y -i video/tocks_workshop_intro.mp4 -vf scale=1280:720:flags=lanczos -r 30 -c:v libtheora -q:v 8 -c:a libvorbis -q:a 5 -ar 44100 assets/video/tocks_workshop_intro.ogv
```

The shot videos and MP4 masters aren't in Git, because they're large and can be rebuilt this way.
