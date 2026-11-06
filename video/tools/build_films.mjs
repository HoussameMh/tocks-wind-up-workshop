// One-off generator: writes plain, editable HyperFrames projects for the intro and outro, and the
// tick tracks. Usage: node build_films.mjs <film frames dir> <video dir>
import fs from "node:fs";
import path from "node:path";

const [framesDir, videoDir] = process.argv.slice(2);
const INK = "#fff3d6";

const cogPath = (() => {
  const teeth = 10, outer = 50, root = 39, hole = 16;
  const pts = [];
  for (let i = 0; i < teeth; i++) {
    const a = (i / teeth) * Math.PI * 2, w = (Math.PI * 2) / teeth;
    for (const [off, r] of [[-0.27, root], [-0.17, outer], [0.17, outer], [0.27, root]]) {
      const b = a + off * w;
      pts.push(`${(50 + Math.cos(b) * r).toFixed(2)} ${(50 + Math.sin(b) * r).toFixed(2)}`);
    }
  }
  return `M${pts.join("L")}Z M${50 + hole} 50 A${hole} ${hole} 0 1 0 ${50 - hole} 50 A${hole} ${hole} 0 1 0 ${50 + hole} 50Z`;
})();

const BRASS = "linear-gradient(180deg,#ffe9a8 0%,#f2c04e 48%,#b97a16 100%)";
const STYLE = `
    #root { position: absolute; inset: 0; overflow: hidden; background: #140d08; font-family: "Open Sans", sans-serif; }
    .shot { position: absolute; left: 0; top: 0; width: 1920px; height: 1080px; object-fit: cover; }
    .band { position: absolute; left: 0; top: 0; width: 1920px; height: 1080px; z-index: 4; }
    .scrim { position: absolute; inset: 0; background: linear-gradient(20deg, rgba(14,8,3,0.82) 0%, rgba(14,8,3,0.42) 26%, rgba(14,8,3,0) 52%); }
    .line { position: absolute; left: 192px; bottom: 124px; font-size: 84px; line-height: 1.12; font-weight: 800; letter-spacing: -0.01em; color: ${INK}; filter: drop-shadow(0 5px 0 rgba(26,14,4,0.95)); white-space: nowrap; }
    .line.big { font-size: 132px; }
    .line.snug { font-size: 70px; }
    .line.right { left: auto; right: 192px; }
    .line.top { bottom: auto; top: 124px; }
    .scrim.right { background: linear-gradient(-20deg, rgba(14,8,3,0.82) 0%, rgba(14,8,3,0.42) 26%, rgba(14,8,3,0) 52%); }
    .scrim.top { background: linear-gradient(160deg, rgba(14,8,3,0.82) 0%, rgba(14,8,3,0.42) 26%, rgba(14,8,3,0) 52%); }
    .who { display: block; font-size: 46px; margin-bottom: 8px; }
    .w { display: inline-block; margin-right: 0.26em; }
    .gold { background: ${BRASS}; -webkit-background-clip: text; background-clip: text; color: transparent; }
    .dip { position: absolute; inset: 0; background: #0a0603; opacity: 0; }
    .flood { position: absolute; inset: 0; background: ${BRASS}; }`;

const words = (text) =>
  text.split(" ").map((w) => {
    if (w === "|") return "<br />";
    const gold = w.startsWith("*");
    return `<span class="w${gold ? " gold" : ""}">${gold ? w.slice(1) : w}</span>`;
  }).join("");

function lineMarkup(id, n, l) {
  const who = l.who ? `<span class="who gold">${l.who}</span>` : "";
  return `    <div id="${id}-line${n}" class="clip band" data-start="${l.at}" data-duration="${(l.to - l.at).toFixed(2)}" data-track-index="${5 + n}">
      <div id="${id}-fade${n}" class="band">
        <div class="scrim${l.place ? ` ${l.place}` : ""}"></div>
        <div class="line${l.big ? " big" : ""}${l.place ? ` ${l.place}` : ""}">${who}${words(l.text)}</div>
      </div>
    </div>`;
}

