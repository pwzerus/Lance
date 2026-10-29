extends SceneTree
## Real Model swept events through formal Battle consumers and wall-clock
## presentation. Scripted targets/engine handlers; never OS or human evidence.
const Model = preload("res://scripts/core/joust_match.gd")
const Exchange = preload("res://scripts/visual/exchange_director.gd")
const PHYSICS_DT = 1.0/120.0
var main: Node
var failures: Array[String] = []
var examples: Array = []
var cases: Array = []
var captures: Array = []
var report_path = "E:/GALUMU/docs/development/logs/v049/exchange-scene-01.json"
var capture_dir = "E:/GALUMU/docs/development/screenshots/v049/exchange-scene01"
var original_master_db = 0.0
var captures_enabled = true

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String, info: Dictionary = {}) -> void:
	if ok:
		return
	if message not in failures:
		failures.append(message)
		push_error(message)
	if examples.size()<30:
		examples.append({"message":message,"context":info.duplicate(true)})

func wait_wall_msec(minimum_ms: int) -> int:
	# SceneTreeTimer's first update can include elapsed time from before the
	# timer was created (e.g. a PNG save in this frame), and fixed-fps changes
	# simulated frame delta. A monotonic deadline measures this actual wait.
	var started = Time.get_ticks_msec()
	var deadline = started+minimum_ms
	while Time.get_ticks_msec()<deadline:
		await process_frame
	return Time.get_ticks_msec()-started

func configure(battle) -> void:
	battle.set_process(false)
	battle.set_physics_process(false)
	battle.set_process_input(false)
	battle.set_process_unhandled_input(false)
	if root.focus_exited.is_connected(battle._on_focus_lost):
		root.focus_exited.disconnect(battle._on_focus_lost)
	for view in battle.riders:
		view.set_process(false)
	battle.sound.music.stop()
	battle.exchange_director.reset(1)
	battle.exchange_state = battle.exchange_director.sample()
	battle.contact_first_frame_pending = false
	battle.contact_audio.clear()

func create_battle(mode_name: String, slow: bool):
	root.get_node("GameState").profile.settings.slow_motion = slow
	main._start_match(mode_name,true)
	var battle = main.battle
	configure(battle)
	return battle

func voice_rows(bank) -> Array:
	var result: Array = []
	for voice in bank.voices:
		var kind = "other"
		for key in ["impact","shield","break","hoof","horn","click"]:
			if voice.stream==bank.streams[key]:
				kind = key
		result.append({"id":voice.get_instance_id(),"kind":kind,"paused":voice.stream_paused,"active":voice.has_stream_playback(),"playing":voice.playing,"position":voice.get_playback_position(),"pitch":voice.pitch_scale})
	return result

