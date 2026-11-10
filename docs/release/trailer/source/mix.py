# Mix: foley from events.json + room tone and the desk clock → out/mix.wav. No music and no voice in this film.
import os, sys, json, numpy as np, soundfile as sf
LIB = os.environ.get('LIB') or os.path.abspath(os.path.join(os.path.dirname(__file__), '../..'))
sys.path.insert(0, os.path.join(LIB, 'core', 'audio'))
from sfx import *

HERE = os.path.dirname(os.path.abspath(__file__))
E = json.load(open(os.path.join(HERE, 'events.json'))); DUR = E['dur']; N = int(DUR * SR)
fx, amb = np.zeros((N, 2)), np.zeros((N, 2))
rng = np.random.default_rng(5)


# sounds this film needs beyond sfx.py
def pew(v=1.0):   # a toy bolt: a quick falling chirp with a little noise
    d = .16; tt = t_(d); f = 1900 * np.exp(-tt * 9) + 380
    return norm(np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(d, .05) + hp(noise(d), 3000) * env_exp(d, .01) * .3) * v
def scrape(d, v=1.0):   # plastic dragged over wood
    return norm(bp(noise(d), 700, 2600) * (.5 + .5 * np.sin(2 * np.pi * 9 * t_(d))) * np.minimum(1, t_(d)[::-1] * 8)) * v
def slosh(d, v=1.0):    # sliding through wet paint
    x = lp(noise(d), 900) * (.6 + .4 * np.sin(2 * np.pi * 3.2 * t_(d)) ** 2)
    return norm(x * np.minimum(1, t_(d) * 6) * np.minimum(1, t_(d)[::-1] * 3)) * v
def rattle(v=1.0):      # a pile of bricks twitching
    out = np.zeros(int(.4 * SR))
    for k in range(9): c = clack(1.4 + rng.random() * .6, .5 + rng.random() * .5); s = int((.02 + k * .04 + rng.random() * .02) * SR); out[s:s + len(c)] += c[:len(out) - s]
    return norm(out) * v
def ratchet(d, v=1.0, slow=False):   # a wind-up key turning: fast clicks, or clicks that slow to a stop
    out = np.zeros(int((d + .1) * SR)); t, gap = 0.0, .045
    while t < d:
        c = click(1.8, .7); s = int(t * SR); out[s:s + len(c)] += c[:len(out) - s]
        t += gap; gap = gap * 1.09 if slow else gap
    return norm(out) * v
def switch(v=1.0):      # the lamp's switch
    return norm(click(.55, 1) + np.pad(click(.8, .5), (int(.03 * SR), 0))[:len(click())]) * v
def blow(v=1.0):
    return norm(bp(noise(.35), 400, 1800) * np.sin(np.pi * t_(.35) / .35)) * v

G = dict(click=.55, clack=.42, crash=.6, whoosh=.2, creak=.3, thump=.6, step=.16, ding=.32, pop=.32, pew=.32, scrape=.25,
         slosh=.3, rattle=.3, ratchet=.35, switch=.6, blow=.18, winddown=.3)
for e in E['ev']:
    ty, t, v = e['type'], e['t'], e.get('v', 1.0); pan = float(rng.uniform(-.25, .25))
    if ty == 'click': x = click(e.get('pitch', 1.0) * rng.uniform(.95, 1.05), v)
    elif ty == 'clack': x = clack(rng.uniform(.8, 1.3), v)
    elif ty == 'crash': x = crash(v)
    elif ty == 'whoosh': x = whoosh(.35, v)
    elif ty == 'creak': x = creak(v)
    elif ty == 'thump': x = thump(v, e.get('f', 70))
    elif ty == 'step': x = step(v)
    elif ty == 'ding': x = ding(v); pan = 0
    elif ty == 'pop': x = pop(v); pan = 0
    elif ty == 'pew': x = pew(v); pan = .2
    elif ty == 'scrape': x = scrape(e['d'], v); pan = -.4
    elif ty == 'slosh': x = slosh(e['d'], v)
    elif ty == 'rattle': x = rattle(v)
    elif ty == 'ratchet': x = ratchet(e['d'], v); pan = 0
    elif ty == 'winddown': x = ratchet(e['d'], v, slow=True); pan = 0
    elif ty == 'switch': x = switch(v); pan = -.3
    elif ty == 'blow': x = blow(v)
    else: continue
    add(fx, x, t, G[ty], pan)
for k in range(5): add(fx, heartbeat(.8), 28.4 + k * .5, .4)   # the pulse under the turn

# room tone, and the desk clock ticking once a second (loudest in the silence before the turn)
room = lp(brown(DUR), 250) * .02
amb[:, 0] += room; amb[:, 1] += np.roll(room, 997)
for k in range(int(DUR)):
    loud = .09 if 26 <= k < 28 or k < 4 else .035
    tick = hp(noise(.02), 3000) * env_exp(.02, .002) * loud
    add(amb, tick, float(k), 1.0, .35)

# No music: the user asked for sound effects only. The foley and the room carry the film.
for c in range(2): fx[:, c] = compress(fx[:, c], .2, 3.0)   # tame the sharpest clicks so the film can reach -14 LUFS
mix = (fx * .9 + amb) * 2.3   # about +7 dB into the limiter: effects alone are sparse and spiky, and the master needs peaks within 13 dB of the loudness
for c in range(2): mix[:, c] = limit(mix[:, c], .95)
sf.write(os.path.join(HERE, 'out', 'mix.wav'), mix.astype(np.float32), SR)
print('mix peak', float(np.abs(mix).max()), 'rms', float(np.sqrt((mix ** 2).mean())))