function lineMotion(id, n, l) {
  const gap = l.gap ?? 0.08;
  return `    tl.fromTo("#${id}-fade${n}", { opacity: 0 }, { opacity: 1, duration: 0.15, ease: "power2.out" }, ${l.at});
    tl.fromTo("#${id}-line${n} .w", { opacity: 0, filter: "blur(6px)" }, { opacity: 1, filter: "blur(0px)", duration: 0.14, stagger: ${gap}, ease: "power4.out" }, ${l.at});
    tl.to("#${id}-fade${n}", { opacity: 0, filter: "blur(8px)", duration: 0.2, ease: "power3.in" }, ${(l.to - 0.24).toFixed(2)});`;
}

function scene(s) {
  const clips = s.clips ?? [{ src: s.id, media: s.media ?? 0, dur: s.dur }];
  let t = 0;
  const videos = clips.map((c, i) => {
    const html = `    <video id="${s.id}-v${i}" class="clip shot" src="assets/shots/${c.src}.mp4" muted playsinline data-start="${t.toFixed(2)}" data-duration="${c.dur}" data-media-start="${c.media}" data-track-index="0" style="z-index:1"></video>`;
    t += c.dur;
    return html;
  });
  const lines = (s.lines ?? []).map((l, n) => lineMarkup(s.id, n, l));
  const motions = (s.lines ?? []).map((l, n) => lineMotion(s.id, n, l));
  let extra = "";
  if (s.logo) extra += logoMarkup(s.id);
  if (s.end) extra += endMarkup(s.id);
  if (s.iris) {
    extra += `\n    <div id="${s.id}-floodc" class="clip band" data-start="0" data-duration="0.5" data-track-index="9" style="z-index:8"><div id="${s.id}-flood" class="flood"></div></div>`;
    motions.push(`    tl.fromTo("#${s.id}-flood", { clipPath: "circle(120% at 64% 58%)" }, { clipPath: "circle(0% at 64% 58%)", duration: 0.42, ease: "power3.inOut" }, 0.02);`);
  }
  if (s.dip) {
    extra += `\n    <div id="${s.id}-dipc" class="clip band" data-start="${(s.dur - 0.4).toFixed(2)}" data-duration="0.4" data-track-index="10" style="z-index:9"><div id="${s.id}-dip" class="dip"></div></div>`;
    motions.push(`    tl.fromTo("#${s.id}-dip", { opacity: 0 }, { opacity: ${s.dip}, duration: 0.36, ease: "power2.in" }, ${(s.dur - 0.4).toFixed(2)});`);
  }
  if (s.logo) motions.push(logoMotion(s.id));
  if (s.end) motions.push(endMotion(s.id));
  return `<template>
  <style>${STYLE}${s.logo ? LOGO_STYLE : ""}${s.end ? END_STYLE : ""}
  </style>
  <div id="root" data-composition-id="${s.id}" data-start="0" data-duration="${s.dur}" data-width="1920" data-height="1080">
${videos.join("\n")}
${lines.join("\n")}${extra}
  </div>
  <script>
    const tl = gsap.timeline({ paused: true });
${motions.join("\n")}
    window.__timelines["${s.id}"] = tl;
  </script>
</template>
`;
}

const LOGO_STYLE = `
    .logo { position: absolute; left: 150px; top: 120px; font-weight: 800; letter-spacing: 0.015em; filter: drop-shadow(0 7px 0 rgba(26,14,4,0.95)); }
    .logo .row { display: block; line-height: 1.04; white-space: nowrap; }
    .logo .c { display: inline-block; background: ${BRASS}; -webkit-background-clip: text; background-clip: text; color: transparent; }
    .logo .r1 { font-size: 112px; } .logo .r2, .logo .r3 { font-size: 146px; }
    .logo svg { display: inline-block; width: 92px; height: 92px; vertical-align: -6px; margin: 0 2px; }
    .logo-scrim { position: absolute; inset: 0; background: linear-gradient(90deg, rgba(14,8,3,0.84) 0%, rgba(14,8,3,0.58) 34%, rgba(14,8,3,0) 62%); }`;

function letters(text) {
  return [...text].map((c) => `<span class="c">${c}</span>`).join("");
}

