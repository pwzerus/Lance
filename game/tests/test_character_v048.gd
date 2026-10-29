extends SceneTree
## Isolated persistence/UI checks plus actual rendered character and seated-leg sheets.
## Programmatic UI signals are not OS input or a player art/feel verdict.
const Appearance = preload("res://scripts/core/character_appearance.gd")
const Face = preload("res://scripts/visual/character_face.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const Rider = preload("res://scripts/visual/rider_view.gd")
const UI = preload("res://scripts/ui/ui_factory.gd")
class FaceSample extends Node2D:
	const FaceRenderer = preload("res://scripts/visual/character_face.gd")
	var appearance: Dictionary = {}
	func _draw() -> void:
		FaceRenderer.draw_face(self,appearance,Rect2(0,0,192,240))
var failures: Array[String] = []
var rows: Array = []
var checks = 0
var report_path = "E:/GALUMU/docs/development/logs/v048/character-01.json"
var capture_dir = ""
var page: Control

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String, context: Dictionary = {}) -> void:
	checks += 1
	if ok:
		return
	if message not in failures:
		failures.append(message)
		push_error(message)
	rows.append({"failure":message,"context":context})

func alternate() -> Dictionary:
	var result = Appearance.defaults()
	for key in Appearance.OPTIONS:
		result[key] = Appearance.OPTIONS[key].size()-1
	return result

func sanitizer_checks(state: Node) -> void:
	var defaults = Appearance.defaults()
	for raw in [null,42,"bad",[],{},true]:
		check(Appearance.sanitize(raw)==defaults,"Absent/non-object appearance migrates to safe defaults",{"raw":str(raw)})
	for key in Appearance.OPTIONS:
		for value in ["2",null,[],{},true,NAN,INF,-INF]:
			check(Appearance.sanitize({key:value})[key]==defaults[key],"Invalid appearance fields fall back without coercing arbitrary data",{"key":key,"raw":str(value)})
		check(Appearance.sanitize({key:-999})[key]==0,"Negative appearance indices stay in range",{"key":key})
		check(Appearance.sanitize({key:999999})[key]==Appearance.OPTIONS[key].size()-1,"Oversized appearance indices stay in range",{"key":key})
		for index in range(Appearance.OPTIONS[key].size()):
			check(Appearance.sanitize({key:index})[key]==index,"Every offered appearance choice survives sanitization",{"key":key,"index":index})
	var old = state.default_profile()
	old.erase("appearance")
	check(state.sanitize(old).appearance==defaults,"Old profile missing appearance receives defaults")
	old.appearance = ["invalid"]
	check(state.sanitize(old).appearance==defaults,"Corrupt profile appearance is sanitized")
	old.appearance = alternate()
	old.appearance.unknown_field = "ignored"
	check(state.sanitize(old).appearance==alternate(),"Valid selections survive profile sanitization; unknown fields are discarded")

func write_json(path: String, value: Dictionary) -> bool:
	var file = FileAccess.open(path,FileAccess.WRITE)
	if file==null:
		return false
	file.store_string(JSON.stringify(value))
	file.close()
	return true

