extends "test_character_v048.gd"
## Focused visual and UI regression for the existing code-native face renderer.
## Calls the actual editor portrait class; no duplicate geometry/call options.
var main_ui: Script

func save_study(name_value: String) -> void:
	await capture(name_value)
	rows.append({"capture":name_value,"path":capture_dir.path_join(name_value+".png")})
	print("FACE_DESIGN_V054 capture=",name_value)

func add_face(index: int, choice: Dictionary, title: String, direction: int, dimensions: Vector2) -> void:
	var panel = UI.panel(page,Rect2(12+(index%4)*356,64+(index/4)*366,344,350))
	panel.clip_contents = true
	UI.label(panel,title,Vector2(10,8),16,UI.GOLD,324)
	var face = main_ui.CharacterFaceCanvas.new()
	face.appearance = choice.duplicate(true)
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.scale = dimensions/Vector2(192,240)*Vector2(direction,1)
	face.position = Vector2(172-dimensions.x*.5*direction,32+(312-dimensions.y)*.5)
	panel.add_child(face)

func shape_sheet(enlarged: bool) -> void:
	var size_name = "8x像素特写" if enlarged else "自建UI原尺寸192x240"
	make_page("DEV-054 · 四脸型 / 无胡须 / 双向 · "+size_name)
	for direction_index in range(2):
		for shape in range(4):
			var choice = Appearance.defaults()
			choice.face_shape = shape
			var direction = 1 if direction_index==0 else -1
			add_face(direction_index*4+shape,choice,str(Appearance.OPTIONS.face_shape[shape])+" / "+("朝右" if direction==1 else "朝左"),direction,Vector2(256,320) if enlarged else Vector2(192,240))
	await save_study("shapes_large" if enlarged else "shapes_editor_size")
	page.queue_free()
	await process_frame

func trait_sheet(field: String) -> void:
	make_page("DEV-054 · "+field+"逐项变化 · 其余保持默认 / 自建UI原尺寸")
	for value in range(Appearance.OPTIONS[field].size()):
		var choice = Appearance.defaults()
		choice[field] = value
		add_face(value,choice,str(Appearance.OPTIONS[field][value]),1,Vector2(192,240))
	await save_study("choices_"+field)
	page.queue_free()
	await process_frame

func freeze_preview(main: Node) -> void:
	# Keep the comparison camera/idle phase constant without replacing its renderer.
	if is_instance_valid(main.preview):
		main.preview.clock = 0.0
		main.preview.stride_phase = 0.0
		main.preview._process(0.0)
		main.preview.set_process(false)
		main.preview.queue_redraw()

func character_ui(state: Node) -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	await process_frame
	main.show_character()
	freeze_preview(main)
	await save_study("character_default")
	var original_profile: Dictionary = state.profile.duplicate(true)
	var disk_before = FileAccess.get_file_as_string(state.save_path)
	var target = {"face_shape":3,"skin":4,"brows":1,"beard":1,"eyes":1,"hair":3}
	for key in target:
		check(main.character_options.has(key),"Appearance UI offers existing choice: "+key)
		if not main.character_options.has(key):
			continue
		var option: OptionButton = main.character_options[key]
		option.select(int(target[key]))
		option.item_selected.emit(int(target[key]))
	check(main.appearance_draft==target,"Existing controls update the same appearance draft")
	check(main.character_face_preview.appearance==target,"Unhelmeted preview receives the chosen appearance")
	check(main.preview.fighter.stats.appearance==target,"Mounted preview receives the same chosen appearance")
	check(state.profile==original_profile,"Unsaved choices do not mutate active profile")
	check(FileAccess.get_file_as_string(state.save_path)==disk_before,"Unsaved choices do not write QA save")
	await save_study("character_draft")
	main._cancel_character()
	check(main.page=="home" and state.profile==original_profile,"Cancel discards appearance draft")
	main.show_character()
	check(main.appearance_draft==original_profile.appearance,"Reopen after cancel restores active appearance")
	for key in target:
		main._change_character_option(key,int(target[key]))
	main._save_character()
	check(main.page=="home" and state.profile.appearance==target,"Save applies the chosen appearance")
	var disk: Variant = JSON.parse_string(FileAccess.get_file_as_string(state.save_path))
	check(disk is Dictionary and disk.get("appearance") is Dictionary,"QA save contains appearance object")
	if disk is Dictionary and disk.get("appearance") is Dictionary:
		for key in target:
			var stored: Variant = disk.appearance.get(key)
			check((stored is float or stored is int) and float(stored)==float(target[key]),"QA disk retains selected index: "+key)
	state.profile = state.default_profile()
	state.load_profile()
	check(state.profile.appearance==target and int(state.profile.coins)==1337,"Reload preserves appearance and unrelated progress")
	main.show_character()
	check(main.appearance_draft==target,"Reopened editor uses actual saved appearance")
	freeze_preview(main)
	await save_study("character_saved_reopened")
	main.queue_free()
	await process_frame
	await process_frame

