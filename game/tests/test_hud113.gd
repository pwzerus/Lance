extends SceneTree
## Isolated GPU and viewport-injected controls; no OS keyboard/mouse input.
var failures:Array[String]=[]
var folder=""
var records=[]
var main:Node

func _initialize() -> void:call_deferred("run")
func check(value:bool,message:String)->void:
	if not value and message not in failures:failures.append(message)
func frame(name:String)->void:
	await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+name+".png")==OK,"Save HUD capture "+name)
func click(control:Control)->void:
	var point=control.get_global_rect().get_center()
	for pressed in [true,false]:
		var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=point;event.global_position=point
		root.push_input(event,true);await process_frame
func key(code:int)->void:
	for pressed in [true,false]:
		var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed
		root.push_input(event,true);await process_frame

func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or DisplayServer.get_name()=="headless" or not "qa_" in state.save_path:quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_hud113.json";state.backup_path=folder+"/qa_hud113.backup.json"
	state.profile=state.default_profile();state.profile.settings.sound=false
	check(not state.profile.settings.detailed_combat,"New profile defaults to minimal combat")
	var old=state.default_profile();old.settings.erase("detailed_combat")
	check(not state.sanitize(old).settings.detailed_combat,"Older saves migrate to minimal combat")
	root.size=Vector2i(1440,810);root.content_scale_size=root.size
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);main.set_process(false)
	main.show_settings();await process_frame
	var setting=main.screen.find_child("DetailedCombatSetting",true,false)
	check(is_instance_valid(setting),"Details setting exists")
	if not is_instance_valid(setting):quit(2);return
	await click(setting)
	check(state.profile.settings.detailed_combat,"Settings checkbox enables detailed mode through viewport input")
	state.load_profile()
	check(state.profile.settings.detailed_combat,"Explicit detailed setting survives save and reload")
	await frame("settings_details")
	await click(setting)
	check(not state.profile.settings.detailed_combat,"Settings checkbox restores minimal mode")
	main._start_match("arena",true)
	var b=main.battle
	b.set_physics_process(false);b.set_process_input(false)
	if root.focus_exited.is_connected(b._on_focus_lost):root.focus_exited.disconnect(b._on_focus_lost)
	while not b.presentation_ready:await process_frame
	b.set_process(false)
	b.match_model.phase="charge";b.match_model.drain_events()
	for i in range(2):
		var f=b.match_model.fighters[i]
		f.x=-300.0 if i==0 else 300.0;f.speed=360.0;f.boost=true;f.gait_moving=true;f.gait_phase=.7+i
	b._update_views();b._update_hud();b._update_camera(1.0,Time.get_ticks_msec())
	check(not b.debug_numbers.visible and b.status_gauges.visible,"Default HUD hides numeric diagnostics")
	check(not b.hud_brand113.visible and not b.hint.visible,"Default HUD removes brand repetition and control paragraph")
	b.match_model.phase="ready";b.match_model.phase_time=2.6;b._update_hud()
	check(b.callout.visible and b.callout.text=="准备 · 3","Minimal HUD keeps the actionable start countdown")
	check(b.ready_panel.visible and b.ready_panel.get_global_rect().encloses(b.callout.get_global_rect()),"Countdown retains a compact contrast backing over bright sky")
	await frame("minimal_ready")
	b.match_model.phase="charge";b._update_hud()
	await key(KEY_H)
	check(not b.training_zones and not b.zone_overlay.visible,"H cannot enable diagnostic geometry without opting in")
	await frame("minimal_charge")
	# Pause is reached through the production viewport event route.
	await key(KEY_ESCAPE)
	check(b.paused,"Escape opens pause")
	var toggle=b.pause_panel.find_child("DetailedCombatPause",true,false) if b.pause_panel else null
	check(is_instance_valid(toggle),"Pause offers details toggle")
	if is_instance_valid(toggle):await click(toggle)
	check(state.profile.settings.detailed_combat and b.debug_numbers.visible,"Pause toggle applies detailed HUD immediately")
	await frame("pause_details")
	check(b.hud_status_strip113.get_global_rect().encloses(b.debug_numbers.get_global_rect()),"Both diagnostic rows have an opaque contrast backing")
	check(b.contact_panel.position.y>=b.debug_numbers.get_global_rect().end.y,"Contact text cannot overpaint diagnostic text")
	check(b.contact_panel.get_global_rect().end.y<=144.01,"Detailed text stays inside the top HUD band")
	check(b.speed_label.get_parent()==b.fatigue_label.get_parent(),"Detailed pace is drawn above the lower panel, not beneath it")
	await key(KEY_ESCAPE)
	check(not b.paused,"Escape resumes")
	await key(KEY_H);b._update_views();b._update_hud()
	check(b.training_zones and b.zone_overlay.visible,"Explicit detailed mode permits diagnostic overlay")
	await frame("detailed_charge")
	state.set_setting("detailed_combat",false);b._update_views();b._update_hud()
	check(not b.debug_numbers.visible and not b.zone_overlay.visible,"Disabling details hides numbers and geometry immediately")
	check(not b.contact_label.text.contains("判定显示"),"Diagnostic notice cannot persist into minimal mode")
	var player=b.match_model.fighters[0]
	for warning in ["shield","injury","seat","lance","fatigue"]:
		player.shield=100;player.hp=100;player.injury=0;player.balance=100;player.unsteady=0;player.seat_support=1;player.broken=false;player.stamina=100
		match warning:
			"shield":player.shield=0
			"injury":player.hp=28;player.injury=.72
			"seat":player.unsteady=.8;player.seat_support=.15
			"lance":player.broken=true
			"fatigue":player.stamina=12
		b._update_hud()
		records.append({"warning":warning,"notice":b.aim_label.text,"fatigue":b.fatigue_label.text,"state":b.status_gauges.rider_state113(player)})
		if warning in ["shield","seat","lance"]:check(b.aim_label.get_parent().visible and not b.aim_label.text.is_empty(),"Minimal mode retains essential notice: "+warning)
		await frame("minimal_"+warning)
	player.shield=0;player.seat_support=.15;b._update_hud()
	check(b.aim_label.text=="失稳 · 回正身体","Imminent loss of support takes priority over persistent broken-equipment notice")
	player.seat_support=1
	for size in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size=size;await process_frame;await frame("minimal_"+str(size.x))
	root.size=Vector2i(1440,810)
	main._close_battle();main.queue_free();await process_frame;await process_frame
	check(not paused and is_equal_approx(Engine.time_scale,1.0),"Exit restores pause and time scale")
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"records":records,"scope":"Source GPU HUD/settings/pause with viewport-injected input; save migration in isolated QA file. Three output sizes. No OS input or player acceptance."},"\t"))
	print("HUD113 ",failures);quit(0 if failures.is_empty() else 1)
