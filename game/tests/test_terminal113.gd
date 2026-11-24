extends "test_incapacity113.gd"
## Combination fixtures: actual Battle physics, bounded control requests and
## one terminal result. Paired injuries are controlled contacts, not sweeps.
var control113: Dictionary = {}

func input_tick113() -> void:
	if control113.is_empty(): return
	var b=control113.battle
	var p:Dictionary=control113.player
	var kind:String=control113.kind
	control113.peak=maxf(float(control113.peak),absf(float(p.seat_offset)))
	control113.support=minf(float(control113.support),float(p.seat_support))
	control113.stamina=minf(float(control113.stamina),float(p.stamina))
	if bool(control113.paired) or p.ko: return
	# Input belongs to every physics tick, independently of asynchronous PNG
	# readback/report sampling. A render-frame coroutine skips controls when
	# the engine catches up several physics ticks after a capture.
	var t=float(p.pose_clock113)
	var flailing=kind!="recover" or t<2.0
	var period=.30 if kind in ["small_corrections","rapid_full"] else .80
	var amplitude=.20 if kind=="small_corrections" else 1.0
	b.wheel_lean=amplitude*(1.0 if int(t/period)%2==0 else -1.0) if flailing else 0.0
	b.pointer_aim=(-.12 if int(t/.24)%2==0 else -.04) if kind=="small_corrections" else ((-.60 if int(t/.24)%2==0 else .50) if flailing else -.08)
	b.guard_slot=1 if kind=="small_corrections" else ((0 if int(t/.29)%2==0 else 2) if flailing else 1)

func run_battle() -> void:
	var state=root.get_node("GameState")
	state.profile=state.default_profile()
	state.profile.settings.sound=true;state.profile.settings.mouse_only=true
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1440,810);root.content_scale_size=root.size
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);main.set_process(false)
	report.battle=[]
	for kind in ["both_unconscious","mixed","recover","small_corrections","rapid_full","deep_flail"]:
		await combination(kind)
	main._close_battle();main.queue_free();await process_frame;await process_frame

func combination(kind: String) -> void:
	main._start_match("arena",true)
	var b=main.battle
	b.set_physics_process(false);b.set_process_input(false);b.set_process_unhandled_input(false)
	if root.focus_exited.is_connected(b._on_focus_lost):root.focus_exited.disconnect(b._on_focus_lost)
	while not b.presentation_ready:await process_frame
	var m=b.match_model
	m.rng.seed=113091;b.ai_rng.seed=113093
	m.phase="charge";m.drain_events()
	for index in range(2):
		var f=m.fighters[index]
		f.x=-1800.0 if index==0 else 1800.0
		f.speed=480.0 if kind in ["recover","small_corrections","rapid_full","deep_flail"] else 240.0
		f.gait_moving=true;f.gait_phase=.8+index;f.pose_clock113=0.0
		f.acted=true;f.aim=0.0;f.lean=0.0;f.lance_stability=1.0
	var p:Dictionary=m.fighters[0]
	var paired=kind in ["both_unconscious","mixed"]
	if paired:
		for index in range(2):
			var f=m.fighters[index];f.x=-140.0 if index==0 else 140.0;f.hp=1.0
			var e={"type":"hit","zone":"head","attacker":1-index,"defender":index,"speed":480.0,
				"head_incidence":.4,"position":Model.head_position(f),"combat_elevation":0.0,"shaft_alignment":1.0}
			m._apply_contact(e)
			check(f.unconscious and not f.unseated,"Paired weak contact incapacitates without launch")
		if kind=="mixed":
			p.seat_offset=22.8;p.seat_velocity=24.0
		m._finish("terminal")
		b._consume_events(m.drain_events())
	else:
		# Starts at a full charge to isolate repeated steering. Stamina and
		# arm strength then use normal drain/recovery; neither is replenished.
		b.mouse_held=true
	control113={"battle":b,"player":p,"kind":kind,"paired":paired,"peak":0.0,"support":1.0,"stamina":100.0}
	physics_frame.connect(input_tick113)
	b._update_views();b.set_physics_process(true)
	var start=Time.get_ticks_msec();var frames=[];var samples=[];var next_capture=0
	var moments=[150,600,1300,2200] if paired else [200,1500,3000,4500,6000]
	var peak_offset=0.0;var min_support=1.0;var min_stamina=100.0
	while Time.get_ticks_msec()-start<20000:
		await physics_frame
		var elapsed=(Time.get_ticks_msec()-start)/1000.0
		# Approach slow motion slows the finite body motion too. Schedule
		# full-weight movements by simulated pose time; a wall-clock timer
		# would reverse before the rider can actually reach the target lean.
		var control_time=float(p.pose_clock113)
		await process_frame
		samples.append({"seconds":elapsed,"simulation_seconds":control_time,"offset":p.seat_offset,"support":p.seat_support,"stamina":p.stamina,"speed":p.speed,"lean":p.lean,"unsteady":p.unsteady,"strain":p.seat_strain,"ko":p.ko,"bodies":b.effects.bodies.size(),"phase":m.phase})
		if capture_dir!="none" and next_capture<moments.size() and elapsed*1000>=moments[next_capture]:
			await RenderingServer.frame_post_draw
			frames.append(save_frame(kind+"_"+str(moments[next_capture])));next_capture+=1
		if b.is_finished or (kind in ["recover","small_corrections","deep_flail"] and control_time>6.0):break
	physics_frame.disconnect(input_tick113)
	peak_offset=float(control113.peak);min_support=float(control113.support);min_stamina=float(control113.stamina)
	control113.clear()
	if paired:
		check(m.result.winner==-1,"Both incapacitated yields one draw")
		check(b.effects.bodies.size()==(1 if kind=="mixed" else 0),"Only the unsupported member becomes a detached body")
		check(b.is_finished,"Paired terminal state reaches result")
	elif kind=="recover":
		check(not p.ko and float(p.seat_support)>.90,"Stopping repeated movement recovers without a strike")
	elif kind=="small_corrections":
		check(not p.unseated,"Small aim and posture corrections remain safe")
	elif kind=="deep_flail":
		# Different phases may rock back into support rather than cross its
		# edge. Require a physical warning, not an arbitrary fall per pattern.
		check(min_support<.35,"Repeated full-weight swings visibly threaten saddle support")
		check(b.effects.bodies.size()==(1 if p.unseated else 0),"Body creation follows actual loss of support")
	else:
		check(p.unseated and not p.unconscious and not p.dead,"Normal fatigue permits conscious loss of seat from sustained violent controls")
		check(float(p.hp)==100.0,"Self-unseating causes no invented weapon wound")
		check(b.effects.bodies.size()==1 and b.is_finished,"Self-unseating gets a visible body and result")
		check(b.exchange_log.filter(func(e):return e.type=="unseat").size()==1,"Self-unseating is logged once")
		var advice=load("res://scripts/ui/combat_report.gd").next_action(b.exchange_log,true,m.result)
		check(advice.contains("回正") and not advice.contains("受击"),"Self-unseating advice does not invent an incoming hit")
	if b.is_finished:
		check(is_equal_approx(Engine.time_scale,1.0),"Terminal combination releases the time scale")
		main.show_result();await process_frame;await RenderingServer.frame_post_draw
		if capture_dir!="none":frames.append(save_frame(kind+"_result"))
	report.battle.append({"kind":kind,"peak_offset":peak_offset,"minimum_support":min_support,"minimum_stamina":min_stamina,"samples":samples,"events":b.exchange_log.duplicate(true),"result":m.result.duplicate(true),"frames":frames})
	main._close_battle();await process_frame