func persistence_checks(state: Node) -> void:
	var legacy = state.default_profile()
	legacy.erase("appearance")
	legacy.coins = 734
	check(write_json(state.save_path,legacy),"QA legacy auto-save fixture writes")
	state.profile = state.default_profile()
	state.load_profile()
	check(state.profile.appearance==Appearance.defaults() and int(state.profile.coins)==734,"Real legacy auto-save loads without losing progress")
	var envelope = {"version":1,"format":"lance-manual-1","saved_at":"legacy QA","profile":legacy}
	check(write_json(state.slot_path(1),envelope),"QA legacy manual-save fixture writes")
	check(state.load_slot(1),"Legacy manual slot loads")
	check(state.profile.appearance==Appearance.defaults() and int(state.profile.coins)==734,"Legacy manual slot retains progress and migrates appearance")
	var choice = alternate()
	check(state.set_appearance(choice),"Changing all appearance fields saves automatically")
	check(state.player_stats().appearance==choice,"Actual player fighter stats receive saved appearance")
	var disk = JSON.parse_string(FileAccess.get_file_as_string(state.save_path))
	# JSON numbers parse as floats. Dictionary equality also compares Variant
	# types, so int-valued choices must be checked numerically, without routing
	# through sanitize (which could conceal a missing/corrupt saved field).
	var disk_appearance: Variant = disk.get("appearance") if disk is Dictionary else null
	check(disk_appearance is Dictionary,"Auto-save contains an actual appearance object")
	if disk_appearance is Dictionary:
		check(disk_appearance.size()==choice.size(),"Auto-save appearance contains exactly the declared fields")
		for key in choice:
			var value: Variant = disk_appearance.get(key)
			var numeric = value is int or value is float
			check(disk_appearance.has(key) and numeric and is_finite(float(value)) and float(value)==float(choice[key]),"Auto-save contains each chosen numeric index",{"key":key,"raw":str(value),"expected":choice[key]})
	state.profile = state.default_profile()
	state.load_profile()
	check(state.profile.appearance==choice and int(state.profile.coins)==734,"Auto-save reload preserves all selections and unrelated progress")
	check(state.save_slot(2),"Current appearance saves in a manual slot")
	check(state.set_appearance(Appearance.defaults()),"Second auto-save fixture can change appearance")
	check(state.load_slot(2),"Manual appearance slot loads")
	check(state.profile.appearance==choice,"Manual slot restores every appearance field")
	var before = state.profile.duplicate(true)
	var good_path: String = state.save_path
	var good_backup: String = state.backup_path
	state.save_path = "user://qa_character_missing_%d/profile.json" % Time.get_ticks_usec()
	state.backup_path = state.save_path+".backup"
	check(not state.set_appearance(Appearance.defaults()),"An unwritable target reports a failed appearance save")
	check(state.profile==before,"Failed appearance save rolls the in-memory profile back")
	state.save_path = good_path
	state.backup_path = good_backup
	state.save_error = ""
	rows.append({"kind":"persistence","qa_path":good_path,"choice":choice,"legacy_coins":734})

func seated_checks() -> void:
	var model = Model.new()
	var fighter: Dictionary = model.fighters[0]
	for direction in [1,-1]:
		fighter.direction = direction
		for lean_value in [-1.0,0.0,1.0]:
			fighter.lean = lean_value
			for phase_index in range(8):
				fighter.speed = 480.0
				fighter.gait_moving = true
				fighter.gait_phase = TAU*phase_index/8
				var pose: Dictionary = Rider.seated_leg_pose(fighter)
				check(pose.has_all(["near","far"]),"Seated pose exposes both legs")
				for side in ["near","far"]:
					var leg: Dictionary = pose.get(side,{})
					check(leg.has_all(["hip","knee","ankle","foot"]),"Seated leg exposes continuous joints",{"side":side})
					if not leg.has_all(["hip","knee","ankle","foot"]):
						continue
					for joint in leg:
						check(Vector2(leg[joint]).is_finite(),"Seated joint remains finite",{"side":side,"joint":joint})
					check(Vector2(leg.hip).distance_to(leg.knee)>1 and Vector2(leg.knee).distance_to(leg.ankle)>1,"Seated leg segments do not collapse",{"side":side})
					check(float(leg.knee.y)>float(leg.hip.y) and float(leg.ankle.y)>float(leg.knee.y),"Bent seated legs descend from saddle towards stirrups",{"side":side})
				check(Vector2(pose.near.hip).distance_to(pose.far.hip)>1 and Vector2(pose.near.foot).distance_to(pose.far.foot)>1,"Near/far seat anchors do not collapse to duplicate pasted legs")
	# The helper is documented in a right-facing local frame. Translation and
	# facing must not be applied a second time inside that frame.
	fighter.x = 0.0
	fighter.lane_y = 0.0
	fighter.direction = 1
	var local_pose: Dictionary = Rider.seated_leg_pose(fighter)
	fighter.x = 1200.0
	fighter.lane_y = 32.0
	fighter.direction = -1
	check(Rider.seated_leg_pose(fighter)==local_pose,"Seated helper stays local; renderer owns world translation and facing")
	rows.append({"kind":"seated_scope","note":"Finite local anchors and full rendered sheets; near/far layer order needs source and image review, not a y-sort assertion."})

