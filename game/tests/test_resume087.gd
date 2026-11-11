extends "test_ui082.gd"
## Two separate engine processes load a copied, genuine prior QA save. Source
## evidence is read-only; this fixture never opens the player's formal files.
func run()->void:
	var source="";var stage="import"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--folder="):folder=a.trim_prefix("--folder=")
		if a.begins_with("--profile-source="):source=a.trim_prefix("--profile-source=")
		if a.begins_with("--stage="):stage=a.trim_prefix("--stage=")
	state=root.get_node("GameState")
	var allowed="E:/GALUMU/logs/comm087/"
	if not folder.simplify_path().begins_with(allowed) or not source.simplify_path().begins_with(allowed) or not source.get_file().begins_with("qa_") or stage not in ["import","reopen"] or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":quit(2);return
	var output=folder+"/report-"+stage+".json"
	if FileAccess.file_exists(output) or (stage=="import" and DirAccess.dir_exists_absolute(folder)):quit(2);return
	var input=FileAccess.open(source,FileAccess.READ)
	if input==null or input.get_length()>state.MAX_SAVE_BYTES:quit(2);return
	var bytes=input.get_buffer(input.get_length());input.close()
	var original=JSON.parse_string(bytes.get_string_from_utf8())
	if not state._valid_save(original):quit(2);return
	var source_hash=FileAccess.get_sha256(source)
	if stage=="import":
		DirAccess.make_dir_recursive_absolute(folder)
		var copy=FileAccess.open(folder+"/qa_profile.json",FileAccess.WRITE)
		copy.store_buffer(bytes);copy.close()
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json"
	state.load_profile()
	check(not state.recovery_required and not state.profile_save_pending,"Valid prior save entered failure recovery")
	for key in ["coins","renown","wins","matches","region","equipped"]:
		check(state.profile[key]==original[key],"Migration changed prior "+key)
	# JSON parses numbers as float; Appearance deliberately stores integer indices.
	# Dictionary equality is type-sensitive, so compare the actual saved choices.
	check(state.profile.appearance.size()==original.appearance.size(),"Migration changed appearance fields")
	for field in original.appearance:
		check(float(state.profile.appearance.get(field,-1))==float(original.appearance[field]),"Migration changed appearance choice "+field)
	for id in original.owned:check(id in state.profile.owned,"Migration lost owned item "+str(id))
	for key in original.settings:check(state.profile.settings[key]==original.settings[key],"Migration changed prior setting "+key)
	for key in ["master_volume","music_volume","effects_volume","ambience_volume"]:
		check(is_equal_approx(float(state.profile.settings[key]),float(original.settings.get(key,1.0))),"New/existing volume default changed: "+key)
	check(state.profile.settings.guided_practice_v087==bool(original.settings.get("guided_practice_v087",false)),"Learning completion failed to survive restart/default migration")
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(960,540)
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	await capture(stage+"_01_camp")
	check(main.page=="home","Valid saved profile did not enter camp")
	main.show_sound_settings();await capture(stage+"_02_sound")
	main.show_practice_setup();await capture(stage+"_03_practice")
	var completed=bool(original.settings.get("guided_practice_v087",false))
	var captions=[]
	for action in buttons(main.screen):captions.append(action.text)
	check(("重温分步练习" if completed else "第一次上马 · 开始引导") in captions,"Practice page does not describe loaded learning state")
	main.show_match_setup();main._begin_match("arena")
	if bool(original.settings.get("combat_brief_v044",false)):
		check(is_instance_valid(main.battle),"Returning learned profile was forced through first-run brief")
	else:
		check(is_instance_valid(main.brief_overlay),"Unlearned legacy profile lost its introduction")
	main._close_battle();main.show_home()
	check(state.save_profile(),"Migrated/reopened progress could not save")
	check(FileAccess.get_sha256(source)==source_hash,"Read-only prior evidence was modified")
	var report={"passed":failures.is_empty(),"failures":failures,"stage":stage,"profile_source":source,"source_sha256":source_hash,"saved_sha256":FileAccess.get_sha256(state.save_path),"version":ProjectSettings.get_setting("application/config/version"),"executable":OS.get_executable_path(),"matches":state.profile.matches,"coins":state.profile.coins,"guided_practice":state.profile.settings.guided_practice_v087,"captures":captures,"scope":"Separate actual engine process, copied prior QA save, real load/sanitize/save and rendered camp/settings/practice. No player's formal files, OS input, fabricated match result or compatibility claim beyond these profiles."}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("RESUME087 ",stage," ",failures)
	# A deliberate prior-frame stall reproduces the old newly-created timer
	# counting time that happened before shutdown. QA only, never production.
	if "--slow-close-frame" in OS.get_cmdline_user_args():OS.delay_msec(180)
	var close_started=Time.get_ticks_usec()
	var music_ref=weakref(main.sounds.music.get_stream_playback()) if main.sounds.music.has_stream_playback() else null
	root.tree_exiting.connect(func():
		var elapsed=(Time.get_ticks_usec()-close_started)/1000.0
		var alive=music_ref!=null and music_ref.get_ref()!=null
		check(elapsed>=120,"Shutdown consumed time before the close request")
		check(not alive,"Camp music playback remained alive at tree exit")
		report.close_milliseconds=elapsed;report.music_released=not alive
		report.passed=failures.is_empty();report.failures=failures
		FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
		print("RESUME087_CLOSE elapsed_ms=",elapsed," music_alive=",alive))
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
