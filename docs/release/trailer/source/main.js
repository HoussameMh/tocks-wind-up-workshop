// Tock's Wind-Up Workshop: a Brick Toy trailer. render(t) draws any frame on its own.
import * as THREE from 'three';
import { makePost } from '/core/three/post.js';
import { clamp, seg, eio, eo, ss, lerp, hash, mulberry } from '/core/lib.js';
import { BRICK, PLATE, brick, mesh, roundGeo } from './bricks.js';
import { DUR, T, SHOTS, shotAt, q, qc, CAPTIONS } from './timeline.js';
import { buildSet, groundY, KEY_SPOT, BUILD, BOOKS, ARENA, RULER, PAINT, SHOOT, CLOCK } from './set.js';
import { makeTock, makeBaron, makeBeetle, makeKey, makePlane, makeBlaster, walkPose, C, HIP, SHOULDER } from './actors.js';

const W = 1920, H = 1080;
const renderer = new THREE.WebGLRenderer({ antialias: false, preserveDrawingBuffer: true });
renderer.setPixelRatio(2); renderer.setSize(W, H);
renderer.toneMapping = THREE.NeutralToneMapping; renderer.toneMappingExposure = 1.0;
renderer.shadowMap.enabled = true; renderer.shadowMap.type = THREE.PCFSoftShadowMap;
document.getElementById('stage').appendChild(renderer.domElement);
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(32, W / H, .5, 3000);
const post = makePost(renderer, scene, camera, W, H, { ssaa: 2, ao: true, aoRadius: 3.5, aoThickness: 3, aoAmt: .9 });
post.bloom.strength = .16; post.bloom.threshold = 1.2;
const vig = post.vig.uniforms;
vig.amt.value = .34; vig.warm.value = -.3; vig.contrast.value = .24; vig.sat.value = 1.1;

const set = await buildSet(scene);
const V = (x, y, z) => new THREE.Vector3(x, y, z);
const FWD = ry => V(Math.sin(ry), 0, Math.cos(ry));

// ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â cast ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â
const tock = makeTock(); scene.add(tock.root);
const baron = makeBaron(); scene.add(baron.root);
const key = makeKey(1); scene.add(key.root);
const keyLight = new THREE.PointLight('#ffc860', 0, 40, 2); scene.add(keyLight);
const beetle = makeBeetle(); scene.add(beetle.root);
const plane = makePlane(); scene.add(plane.root);
const PLANE_HOME = plane.pieces.map(pc => ({ p: pc.position.clone(), r: pc.rotation.clone() }));
const blaster = makeBlaster(); scene.add(blaster.root);
const bolts = [0, 1, 2].map(() => { const b = mesh(roundGeo(.5, PLATE), '#ffd23a'); b.material = b.material.clone(); b.material.emissive = new THREE.Color('#ffb020'); b.material.emissiveIntensity = 1.4; scene.add(b); return b; });

// the grabber that steals the key: two rusty jaws on a grey rod reaching in from the left
const grab = new THREE.Group(); scene.add(grab);
const rod = new THREE.Mesh(new THREE.CylinderGeometry(.55, .55, 60, 20), new THREE.MeshPhysicalMaterial({ color: C.grey, roughness: .3, clearcoat: .8 }));
rod.rotation.z = Math.PI / 2; rod.position.set(-31, 0, 0); rod.castShadow = true; grab.add(rod);
const cross = brick(2, 8, C.rustDark); cross.position.set(-1.5, -.6, 0); grab.add(cross);
const jaws = [-1, 1].map(s => { const j = new THREE.Group(); grab.add(j); for (let i = 0; i < 3; i++) { const b = brick(2, 1, i === 1 ? C.rustDark : C.rust); b.position.y = i * BRICK - 1.8; j.add(b); } return j; });

// loose set dressing bricks, clear of every camera axis
for (const [x, z, col, w, d, ry] of [[16, 22, '#f2cd37', 1, 2, .2], [-10, 38, '#237841', 2, 3, 2.0], [50, 70, '#fe8a18', 1, 4, .8], [96, 8, '#a0a5a9', 2, 2, .3]]) {
  const b = brick(w, d, col); b.position.set(x, 0, z); b.rotation.y = ry; scene.add(b);
}

// ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â the Baron's collapse, simulated once so every render is identical ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â
const BARON_FIGHT = { p: ARENA.clone(), ry: .55 };
const JAW_SHUT = 1.5, KEY_IN_JAWS = V(-.25, PLATE + 3 * BRICK + .02, 0);   // the key stands in the gap between the jaws
const debris = new THREE.Group(); scene.add(debris);
const SIM = (() => {
  baron.root.position.copy(BARON_FIGHT.p); baron.root.rotation.y = BARON_FIGHT.ry; baron.jaw.position.x = JAW_SHUT; baron.root.updateMatrixWorld(true);
  const R = mulberry(31), G = 380, DT = 1 / 240, DUR_S = 3.2, bodies = [];
  const center = BARON_FIGHT.p.clone().add(V(0, 4, 0));
  for (const src of baron.bricks) {
    const clone = src.clone(true); const m = src.matrixWorld.clone();
    const p = new THREE.Vector3(), qq = new THREE.Quaternion(), s = new THREE.Vector3(); m.decompose(p, qq, s);
    const box = new THREE.Box3().setFromObject(src), size = box.getSize(new THREE.Vector3()), mid = box.getCenter(new THREE.Vector3());
    clone.position.copy(p); clone.quaternion.copy(qq); clone.scale.copy(s); debris.add(clone);
    const off = p.clone().sub(mid).applyQuaternion(qq.clone().invert());   // origin relative to the box centre, in the body's frame
    const out = mid.clone().sub(center); out.y = 0; out.normalize().multiplyScalar(6 + R() * 10);
    bodies.push({ clone, off, p: mid.clone(), q: qq.clone(), half: size.clone().multiplyScalar(.5).max(V(.3, .3, .3)),
      v: V(out.x - 4, 6 + R() * 12 + (mid.y - 4) * 1.5, out.z), w: V((R() - .5) * 9, (R() - .5) * 7, (R() - .5) * 9), rest: false });
  }
  const corners = [-1, 1].flatMap(a => [-1, 1].flatMap(b => [-1, 1].map(c => V(a, b, c))));
  const samples = [], _q = new THREE.Quaternion(), _v = new THREE.Vector3();
  for (let f = 0, n = Math.round(DUR_S / DT); f <= n; f++) {
    if (f % 10 === 0) samples.push(bodies.map(b => [b.p.x, b.p.y, b.p.z, b.q.x, b.q.y, b.q.z, b.q.w]));
    for (const b of bodies) {
      if (b.rest) continue;
      b.v.y -= G * DT; b.p.addScaledVector(b.v, DT);
      const wl = b.w.length(); if (wl > 1e-5) { _q.setFromAxisAngle(_v.copy(b.w).divideScalar(wl), wl * DT); b.q.premultiply(_q); }
      let low = Infinity; for (const c of corners) { _v.set(c.x * b.half.x, c.y * b.half.y, c.z * b.half.z).applyQuaternion(b.q).add(b.p); low = Math.min(low, _v.y); }
      if (low < 0) {
        b.p.y -= low; if (b.v.y < 0) b.v.y *= -.3; b.v.x *= .7; b.v.z *= .7; b.w.multiplyScalar(.6);
        if (b.v.length() < 2.5 && f * DT > .5) { b.rest = true; b.v.set(0, 0, 0); b.w.set(0, 0, 0); }
      }
    }
  }
  return { samples, bodies, rate: 24 };
})();
function poseDebris(t) {
  const on = t >= T.tip; debris.visible = on; if (!on) return;
  const f = Math.min(Math.floor((t - T.tip) * SIM.rate), SIM.samples.length - 1), row = SIM.samples[f];
  SIM.bodies.forEach((b, k) => {
    const r = row[k], qq = new THREE.Quaternion(r[3], r[4], r[5], r[6]);
    b.clone.quaternion.copy(qq); b.clone.position.set(r[0], r[1], r[2]).add(b.off.clone().applyQuaternion(qq));
  });
}
// the hat, knocked off before the fall, stays where it landed
const hatRest = baron.hat.clone(true); scene.add(hatRest);
const HAT_LOCAL = u => V(-2 + u * 9, baron.top + 3 * BRICK + Math.sin(u * Math.PI) * 6 - u * u * 7.5, u * 3);

// ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â Tock's performance ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â
const TOCK_BUILD_RY = 0;
const BARON_TOP = () => BOOKS.clone().add(V(0, set.booksTop, 0));
const TOCK_LOOKUP = BOOKS.clone().add(V(18, 0, 24));
const RUN = { x0: 36, speed: 13 };
const STOMP_X = 64;
const SLIDE_A = V(PAINT.x - 24, 0, PAINT.z + 6), SLIDE_B = V(PAINT.x + 11, 0, PAINT.z - 4);
const LONE = ARENA.clone().add(V(14, 0, 13));
const RETURN_FROM = KEY_SPOT.clone().add(V(16, 0, 6)), KEY_STAND = KEY_SPOT.clone().add(V(3.2, 0, 1.0));
const PIECES = [
  ['leg0', T.snaps[0], V(-6, 0, 4), V(0, 0, 1.4)], ['leg1', T.snaps[0], V(6.5, 0, 3), V(0, 0, -1.4)],
  ['body', T.snaps[1], V(5, -HIP, -4), V(0, .6, 0)], ['arm0', T.snaps[2], V(-5, -1.9, -4), V(0, 0, 1.57)],
  ['arm1', T.snaps[3], V(7, -1.9, 1), V(0, 0, -1.57)], ['head', T.snaps[4], V(-7, -6, -1), V(0, .8, 0)],
  ['cap', T.snaps[5], V(3, -8.4, 7), V(0, 0, .4)], ['wind', T.keySnap, V(-3.5, -3.8, -6), V(1.57, 0, 0)],
];
// each piece's resting place in the finished toy; the build flies it in from an offset on the desk
const PART_REST = Object.fromEntries(PIECES.map(([name]) => [name, { p: tock.parts[name].position.clone(), r: tock.parts[name].rotation.clone() }]));
function buildParts(t) {
  for (const [name, ts, off, rot] of PIECES) {
    const p = tock.parts[name], rest = PART_REST[name], u = seg(t, ts - .5, ts), lift = Math.sin(u * Math.PI) * 7;
    const hopU = seg(t, 4.5, 4.75), hop = t < ts - .5 ? Math.sin(hopU * Math.PI) * .9 : 0;   // the pile twitches before it flies
    const snap = t >= ts ? -.35 * (1 - ss(seg(t, ts, ts + .17))) : 0;
    p.position.set(rest.p.x + lerp(off.x, 0, eio(u)), rest.p.y + lerp(off.y, 0, eio(u)) + lift + hop + snap, rest.p.z + lerp(off.z, 0, eio(u)));
    p.rotation.set(rest.r.x + lerp(rot.x, 0, eio(u)), rest.r.y + lerp(rot.y, 0, eio(u)), rest.r.z + lerp(rot.z, 0, eio(u)));
  }
}
function resetParts() { for (const [name] of PIECES) { tock.parts[name].position.copy(PART_REST[name].p); tock.parts[name].rotation.copy(PART_REST[name].r); } }
function windSpin(t) {
  if (t < T.wind) return 0;
  if (t < T.wind + .5) return eio(seg(t, T.wind, T.wind + .5)) * Math.PI * 4;
  if (t < T.lampOff) return Math.PI * 4 + (t - T.wind - .5) * 3.2;
  const base = Math.PI * 4 + (T.lampOff - T.wind - .5) * 3.2, u = seg(t, T.lampOff, T.windStop);
  return base + 3.2 * (T.windStop - T.lampOff) * (u - u * u / 2);   // slows to a stop
}

