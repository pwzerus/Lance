extends SceneTree
## Actual AudioServer mix recording, with Master muted AFTER its effects.
## Authored event schedules exercise production SoundBank/Exchange; this is
## not a collision test, microphone recording, OS input, or human listening.
const Bank = preload("res://scripts/visual/sound_bank.gd")
const Exchange = preload("res://scripts/visual/exchange_director.gd")
var run_dir = ""
var failures: Array[String] = []
var rows: Array = []
var battle_bank: SoundBank
var ui_bank: SoundBank
var wind: AudioStreamPlayer
var recorder: AudioEffectRecord
var saved_mute = false
var saved_volume = 0.0
var saved_bypass = false
var original_effect_count = 0
var master_modified = false

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

func hit(zone: String, impulse: float = 85.0, broke: bool = false, attacker: int = 0) -> Dictionary:
	return {"type":"hit","zone":zone,"impulse":impulse,"speed":960.0,"glanced":false,
		"broke":broke,"attacker":attacker,"defender":1-attacker,"position":Vector2(0,-210),"damage":10.0}

func fixture_cases() -> Array:
	return [
		{"id":"00_muted_record_probe","probe":true,"duration":.38},
		{"id":"01_helmet_running_mix","events":[hit("head")],"duration":1.0},
		{"id":"02_plate_running_mix","events":[hit("body")],"duration":1.0},
		{"id":"03_wood_shield_running_mix","events":[hit("shield",11.0)],"duration":1.0},
		{"id":"04_double_break_win_boundary","events":[hit("head",85,true,0),hit("body",85,true,1)],"ui":"win","duration":1.95},
		{"id":"05_double_break_lose_boundary","events":[hit("head",85,true,0),hit("body",85,true,1)],"ui":"lose","duration":1.65},
		{"id":"06_staggered_contacts_and_click","events":[hit("body",85,true,0)],"second_events":[hit("shield",11,true,1)],"ui":"click","duration":1.15}
	]

func read_pcm_file(path: String) -> Dictionary:
	# Analyze the WAV that was actually written, not a synthetic peak bound.
	var bytes = FileAccess.get_file_as_bytes(path)
	if bytes.size()<44 or bytes.slice(0,4).get_string_from_ascii()!="RIFF" or bytes.slice(8,12).get_string_from_ascii()!="WAVE":
		return {"valid":false,"reason":"Not a readable RIFF/WAVE"}
	var offset = 12
	var channels = 0
	var bits = 0
	var rate = 0
	var encoding = 0
	var pcm = PackedByteArray()
	while offset+8<=bytes.size():
		var tag = bytes.slice(offset,offset+4).get_string_from_ascii()
		var size = int(bytes.decode_u32(offset+4))
		var begin = offset+8
		if size<0 or begin+size>bytes.size():
			return {"valid":false,"reason":"Truncated WAV chunk"}
		if tag=="fmt " and size>=16:
			encoding = bytes.decode_u16(begin)
			channels = bytes.decode_u16(begin+2)
			rate = bytes.decode_u32(begin+4)
			bits = bytes.decode_u16(begin+14)
		elif tag=="data":
			pcm = bytes.slice(begin,begin+size)
		offset = begin+size+(size%2)
	if encoding!=1 or bits!=16 or channels not in [1,2] or rate<=0 or pcm.is_empty() or pcm.size()%(channels*2)!=0:
		return {"valid":false,"reason":"Expected aligned mono/stereo 16-bit PCM","encoding":encoding,"bits":bits,"channels":channels,"rate":rate}
	var sample_count = int(pcm.size()/2)
	var peak = 0.0
	var energy = 0.0
	var clipped = 0
	var near_full_scale = 0
	var peak_channels = [0.0,0.0]
	for i in range(sample_count):
		var value = int(pcm.decode_u16(i*2))
		if value>=32768:
			value -= 65536
		var normalized = float(value)/32768.0
		var magnitude = absf(normalized)
		peak = maxf(peak,magnitude)
		peak_channels[i%channels] = maxf(peak_channels[i%channels],magnitude)
		energy += normalized*normalized
		if absi(value)>=32766:
			clipped += 1
		if magnitude>=.98:
			near_full_scale += 1
	return {"valid":true,"channels":channels,"rate":rate,"bits":bits,"frames":int(sample_count/channels),
		"duration":float(sample_count)/(channels*rate),"peak":peak,"peak_dbfs":linear_to_db(maxf(.0000001,peak)),
		"peak_channels":peak_channels,"rms":sqrt(energy/maxi(1,sample_count)),"clipped_samples":clipped,
		"near_full_scale_samples":near_full_scale,"sha256":FileAccess.get_sha256(path)}