function logoMarkup(id) {
  return `
    <div id="${id}-logoc" class="clip band" data-start="0.5" data-duration="4.1" data-track-index="7" style="z-index:5">
      <div id="${id}-scrim" class="logo-scrim"></div>
      <div class="logo">
        <span class="row r1">${letters("T")}<svg id="${id}-cog" viewBox="0 0 100 100"><defs><linearGradient id="brass" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffe9a8"/><stop offset="0.5" stop-color="#f2c04e"/><stop offset="1" stop-color="#b97a16"/></linearGradient></defs><path d="${cogPath}" fill="url(#brass)" fill-rule="evenodd"/></svg>${letters("CK'S")}</span>
        <span class="row r2">${letters("WIND-UP")}</span>
        <span class="row r3">${letters("WORKSHOP")}</span>
      </div>
    </div>`;
}

function logoMotion(id) {
  return `    tl.fromTo("#${id}-scrim", { opacity: 0 }, { opacity: 1, duration: 0.3, ease: "power2.out" }, 0.5);
    tl.fromTo("#${id}-logoc .c", { opacity: 0.0, y: 34, filter: "blur(5px)" }, { opacity: 1, y: 0, filter: "blur(0px)", duration: 0.26, stagger: 0.028, ease: "back.out(1.5)" }, 0.55);
    tl.fromTo("#${id}-cog", { opacity: 0, rotation: -200, scale: 0.4, transformOrigin: "50% 50%" }, { opacity: 1, rotation: 0, scale: 1, duration: 0.7, ease: "back.out(1.3)" }, 0.6);`;
}

const END_STYLE = `
    .endt { position: absolute; left: 150px; top: 190px; }
    .endt .big { display: block; font-size: 190px; line-height: 1; font-weight: 800; filter: drop-shadow(0 8px 0 rgba(26,14,4,0.95)); }
    .endt .big .w { margin-right: 0.22em; }
    .endt .small { display: block; margin-top: 22px; font-size: 68px; font-weight: 700; color: ${INK}; filter: drop-shadow(0 4px 0 rgba(26,14,4,0.95)); }
    .logo-scrim { position: absolute; inset: 0; background: linear-gradient(90deg, rgba(14,8,3,0.84) 0%, rgba(14,8,3,0.58) 34%, rgba(14,8,3,0) 62%); }`;

function endMarkup(id) {
  return `
    <div id="${id}-endc" class="clip band" data-start="0.3" data-duration="4.5" data-track-index="7" style="z-index:5">
      <div id="${id}-scrim" class="logo-scrim"></div>
      <div class="endt">
        <span class="big"><span class="w gold">The</span><span class="w gold">End</span></span>
        <span id="${id}-thanks" class="small">Thanks for playing</span>
      </div>
    </div>`;
}

function endMotion(id) {
  return `    tl.fromTo("#${id}-scrim", { opacity: 0 }, { opacity: 1, duration: 0.4, ease: "power2.out" }, 0.3);
    tl.fromTo("#${id}-endc .big .w", { opacity: 0, y: 40, filter: "blur(6px)" }, { opacity: 1, y: 0, filter: "blur(0px)", duration: 0.4, stagger: 0.16, ease: "back.out(1.5)" }, 0.45);
    tl.fromTo("#${id}-thanks", { opacity: 0, filter: "blur(6px)" }, { opacity: 1, filter: "blur(0px)", duration: 0.2, ease: "power4.out" }, 1.25);`;
}

