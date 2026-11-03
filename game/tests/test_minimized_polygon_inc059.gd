extends SceneTree
## Minimal engine/driver reproducer: no rider, art, mesh skin or battle.
class PolygonProbe extends Node2D:
	var redraws = 0
	var skip_hidden = false
	var triangle = PackedVector2Array([Vector2(0,0),Vector2(6,0),Vector2(3,6)])
	func _process(_delta: float) -> void:
		if skip_hidden and not DisplayServer.window_can_draw(): return
		queue_redraw()
	func _draw() -> void:
		if skip_hidden and not DisplayServer.window_can_draw(): return
		redraws+=1
		for i in range(100):
			draw_set_transform(Vector2((i%10)*8,(i/10)*8))
			draw_colored_polygon(triangle,Color.WHITE)

var report: FileAccess
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if OS.get_environment("GALUMU_MEMORY_BOUND")!="1024":
		push_error("Run this memory reproducer only through Start-MemoryBound.ps1.")
		quit(2)
		return
	var path=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--window-report="): path=arg.trim_prefix("--window-report=")
	if not root.get_node("GameState").save_path.contains("qa_") or path.is_empty() or FileAccess.file_exists(path) or DisplayServer.get_name()=="headless":
		quit(2)
		return
	report=FileAccess.open(path,FileAccess.WRITE)
	if report==null:
		quit(2)
		return
	Engine.max_fps=10
	var probe=PolygonProbe.new()
	probe.skip_hidden="--skip-hidden" in OS.get_cmdline_user_args()
	root.add_child(probe)
	await create_timer(3,true,false,true).timeout
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	for i in range(30):
		await create_timer(.5,true,false,true).timeout
		report.store_line(JSON.stringify({"step":i,"redraws":probe.redraws,"presented_frames":Engine.get_frames_drawn(),"static_bytes":OS.get_static_memory_usage(),"buffer_bytes":Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)}))
		report.flush()
	probe.set_process(false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await create_timer(4,true,false,true).timeout
	report.close()
	quit()
