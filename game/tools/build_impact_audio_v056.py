"""Author deterministic, layered contact PCM using only Python's standard library.

These are stylised game effects, not recordings or historical acoustic simulations.
No old asset is overwritten. The optional bank update changes this task's peak table
and asset directory only; Godot import/runtime validation belongs to the owner.
"""
from __future__ import annotations

import argparse
import array
import cmath
import hashlib
import json
import math
from pathlib import Path
import random
import re
import wave

RATE = 44100
ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "game"
DEST = GAME / "assets/audio/impact_v056"
OLD = GAME / "assets/audio/impact_v050"
FAMILIES = ("helmet", "plate", "mail", "padded", "shield_wood", "brigandine")
# Frequency, relative body gain, exponential damping. Metal modes are deliberately
# inharmonic, span the audible mids, and have no single sustained bell fundamental.
PROFILES = {
    "helmet": dict(modes=((153,.17,17),(327,.18,13),(579,.13,16),(913,.12,19),
                          (1437,.08,24),(2291,.05,33),(3547,.025,50)),
                   pressure=.60, body=.82, edge=.70, grain=.12, tail=.53, peak=.68),
    "plate": dict(modes=((117,.22,14),(203,.18,15),(379,.19,11),(653,.13,17),
                         (1031,.10,20),(1667,.055,31),(2683,.025,42)),
                  pressure=.84, body=1.0, edge=.48, grain=.18, tail=.60, peak=.68),
    "mail": dict(modes=((139,.16,24),(271,.13,25),(473,.075,34),(1109,.05,46)),
                 pressure=.58, body=.59, edge=.37, grain=.90, tail=.44, peak=.63),
    "padded": dict(modes=((83,.25,17),(147,.18,23),(263,.12,31),(421,.055,43)),
                   pressure=1.02, body=.90, edge=.16, grain=.07, tail=.42, peak=.64),
    "shield_wood": dict(modes=((137,.23,22),(239,.22,25),(419,.15,31),
                               (733,.055,42),(1259,.025,61)),
                        pressure=.64, body=.90, edge=.43, grain=.29, tail=.43, peak=.68),
    "brigandine": dict(modes=((143,.18,22),(283,.17,25),(547,.10,24),
                              (997,.065,31),(1807,.035,44)),
                       pressure=.70, body=.72, edge=.43, grain=.61, tail=.48, peak=.65),
}


def lowpass(values: list[float], hz: float) -> list[float]:
    a = 1.0 - math.exp(-2 * math.pi * hz / RATE)
    state = 0.0
    result = []
    for value in values:
        state += a * (value - state)
        result.append(state)
    return result


def bandpass(values: list[float], low: float, high: float) -> list[float]:
    floor = lowpass(values, low)
    return lowpass([a-b for a, b in zip(values, floor)], high)


def pulse(t: float, start: float, decay: float, attack: float = .0012) -> float:
    age = t - start
    if age < 0:
        return 0.0
    return min(1.0, age / attack) * math.exp(-age * decay)


def contact(family: str, kind: str, variant: int) -> list[float]:
    p = PROFILES[family]
    glance = kind == "glance"
    duration = .32 if glance else p["tail"]
    count = round(duration * RATE)
    rng = random.Random(56003 + FAMILIES.index(family)*701 + variant*137 + (10007 if glance else 0))
    raw = [rng.uniform(-1, 1) for _ in range(count)]
    pressure = bandpass(raw, 48, 280)
    body_noise = bandpass(raw, 170, 1900 if family != "padded" else 800)
    surface = bandpass(raw, 950 if family != "shield_wood" else 600, 7400)
    rattle = bandpass([rng.uniform(-1, 1) for _ in range(count)], 1300, 7000)
    tuning = 1.0 + (-.013, .008, .020)[variant]
    modes = [(f*tuning, g, d, rng.uniform(-.26,.26)) for f,g,d in p["modes"]]
    grain_times = [.014,.032,.055,.083,.119,.161]
    grain_times = [s+rng.uniform(-.002,.002) for s in grain_times]
    values = []
    for i in range(count):
        t = i/RATE
        # Broad-band loaded body lasts longer than the edge, so the audible
        # response is a compressed object, not a click over an inaudible sub.
        loaded = pressure[i]*p["pressure"]*3.0*pulse(t,0,20,.0018)
        loaded += body_noise[i]*p["body"]*1.32*pulse(t,0,24,.0013)
        edge = surface[i]*p["edge"]*1.50*pulse(t,0,105,.00065)
        modes_value = 0.0
        for freq,gain,decay,phase in modes:
            # Slight pitch movement is confined to body compression. Do not
            # turn the high shell response into a laser or a tuned bell.
            deflect = .008 if freq < 300 else .002
            phase_t = 2*math.pi*(freq*t-freq*deflect*t*t)
            modes_value += math.sin(phase_t+phase)*gain*pulse(t,0,decay,.0017)
        grain_envelope = sum(pulse(t,s,92,.0009) * math.exp(-s*8) for s in grain_times)
        grains = rattle[i]*p["grain"]*grain_envelope*.70
        if family == "shield_wood":
            # Brief stressed-fibre crunch follows the board's initial knock;
            # actual lance fracture remains a separate event/cue.
            grains += body_noise[i]*.75*(pulse(t,.009,90)+pulse(t,.024,105))
        elif family == "plate":
            # Lower-mid flex comes after contact, tightly enough to stay one
            # event. A plate has a broader, slower body than a helmet shell.
            modes_value += math.sin(2*math.pi*331*t+.17)*.10*pulse(t,.011,19,.003)
        elif family == "helmet":
            modes_value += math.sin(2*math.pi*1871*t+.7)*.05*pulse(t,.003,32,.001)
        if glance:
            scrape = body_noise[i]*1.05*pulse(t,.004,22,.006)
            scrape += surface[i]*.40*pulse(t,.006,32,.004)
            value = loaded*.25+edge*.45+modes_value*.22+grains*.60+scrape
        else:
            value = loaded+edge+modes_value+grains
        # Broad, gentle saturation gives body density without hard clipping;
        # final bounded gain is explicit and measured from written int16 PCM.
        value = math.tanh(value*1.12)/1.12
        value *= min(1.0,max(0.0,(duration-t)/.024))
        values.append(value)
    return master(values, p["peak"]*(.57 if glance else 1.0))


