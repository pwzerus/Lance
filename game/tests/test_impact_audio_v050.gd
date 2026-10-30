extends SceneTree
## Selection, PCM safety, bounded playback and real pause observations.
## Exported WAVs are audition material, not evidence that anyone liked the sound.
const Bank = preload("res://scripts/visual/sound_bank.gd")
const Catalogue = preload("res://scripts/core/catalogue.gd")
var failures: Array[String] = []
var rows: Array = []
var report_path = "E:/GALUMU/docs/development/logs/v050/audio01.json"
var audio_dir = ""
var original_master_db = 0.0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String, context: Dictionary = {}) -> void:
	if ok:
		return
	if message not in failures:
		failures.append(message)
		push_error(message)
	rows.append({"failure":message,"context":context})

func real_wait(seconds: float) -> void:
	var until = Time.get_ticks_usec()+int(seconds*1000000.0)
	while Time.get_ticks_usec()<until:
		await process_frame

func event(zone: String, impulse: float = 85.0, glanced: bool = false) -> Dictionary:
	return {"type":"hit","zone":zone,"impulse":impulse,"glanced":glanced,"broke":false,"attacker":0,"defender":1}

func selection_checks(bank) -> void:
	var generation_before = Bank.contact_generation_count
	var items = Catalogue.load_items()
	var expected = {"mail_basic":"mail","armor_e1":"brigandine","armor_e2":"plate","armor_e4":"plate","helm_nasal":"helmet","helm_e4":"helmet","shield_basic":"shield_wood","eng_shield_4":"shield_wood"}
	for item_id in expected:
		var item: Dictionary = Catalogue.find(items,item_id)
		check(not item.is_empty(),"Known equipment fixture exists",{"item":item_id})
		if item.is_empty():
			continue
		var zone = "head" if item.slot=="helmet" else ("shield" if item.slot=="shield" else "body")
		var stats: Dictionary = Catalogue.stats(items,{item.slot:item_id})
		var cue: Dictionary = bank.impact_cue(event(zone),stats)
		check(cue.material==expected[item_id],"Actual catalogue equipment maps to its documented audible material",{"item":item_id,"cue":cue})
	var explicit = {"armor_tier":4,"armor_material":"padded"}
	check(bank.impact_cue(event("body"),explicit).material=="padded","Explicit material wins over visual tier (API fixture; no padded catalogue item is claimed)")
	check(bank.impact_cue(event("body"),{"armor_tier":0,"armor_material":"steel"}).material=="plate","Explicit plate metadata wins over a legacy tier")
	check(bank.impact_cue(event("shield"),{"shield_shape":"targe","shield_quality":5}).material=="shield_wood","Shield shape and price do not fabricate a solid-metal shield")
	var shield_slow_event = event("shield",11.0)
	var shield_fast_event = shield_slow_event.duplicate(true)
	shield_fast_event.speed = 900.0
	var shield_slow = bank.impact_cue(shield_slow_event,{})
	var shield_fast = bank.impact_cue(shield_fast_event,{})
	check(shield_fast.strength>=.75 and shield_fast.db>shield_slow.db+3.0,"Audible high-speed shield contact is not reduced to its already-damped damage impulse",{"slow":shield_slow,"fast":shield_fast})
	check(shield_fast_event.impulse==11.0 and shield_fast_event.speed==900.0,"Presentation strength does not increase shield rule damage")
	check(bank.impact_cue(event("miss"),{})=={} and bank.impact_cue({"type":"charge"},{})=={},"Only an actual supported hit selects impact audio")
	check(bank.impact_cue(event("head",NAN),{})=={},"Malformed force cannot select a non-finite cue")
	var stable_event = event("flank",50.0)
	var stable_stats = {"armor_tier":1}
	var before_event = stable_event.duplicate(true)
	var before_stats = stable_stats.duplicate(true)
	var cue = bank.impact_cue(stable_event,stable_stats)
	check(stable_event==before_event and stable_stats==before_stats,"Audio selection does not mutate collision events or equipment stats")
	check(cue.zone=="flank" and cue.material=="brigandine","Flank stays lower torso, not an invented leg target")
	var fresh = Bank.new()
	var names: Array = []
	for index in range(7):
		var choice = fresh.impact_cue(event("body"),{"armor_tier":2})
		names.append(choice.cue)
		check(is_finite(float(choice.db)) and is_finite(float(choice.pitch)) and choice.pitch>0,"Selected playback parameters stay finite")
	check(names[0]==names[3] and names[0]!=names[1] and names[1]!=names[2] and names[0]!=names[2],"Variants are a bounded three-choice cycle")
	check(fresh.voices.is_empty(),"Selecting a cue does not create or play an audio node")
	var normal = fresh.impact_cue(event("body",70,false),{"armor_tier":2})
	var glanced = fresh.impact_cue(event("body",70,true),{"armor_tier":2})
	check(normal.kind=="solid" and glanced.kind=="glance" and normal.cue!=glanced.cue,"Glancing contact has its own texture, not just a quieter solid hit")
	check(absf(normal.strength-glanced.strength)<.000001 and glanced.db<normal.db,"Glance texture and gain provide the weak scrape without double-reducing contact strength")
	var broken_event = event("body")
	broken_event.broke = true
	check(fresh.break_cue(broken_event).cue.begins_with("lance_break_"),"Broken wood has a separate finite cue family")
	check(fresh.break_cue(event("body"))=={},"An intact lance does not select a crack")
	var landing = fresh.landing_cue(400.0)
	check(landing.cue.begins_with("contact_padded_solid_") and landing.kind=="landing" and landing.pitch<.84,"Ground landing reuses a lower soft-body response, never a hoof")
	check(fresh.landing_cue(NAN)=={},"Non-finite landing speed cannot select playback")
	check(Bank.contact_generation_count==generation_before,"Collision/landing cue selection never generates PCM in the impact frame")
	fresh.free()

