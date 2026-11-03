extends SceneTree
## Run only inside Start-MemoryBound. Wall-clock samples are flushed, not retained.
var main: Node
var output: FileAccess
var font: FontFile
var scenario = "resize"
var steps = 120
var interval = .4
var start = 0
var font_one = false
var replays = 0
var freeze_rider = false
var redraw_frozen = false
var rider_draws = 0

func _initialize() -> void:
	call_deferred("run")

func sample(step: int) -> void:
	var sizes = 0
	var textures = 0
	for cache in range(font.get_cache_count()):
		for size in font.get_size_cache_list(cache):
			sizes += 1
			textures += font.get_texture_count(cache,size)
	var row = {"step":step,"scenario":scenario,"replays":replays,"rider_draws":rider_draws,"process_frames":Engine.get_process_frames(),"seconds":(Time.get_ticks_msec()-start)/1000.0,
		"window_size":str(root.size),"window_mode":DisplayServer.window_get_mode(),"max_fps":Engine.max_fps,"frames":Engine.get_frames_drawn(),"fps":Engine.get_frames_per_second(),
		"static_bytes":OS.get_static_memory_usage(),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
		"buffer_bytes":Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED),
		"font_caches":font.get_cache_count(),"font_sizes":sizes,"font_textures":textures,"font_oversampling":font.oversampling}
	output.store_line(JSON.stringify(row))
	output.flush()

func run() -> void:
	if OS.get_environment("GALUMU_MEMORY_BOUND")!="1024":
		push_error("Run this memory diagnostic only through Start-MemoryBound.ps1.")
		quit(2)
		return
	var report = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--window-report="): report=arg.trim_prefix("--window-report=")
		if arg.begins_with("--scenario="): scenario=arg.trim_prefix("--scenario=")
		if arg.begins_with("--steps="): steps=clampi(int(arg.trim_prefix("--steps=")),1,360)
		if arg=="--font-one": font_one=true
		if arg=="--freeze-rider": freeze_rider=true
		if arg=="--redraw-frozen": redraw_frozen=true
		if arg.begins_with("--interval="): interval=clampf(float(arg.trim_prefix("--interval=")),.1,2.0)
	var state = root.get_node("GameState")
	if not state.save_path.contains("qa_") or report.is_empty() or FileAccess.file_exists(report) or scenario not in ["resize","pages","battle","idle","close","paused-close","replay-close","minimized"]:
		quit(2)
		return
	output = FileAccess.open(report,FileAccess.WRITE)
	if output==null:
		quit(2)
		return
	state.profile=state.default_profile()
	font=load("res://assets/fonts/NotoSansSC.ttf")
	if font_one: font.oversampling=1.0
	main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.preview.draw.connect(func(): rider_draws+=1)
	font=load("res://assets/fonts/NotoSansSC.ttf")
	start=Time.get_ticks_msec()
	await create_timer(5.0,true,false,true).timeout
	sample(-1)
	if scenario=="minimized":
		if freeze_rider: main.preview.set_process(false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	if scenario in ["battle","close","paused-close","replay-close"]:
		main._start_match("arena",true)
		main.battle.autoplay=true
	for i in range(steps):
		if redraw_frozen: main.preview.queue_redraw()
		if scenario=="replay-close" and main.result_visible:
			replays+=1
			main._start_match("war" if replays%2==1 else "arena",true)
			main.battle.autoplay=true
		if scenario=="resize":
			# Distinct sizes exercise DPI/font/viewport allocation paths; bounded
			# at 1440x810, never request an enormous render target.
			root.size=Vector2i(960+(i%120)*4,540+int((i%120)*2.25))
		elif scenario=="pages":
			if i%3==0: main.show_armory()
			elif i%3==1: main.show_history()
			else: main.show_home()
			# Capture synchronous allocation before the next rendered frame too.
			sample(i)
		await create_timer(interval,true,false,true).timeout
		if i%5==0: sample(i)
	if scenario in ["close","paused-close","replay-close"]:
		if scenario=="paused-close": main.battle._toggle_pause()
		sample(steps)
		output.close()
		# Same handler as Window close, but an engine notification injection,
		# not native mouse input. The supervisor must observe actual process exit.
		main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		return
	if scenario=="minimized": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size=Vector2i(1280,720)
	if main.battle: main._close_battle()
	main.show_home()
	await create_timer(10.0,true,false,true).timeout
	sample(steps)
	main.queue_free()
	await process_frame
	output.close()
	quit()
