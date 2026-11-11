extends "test_impact_audio_v050.gd"
## Keep the existing PCM, cue selection, pool and pause assertions unchanged.
## A headless test can finish several scene frames before Dummy mixes once.
func playback_checks(bank)->void:
 await super.playback_checks(bank)
 var block=4096.0/maxf(1.0,AudioServer.get_mix_rate()) if AudioServer.get_driver_name()=="Dummy" else .02
 await real_wait(maxf(.08,block*3.0+.02))
 rows.append({"kind":"qa_teardown_drain","seconds":maxf(.08,block*3.0+.02),"scope":"Wait after already-stopped test voices for backend release. No change to shipped SoundBank/Main or assertions."})