function tockAt(t) {
  const P = { x: 0, y: 0, z: 0, ry: 0, blink: Math.floor(t * 12) % 41 === 0, spin: windSpin(t) };
  let vis = true, hold = null;
  const put = (p, ry) => { P.x = p.x; P.y = p.y; P.z = p.z; P.ry = ry; };
  if (t < 4) vis = false;
  else if (t < 10) {   // builds himself, winds up, hops and turns to us
    put(BUILD, TOCK_BUILD_RY);
    if (t >= T.wind) { P.armL = P.armR = [0, .25]; P.nod = -.15; }
    if (t >= T.joy) { const u = seg(t, T.joy, T.joy + .45); P.y = Math.sin(u * Math.PI) * 2.2; P.armL = P.armR = [-.2, lerp(.25, 2.5, ss(seg(t, T.joy, T.joy + .2)))]; P.ry = lerp(0, .35 + Math.PI, ss(seg(t, T.joy, T.joy + .45))); }
  } else if (t < 14) {   // looks up the tower of books at the Baron
    put(TOCK_LOOKUP, Math.atan2(BOOKS.x - TOCK_LOOKUP.x, BOOKS.z - TOCK_LOOKUP.z)); P.nod = -.55;
    if (t >= T.raise) { const a = ss(seg(t, T.raise, T.raise + .25)); P.armL = P.armR = [-.4 * a, .2 + 2.4 * a]; P.y = Math.sin(seg(t, T.raise, T.raise + .35) * Math.PI) * .8; }
    else P.armL = P.armR = [-.6, .1];
  } else if (t < 18) {   // runs the ruler, jumps, stomps the beetle, runs on
    const y0 = RULER.top; let x;
    if (t < T.jump) { x = RUN.x0 + (t - T.run) * RUN.speed; Object.assign(P, walkPose((x - RUN.x0) / 3.2 * Math.PI * 2, .8)); P.lean = .25; P.armL = [P.armL[0] * 1.4, .2]; P.armR = [P.armR[0] * 1.4, .2]; P.y = y0; }
    else if (t < T.stomp) { const u = seg(t, T.jump, T.stomp), xa = RUN.x0 + (T.jump - T.run) * RUN.speed; x = lerp(xa, STOMP_X, u); P.y = y0 + 1.5 + Math.sin(u * Math.PI * .8) * 6; P.legs = [-.6, .4]; P.armL = P.armR = [-.3, 2.2]; }
    else if (t < 16.6) { const u = seg(t, T.stomp, 16.6); x = lerp(STOMP_X, STOMP_X + 8, u); P.y = y0 + 1.5 * (1 - u) + Math.sin(u * Math.PI) * 4.5; P.armL = P.armR = [-.2, 2.6]; P.legs = [.3, -.3]; }
    else { x = STOMP_X + 8 + (t - 16.6) * RUN.speed; Object.assign(P, walkPose((x - RUN.x0) / 3.2 * Math.PI * 2, .8)); P.lean = .25; P.y = y0; }
    put(V(x, P.y, RULER.z), Math.PI / 2); P.y = P.y;
  } else if (t < 22) {   // slides across the paint, spinning, arms out
    if (t < 18.6) { const u = seg(t, T.slide, 18.6), p = SLIDE_A.clone().lerp(PAINT_EDGE, u); put(p, Math.atan2(SLIDE_B.x - SLIDE_A.x, SLIDE_B.z - SLIDE_A.z)); Object.assign(P, walkPose(u * 9, .8)); P.lean = .2; }
    else {
      const u = seg(t, 18.6, T.slideStop), p = PAINT_EDGE.clone().lerp(SLIDE_B, eo(u)); p.y = groundY(p.x, p.z);
      const spin = ss(seg(t, 19.0, 20.6)) * Math.PI * 4;
      put(p, Math.atan2(SLIDE_B.x - SLIDE_A.x, SLIDE_B.z - SLIDE_A.z) + spin);
      P.armL = P.armR = [0, 1.45]; P.legs = [.35, -.15]; P.lean = -.12;
      if (t > T.slideStop) { const w = t - T.slideStop; P.roll = Math.sin(w * 18) * .18 * Math.exp(-w * 3); P.armL = P.armR = [0, 1.45 - ss(seg(t, 21.4, 21.8)) * 1.3]; }
    }
  } else if (t < 26) {   // aims and fires at the paper plane, then blows on the barrel
    const pl = planeAt(t).p, ry = Math.atan2(pl.x - SHOOT.x, pl.z - SHOOT.z);
    put(SHOOT, t < T.blow ? ry : lerp(ry, ry - .6, ss(seg(t, T.blow, T.blow + .3))));
    const recoil = T.bolts.reduce((a, b) => a + (t >= b && t < b + .17 ? .25 : 0), 0);
    const up = Math.atan2(pl.y - 7, Math.hypot(pl.x - SHOOT.x, pl.z - SHOOT.z));
    P.armR = [-1.5 - up + recoil, .05]; P.armL = [-.2, .15]; P.lean = -.05;
    if (t >= T.blow) { P.armR = [-2.2, .25]; P.nod = .25; P.look = -.25; }
    hold = 'blaster';
  } else if (t < 28) {   // small at the foot of the arena, facing the Baron
    put(LONE, Math.atan2(ARENA.x - LONE.x, ARENA.z - LONE.z)); P.armL = P.armR = [-.3, .2]; P.nod = -.2;
  } else if (t < 34) {   // hops onto the Baron's head, knocks off his hat, jumps clear, catches the key
    const face = Math.atan2(ARENA.x - LONE.x, ARENA.z - LONE.z), head = baronHead();
    if (t < T.hop) { put(LONE, face); P.armL = P.armR = [-.3, .2 + (t > T.slam ? .8 : 0)]; P.lean = t > T.slam + .3 ? .2 : 0; }
    else if (t < T.landHead) { const u = seg(t, T.hop, T.landHead), p = LONE.clone().lerp(head, u); p.y = lerp(0, head.y, u) + Math.sin(u * Math.PI) * 7; put(p, face); P.armL = P.armR = [-.2, 2.4]; P.legs = [-.5, .4]; }
    else if (t < T.tip) { put(head, face); P.armL = P.armR = [0, 2.6]; P.y += Math.sin(seg(t, T.landHead, T.landHead + .25) * Math.PI) * .6; }
    else if (t < 30.9) { const u = seg(t, T.tip, 30.9), land = ARENA.clone().add(V(15, 0, -1)), p = head.clone().lerp(land, u); p.y = lerp(head.y, 0, u) + Math.sin(u * Math.PI) * 5; put(p, face); P.armL = P.armR = [-.4, 2.2]; P.legs = [.4, -.4]; }
    else { const land = ARENA.clone().add(V(15, 0, -1)); put(land, face); const c = t > T.keyUp ? ss(seg(t, T.keyUp, T.keyUp + .3)) : 0; P.armL = P.armR = [-.2 - c * 2.6, .2 + c * .1]; P.nod = -.3 - c * .2; if (t >= 33.2) hold = 'key'; }
  } else if (t < 37) {   // brings the key home, sets it down, arms in a V
    if (t < T.setDown) { const u = seg(t, 34, T.setDown - .3), p = RETURN_FROM.clone().lerp(KEY_STAND, u); put(p, Math.atan2(KEY_SPOT.x - p.x, KEY_SPOT.z - p.z) * (u < 1 ? 1 : 1)); Object.assign(P, walkPose(u * 10)); P.armL = P.armR = [-1.1, .05]; hold = 'key'; }
    else { put(KEY_STAND, lerp(-1.3, .49, ss(seg(t, T.setDown + .1, T.vee)))); const v = ss(seg(t, T.vee, T.vee + .25)); P.armL = P.armR = [-.1, .2 + v * 2.3]; P.nod = -.2 * v; P.y = Math.sin(seg(t, T.vee, T.vee + .4) * Math.PI) * 1.2; }
  } else {   // in the dark beside the glowing key; his key winds down
    put(KEY_STAND, .1); const s = ss(seg(t, 42.2, T.windStop + .4));
    P.armL = P.armR = [0, .2]; P.nod = .1 + s * .35; P.lean = s * .14; P.eyeX = -.6;
  }
  return { vis, P, hold };
}
const PAINT_EDGE = V(PAINT.x - 13, 0, PAINT.z + 3.6);

