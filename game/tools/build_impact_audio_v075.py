"""FEEL-075: extend the existing original procedural bank, retain v056 files.
Material envelopes are game sound design, not measured historical acoustics.
"""
from pathlib import Path
import build_impact_audio_v056 as base

base.DEST = base.GAME / "assets/audio/impact_v075"
base.OLD = base.GAME / "assets/audio/impact_v056"
# More sustained loaded mids; distinct compact helmet, broad plate and dry
# board response. Peak budgets stay unchanged, including simultaneous hits.
base.PROFILES["helmet"].update(pressure=.78, body=1.12, edge=.50, grain=.12)
base.PROFILES["helmet"]["modes"] = ((173,.20,15),(367,.24,10),(617,.18,13),(1093,.11,22),(2137,.045,36))
base.PROFILES["plate"].update(pressure=1.10, body=1.20, edge=.36, grain=.26)
base.PROFILES["plate"]["modes"] = ((103,.22,12),(227,.25,9),(347,.20,10),(571,.12,16),(1249,.05,32))
base.PROFILES["shield_wood"].update(pressure=.92, body=1.12, edge=.34, grain=.46)
base.PROFILES["shield_wood"]["modes"] = ((119,.27,20),(209,.25,23),(383,.18,29),(827,.04,53))

def main():
    import json
    dest=base.DEST
    if dest.exists():
        raise SystemExit("Refusing to overwrite an existing audio bank")
    dest.mkdir(parents=True)
    rows={}
    for family in base.FAMILIES:
        for kind in ("solid","glance"):
            for variant in range(3):
                name=f"contact_{family}_{kind}_{variant}"
                path=dest/(name+".wav")
                values=base.write_wav(path,base.contact(family,kind,variant))
                base.import_settings(path)
                rows[name]={"new":base.metrics(values),"old":base.metrics(base.read_wav(base.OLD/(name+".wav")))}
    # Break sounds are unchanged; copy instead of growing a second generator.
    import shutil
    for variant in range(3):
        path=dest/f"lance_break_{variant}.wav"
        shutil.copyfile(base.OLD/path.name,path)
        base.import_settings(path)
    report=base.ROOT/"docs/development/audio/v075"
    report.mkdir(parents=True,exist_ok=True)
    (report/"asset-analysis.json").write_text(json.dumps(rows,indent=2),encoding="utf-8")
    silence=[0.0]*int(base.RATE*.4)
    comparison=[]
    for family in ("helmet","plate","shield_wood"):
        name=f"contact_{family}_solid_0.wav"
        comparison+=base.read_wav(base.OLD/name)+silence+base.read_wav(dest/name)+silence
    base.write_wav(report/"helmet_plate_shield_before_after.wav",comparison)
    (dest/"README.md").write_text("# FEEL-075\n\nOriginal procedural PCM, derived from build_impact_audio_v056.py. Helmet, plate and wood have separate loaded-body envelopes. Same fixed peak budgets; no new runtime generation. Old bank retained. Numeric checks do not establish human listening acceptance.\n",encoding="utf-8")
    print("FEEL075 audio",len(rows),"contact variants; peaks unchanged")

if __name__=="__main__": main()
