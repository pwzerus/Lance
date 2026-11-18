extends "test_impact097.gd"
## Actual swept KO fixtures, isolated rendered camera checks. Captures excluded
## from timing claims; same external script also runs against the old PCK.
func run_timing() -> void:
	super.run_timing()
	for hz in [30,60,120]:
		var context={"phase":"ended","pass_id":1,"slow_motion":true}
		var hit={"type":"hit","zone":"head","attacker":0,"defender":1,"position":Vector2(0,-220),"impulse":90.0,"ko":true}
		for duration in [.3,.8,1.5,2.6,3.1]:
			var a=Exchange.new();var b=Exchange.new()
			a.notify_contacts([hit]);b.notify_contacts([hit])
			var remaining=duration
			while remaining>0.00000001:
				var dt=minf(1.0/hz,remaining)
				a.advance(dt,context);remaining-=dt
			var expected=b.advance(duration,context)
			check(absf(float(a.sample().scale)-float(expected.scale))<.00001,"KO clock partition invariance")
		var director=Exchange.new();director.notify_contacts([hit])
		var held=director.advance(.45,context)
		check(held.state=="read" and held.scale<.16,"KO begins with deeper readable slow motion")
		director.set_paused(true)
		check(director.advance(3,context)==held.merged({"paused":true},true),"Pause does not spend KO budget")
		director.set_paused(false)
		var late=director.advance(.65,context)
		check(late.state=="read" and late.scale>.20 and late.scale<.33,"Flight progresses before release")
		check(not director.advance(.7,context).impact_active,"KO presentation releases within 1.8 real seconds")
		context.slow_motion=false
		check(is_equal_approx(float(director.advance(.14,context).scale),1.0),"Disabling slow motion exits promptly")
		director.reset()
		check(is_equal_approx(float(director.sample().scale),1.0),"Restart resets KO clock")
func run_battle() -> void:
	var state=root.get_node("GameState")
	state.profile=state.default_profile()
	state.profile.settings.sound=true
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1440,810)
	root.content_scale_size=Vector2i(1440,810)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	report.battle=[]
	for c in [
		{"name":"right_body","attacker":0,"zone":"body","att":480.0,"def":480.0,"gap":950.0,"ko":true},
		{"name":"left_head","attacker":1,"zone":"head","att":480.0,"def":480.0,"gap":950.0,"ko":true},
		{"name":"double_body","attacker":0,"zone":"body","att":480.0,"def":480.0,"gap":950.0,"ko":true,"double":true},
		{"name":"no_slow","attacker":1,"zone":"body","att":480.0,"def":150.0,"gap":950.0,"ko":true,"slow":false}]:
		await run_battle_case(c)
	main._close_battle()
	main.queue_free()
	await process_frame
	await process_frame

func start_case() -> void:
	main._start_match("arena",true)

func after_result(_case: Dictionary, _battle: Node) -> void:
	pass

