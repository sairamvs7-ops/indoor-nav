import sys, subprocess, numpy as np
from faster_whisper import WhisperModel
m = WhisperModel("small.en", device="cpu", compute_type="int8")
for p in sys.argv[1:]:
    raw = subprocess.run(["ffmpeg","-v","error","-i",p,"-ac","1","-ar","16000","-f","f32le","-"],capture_output=True).stdout
    a = np.frombuffer(raw, np.float32)
    segs,_ = m.transcribe(a, beam_size=1, vad_filter=False)
    print("==", p.split('/')[-1])
    for s in segs:
        print(f"  {s.start:6.1f}-{s.end:6.1f} nospeech={s.no_speech_prob:.2f} {s.text}")
