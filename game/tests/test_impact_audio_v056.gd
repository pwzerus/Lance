extends "test_impact_audio_v050.gd"
## Reuse the existing real playback/PCM/group-budget contract. Additional
## measurements isolate spectral/body changes from merely raising the gain.

func _initialize() -> void:
	report_path = "E:/GALUMU/docs/development/logs/v056/audio01.json"
	call_deferred("run")

func projection_metrics(stream: AudioStreamWAV) -> Dictionary:
	if stream.format!=AudioStreamWAV.FORMAT_16_BITS or stream.stereo:
		return {"valid":false}
	var count = mini(stream.data.size()/2,int(stream.mix_rate*.12))
	var low_alpha = 1.0-exp(-TAU*250.0/stream.mix_rate)
	var high_alpha = 1.0-exp(-TAU*4000.0/stream.mix_rate)
	var low = 0.0
	var band = 0.0
	var energy = 0.0
	var peak = 0.0
	var peak_at = 0
	for i in range(count):
		var word = int(stream.data[i*2])|(int(stream.data[i*2+1])<<8)
		if word>=32768:
			word -= 65536
		var value = float(word)/32768.0
		low += low_alpha*(value-low)
		band += high_alpha*((value-low)-band)
		energy += band*band
		if absf(value)>peak:
			peak = absf(value)
			peak_at = i
	return {"valid":true,"mid_rms":sqrt(energy/maxi(1,count)),"mid_per_peak":sqrt(energy/maxi(1,count))/maxf(.000001,peak),"peak":peak,"peak_at_seconds":float(peak_at)/stream.mix_rate}

func material_projection_checks(bank) -> void:
	check(Bank.IMPACT_ASSET_DIR=="res://assets/audio/impact_v056/","Actual bank uses the new authored asset directory")
	for family in ["helmet","plate","shield_wood"]:
		for variant in range(3):
			var cue = "contact_%s_solid_%d" % [family,variant]
			var old_path = "res://assets/audio/impact_v050/"+cue+".wav"
			check(ResourceLoader.exists(old_path),"Previous asset is retained for a matched-peak comparison",{"cue":cue})
			if not ResourceLoader.exists(old_path):
				continue
			var old_stream = load(old_path)
			if not old_stream is AudioStreamWAV:
				check(false,"Previous asset is still a readable WAV",{"cue":cue})
				continue
			var before = projection_metrics(old_stream)
			var after = projection_metrics(bank.streams[cue])
			check(bool(before.valid) and bool(after.valid),"Both comparison streams expose inspectable PCM",{"cue":cue})
			if not bool(before.valid) or not bool(after.valid):
				continue
			check(float(after.mid_per_peak)>float(before.mid_per_peak),"New material body has more 250–4000Hz energy at matched peak, independently of gain",{"cue":cue,"old":before,"new":after})
			check(float(after.peak_at_seconds)<.04,"Solid contact attack is not delayed by the longer body texture",{"cue":cue,"new":after})
			rows.append({"kind":"matched_peak_material_projection","cue":cue,"old":before,"new":after,"note":"One-pole analysis over the first 120ms; a PCM regression observation, not a loudness or perceptual acceptance score."})