const films = {
  intro: {
    scenes: [
      { id: "dusk", dur: 4.2, lines: [{ text: "The workshop closes at dusk", at: 0.35, to: 3.95 }] },
      { id: "key", dur: 4.6, lines: [{ text: "One *Golden *Key winds every toy", at: 0.5, to: 4.4 }] },
      { id: "baron", dur: 5.2, dip: 0.45, lines: [{ text: "Nobody ever wound *Baron *Rust", at: 2.6, to: 5.1 }] },
      { id: "snatch", dur: 4.8, dip: 0.6, lines: [{ text: "So he took it", at: 2.5, to: 4.6, place: "right" }] },
      { id: "winddown", dur: 8.2, lines: [
        { text: "Every toy wound down", at: 2.75, to: 5.05, gap: 0.16 },
        { text: "All but *one", at: 5.85, to: 8.05, gap: 0.3, big: true, place: "top" },
      ] },
      { id: "run", dur: 7.9, clips: [
        { src: "run_bench", media: 0.7, dur: 1.3 },
        { src: "run_pencil", media: 0.65, dur: 1.2 },
        { src: "run_paint", media: 0.9, dur: 1.3 },
        { src: "run_wrench", media: 0.35, dur: 1.2 },
        { src: "run_blaster", media: 0.35, dur: 1.2 },
        { src: "run_boss", media: 0.0, dur: 1.7 },
      ], lines: [
        { text: "One wind left", at: 0.2, to: 2.3 },
        { text: "Run, *Tock", at: 6.2, to: 7.85, big: true },
      ] },
      { id: "title", dur: 4.6, iris: true, logo: true },
    ],
    // Absolute seconds.
    sfx: [
      ["jump", 2.3], ["reveal", 4.35], ["boss_grumble", 10.65], ["armor_clang", 12.4],
      ["spring", 14.92], ["crate", 15.22], ["boss_grumble", 16.7],
      ["boss_droop", 21.3], ["bolt_clink", 24.0], ["jump", 24.45], ["teeth_wind", 26.1],
      ["stomp", 27.65], ["jump", 28.45], ["paint_sloop", 29.8], ["wrench_clank", 31.05],
      ["bolt_fire", 32.3], ["bolt_hit", 32.7], ["boss_slam", 33.2], ["jump", 34.15],
      ["clear", 35.45],
    ],
    // [from, gap] pairs; a gap of 0 stops the ticking there.
    ticks: [[0, 0.5], [20.8, 0.7], [21.7, 1.1], [22.6, 0], [24.0, 0], [26.0, 0.25], [34.8, 0]],
    single: [24.0],
  },
  outro: {
    scenes: [
      { id: "heap", dur: 4.2, lines: [{ who: "Baron Rust", text: "I seem to have come unscrewed", at: 2.0, to: 4.15 }] },
      { id: "hat", dur: 3.6 },
      { id: "rewind", dur: 4.6, lines: [{ text: "The *Golden *Key | turned again", at: 2.2, to: 4.5, place: "snug" }] },
      { id: "wake", dur: 6.2, lines: [{ text: "Every toy woke up", at: 2.3, to: 5.9 }] },
      { id: "even_him", dur: 6.8, dip: 0.4, lines: [{ text: "Even *him", at: 3.3, to: 6.6, big: true, gap: 0.3 }] },
      { id: "endcard", dur: 4.8, end: true },
    ],
    sfx: [
      ["boss_down", 0.2], ["armor_clang", 3.1], ["thud", 5.4], ["jump", 5.5],
      ["jump", 9.35], ["reveal", 9.7], ["power", 9.95],
      ["win", 12.75], ["duck_squeak", 13.7], ["teeth_chatter", 14.3], ["plane_fwip", 15.1], ["teeth_chatter", 16.2], ["duck_raspberry", 17.1],
      ["bolt_clink", 19.9], ["teeth_wind", 20.35], ["boss_phase", 20.85], ["jump", 22.0],
      ["clear", 25.75],
    ],
    ticks: [[9.8, 0.5], [12.4, 0.3], [18.6, 0], [20.3, 0.4], [25.4, 0.5], [30.0, 0]],
    single: [],
  },
};

function readWav(file) {
  const b = fs.readFileSync(file);
  let p = 12, rate = 22050, data = null;
  while (p + 8 <= b.length) {
    const id = b.toString("ascii", p, p + 4), size = b.readUInt32LE(p + 4);
    if (id === "fmt ") rate = b.readUInt32LE(p + 12);
    if (id === "data") data = b.subarray(p + 8, p + 8 + size);
    p += 8 + size + (size % 2);
  }
  return { rate, data };
}