func indexed_voices(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for row in values:
		result[row.id] = row
	return result

func active_contact_voice(bank) -> bool:
	for voice in bank.voices:
		if voice.has_stream_playback() and (voice.stream==bank.streams.impact or voice.stream==bank.streams.shield):
			return true
	return false

func frame_record(battle, elapsed: float) -> Dictionary:
	var fighters: Array = []
	for fighter in battle.match_model.fighters:
		fighters.append({"x":fighter.x,"speed":fighter.speed,"hp":fighter.hp,"guard":fighter.guard,"aim":fighter.aim,"gait":fighter.gait_phase,"ko":fighter.ko,"dead":fighter.dead})
	return {"wall_seconds":elapsed,"wall_msec":Time.get_ticks_msec(),"phase":battle.match_model.phase,"state":battle.exchange_state.duplicate(true),"engine_scale":Engine.time_scale,"first_contact_pending":battle.contact_first_frame_pending,"queued_audio":battle.contact_audio.size(),"camera":[battle.camera.position.x,battle.camera.position.y,battle.camera.zoom.x,battle.camera.offset.x,battle.camera.offset.y],"kick":[battle.impact_kick.x,battle.impact_kick.y],"voices":voice_rows(battle.sound),"fighters":fighters}

func capture(battle, case_name: String, stage: String, elapsed: float) -> void:
	if not captures_enabled or capture_dir.is_empty():
		# Keep a real rendered frame for first-contact/read visibility probes,
		# while excluding synchronous PNG encoding/writing from telemetry.
		await RenderingServer.frame_post_draw
		return
	await RenderingServer.frame_post_draw
	var path = capture_dir+"/"+case_name+"_"+stage+".png"
	var code = root.get_texture().get_image().save_png(path)
	check(code==OK,"Rendered exchange screenshot saves",{"path":path,"error":code})
	var row = frame_record(battle,elapsed)
	row["path"] = path
	row["tag"] = stage
	captures.append(row)
	print("EXCHANGE_SCENE_CAPTURE ",case_name," ",stage," ",code)

func prepare_match(battle, kind: String) -> void:
	var model = battle.match_model
	model.phase = "charge"
	model.rng.seed = 49051
	model.fighters[0].x = -600.0
	model.fighters[1].x = 600.0
	for fighter in model.fighters:
		fighter.speed = 480.0
		fighter.stamina = 100.0
		fighter.stats.speed = 1.0
		fighter.stats.stability = 1.0
		fighter.stats.reach = 247.0
		fighter.acted = false
		fighter.guard = .43
		fighter.guard_target = .43
		fighter.lean = 0.0
		fighter.aim = .58
		fighter.hp = 100.0
		fighter.ko = false
		fighter.dead = false
		fighter.gait_phase = 0.0
		fighter.gait_moving = true
	if kind in ["body","wounded"]:
		model.fighters[1].shield = 0.0
		model.fighters[1].stats.armor = 0.0
	if kind=="wounded":
		# Explicit rule-contract fixture, not full-health combat balancing.
		model.fighters[1].hp = 1.0
	if kind!="miss":
		model.fighters[0].aim = target_aim(model,kind)
	for fighter in model.fighters:
		model._cache_pose(fighter)
	battle.pointer_aim = model.fighters[0].aim
	battle._update_views()
	for view in battle.riders:
		view._process(0.0)
	for tick in range(60):
		battle._update_camera(1.0/60.0,Time.get_ticks_msec())
	battle._update_hud()
	battle.last_visual_time = Time.get_ticks_msec()

func target_aim(model, kind: String) -> float:
	var a: Dictionary = model.fighters[0]
	var b: Dictionary = model.fighters[1]
	var target = Model.shield_position(b) if kind=="shield" else Model.body_position(b)
	return asin(clampf((target.y-Model.hand_position(a).y)/Model.lance_length(a),-.629,.548))

func step_rules(battle, scaled_delta: float, kind: String) -> Array:
	var events: Array = []
	var remaining = minf(.25,maxf(0.0,scaled_delta))
	while remaining>.000001 and battle.match_model.phase=="charge":
		var dt = minf(PHYSICS_DT,remaining)
		var model = battle.match_model
		var aim = .58 if kind=="miss" else target_aim(model,kind)
		for index in range(2):
			var fighter = model.fighters[index]
			var old_aim = float(fighter.aim)
			var old_guard = float(fighter.guard)
			var committed = float(model.fighters[1].x)-float(model.fighters[0].x)<1100 and float(model.fighters[0].x)<float(model.fighters[1].x)
			model.set_controls(index,aim if index==0 else .58,0.0,true,dt,.43)
			check(absf(float(fighter.aim)-old_aim)<=(.95 if committed else 2.2)*dt*float(fighter.stats.get("lance_handling",1.0))+.0001,"Scripted slow scene cannot teleport a lance",{"state":battle.exchange_state.state,"dt":dt})
			check(absf(float(fighter.guard)-old_guard)<=2.8*dt*float(fighter.stats.get("shield_handling",1.0))+.0001,"Scripted slow scene cannot teleport a shield",{"state":battle.exchange_state.state,"dt":dt})
		model.time_effect_active = bool(battle.exchange_state.impact_active)
		model.step(dt)
		var pending = model.drain_events()
		if not pending.is_empty():
			battle._consume_events(pending)
			for event in pending:
				events.append(event.duplicate(true))
		remaining -= dt
		if battle.contact_first_frame_pending:
			# Render the collision before running more pre-accumulated physics.
			break
	return events

func pause_contract(battle) -> Dictionary:
	var before = battle.exchange_state.duplicate(true)
	var x_before = float(battle.match_model.fighters[0].x)
	var gait_before = float(battle.match_model.fighters[0].gait_phase)
	var kick_before: Vector2 = battle.impact_kick
	var original_label_remaining = maxi(0,battle.contact_until-Time.get_ticks_msec())
	# A just-started long cue cannot finish naturally during this 140ms wait.
	# It is the strong control group; old hoof slots may already be finished
	# and waiting for Godot's playback-list cleanup at the pause boundary.
	battle.sound.play("horn",-80.0,1.0)
	var control_voice: AudioStreamPlayer
	for voice in battle.sound.voices:
		if voice.stream==battle.sound.streams.horn and voice.has_stream_playback():
			if not is_instance_valid(control_voice) or voice.get_playback_position()<control_voice.get_playback_position():
				control_voice = voice
	check(is_instance_valid(control_voice),"Audio pause control cue did not create an active long playback")
	var voices_before = voice_rows(battle.sound)
	# Keep only 40ms of the label budget: a real paused wait must not hide it.
	battle.contact_until = Time.get_ticks_msec()+40
	battle._update_hud()
	battle._toggle_pause()
	var voices_immediate = voice_rows(battle.sound)
	var immediate_by_id = indexed_voices(voices_immediate)
	var control_position_before = control_voice.get_playback_position() if is_instance_valid(control_voice) else 0.0
	var pause_wall_start = Time.get_ticks_msec()
	var size_before = battle.sound.voices.size()
	var voice_index_before = battle.sound.next_voice
	var label_remaining = battle.contact_until-battle.pause_started
	battle.sound.play("impact")
	await wait_wall_msec(140)
	battle._physics_process(.3)
	battle._process(0.0)
	var voices_delayed = voice_rows(battle.sound)
	var delayed_by_id = indexed_voices(voices_delayed)
	check(battle.exchange_state.state==before.state and absf(float(battle.exchange_state.stage_elapsed)-float(before.stage_elapsed))<.0001,"Pause freezes the active presentation budget")
	check(battle.match_model.fighters[0].x==x_before and battle.match_model.fighters[0].gait_phase==gait_before,"Pause freezes actual rule movement and gait")
	check(battle.impact_kick.is_equal_approx(kick_before),"Pause freezes the directed impact kick")
	check(battle.contact_label.visible,"Paused contact text expired against wall time")
	check(battle.sound.playback_paused and battle.wind.stream_paused,"Pause freezes sound-bank and wind playheads")
	# Godot 4.5.1 does not retain stream_paused on an empty playback list;
	# requiring true on finished/idle pool slots was a test false positive.
	# Active slots must actually pause and keep their mixed playhead still.
	var playhead_tolerance = .040
	for voice in voices_delayed:
		if voice.active:
			check(voice.paused,"An active effect playback continued through pause",{"before":voices_before,"immediate":voices_immediate,"delayed":voices_delayed,"voice":voice})
			if immediate_by_id.has(voice.id) and immediate_by_id[voice.id].active:
				var advance = float(voice.position)-float(immediate_by_id[voice.id].position)
				check(absf(advance)<=playhead_tolerance,"A paused active effect playhead advanced beyond mixing tolerance",{"voice_id":voice.id,"advance":advance,"tolerance":playhead_tolerance,"before":voices_before,"immediate":voices_immediate,"delayed":voices_delayed})
		elif immediate_by_id.has(voice.id):
			check(not voice.playing,"An inactive/ended voice claimed to play while paused",{"immediate":immediate_by_id[voice.id],"delayed":voice})
	if is_instance_valid(control_voice):
		check(control_voice.has_stream_playback() and control_voice.stream_paused,"The fresh 1.2s control cue did not remain paused and active",{"before":voices_before,"immediate":voices_immediate,"delayed":voices_delayed})
		check(absf(control_voice.get_playback_position()-control_position_before)<=playhead_tolerance,"The fresh audio control cue advanced during pause",{"initial":control_position_before,"after":control_voice.get_playback_position(),"tolerance":playhead_tolerance,"delayed":voices_delayed})
	check(battle.sound.voices.size()==size_before and battle.sound.next_voice==voice_index_before,"Playing a cue while paused cannot allocate or steal an effect voice")
	var actual_paused_ms = Time.get_ticks_msec()-pause_wall_start
	check(actual_paused_ms>=140,"Pause observation did not span 140ms of actual monotonic wall time",{"actual_paused_ms":actual_paused_ms})
	battle._toggle_pause()
	var resume_wall_start = Time.get_ticks_msec()
	var voices_resumed = voice_rows(battle.sound)
	check(not paused and not battle.paused and not battle.sound.playback_paused,"Resume releases tree/audio pause")
	check(absf(float(battle.contact_until-Time.get_ticks_msec())-label_remaining)<30,"Resume preserves remaining contact-text time")
	check(not battle.sound.music.has_stream_playback(),"Resume unexpectedly restarted manually stopped battle music")
	check(is_equal_approx(Engine.time_scale,float(battle.exchange_state.scale)),"Resume reapplies the remaining presentation scale")
	var control_resume_start = control_voice.get_playback_position() if is_instance_valid(control_voice) else 0.0
	await wait_wall_msec(75)
	var actual_resume_ms = Time.get_ticks_msec()-resume_wall_start
	check(actual_resume_ms>=75,"Resume observation did not span 75ms of actual monotonic wall time",{"actual_resume_ms":actual_resume_ms})
	var voices_resume_delayed = voice_rows(battle.sound)
	if is_instance_valid(control_voice):
		check(control_voice.has_stream_playback() and not control_voice.stream_paused,"Resume did not restore the fresh audio control cue",{"resumed":voices_resumed,"after_wait":voices_resume_delayed})
		check(control_voice.get_playback_position()>control_resume_start+.010,"Resumed audio control playhead failed to advance",{"start":control_resume_start,"after":control_voice.get_playback_position(),"resumed":voices_resumed,"after_wait":voices_resume_delayed})
	# Do not let the artificial 40ms edge fixture shorten the subsequent
	# rendered contact feedback in this otherwise continuous real exchange.
	battle.contact_until = Time.get_ticks_msec()+original_label_remaining
	return {"before":before,"after":battle.exchange_state.duplicate(true),"requested_paused_ms":140,"actual_paused_ms":actual_paused_ms,"requested_resume_ms":75,"actual_resume_ms":actual_resume_ms,"measured_pause_and_resume_probe_seconds":float(Time.get_ticks_msec()-pause_wall_start)/1000.0,"edge_fixture_label_remaining_ms":label_remaining,"restored_original_label_remaining_ms":original_label_remaining,"playhead_tolerance_seconds":playhead_tolerance,"voices_before":voices_before,"voices_immediate_pause":voices_immediate,"voices_delayed_pause":voices_delayed,"voices_immediate_resume":voices_resumed,"voices_delayed_resume":voices_resume_delayed,"api_boundary":"Finished/empty pool slots need not retain stream_paused; active playback and a newly started 1.2s horn control must pause, stay still within mixing granularity and resume. Wait duration uses monotonic wall deadlines, not simulated timer delta. See Godot 4.5.1 audio_stream_player_internal.cpp set_stream_paused/get_stream_paused/playback cleanup."}

func rate_probe(battle) -> void:
	if battle.match_model.phase!="charge":
		return
	var fighter = battle.match_model.fighters[0]
	var old_aim = float(fighter.aim)
	var old_guard = float(fighter.guard)
	battle.pointer_aim = .58 if old_aim<0 else -.68
	battle._select_guard(0 if old_guard<.5 else 2)
	var game_dt = (1.0/60.0)*float(Engine.time_scale)
	battle._physics_process(game_dt)
	check(absf(float(fighter.aim)-old_aim)<=2.2*game_dt*float(fighter.stats.get("lance_handling",1.0))+.0001,"Formal Battle input bypassed lance rate during slowdown")
	check(absf(float(fighter.guard)-old_guard)<=2.8*game_dt*float(fighter.stats.get("shield_handling",1.0))+.0001,"Formal Battle input bypassed shield rate during slowdown")

func run_case(mode_name: String, slow: bool, kind: String) -> void:
	var name = mode_name+"_"+kind+("_slow_on" if slow else "_slow_off")
	var battle = create_battle(mode_name,slow)
	prepare_match(battle,kind)
	await process_frame
	var start = Time.get_ticks_msec()
	var previous = start
	var timeline: Array = []
	var actual_hits: Array = []
	var seen: Dictionary = {}
	var pause_result: Dictionary = {}
	var crossed = false
	var first_contact_checked = false
	var ended = false
	for frame in range(900):
		await create_timer(PHYSICS_DT,true,false,true).timeout
		var now = Time.get_ticks_msec()
		var real_dt = maxf(0.0,float(now-previous)/1000.0)
		previous = now
		var elapsed = float(now-start)/1000.0
		var game_dt = real_dt*float(Engine.time_scale)
		var events = step_rules(battle,game_dt,kind)
		var new_hit = false
		for event in events:
			if event.type=="hit":
				actual_hits.append(event)
				new_hit = true
		var queued_before = battle.contact_audio.size()
		var kick_before: Vector2 = battle.impact_kick
		if new_hit and not first_contact_checked:
			check(battle.contact_first_frame_pending and queued_before>0,"A real contact did not queue its first visible frame/audio")
			check(not active_contact_voice(battle.sound),"Contact audio played before its first visible frame")
			# Deliberately stale pre-contact elapsed: production must not consume
			# the entire new hold before the first displayed collision.
			battle.last_visual_time = Time.get_ticks_msec()-150
		battle._process(game_dt)
		battle._update_views()
		for view in battle.riders:
			view._process(real_dt*float(Engine.time_scale))
		if new_hit and not first_contact_checked:
			first_contact_checked = true
			check(battle.exchange_state.state=="contact" and battle.exchange_state.hitstop,"First visible contact was consumed by a stale 150ms pre-hit frame")
			check(not battle.contact_first_frame_pending and battle.contact_audio.is_empty(),"First-frame contact queue was not consumed exactly once")
			check(battle.impact_kick.is_equal_approx(kick_before),"The directed impact kick decayed before its first displayed contact")
			check(active_contact_voice(battle.sound),"Queued contact audio did not start beside the first visible frame")
			await capture(battle,name,"first_contact",elapsed)
			if slow and kind=="shield":
				rate_probe(battle)
				pause_result = await pause_contract(battle)
				previous = Time.get_ticks_msec()
		var state_name = str(battle.exchange_state.state)
		if state_name in ["approach","read","release"] and not seen.has(state_name):
			seen[state_name] = true
			await capture(battle,name,state_name,elapsed)
		if kind=="miss":
			check(not battle.exchange_state.hitstop and not battle.exchange_state.impact_active,"A genuine miss triggered contact-only timing")
		if not slow:
			check(state_name not in ["approach","read"],"Slow-motion-off scene entered an optional slow stage")
		var bounds: Vector2 = battle._mounted_vertical_bounds()
		var safe: Rect2 = battle.combat_safe_rect()
		var center_y = root.get_visible_rect().size.y*.5
		var top_y = center_y+(bounds.x-battle.camera.position.y-battle.camera.offset.y)*battle.camera.zoom.y
		var bottom_y = center_y+(bounds.y-battle.camera.position.y-battle.camera.offset.y)*battle.camera.zoom.y
		check(top_y>=safe.position.y-1 and bottom_y<=safe.end.y+1,"Final contact camera kick crossed the mounted HUD envelope",{"top":top_y,"bottom":bottom_y,"camera":str(battle.camera.position),"offset":str(battle.camera.offset)})
		timeline.append(frame_record(battle,elapsed))
		crossed = float(battle.match_model.fighters[0].x)>float(battle.match_model.fighters[1].x)+200
		ended = battle.match_model.phase=="ended"
		if kind=="wounded":
			if battle.is_finished:
				check(is_equal_approx(Engine.time_scale,1.0),"The result state retained cinematic time scale")
				await capture(battle,name,"terminal_restored",elapsed)
				break
		elif crossed and not battle.exchange_state.impact_active and is_equal_approx(Engine.time_scale,1.0):
			await capture(battle,name,"crossed_restored",elapsed)
			break
		if elapsed>8.0:
			check(false,"Formal exchange exceeded its bounded test duration",{"case":name,"phase":battle.match_model.phase,"state":state_name,"gap":battle._exchange_context().gap})
			break
	if kind=="miss":
		check(actual_hits.is_empty() and crossed,"Deliberate-miss fixture did not cross without actual contacts",{"case":name,"hits":actual_hits.size(),"crossed":crossed})
	else:
		check(not actual_hits.is_empty() and first_contact_checked,"Expected formal Model contact never occurred",{"case":name})
		var expected_zone = "shield" if kind=="shield" else "body"
		var observed = false
		for hit in actual_hits:
			observed = observed or str(hit.zone)==expected_zone
		check(observed,"The actual contact did not strike the staged target zone",{"case":name,"wanted":expected_zone,"hits":actual_hits})
	if kind=="wounded":
		check(ended and battle.is_finished and battle.match_model.fighters[1].dead,"The explicit 1HP war fixture did not finish and restore results")
	var final = frame_record(battle,float(Time.get_ticks_msec()-start)/1000.0)
	var bank = battle.sound
	main._close_battle()
	check(not paused and is_equal_approx(Engine.time_scale,1.0),"Leaving the formal exchange did not restore global time")
	for voice in bank.voices:
		check(not voice.has_stream_playback(),"Leaving the exchange retained an active effect playback")
	cases.append({"name":name,"source":"actual Model.step swept contacts/miss, scripted target controls","starting_defender_hp":1 if kind=="wounded" else 100,"first_contact_injected_stale_timestamp_ms":150 if first_contact_checked else 0,"contact_events":actual_hits,"pause":pause_result,"final":final,"timeline":timeline})
	await process_frame

func simultaneous_fixture() -> Dictionary:
	for phase in [0.0,.15,.4,.8]:
		for gap in [1000.0,1004.0,1008.0,1012.0]:
			var model = Model.new("arena",{"speed":1.0,"stability":1.0,"reach":247.0},{"speed":1.0,"stability":1.0,"reach":247.0},49055)
			model.phase = "charge"
			for index in range(2):
				var fighter = model.fighters[index]
				fighter.x = -gap*.5 if index==0 else gap*.5
				fighter.speed = 480.0
				fighter.guard = .43
				fighter.guard_target = .43
				fighter.gait_phase = phase
				fighter.gait_moving = true
			for index in range(2):
				var fighter = model.fighters[index]
				fighter.aim = asin(clampf((Model.shield_position(model.fighters[1-index]).y-Model.hand_position(fighter).y)/Model.lance_length(fighter),-.629,.548))
				model._cache_pose(fighter)
			for tick in range(240):
				for index in range(2):
					var fighter = model.fighters[index]
					var aim = asin(clampf((Model.shield_position(model.fighters[1-index]).y-Model.hand_position(fighter).y)/Model.lance_length(fighter),-.629,.548))
					model.set_controls(index,aim,0,true,PHYSICS_DT,.43)
				model.step(PHYSICS_DT)
				var hits: Array = []
				for event in model.drain_events():
					if event.type=="hit":
						hits.append(event)
				if hits.size()==2:
					return {"fighters":model.fighters.duplicate(true),"events":hits,"mode":"arena","phase":phase,"initial_gap":gap}
	return {}

func simultaneous_scene_order() -> void:
	var fixture = simultaneous_fixture()
	check(not fixture.is_empty(),"Could not generate a genuine same-physics-step two-contact fixture")
	if fixture.is_empty():
		return
	var snapshots: Array = []
	for reverse in [false,true]:
		var battle = create_battle("arena",true)
		battle.match_model.phase = "charge"
		battle.match_model.fighters = fixture.fighters.duplicate(true)
		for index in range(2):
			battle.riders[index].fighter = battle.match_model.fighters[index]
		battle._update_views()
		var events: Array = fixture.events.duplicate(true)
		if reverse:
			events.reverse()
		battle._consume_events(events)
		battle.last_visual_time = Time.get_ticks_msec()-100
		battle._process(0)
		snapshots.append(battle.exchange_state.duplicate(true))
		main._close_battle()
		await process_frame
	for key in ["state","scale","strength","focus","stage_elapsed","impact_elapsed"]:
		check(snapshots[0][key]==snapshots[1][key],"Same-step real contacts changed presentation when their event-array order was reversed",{"key":key,"samples":snapshots})
	cases.append({"name":"simultaneous_scene_order","source":"two contacts actually emitted in one Model.step; same state replayed into formal scene consumers in opposite array order","fixture_phase":fixture.phase,"fixture_gap":fixture.initial_gap,"events":fixture.events,"samples":snapshots})

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report-path="):
			report_path = arg.trim_prefix("--report-path=")
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
		if arg=="--no-captures":
			captures_enabled = false
	var state = root.get_node_or_null("GameState")
	if state==null or not state.save_path.contains("qa_") or DisplayServer.get_name()=="headless":
		push_error("Formal exchange study requires rendering and -- --test-profile")
		quit(1)
		return
	if FileAccess.file_exists(report_path):
		push_error("Choose a fresh formal exchange report path")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	if captures_enabled and not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
	state.profile = state.default_profile()
	state.profile.settings.sound = true
	state.profile.settings.shake = true
	original_master_db = AudioServer.get_bus_volume_db(0)
	AudioServer.set_bus_volume_db(0,-60.0)
	root.size = Vector2i(1280,720)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	for item in [["arena",true,"shield"],["arena",false,"shield"],["war",true,"body"],["arena",true,"miss"],["war",false,"miss"],["war",true,"wounded"]]:
		await run_case(item[0],item[1],item[2])
	await simultaneous_scene_order()
	main.queue_free()
	await process_frame
	AudioServer.set_bus_volume_db(0,original_master_db)
	var report = {"passed":failures.is_empty(),"failures":failures,"examples":examples,"cases":cases,"captures_enabled":captures_enabled,"captures":captures,"project_version":ProjectSettings.get_setting("application/config/version","unknown"),"scope":"Formal BattleScene consumes actual Model swept events and genuinely empty misses; wall-clock _process advances production ExchangeDirector, Engine.time_scale is not forced to 1 between stages, fixed small physics substeps use scaled game time. First-contact stale-frame, audio/kick timing, monotonic wall-deadline pause/resume observations, settings, continuous control limits, terminal/exit restoration and same-step event order. --no-captures removes PNG-save stalls from telemetry, not all harness overhead; sample cadence is not GPU FPS. Deliberate 1HP death fixture is a mode contract, not full-health balance. Scripted controls/engine handlers, no OS/human approval or comprehensive performance claim."}
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("EXCHANGE_SCENE_V049 ",report.passed," failures=",failures)
	quit(0 if failures.is_empty() else 1)
