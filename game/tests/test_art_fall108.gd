extends SceneTree
## Controlled detached-rider render study. Actual campaign matches separately
## check the normal contact/camera path; this fixture isolates outfit continuity.
const Model=preload("res://scripts/core/joust_match.gd")
const Rider=preload("res://scripts/visual/rider_view.gd")
const Fallen=preload("res://scripts/visual/fallen_rider.gd")
const Catalogue=preload("res://scripts/core/catalogue.gd")
const Appearance=preload("res://scripts/core/character_appearance.gd")
var failures=[]
var rows=[]
var folder=""
func _initialize()->void:call_deferred("run")
func check(ok:bool,why:String)->void:
	if not ok and why not in failures:failures.append(why);push_error(why)
func run()->void:
	var region="eng"
	var only_tier=-1;var raw_frames=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
		if arg.begins_with("--region="):region=arg.trim_prefix("--region=")
		if arg.begins_with("--tier="):only_tier=int(arg.trim_prefix("--tier="))
		if arg=="--raw-frames":raw_frames=true
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or region not in ["eng","fr","de","it"] or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless" or not root.get_node("GameState").save_path.contains("qa_"):quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(640,480);root.content_scale_size=root.size
	RenderingServer.set_default_clear_color(Color("40504d"))
	var items=Catalogue.load_items()
	var caption=Label.new();caption.position=Vector2(130,82);caption.z_index=100;root.add_child(caption)
	for tier in range(6):
		if only_tier>=0 and tier!=only_tier:continue
		var sheet=Image.create_empty(6*384,6*300,false,Image.FORMAT_RGBA8)
		var row=0
		for facing in [1,-1]:
			for zone in ["head","body","flank"]:
				var kit=Catalogue.stats(items,{"helmet":"%s_helmet_%d"%[region,tier],"armor":"%s_armor_%d"%[region,tier],"shield":region+"_shield_2","lance":region+"_lance_long_2","crest":"crest_lion"})
				kit.appearance=Appearance.variant(tier*409+row*211+10801)
				var model=Model.new("war",kit,kit,10801)
				var f=model.fighters[0 if facing==1 else 1]
				f.x=0.0;f.lane_y=0.0;f.speed=480.0;f.gait_moving=true;f.gait_phase=.8
				f.lean=1.0 if zone=="head" else (-1.0 if zone=="flank" else 0.0)
				f.guard=.43;f.aim=-.15
				var before=Rider.head_transform(Rider.arm_pose(f),f)
				var holder=Node2D.new();holder.scale=Vector2.ONE*.8;root.add_child(holder)
				var floor_line=Line2D.new();floor_line.points=PackedVector2Array([Vector2(-3000,12),Vector2(3000,12)]);floor_line.default_color=Color("89927a");floor_line.width=1;holder.add_child(floor_line)
				var actor=Fallen.new();holder.add_child(actor)
				actor.setup(f,{"zone":zone,"direction":-facing,"impulse":100.0,"attacker_speed":480.0,"defender_speed":480.0})
				actor.visual.mode="war";actor.far_leg.mode="war"
				actor.set_process(false);actor.visual.set_process(false);actor.far_leg.set_process(false)
				actor._update_pose()
				var after=actor.transform*Rider.head_transform(actor.visual.detached_pose,actor.fighter)
				var snap=0.0
				for point in [Vector2(0,-111),Vector2(-20,-145),Vector2(20,-100)]:snap=maxf(snap,(before*point).distance_to(after*point))
				check(snap<.02,"Head snapped at detachment "+region+str(tier)+str(facing)+zone)
				var frame_index=0;var stamps=[0,12,36,84,180,600];var maximum_neck=0.0
				for tick in range(601):
					if tick>0:actor.advance(1.0/120.0)
					# The isolated pose study has no physics ground. The production
					# released weapon is tested by release105 and real match scenes;
					# exclude it here rather than inventing a second flight clock.
					if is_instance_valid(actor.loose_lance):actor.loose_lance.freeze=true;actor.loose_lance.visible=false
					if tick>=36:
						check(not actor.visual.detached_lance_visible,"Released weapon still held by detached renderer")
						check(is_instance_valid(actor.loose_lance) and not actor.loose_lance.is_visible_in_tree(),"Excluded released weapon is visible in pose fixture")
					check(actor.fighter.stats.appearance==kit.appearance and actor.visual.fighter.stats.appearance==kit.appearance,"Detached face changed")
					check(actor.position.is_finite() and is_finite(actor.rotation),"Nonfinite fallen pose")
					var neck=Rider.neck_geometry(actor.visual.detached_pose,actor.fighter)
					maximum_neck=maxf(maximum_neck,Vector2(neck.base).distance_to(neck.top))
					if tick in stamps:
						var local_center=holder.to_local(actor.world_body_rect().get_center())
						holder.position=Vector2(320,240)-local_center*.8
						caption.text="%s %d / %s / %d / %.2fs"%[region,tier,zone,facing,tick/120.0]
						actor.visual.queue_redraw();actor.far_leg.queue_redraw()
						await process_frame;await RenderingServer.frame_post_draw
						var frame=root.get_texture().get_image()
						if raw_frames:frame.save_png(folder+"/raw-%s-%d-%d-%s-%d.png"%[region,tier,facing,zone,tick])
						sheet.blit_rect(frame,Rect2i(128,80,384,300),Vector2i(frame_index*384,row*300));frame_index+=1
				check(maximum_neck<52,"Unbounded detached neck")
				check(actor.grounded and actor.settled and actor.support_gap()<14.0,"Outfit fall failed to settle "+region+str(tier)+str(facing)+zone)
				rows.append({"region":region,"tier":tier,"facing":facing,"zone":zone,"appearance":kit.appearance,"zero_time_head_error":snap,"maximum_neck":maximum_neck,"settled":actor.settled,"grounded":actor.grounded,"support_gap":actor.support_gap()})
				holder.queue_free();await process_frame;row+=1
		sheet.save_png(folder+"/fall-%s-%d.png"%[region,tier])
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"Controlled detached outfit sequence, zero-time registration and stable identity; real GPU frames from fixed 120Hz stepping. Recentered crop excludes the released weapon and is not the actual match camera; no OS input/human feel acceptance."},"\t"))
	print("ART108 FALL ",region," failures=",failures.size());quit(0 if failures.is_empty() else 1)
