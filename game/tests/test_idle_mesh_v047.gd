extends SceneTree
## Real menu preview draw sweep. The caller must ALSO inspect the engine log
## for renderer ERROR lines; finishing this script alone is not error-free QA.
const Rider = preload("res://scripts/visual/rider_view.gd")
var failures: Array[String] = []
var screenshots: Array = []
var phases: Array[float] = []
var report_path = "E:/GALUMU/docs/development/logs/v047/idle-mesh-01.json"
var capture_dir = ""
var main: Node

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok and message not in failures:
		failures.append(message)
		push_error(message)

func triangle_contract() -> void:
	var diagnosed = PackedVector2Array([Vector2(34.2846697,-100.4906785),Vector2(84.8610592,-122.6055792),Vector2(84.8416263,-122.5970789)])
	check(not Rider.triangle_has_area(diagnosed), "Near-zero idle foreleg triangle is rejected")
	check(not Rider.triangle_has_area(PackedVector2Array([Vector2.ZERO,Vector2(1,1),Vector2(2,2)])), "Collinear triangle is rejected")
	check(not Rider.triangle_has_area(PackedVector2Array([Vector2.ZERO,Vector2(INF,0),Vector2(0,2)])), "Non-finite triangle is rejected")
	check(Rider.triangle_has_area(PackedVector2Array([Vector2.ZERO,Vector2(2,0),Vector2(0,2)])), "Normal counterclockwise triangle remains drawable")
	check(Rider.triangle_has_area(PackedVector2Array([Vector2.ZERO,Vector2(0,2),Vector2(2,0)])), "Normal clockwise triangle remains drawable")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report-path="):
			report_path = arg.trim_prefix("--report-path=")
		elif arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	var state = root.get_node_or_null("GameState")
	if state==null or not state.save_path.contains("qa_"):
		push_error("Idle mesh study requires -- --test-profile")
		quit(1)
		return
	if DisplayServer.get_name()=="headless":
		push_error("Idle mesh study requires actual rendering; do not use --headless")
		quit(1)
		return
	triangle_contract()
	state.profile.settings.sound = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	# Use the normal production menu and its normal Rider preview, not a
	# rebuilt mesh in the test. Only its idle phase is deterministically fixed.
	check(main.page=="home", "Normal game scene starts at the home menu")
	var preview = main.preview
	if not is_instance_valid(preview):
		check(false,"Home menu has an actual Rider preview")
		write_report(0)
		main.queue_free()
		await process_frame
		quit(1)
		return
	check(preview is Rider,"Home preview uses the production Rider script")
	check(not preview.moving and preview.preview,"Home preview remains in its normal idle-preview mode")
	preview.set_process(false)
	for index in range(629):
		phases.append(index*.01)
	# Include a complete endpoint and narrow samples around the mathematical
	# candidate. These are requested render poses, not an engine reproduction
	# claim until the caller checks the actual renderer log.
	phases.append(TAU)
	for extra in [3.5499,3.54999,3.549999698556,3.55001,3.5501]:
		phases.append(extra)
	phases.sort()
	var first_drawn = Engine.get_frames_drawn()
	var captured_first = false
	var captured_diagnostic = false
	var captured_last = false
	for phase in phases:
		preview.stride_phase = phase
		preview.fighter.gait_phase = phase
		preview.fighter.gait_moving = false
		preview._process(0.0)
		preview.queue_redraw()
		var before = Engine.get_frames_drawn()
		await process_frame
		await RenderingServer.frame_post_draw
		check(Engine.get_frames_drawn()>before,"Each requested phase reached an actual rendered frame")
		if not capture_dir.is_empty():
			var name_value = ""
			if not captured_first:
				name_value = "menu_idle_start"
				captured_first = true
			elif not captured_diagnostic and absf(phase-3.549999698556)<.000001:
				name_value = "menu_idle_phase_3p55"
				captured_diagnostic = true
			elif not captured_last and phase>=TAU:
				name_value = "menu_idle_full_cycle"
				captured_last = true
			if not name_value.is_empty():
				DirAccess.make_dir_recursive_absolute(capture_dir)
				var path = capture_dir+"/"+name_value+".png"
				var error = root.get_texture().get_image().save_png(path)
				check(error==OK,"Requested idle screenshot saves successfully")
				screenshots.append({"phase":phase,"path":path,"error":error})
		print("IDLE_MESH_PHASE ",phase)
	var drawn = Engine.get_frames_drawn()-first_drawn
	check(drawn>=phases.size(),"The complete idle sweep rendered one or more frames per sample")
	write_report(drawn)
	main.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)

func write_report(drawn: int) -> void:
	var report = {"passed":failures.is_empty(),"failures":failures,"project_version":ProjectSettings.get_setting("application/config/version","unknown"),
		"rendered_phase_samples":phases.size(),"drawn_frames":drawn,"phase_step":.01,"phase_start":0.0,"phase_end":TAU,
		"diagnostic_neighborhood":[3.5499,3.54999,3.549999698556,3.55001,3.5501],"screenshots":screenshots,
		"engine_error_log_review_required":true,"scope":"Production home-menu Rider preview, fixed idle phases through a complete cycle plus the near-degenerate foreleg neighborhood, actual rendered frames. Helper accepts both triangle windings and rejects collinear/non-finite/near-zero triangles. Passed here means the helper and sweep completed; caller must separately inspect renderer ERROR logs. No OS input or human visual-quality claim."}
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	else:
		check(false,"Idle mesh QA report can be written")
	print("IDLE_MESH_V047 ",JSON.stringify(report))
