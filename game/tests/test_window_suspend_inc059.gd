extends SceneTree
## Real-window integration only. No desktop-input or subjective play evidence.
var main: Node
var output: FileAccess
var report_path = ""
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	output.store_line(JSON.stringify({"ok":ok,"check":message,"frames":Engine.get_frames_drawn(),"fps_limit":Engine.max_fps}))
	output.flush()
	if not ok: failures.append(message)

func wait_real(seconds: float) -> void:
	await create_timer(seconds,true,false,true).timeout

func run() -> void:
	if OS.get_environment("GALUMU_MEMORY_BOUND")!="1024":
		push_error("Run this memory diagnostic only through Start-MemoryBound.ps1.")
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--window-report="): report_path=arg.trim_prefix("--window-report=")
	var state = root.get_node("GameState")
	if DisplayServer.get_name()=="headless" or not state.save_path.contains("qa_") or report_path.is_empty() or FileAccess.file_exists(report_path):
		quit(2)
		return
	output=FileAccess.open(report_path,FileAccess.WRITE)
	if output==null:
		quit(2)
		return
	state.profile=state.default_profile()
	main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await wait_real(3)
	for page in ["home","armory","character","arena","war","prepaused"]:
		if main.battle: main._close_battle()
		if page=="home": main.show_home()
		elif page=="armory": main.show_armory()
		elif page=="character": main.show_character()
		else:
			main._start_match("war" if page=="war" else "arena",true)
			main.battle.autoplay=true
		await wait_real(3)
		if page=="prepaused": main.battle._toggle_pause()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
		await wait_real(1)
		var frames=Engine.get_frames_drawn()
		var x=main.battle.match_model.fighters[0].x if main.battle else 0.0
		check(not DisplayServer.window_can_draw(),page+": OS window is not drawable")
		check(Engine.max_fps==10,page+": background limiter works even when paused")
		if main.battle:
			check(main.battle.paused and paused,page+": battle paused on minimize")
			check(not main.battle.mouse_held,page+": held spur cleared")
		await wait_real(7)
		check(Engine.get_frames_drawn()==frames,page+": no presented frames while minimized")
		if main.battle:
			check(main.battle.match_model.fighters[0].x==x,page+": simulation stayed paused")
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		await wait_real(1)
		check(Engine.get_frames_drawn()>frames and Engine.max_fps==60,page+": display and frame cap restored")
		if main.battle:
			check(main.battle.paused and paused,page+": restore did not silently unpause")
		if page in ["home","arena"]:
			await RenderingServer.frame_post_draw
			var screenshot=root.get_texture().get_image()
			check(screenshot.save_png(report_path.get_basename()+"-"+page+".png")==OK,page+": restored frame captured")
		if main.battle:
			main.battle._toggle_pause()
			await wait_real(3)
			check(not main.battle.paused and not paused,page+": explicit resume works")
	# Exercise shutdown while minimized and paused, not only the visible close.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	await wait_real(2)
	check(main.battle.paused,"final close: paused minimized battle")
	output.store_line(JSON.stringify({"complete":true,"failures":failures}))
	output.close()
	if not failures.is_empty():
		quit(1)
		return
	main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
