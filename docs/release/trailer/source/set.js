// The desk: walnut, a studio HDRI, a real desk clock, a stack of books, a wooden ruler, a paint spill
// of translucent blue plates, and the desk lamp that goes out at the end. 1 unit = one stud (8 mm).
import * as THREE from 'three';
import { RGBELoader } from 'three/addons/loaders/RGBELoader.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { RectAreaLightUniformsLib } from 'three/addons/lights/RectAreaLightUniformsLib.js';
import { PLATE, mesh, roundGeo, plastic } from './bricks.js';
import { mulberry, lerp } from '/core/lib.js';

const PH = '/core/assets/polyhaven/';
export const M = 125;                                   // 1 metre in studs
export const KEY_SPOT = new THREE.Vector3(0, 0, 0);     // where the Golden Key stands, at the clock's foot
export const BUILD = new THREE.Vector3(-24, 0, 16);     // where Tock snaps together
export const BOOKS = new THREE.Vector3(-70, 0, -26);    // the Baron's tower
export const ARENA = new THREE.Vector3(-52, 0, 8);      // the fight, in front of the books
export const RULER = { x0: 30, x1: 140, z: 50, w: 8, top: .8 };
export const PAINT = { x: 74, z: -34, r: 15 };
export const SHOOT = new THREE.Vector3(30, 0, 104);
export const CLOCK = new THREE.Vector3(0, 0, -26);

export const groundY = (x, z) => {
  if (x > RULER.x0 && x < RULER.x1 && Math.abs(z - RULER.z) < RULER.w / 2) return RULER.top;
  if (Math.hypot(x - PAINT.x, z - PAINT.z) < PAINT.r) return PLATE;
  return 0;
};

function canvasTex(w, h, draw) {
  const c = document.createElement('canvas'); c.width = w; c.height = h; draw(c.getContext('2d'), w, h);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8; return t;
}