func pcm_metrics(stream: AudioStreamWAV) -> Dictionary:
	# AudioStreamWAV.data is encoded data for QOA/ADPCM, not 16-bit samples.
	# Never produce fake peak/RMS numbers or try WAV export for those codecs.
	if stream.format!=AudioStreamWAV.FORMAT_16_BITS or stream.stereo or stream.mix_rate<=0:
		return {"valid_pcm":false,"format":stream.format,"stereo":stream.stereo,"mix_rate":stream.mix_rate}
	var data = stream.data
	if data.size()%2!=0:
		return {"valid_pcm":false,"format":stream.format,"reason":"unaligned 16-bit PCM bytes"}
	var count = data.size()/2
	var peak = 0.0
	var energy = 0.0
	var clipped = 0
	for i in range(count):
		var value = int(data[i*2])|(int(data[i*2+1])<<8)
		if value>=32768:
			value -= 65536
		var normalized = float(value)/32768.0
		peak = maxf(peak,absf(normalized))
		energy += normalized*normalized
		if absi(value)>=32766:
			clipped += 1
	return {"valid_pcm":true,"peak":peak,"rms":sqrt(energy/maxi(1,count)),"clipped_samples":clipped,"duration":float(count)/stream.mix_rate,"sha256":data.hex_encode().sha256_text()}

