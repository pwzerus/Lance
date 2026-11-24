extends "test_incapacity113.gd"
## Existing Battle draws intact/damaged/broken shields and real-time fragments.
func run_battle() -> void:
	var state=root.get_node("GameState");state.profile=state.default_profile()
	root.size=Vector2i(1440,810);root.content_scale_size=root.size;root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);main.set_process(false)
	report.battle=[]
	for q in [0,2,4,5]:
		for defender in [0,1]:await shield_case(q,defender)
	main._close_battle();main.queue_free();await process_frame;await process_frame

func shield_case(quality: int,defender: int) -> void:
	var state=root.get_node("GameState")
	var items=load("res://scripts/core/catalogue.gd").load_items()
	state.profile.equipped.shield="eng_shield_"+str(quality)
	main._start_match("arena",true)
	var b=main.battle;b.set_physics_process(false);b.set_process_input(false)
	if root.focus_exited.is_connected(b._on_focus_lost):root.focus_exited.disconnect(b._on_focus_lost)
	while not b.presentation_ready:await process_frame
	b.set_process(false)
	var model=b.match_model;model.phase="charge";model.drain_events()
	for index in range(2):
		var f=model.fighters[index]
		f.x=-150.0 if index==0 else 150.0;f.speed=240.0;f.boost=false;f.gait_moving=true;f.gait_phase=.7+index
		f.aim=0.0;f.lance_stability=1.0;f.acted=true;f.lean=0.0
	var f:Dictionary=model.fighters[defender]
	var item=load("res://scripts/core/catalogue.gd").find(items,"eng_shield_"+str(quality))
	f.stats.merge(item.stats,true);f.stats.shield_heraldry=item.id
	var name="q"+str(quality)+"_d"+str(defender);var frames=[]
	for condition in [1.0,.65,.24]:
		f.shield=float(f.stats.shield_capacity)*condition
		b._update_views();b._update_hud();b._update_camera(1,Time.get_ticks_msec())
		await process_frame;await RenderingServer.frame_post_draw
		frames.append(save_frame(name+"_condition"+str(roundi(condition*100))))
	f.shield=10.0
	var contact={"type":"hit","zone":"shield","attacker":1-defender,"defender":defender,"speed":480.0,"position":Model.shield_position(f),"combat_elevation":0.0,"shaft_alignment":1.0,"eccentricity":0.0,"shield_region":"center","lever":0.0}
	model._apply_contact(contact);model.drain_events()
	b._consume_events([contact]);b._update_views();b._update_hud()
	# This fixture freezes Battle's camera clock to inspect the exact mesh.
	# Do not leave its first hit-stop active while measuring fragment life.
	Engine.time_scale=1.0
	check(contact.shield_broke and f.shield==0 and not f.unseated,"Half-speed finishing strike breaks existing damaged shield without launching rider")
	check(b.effects.shield_fragments113.size()==4,"Four silhouette fragments replace the broken face: "+name)
	var initial=[]
	for part in b.effects.shield_fragments113:initial.append({"center":part.p,"vertices":part.polygon})
	await process_frame;await RenderingServer.frame_post_draw
	frames.append(save_frame(name+"_break"))
	var started=Time.get_ticks_msec();var next_frame=0
	while not b.effects.shield_fragments113.is_empty() and Time.get_ticks_msec()-started<10000:
		await process_frame;await RenderingServer.frame_post_draw
		if next_frame<3 and Time.get_ticks_msec()-started>=[180,450,1100][next_frame]:
			frames.append(save_frame(name+"_fragments"+str(next_frame)));next_frame+=1
	check(b.effects.shield_fragments113.is_empty(),"Fragments expire after their game-time lifetime; capture overhead is not simulation time")
	report.battle.append({"quality":quality,"defender":defender,"contact":contact,"frames":frames,"initial_fragments":initial})
	main._close_battle();await process_frame
