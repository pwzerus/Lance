# DEV-056 impact audio

39 original procedural 44.1kHz mono int16 WAVs. Regenerate with `python game/tools/build_impact_audio_v056.py --write-bank`. Godot import and actual playback validation remain separate. Do not normalize, trim or compress at import: the bank uses the written PCM peaks for conservative grouped playback headroom. These are stylised cues, not recordings or historical acoustic measurements.

Material routing and event strength are unchanged; each family has three solid and three glance variants, plus three independent lance-fracture sounds. The old impact_v050 directory is retained. Comparisons and measurements are in docs/development/audio/v056.
