# Original score from the cue map in TREATMENT.md: 120 bpm, one bar = 2 s. VCSL samples (CC0) and pluck.py models.
# Writes out/score.wav.
import os, sys, numpy as np, soundfile as sf
LIB = os.environ.get('LIB') or os.path.abspath(os.path.join(os.path.dirname(__file__), '../..'))
sys.path.insert(0, LIB)
from core.audio import sampler as S, pluck as P
from core.audio.sfx import SR, add, limit

HERE = os.path.dirname(os.path.abspath(__file__))
DUR = 44.0
B = .5   # one beat
S.seed(7)
ev = []                                   # sampled events: (t, inst, pitch, dur, vel, pan)
buf = np.zeros((int((DUR + 3) * SR), 2), np.float32)   # modelled plucks go straight in here


def pl(preset, pitch, t, dur, vel=.7, pan=0., gain=1., **kw):
    add(buf, P.pluck(preset, pitch, dur, vel, **kw), t, gain, pan)


# —— 0–2.5 the theft: a music box over a plucked bass, cut dead at the clamp ——
for i, n in enumerate(['E5', 'G5', 'C6', 'G5', 'E5']):
    pl('music_box', n, i * B, .9, .55, .15, .9)
for t, n in [(0, 'C2'), (1.0, 'G2'), (2.0, 'C2')]:
    pl('upright_bass_pizz', n, t, .45, .6, -.1, .8)

# —— 4–10 the build: a glockenspiel note on every snap, rising ——
for t, n in zip([5.0, 5.5, 6.0, 6.5, 7.0, 7.5, 8.0], ['C6', 'D6', 'E6', 'F6', 'G6', 'A6', 'C7']):
    ev.append((t, 'glockenspiel', n, 1.2, .62, .1))
for k, n in enumerate(['C2', 'E2', 'G2', 'E2', 'F2', 'A2', 'C3', 'A2', 'G2', 'B2', 'D3', 'B2']):
    pl('upright_bass_pizz', n, 4.0 + k * B, .45, .5, -.15, .7)
for t, ch in [(4.0, ['C4', 'E4', 'G4']), (6.0, ['F4', 'A4', 'C5']), (8.0, ['G4', 'B4', 'D5'])]:
    for n in ch: ev.append((t, 'marimba', n, 1.6, .35, -.2))
for k, n in enumerate(['C4', 'E4', 'G4', 'C5', 'E5', 'G5', 'C6', 'E6']):   # harp run on the wind-up
    ev.append((8.5 + k * .055, 'harp', n, 1.2, .5, .25))
ev.append((9.25, 'glockenspiel', 'C7', 1.5, .55, 0)); ev.append((9.25, 'claps', 'group', None, .45, 0))

# —— 10–14 the Baron: pompous staccato sax and low marimba, woodblock on the off-beats ——
sax = [(10.0, 'C3'), (10.5, 'G#2'), (11.0, 'A#2'), (11.5, 'C3'), (11.75, 'D#3'), (12.0, 'D3'), (12.5, 'A#2'), (13.0, 'G#2'), (13.5, 'G#2')]
for t, n in sax: ev.append((t, 'tenor_sax_stac', n, .35, .7, -.1))
for t in [10.0, 11.0, 12.0, 13.0]: ev.append((t, 'marimba', 'C3' if t < 12 else 'G#2', 1.0, .5, .1))
for t in np.arange(10.25, 14, .5): ev.append((float(t), 'woodblock', 'a', None, .32, .3))

# —— 14–26 the chase: xylophone tune in eighths, plucked bass, claps on 2 and 4 ——
phrase = ['C5', 'E5', 'G5', 'C6', 'B5', 'G5', 'E5', 'G5', 'A5', 'F5', 'A5', 'C6', 'G5', 'E5', 'D5', 'E5',
          'F5', 'A5', 'C6', 'A5', 'G5', 'E5', 'C5', 'E5', 'D5', 'F5', 'G5', 'B5', 'C6', None, None, None]