def lance_break(variant: int) -> list[float]:
    rng = random.Random(56831+variant*157)
    duration = .41
    raw = [rng.uniform(-1,1) for _ in range(round(duration*RATE))]
    snap = bandpass(raw, 550, 7800)
    fibre = bandpass(raw, 180, 2300)
    values = []
    starts = [0,.007+variant*.0008,.019,.042,.076,.128]
    for i in range(len(raw)):
        t = i/RATE
        envelope = sum(pulse(t,s,140,.0006)*math.exp(-s*9) for s in starts)
        value = snap[i]*1.13*envelope+fibre[i]*.75*pulse(t,.003,28,.001)
        value += math.sin(2*math.pi*(183+variant*4)*t)*.14*pulse(t,0,30,.001)
        values.append(math.tanh(value)*min(1.0,(duration-t)/.02))
    return master(values,.57)


def master(values: list[float], target: float) -> list[float]:
    # Eliminate DC/rumble and keep the noisy surface out of brittle extreme
    # treble. Per-variant fixed target is mastering, not a runtime compressor.
    filtered = bandpass(values, 32, 10500)
    gain = target/max(1e-9,max(abs(x) for x in filtered))
    return [x*gain for x in filtered]


def write_wav(path: Path, values: list[float]) -> list[float]:
    if max(abs(x) for x in values) >= .99:
        raise ValueError(f"Unexpected master peak: {path.name}")
    data = array.array("h", (round(x*32767) for x in values))
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(data.tobytes())
    return [x/32768 for x in data]


def read_wav(path: Path) -> list[float]:
    with wave.open(str(path), "rb") as source:
        assert source.getsampwidth() == 2 and source.getnchannels() == 1 and source.getframerate() == RATE
        data = array.array("h",source.readframes(source.getnframes()))
    return [x/32768 for x in data]


def rms(values: list[float]) -> float:
    return math.sqrt(sum(x*x for x in values)/max(1,len(values)))


