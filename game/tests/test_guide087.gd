extends SceneTree
## Actual running Battle + viewport/key injection. No direct fighter poses,
## forced hits, shortened distances or time-scale acceleration.
const Model = preload("res://scripts/core/joust_match.gd")
const Guide = preload("res://scripts/core/practice_guide.gd")
var folder = ""
var main
var state
var failures: Array = []
var timeline: Array = []
var guide: Guide
var mouse_down = false
var forward_down = false
var mouse_only = false
var compact = false
var elite = false
var resume_test = false
var resumed = false
var paused_once = false
var last_stage = -1
var last_pointer_time = 0.0
var entered_stage = 0.0
var first_aim_sent = false
var match_count = 1

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok and message not in failures: failures.append(message)
func mouse_button(button: int, pressed: bool) -> void:
	var event=InputEventMouseButton.new()
	event.button_index=button;event.pressed=pressed;event.position=Vector2(800,420)
	root.push_input(event,true)
func urge(value: bool) -> void:
	if value==mouse_down:return
	mouse_down=value
	mouse_button(MOUSE_BUTTON_LEFT,value)
func forward(value: bool) -> void:
	if value==forward_down:return
	forward_down=value
	if mouse_only:
		if value:
			for _i in range(3): mouse_button(MOUSE_BUTTON_WHEEL_UP,true)
		else: mouse_button(MOUSE_BUTTON_MIDDLE,true)
	else:
		var event=InputEventKey.new()
		event.keycode=KEY_W;event.physical_keycode=KEY_W;event.pressed=value
		Input.parse_input_event(event)
func guard_slot(slot: int) -> void:
	if main.battle.guard_slot==slot:return
	var event=InputEventKey.new()
	event.keycode=KEY_1+slot;event.physical_keycode=KEY_1+slot;event.pressed=true
	root.push_input(event,true)
func aim_angle(angle: float) -> void:
	var battle=main.battle
	var fighter:Dictionary=battle.match_model.fighters[0]
	var target=Model.hand_position(fighter)+Vector2(150,sin(angle)*Model.lance_length(fighter))
	var point=battle.world.get_global_transform_with_canvas()*target
	check(battle.combat_safe_rect().has_point(point),"Guide bot aim fell under HUD; input not a valid player action")
	var event=InputEventMouseMotion.new()
	event.position=point;event.relative=Vector2(0,5)
	root.push_input(event,true)
func aim_body() -> void:
	var model=main.battle.match_model
	var fighter:Dictionary=model.fighters[0]
	var target=Model.body_position(model.fighters[1])
	aim_angle(asin(clampf((target.y-Model.hand_position(fighter).y)/Model.lance_length(fighter),-.629,.548)))