func pcm_checks(bank) -> void:
	var hashes: Dictionary = {}
	var comparisons = {"solid":PackedByteArray(),"glance":PackedByteArray()}
	var silence = PackedByteArray()
	silence.resize(int(.28*Bank.CONTACT_RATE)*2)
	if not audio_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(audio_dir)
	for family in Bank.IMPACT_FAMILIES:
		for kind in ["solid","glance"]:
			for variant in range(Bank.IMPACT_VARIANTS):
				var name_value = "contact_%s_%s_%d" % [family,kind,variant]
				var stream: AudioStreamWAV = bank.streams[name_value]
				check(stream.get_meta("audio_origin","")=="baked","Shipped contact sample is loaded from its baked asset",{"cue":name_value,"origin":stream.get_meta("audio_origin","")})
				var metrics = pcm_metrics(stream)
				check(stream.mix_rate==44100 and stream.format==AudioStreamWAV.FORMAT_16_BITS and not stream.stereo,"Contact streams use inspectable 44.1kHz mono PCM",{"cue":name_value})
				if not metrics.valid_pcm:
					rows.append({"cue":name_value,"unsupported_pcm_metrics":metrics})
					continue
				check(metrics.peak>.03 and metrics.peak<.90 and metrics.rms>.005 and metrics.clipped_samples==0,"Contact PCM is non-silent and has unclipped headroom",{"cue":name_value,"metrics":metrics})
				check(Bank.CONTACT_PEAKS.has(name_value) and absf(float(Bank.CONTACT_PEAKS.get(name_value,0.0))-float(metrics.peak))<.00000001,"Contact group peak table matches its actual imported PCM",{"cue":name_value,"measured":metrics.peak,"table":Bank.CONTACT_PEAKS.get(name_value)})
				check(not hashes.has(metrics.sha256),"Material/kind/variant waveforms are actually different",{"cue":name_value})
				hashes[metrics.sha256] = name_value
				rows.append({"cue":name_value,"metrics":metrics})
				if variant==0:
					var comparison_data: PackedByteArray = comparisons[kind]
					comparison_data.append_array(stream.data)
					comparison_data.append_array(silence)
					comparisons[kind] = comparison_data
				if not audio_dir.is_empty():
					check(stream.save_to_wav(audio_dir+"/"+name_value+".wav")==OK,"Audition WAV exports",{"cue":name_value})
	for variant in range(Bank.IMPACT_VARIANTS):
		var name_value = "lance_break_%d" % variant
		var stream: AudioStreamWAV = bank.streams[name_value]
		check(stream.get_meta("audio_origin","")=="baked","Shipped wood crack is loaded from its baked asset",{"cue":name_value})
		var metrics = pcm_metrics(stream)
		check(bool(metrics.valid_pcm),"Wood crack uses inspectable mono 16-bit PCM",{"cue":name_value,"format":stream.format})
		if not metrics.valid_pcm:
			rows.append({"cue":name_value,"unsupported_pcm_metrics":metrics})
			continue
		check(metrics.peak>.03 and metrics.peak<.90 and metrics.clipped_samples==0,"Wood crack stays non-silent and unclipped",{"cue":name_value,"metrics":metrics})
		check(Bank.CONTACT_PEAKS.has(name_value) and absf(float(Bank.CONTACT_PEAKS.get(name_value,0.0))-float(metrics.peak))<.00000001,"Wood crack group peak table matches its actual imported PCM",{"cue":name_value,"measured":metrics.peak,"table":Bank.CONTACT_PEAKS.get(name_value)})
		rows.append({"cue":name_value,"metrics":metrics})
		if not audio_dir.is_empty():
			check(stream.save_to_wav(audio_dir+"/"+name_value+".wav")==OK,"Break audition WAV exports")
	if not audio_dir.is_empty():
		for kind in comparisons:
			if comparisons[kind].is_empty():
				check(false,"No valid PCM is available for the material comparison",{"kind":kind})
				continue
			var comparison = Bank._pcm_stream(comparisons[kind],Bank.CONTACT_RATE)
			check(comparison.save_to_wav(audio_dir+"/compare_"+kind+"_materials.wav")==OK,"Fixed-gain material comparison exports")
	rows.append({"comparison_order":Bank.IMPACT_FAMILIES,"comparison_note":"Raw streams at equal fixed gain, 280ms silence between materials; not the final gameplay mix or a listening verdict."})

func cue_group_bound(cues: Array) -> float:
	var result = 0.0
	for cue in cues:
		result += Bank.cue_peak_bound(str(cue.cue))*db_to_linear(float(cue.db))
	return result

func active_contact_bound(bank) -> float:
	var result = 0.0
	for voice in bank.voices:
		var cue = str(voice.get_meta("sfx_cue",""))
		if voice.has_stream_playback() and Bank._group_voice(cue):
			result += Bank.cue_peak_bound(cue)*db_to_linear(voice.volume_db)
	return result

