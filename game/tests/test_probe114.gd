extends SceneTree
## PHYS-114 diagnostic: the shield105 fixture, per-step forearm turn relative
## to the trunk, with the contact state at the largest steps. No assertions.
const Model=preload("res://scripts/core/joust_match.gd")
const Fallen=preload("res://scripts/visual/fallen_rider.gd")
const Catalogue=preload("res://scripts/core/catalogue.gd")

func _initialize()->void:call_deferred("run")

func run()->void:
	var path=""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--report="):path=a.trim_prefix("--report=")
	var stats=Catalogue.stats(Catalogue.load_items(),{"armor":"de_armor_1","helmet":"de_helmet_1","shield":"de_shield_0","horse":"horse_bay","lance":"lance_ash"})
	var out=[]
	for facing in [1,-1]:
		for zone in ["head","body"]:
			var m=Model.new("arena",stats,stats,105);var f=m.fighters[0]
			f.x=0.0;f.lane_y=0.0;f.direction=facing;f.lean=-.6;f.guard=1.0;f.aim=-.2;f.speed=440;f.gait_moving=true
			var actor=Fallen.new();root.add_child(actor)
			actor.setup(f,{"zone":zone,"impulse":105,"direction":-facing})
			actor.set_process(false);actor.visual.set_process(false);actor.far_leg.set_process(false)
			var last=actor.visual.detached_pose.shield_transform.x if actor.visual.detached_pose.has("shield_transform") else Vector2.ZERO
			var rows=[]
			for tick in range(480):
				actor.advance(1.0/120)
				var t: Transform2D=actor.visual.detached_pose.shield_transform
				var turn=absf(last.angle_to(t.x)) if last!=Vector2.ZERO else 0.0
				last=t.x
				if turn>.12:
					rows.append({"age":actor.age,"turn":turn,"contacts":actor.body.contacts.keys(),"grounded_age":actor.body.grounded_age,
						"elbow":actor.body.flex("left_elbow"),"shoulder":actor.body.flex("left_upper"),"roll":actor.body.shield_roll,"tone":actor.body.tone})
			out.append({"facing":facing,"zone":zone,"big_steps":rows})
			if is_instance_valid(actor.loose_lance):actor.loose_lance.free()
			actor.free()
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(out,"\t"))
	quit(0)