func submit_events(events: Array, director, context: Dictionary) -> Array:
	director.notify_contacts(events)
	var state: Dictionary = director.advance(0.0,context)
	battle_bank.set_movement_duck(float(state.audio_duck))
	var cues: Array = []
	for event in events:
		# These explicit materials represent current catalogue categories;
		# the synthetic event schedule does not claim a historical experiment.
		var stats = {"helmet_material":"steel","armor_material":"plate","shield_material":"wood"}
		cues.append(battle_bank.impact_cue(event,stats))
		if bool(event.broke):
			cues.append(battle_bank.break_cue(event))
	var limited: Array = battle_bank.limit_contact_group(cues)
	for cue in limited:
		battle_bank.play(cue.cue,cue.db,cue.pitch)
	return limited

func record_case(spec: Dictionary) -> void:
	battle_bank.stop_all()
	ui_bank.stop_all()
	wind.stop()
	# Flush old voices from the real mixer before opening a fresh recording.
	await real_wait(.23)
	check(AudioServer.is_bus_mute(0),"Master remains muted before every recording")
	recorder.set_recording_active(true)
	check(recorder.is_recording_active(),"The installed Record effect starts recording")
	var director = Exchange.new()
	var context = {"phase":"charge","pass_id":1,"gap":1000.0,"reach":282.0,"closing_speed":960.0,"slow_motion":true}
	var start = Time.get_ticks_usec()
	var previous = start
	var first_sent = false
	var second_sent = false
	var hoof_index = 0
	var events_played: Array = []
	var hoof_times = [0.0,.055,.125,.19,.22,.285,.37,.455,.57,.69]
	var maximum_muted_meter = -200.0
	if bool(spec.get("probe",false)):
		battle_bank.play("hoof",-12.0,.88)
	else:
		wind.volume_db = -12.0
		wind.pitch_scale = 1.22
		wind.play()
	while true:
		var now = Time.get_ticks_usec()
		var elapsed = float(now-start)/1000000.0
		if elapsed>=float(spec.duration):
			break
		var dt = float(now-previous)/1000000.0
		previous = now
		if not bool(spec.get("probe",false)):
			var fresh_batch = false
			if elapsed>=.22 and not first_sent:
				var limited = submit_events(spec.events,director,context)
				events_played.append({"actual_seconds":elapsed,"batch":1,"cues":limited})
				first_sent = true
				fresh_batch = true
				if spec.has("ui"):
					ui_bank.play(spec.ui,-16.0 if spec.ui=="click" else -9.0)
					events_played.append({"actual_seconds":elapsed,"ui":spec.ui,"note":"Deliberate same-frame boundary stress; normal results appear later."})
			if elapsed>=.285 and spec.has("second_events") and not second_sent:
				var limited = submit_events(spec.second_events,director,context)
				events_played.append({"actual_seconds":elapsed,"batch":2,"cues":limited})
				second_sent = true
				fresh_batch = true
			# Like Battle, show the new contact at age zero rather than consuming
			# the previous frame's elapsed time before its first audible frame.
			var state: Dictionary = director.advance(0.0 if fresh_batch else dt,context)
			var duck = float(state.audio_duck)
			battle_bank.set_movement_duck(duck)
			wind.volume_db = lerpf(wind.volume_db,-12.0-duck*21.0,1.0-exp(-minf(dt,.1)*(24.0 if duck>.3 else 7.0)))
			wind.pitch_scale = lerpf(wind.pitch_scale,1.22*lerpf(1.0,.62,duck),1.0-exp(-minf(dt,.1)*12.0))
			while hoof_index<hoof_times.size() and elapsed>=float(hoof_times[hoof_index]):
				var far = hoof_index%2==1
				battle_bank.play("hoof",-17.0 if far else -12.0,.88 if hoof_index%4<2 else 1.06)
				hoof_index += 1
		maximum_muted_meter = maxf(maximum_muted_meter,maxf(AudioServer.get_bus_peak_volume_left_db(0,0),AudioServer.get_bus_peak_volume_right_db(0,0)))
		await process_frame
	wind.stop()
	battle_bank.stop_all()
	ui_bank.stop_all()
	# Keep recording a short clean tail; then allow its worker to settle.
	await real_wait(.12)
	recorder.set_recording_active(false)
	await real_wait(.04)
	var recording = recorder.get_recording()
	check(recording is AudioStreamWAV,"Master recording returns a WAV",{"case":spec.id})
	if not recording is AudioStreamWAV:
		return
	var path = run_dir.path_join(str(spec.id)+".wav")
	if FileAccess.file_exists(path):
		check(false,"Refuse to overwrite an existing recording",{"path":path})
		return
	var save_error = recording.save_to_wav(path)
	check(save_error==OK,"Master WAV saves successfully",{"case":spec.id,"error":save_error})
	var measured = read_pcm_file(path)
	check(bool(measured.valid),"The saved Master WAV is readable PCM",{"case":spec.id,"metrics":measured})
	if bool(measured.valid):
		check(float(measured.duration)>.2 and float(measured.peak)>.01 and float(measured.rms)>.0001,"Muted Master effect captured real non-silent signal",{"case":spec.id,"metrics":measured})
		check(int(measured.clipped_samples)==0,"The recorded fixture has no full-scale clipped PCM samples",{"case":spec.id,"metrics":measured})
		check(maximum_muted_meter<=-90.0 and AudioServer.is_bus_mute(0),"Hardware-facing Master stays silent while pre-mute capture is non-silent",{"case":spec.id,"maximum_muted_meter_db":maximum_muted_meter})
	rows.append({"case":spec,"wav":path,"metrics":measured,"master_muted":AudioServer.is_bus_mute(0),
		"maximum_post_mute_meter_db":maximum_muted_meter,"events":events_played,
		"scope":"Actual pre-mute Master mix of authored production cues and representative movement/UI layers, not a full match or human listening verdict."})
	print("CONTACT_MIX_CASE ",spec.id," ",JSON.stringify(measured))

