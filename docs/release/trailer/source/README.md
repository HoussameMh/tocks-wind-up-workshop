# Trailer source

The code behind `../tocks-wind-up-workshop-trailer.mp4`, made with the
[Lemo-Opuscar](https://github.com/lemomo-ai/lemo-opuscar) film library in its Brick Toy style. The
story, shots and timing are in [`../TREATMENT.md`](../TREATMENT.md), and the third-party assets in
[`../CREDITS`](../CREDITS).

The source only builds inside the library, which supplies the renderer, the sample library and the
desk textures. To rebuild it:

1. Clone the library, then copy this folder's files into `films/tock-trailer/` inside it.
2. From the library folder, install its tools and assets:

```bash
sh plugin/skills/lemo-opuscar/scripts/setup.sh deps music
```

```bash
sh tools/fetch.sh hdri
```

```bash
sh tools/fetch.sh instruments vcsl
```

3. Build the film, about 30 minutes on an Intel HD 520:

```bash
sh films/tock-trailer/build.sh
```

`bricks.js` is the library's brick geometry module, used under the MIT License in
[`LICENSE-lemo-opuscar`](LICENSE-lemo-opuscar). Everything else here was written for this trailer.
