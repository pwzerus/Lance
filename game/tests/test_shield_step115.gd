extends "test_shield105.gd"
## Diagnose the first excessive angular step; captures raw and drawn bones.
## No gameplay mutation, statistical balance claim, or visual acceptance.

func snapshot115(actor) -> Dictionary:
	var b = actor.body
	var pose: Dictionary = actor.visual.detached_pose
	var shield: Transform2D = shield_frame(pose,actor.fighter)
	var display = b.display_points()
	var joints = {}
	for j in b.joints:
		joints[j.name] = {"value":b.range_flex(j),"lo":j.lo,"hi":j.hi}
	return {"age":actor.age,"theta":b.theta,"omega":b.omega,"grounded":actor.grounded,
		"contacts":b.contacts.keys(),"tone":b.tone,"shield_angle":shield.x.angle()+actor.rotation,
		"raw_arm":(b.p[b.HAND_L]-b.p[b.ELBOW_L]).angle(),
		"display_arm":(display[b.HAND_L]-display[b.ELBOW_L]).angle(),
		"arm_length":b.p[b.HAND_L].distance_to(b.p[b.ELBOW_L]),
		"joints":joints,"settled":actor.settled}

func run() -> void:
	var path = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--report="): path=a.trim_prefix("--report=")
	if path.is_empty() or FileAccess.file_exists(path) or OS.get_environment("GALUMU_MEMORY_BOUND").is_empty():
		quit(2)
		return
	var stats=Catalogue.stats(Catalogue.load_items(),{"armor":"de_armor_1","helmet":"de_helmet_1","shield":"de_shield_0","horse":"horse_bay","lance":"lance_ash"})
	var rows=[]
	for facing in [1,-1]:
		for zone in ["head","body","flank"]:
			for guard in [0.0,.43,1.0]:
				var m=Model.new("arena",stats,stats,105)
				var f=m.fighters[0]
				f.x=0.0;f.lane_y=0.0;f.direction=facing;f.lean=-.6;f.guard=guard;f.aim=-.2;f.speed=440;f.gait_moving=true
				var actor=Fallen.new()
				root.add_child(actor)
				actor.setup(f,{"zone":zone,"impulse":105,"direction":-facing})
				actor.set_process(false);actor.visual.set_process(false);actor.far_leg.set_process(false)
				var before=snapshot115(actor)
				var worst={"delta":0.0}
				var first={}
				for tick in range(480):
					actor.advance(1.0/120.0)
					var after=snapshot115(actor)
					var delta=absf(wrapf(float(after.shield_angle)-float(before.shield_angle),-PI,PI))
					if delta>float(worst.delta): worst={"delta":delta,"before":before,"after":after}
					if first.is_empty() and delta>.15: first={"delta":delta,"before":before,"after":after}
					before=after
				rows.append({"facing":facing,"zone":zone,"guard":guard,"first":first,"worst":worst})
				if is_instance_valid(actor.loose_lance):actor.loose_lance.free()
				actor.free()
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"scope":"Diagnostic raw/drawn angular step; no pass verdict"},"\t"))
	quit(0)
