extends SceneTree
## EQUIP-067 battle HUD capture: real main scene, autoplay arena match (the
## smoke-mode autopilot holds the spur), screenshots during the charge and at
## the result, to check the horse-condition gauge, live numbers and score.
## Isolated desktop, QA profile. Not OS input, not a playtest.
var folder = ""

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hud-report="): folder = arg.trim_prefix("--hud-report=")
	if OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not root.get_node("GameState").save_path.contains("qa_") or folder.is_empty() or DisplayServer.get_name()=="headless" or DirAccess.dir_exists_absolute(folder):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1440,810)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for _i in range(3):
		await process_frame
	main.smoke_mode = true
	main._start_match("arena",false)
	var shots = {240:"charge_early.png",420:"charge_late.png",900:"pass2.png"}
	for frame in range(2400):
		await process_frame
		if shots.has(frame):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/"+shots[frame])
		if main.result_visible:
			for _i in range(20):
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/result.png")
			break
	print("HUD067_DONE "+folder+" result="+str(main.pending_result))
	quit()