export async function buildSet(scene) {
  const hdr = await new RGBELoader().loadAsync(PH + 'photo_studio_loft_hall_2k.hdr');
  hdr.mapping = THREE.EquirectangularReflectionMapping;
  scene.environment = hdr; scene.background = hdr;
  scene.backgroundBlurriness = .55; scene.backgroundIntensity = .2; scene.environmentIntensity = .45;
  scene.environmentRotation.y = scene.backgroundRotation.y = 2.1;

  const tl = new THREE.TextureLoader(), tex = (f, srgb) => { const t = tl.load(PH + f); t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(4, 4); t.anisotropy = 8; if (srgb) t.colorSpace = THREE.SRGBColorSpace; return t; };
  const desk = new THREE.Mesh(new THREE.PlaneGeometry(700, 700), new THREE.MeshStandardMaterial({ map: tex('walnut_diff.jpg', true), normalMap: tex('walnut_nor.jpg'), roughnessMap: tex('walnut_rough.jpg'), roughness: 1 }));
  desk.rotation.x = -Math.PI / 2; desk.position.set(20, 0, 20); desk.receiveShadow = true; scene.add(desk);

  // lights: a warm key with shadows, a cool fill, softboxes for the rectangular highlights on plastic
  const key = new THREE.DirectionalLight('#fff4e8', 3.0); key.castShadow = true;
  key.shadow.mapSize.set(4096, 4096); key.shadow.bias = -.0004; key.shadow.normalBias = .03; key.shadow.radius = 4;
  Object.assign(key.shadow.camera, { left: -40, right: 40, top: 40, bottom: -40, near: 10, far: 400 });
  scene.add(key, key.target);
  const fill = new THREE.DirectionalLight('#cfe0ff', .45); fill.position.set(60, 40, -50); scene.add(fill);
  RectAreaLightUniformsLib.init();
  const box = (col, I, w, h) => { const l = new THREE.RectAreaLight(col, I, w, h); scene.add(l); return l; };
  const softKey = box('#fff6ee', 6, 60, 40), softRim = box('#e4eeff', 8, 50, 26);

  // the desk lamp: its bulb is the warm pool on the key, and it clicks off at the end
  const gl = new GLTFLoader();
  const lamp = (await gl.loadAsync(`${PH}desk_lamp_arm_01/desk_lamp_arm_01.gltf`)).scene;
  lamp.scale.setScalar(M); lamp.position.set(-62, 0, -70); lamp.rotation.y = 1.25;
  lamp.traverse(m => { if (m.isMesh) m.castShadow = m.receiveShadow = true; }); scene.add(lamp);
  const bulb = new THREE.PointLight('#ffd9a8', 900, 140, 2); bulb.position.set(-14, 52, -30); scene.add(bulb);

  // a real desk clock: cream face, brass bezel, black hands, two feet
  const clock = new THREE.Group(); clock.position.copy(CLOCK); scene.add(clock);
  const R = 20, CY = 31;
  const face = canvasTex(1024, 1024, (x, w) => {
    const c = w / 2; x.fillStyle = '#efe6d0'; x.fillRect(0, 0, w, w);
    const gr = x.createRadialGradient(c, c, c * .2, c, c, c); gr.addColorStop(0, 'rgba(0,0,0,0)'); gr.addColorStop(1, 'rgba(70,50,20,.25)'); x.fillStyle = gr; x.fillRect(0, 0, w, w);
    x.strokeStyle = '#2a2420'; x.fillStyle = '#2a2420';
    for (let i = 0; i < 60; i++) {
      const a = i / 60 * Math.PI * 2, big = i % 5 === 0, r0 = c * (big ? .78 : .84), r1 = c * .9;
      x.lineWidth = big ? 14 : 5; x.beginPath(); x.moveTo(c + Math.sin(a) * r0, c - Math.cos(a) * r0); x.lineTo(c + Math.sin(a) * r1, c - Math.cos(a) * r1); x.stroke();
    }
    x.font = '700 96px Fredoka'; x.textAlign = 'center'; x.textBaseline = 'middle';
    for (let h = 1; h <= 12; h++) { const a = h / 12 * Math.PI * 2; x.fillText(String(h), c + Math.sin(a) * c * .64, c - Math.cos(a) * c * .64 + 4); }
  });
  const body = new THREE.Mesh(new THREE.CylinderGeometry(R, R, 8, 64), new THREE.MeshStandardMaterial({ color: '#7a2f22', roughness: .35, metalness: .1 }));
  body.rotation.x = Math.PI / 2; body.position.set(0, CY, -4); clock.add(body);
  const dial = new THREE.Mesh(new THREE.CircleGeometry(R - 1.6, 64), new THREE.MeshStandardMaterial({ map: face, roughness: .6 }));
  dial.position.set(0, CY, .05); clock.add(dial);
  const bezel = new THREE.Mesh(new THREE.TorusGeometry(R - .8, 1.4, 16, 72), new THREE.MeshStandardMaterial({ color: '#c79a45', metalness: 1, roughness: .28 }));
  bezel.position.set(0, CY, .3); clock.add(bezel);
  const glass = new THREE.Mesh(new THREE.CircleGeometry(R - 1.2, 64), new THREE.MeshPhysicalMaterial({ color: '#ffffff', transmission: 1, roughness: .02, thickness: .2, clearcoat: 1, transparent: true, opacity: .25 }));
  glass.position.set(0, CY, 1.2); clock.add(glass);
  const handMat = new THREE.MeshStandardMaterial({ color: '#1d1916', roughness: .4 });
  const hand = (len, wid) => { const g = new THREE.Group(); const m = new THREE.Mesh(new THREE.BoxGeometry(wid, len, .3), handMat); m.position.y = len / 2 - 1.2; g.add(m); g.position.set(0, CY, .6); clock.add(g); return g; };
  const hourHand = hand(10, 1.3), minHand = hand(15, .9);
  const secHand = hand(16, .35); secHand.children[0].material = new THREE.MeshStandardMaterial({ color: '#b3261e', roughness: .4 });
  hourHand.rotation.z = -2.2; minHand.rotation.z = -5.5;
  for (const sx of [-12, 12]) { const f = new THREE.Mesh(new THREE.CylinderGeometry(2.2, 3, 11.5, 24), new THREE.MeshStandardMaterial({ color: '#c79a45', metalness: 1, roughness: .3 })); f.position.set(sx, 5.75, -4); clock.add(f); }
  clock.traverse(m => { if (m.isMesh) m.castShadow = m.receiveShadow = true; });
  glass.castShadow = false;

  // a stack of four cloth books
  const books = new THREE.Group(); books.position.copy(BOOKS); scene.add(books);
  const cloth = ['#2f4b6b', '#7b2d26', '#c9a45c', '#3d5c3a'];
  let by = 0; const rnd = mulberry(5);
  [[36, 4.6, 26], [33, 3.6, 24], [35, 5.2, 25], [30, 3.8, 22]].forEach(([w, h, d], i) => {
    const b = new THREE.Group(); b.position.y = by; b.rotation.y = (rnd() - .5) * .22;
    const cover = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), new THREE.MeshStandardMaterial({ color: cloth[i], roughness: .78 }));
    cover.position.y = h / 2; b.add(cover);
    const pages = new THREE.Mesh(new THREE.BoxGeometry(w - .6, h - .7, d - .3), new THREE.MeshStandardMaterial({ color: '#efe6d2', roughness: .9 }));
    pages.position.set(.4, h / 2, 0); b.add(pages);
    b.traverse(m => { if (m.isMesh) m.castShadow = m.receiveShadow = true; });
    books.add(b); by += h;
  });
  const booksTop = by;

  // a wooden ruler, the running track
  const rulerTex = canvasTex(2048, 128, (x, w, h) => {
    x.fillStyle = '#c9a26a'; x.fillRect(0, 0, w, h);
    for (let i = 0; i < 400; i++) { x.fillStyle = `rgba(110,70,30,${.03 + (i % 7) * .006})`; x.fillRect(0, (i * 37) % h, w, 1); }
    x.fillStyle = '#2b2118';
    for (let mm = 0; mm <= 880; mm += 5) { const px = mm / 880 * w, tall = mm % 50 === 0 ? 46 : mm % 10 === 0 ? 30 : 18; x.fillRect(px, 0, 3, tall); }
    x.font = '700 30px Fredoka'; for (let cm = 1; cm < 88; cm += 5) x.fillText(String(cm), cm * 10 / 880 * w + 6, 82);
  });
  const ruler = new THREE.Mesh(new THREE.BoxGeometry(RULER.x1 - RULER.x0, RULER.top, RULER.w),
    [0, 1, 2, 3, 4, 5].map(i => new THREE.MeshStandardMaterial(i === 2 ? { map: rulerTex, roughness: .55 } : { color: '#b48c58', roughness: .6 })));
  ruler.position.set((RULER.x0 + RULER.x1) / 2, RULER.top / 2, RULER.z); ruler.castShadow = ruler.receiveShadow = true; scene.add(ruler);

  // the paint spill: translucent blue round plates lying flat in a blob
  const paint = new THREE.Group(); paint.position.set(PAINT.x, 0, PAINT.z); scene.add(paint);
  // packed on a jittered hex grid inside a lumpy outline, so it reads as one puddle
  const pr = mulberry(9);
  for (let gx = -PAINT.r; gx <= PAINT.r; gx += 1.75) for (let gz = -PAINT.r, row = 0; gz <= PAINT.r; gz += 1.52, row++) {
    const x = gx + (row % 2) * .87 + (pr() - .5) * .35, z = gz + (pr() - .5) * .35, a = Math.atan2(z, x);
    if (Math.hypot(x, z) > PAINT.r * (.82 + .14 * Math.sin(a * 3 + 1) + .06 * Math.sin(a * 7))) continue;
    const m = mesh(roundGeo(1, PLATE), pr() < .3 ? '#1e64c8' : '#2f7fe0', { trans: true });
    m.position.set(x, 0, z); m.castShadow = false; paint.add(m);
  }

  // a few loose bricks on the desk, kept away from every camera's axis (checked in the stills)
  const loose = [[-48, 30, '#c91a09', 2, 4], [-36, 40, '#0055bf', 2, 2], [18, 18, '#f2cd37', 1, 2], [-8, 34, '#237841', 2, 3]];

  // the night: lamp off, the room drops to blue dusk
  function setNight(n) {
    bulb.intensity = lerp(900, 0, n);
    key.intensity = lerp(3.0, .35, n); key.color.set('#fff4e8').lerp(new THREE.Color('#7f9fe0'), n);
    fill.intensity = lerp(.45, .25, n);
    softKey.intensity = lerp(6, .4, n); softRim.intensity = lerp(8, 2.5, n);
    scene.environmentIntensity = lerp(.45, .12, n); scene.backgroundIntensity = lerp(.2, .05, n);
  }
  return { key, fill, bulb, softKey, softRim, clock, secHand, minHand, booksTop, setNight, loose };
}