func wait_draw() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func capture(name_value: String) -> void:
	if capture_dir.is_empty():
		return
	await wait_draw()
	DirAccess.make_dir_recursive_absolute(capture_dir)
	check(root.get_texture().get_image().save_png(capture_dir+"/"+name_value+".png")==OK,"Character PNG is saved",{"name":name_value})

func ui_checks(state: Node) -> void:
	state.profile.settings.sound = false
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.show_character()
	await wait_draw()
	var original: Dictionary = state.profile.duplicate(true)
	var disk_before = FileAccess.get_file_as_string(state.save_path)
	var target = Appearance.defaults()
	for key in Appearance.OPTIONS:
		target[key] = (int(original.appearance[key])+1)%Appearance.OPTIONS[key].size()
		check(main.character_options.has(key),"Character page contains every choice control",{"key":key})
		var option: OptionButton = main.character_options[key]
		option.select(target[key])
		option.item_selected.emit(target[key])
	check(main.appearance_draft==target,"OptionButton signals update the entire draft")
	check(state.profile==original,"Unsaved UI draft does not mutate the active profile")
	check(FileAccess.get_file_as_string(state.save_path)==disk_before,"Unsaved UI draft does not write the auto-save")
	check(main.preview.fighter.stats.appearance==target,"Mounted preview uses the current draft")
	check(main.character_face_preview.appearance==target,"Face preview uses the same draft")
	await capture("character_draft")
	main._cancel_character()
	check(main.page=="home" and state.profile==original,"Cancel returns home without applying the draft")
	main.show_character()
	check(main.appearance_draft==original.appearance,"Reopening after cancel restores saved choices")
	for key in Appearance.OPTIONS:
		main._change_character_option(key,target[key])
	main._save_character()
	check(main.page=="home" and state.profile.appearance==target,"Save applies appearance and returns home")
	state.profile = state.default_profile()
	state.load_profile()
	main.show_character()
	check(main.appearance_draft==target,"Disk reload then reopening editor preserves saved choices")
	for key in Appearance.OPTIONS:
		check(main.character_options[key].selected==target[key],"Reopened UI displays the saved selection",{"key":key})
	await capture("character_saved_reopened")
	var good_path: String = state.save_path
	var good_backup: String = state.backup_path
	main._change_character_option("skin",(int(target.skin)+1)%Appearance.OPTIONS.skin.size())
	var failed_draft: Dictionary = main.appearance_draft.duplicate(true)
	state.save_path = "user://qa_character_ui_missing_%d/profile.json" % Time.get_ticks_usec()
	state.backup_path = state.save_path+".backup"
	main._save_character()
	check(main.page=="character" and main.appearance_draft==failed_draft,"Failed UI save keeps the draft available for retry")
	check(state.profile.appearance==target,"Failed UI save does not apply the draft to the active profile")
	check(is_instance_valid(main.message_label) and main.message_label.text.contains("保存失败"),"Failed UI save presents an explicit error")
	state.save_path = good_path
	state.backup_path = good_backup
	state.save_error = ""
	main._cancel_character()
	main.queue_free()
	await process_frame
	await process_frame

func make_page(title: String) -> void:
	page = Control.new()
	page.theme = UI.theme()
	root.add_child(page)
	var bg = ColorRect.new()
	bg.color = Color("17251f")
	bg.size = Vector2(1440,810)
	page.add_child(bg)
	UI.label(page,title,Vector2(20,14),24,UI.GOLD)

