extends "test_icons085.gd"
## Wall-clock mixed lifetime test. Window mode changes affect only the protected
## isolated QA desktop; never switch desktops or synthesize OS user input.
var folder=""
var main
var rows: Array=[]
var marks: Array=[]
var started=0
var completed_matches=0

func snapshot(label: String) -> Dictionary:
	var row={"label":label,"seconds":(Time.get_ticks_msec()-started)/1000.0,"can_draw":DisplayServer.window_can_draw(),"frames_drawn":Engine.get_frames_drawn(),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"bus_count":AudioServer.bus_count,"fps_cap":Engine.max_fps,"page":main.page}
	if is_instance_valid(main.battle):
		row.merge({"paused":main.battle.paused,"phase":main.battle.match_model.phase,"x":main.battle.match_model.fighters[0].x,"time_scale":Engine.time_scale})
	return row

func watch(label: String, seconds: float, auto_replay: bool=false) -> void:
	var until=Time.get_ticks_msec()+int(seconds*1000)
	var next_sample=0
	while Time.get_ticks_msec()<until:
		await process_frame
		if auto_replay and is_instance_valid(main.battle) and main.battle.is_finished:
			completed_matches+=1
			start_battle()
		if Time.get_ticks_msec()>=next_sample:
			next_sample=Time.get_ticks_msec()+1000
			rows.append(snapshot(label))
	marks.append(snapshot(label+"-end"))
	FileAccess.open(folder+"/progress.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"marks":marks,"failures":failures}))
	print("SOAK087 ",label," done t=",(Time.get_ticks_msec()-started)/1000.0)

func start_battle() -> void:
	main._start_match("arena",false)
	if root.focus_exited.is_connected(main.battle._on_focus_lost):root.focus_exited.disconnect(main.battle._on_focus_lost)

func hide_and_check(label: String, seconds: float) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	await settle(1.0)
	var before=snapshot(label+"-start")
	marks.append(before)
	if bool(before.can_draw):failures.append(label+" did not become non-drawable")
	await watch(label,seconds)
	var after=snapshot(label+"-end")
	if int(after.frames_drawn)-int(before.frames_drawn)>2:failures.append(label+" kept rendering while hidden")
	if int(after.fps_cap)!=10:failures.append(label+" hidden frame cap did not apply")
	if before.has("x"):
		if not bool(after.paused) or not is_equal_approx(float(after.x),float(before.x)):failures.append("Hidden battle advanced or failed to pause")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await settle(1.2)
	if not DisplayServer.window_can_draw() or Engine.max_fps!=60:failures.append(label+" failed to restore normal presentation")

func capture(tag: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+tag+".png")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json";state.load_profile()
	# Keep actual audio processing, silence only the hardware-facing output.
	state.profile.settings.sound=true;AudioServer.set_bus_mute(0,true)
	state.profile.renown=60;state.profile.region=2
	var selected={}
	for item in state.items:
		var slot=str(item.get("slot",""))
		if slot not in state.profile.equipped or str(item.get("region","")) not in ["德意志","欧洲共通"]:continue
		if not selected.has(slot) or int(item.get("price",0))>int(selected[slot].get("price",0)):selected[slot]=item
	for slot in selected:
		state.profile.equipped[slot]=selected[slot].id
		if selected[slot].id not in state.profile.owned:state.profile.owned.append(selected[slot].id)
	root.size=Vector2i(1280,720)
	main=load("res://scenes/main.tscn").instantiate();main.smoke_mode=true;root.add_child(main);current_scene=main;main.set_process(false)
	started=Time.get_ticks_msec()
	await watch("home_warm",12)
	main.show_armory();await watch("armory_warm",6)
	main.selected_slot="helmet";main.selected_item={};main.show_armory()
	await hide_and_check("armory_loading_hidden",75)
	await watch("armory_restored",6)
	marks.append({"icons":visible_icons(main)})
	await capture("01_armory_restored")
	start_battle();await watch("competitive_with_audio",75,true)
	start_battle();await watch("charge_before_hide",5)
	await hide_and_check("battle_hidden",75)
	var frozen_x=float(main.battle.match_model.fighters[0].x)
	await watch("restored_still_paused",8)
	if not main.battle.paused or not is_equal_approx(frozen_x,float(main.battle.match_model.fighters[0].x)):failures.append("Restored game resumed without player choice")
	await capture("02_battle_restored_paused")
	main.battle._toggle_pause()
	await watch("explicitly_resumed",45,true)
	main._close_battle();main.show_home()
	await hide_and_check("home_hidden",75)
	await watch("home_restored",3)
	await capture("03_home_restored")
	var stable_nodes=[]
	for cycle in range(3):
		main.show_settings();await settle(.3)
		main.show_sound_settings();await settle(.3)
		main.show_help(true);await settle(.3)
		main.show_saves();await settle(.3)
		main.show_armory();await settle(.8)
		main.show_home();await settle(.6)
		stable_nodes.append(get_node_count());marks.append(snapshot("menu_cycle_%d"%cycle))
	if abs(int(stable_nodes[-1])-int(stable_nodes[0]))>2:failures.append("Repeated final menu cycle retains extra nodes")
	if completed_matches<1:failures.append("No actual competitive match completed")
	if not state.save_profile():failures.append("Final QA save failed")
	var report={"passed":failures.is_empty(),"failures":failures,"wall_seconds":(Time.get_ticks_msec()-started)/1000.0,"matches":completed_matches,"rows":rows,"marks":marks,"stable_home_nodes":stable_nodes,"equipped":state.profile.equipped,"executable":OS.get_executable_path(),"version":ProjectSettings.get_setting("application/config/version"),"scope":"Real-time source or packaged Main, actual GPU, audio mixing muted at Master, three 75-second hidden intervals including pending armoury jobs and charge. Engine window-mode and menu calls on isolated desktop, no OS user input. Private memory/exit authority is external guard log."}
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SOAK087_RESULT ",failures," seconds=",report.wall_seconds)
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