func group_checks(bank) -> void:
	bank.enabled = true
	bank.music.stop()
	# Godot 4.5.1's four-point cubic has two negative outer coefficients.
	# Their absolute sum is 1+mu-mu^2, at most 1.25. A raw-PCM-only peak
	# bound would therefore not cover arbitrary pitched/resampled playback.
	for index in range(101):
		var mu = index/100.0
		var h11 = mu*mu*(mu-1.0)
		var z = mu*mu-h11
		var h01 = z-h11
		var h10 = mu-z
		var coefficient_sum = absf(-.5*h10)+absf(1.0-h01-.5*h11)+absf(h01+.5*h10)+absf(.5*h11)
		check(coefficient_sum*32768.0/32767.0<=Bank.CONTACT_RESAMPLE_BOUND,"Contact headroom includes Godot cubic resampling and PCM scale bounds")
	var batch: Array = []
	# A simultaneous two-rider hit can yield two impacts plus two wood cracks.
	# Explicit loud gains exercise the actual shared budget, not only the usual
	# quieter cue settings that might never need reduction.
	for cue in ["contact_padded_solid_2","contact_helmet_solid_0","lance_break_0","lance_break_1"]:
		batch.append({"cue":cue,"db":0.0,"pitch":.96})
	var original = batch.duplicate(true)
	var node_count = bank.get_child_count()
	var limited: Array = bank.limit_contact_group(batch)
	check(limited.size()==4 and cue_group_bound(limited)<=Bank.CONTACT_GROUP_BUDGET+.000001,"Two simultaneous impacts plus two cracks share one bounded contact budget",{"before_bound":cue_group_bound(batch),"after_bound":cue_group_bound(limited),"limited":limited})
	check(batch==original and bank.get_child_count()==node_count and bank.voices.is_empty(),"Group mixing copies cue data and allocates no playback nodes")
	var common_cut = float(limited[0].db)-float(batch[0].db)
	for index in range(limited.size()):
		check(absf(float(limited[index].db)-float(batch[index].db)-common_cut)<.000001,"Group attenuation preserves relative material and force gains")
	for cue in limited:
		bank.play(str(cue.cue),float(cue.db),float(cue.pitch))
	var first_active_bound = active_contact_bound(bank)
	check(first_active_bound>0.0,"Contact tail budget fixture contains actual retained audio playbacks")
	# No wall-clock wait is needed: retained active playbacks use a full-peak
	# bound, which is deliberately stricter than measuring an arbitrary phase.
	var delayed: Array = bank.limit_contact_group(batch)
	var tails_after = active_contact_bound(bank)
	check(tails_after+cue_group_bound(delayed)<=Bank.CONTACT_GROUP_BUDGET+.000001,"A delayed second contact group includes and attenuates existing tails",{"existing_before":first_active_bound,"existing_after":tails_after,"incoming_after":cue_group_bound(delayed)})
	check(tails_after<first_active_bound and batch==original,"Tail attenuation does not silently rewrite pending event cues")
	for cue in delayed:
		bank.play(str(cue.cue),float(cue.db),float(cue.pitch))
	check(bank.voices.size()<=Bank.MAX_VOICES and active_contact_bound(bank)<=Bank.CONTACT_GROUP_BUDGET+.000001,"Actual retained contact voices respect the shared peak bound")
	rows.append({"kind":"contact_group_budget","budget":Bank.CONTACT_GROUP_BUDGET,"first_bound":first_active_bound,"delayed_existing_bound":tails_after,"combined_bound":active_contact_bound(bank),"scope":"Conservative contact-only peak sum; music, wind and hoof streams require the remaining mix headroom. This is not a hardware loudness or whole-Master clipping measurement."})
	bank.stop_all()
	# Restore the reusable music stream after stop_all's explicit release.
	bank.music.stream = bank.streams.lute_loop
	var quiet: Array = [{"cue":"contact_plate_solid_0","db":-18.0,"pitch":1.0}]
	var untouched: Array = bank.limit_contact_group(quiet)
	check(absf(float(untouched[0].db)+18.0)<.000001,"Quiet isolated contact is never boosted or needlessly attenuated")
	bank.voices.clear()
	for child in bank.get_children():
		if child is AudioStreamPlayer and child!=bank.music:
			child.free()