roots = ['C2', 'F2', 'C2', 'G2']
for bar in range(6):
    t0 = 14.0 + bar * 2
    for k in range(8):
        n = phrase[(bar % 4) * 8 + k]
        if n and not (t0 + k * .25 > 25.9): ev.append((t0 + k * .25, 'xylophone', n, .3, .5 + (.08 if k % 2 == 0 else 0), .2))
    r = roots[bar % 4]
    for k in range(4): pl('upright_bass_pizz', r if k % 2 == 0 else S.name(S.midi(r) + 7), t0 + k * B, .45, .6, -.15, .85)
    for k in (1, 3): ev.append((t0 + k * B, 'claps', 'group', None, .35, 0))
for t, n in [(16.0, 'G6'), (19.5, 'E6'), (23.75, 'C7')]:   # an answer on each verb
    ev.append((t, 'glockenspiel', n, 1.0, .6, -.2))

# —— 26–28 silence: only the clock (in the mix) ——

# —— 28–34 the turn: bass drum on the slam, the band on the collapse ——
ev.append((28.0, 'gran_cassa', 'hit', None, .8, 0))
for k, n in enumerate(['C5', 'B4', 'A4', 'G4', 'F4', 'E4', 'D4', 'C4']):   # tumbling bricks
    ev.append((31.0 + k * .09, 'xylophone' if S.midi(n) >= S.midi('G4') else 'marimba', n, .3, .55, (k % 2 - .5) * .4))
ev.append((31.0, 'clash', 'crash', None, .55, 0)); ev.append((31.0, 'gran_cassa', 'hit', None, .7, 0))
for n in ['C3', 'G3', 'C4', 'E4']: ev.append((31.0, 'marimba', n, 2.0, .45, 0))
ev.append((32.5, 'glockenspiel', 'G6', 1.2, .55, .2)); ev.append((32.75, 'glockenspiel', 'C7', 1.4, .55, .2))
for n in ['C4', 'E4', 'G4', 'C5']: ev.append((33.2, 'vibraphone', n, 1.5, .45, 0))

# —— 34–37 the theme in major on vibraphone and harp ——
for t, n in [(34.0, 'E5'), (34.5, 'G5'), (35.0, 'C6'), (35.5, 'E6'), (36.0, 'D6'), (36.5, 'C6')]:
    ev.append((t, 'vibraphone', n, .9, .5, .1))
for t, ch in [(34.0, ['C3', 'G3', 'E4']), (35.0, ['F3', 'C4', 'A4']), (36.0, ['G3', 'D4', 'B4'])]:
    for k, n in enumerate(ch): ev.append((t + k * .04, 'harp', n, 1.2, .45, -.2))

# —— 37–44 lights out: a cymbal roll into the title, one held chord, then the music box winding down ——
ev.append(dict(t=37.9, inst='sus_cymbal', pitch='cresc', dur=None, vel=.45, pan=0))
for n in ['C3', 'G3', 'C4', 'E4', 'G4', 'C5']: ev.append((39.0, 'vibraphone', n, 3.0, .45, 0))
for k, n in enumerate(['C4', 'G4', 'C5', 'E5', 'G5', 'C6']): ev.append((39.0 + k * .05, 'harp', n, 2.5, .45, .2))
ev.append((39.0, 'glockenspiel', 'C7', 2.0, .5, 0)); ev.append((41.2, 'glockenspiel', 'G6', 1.6, .45, .1))
for n in ['C4', 'E4', 'G4']: ev.append((42.0, 'vibraphone', n, 2.2, .35, 0))
gap, t = .5, 37.5
for n in ['E5', 'G5', 'C6', 'G5', 'E5', 'D5', 'C5']:   # the opening motif, slowing like a spring running out
    pl('music_box', n, t, 1.2, .5, .2, .85); t += gap; gap *= 1.17

mix = S.render(ev, dur=DUR + 3)
mix = mix + buf[:len(mix)]
mix = S.room(mix, size=.35, mix=.16)
mix = mix[:int(DUR * SR)]
for c in range(2): mix[:, c] = limit(mix[:, c], .9)
os.makedirs(os.path.join(HERE, 'out'), exist_ok=True)
sf.write(os.path.join(HERE, 'out', 'score.wav'), mix.astype(np.float32), SR)
print('score', mix.shape, 'peak', float(np.abs(mix).max()))
print('\n'.join(S.credits(['glockenspiel', 'xylophone', 'marimba', 'vibraphone', 'harp', 'tenor_sax_stac', 'woodblock', 'claps', 'gran_cassa', 'clash', 'sus_cymbal'])))