func run_battle_case(c: Dictionary) -> void:
	var state=root.get_node("GameState")
	state.profile.settings.slow_motion=c.get("slow",true)
	state.profile.settings.shake=true
	start_case()
	var b=main.battle
	check(is_instance_valid(b),"Fixture starts an actual battle: "+str(c.name))
	if not is_instance_valid(b): return
	b.set_physics_process(false)
	b.set_process_input(false)
	b.set_process_unhandled_input(false)
	if root.focus_exited.is_connected(b._on_focus_lost):root.focus_exited.disconnect(b._on_focus_lost)
	while not b.presentation_ready:await process_frame
	var attacker=int(c.attacker)
	prepare(b.match_model,attacker,str(c.zone),c)
	if c.get("double",false):
		for f in b.match_model.fighters:
			f.acted=false;f.hp=1.0;f.shield=0.0
	b._update_views()
	var contact_at=-1
	var started=Time.get_ticks_msec()
	var hits=[];var timeline=[];var frames=[];var cropped=0
	var captures=[] if capture_dir=="none" else [120,650,1400,2200,3200,4100]
	var capture_index=0
	var pause_tested=false
	while Time.get_ticks_msec()-started<15000:
		await physics_frame
		if b.match_model.phase=="charge":
			var dt=Engine.time_scale/float(Engine.physics_ticks_per_second)
			for i in range(2):
				var f=b.match_model.fighters[i]
				b.match_model.set_controls(i,aim_at(b.match_model,i,str(c.zone)) if not f.acted else f.aim,0.0,f.boost,dt,.43)
			b.match_model.time_effect_active=b.exchange_state.impact_active
			b.match_model.step(dt)
			var events=b.match_model.drain_events()
			if c.get("double",false) and events.filter(func(e):return e.type=="hit").size()==1:
				# Deliberate paired-contact presentation fixture, not a claim that two
				# asymmetric 3/4-view sweeps necessarily land on the same physics tick.
				var first={}
				for e in events:
					if e.type=="hit":first=e
				var other=first.duplicate(true)
				other.attacker=1-int(first.attacker);other.defender=1-int(first.defender)
				other.position=zone_point(b.match_model.fighters[other.defender],str(c.zone))
				other.attacker_direction=-int(first.get("attacker_direction",1))
				other.defender_direction=-int(first.get("defender_direction",-1))
				var paired_attacker=b.match_model.fighters[int(other.attacker)]
				var paired_defender=b.match_model.fighters[int(other.defender)]
				other.break_hand=Model.hand_position(paired_attacker)
				other.break_direction=int(paired_attacker.direction)
				other.break_angle=float(paired_attacker.aim)
				other.break_reach=float(paired_attacker.stats.get("reach",247.0))
				other.break_tip=Vector2(other.break_hand)+Vector2(cos(other.break_angle)*other.break_direction,sin(other.break_angle))*other.break_reach
				other.break_hand_velocity=Vector2(paired_attacker.direction*paired_attacker.speed,paired_attacker.get("mount_velocity_y",0.0))
				other.break_angular_velocity=0.0
				other.attacker_speed=float(paired_attacker.speed)
				other.defender_speed=float(paired_defender.speed)
				other.defender_ground_y=float(paired_defender.lane_y)+12.0
				b.match_model.fighters[other.defender].ko=true
				b.match_model.fighters[other.defender].hp=0.0
				events=events.filter(func(e):return e.type!="end")
				events.append(other)
				b.match_model._finish("terminal")
				events.append_array(b.match_model.drain_events())
			b._consume_events(events)
			for e in events:
				if e.type=="hit":
					hits.append(e.duplicate(true))
					if contact_at<0:contact_at=Time.get_ticks_msec()
			b._update_views()
		await process_frame
		if contact_at<0:continue
		var since=Time.get_ticks_msec()-contact_at
		await RenderingServer.frame_post_draw
		for rider in b.riders:
			check(rider.visible and is_equal_approx(rider.modulate.a,1.0),"Mounted rider never fades out during KO: "+str(c.name))
		var rects=[]
		for body in b.effects.bodies:
			check(body.visual.visible and is_equal_approx(body.visual.modulate.a,1.0),"Detached rider remains visible through KO: "+str(c.name))
			var r: Rect2=body.world_body_rect()
			var t=b.world.get_canvas_transform()
			var screen_rect=Rect2(t*r.position,r.size*b.camera.zoom)
			rects.append({"world":str(r),"screen":str(screen_rect),"age":body.age,"grounded":body.grounded,"settled":body.settled})
			if not b.combat_safe_rect().grow(3).encloses(screen_rect):cropped+=1
		timeline.append({"ms":since,"scale":Engine.time_scale,"zoom":b.camera.zoom.x,"state":b.exchange_state.state,"body_count":b.effects.bodies.size(),"rects":rects,"finished":b.is_finished})
		if capture_index<captures.size() and since>=captures[capture_index]:
			frames.append(save_frame(str(c.name)+"_"+str(captures[capture_index])))
			capture_index+=1
		if not pause_tested and since>750 and c.name=="right_body":
			var age=b.effects.bodies[0].age if not b.effects.bodies.is_empty() else -1.0
			var scale_before=Engine.time_scale
			b._toggle_pause()
			var until=Time.get_ticks_msec()+180
			while Time.get_ticks_msec()<until:await process_frame
			check(b.paused and is_equal_approx(b.effects.bodies[0].age,age),"Pause preserves fall pose")
			b._toggle_pause()
			check(is_equal_approx(Engine.time_scale,scale_before),"Resume restores cinematic scale")
			contact_at+=180
			pause_tested=true
		if b.is_finished or since>7000:break
	check(not hits.is_empty(),"Actual sweep reaches contact: "+str(c.name))
	check(cropped==0,"Detached body remains inside HUD-safe view: "+str(c.name))
	check(b.effects.bodies.size()==(2 if c.get("double",false) else 1),"Expected fall count: "+str(c.name))
	check(b.is_finished and is_equal_approx(Engine.time_scale,1.0),"Result restores time after fall: "+str(c.name))
	check(not timeline.is_empty() and int(timeline[-1].ms)<=3900,"Result follows KO within shortened budget: "+str(c.name))
	report.battle.append({"case":c,"hits":hits,"timeline":timeline,"frames":frames,"cropped_frames":cropped})
	await after_result(c,b)
	main._close_battle()
	check(is_equal_approx(Engine.time_scale,1.0),"Exit restores time: "+str(c.name))
	await process_frame
