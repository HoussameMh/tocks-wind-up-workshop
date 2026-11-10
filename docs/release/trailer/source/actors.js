// The cast, built only from bricks: Tock (the game's clockwork hero), Baron Rust (a rusty bench vise with a
// tiny top hat and a moustache), a gear-beetle, the Golden Key, a paper plane and Tock's blaster.
import * as THREE from 'three';
import { BRICK, PLATE, brick, plate, mesh, roundGeo, plastic } from './bricks.js';

export const C = {
  teal: '#1fa39b', brass: '#e0a12a', cap: '#c91a09', skin: '#e4cd9e', grey: '#a0a5a9', dgrey: '#5d6063',
  black: '#1b2a34', white: '#f4f4f1', gold: '#f2c230', rust: '#9a4a26', rustDark: '#6b321b', orange: '#d9531e', blue: '#0055bf',
};
export const HIP = PLATE + 2 * BRICK;               // 2.8
export const SHOULDER = HIP + PLATE + 2 * BRICK;    // 5.6
export const ARM_L = 3 * BRICK;
export const TOCK_H = SHOULDER + PLATE + 2 * BRICK + 2 * PLATE;

const shadowAll = g => g.traverse(o => { if (o.isMesh) o.castShadow = o.receiveShadow = true; });
function eyes(parent, y, z, spread, r = .32) {
  const white = new THREE.MeshPhysicalMaterial({ color: '#ffffff', roughness: .15, clearcoat: 1 });
  const black = new THREE.MeshPhysicalMaterial({ color: '#111111', roughness: .1, clearcoat: 1 });
  return [-1, 1].map(s => {
    const g = new THREE.Group(); g.position.set(s * spread, y, z); parent.add(g);
    const w = new THREE.Mesh(new THREE.SphereGeometry(r, 20, 14), white); g.add(w);
    const p = new THREE.Mesh(new THREE.SphereGeometry(r * .55, 16, 12), black); p.position.z = r * .62; g.add(p);
    return { g, w, p };
  });
}

// The Golden Key: a shaft of gold round bricks and a bow of two gold rings. Pivot at its bottom.
export function makeKey(scale = 1) {
  const root = new THREE.Group(), k = new THREE.Group(); k.scale.setScalar(scale); root.add(k);
  const gold = new THREE.MeshPhysicalMaterial({ color: C.gold, metalness: .35, roughness: .22, clearcoat: 1, clearcoatRoughness: .05, emissive: '#ffb020', emissiveIntensity: 0 });
  for (let i = 0; i < 3; i++) { const b = new THREE.Mesh(roundGeo(.5), gold); b.position.y = i * BRICK; k.add(b); }
  const ringGeo = new THREE.TorusGeometry(1.05, .38, 16, 40);
  for (const s of [-1, 1]) { const r = new THREE.Mesh(ringGeo, gold); r.position.set(s * 1.2, 3 * BRICK + 1.2, 0); k.add(r); }
  const tooth = new THREE.Mesh(new THREE.BoxGeometry(1, .5, .8), gold); tooth.position.set(.7, .35, 0); k.add(tooth);
  shadowAll(root);
  return { root, gold };
}

