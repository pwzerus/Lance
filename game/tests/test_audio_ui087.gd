extends "test_ui082.gd"
const Mix = preload("res://scripts/core/audio_mix.gd")

func slider(key: String) -> HSlider:
	return main.screen.find_child(key,true,false) as HSlider

func bus_gain(name_value: StringName) -> float:
	var index = AudioServer.get_bus_index(name_value)
	return 0.0 if AudioServer.is_bus_mute(index) else db_to_linear(AudioServer.get_bus_volume_db(index))

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder=arg.trim_prefix("--folder=")
		if arg=="--compact": compact=true
	state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json"
	state.load_profile();state.save_profile()
	# All mixing is in process. No audible output or OS/system volume changes.
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(960,540) if compact else Vector2i(1280,720)
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	main.show_settings()
	await capture("00_game_settings")
	check(press("音量与材质试听"),"Sound settings are not reachable")
	await capture("01_sound_settings")
	check(main.sounds.music.bus==Mix.MUSIC,"Camp music bypasses Music bus")
	var bus_count=AudioServer.bus_count
	var original=FileAccess.get_sha256(state.save_path)
	slider("music_volume").grab_focus()
	for _i in range(2):
		var event=InputEventKey.new();event.keycode=KEY_LEFT;event.physical_keycode=KEY_LEFT;event.pressed=true
		root.push_input(event,true)
		event=event.duplicate();event.pressed=false;root.push_input(event,true)
	check(is_equal_approx(state.profile.settings.music_volume,.9),"Keyboard slider did not change Music by 5 percent")
	check(is_equal_approx(bus_gain(Mix.MUSIC),.9) and is_equal_approx(bus_gain(Mix.EFFECTS),1.0),"Music slider altered effects or not its own bus")
	check(FileAccess.get_sha256(state.save_path)==original and main.audio_save_pending,"Slider wrote disk per key instead of debouncing")
	await create_timer(.45,true,false,true).timeout
	check(not main.audio_save_pending and is_equal_approx(state._read_save(state.save_path).settings.music_volume,.9),"Debounced volume not persisted")
	slider("effects_volume").value=0
	check(press("试听 · 钢制头盔"),"Helmet preview missing")
	check(main.audio_preview_notice.text.contains("静音") and main.sounds.voices.is_empty(),"Muted preview played or silently failed without explanation")
	main._change_setting("sound",false)
	slider("effects_volume").value=65
	check(bus_gain(Mix.GAME)==0.0,"Volume preview unmuted global sound toggle")
	main._change_setting("sound",true)
	slider("ambience_volume").value=35
	await create_timer(.45,true,false,true).timeout
	for pair in [["试听 · 钢制头盔","helmet"],["试听 · 板甲胸甲","plate"],["试听 · 木芯盾牌","shield_wood"]]:
		check(press(pair[0]),"Missing material preview")
		check(main.sounds.voices.any(func(voice):return str(voice.get_meta("sfx_cue","")).begins_with("contact_"+pair[1]+"_")),"Preview selected wrong material: "+pair[1])
		await create_timer(.70,true,false,true).timeout
	await capture("02_material_preview")
	check(state.save_slot(1),"Cannot save volume slot")
	slider("music_volume").value=20
	main.show_saves()
	check(not main.audio_save_pending and is_equal_approx(state._read_save(state.save_path).settings.music_volume,.2),"Leaving volume page dropped unsaved adjustment")
	main._perform_slot_operation(1,true)
	check(is_equal_approx(bus_gain(Mix.MUSIC),.9) and is_equal_approx(bus_gain(Mix.AMBIENCE),.35),"Manual load did not apply saved audio mix")
	main.show_sound_settings()
	state.backup_path=folder+"/blocked_backup"
	DirAccess.make_dir_recursive_absolute(state.backup_path)
	FileAccess.open(state.backup_path+"/keep.txt",FileAccess.WRITE).store_string("fault fixture")
	slider("effects_volume").value=40
	await create_timer(.45,true,false,true).timeout
	check(state.profile_save_pending and main.settings_notice.text.contains("暂未保存"),"Failed audio save is hidden")
	await capture("03_save_failure")
	state.backup_path=folder+"/qa_backup.json"
	check(state.save_profile(),"Retry cannot persist audio mix")
	for _i in range(3):
		main._start_match("arena",true)
		check(main.battle.wind.bus==Mix.AMBIENCE,"Battle wind bypasses its own bus")
		main.battle.sound.play("hoof")
		check(main.battle.sound.voices.all(func(voice):return voice.bus==Mix.EFFECTS),"Battle effect bypasses effect bus")
		check(is_equal_approx(bus_gain(Mix.EFFECTS),.4) and is_equal_approx(bus_gain(Mix.MUSIC),.9),"Battle setup reset user audio mix")
		main._close_battle();main.show_sound_settings()
		await process_frame
	check(AudioServer.bus_count==bus_count,"Reopened menu/battle keeps adding buses")
	var clean=state.sanitize({"settings":{"master_volume":-8,"music_volume":2,"effects_volume":"oops","ambience_volume":NAN}})
	check(clean.settings.master_volume==0.0 and clean.settings.music_volume==1.0 and clean.settings.effects_volume==1.0 and clean.settings.ambience_volume==1.0,"Malformed volume settings not clamped safely")
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"captures":captures,"bus_count":bus_count,"scope":"Actual background GPU and audio buses; viewport keyboard slider plus production callbacks. Master muted, no OS input/listening. Isolated file failure is intentional."},"\t"))
	main.sounds.set_enabled(false);main.sounds.stop_all();main.queue_free()
	await create_timer(.3,true,false,true).timeout
	print("AUDIO_UI087 ",failures)
	quit(0 if failures.is_empty() else 1)
