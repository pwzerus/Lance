extends SceneTree
## Diagnostic lifecycle fixture. Not OS input or audio quality acceptance.
var main
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var state = root.get_node("GameState")
	if not str(state.save_path).contains("qa_"):
		quit(2)
		return
	state.profile = state.default_profile()
	state.profile.settings.sound = true
	# Muting only this process lets the default hardware driver be exercised
	# without playing diagnostic music through the user's desktop.
	AudioServer.set_bus_mute(0,true)
	print("AUDIO_EXIT_DRIVER ",AudioServer.get_driver_name())
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for frame in range(30): await process_frame
	for cue in main.sounds.streams:
		if cue in ["lute_loop","wind_loop","hoof","win","lose"]:
			print("STREAM_ID ",cue,"=",main.sounds.streams[cue].get_instance_id())
	for cycle in range(2):
		main._start_match("arena",true)
		for frame in range(30): await process_frame
		main._close_battle()
		main.show_home()
		for frame in range(30): await process_frame
		print("AUDIO_EXIT_CYCLE ",cycle," finished")
	if "--paused-exit" in OS.get_cmdline_user_args():
		main._start_match("arena",true)
		for frame in range(30): await process_frame
		main.battle._toggle_pause()
		print("AUDIO_EXIT paused=",paused)
	main._save_and_exit()
	main._save_and_exit() # Rapid repeated exit must not save/start twice.