// Tock: grey 1×1 legs, a teal 2×2 body with a brass plate, round brass arms, a round tan head,
// a red cap with a peak, googly eyes and a gold wind-up key on his back.
export function makeTock() {
  const root = new THREE.Group(), body = new THREE.Group(); root.add(body);
  const parts = {};   // the pieces that fly in during the build, by name
  const legs = [-.5, .5].map((x, i) => {
    const g = new THREE.Group(); g.position.set(x, HIP, 0); body.add(g);
    const inner = new THREE.Group(); g.add(inner);
    for (let k = 0; k < 2; k++) { const b = brick(1, 1, C.grey); b.position.y = -HIP + PLATE + k * BRICK; inner.add(b); }
    const f = plate(1, 2, C.dgrey); f.position.set(0, -HIP, .35); inner.add(f);
    parts['leg' + i] = inner; return g;
  });
  const torso = new THREE.Group(); body.add(torso); parts.body = torso;
  const hip = plate(2, 2, C.dgrey); hip.position.y = HIP; torso.add(hip);
  for (let k = 0; k < 2; k++) { const b = brick(2, 2, C.teal); b.position.y = HIP + PLATE + k * BRICK; torso.add(b); }
  const chest = plate(2, 1, C.brass, { tile: true }); chest.rotation.x = Math.PI / 2; chest.scale.set(.8, 1, .75); chest.position.set(0, HIP + PLATE + BRICK * .75, 1.0); torso.add(chest);
  for (const dx of [-.38, .38]) { const bolt = new THREE.Mesh(new THREE.CylinderGeometry(.13, .13, .12, 16), new THREE.MeshStandardMaterial({ color: '#7a5a1a', metalness: .8, roughness: .3 })); bolt.rotation.x = Math.PI / 2; bolt.position.set(dx, HIP + PLATE + BRICK * .75, 1.42); torso.add(bolt); }
  const collar = plate(2, 2, C.dgrey); collar.position.y = SHOULDER; torso.add(collar);
  const arms = [-1.5, 1.5].map((x, i) => {
    const g = new THREE.Group(); g.position.set(x, SHOULDER - .1, 0); body.add(g);
    const inner = new THREE.Group(); g.add(inner);
    for (let k = 0; k < 3; k++) { const b = mesh(roundGeo(.5), C.brass); b.position.y = -ARM_L + k * BRICK; inner.add(b); }
    const hand = new THREE.Group(); hand.position.y = -ARM_L - .2; g.add(hand);
    parts['arm' + i] = inner; return { g, hand };
  });
  const head = new THREE.Group(); head.position.set(0, SHOULDER + PLATE, 0); body.add(head);
  const headInner = new THREE.Group(); head.add(headInner); parts.head = headInner;
  const skull = mesh(roundGeo(1, BRICK * 2), C.skin); skull.scale.set(1.1, 1, 1.1); headInner.add(skull);
  const eye = eyes(headInner, BRICK * 1.1, 1.0, .5);
  const capG = new THREE.Group(); capG.position.y = BRICK * 2; head.add(capG); parts.cap = capG;
  const cap = mesh(roundGeo(1, PLATE * 2), C.cap); cap.scale.set(1.16, 1, 1.16); capG.add(cap);
  const peak = plate(2, 2, C.cap, { tile: true }); peak.position.set(0, 0, 1.2); peak.scale.set(1.05, 1, .8); capG.add(peak);
  // wind-up key on the back: turns about the z axis
  const windG = new THREE.Group(); windG.position.set(0, HIP + PLATE + BRICK, -1.05); body.add(windG); parts.wind = windG;
  const wind = new THREE.Group(); windG.add(wind);
  const k = makeKey(.4); k.root.rotation.x = -Math.PI / 2; k.root.position.z = .1; wind.add(k.root);
  shadowAll(root);

  // a pose: angles in radians. arm = [swing x, raise z]; legs = [left, right] swing; lean forward; spin = key turn
  function pose(p) {
    root.position.set(p.x, p.y ?? 0, p.z); root.rotation.y = p.ry ?? 0;
    body.position.y = p.bob ?? 0; body.rotation.x = p.lean ?? 0; body.rotation.z = p.roll ?? 0;
    legs[0].rotation.x = p.legs?.[0] ?? 0; legs[1].rotation.x = p.legs?.[1] ?? 0;
    const aL = p.armL ?? [0, .05], aR = p.armR ?? [0, .05];
    arms[0].g.rotation.set(aL[0], 0, -aL[1]); arms[1].g.rotation.set(aR[0], 0, aR[1]);
    head.rotation.set(p.nod ?? 0, p.look ?? 0, p.tilt ?? 0);
    wind.rotation.z = p.spin ?? 0;
    const lid = p.blink ? .15 : 1; eye.forEach(e => { e.g.scale.set(1, lid, 1); e.p.position.x = (p.eyeX ?? 0) * .1; e.p.position.y = (p.eyeY ?? 0) * .1; });
    root.scale.setScalar(p.scale ?? 1);
  }
  return { root, body, arms, legs, head, parts, pose, keyGold: k.gold };
}

// stride phase φ → a walk or run pose
export function walkPose(phi, amp = .55) {
  const s = Math.sin(phi);
  return { legs: [s * amp, -s * amp], armL: [-s * amp * .8, .08], armR: [s * amp * .8, .08], bob: Math.abs(Math.cos(phi)) * .2 };
}