func seated_sheet(extremes: bool) -> void:
	make_page("跨坐双向 · "+("前后倾／高低盾" if extremes else "不同盾位／步态")+" · 静态姿态夹具")
	for index in range(8):
		var panel = UI.panel(page,Rect2(12+(index%4)*356,64+(index/4)*366,344,350))
		panel.clip_contents = true
		var model = Model.new()
		var fighter: Dictionary = model.fighters[0]
		fighter.x = 0.0
		fighter.lane_y = 0.0
		fighter.direction = 1 if index<4 else -1
		fighter.lean = (1.0 if index%2==0 else -1.0) if extremes else 0.0
		fighter.guard = [0.0,.43,1.0,.43][index%4]
		fighter.aim = -.68 if index%2==0 else .58
		fighter.speed = 480.0
		fighter.gait_moving = true
		fighter.gait_phase = TAU*(index%4)/4
		fighter.stats.appearance = alternate()
		UI.label(panel,"%s 倾%.1f 盾%.2f" % ["右向" if index<4 else "左向",fighter.lean,fighter.guard],Vector2(10,10),16,UI.GOLD)
		var rider = Rider.new()
		rider.fighter = fighter
		rider.moving = true
		rider.stride_phase = fighter.gait_phase
		rider.position = Vector2(167,312)
		rider.scale = Vector2.ONE*.81
		panel.add_child(rider)
		rider.set_process(false)
		rider._process(0)
	await capture("seated_extremes" if extremes else "seated_guards")
	page.queue_free()
	await process_frame

func face_sheet() -> void:
	make_page("像素脸组合 · 基准与逐项单独变化（实际绘制）")
	var options: Array = [{"title":"基准","appearance":Appearance.defaults()}]
	for key in Appearance.OPTIONS:
		var choice = Appearance.defaults()
		choice[key] = Appearance.OPTIONS[key].size()-1
		options.append({"title":key+" = "+str(choice[key]),"appearance":choice})
	options.append({"title":"全部变化","appearance":alternate()})
	for index in range(options.size()):
		var panel = UI.panel(page,Rect2(12+(index%4)*356,64+(index/4)*366,344,350))
		UI.label(panel,options[index].title,Vector2(12,12),17,UI.GOLD)
		var face = FaceSample.new()
		face.appearance = options[index].appearance
		face.position = Vector2(76,65)
		panel.add_child(face)
	await wait_draw()
	var image = root.get_texture().get_image()
	var baseline = image.get_region(Rect2i(88,129,192,240)).get_data()
	for index in range(1,options.size()):
		var region = Rect2i(88+(index%4)*356,129+(index/4)*366,192,240)
		var pixels = image.get_region(region).get_data()
		check(pixels!=baseline,"Every individual face choice causes a real rendered pixel change",{"choice":options[index].title})
	await capture("face_options")
	page.queue_free()
	await process_frame

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report-path="):
			report_path = arg.trim_prefix("--report-path=")
		elif arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	var state = root.get_node_or_null("GameState")
	if state==null or not state.save_path.contains("qa_"):
		push_error("Character QA requires -- --test-profile")
		quit(1)
		return
	var original_profile: Dictionary = state.profile.duplicate(true)
	var original_path: String = state.save_path
	var original_backup: String = state.backup_path
	state.save_path = "user://qa_character_v048_%d.json" % Time.get_ticks_usec()
	state.backup_path = state.save_path+".backup"
	sanitizer_checks(state)
	persistence_checks(state)
	seated_checks()
	if DisplayServer.get_name()!="headless":
		root.size = Vector2i(1440,810)
		await ui_checks(state)
		if not capture_dir.is_empty():
			await seated_sheet(false)
			await seated_sheet(true)
			await face_sheet()
	else:
		check(false,"Character UI and face pixels require an actual rendered engine window")
	state.profile = original_profile
	state.save_path = original_path
	state.backup_path = original_backup
	state.save_error = ""
	var report = {"passed":failures.is_empty(),"checks":checks,"failures":failures,"rows":rows,
		"scope":"Isolated real save files, old-profile migration, sanitizer, auto/manual persistence, programmatic OptionButton draft/cancel/save/reopen flow, seated local joint sanity, actual face-pixel differences and render sheets. Does not prove OS input, movement timing, depth from joint numbers alone, or player visual/feel approval."}
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	else:
		push_error("Character QA report cannot be written")
		quit(1)
		return
	print("CHARACTER_V048 ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
