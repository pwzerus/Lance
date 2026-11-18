extends SceneTree
## Motion study: production limited controls and renderer pose snapshots.
## Captures are evidence for review, not a numeric claim of human quality.
const Model=preload("res://scripts/core/joust_match.gd")
const Rider=preload("res://scripts/visual/rider_view.gd")
const Catalogue=preload("res://scripts/core/catalogue.gd")
const Campaign=preload("res://scripts/core/campaign.gd")
const UI=preload("res://scripts/ui/ui_factory.gd")
var folder=""
var failures=[]
var records=[]
var expect_grip=false
var study_prefix=""

func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	if not ok and message not in failures:failures.append(message);push_error(message)

func render_study(samples:Array,label:String)->void:
	var page=Control.new();root.add_child(page)
	page.theme=UI.theme()
	var backdrop=ColorRect.new();backdrop.size=Vector2(1440,900);backdrop.color=Color("14231c");page.add_child(backdrop)
	UI.label(page,label+" · 连续控制采样，非游戏界面",Vector2(20,12),22,UI.GOLD)
	for i in range(samples.size()):
		var cell=UI.panel(page,Rect2(12+(i%3)*474,52+(i/3)*418,462,406));cell.clip_contents=true
		var s:Dictionary=samples[i]
		UI.label(cell,"%.2fs / 速度%.0f / 枪%.2f / 盾%.2f"%[s.time,s.fighter.speed,s.fighter.aim,s.fighter.guard],Vector2(10,9),16,UI.GOLD)
		var view=Rider.new();view.fighter=s.fighter.duplicate(true);view.fighter.x=0.0;view.fighter.lane_y=0.0
		view.position=Vector2(230,365);view.scale=Vector2.ONE*.85;view.moving=s.moving
		view.leg_poses=s.legs.duplicate(true);view.visual_pose=s.body.duplicate(true);view.stride_phase=float(s.fighter.gait_phase)
		cell.add_child(view);view.set_process(false)
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+label+".png")==OK,"Motion capture saved")
	page.queue_free();await process_frame

func study(kind:String,facing:int,kit:Dictionary)->void:
	var model=Model.new("arena",kit,kit,10501)
	model.phase="charge";model.fighters[0].x=-50000;model.fighters[1].x=50000
	for member in model.fighters:member.acted=true
	var index=0 if facing==1 else 1
	var f:Dictionary=model.fighters[index]
	f.aim=-.08;f.guard=.43;f.guard_target=.43;f.speed=0.0;f.gait_moving=false
	var rider=Rider.new();rider.fighter=f;root.add_child(rider);rider.set_process(false)
	var duration=8.0 if kind=="ride" else 3.0
	var stamps=[.15,1.0,2.5,4.0,5.5,7.9] if kind=="ride" else [.05,.35,.8,1.25,1.8,2.9]
	var samples=[];var points=[];var previous={};var max_step=0.0
	var hand_min=INF;var hand_max=-INF
	for tick in range(int(duration*120)):
		var time=tick/120.0
		var aim=-.58 if time<1.25 else .50
		var guard=.43;var lean=0.0
		if kind=="guard":guard=1.0 if time<1.25 else 0.0;aim=-.08
		if kind=="lean":lean=-1.0 if time<1.25 else 1.0;aim=-.08
		if kind=="ride":aim=-.08
		model.set_controls(index,aim,lean,kind=="ride" and time<4,1.0/120,guard)
		if kind=="ride":model.step(1.0/120)
		else:Model.advance_unsteady(f,1.0/120,false)
		rider.position=Vector2(f.x,0);rider.moving=kind=="ride";rider._process(1.0/120)
		var pose=Rider.arm_pose(f);var inv:Transform2D=pose.torso_transform.affine_inverse()
		var hand:Vector2=inv*Vector2(pose.right.hand)
		hand_min=minf(hand_min,hand.y);hand_max=maxf(hand_max,hand.y)
		var current={"head":Model.head_position(f),"hand":Model.hand_position(f),"elbow":pose.right.elbow,"shield":pose.left.hand}
		for joint in current:
			check(Vector2(current[joint]).is_finite(),"Finite joint: "+joint)
			if previous.has(joint):max_step=maxf(max_step,Vector2(current[joint]).distance_to(previous[joint]))
		previous=current
		if tick%6==0:points.append({"time":time,"aim":f.aim,"guard":f.guard,"speed":f.speed,"hand_local":str(hand),"right_elbow":str(inv*Vector2(pose.right.elbow)),"pose_angle":Model.pose_angle(f),"seat":str(Model.rider_origin(f)-Vector2(f.x,0))})
		if samples.size()<stamps.size() and time>=float(stamps[samples.size()]):
			samples.append({"time":time,"fighter":f.duplicate(true),"body":rider.visual_pose.duplicate(true),"legs":rider.leg_poses.duplicate(true),"moving":rider.moving})
	var span=hand_max-hand_min
	if expect_grip and kind=="aim":check(span>7 and span<28,"Aim uses a bounded forearm/grip arc")
	records.append({"coat":str(kit.get("horse_coat","bay")),"kind":kind,"facing":facing,"hand_vertical_span":span,"maximum_world_step":max_step,"samples":points})
	rider.queue_free();await process_frame
	await render_study(samples,study_prefix+kind+str(facing))

func run()->void:
	var coats=[];var kinds=["aim","guard","lean","ride"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
		if arg=="--expect-animated-grip":expect_grip=true
		if arg.begins_with("--coats="):coats=Array(arg.trim_prefix("--coats=").split(","))
		if arg.begins_with("--kinds="):kinds=Array(arg.trim_prefix("--kinds=").split(","))
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not "qa_" in state.save_path or DisplayServer.get_name()=="headless" or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1440,900);root.content_scale_size=Vector2i(1440,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var kit=Catalogue.stats(state.items,Campaign.level(state.items,2).equipment)
	if coats.is_empty():coats=[str(kit.get("horse_coat","bay"))]
	for coat in coats:
		check(coat in ["bay","black","flaxen","grey"],"Known shipped coat")
		kit["horse_coat"]=coat
		study_prefix=str(coat)+"_" if coats.size()>1 else ""
		for kind in kinds:
			check(kind in ["aim","guard","lean","ride"],"Known study type")
			for facing in [1,-1]:await study(kind,facing,kit)
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"records":records,"version":ProjectSettings.get_setting("application/config/version"),"coats":coats,"scope":"Coat-only visual variants, unchanged horse stats. Production controls/pose sampling and isolated GPU images; no OS input or human rating."},"\t"))
	print("MOTION105 ",failures)
	quit(0 if failures.is_empty() else 1)
