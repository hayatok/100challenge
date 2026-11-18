"""Offline Japanese dispatch announcements. Run with pyopenjtalk-plus 0.4.1.post10 and NumPy."""
from pathlib import Path
import wave
import numpy as np
import pyopenjtalk

lines = {
    "arrival_pa": "乗車を確認。避難輸送を出発します。",
    "field_pa": "各班、出動してください。",
    "danger_pa": "接近警報。現場からの報告です。",
    "section_pa": "次の避難場所を地図に表示します。",
    "accepted_pa": "了解。現場に向かいます。",
    "casualty_pa": "こちら指令。隊員の救護を要請します。",
    "ready_pa": "輸送の準備ができました。出発の指示を待ちます。",
}
out = Path(__file__).resolve().parents[2] / "Game/Assets/Resources/Sound"
for key, line in lines.items():
    x, rate = pyopenjtalk.tts(line)
    x = x.astype(float) / max(1, np.max(np.abs(x)))
    # Limit both ends of the spectrum to reproduce the field receiver.
    x -= np.convolve(x, np.ones(83) / 83, 'same')
    x = np.convolve(x, np.ones(9) / 9, 'same')
    samples = np.tanh(x * 1.8)[::2]
    samples += .10 * np.concatenate((np.zeros(750), samples[:-750]))
    with wave.open(str(out / (key + ".wav")), "wb") as wav:
        wav.setparams((1, 2, round(rate / 2), 0, "NONE", ""))
        wav.writeframes((np.clip(samples, -1, 1)*27500).astype("<i2").tobytes())