func run() -> void:
	report_path = "E:/GALUMU/docs/development/logs/v054/face-design01.json"
	capture_dir = "E:/GALUMU/docs/development/screenshots/v054/face-design01"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
		if arg.begins_with("--captures="): capture_dir = arg.trim_prefix("--captures=")
	var state = root.get_node_or_null("GameState")
	if state==null or not str(state.save_path).contains("qa_") or DisplayServer.get_name()=="headless":
		push_error("FACE_DESIGN_V054 requires GPU rendering and -- --test-profile")
		quit(2)
		return
	if FileAccess.file_exists(report_path) or DirAccess.dir_exists_absolute(capture_dir):
		push_error("Use fresh report and capture paths; existing evidence is retained")
		quit(2)
		return
	var original_profile: Dictionary = state.profile.duplicate(true)
	var original_path: String = state.save_path
	var original_backup: String = state.backup_path
	var original_error: String = state.save_error
	# main.gd references the GameState autoload. Resolve it after the SceneTree
	# has installed autoloads, not while this command-line script is compiling.
	main_ui = load("res://scripts/main.gd")
	if main_ui==null or not main_ui.can_instantiate():
		push_error("Production character UI failed to load")
		quit(2)
		return
	state.save_path = "user://qa_face_v054_%d.json" % Time.get_ticks_usec()
	state.backup_path = state.save_path+".backup"
	var qa_path: String = state.save_path
	state.profile = state.default_profile()
	state.profile.settings.sound = false
	state.profile.coins = 1337
	state.profile.equipped.helmet = "fr_helmet_0"
	state.profile.equipped.armor = "eng_armor_0"
	state.profile.appearance = Appearance.defaults()
	check(state.save_profile(),"Dedicated QA appearance fixture saves")
	root.size = Vector2i(1440,810)
	root.content_scale_size = Vector2i(1440,810)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	await character_ui(state)
	await shape_sheet(false)
	await shape_sheet(true)
	for field in ["skin","beard","eyes","brows","hair"]:
		await trait_sheet(field)
	check(rows.size()==10,"All intended UI and portrait captures completed")
	state.profile = original_profile
	state.save_path = original_path
	state.backup_path = original_backup
	state.save_error = original_error
	var report = {"passed":failures.is_empty(),"failures":failures,"rows":rows,"qa_save":qa_path,
		"scope":"Production face drawing in four shapes/both facings at editor size and 8x grid; all six skin/five beard/five eye/four brow/four hair options, and production character UI draft/cancel/save/reload via signals. GPU screenshots and dedicated QA persistence only; no OS input, human art approval or aesthetic score. Mounted/helmet and dynamic coverage are separate tests."}
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	if file==null:
		push_error("Unable to write face design report")
		quit(2)
		return
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("FACE_DESIGN_V054 completed=",failures.is_empty()," captures=",rows.size()," visual_acceptance=pending")
	quit(0 if failures.is_empty() else 1)