func capture(name_value: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+name_value+".png")
func prepare_battle() -> void:
	var battle=main.battle
	if root.focus_exited.is_connected(battle._on_focus_lost):root.focus_exited.disconnect(battle._on_focus_lost)
	mouse_down=false;forward_down=false
	entered_stage=Time.get_ticks_msec()/1000.0
	first_aim_sent=false
	last_pointer_time=0.0

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
		if arg=="--mouse-only":mouse_only=true
		if arg=="--compact":compact=true
		if arg=="--elite":elite=true
		if arg=="--resume-test":resume_test=true
	state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not "qa_" in str(state.save_path) or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json"
	state.load_profile()
	state.profile.settings.sound=false
	state.profile.settings.mouse_only=mouse_only
	if elite:
		state.profile.region=2
		state.profile.renown=60
		var selected={}
		for item in state.items:
			var slot=str(item.get("slot",""))
			if slot not in state.profile.equipped or str(item.get("region","")) not in ["德意志","欧洲共通"]:continue
			if not selected.has(slot) or int(item.get("price",0))>int(selected[slot].get("price",0)):selected[slot]=item
		for slot in selected:
			state.profile.equipped[slot]=selected[slot].id
			if selected[slot].id not in state.profile.owned:state.profile.owned.append(selected[slot].id)
	root.size=Vector2i(960,540) if compact else Vector2i(1280,720)
	main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main);current_scene=main
	main.show_practice_setup()
	for _i in range(4):await process_frame
	await capture("00_practice_choice")
	guide=Guide.new()
	main._start_match("arena",true,guide)
	prepare_battle()
	var start=Time.get_ticks_msec()/1000.0
	var done_at=-1.0
	while Time.get_ticks_msec()/1000.0-start<180.0:
		await process_frame
		var now=Time.get_ticks_msec()/1000.0
		if main.page=="lesson_result":
			await capture("08_lesson_result")
			break
		var battle=main.battle
		var fighter:Dictionary=battle.match_model.fighters[0]
		if resume_test and guide.step==1 and not resumed:
			resumed=true
			urge(false)
			var restart=InputEventKey.new()
			restart.keycode=KEY_R;restart.physical_keycode=KEY_R;restart.pressed=true
			root.push_input(restart,true)
			await process_frame
			check(main.active_guide==guide and guide.step==1,"R restarted the lesson instead of preserving completed actions")
			match_count+=1
			prepare_battle()
			continue
		if resume_test and guide.step==2 and not paused_once:
			paused_once=true
			var pause_key=InputEventKey.new()
			pause_key.keycode=KEY_ESCAPE;pause_key.physical_keycode=KEY_ESCAPE;pause_key.pressed=true
			root.push_input(pause_key,true)
			var held_progress=guide.hold
			var frozen_x=float(fighter.x)
			await create_timer(1.0,true,false,true).timeout
			check(battle.paused and guide.step==2 and is_equal_approx(guide.hold,held_progress) and is_equal_approx(float(fighter.x),frozen_x),"Paused lesson advanced motion or progress")
			await capture("pause_respected")
			root.push_input(pause_key,true)
			entered_stage=Time.get_ticks_msec()/1000.0
			continue
		if guide.step!=last_stage:
			timeline.append({"step":guide.step,"seconds":now-start,"match":match_count,"pass":battle.match_model.pass_number,"phase":battle.match_model.phase,"speed":fighter.speed,"aim":fighter.aim,"guard":fighter.guard,"lean":fighter.lean,"text":guide.instruction(mouse_only)})
			last_stage=guide.step;entered_stage=now;first_aim_sent=false
			await capture("step_%02d" % guide.step)
		if guide.step<6:
			check(not battle.exchange_log.any(func(event):return int(event.attacker)==1),"Coach attacked before the defensive lesson")
		if guide.complete():
			if done_at<0:done_at=now
			urge(false);forward(false)
			if main.result_visible:
				await capture("08_lesson_result")
				break
			if now-done_at>1.0 and is_instance_valid(battle.lesson_result_button):
				var finish=InputEventMouseButton.new()
				finish.button_index=MOUSE_BUTTON_LEFT
				finish.position=battle.lesson_result_button.get_global_rect().get_center()
				finish.pressed=true;root.push_input(finish,true)
				finish=finish.duplicate();finish.pressed=false;root.push_input(finish,true)
				continue
			if now-done_at>65:check(false,"Lesson completed but match did not reach result");break
		elif main.result_visible:
			await capture("continue_%02d" % match_count)
			urge(false);forward(false)
			match_count+=1
			main._start_match("arena",true,guide)
			prepare_battle()
			continue
		match guide.step:
			0:urge(true)
			1:urge(guide.peak_speed<guide.cruise+55.0)
			2:
				urge(false)
				if not first_aim_sent and now-entered_stage>.15:
					aim_angle(.30);first_aim_sent=true
			3:guard_slot(0)
			4:forward(not guide.leaned)
			5:
				forward(false)
				urge(true)
				if now-last_pointer_time>.20:
					aim_body();last_pointer_time=now
			6:
				urge(false);guard_slot(1)
				if not first_aim_sent:aim_angle(-.60);first_aim_sent=true
	urge(false);forward(false)
	check(guide.complete(),"Guided practice did not complete within 180 real seconds")
	check(bool(state.profile.settings.get("guided_practice_v087",false)),"Completed lesson was not saved")
	var saved=state._read_save(state.save_path)
	check(not saved.is_empty() and saved.settings.get("guided_practice_v087",false),"Lesson completion flag missing from actual saved file")
	check(state.profile.coins==520 and state.profile.matches==0,"Practice incorrectly awarded money or counted a match")
	check(not guide.last_contact.is_empty() and not guide.last_block.is_empty(),"Completion lacked actual outgoing contact or shield interception")
	var result={"passed":failures.is_empty(),"failures":failures,"timeline":timeline,"matches":match_count,"wall_seconds":Time.get_ticks_msec()/1000.0-start,"mouse_only":mouse_only,"compact":compact,"elite":elite,"resumed":resumed,"pause_test":paused_once,"last_contact":guide.last_contact,"last_block":guide.last_block,"scope":"Real-time background Battle; viewport mouse/guard events and Input.parse_input_event keyboard. No OS input, forced hit or pose changes."}
	var report=FileAccess.open(folder+"/report.json",FileAccess.WRITE);report.store_string(JSON.stringify(result,"\t"));report.close()
	main.sounds.set_enabled(false);main._close_battle();main.queue_free()
	await create_timer(.15,true,false,true).timeout
	print("GUIDE087 ",failures)
	quit(0 if failures.is_empty() else 1)