func cleanup() -> void:
	if is_instance_valid(wind):
		wind.stop()
		wind.stream = null
		wind.queue_free()
	for bank in [battle_bank,ui_bank]:
		if is_instance_valid(bank):
			bank.stop_all()
			bank.queue_free()
	if recorder:
		recorder.set_recording_active(false)
	await real_wait(.23)
	if recorder:
		for index in range(AudioServer.get_bus_effect_count(0)-1,-1,-1):
			if AudioServer.get_bus_effect(0,index)==recorder:
				AudioServer.remove_bus_effect(0,index)
	if master_modified:
		AudioServer.set_bus_volume_db(0,saved_volume)
		AudioServer.set_bus_bypass_effects(0,saved_bypass)
		AudioServer.set_bus_mute(0,saved_mute)
		check(AudioServer.get_bus_effect_count(0)==original_effect_count,"Temporary recorder is removed after the fixture")

func run() -> void:
	var state = root.get_node_or_null("GameState")
	if state==null or not str(state.save_path).contains("qa_"):
		push_error("Contact mix recording requires -- --test-profile")
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--run-dir="):
			run_dir = arg.trim_prefix("--run-dir=").simplify_path()
	if run_dir.is_empty() or not run_dir.is_absolute_path() or DirAccess.dir_exists_absolute(run_dir) or FileAccess.file_exists(run_dir):
		push_error("Provide a new absolute --run-dir; existing output directories are never overwritten")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(run_dir)!=OK:
		push_error("Could not create new mix recording directory")
		quit(2)
		return
	saved_mute = AudioServer.is_bus_mute(0)
	saved_volume = AudioServer.get_bus_volume_db(0)
	saved_bypass = AudioServer.is_bus_bypassing_effects(0)
	original_effect_count = AudioServer.get_bus_effect_count(0)
	master_modified = true
	# No microphone, system-volume change or persistent bus-layout write.
	AudioServer.set_bus_mute(0,true)
	AudioServer.set_bus_volume_db(0,0.0)
	AudioServer.set_bus_bypass_effects(0,false)
	recorder = AudioEffectRecord.new()
	recorder.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0,recorder,original_effect_count)
	battle_bank = Bank.new()
	battle_bank.enabled = false
	root.add_child(battle_bank)
	battle_bank.enabled = true
	ui_bank = Bank.new()
	ui_bank.enabled = false
	root.add_child(ui_bank)
	ui_bank.enabled = true
	wind = AudioStreamPlayer.new()
	wind.stream = battle_bank.streams.wind_loop
	root.add_child(wind)
	await real_wait(.23)
	for spec in fixture_cases():
		await record_case(spec)
	await cleanup()
	var report = {"passed":failures.is_empty(),"failures":failures,"driver":AudioServer.get_driver_name(),
		"mix_rate":AudioServer.get_mix_rate(),"run_dir":run_dir,"rows":rows,
		"record_position":"Last Master effect; effects run before the Master volume/mute stage in Godot 4.5.1.",
		"sources":["https://docs.godotengine.org/en/4.5/classes/class_audioeffectrecord.html","https://github.com/godotengine/godot/blob/4.5.1-stable/servers/audio_server.cpp#L507-L570"],
		"scope":"Actual AudioEffectRecord Master output before final mute, saved WAV PCM read-back for these representative/explicit stress schedules. Not every possible gameplay mix, LUFS, hardware loudness, true-peak certification, collision verification or human listening."}
	var report_path = run_dir.path_join("report.json")
	if FileAccess.file_exists(report_path):
		push_error("Refuse to overwrite mix report")
		quit(2)
		return
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	if not file:
		push_error("Cannot save mix report")
		quit(2)
		return
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("CONTACT_MIX_V056 ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"run_dir":run_dir}))
	quit(0 if failures.is_empty() else 1)
