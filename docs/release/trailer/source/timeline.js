// One timeline for picture, sound and score. 120 bpm, 4/4: one bar = 2 s. Acting steps at 12 fps.
export const DUR = 44;
export const ANIM_FPS = 12;
export const BPM = 120, BEAT = 60 / BPM, BAR = 4 * BEAT;
export const q = t => Math.floor(t * ANIM_FPS + 1e-6) / ANIM_FPS;
export const qc = t => Math.ceil(t * ANIM_FPS - 1e-6) / ANIM_FPS;   // first frame an event is on screen

export const T = {
  jawIn: 2.0, clamp: 2.5, yank: 2.75,
  snaps: [5.0, 5.5, 6.0, 6.5, 7.0, 7.5], keySnap: 8.0, wind: 8.5, joy: 9.25,
  raise: 11.5,
  run: 14.0, jump: 15.5, stomp: 16.0,
  slide: 18.0, spin: 19.5, slideStop: 21.0,
  aim: 22.0, bolts: [22.5, 23.0, 23.5], planeHit: 23.75, blow: 25.0,
  silence: 26.0, slam: 28.0, hop: 29.0, landHead: 29.75, tip: 30.25, crash: 31.0, keyUp: 32.5,
  setDown: 35.0, vee: 35.5, glint: 36.0, lampOff: 37.0, title: 39.0, sub: 40.2, itch: 41.2, windStop: 43.0,
};

// [start, end, name]: every cut on a bar line
export const SHOTS = [
  [0, 4, 'clock'], [4, 10, 'build'], [10, 14, 'baron'], [14, 18, 'ruler'], [18, 22, 'paint'],
  [22, 26, 'shoot'], [26, 28, 'lonely'], [28, 34, 'fight'], [34, 37, 'return'], [37, DUR, 'dark'],
];
export const shotAt = t => SHOTS.find(s => t >= s[0] && t < s[1]) || SHOTS[SHOTS.length - 1];

export const CAPTIONS = [
  { t0: 5.0, t1: 9.8, text: 'Tock is the smallest toy in the workshop.' },
  { t0: 10.2, t1: 13.9, text: 'Baron Rust took the Golden Key.' },
  { t0: 15.9, t1: 17.9, text: 'Stomp!' },
  { t0: 19.4, t1: 21.8, text: 'Slide!' },
  { t0: 23.6, t1: 25.8, text: 'Shoot!' },
];
