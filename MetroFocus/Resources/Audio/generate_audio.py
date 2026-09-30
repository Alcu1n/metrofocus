#!/usr/bin/env python3
"""Original deterministic MetroFocus sound design. Python standard library only.
All WAV output is newly synthesized; no sampled or licensed third-party audio.
Run from any directory: python3 path/to/generate_audio.py
"""
import array
import json
import math
from pathlib import Path
import random
import sys
import wave

ROOT = Path(__file__).resolve().parent
RATE = 22050
DURATION = 12
N = RATE * DURATION
TAU = 2 * math.pi
rng = random.Random(734921)

def cyclic_lowpass(values, alpha):
    # Warm up using the exact preceding period so the noise filters close at the seam.
    state = 0.0
    for x in values:
        state += alpha * (x - state)
    result = []
    for x in values:
        state += alpha * (x - state)
        result.append(state)
    return result

report = {}
def write(name, values, loop=False):
    peak = max(abs(x) for x in values) or 1
    values = [x * (0.25 / peak) for x in values]
    pcm = array.array('h', (round(x * 32767) for x in values))
    if sys.byteorder != 'little': pcm.byteswap()
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as out:
        out.setnchannels(1); out.setsampwidth(2); out.setframerate(RATE)
        out.writeframes(pcm.tobytes())
    differences = sorted(abs(values[i] - values[i - 1]) for i in range(1, len(values)))
    report[name] = {'duration_seconds': len(values) / RATE, 'peak_dbfs': round(20 * math.log10(max(abs(x) for x in values)), 2), 'rms_dbfs': round(20 * math.log10(math.sqrt(sum(x*x for x in values)/len(values))), 2), 'loop': loop}
    if loop:
        report[name].update(seam_delta=round(abs(values[0] - values[-1]), 6), adjacent_delta_p99=round(differences[int(len(differences)*.99)], 6))

white = [rng.uniform(-1, 1) for _ in range(N)]
low = cyclic_lowpass(white, .014)
mid = cyclic_lowpass(white, .16)
fine = cyclic_lowpass(white, .5)
# All tones/envelopes have an integer number of cycles within the 12-second loop.
metro=[]; rain=[]; air=[]
for i in range(N):
    t = i / RATE
    phase = i / N
    rumble = .14 * math.sin(TAU * 48 * t) + .07 * math.sin(TAU * 72 * t)
    joint = max(0, math.sin(TAU * 24 * phase)) ** 20
    metro.append(low[i] * 3.0 + mid[i] * .14 + rumble + joint * .10 * math.sin(TAU * 160 * t))
    rain.append((fine[i] - low[i]) * .36 * (1 + .10 * math.sin(TAU * 3 * phase)) + low[i] * .8)
    air.append(mid[i] * .3 + low[i] * 2.2 * (1 + .07 * math.sin(TAU * phase)))
write('metro', metro, True); write('rain', rain, True); write('air', air, True)

for name, notes in [('departure', [523.25, 659.25, 783.99]), ('arrival', [783.99, 659.25, 523.25])]:
    samples=[]
    for i in range(int(RATE * 1.3)):
        t=i/RATE
        value=0
        for j, freq in enumerate(notes):
            age=t-j*.24
            if age >= 0:
                envelope=min(1, age/.012)*math.exp(-age*7)
                value += envelope*(math.sin(TAU*freq*age)+.18*math.sin(TAU*freq*2*age))
        samples.append(value)
    # Fade to digital zero, eliminating edge clicks.
    for j in range(300): samples[-300+j] *= (299-j)/300
    write(name, samples)
samples=[]
for i in range(int(RATE*.32)):
    t=i/RATE
    tap=min(1,t/.003)*math.exp(-t*45)
    rebound=0 if t<.085 else math.exp(-(t-.085)*70)*.3
    value=tap*(rng.uniform(-1,1)*.55+math.sin(TAU*130*t)) + rebound*math.sin(TAU*240*t)
    samples.append(value)
for j in range(300): samples[-300+j] *= (299-j)/300
write('punch', samples)
for name, result in report.items():
    assert result['peak_dbfs'] < -12, name + ': unexpected clipping risk'
    assert result['rms_dbfs'] > -45, name + ': unexpectedly silent'
    if result['loop']:
        assert result['seam_delta'] < result['adjacent_delta_p99'], name + ': loop discontinuity'
(ROOT / 'audio-validation.json').write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps(report, indent=2))
