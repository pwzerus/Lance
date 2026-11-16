extends "test_play087.gd"
## Focused transition fixture: real Main result/save/replay, replayed contact
## logs from normal matches, shortened waiting (not gameplay/balance evidence).
func run() -> void:
	var folder="";var fixture=""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--folder="):folder=a.trim_prefix("--folder=")
		if a.begins_with("--fixture="):fixture=a.trim_prefix("--fixture=")
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or DisplayServer.get_name()=="headless" or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json";state.load_profile()
	state.profile.settings.sound=true;AudioServer.set_bus_mute(0,true)
	state.profile.renown=60
	state.profile.equipped.merge({"armor":"it_armor_5","helmet":"it_helmet_5","shield":"it_shield_5","lance":"it_lance_long_5","horse":"horse_courser","caparison":"caparison_velvet"},true)
	for id in state.profile.equipped.values():
		if id not in state.profile.owned:state.profile.owned.append(id)
	var recorded=JSON.parse_string(FileAccess.get_file_as_string(fixture))
	root.size=Vector2i(1280,720)
	var main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	var warm=Time.get_ticks_msec()
	while Time.get_ticks_msec()-warm<1800:await process_frame
	var rows=[]
	for cycle in range(24):
		await process_frame
		var before=Time.get_ticks_usec()
		main._start_match("war",false)
		var start_cost=(Time.get_ticks_usec()-before)/1000.0
		var b=main.battle
		if root.focus_exited.is_connected(b._on_focus_lost):root.focus_exited.disconnect(b._on_focus_lost)
		while not b.presentation_ready:await process_frame
		for frame in range(4):await process_frame
		var match_row=recorded.matches[cycle%recorded.matches.size()]
		b.exchange_log.assign(match_row.hits.duplicate(true))
		# Production result signal, persistence and controls. Only waiting is skipped.
		b.match_model.fighters[0].hp=float(match_row.result.player_hp)
		b.match_model.fighters[1].hp=float(match_row.result.enemy_hp)
		b.match_model._finish(str(match_row.result.reason))
		b._consume_events(b.match_model.drain_events())
		b.terminal_at=maxi(1,Time.get_ticks_msec()-7000)
		b.is_finished=true
		Engine.time_scale=1.0
		var gaps=[];var previous=Time.get_ticks_usec()
		for frame in range(24):
			await process_frame
			var now=Time.get_ticks_usec();gaps.append((now-previous)/1000.0);previous=now
		check(main.result_visible,"Result appears")
		check(state.profile.matches==cycle+1 and not state.profile_save_pending,"Exactly one persisted reward per result")
		var toggle=InputEventKey.new();toggle.keycode=KEY_H;toggle.pressed=true
		main._unhandled_input(toggle)
		await process_frame
		check(main.result_debug and not main.result_details.text.is_empty(),"H retains detailed contact report")
		main._unhandled_input(toggle)
		rows.append({"cycle":cycle,"start_ms":start_cost,"result_frames":stats(gaps),"nodes":get_node_count(),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)})
	var out={"passed":failures.is_empty(),"failures":failures,"version":ProjectSettings.get_setting("application/config/version"),"rows":rows,"scope":"24 shortened real Main result/replay transitions, recorded contacts; no OS input or gameplay balance inference"}
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(out,"\t"))
	print("RESULT099 ",out.passed)
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
