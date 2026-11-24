extends "test_cinema099.gd"
## Controlled direct contacts in the actual Battle renderer and settlement.
## Contact geometry is injected here; sweep accuracy is covered separately.
func run_battle() -> void:
	var state=root.get_node("GameState")
	state.profile=state.default_profile()
	state.profile.settings.sound=true
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1440,810);root.content_scale_size=root.size
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);main.set_process(false)
	report.battle=[]
	for fixture in [
		{"name":"mounted_right","defender":0,"mode":"arena","hp":1.0,"offset":0.0},
		{"name":"mounted_left","defender":1,"mode":"arena","hp":1.0,"offset":0.0},
		{"name":"aware_loss","defender":0,"mode":"arena","hp":90.0,"awareness":1.0,"offset":0.0},
		{"name":"late_slip_right","defender":0,"mode":"arena","hp":1.0,"offset":22.8},
		{"name":"late_slip_left","defender":1,"mode":"arena","hp":1.0,"offset":-22.8},
		{"name":"war_mounted","defender":1,"mode":"war","hp":1.0,"offset":0.0}]:
		await incapacity_case(fixture)
	main._close_battle();main.queue_free();await process_frame;await process_frame

func incapacity_case(c: Dictionary) -> void:
	main._start_match(str(c.mode),true)
	var b=main.battle
	b.set_physics_process(false);b.set_process_input(false);b.set_process_unhandled_input(false)
	if root.focus_exited.is_connected(b._on_focus_lost):root.focus_exited.disconnect(b._on_focus_lost)
	while not b.presentation_ready:await process_frame
	var model=b.match_model
	model.phase="charge";model.drain_events()
	for index in range(2):
		var f=model.fighters[index]
		f.x=-150.0 if index==0 else 150.0
		f.speed=240.0;f.boost=false;f.gait_moving=true;f.gait_phase=.7+index
		f.aim=0.0;f.lance_stability=1.0;f.acted=true;f.lean=0.0
	var target:Dictionary=model.fighters[int(c.defender)]
	target.hp=float(c.hp);target.consciousness=float(c.get("awareness",100.0))
	var contact={"type":"hit","zone":"head","attacker":1-int(c.defender),"defender":int(c.defender),"speed":480.0,
		"head_incidence":.4,"position":Model.head_position(target),"combat_elevation":0.0,"shaft_alignment":1.0}
	model._apply_contact(contact)
	check(target.ko and not target.unseated,"Incapacity initially stays mounted: "+str(c.name))
	target.seat_offset=float(c.offset);target.seat_velocity=signf(float(c.offset))*24.0
	model._finish("terminal")
	b._consume_events(model.drain_events());b._update_views()
	# Use the actual engine physics loop after terminal contact. Advancing
	# once per screenshot-loop iteration drops steps during PNG readback and
	# cannot establish whether the production collapse finishes in time.
	b.set_physics_process(true)
	var started=Time.get_ticks_msec();var timeline=[];var frames=[];var next_frame=0
	var capture_ms=[] if capture_dir=="none" else [100,500,1000,1700,2600]
	while Time.get_ticks_msec()-started<6000:
		await process_frame;await RenderingServer.frame_post_draw
		var elapsed=Time.get_ticks_msec()-started
		check(b.riders[int(c.defender)].visible,"Mounted renderer node remains available: "+str(c.name))
		timeline.append({"ms":elapsed,"slump":target.slump,"unseated":target.unseated,"seat_offset":target.seat_offset,"bodies":b.effects.bodies.size(),"scale":Engine.time_scale,"finished":b.is_finished})
		if next_frame<capture_ms.size() and elapsed>=capture_ms[next_frame]:
			frames.append(save_frame(str(c.name)+"_"+str(capture_ms[next_frame])));next_frame+=1
		if b.is_finished:break
	var expects_slip=absf(float(c.offset))>20
	check(b.effects.bodies.size()==(1 if expects_slip else 0),"Physical body is spawned only for an actual support loss: "+str(c.name))
	check(b.is_finished and is_equal_approx(Engine.time_scale,1.0),"Settlement completes and releases time: "+str(c.name))
	if capture_dir=="none" and not expects_slip:check(float(target.slump)>.90,"Actual engine physics shows mounted collapse before settlement: "+str(c.name))
	check(target.dead==(str(c.mode)=="war"),"Incapacity preserves arena nonfatal rule: "+str(c.name))
	var summary=load("res://scripts/ui/combat_report.gd").summarize(b.exchange_log,str(c.mode))
	if not expects_slip:check(not summary.contains("落马"),"Mounted result does not falsely report a fall: "+str(c.name))
	main.show_result();await process_frame;await RenderingServer.frame_post_draw
	if capture_dir!="none":frames.append(save_frame(str(c.name)+"_result"))
	check(main.pending_result.get("player_unseated" if int(c.defender)==0 else "enemy_unseated")==expects_slip,"Result snapshot includes post-incapacity physical slip: "+str(c.name))
	report.battle.append({"fixture":c,"contact":contact,"summary":summary,"timeline":timeline,"frames":frames})
	main._close_battle();await process_frame