func movement_duck_checks(bank) -> void:
	bank.enabled = true
	bank.set_paused(false)
	bank.set_movement_duck(0.0)
	bank.play("hoof",-12.0,.88)
	var first: AudioStreamPlayer = bank.voices[0]
	check(first.has_stream_playback(),"Ducking fixture has a real retained hoof playback")
	bank.set_movement_duck(.6)
	check(absf(first.volume_db-(-22.8))<.0001,"An existing hoof tail follows the contact duck envelope")
	bank.set_movement_duck(.6)
	check(absf(first.volume_db-(-22.8))<.0001,"Repeated duck updates do not accumulate attenuation")
	bank.play("hoof",-17.0,1.06)
	var second: AudioStreamPlayer = bank.voices[1]
	check(second.has_stream_playback() and absf(second.volume_db-(-27.8))<.0001,"A new hoof uses the same active movement duck")
	check(absf(first.pitch_scale-.88)<.0001 and absf(second.pitch_scale-1.06)<.0001,"Movement duck changes no hoof pitch")
	bank.play("contact_helmet_solid_0",-9.0,.96)
	var contact_voice: AudioStreamPlayer = bank.voices[2]
	bank.set_movement_duck(1.0)
	check(absf(first.volume_db-(-30.0))<.0001 and absf(second.volume_db-(-35.0))<.0001,"Full movement duck is bounded at eighteen dB")
	check(absf(contact_voice.volume_db-(-9.0))<.0001,"Movement duck does not attenuate the contact cue")
	bank.set_movement_duck(0.0)
	check(absf(first.volume_db+12.0)<.0001 and absf(second.volume_db+17.0)<.0001,"Returning to zero restores each hoof's own requested gain")
	bank.set_paused(true)
	var count = bank.voices.size()
	var cursor = bank.next_voice
	bank.set_movement_duck(.8)
	bank.play("hoof",-12.0)
	check(first.stream_paused and first.has_stream_playback(),"Ducking does not resume a paused hoof")
	check(bank.voices.size()==count and bank.next_voice==cursor,"Paused duck/new-play request cannot allocate or steal a voice")
	bank.set_paused(false)
	bank.set_enabled(false)
	bank.set_movement_duck(.2)
	bank.play("hoof",-12.0)
	check(bank.voices.size()==count and bank.next_voice==cursor,"Sound-off duck/new-play request cannot allocate or steal a voice")
	for voice in bank.voices:
		check(not voice.has_stream_playback(),"Movement duck never restarts sound-off voices")
	bank.stop_all()
	check(bank.movement_duck==0.0,"Scene cleanup clears the movement duck for a reusable bank")
	bank.music.stream = bank.streams.lute_loop
	rows.append({"kind":"movement_duck","maximum_cut_db":18.0,"same_frame_repeated_set_accumulates":false,"new_and_existing_hoof":true,"contact_gain_unchanged":true,"scope":"Real player gains/paused playbacks; no claim of human mix acceptance."})

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report-path="):
			report_path = arg.trim_prefix("--report-path=")
		elif arg.begins_with("--audio-dir="):
			audio_dir = arg.trim_prefix("--audio-dir=")
	var state = root.get_node_or_null("GameState")
	if state==null or not state.save_path.contains("qa_"):
		push_error("Impact audio checks require -- --test-profile")
		quit(1)
		return
	original_master_db = AudioServer.get_bus_volume_db(0)
	AudioServer.set_bus_volume_db(0,-80.0)
	var bank = Bank.new()
	bank.enabled = false
	bank.process_mode = Node.PROCESS_MODE_ALWAYS
	var started = Time.get_ticks_usec()
	root.add_child(bank)
	var generation_ms = (Time.get_ticks_usec()-started)/1000.0
	selection_checks(bank)
	pcm_checks(bank)
	material_projection_checks(bank)
	group_checks(bank)
	movement_duck_checks(bank)
	await playback_checks(bank)
	bank.stop_all()
	bank.queue_free()
	# AudioServer can retain stopped playbacks until its mixer/update cycle.
	# Let cleanup complete on real time before quitting, also under Dummy.
	await create_timer(.22,true,false,true).timeout
	AudioServer.set_bus_volume_db(0,original_master_db)
	var report = {"passed":failures.is_empty(),"failures":failures,"rows":rows,"initial_generation_ms":generation_ms,"audio_dir":audio_dir,"audio_driver":AudioServer.get_driver_name(),
		"scope":"Actual baked v056 PCM/peak table, old-new matched-peak mid-band and attack comparison, unchanged material routing and finite variants, simultaneous/staggered contact budget, real voice pause/resume, mute and bounded pool. No human listening, loudness/whole-Master hardware measurement or player impact acceptance claim."}
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	else:
		push_error("Impact audio report cannot be written")
		quit(1)
		return
	print("IMPACT_AUDIO_V056 ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"generation_ms":generation_ms}))
	quit(0 if failures.is_empty() else 1)
