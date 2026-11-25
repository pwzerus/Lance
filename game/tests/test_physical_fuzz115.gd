extends "test_support115.gd"
## Vary real mounted bodies, then apply contact-point impulses and transfer
## the SAME body on actual loss of support. Legacy fuzz105 reconstructs a
## launched falling body and remains a separate compatibility regression.
const Catalogue115=preload("res://scripts/core/catalogue.gd")
const Campaign115=preload("res://scripts/core/campaign.gd")
func run() -> void:
	var path="";var first=0;var count=64;var selected=[];var folder="";var solver=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
		if arg.begins_with("--solver="):solver=arg.trim_prefix("--solver=")
		if arg.begins_with("--ids="):
			for number in arg.trim_prefix("--ids=").split(","):selected.append(int(number))
		if arg.begins_with("--report="):path=arg.trim_prefix("--report=")
		if arg.begins_with("--first="):first=int(arg.trim_prefix("--first="))
		if arg.begins_with("--count="):count=clampi(int(arg.trim_prefix("--count=")),1,128)
	if path.is_empty() or FileAccess.file_exists(path) or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	if not folder.is_empty():
		if DisplayServer.get_name()=="headless" or DirAccess.dir_exists_absolute(folder):quit(2);return
		DirAccess.make_dir_recursive_absolute(folder);root.size=Vector2i(1280,720);root.content_scale_size=root.size
		RenderingServer.set_default_clear_color(Color("21382f"))
	var items=Catalogue115.load_items();var rows=[];var releases=0
	for id in range(first,first+count):
		if not selected.is_empty() and id not in selected:continue
		var rng=RandomNumberGenerator.new();rng.seed=115400+id
		var level=Campaign115.level(items,1+(id*17)%80)
		var stats=Catalogue115.stats(items,level.equipment)
		var model=Model.new("war",stats,stats,115400+id)
		var f:Dictionary=model.fighters[0];var facing=1 if id%2==0 else -1
		f.x=1000.0 if id%4<2 else -1000.0;f.lane_y=32.0 if facing>0 else -32.0;f.direction=facing
		f.speed=rng.randf_range(180,460);f.gait_moving=true;f.gait_phase=rng.randf_range(0,TAU)
		f.lean=rng.randf_range(-1,1);f.guard=rng.randf_range(0,1);f.aim=rng.randf_range(-.6,.5)
		var zone=["head","body","flank","shield"][id%4]
		var force=rng.randf_range(45,125)
		model._ensure_body115(0)
		if not solver.is_empty():model.bodies115[0].body=load("res://tests/test_solver_pair115.gd").clone_body115(model.bodies115[0].body,load(solver))
		var stage=Node2D.new();root.add_child(stage)
		var rider=null
		if not folder.is_empty():
			rider=load("res://scripts/visual/rider_view.gd").new();rider.fighter=f;stage.add_child(rider);rider.set_process(false)
			stage.scale=Vector2.ONE*1.25;stage.position.y=600
			var floor_line=Line2D.new();floor_line.points=PackedVector2Array([Vector2(-10000,f.lane_y+12),Vector2(10000,f.lane_y+12)]);floor_line.width=1;floor_line.default_color=Color("ad9b65");stage.add_child(floor_line)
		var actor=null;var detach=-1.0;var settled_at=-1.0;var gap=0.0;var bone_error=0.0
		var impulse={};var transfer_error=0.0;var trace=[]
		for tick in range(900):
			if tick==144 and actor==null:
				var physical=model.bodies115[0]
				impulse={"zone":zone,"position":point_for(physical.body,zone,id%3==0),"direction":-facing,"impulse":force,"defender_speed":f.speed,"ko_reason":"impact"}
				physical.queue_hit(impulse)
				if id%3==0:f.unconscious=true;f.ko=true
			f.x+=float(f.speed)*facing/120.0
			f.gait_phase+=TAU*Model.Gait.frequency(float(f.speed))/120.0
			if actor==null:
				model._advance_body115(0,1.0/120.0)
				var physical=model.bodies115[0]
				if physical.detached:
					detach=(tick+1)/120.0;releases+=1
					if tick<144:failures.append("Calm rider lost support before impact: "+str(id))
					var same_body=physical.body;var old_points=same_body.p.duplicate();var old_velocity=same_body.vel.duplicate()
					var payload=model.take_body115(0)
					actor=Fallen.new();stage.add_child(actor);actor.setup(f,impulse,null,payload)
					actor.set_process(false);actor.visual.set_process(false);actor.far_leg.set_process(false)
					if actor.body!=same_body:failures.append("Ownership changed body identity: "+str(id))
					for i in range(Body.COUNT):transfer_error=maxf(transfer_error,maxf(old_points[i].distance_to(actor.body.p[i]),old_velocity[i].distance_to(actor.body.vel[i])))
			else:
				actor.advance(1.0/120.0)
				if tick%30==0:
					var values={}
					for name in ["near_hip","far_hip","near_knee","far_knee","left_upper","right_upper","left_elbow","right_elbow"]:values[name]=actor.body.flex(name)
					trace.append({"age":actor.age,"angle":actor.rotation,"gap":actor.support_gap(),"flex":values,"chest_contact":actor.body.chest_contact115,"pelvis_contact":actor.body.pelvis_contact115,"rest":actor.body.rest,"points":Array(actor.body.p),"velocities":Array(actor.body.vel),"contacts":actor.body.contacts.keys()})
				for bone in actor.body.bones:bone_error=maxf(bone_error,absf(actor.body.end_position(bone[0]).distance_to(actor.body.p[bone[1]])-float(bone[2])))
				if actor.settled:
					settled_at=actor.age;gap=actor.support_gap();break
				if actor.age>=6.0:gap=actor.support_gap();break
			if not folder.is_empty() and tick%30==0:
				rider.position=Vector2(f.x,f.lane_y);rider._process(1.0/120.0)
				stage.position.x=640-(actor.position.x if actor!=null else float(f.x))*1.25
				await process_frame;await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(folder+"/case%03d-t%03d.png"%[id,tick])
		var raised=actor._unsupported_leg115() if actor!=null else false
		if transfer_error>.001:failures.append("Transfer position/velocity jump: "+str(id))
		if actor!=null and (settled_at<0 or settled_at>4.0+.00001):failures.append("Four-second shared-body rest: "+str(id))
		if raised or (actor!=null and gap>14):failures.append("Unsupported shared-body pose: "+str(id))
		rows.append({"id":id,"level":level.number,"zone":zone,"force":force,"facing":facing,"equipment":level.equipment,"detach_time":detach,"settled_at":settled_at,"final_gap":gap,"unsupported_leg":raised,"transfer_error":transfer_error,"raw_bone_error":bone_error,"unconscious":f.unconscious,"trace":trace})
		stage.free()
		if (id-first)%8==7:FileAccess.open(path+".partial",FileAccess.WRITE).store_string(JSON.stringify({"cases":rows,"failures":failures},"\t"))
	if releases==0:failures.append("Fixture produced no actual releases")
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":rows,"releases":releases,"scope":"Protected deterministic mounted-body impulse fixtures with campaign gear/lean/aim/guard/stride phase and alternating consciousness; no HP damage or manual launch/forced rest, no rendered or human acceptance."},"\t"))
	quit(0 if failures.is_empty() else 1)
