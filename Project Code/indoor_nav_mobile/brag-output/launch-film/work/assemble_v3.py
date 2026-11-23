"""Assembles build_film3.py: helpers and audio mix from build_film.py, scenes
from scenes_v3.py.txt, and captions timed to the voiced parts of each line."""
from pathlib import Path

W = Path(__file__).parent
src = (W / "build_film.py").read_text(encoding="utf-8")
head = src[:src.index("# What the captions say")]
mid = src[src.index("def place(plan, lead):"):src.index("# ======================================================================= 1 campus")]
foot = src[src.index("TOTAL = round(T0[0], 2)"):]
a = foot.index("cap_items = []")
b = foot.index("caps = ")
new_cap = '''cap_items = []
import re as _re
import subprocess as _sp


def voiced(path, d):
    """Voiced spans of a narration file, from ffmpeg silencedetect."""
    out = _sp.run(["ffmpeg", "-hide_banner", "-i", str(ROOT / path), "-af", "silencedetect=n=-38dB:d=0.18", "-f", "null", "-"],
                  capture_output=True, text=True).stderr
    st = [float(x) for x in _re.findall(r"silence_start: ([0-9.]+)", out)]
    en = [float(x) for x in _re.findall(r"silence_end: ([0-9.]+)", out)]
    spans, cur = [], 0.0
    for s0, e0 in zip(st, en + [d]):
        if s0 > cur + 0.05:
            spans.append((cur, s0))
        cur = e0
    if cur < d - 0.05:
        spans.append((cur, d))
    return spans or [(0.0, d)]


def at_voiced(spans, frac):
    want = sum(e0 - s0 for s0, e0 in spans) * frac
    for s0, e0 in spans:
        if want <= e0 - s0:
            return s0 + want
        want -= e0 - s0
    return spans[-1][1]


for vid, start in VOICE:
    text, d = CAP[vid], VD[vid]
    spans = voiced(f"{VO_DIR}/{vid}.wav", d)
    parts, cur = [], []
    words = text.split(" ")
    for k, w in enumerate(words):
        cur.append(w)
        # a long run breaks at 8 words, unless a phrase ends within 2 more
        soon = any(x.endswith((",", ".", "?", ":")) for x in words[k + 1:k + 3])
        if (w.endswith((",", ".", "?", ":")) and len(cur) >= 3) or (len(cur) >= 8 and not soon) or len(cur) >= 10:
            parts.append(" ".join(cur)); cur = []
    if cur:
        if parts and len(cur) < 3:
            parts[-1] += " " + " ".join(cur)
        else:
            parts.append(" ".join(cur))
    total = sum(len(p) for p in parts)
    acc = 0
    for p in parts:
        t0 = at_voiced(spans, acc / total)
        acc += len(p)
        t1 = at_voiced(spans, acc / total)
        cap_items.append((round(start + t0 - 0.05, 2), round(max(0.5, t1 - t0 + 0.15), 2), p))
cap_items.sort()
for _i in range(len(cap_items) - 1):
    _st, _du, _tx = cap_items[_i]
    _nx = cap_items[_i + 1][0]
    if _st + _du > _nx - 0.02:
        cap_items[_i] = (_st, round(max(0.2, _nx - 0.02 - _st), 2), _tx)
'''
foot = foot[:a] + new_cap + foot[b:]
mix_code = r"""
# ---- one pre-mixed soundtrack (smooth preview); the separate clips stay, hidden
import re as _re2
import subprocess as _sp2
import wave as _wave
import numpy as _np
SR = 48000
mix = _np.zeros((int((TOTAL + 1) * SR), 2), _np.float32)
for tag in audio:
    at = dict(_re2.findall(r'([\w-]+)="([^"]*)"', tag))
    st, du = float(at["data-start"]), float(at.get("data-duration", 0) or 0)
    ms = float(at.get("data-media-start", 0))
    raw = _sp2.run(["ffmpeg", "-v", "error", "-ss", str(ms), "-t", str(du), "-i", str(ROOT / at["src"]), "-ac", "2", "-ar", str(SR), "-f", "f32le", "-"],
                   capture_output=True, check=True).stdout
    x = _np.frombuffer(raw, _np.float32).reshape(-1, 2) * float(at.get("data-volume", 1))
    n = len(x)
    env = _np.ones(n, _np.float32)
    fi, fo = float(at.get("data-fade-in", 0)), float(at.get("data-fade-out", 0))
    if fi:
        k = min(n, int(fi * SR)); env[:k] = _np.linspace(0, 1, k)
    if fo:
        k = min(n, int(fo * SR)); env[n - k:] = _np.linspace(1, 0, k)
    i = int(st * SR)
    seg = (x * env[:, None])[: len(mix) - i]
    mix[i:i + len(seg)] += seg
mix = mix[: int(TOTAL * SR)]
peak = float(_np.abs(mix).max())
if peak > 0.89:
    mix *= 0.89 / peak
(ROOT / "assets/audio").mkdir(exist_ok=True)
with _wave.open(str(ROOT / "assets/audio/film_mix.wav"), "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((_np.clip(mix, -1, 1) * 32767).astype("<i2").tobytes())
(W / "audio_stems.html").write_text("\n".join(audio), encoding="utf-8")  # the separate clips, for re-mixing
audio = []
audio.insert(0, f'      <audio id="film-mix" data-start="0" data-duration="{TOTAL}" data-track-index="5" data-volume="1" src="assets/audio/film_mix.wav"></audio>')
"""
idx = foot.index('(ROOT / "index.html").write_text(')
foot = foot[:idx] + mix_code + "\n" + foot[idx:]

(W / "build_film3.py").write_text(head + mid + (W / "scenes_v3.py.txt").read_text(encoding="utf-8") + foot, encoding="utf-8")
print("assembled build_film3.py")