def fft(values: list[float]) -> list[complex]:
    # Bounded analysis window; used for descriptive spectral measurements.
    n = 16384
    source = (values+[0.0]*n)[:n]
    out = [complex(v*.5*(1-math.cos(2*math.pi*i/(n-1)))) for i,v in enumerate(source)]
    j = 0
    for i in range(1,n):
        bit = n >> 1
        while j & bit:
            j ^= bit
            bit >>= 1
        j ^= bit
        if i < j:
            out[i],out[j] = out[j],out[i]
    size = 2
    while size <= n:
        twiddle = cmath.exp(-2j*math.pi/size)
        for start in range(0,n,size):
            w = 1.0+0j
            for k in range(size//2):
                a = out[start+k]
                b = w*out[start+k+size//2]
                out[start+k],out[start+k+size//2] = a+b,a-b
                w *= twiddle
        size *= 2
    return out[:n//2+1]


def metrics(values: list[float]) -> dict:
    peak = max(abs(x) for x in values)
    audible = bandpass(values,250,4000)
    first = round(.12*RATE)
    spec = [abs(x)**2 for x in fft(values)]
    total = max(1e-12,sum(spec))
    bands = {}
    for name,lo,hi in [("sub_0_60",0,60),("body_60_250",60,250),("mid_250_4000",250,4000),("edge_4000_16000",4000,16000)]:
        bands[name] = sum(v for i,v in enumerate(spec) if lo <= i*RATE/16384 < hi)/total
    return dict(peak=peak,rms=rms(values),duration=len(values)/RATE,
                clipped_samples=sum(abs(x)>=32766/32768 for x in values),
                first120ms_rms=rms(values[:first]),
                first120ms_mid_rms=rms(audible[:first]),
                first120ms_mid_per_peak=rms(audible[:first])/peak,
                spectral_energy_16384_hann=bands,
                spectral_centroid_hz=sum(i*RATE/16384*v for i,v in enumerate(spec))/total)


def import_settings(path: Path) -> None:
    # Godot fills remap UID/path on its first import. Explicit PCM settings
    # prevent short effects being compressed to QOA and invalidating bounds.
    target = Path(str(path)+".import")
    if target.exists():
        return
    res_path = "res://"+path.relative_to(GAME).as_posix()
    target.write_text('[remap]\n\nimporter="wav"\ntype="AudioStreamWAV"\n\n[deps]\n\nsource_file="'+res_path+'"\n\n[params]\n\nforce/8_bit=false\nforce/mono=false\nforce/max_rate=false\nforce/max_rate_hz=44100\nedit/trim=false\nedit/normalize=false\nedit/loop_mode=0\nedit/loop_begin=0\nedit/loop_end=-1\ncompress/mode=0\n',encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write-bank",action="store_true")
    args = parser.parse_args()
    DEST.mkdir(parents=True,exist_ok=True)
    report_dir = ROOT / "docs/development/audio/v056"
    report_dir.mkdir(parents=True,exist_ok=True)
    rows = {}
    rendered = {}
    for family in FAMILIES:
        for kind in ("solid","glance"):
            for variant in range(3):
                name = f"contact_{family}_{kind}_{variant}"
                values = write_wav(DEST/(name+".wav"),contact(family,kind,variant))
                rendered[name] = values
    for variant in range(3):
        name = f"lance_break_{variant}"
        rendered[name] = write_wav(DEST/(name+".wav"),lance_break(variant))
    for name,values in rendered.items():
        path = DEST/(name+".wav")
        import_settings(path)
        old = read_wav(OLD/(name+".wav"))
        rows[name] = dict(new=metrics(values),old=metrics(old),sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    # Same digital gain (0.6) for the raw A/B. The peak-matched sequence
    # separately isolates the material/density change from the volume change.
    silence = [0.0]*round(.36*RATE)
    comparison = []
    matched = []
    order = []
    for family in FAMILIES:
        name = f"contact_{family}_solid_0"
        old,new = read_wav(OLD/(name+".wav")),rendered[name]
        comparison += [x*.6 for x in old]+silence+[x*.6 for x in new]+silence
        old_gain = .36/max(abs(y) for y in old)
        new_gain = .36/max(abs(y) for y in new)
        matched += [x*old_gain for x in old]+silence
        matched += [x*new_gain for x in new]+silence
        order += [f"{family}: v050",f"{family}: v056"]
    write_wav(report_dir/"old_new_same_gain.wav",comparison)
    write_wav(report_dir/"old_new_peak_matched.wav",matched)
    report = dict(generator="game/tools/build_impact_audio_v056.py",rate=RATE,
                  source="Original deterministic procedural sound design; no external samples.",
                  listening_verdict="Not performed. Numeric spectral/mix checks are not human listening acceptance.",
                  comparison_order=order,comparison_gain=.6,peak_matched_target=.36,
                  measurement_note="FFT uses first 16384 mono samples with Hann window; broad fractions and centroid are descriptive, not perceived loudness or a material classifier.",rows=rows)
    (report_dir/"asset-analysis.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    (DEST/"README.md").write_text("# DEV-056 impact audio\n\n39 original procedural 44.1kHz mono int16 WAVs. Regenerate with `python game/tools/build_impact_audio_v056.py --write-bank`. Godot import and actual playback validation remain separate. Do not normalize, trim or compress at import: the bank uses the written PCM peaks for conservative grouped playback headroom. These are stylised cues, not recordings or historical acoustic measurements.\n\nMaterial routing and event strength are unchanged; each family has three solid and three glance variants, plus three independent lance-fracture sounds. The old impact_v050 directory is retained. Comparisons and measurements are in docs/development/audio/v056.\n",encoding="utf-8")
    if args.write_bank:
        bank = GAME/"scripts/visual/sound_bank.gd"
        content = bank.read_text(encoding="utf-8")
        table = "const CONTACT_PEAKS = {\n"+",\n".join(f'\t"{name}":{data["new"]["peak"]:.12f}' for name,data in rows.items())+"\n}"
        content,n = re.subn(r"const CONTACT_PEAKS = \{.*?\n\}",table,content,count=1,flags=re.S)
        assert n == 1
        content = content.replace('const IMPACT_ASSET_DIR = "res://assets/audio/impact_v050/"','const IMPACT_ASSET_DIR = "res://assets/audio/impact_v056/"')
        bank.write_text(content,encoding="utf-8",newline="\n")
    print(json.dumps({"assets":len(rows),"clipped":sum(v["new"]["clipped_samples"] for v in rows.values()),"report":str(report_dir/"asset-analysis.json")},ensure_ascii=False))
    for family in ("helmet","plate","shield_wood"):
        pair = rows[f"contact_{family}_solid_0"]
        print(family,json.dumps({which:{k:pair[which][k] for k in ("peak","first120ms_mid_per_peak","spectral_centroid_hz")} for which in ("old","new")}))


if __name__ == "__main__":
    main()
