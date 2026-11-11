extends "test_contact_mix_v056.gd"
const Mix = preload("res://scripts/core/audio_mix.gd")

func record_channel(tag: String, channel: StringName, settings: Dictionary) -> Dictionary:
	battle_bank.stop_all()
	wind.stop()
	Mix.apply(settings)
	await real_wait(.25)
	recorder.set_recording_active(true)
	if channel==Mix.MUSIC:
		# stop_all intentionally releases streams during scene teardown.
		battle_bank.music.stream=battle_bank.streams.contact_helmet_solid_0
		battle_bank.music.play()
	elif channel==Mix.AMBIENCE:
		wind.play()
	else:
		battle_bank.play("contact_helmet_solid_0",-6.0,1.0)
	await real_wait(1.0)
	battle_bank.stop_all();wind.stop()
	await real_wait(.2)
	recorder.set_recording_active(false)
	await real_wait(.10)
	var path=run_dir+"/"+tag+".wav"
	check(recorder.get_recording().save_to_wav(path)==OK,"Could not save channel recording")
	var measured=read_pcm_file(path)
	check(measured.get("valid",false),"Unreadable actual recorded audio")
	check(AudioServer.is_bus_mute(0),"Recording unmuted hardware-facing Master")
	rows.append({"case":tag,"channel":channel,"settings":settings.duplicate(true),"metrics":measured})
	return measured

func run() -> void:
	var state=root.get_node("GameState")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--run-dir="):run_dir=arg.trim_prefix("--run-dir=")
	if run_dir.is_empty() or DirAccess.dir_exists_absolute(run_dir) or not str(state.save_path).contains("qa_"):quit(2);return
	DirAccess.make_dir_recursive_absolute(run_dir)
	AudioServer.set_bus_mute(0,true)
	recorder=AudioEffectRecord.new();recorder.format=AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0,recorder)
	battle_bank=Bank.new();battle_bank.enabled=false;root.add_child(battle_bank);battle_bank.enabled=true
	# The same production PCM in each channel isolates routing/gain from
	# different song/impact envelopes. Music and effect players are real bank nodes.
	battle_bank.music.stream=battle_bank.streams.contact_helmet_solid_0
	battle_bank.music.volume_db=-6.0
	wind=AudioStreamPlayer.new();wind.stream=battle_bank.streams.contact_helmet_solid_0;wind.bus=Mix.AMBIENCE;wind.volume_db=-6.0;root.add_child(wind)
	var settings={"sound":true,"master_volume":1.0,"music_volume":1.0,"effects_volume":1.0,"ambience_volume":1.0}
	var base=await record_channel("01_effects_full",Mix.EFFECTS,settings)
	check(float(base.get("peak",0))>.05,"Full effect recorded silence")
	settings.effects_volume=.5
	var half=await record_channel("02_effects_half",Mix.EFFECTS,settings)
	check(absf(float(half.get("peak",0))/maxf(.0001,float(base.get("peak",0)))-.5)<.025,"Effect half volume was not half actual amplitude")
	settings.effects_volume=0
	var silent=await record_channel("03_effects_muted",Mix.EFFECTS,settings)
	check(float(silent.get("peak",1))<.0001,"Zero effects volume leaked sound")
	var music=await record_channel("04_music_independent",Mix.MUSIC,settings)
	check(float(music.get("peak",0))>.05,"Muting effects incorrectly muted music")
	settings.music_volume=0
	var music_off=await record_channel("05_music_muted",Mix.MUSIC,settings)
	check(float(music_off.get("peak",1))<.0001,"Zero music volume leaked sound")
	var ambience=await record_channel("06_ambience_independent",Mix.AMBIENCE,settings)
	check(float(ambience.get("peak",0))>.05,"Music/effect mute incorrectly muted ambience")
	settings.ambience_volume=0
	var wind_off=await record_channel("07_ambience_muted",Mix.AMBIENCE,settings)
	check(float(wind_off.get("peak",1))<.0001,"Zero ambience volume leaked sound")
	settings.effects_volume=1.0;settings.master_volume=.5
	var master_half=await record_channel("08_master_half",Mix.EFFECTS,settings)
	check(absf(float(master_half.get("peak",0))/maxf(.0001,float(base.get("peak",0)))-.5)<.025,"Master volume did not attenuate actual effects")
	settings.sound=false
	var off=await record_channel("09_sound_off",Mix.EFFECTS,settings)
	check(float(off.get("peak",1))<.0001,"Sound toggle left actual output")
	await cleanup()
	FileAccess.open(run_dir+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"driver":AudioServer.get_driver_name(),"scope":"Real AudioEffectRecord before final Master mute. Actual routed PCM checks, no OS audio, microphone or human listening; not a subjective quality assessment."},"\t"))
	print("MIX087 ",failures)
	quit(0 if failures.is_empty() else 1)
