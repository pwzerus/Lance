extends "test_equipment_battle_v051.gd"
## Narrow regression for the head shells / collar registration changed in DEV-053.
## Relative parent path supports an external --script against an exported PCK.
## Parent run_case uses genuine finite controls, swept contacts, production scene
## consumers, captured complete riders and live-physics weapon release.

func finish() -> void:
	var covered: Dictionary = {}
	for row in rows:
		covered[str(row.country)+"/"+str(row.attacker)] = true
		check(row.tier==0 and row.mode=="war" and row.kind=="fall","Head-only fixture has the requested equipment and mode",{"case":row.case})
		check(str(row.actual_hit.get("zone",""))=="head","Contact is genuinely the head, not an incidental body strike",{"case":row.case})
		check(bool(row.actual_hit.get("ko",false)) and bool(row.actual_hit.get("dead",false)),"Initial1HP fixture reaches actual fatal KO",{"case":row.case})
	check(covered.size()==6 and rows.size()==6,"All three changed early helmets have both attack directions")
	if is_instance_valid(main):
		main._close_battle()
		main.queue_free()
		await process_frame
		await process_frame
	if state and not original_profile.is_empty():
		state.profile = original_profile
	check(is_equal_approx(Engine.time_scale,1.0) and not paused,"Head-contact teardown restores global time and pause state")
	var result = {
		"passed":failures.is_empty() and rows.size()==6,
		"failures":failures,"examples":examples,"rows":rows,"captures":shots,
		"wall_msec":Time.get_ticks_msec()-started,
		"scope":"Six production head contacts: eng/fr/de tier0 in war, each attacked from both directions. Genuine finite-control swept contact, exact equipment retained through actual fatal KO and fallen weapon release; contact/release PNGs require visual comparison with the helmet and face. No automated pixel-fit claim, OS input, human play, balance claim or timing assessment.",
		"fixture_limits":"Reuses test_equipment_battle_v051 run_case. Both riders receive identical catalogue stats; shield=0, other rider already acted, defender HP=1, speed480 and x±720.120Hz Model steps; camera manually settled, presentation director advanced after first contact only for release observation. QA profile is in memory and restored; no save is written."
	}
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	if file==null:
		push_error("Cannot write head-contact report")
		quit(2)
		return
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print("HEAD_CONTACTS_V053 passed=",result.passed," cases=",rows.size()," wall_msec=",result.wall_msec)
	quit(0 if result.passed else 1)

func run() -> void:
	report_path = "E:/GALUMU/docs/development/logs/v053/head-contacts01.json"
	capture_dir = "E:/GALUMU/docs/development/screenshots/v053/head-contacts01"
	var args = OS.get_cmdline_user_args()
	for i in range(args.size()):
		var arg = str(args[i])
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
		elif arg=="--report" and i+1<args.size(): report_path = str(args[i+1])
		elif arg.begins_with("--captures="): capture_dir = arg.trim_prefix("--captures=")
		elif arg=="--captures" and i+1<args.size(): capture_dir = str(args[i+1])
		elif arg=="--no-captures": captures_enabled = false
		elif arg.begins_with("--budget-ms="): budget_ms = clampi(int(arg.trim_prefix("--budget-ms=")),10000,120000)
	started = Time.get_ticks_msec()
	state = root.get_node_or_null("GameState")
	if state==null or not str(state.save_path).contains("qa_") or DisplayServer.get_name()=="headless":
		push_error("Head-contact regression needs GPU and isolated -- --test-profile")
		quit(2)
		return
	if FileAccess.file_exists(report_path):
		push_error("Use a fresh head-contact report path")
		quit(2)
		return
	if captures_enabled and DirAccess.dir_exists_absolute(capture_dir):
		var folder = DirAccess.open(capture_dir)
		if folder!=null and not folder.get_files().is_empty():
			push_error("Use a fresh head-contact screenshot directory")
			quit(2)
			return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	original_profile = state.profile.duplicate(true)
	state.profile = state.default_profile()
	state.profile.settings.sound = false
	state.profile.settings.blood = false
	state.profile.settings.shake = false
	state.profile.settings.aim_cues = false
	items = Catalogue.load_items()
	root.size = Vector2i(1440,810)
	root.content_scale_size = Vector2i(1440,810)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	for country in ["eng","fr","de"]:
		for attacker in [0,1]:
			if Time.get_ticks_msec()-started>budget_ms:
				check(false,"Head-contact regression exceeded wall budget; remaining cases untested")
				await finish()
				return
			await run_case(country,0,"war",attacker,"fall")
	await finish()