// Baron Rust: a bench vise of rusty bricks. A fixed jaw and a sliding jaw on a grey screw, angry eyes,
// a big black moustache and a tiny top hat. Every brick is a separate body so he can fall apart.
export function makeBaron() {
  const root = new THREE.Group(); const bricks = [];
  const add = (m, x, y, z) => { m.position.set(x, y, z); root.add(m); bricks.push(m); return m; };
  add(plate(8, 6, C.rustDark), 0, 0, 0);
  for (let i = 0; i < 3; i++) add(brick(6, 4, i === 1 ? C.rustDark : C.rust), 0, PLATE + i * BRICK, 0);
  const top = PLATE + 3 * BRICK;
  for (let i = 0; i < 3; i++) add(brick(2, 4, C.rust), -2, top + i * BRICK, 0);   // fixed jaw
  const jaw = new THREE.Group(); jaw.position.set(2, top, 0); root.add(jaw);     // sliding jaw
  for (let i = 0; i < 3; i++) { const b = brick(2, 4, i === 2 ? C.rustDark : C.rust); b.position.y = i * BRICK; jaw.add(b); bricks.push(b); }
  const screw = new THREE.Mesh(new THREE.CylinderGeometry(.45, .45, 9, 20), plastic(C.grey)); screw.rotation.z = Math.PI / 2; screw.position.set(4, 1.4 * BRICK, 0); jaw.add(screw); bricks.push(screw);
  const handle = new THREE.Mesh(new THREE.CylinderGeometry(.3, .3, 6, 16), plastic(C.dgrey)); handle.position.set(8.5, 1.4 * BRICK, 0); jaw.add(handle); bricks.push(handle);
  // face on the front of the body
  const face = new THREE.Group(); face.position.set(0, PLATE + 2 * BRICK, 2.05); root.add(face);
  const e = eyes(face, .5, 0, 1.3, .62);
  const brows = [-1, 1].map(s => { const b = plate(2, 1, C.black, { tile: true }); b.rotation.set(Math.PI / 2, 0, s * .45); b.position.set(s * 1.3, 1.45, .3); face.add(b); return b; });
  // a handlebar moustache: two curved black pieces that curl up at the ends
  const stache = new THREE.Group(); stache.position.set(0, -.62, .45); face.add(stache);
  const curl = new THREE.TorusGeometry(1.25, .42, 14, 32, Math.PI * .95);
  for (const s of [-1, 1]) {
    const half = new THREE.Mesh(curl, plastic(C.black)); half.rotation.set(0, 0, s > 0 ? Math.PI * 1.02 : -Math.PI * .97);
    half.scale.set(s, 1, 1); half.position.set(s * 1.25, .55, 0); stache.add(half);
  }
  const knot = mesh(roundGeo(.5, PLATE * 1.5), C.black); knot.rotation.x = Math.PI / 2; knot.position.set(0, .15, -.2); stache.add(knot);
  // tiny top hat on the fixed jaw
  const hat = new THREE.Group(); hat.position.set(-2, top + 3 * BRICK, 0); hat.rotation.z = .18; root.add(hat);
  const brim = mesh(roundGeo(1, PLATE), C.black); hat.add(brim);
  const crown = mesh(roundGeo(.5, BRICK * 1.4), C.black); crown.position.y = PLATE; crown.scale.set(1.3, 1, 1.3); hat.add(crown);
  const band = new THREE.Mesh(new THREE.CylinderGeometry(.68, .68, .25, 24), plastic(C.cap)); band.position.y = PLATE + .3; hat.add(band);
  bricks.push(...face.children);   // the hat is not debris: it is knocked off before the fall
  shadowAll(root);
  return { root, jaw, face, eyes: e, brows, stache, hat, top, bricks };
}

// a gear-beetle: orange dome shell, dark legs, a grey gear on its back
export function makeBeetle() {
  const root = new THREE.Group();
  const shell = mesh(roundGeo(1, BRICK), C.orange); shell.position.y = .6; shell.scale.set(1.25, 1, 1.5); root.add(shell);
  const legs = new THREE.Group(); root.add(legs);
  for (const sx of [-1.3, 1.3]) for (const sz of [-1, 0, 1]) { const l = plate(1, 1, C.black); l.position.set(sx, 0, sz * .9); legs.add(l); }
  const gear = new THREE.Group(); gear.position.y = .6 + BRICK + .2; root.add(gear);
  const disc = new THREE.Mesh(new THREE.CylinderGeometry(.9, .9, .35, 24), plastic(C.grey)); gear.add(disc);
  for (let i = 0; i < 8; i++) { const t = plate(1, 1, C.grey, { tile: true }); const a = i / 8 * Math.PI * 2; t.scale.set(.45, .9, .45); t.position.set(Math.cos(a) * 1.0, -.18, Math.sin(a) * 1.0); gear.add(t); }
  const e = eyes(root, 1.1, 1.75, .45, .26);
  shadowAll(root);
  return { root, shell, legs, gear, eyes: e };
}

// a paper plane built from white plates
export function makePlane() {
  const root = new THREE.Group(); const pieces = [];
  const bodyP = plate(1, 8, C.white); bodyP.position.y = -.2; root.add(bodyP); pieces.push(bodyP);
  for (const s of [-1, 1]) {
    const w = plate(3, 6, C.white, { tile: true }); w.position.set(s * 1.9, 0, -.6); w.rotation.z = s * .22; root.add(w); pieces.push(w);
    const tip = plate(2, 2, C.white, { tile: true }); tip.position.set(s * 1.2, 0, 3.4); tip.rotation.z = s * .22; root.add(tip); pieces.push(tip);
  }
  const stripe = plate(1, 4, C.cap, { tile: true }); stripe.position.set(0, .2, -1.5); root.add(stripe); pieces.push(stripe);
  shadowAll(root);
  return { root, pieces };
}

// Tock's blaster: a dark grey brick with a round barrel
export function makeBlaster() {
  const root = new THREE.Group();
  const b = brick(1, 2, C.dgrey); b.position.set(0, -.6, 0); root.add(b);
  const barrel = mesh(roundGeo(.5, BRICK), C.black); barrel.rotation.x = Math.PI / 2; barrel.position.set(0, 0, 1.0); root.add(barrel);
  const grip = brick(1, 1, C.black); grip.position.set(0, -1.6, -.4); root.add(grip);
  shadowAll(root);
  return { root };
}
