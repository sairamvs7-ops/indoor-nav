import sys, subprocess, numpy as np
from faster_whisper import WhisperModel
m = WhisperModel("small.en", device="cpu", compute_type="int8")
raw = subprocess.run(["ffmpeg","-v","error","-i",sys.argv[1],"-ac","1","-ar","16000","-f","f32le","-"],capture_output=True).stdout
segs,_ = m.transcribe(np.frombuffer(raw,np.float32), beam_size=5, word_timestamps=True)
print(" ".join(f"{w.word.strip()}@{w.start+44:.2f}" for s in segs for w in s.words))
