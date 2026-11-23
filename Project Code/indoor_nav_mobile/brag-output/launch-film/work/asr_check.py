"""Transcribes every narration file and prints it next to the intended line,
so garbled or extra words from the TTS are caught."""
import sys
from pathlib import Path
import subprocess
import numpy as np
from faster_whisper import WhisperModel


def load(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", "16000", "-f", "f32le", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32)


vo = Path(sys.argv[1]); lines = dict(l.split("\t", 1) for l in Path(sys.argv[2]).read_text(encoding="utf8").strip().split("\n"))
m = WhisperModel("small.en", device="cpu", compute_type="int8")
for f in sorted(vo.glob("*.wav")):
    segs, _ = m.transcribe(load(f), beam_size=5, word_timestamps=True)
    words = [(w.word.strip(), round(w.start, 2), round(w.end, 2)) for s in segs for w in s.words]
    heard = " ".join(w for w, _, _ in words)
    print(f"== {f.stem}\n  want : {lines.get(f.stem, '?')}\n  heard: {heard}")
    if len(sys.argv) > 3:
        print("  words:", words)