function writeTicks(file, tickWav, film, seconds) {
  const { rate, data } = readWav(tickWav);
  const out = new Int16Array(Math.ceil(seconds * rate));
  const place = (t, gain) => {
    const start = Math.round(t * rate);
    for (let i = 0; i * 2 + 1 < data.length && start + i < out.length; i++) {
      const v = out[start + i] + data.readInt16LE(i * 2) * gain;
      out[start + i] = Math.max(-32000, Math.min(32000, v));
    }
  };
  for (let i = 0; i < film.ticks.length; i++) {
    const [from, gap] = film.ticks[i];
    if (!gap) continue;
    const to = i + 1 < film.ticks.length ? film.ticks[i + 1][0] : seconds;
    let beat = 0;
    for (let t = from; t < to; t += gap) { place(t, beat % 2 ? 0.55 : 0.8); beat++; }
  }
  for (const t of film.single) place(t, 1.0);
  const head = Buffer.alloc(44);
  head.write("RIFF", 0); head.writeUInt32LE(36 + out.length * 2, 4); head.write("WAVEfmt ", 8);
  head.writeUInt32LE(16, 16); head.writeUInt16LE(1, 20); head.writeUInt16LE(1, 22);
  head.writeUInt32LE(rate, 24); head.writeUInt32LE(rate * 2, 28); head.writeUInt16LE(2, 32); head.writeUInt16LE(16, 34);
  head.write("data", 36); head.writeUInt32LE(out.length * 2, 40);
  fs.writeFileSync(file, Buffer.concat([head, Buffer.from(out.buffer)]));
}

for (const [name, film] of Object.entries(films)) {
  const dir = path.join(videoDir, name);
  fs.mkdirSync(path.join(dir, "compositions"), { recursive: true });
  fs.mkdirSync(path.join(dir, "assets", "sfx"), { recursive: true });
  let t = 0;
  const hosts = film.scenes.map((s, i) => {
    fs.writeFileSync(path.join(dir, "compositions", `${s.id}.html`), scene(s));
    const html = `      <div id="${s.id}" data-composition-id="${s.id}" data-composition-src="compositions/${s.id}.html" data-start="${t.toFixed(2)}" data-duration="${s.dur}" data-track-index="1" data-track-kind="graphics" data-width="1920" data-height="1080" style="z-index:${i + 1}"></div>`;
    t += s.dur;
    return html;
  });
  const total = t;
  for (const [sound] of film.sfx) {
    fs.copyFileSync(path.join(framesDir, "sfx", `${sound}.wav`), path.join(dir, "assets", "sfx", `${sound}.wav`));
  }
  writeTicks(path.join(dir, "assets", "sfx", "clockwork_ticks.wav"), path.join(framesDir, "sfx", "bolt_clink.wav"), film, total);
  const audio = film.sfx.map(([sound, at], i) => {
    const wav = readWav(path.join(framesDir, "sfx", `${sound}.wav`));
    const seconds = (wav.data.length / 2 / wav.rate).toFixed(2);
    return `      <audio id="sfx-${i}-${sound}" class="clip" src="assets/sfx/${sound}.wav" data-start="${at}" data-duration="${seconds}" data-track-index="${20 + (i % 4)}" data-volume="${name === "outro" ? 1.55 : 2.6}"></audio>`;
  });
  audio.push(`      <audio id="ticks" class="clip" src="assets/sfx/clockwork_ticks.wav" data-start="0" data-duration="${total.toFixed(2)}" data-track-index="30" data-volume="${name === "outro" ? 0.66 : 1.1}"></audio>`);
  fs.writeFileSync(path.join(dir, "index.html"), `<!doctype html>
<html lang="en" data-resolution="landscape">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=1920, height=1080" />
    <script src="https://cdn.jsdelivr.net/npm/gsap@3.15.0/dist/gsap.min.js"></script>
    <style>
      * { margin: 0; padding: 0; box-sizing: border-box; }
      html, body { margin: 0; width: 1920px; height: 1080px; overflow: hidden; background: #140d08; }
    </style>
  </head>
  <body>
    <div id="root" data-composition-id="main" data-start="0" data-duration="${total.toFixed(2)}" data-width="1920" data-height="1080">
${hosts.join("\n")}
${audio.join("\n")}
    </div>
    <script>
      window.__timelines["main"] = gsap.timeline({ paused: true });
    </script>
  </body>
</html>
`);
  console.log(name, "total", total.toFixed(2));
}
