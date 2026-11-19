"""Bake original quiet riding-armour cues; Python standard library only.

Not historical measurements or recordings from another game. A deterministic
local generator keeps audio variation independent of the gameplay RNG.
"""
from array import array
import hashlib
import json
import math
from pathlib import Path
import random
import sys
import wave

RATE = 44100
ROOT = Path(__file__).resolve().parents[1] / "assets/audio/movement_v106"
PROFILES = {
    "plate": {"duration": .20, "pulses": (0, .034, .078), "modes": (237, 513, 1087), "damping": 58, "noise": .13},
    "mail": {"duration": .18, "pulses": (0, .012, .027, .046, .073, .097), "modes": (1187, 2173, 3911), "damping": 125, "noise": .34},
    "brigandine": {"duration": .17, "pulses": (0, .023, .051), "modes": (311, 683, 1471), "damping": 95, "noise": .24},
}


def samples(family: str, variant: int) -> list[float]:
    profile = PROFILES[family]
    rng = random.Random(106000 + list(PROFILES).index(family) * 100 + variant)
    pulses = [(max(0, t + rng.uniform(-.002, .002)), .82 ** i * rng.uniform(.86, 1.0)) for i, t in enumerate(profile["pulses"])]
    modes = [freq * (1 + .025 * (variant - 1)) for freq in profile["modes"]]
    values = []
    low_noise = 0.0
    for index in range(round(RATE * profile["duration"])):
        t = index / RATE
        noise = rng.uniform(-1, 1)
        low_noise += (noise - low_noise) * .2
        value = 0.0
        for start, amplitude in pulses:
            u = t - start
            if u < 0:
                continue
            envelope = min(1.0, u / .0012) * math.exp(-u * profile["damping"])
            shell = sum(math.sin(math.tau * freq * u) * weight for freq, weight in zip(modes, (.54, .29, .17)))
            value += amplitude * envelope * (shell * (1 - profile["noise"]) + (noise - low_noise) * profile["noise"])
        value *= min(1.0, (profile["duration"] - t) / .015)
        values.append(value)
    peak = max(map(abs, values))
    return [v * .30 / peak for v in values]


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    rows = []
    for family in PROFILES:
        for variant in range(3):
            values = samples(family, variant)
            pcm = array("h", (round(value * 32767) for value in values))
            if sys.byteorder != "little":
                pcm.byteswap()
            path = ROOT / f"armor_{family}_{variant}.wav"
            with wave.open(str(path), "wb") as out:
                out.setnchannels(1)
                out.setsampwidth(2)
                out.setframerate(RATE)
                out.writeframes(pcm.tobytes())
            # Keep the tiny transients lossless and the imported PCM auditable.
            imported = Path(str(path) + ".import")
            if imported.exists():
                settings = imported.read_text(encoding="utf-8").replace("compress/mode=2", "compress/mode=0").replace("compress/mode=1", "compress/mode=0")
            else:
                res_path = "res://assets/audio/movement_v106/" + path.name
                settings = '[remap]\nimporter="wav"\ntype="AudioStreamWAV"\n\n[deps]\nsource_file="' + res_path + '"\n\n[params]\nforce/8_bit=false\nforce/mono=false\nforce/max_rate=false\nforce/max_rate_hz=44100\nedit/trim=false\nedit/normalize=false\nedit/loop_mode=0\nedit/loop_begin=0\nedit/loop_end=-1\ncompress/mode=0\n'
            imported.write_text(settings, encoding="utf-8")
            rows.append({"file": path.name, "bytes": path.stat().st_size, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "seconds": len(values) / RATE, "peak": max(map(abs, values)), "rms": math.sqrt(sum(x*x for x in values) / len(values))})
    (ROOT / "manifest.json").write_text(json.dumps({"generator": "game/tools/build_movement_audio106.py", "origin": "Original procedural game sound; no third-party recordings; not historical acoustic data", "rate": RATE, "channels": 1, "sample_bits": 16, "files": rows}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"files": len(rows), "wav_bytes": sum(x["bytes"] for x in rows), "directory": str(ROOT)}))


if __name__ == "__main__":
    main()