func playback_checks(bank) -> void:
	var generation_before = Bank.contact_generation_count
	bank.enabled = true
	bank.music.stop()
	for index in range(20):
		bank.play("horn",-80.0)
	check(bank.voices.size()==Bank.MAX_VOICES,"Playback pool stays bounded at twelve voices")
	var live: AudioStreamPlayer = bank.voices[0]
	var driver = AudioServer.get_driver_name()
	var mix_rate = AudioServer.get_mix_rate()
	# Official 4.5.1 AudioDriverDummy uses a 4096-frame thread buffer.
	# At 44100Hz an 80ms wait may contain ZERO mixes. Observe at least two
	# backend blocks rather than weakening the pause/resume assertion.
	var dummy_block = 4096.0/maxf(1.0,mix_rate) if driver=="Dummy" else 0.0
	await real_wait(maxf(.04,dummy_block*2+.02))
	var observations: Array = []
	observations.append({"stage":"before_pause","ticks_usec":Time.get_ticks_usec(),"position":live.get_playback_position(),"active":live.has_stream_playback(),"paused":live.stream_paused})
	bank.set_paused(true)
	var count = bank.voices.size()
	var cursor = bank.next_voice
	var before = live.get_playback_position()
	observations.append({"stage":"immediate_pause","ticks_usec":Time.get_ticks_usec(),"position":before,"active":live.has_stream_playback(),"paused":live.stream_paused})
	bank.play("contact_plate_solid_0",-80)
	await real_wait(.14)
	observations.append({"stage":"after_pause_wait","ticks_usec":Time.get_ticks_usec(),"position":live.get_playback_position(),"active":live.has_stream_playback(),"paused":live.stream_paused})
	check(bank.playback_paused and live.has_stream_playback() and live.stream_paused,"An active long voice remains paused (idle slots are not required to preserve pause flags)")
	check(absf(live.get_playback_position()-before)<.04,"Paused live playhead stays within mix-granularity tolerance")
	check(bank.voices.size()==count and bank.next_voice==cursor,"Paused play cannot allocate or steal a voice")
	bank.set_paused(false)
	observations.append({"stage":"immediate_resume","ticks_usec":Time.get_ticks_usec(),"position":live.get_playback_position(),"active":live.has_stream_playback(),"paused":live.stream_paused})
	var resume_seconds = maxf(.08,dummy_block*2+.025)
	await real_wait(resume_seconds)
	var after = live.get_playback_position()
	observations.append({"stage":"after_resume_wait","ticks_usec":Time.get_ticks_usec(),"position":after,"active":live.has_stream_playback(),"paused":live.stream_paused})
	check(not live.stream_paused and after>before+.025,"Resume continues the retained long voice",{"driver":driver,"resume_wait":resume_seconds,"before":before,"after":after})
	rows.append({"kind":"playback_pause_resume","audio_driver":driver,"mix_rate":mix_rate,"dummy_block_seconds":dummy_block,"requested_resume_seconds":resume_seconds,"observations":observations})
	check(not bank.music.has_stream_playback(),"Resuming does not restart manually stopped music")
	check(Bank.contact_generation_count==generation_before,"Actual cue playback does not synthesize in an impact frame")
	bank.set_enabled(false)
	bank.play("contact_plate_solid_0")
	for voice in bank.voices:
		check(not voice.has_stream_playback(),"Sound-off stops all voices and blocks new playback")
	bank.stop_all()
	for voice in bank.voices:
		check(voice.stream==null,"Exit-style cleanup releases stream references")
	var fallback_before = Bank.contact_generation_count
	var fallback = Bank._load_impact_stream("qa_missing_asset_fixture","padded","solid",0)
	check(fallback is AudioStreamWAV and fallback.get_meta("audio_origin","")=="synth_fallback" and Bank.contact_generation_count==fallback_before+1,"A genuinely missing asset has an explicit warm-up synthesis fallback")
	rows.append({"kind":"missing_asset_fixture","generated_samples":Bank.contact_generation_count-fallback_before,"note":"Intentional nonexistent QA path; not part of the shipped cue bank or impact playback."})

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
	group_checks(bank)
	await playback_checks(bank)
	bank.queue_free()
	await process_frame
	await process_frame
	AudioServer.set_bus_volume_db(0,original_master_db)
	var report = {"passed":failures.is_empty(),"failures":failures,"rows":rows,"initial_generation_ms":generation_ms,"audio_dir":audio_dir,"audio_driver":AudioServer.get_driver_name(),
		"scope":"Real catalogue material fallback and explicit material fixtures, speed-aware contact strength distinct from damage, pure cue selection, bounded variants, original-event immutability, actual PCM/headroom and simultaneous/staggered contact-group peak budget, optional fixed-gain audition WAVs, live long-voice pause/resume, mute and bounded pool. No claim of human listening, whole-Master mix measurement, hardware loudness, real recorded material or player impact satisfaction."}
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	else:
		push_error("Impact audio report cannot be written")
		quit(1)
		return
	print("IMPACT_AUDIO_V050 ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"generation_ms":generation_ms}))
	quit(0 if failures.is_empty() else 1)