function baronHead() { const p = BARON_FIGHT.p.clone().add(V(-2, PLATE + 6 * BRICK + .1, 0).applyAxisAngle(V(0, 1, 0), BARON_FIGHT.ry)); return p; }

// ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â the Baron ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â
function baronAt(t) {
  const B = { vis: true, p: BARON_TOP(), ry: .35, jaw: JAW_SHUT, hop: 0, hat: null, stache: 0 };
  if (t < 10 || (t >= 14 && t < 26)) B.vis = false;
  else if (t < 14) {   // on the books, gloating, hops once
    const u = seg(t, T.raise, T.raise + .5); B.hop = Math.sin(u * Math.PI) * 2.5; B.stache = Math.sin(q(t) * 10) * .12;
  } else if (t < T.tip) {
    B.p = BARON_FIGHT.p.clone(); B.ry = BARON_FIGHT.ry;
    if (t >= 27.5 && t < T.slam + .1) { const u = seg(t, 27.5, T.slam); B.hop = Math.sin(u * Math.PI) * 4; }
    if (t >= T.landHead) B.hat = seg(t, T.landHead, T.landHead + .6);
    if (t >= T.landHead) B.wobble = Math.sin((t - T.landHead) * 22) * .05 * (1 + seg(t, T.landHead, T.tip) * 2);
  } else B.vis = false;   // the debris takes over
  return B;
}

// ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â props over time ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â
function keyAt(t, A) {
  // returns world position, yaw, roll for the Golden Key (its pivot is at its bottom)
  if (t < T.clamp) return { p: KEY_SPOT.clone(), ry: .3, vis: true };
  if (t < 4) { const g = grabAt(t); return { p: V(g.x + 0, 0 + g.lift, 0), ry: .3, vis: true }; }
  if (t < 10) return { vis: false };
  const baronVis = t < 14 || (t >= 26 && t < T.tip);
  if (baronVis) {   // standing in the gap between his jaws
    const B = baronAt(t); const p = B.p.clone().add(KEY_IN_JAWS.clone().applyAxisAngle(V(0, 1, 0), B.ry)).add(V(0, B.hop, 0)); return { p, ry: B.ry, vis: true };
  }
  if (t < 26) return { vis: false };
  if (t < 33.2) {   // thrown up out of the wreck, caught
    const start = BARON_FIGHT.p.clone().add(V(0, 0, 0)), end = handsMid();
    if (t < T.keyUp) return { p: start.clone().add(V(0, 1.5, 0)), ry: 0, vis: true, tumble: 1.2 };
    const u = seg(t, T.keyUp, 33.2), p = start.clone().lerp(end, u); p.y = lerp(1.5, end.y - 2, u) + Math.sin(u * Math.PI) * 14;
    return { p, ry: u * 9, vis: true };
  }
  if (t < T.setDown) { const h = handsMid(); return { p: h.add(V(0, -2.6, 0)).add(FWD(A.P.ry).multiplyScalar(.8)), ry: A.P.ry, vis: true }; }
  return { p: KEY_SPOT.clone(), ry: .3, vis: true };
}
function grabAt(t) {
  const inU = eo(seg(t, T.jawIn, T.clamp - .1)), out = ei2(seg(t, T.yank, 3.4));
  return { x: lerp(-34, 0, inU) - out * 60, close: ss(seg(t, T.clamp - .1, T.clamp + .02)), lift: out * 6 };
}
const ei2 = u => u * u;
function planeAt(t) {
  const u = seg(t, 21.8, 24.6), p = V(SHOOT.x + 21, 10 + Math.sin(u * 6) * 1.2, SHOOT.z - 34 + u * 70);
  return { p, ry: 0, hit: t >= T.planeHit };
}
const _h1 = V(0, 0, 0), _h2 = V(0, 0, 0);
function handsMid() { tock.root.updateMatrixWorld(true); tock.arms[0].hand.getWorldPosition(_h1); tock.arms[1].hand.getWorldPosition(_h2); return _h1.clone().add(_h2).multiplyScalar(.5); }

// ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â camera ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â
function camAt(t0) {
  const [s0, s1, name] = shotAt(t0), u = seg(t0, s0, s1), tp = tock.root.position.clone();
  let pos, look, fov = 32, focus, aper = 800, span = 32;
  switch (name) {
    case 'clock': {
      const d = eio(seg(t0, .2, 1.8));
      pos = V(12, 24, 58).lerp(V(9, 4.5, 21), d); look = V(0, 31, CLOCK.z).lerp(V(-1, 4, 0), d); fov = 30;
      focus = d < .5 ? V(0, 31, CLOCK.z) : V(0, 3, 0); aper = lerp(500, 1100, d); span = 40; break;
    }
    case 'build': {
      const a = .35 + eio(u) * Math.PI;   // a half-turn around the building toy
      pos = BUILD.clone().add(V(Math.sin(a) * 22, 7.5 - u * 2, Math.cos(a) * 22)); look = BUILD.clone().add(V(0, 4.2, 0)); fov = 34;
      focus = BUILD.clone().add(V(0, 4, 0)); aper = 650; break;
    }
    case 'baron': {
      const c = eio(seg(t0, 10.2, 12.0)), top = BARON_TOP().add(V(0, 6, 0));
      pos = TOCK_LOOKUP.clone().add(V(9, 2.4, 13)).lerp(TOCK_LOOKUP.clone().add(V(4, 9, 9)), c);
      look = TOCK_LOOKUP.clone().add(V(0, 5, 0)).lerp(top, c); fov = 38; focus = c < .5 ? TOCK_LOOKUP.clone().add(V(0, 6, 0)) : top; aper = 650; span = 45; break;
    }
    case 'ruler': {
      const x = clamp(tp.x, 40, 130);
      const rise = Math.max(0, tp.y - RULER.top); pos = V(x - 9, 6 + rise * .7, RULER.z + 22); look = V(x + 7, 3.5 + rise * .8, RULER.z); fov = 36; focus = tp.clone().add(V(0, 5, 0)); aper = 700; break;
    }
    case 'paint': pos = V(PAINT.x - 5, 50, PAINT.z + 4); look = V(PAINT.x - 5, 0, PAINT.z + 1); fov = 40; focus = V(PAINT.x, 3, PAINT.z); aper = 250; span = 40; break;
    case 'shoot': pos = V(SHOOT.x - 10, 7, SHOOT.z + 30); look = V(SHOOT.x + 15, 8, SHOOT.z + 2); fov = 42; focus = SHOOT.clone().add(V(4, 6, 0)); aper = 600; span = 45; break;
    case 'lonely': pos = ARENA.clone().add(V(12, 2.2, 62)).lerp(ARENA.clone().add(V(13, 2.4, 59)), u); look = ARENA.clone().add(V(9, 8, 0)); fov = 36; focus = LONE.clone().add(V(0, 5, 0)); aper = 450; span = 45; break;
    case 'fight': {
      pos = ARENA.clone().add(V(26, 6, 32)); look = ARENA.clone().add(V(5, 7, 4)); fov = 40; focus = ARENA.clone().add(V(4, 6, 4)); span = 40;
      const fr = Math.floor(t0 * 24), sh = Math.max(seg(t0, T.slam, T.slam + .05) * (1 - seg(t0, T.slam + .1, T.slam + .5)), seg(t0, T.crash, T.crash + .05) * (1 - seg(t0, T.crash + .1, T.crash + .6)));
      pos.add(V(hash(fr) - .5, hash(fr + 99) - .5, 0).multiplyScalar(sh * 1.2)); break;
    }
    case 'return': pos = KEY_SPOT.clone().add(V(15, 5, 25)).lerp(KEY_SPOT.clone().add(V(13, 4.6, 22)), eio(u)); look = KEY_SPOT.clone().add(V(1.5, 5.5, 0)); fov = 34; focus = KEY_SPOT.clone().add(V(2, 5, 0)); aper = 650; break;
    default: pos = KEY_SPOT.clone().add(V(13, 10, 36)); look = KEY_SPOT.clone().add(V(-1, 12, -12)); fov = 36; focus = KEY_SPOT.clone().add(V(2, 4, 0)); aper = 420; span = 50;
  }
  camera.position.copy(pos); camera.fov = fov; camera.updateProjectionMatrix(); camera.lookAt(look);
  const k = set.key, fc = focus;
  k.target.position.copy(fc); k.position.copy(fc).add(V(-60, 110, 50)); k.target.updateMatrixWorld();
  Object.assign(k.shadow.camera, { left: -span, right: span, top: span, bottom: -span }); k.shadow.camera.updateProjectionMatrix();
  set.softKey.position.copy(fc).add(V(-45, 50, 45)); set.softKey.lookAt(fc);
  set.softRim.position.copy(fc).add(V(40, 38, -60)); set.softRim.lookAt(fc);
  post.dof.focus = camera.position.distanceTo(fc); post.dof.aper = aper; post.dof.maxCoc = 16;
}

// ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â 2D layer: captions on a toy pill, the title on a red brick plate ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â
const ov = document.getElementById('ov'), g = ov.getContext('2d');
function brickIcon(x, y, s, col) {
  g.save(); g.translate(x, y); g.scale(s, s); g.fillStyle = col; g.beginPath(); g.roundRect(0, 8, 58, 26, 5); g.fill();
  g.beginPath(); g.roundRect(7, 0, 18, 10, 3); g.roundRect(33, 0, 18, 10, 3); g.fill(); g.fillStyle = 'rgba(0,0,0,.18)'; g.fillRect(0, 28, 58, 6); g.restore();
}
function pillBox(text) { g.font = '600 46px Fredoka'; const tw = g.measureText(text).width, pw = tw + 150, ph = 84; return { x: (W - pw) / 2, y: H - 160, w: pw, h: ph }; }
function pill(text) {
  const b = pillBox(text);
  g.fillStyle = 'rgba(18,20,26,.64)'; g.beginPath(); g.roundRect(b.x, b.y, b.w, b.h, 42); g.fill();
  brickIcon(b.x + 30, b.y + 21, 1, '#e0a12a');
  g.fillStyle = '#fff'; g.textBaseline = 'middle'; g.textAlign = 'left'; g.font = '600 46px Fredoka'; g.fillText(text, b.x + 110, b.y + b.h / 2 + 2);
}
const TITLE_Y = 250;
function titleBoxes() {
  g.font = '700 100px Fredoka'; const tw = g.measureText("TOCK'S WIND-UP WORKSHOP").width;
  return { title: { x: W / 2 - tw / 2 - 50, y: TITLE_Y - 80, w: tw + 100, h: 160 } };
}
function plateBg(b, a) {
  g.save(); g.globalAlpha = a; g.fillStyle = '#b8160a'; g.shadowColor = 'rgba(0,0,0,.5)'; g.shadowBlur = 30; g.shadowOffsetY = 10;
  g.beginPath(); g.roundRect(b.x, b.y, b.w, b.h, 18); g.fill(); g.shadowBlur = 0; g.shadowOffsetY = 0;
  g.fillStyle = 'rgba(255,255,255,.08)'; g.beginPath(); g.roundRect(b.x + 6, b.y + 6, b.w - 12, 24, 10); g.fill();
  g.fillStyle = '#d42a14'; for (let x = b.x + 40; x < b.x + b.w - 30; x += 74) { g.beginPath(); g.roundRect(x, b.y - 16, 44, 20, 6); g.fill(); }
  g.restore();
}
function pop(t, t0) { const u = seg(q(t), t0, t0 + .25); return u <= 0 ? 0 : u < 1 ? .55 + .55 * Math.sin(u * Math.PI * .75) : 1; }
function hud(t) {
  g.clearRect(0, 0, W, H);
  const c = CAPTIONS.find(c => t >= c.t0 && t < c.t1); if (c) pill(c.text);
  if (t >= T.title) {
    const s = pop(t, T.title), b = titleBoxes().title;
    g.save(); g.translate(W / 2, TITLE_Y); g.scale(s, s); g.translate(-W / 2, -TITLE_Y);
    plateBg(b, 1); g.font = '700 100px Fredoka'; g.textAlign = 'center'; g.textBaseline = 'middle';
    g.fillStyle = '#f2cd37'; g.shadowColor = 'rgba(0,0,0,.35)'; g.shadowOffsetY = 4; g.fillText("TOCK'S WIND-UP WORKSHOP", W / 2, TITLE_Y + 6); g.restore();
    const s2 = pop(t, T.sub); if (s2 > 0) { g.save(); g.translate(W / 2, TITLE_Y + 140); g.scale(s2, s2); g.font = '600 50px Fredoka'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillStyle = '#fff'; g.shadowColor = 'rgba(0,0,0,.6)'; g.shadowBlur = 16; g.fillText('Five levels. One very rude vise.', 0, 0); g.restore(); }
    const s3 = pop(t, T.itch); if (s3 > 0) { g.save(); g.translate(W / 2, TITLE_Y + 215); g.scale(s3, s3); g.font = '700 44px Fredoka'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillStyle = '#f2cd37'; g.shadowColor = 'rgba(0,0,0,.6)'; g.shadowBlur = 16; g.fillText('Coming to itch.io', 0, 0); g.restore(); }
  }
}
function texts(t) {
  const out = []; const c = CAPTIONS.find(c => t >= c.t0 && t < c.t1);
  if (c) { const b = pillBox(c.text); out.push({ id: c.text, text: c.text, x0: b.x, y0: b.y, x1: b.x + b.w, y1: b.y + b.h }); }
  if (t >= T.title) { const b = titleBoxes().title; out.push({ id: 'title', text: "TOCK'S WIND-UP WORKSHOP", x0: b.x, y0: b.y, x1: b.x + b.w, y1: b.y + b.h }); }
  if (t >= T.sub) out.push({ id: 'sub', text: 'Five levels. One very rude vise.', x0: 560, y0: TITLE_Y + 110, x1: 1360, y1: TITLE_Y + 170 });
  if (t >= T.itch) out.push({ id: 'itch', text: 'Coming to itch.io', x0: 760, y0: TITLE_Y + 190, x1: 1160, y1: TITLE_Y + 240 });
  return out;
}

// ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â a frame ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â
function render(t0) {
  const t = q(t0);
  // Tock
  const A = tockAt(t); tock.root.visible = A.vis; resetParts();
  tock.pose(A.P); if (t >= 4 && t < 10) buildParts(t);
  // the Baron
  const B = baronAt(t); baron.root.visible = B.vis;
  if (B.vis) {
    baron.root.position.copy(B.p).add(V(0, B.hop, 0)); baron.root.rotation.set(0, B.ry, B.wobble ?? 0); baron.jaw.position.x = B.jaw;
    baron.stache.rotation.z = B.stache; baron.brows.forEach((b, i) => b.rotation.z = (i ? 1 : -1) * (.45 + (t >= T.landHead ? .3 : 0)));
    baron.eyes.forEach(e => { e.p.position.x = t < 14 ? .12 : .05; });
    const u = B.hat ?? 0; baron.hat.position.copy(HAT_LOCAL(u)); baron.hat.rotation.set(u * 4, 0, .18 + u * 5);
  }
  poseDebris(t);
  hatRest.visible = t >= T.tip;
  if (hatRest.visible) { hatRest.position.copy(BARON_FIGHT.p).add(HAT_LOCAL(1).applyAxisAngle(V(0, 1, 0), BARON_FIGHT.ry)); hatRest.rotation.set(Math.PI / 2, BARON_FIGHT.ry, .3); hatRest.position.y = 1.0; }
  // the grabber
  const gr = grabAt(t); grab.visible = t >= T.jawIn - .1 && t < 4;
  grab.position.set(gr.x, 3.2 + gr.lift, 0);
  jaws[0].position.set(0, 0, lerp(-2.6, -1.05, gr.close)); jaws[1].position.set(0, 0, lerp(2.6, 1.05, gr.close));
  // the key
  const K = keyAt(t, A); key.root.visible = K.vis !== false;
  if (key.root.visible) { key.root.position.copy(K.p); key.root.rotation.set(K.tumble ? Math.sin(t * 9) * .4 : 0, K.ry, 0); }
  const glow = ss(seg(t, T.lampOff + .3, T.lampOff + 1.4));
  key.gold.emissiveIntensity = (t >= T.glint && t < T.glint + .25 ? 1.2 : 0) + glow * 1.6;
  keyLight.intensity = glow * 260; keyLight.position.copy(KEY_SPOT).add(V(0, 6, 1.5));
  // the beetle: walks the ruler toward Tock, then pops apart
  const bx = lerp(82, STOMP_X, seg(t, T.run, T.stomp));
  beetle.root.visible = t >= 14 && t < 18;
  beetle.root.position.set(bx, RULER.top, RULER.z); beetle.root.rotation.set(0, -Math.PI / 2, 0);
  const pu = t >= T.stomp ? t - T.stomp : 0, fall = (v, h) => Math.max(0, h + v * pu - 120 * pu * pu);
  beetle.shell.position.set(0, .6 + fall(14, 0), pu * 6); beetle.shell.rotation.x = pu * 7;
  beetle.gear.position.set(pu * 5, .6 + BRICK + .2 + fall(20, 0), -pu * 3); beetle.gear.rotation.z = pu * 12;
  beetle.legs.position.set(0, 0, 0); beetle.legs.rotation.y = pu * 3;
  beetle.eyes.forEach(e => e.g.position.y = 1.1 + fall(14, 0));
  // paper plane and bolts
  const PL = planeAt(t); plane.root.visible = t >= 21.8 && t < 26;
  plane.root.position.copy(PL.p); plane.root.rotation.set(-.08, 0, Math.sin(t * 4) * .15);
  if (t >= T.planeHit) plane.root.position.copy(planeAt(T.planeHit).p);
  plane.pieces.forEach((pc, i) => {
    const home = PLANE_HOME[i], h = Math.max(0, t - T.planeHit), dir = V(hash(i) - .5, 0, hash(i + 7) - .5).multiplyScalar(14);
    pc.position.set(home.p.x + dir.x * h, Math.max(-plane.root.position.y + .2, home.p.y + 4 * h - 60 * h * h), home.p.z + dir.z * h);
    pc.rotation.set(home.r.x + h * (3 + i), home.r.y + h * 2, home.r.z + h * (2 - i));
  });
  // blaster in Tock's right hand
  blaster.root.visible = A.hold === 'blaster';
  if (blaster.root.visible) { tock.root.updateMatrixWorld(true); const h = tock.arms[1].hand.getWorldPosition(V(0, 0, 0)); blaster.root.position.copy(h); blaster.root.quaternion.copy(tock.arms[1].g.getWorldQuaternion(new THREE.Quaternion())); blaster.root.rotateX(Math.PI / 2); }
  bolts.forEach((b, i) => {
    const tb = T.bolts[i], u = seg(t0, tb, tb + .25), on = t0 >= tb && t0 < tb + .25;
    b.visible = on && blaster.root.visible;
    if (b.visible) { const from = blaster.root.position.clone(), to = planeAt(tb + .25).p.clone().add(V(0, i < 2 ? 3 + i * 2 : 0, i < 2 ? 6 : 0)); b.position.copy(from.lerp(to, u)); b.rotation.set(Math.PI / 2, 0, 0); }
  });
  // clock hands: the second hand ticks every second
  set.secHand.rotation.z = -Math.floor(t0) / 60 * Math.PI * 2; set.minHand.rotation.z = -5.5 - t0 / 3600 * Math.PI * 2;
  // night
  set.setNight(ss(seg(t0, T.lampOff, T.lampOff + .2)) * .85 + ss(seg(t0, T.lampOff + .2, T.lampOff + 1.5)) * .15);
  vig.warm.value = lerp(-.3, -.75, ss(seg(t0, T.lampOff, T.lampOff + 1.5)));
  camAt(t0);
  post.composer.render();
  hud(t0);
}

// ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â sound events for mix.py ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â
function events() {
  const ev = [], add = (type, t, o = {}) => ev.push({ type, t: +t.toFixed(3), ...o });
  add('click', qc(T.clamp), { v: 1.1, pitch: .7 }); add('whoosh', T.yank, { v: .8 }); add('scrape', T.jawIn, { d: .5, v: .5 });
  add('rattle', 4.5, { v: .5 });
  T.snaps.forEach((s, i) => { add('whoosh', s - .45, { v: .35 }); add('click', qc(s), { v: 1, pitch: 1 + i * .06 }); });
  add('whoosh', T.keySnap - .45, { v: .35 }); add('click', qc(T.keySnap), { v: 1.2, pitch: 1.35 });
  add('ratchet', T.wind, { d: .5, v: .8 }); add('step', qc(T.joy), { v: .6 }); add('step', qc(T.joy + .45), { v: .8 });
  add('thump', qc(T.raise + .5), { v: .55, f: 90 }); add('creak', T.raise + .1, { v: .3 });
  add('whoosh', T.jump, { v: .5 }); add('clack', qc(T.stomp), { v: 1.2 }); add('pop', qc(T.stomp), { v: .8 });
  for (let k = 0; k < 5; k++) add('clack', T.stomp + .45 + k * .09, { v: .6 - k * .08 });
  add('step', qc(16.6), { v: .7 });
  add('slosh', 18.6, { d: 2.5, v: .5 }); add('whoosh', T.spin - .5, { v: .45 }); add('whoosh', T.spin + .3, { v: .4 }); add('click', qc(T.slideStop), { v: .5, pitch: .8 });
  T.bolts.forEach(b => add('pew', b, { v: .8 })); add('crash', T.planeHit, { v: .7 });
  for (let k = 0; k < 6; k++) add('clack', T.planeHit + .5 + k * .1, { v: .55 });
  add('blow', T.blow, { v: .5 });
  add('thump', qc(T.slam), { v: 1.2, f: 55 }); add('crash', qc(T.slam), { v: .45 });
  add('whoosh', T.hop, { v: .5 }); add('click', qc(T.landHead), { v: .9, pitch: .9 }); add('whoosh', T.landHead + .1, { v: .35 });
  add('creak', T.landHead + .15, { v: .5 }); add('creak', T.tip - .2, { v: .7 });
  add('crash', qc(T.crash), { v: 1.1 }); for (let k = 0; k < 24; k++) add('clack', T.tip + .35 + Math.pow(k / 24, 1.5) * 2.2 + hash(k) * .07, { v: 1 - k / 28 });
  add('ding', T.keyUp, { v: .7 }); add('click', qc(33.2), { v: .7, pitch: 1.2 });
  add('click', qc(T.setDown), { v: .9, pitch: 1.1 }); add('ding', T.glint, { v: .9 });
  add('switch', T.lampOff, { v: 1 });
  add('pop', T.title, { v: .8 }); add('click', qc(T.title + .2), { v: 1, pitch: 1.2 }); add('click', qc(T.sub + .2), { v: .7, pitch: 1.3 }); add('click', qc(T.itch + .2), { v: .7, pitch: 1.4 });
  add('winddown', T.lampOff + .2, { d: T.windStop - T.lampOff - .2, v: .45 });
  let last = null;   // footsteps from the performance
  for (let f = 0; f < DUR * 12; f++) {
    const t = f / 12, A = tockAt(t); if (!A.vis) { last = null; continue; }
    const l = A.P.legs?.[0] ?? 0, s = Math.sign(l);
    if (last !== null && s !== 0 && s !== last && Math.abs(l) > .2 && !(t >= 18.6 && t < 22)) add('step', t, { v: .45 });
    if (s !== 0) last = s;
  }
  return ev.sort((a, b) => a.t - b.t);
}

window.render = render; window.DUR = DUR; window.EV = events(); window.TEXTS = texts; window.DBG = { camera, tock, baron, post, set };
await document.fonts.load('600 46px Fredoka'); await document.fonts.load('700 100px Fredoka');
render(parseFloat(new URLSearchParams(location.search).get('t') ?? '6'));
window.READY = true;
