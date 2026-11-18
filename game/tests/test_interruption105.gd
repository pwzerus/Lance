extends "test_flow082.gd"
## Real production scene/window interruption on an isolated desktop only.
## Autoplay provides movement/contact; injected viewport events exercise latches.
func snapshot(b)->Dictionary:
	var data={"phase_time":b.match_model.phase_time,"scale":Engine.time_scale,"exchange":b.exchange_state.duplicate(true),"fighters":[],"falls":[]}
	for f in b.match_model.fighters:
		data.fighters.append({"x":f.x,"speed":f.speed,"aim":f.aim,"guard":f.guard,"lean":f.lean,"phase":f.gait_phase,"body":b.Model.body_position(f),"head":b.Model.head_position(f)})
	for f in b.effects.bodies:data.falls.append({"age":f.age,"position":f.position,"rotation":f.rotation,"pose":f.visual.detached_pose.duplicate(true)})
	return data
func real_wait(seconds:float)->void:
	var end_at=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<end_at:await process_frame
func mouse(held:bool)->void:
	var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=held;event.position=Vector2(650,400)
	root.push_input(event,true)
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
	state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not "qa_" in state.save_path or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json";state.profile=state.default_profile();state.profile.settings.sound=false
	root.size=Vector2i(1280,720)
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	var rows=[]
	for stage in ["ready","charge","impact"]:
		main._start_match("arena",true)
		var b=main.battle;b.autoplay=true;b.match_model.rng.seed=10589;b.ai_rng.seed=10903
		if root.focus_exited.is_connected(b._on_focus_lost):root.focus_exited.disconnect(b._on_focus_lost)
		if not await wait_battle(b):quit(2);return
		var start_x=float(b.match_model.fighters[0].x)
		var deadline=Time.get_ticks_msec()+90000
		while Time.get_ticks_msec()<deadline:
			if stage=="ready" or (stage=="charge" and b.match_model.phase=="charge" and absf(float(b.match_model.fighters[0].x)-start_x)>120.0) or (stage=="impact" and b.exchange_state.impact_active and not b.is_finished):break
			await process_frame
		check(Time.get_ticks_msec()<deadline,"Live match did not reach "+stage)
		if Time.get_ticks_msec()>=deadline:quit(2);return
		mouse(true);check(b.mouse_held,"Viewport press did not reach battle latch")
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
		await real_wait(1.0)
		check(not DisplayServer.window_can_draw() and b.paused and paused,"Hidden active match did not pause")
		check(not b.mouse_held and b.touch_roles.is_empty(),"Minimize retained held controls")
		mouse(false)
		var before=snapshot(b)
		var start=Time.get_ticks_msec()
		await real_wait(8.0)
		var after=snapshot(b)
		var hidden_elapsed=(Time.get_ticks_msec()-start)/1000.0
		check(before==after,"Hidden "+stage+" advanced poses or impact time")
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		await real_wait(.7)
		check(b.paused and snapshot(b)==before,"Restoring "+stage+" spent impact time or resumed automatically")
		await capture(stage+"_restored_paused")
		key(KEY_ESCAPE)
		await process_frame
		check(not b.paused and not paused,"Explicit resume failed after "+stage)
		check(not b.mouse_held,"Resume restored a stale held spur")
		var resumed_at=Time.get_ticks_msec()
		await real_wait(.6)
		check(snapshot(b)!=before,"Resume left the live simulation stuck")
		rows.append({"stage":stage,"hidden_seconds":hidden_elapsed,"resume_ms":Time.get_ticks_msec()-resumed_at,"before":before,"after":after})
		main._close_battle();main.show_home();await process_frame
		check(is_equal_approx(Engine.time_scale,1.0) and not paused,"Closing interrupted battle failed to reset clock")
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":rows,"version":ProjectSettings.get_setting("application/config/version"),"scope":"Actual isolated GPU/windows minimized during ordinary practice ready/charge/contact. Live autoplay, viewport mouse/Escape injection, 8s settled-hidden pose snapshots; no damage injection, no OS input/human feel."},"\t"))
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
