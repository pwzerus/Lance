extends "test_fall_v057.gd"
## Actual mounted renderer after low-impulse incapacitation; isolated GPU.
func run() -> void:
	var folder=""
	var region="eng";var tier_start=0;var pace=240.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
		elif arg.begins_with("--region="):region=arg.trim_prefix("--region=")
		elif arg.begins_with("--tier-start="):tier_start=int(arg.trim_prefix("--tier-start="))
		elif arg.begins_with("--pace="):pace=float(arg.trim_prefix("--pace="))
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or DisplayServer.get_name()=="headless" or not "qa_" in root.get_node("GameState").save_path:quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1440,960);root.content_scale_size=root.size
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	RenderingServer.set_default_clear_color(Color("21382f"))
	var items=Catalogue.load_items();var actors=[];var models=[];var traces=[]
	for index in range(6):
		var tier=tier_start+index%3;var facing=1 if index<3 else -1
		var stats=Catalogue.stats(items,{"armor":region+"_armor_"+str(tier),"helmet":region+"_helmet_"+str(tier),"shield":region+"_shield_"+str(tier),"horse":"horse_bay","lance":"lance_ash","crest":"crest_bend"})
		var model=Model.new("arena",stats,stats,113);models.append(model)
		var f:Dictionary=model.fighters[1]
		f.direction=facing;f.x=0.0;f.lane_y=0.0;f.hp=1.0;f.speed=pace;f.lean=-.5;f.guard=.43;f.gait_moving=pace>0
		model.fighters[0].speed=240;model.fighters[0].aim=0.0;model.fighters[0].lance_stability=1.0
		model._apply_contact({"type":"hit","zone":"head","attacker":0,"defender":1,"speed":480.0,"head_incidence":.4,"position":Model.head_position(f)})
		check(f.ko and not f.unseated,"Low-health grazing hit ends combat without spawning a fall")
		var stage=Node2D.new();root.add_child(stage);stage.position=Vector2(240+(index%3)*480,415+(index/3)*465);stage.scale=Vector2.ONE*.85
		var floor_line=Line2D.new();floor_line.points=PackedVector2Array([Vector2(-260,12),Vector2(260,12)]);floor_line.default_color=Color("a99664");floor_line.width=2;stage.add_child(floor_line)
		var rider=Rider.new();rider.fighter=f;rider.mode="arena";rider.blood_enabled=false;rider.moving=pace>0;stage.add_child(rider);rider.set_process(false);actors.append(rider)
		var label=Label.new();label.text="Tier %d / facing %d"%[tier,facing];label.position=Vector2(24+(index%3)*480,15+(index/3)*465);root.add_child(label)
		traces.append({"region":region,"tier":tier,"facing":facing,"samples":[]})
	for tick in range(301):
		for i in range(6):
			var f:Dictionary=models[i].fighters[1]
			if tick>0:
				Model.advance_reaction(f,1.0/120)
				f.gait_phase+=TAU*Model.Gait.frequency(f.speed)/120.0
				actors[i]._process(1.0/120)
			if tick%12==0:
				var pose=Rider.arm_pose(f)
				var head=Rider.head_transform(pose,f)
				check(head.origin.is_finite() and Model.rider_origin(f).is_finite(),"Finite mounted incapacitated pose")
				var fit=Rider.HeadFit.layout(f.stats)
				var face:Rect2=fit.face
				var jaw=(head*Vector2(face.get_center().x,face.end.y))*Vector2(int(f.direction),1)
				var crest=Model.HorseSurface113.crest_points(actors[i]._visual_body())
				var gap=Model.HorseSurface113.crest_height(crest,jaw.x)-jaw.y
				if float(f.slump)>.95:check(gap>=-5.0,"Jaw remains above the horse's support surface: "+region+str(traces[i].tier)+"/"+str(f.direction)+" gap="+str(gap))
				traces[i].samples.append({"time":tick/120.0,"slump":f.slump,"pose_angle":Model.pose_angle(f),"jaw_gap":gap,"head_origin":[head.origin.x,head.origin.y],"aim":f.aim,"guard":f.guard,"ko":f.ko,"unseated":f.unseated})
		if tick in [0,24,60,120,180,300]:
			await process_frame;await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(folder+"/frame_%03d.png"%tick)==OK,"Slumped mounted pose capture saves")
	for i in range(6):actors[i].get_parent().free()
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":traces,"scope":"Six mounted low-health glance fixtures, actual shared Model/Rider transforms and three equipment tiers, both directions. GPU frames for neck/helmet/horse/arm inspection; no Battle camera or human gameplay."},"\t"))
	print("SLUMP113 ",failures);quit(0 if failures.is_empty() else 1)
