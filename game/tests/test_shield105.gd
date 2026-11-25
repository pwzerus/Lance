extends SceneTree
## A strapped shield follows its forearm through a fall, with one shared
## handle and visible/support transform. This does not change mounted rules.
const Model=preload("res://scripts/core/joust_match.gd")
const Rider=preload("res://scripts/visual/rider_view.gd")
const Fallen=preload("res://scripts/visual/fallen_rider.gd")
const Catalogue=preload("res://scripts/core/catalogue.gd")
var failures=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	if not ok and message not in failures:failures.append(message);push_error(message)
func shield_frame(pose:Dictionary,f:Dictionary)->Transform2D:
	if pose.has("shield_transform"):return pose.shield_transform
	var t:Transform2D=pose.torso_transform;t.x*=int(f.direction)
	t=t*Transform2D(float(f.get("shield_twist",0.0)),Vector2.ZERO);t.origin=pose.shield_center
	return t
func run()->void:
	var path=""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--report="):path=a.trim_prefix("--report=")
	var state=root.get_node("GameState")
	if path.is_empty() or FileAccess.file_exists(path) or not "qa_" in state.save_path or OS.get_environment("GALUMU_MEMORY_BOUND")=="":quit(2);return
	var stats=Catalogue.stats(Catalogue.load_items(),{"armor":"de_armor_1","helmet":"de_helmet_1","shield":"de_shield_0","horse":"horse_bay","lance":"lance_ash"})
	var rows=[]
	for facing in [1,-1]:
		for zone in ["head","body","flank"]:
			for guard in [0.0,.43,1.0]:
				var m=Model.new("arena",stats,stats,105);var f=m.fighters[0]
				f.x=0.0;f.lane_y=0.0;f.direction=facing;f.lean=-.6;f.guard=guard;f.aim=-.2;f.speed=440;f.gait_moving=true
				var actor=Fallen.new();root.add_child(actor)
				actor.setup(f,{"zone":zone,"impulse":105,"direction":-facing})
				actor.set_process(false);actor.visual.set_process(false);actor.far_leg.set_process(false)
				var initial:Dictionary=actor.initial_pose
				var initial_axis=shield_frame(initial,f).x.normalized()
				var initial_arm=Vector2(initial.left.hand)-Vector2(initial.left.elbow)
				var initial_grip_error=(shield_frame(initial,f)*Vector2(-10,4)).distance_to(initial.left.hand)
				var max_error=0.0;var max_grip=initial_grip_error;var max_joint_turn=0.0;var max_step=0.0;var max_strap=0.0;var last=initial_axis;var samples=[];var peak_frame={}
				for tick in range(480):
					actor.advance(1.0/120)
					var p:Dictionary=actor.visual.detached_pose;var t=shield_frame(p,f)
					var arm=Vector2(p.left.hand)-Vector2(p.left.elbow)
					var turn=initial_arm.angle_to(arm)
					var error=absf(initial_axis.rotated(actor.body.shield_theta115-actor.rotation).angle_to(t.x))
					var physical_forearm=(actor.body.p[actor.body.HAND_L]-actor.body.p[actor.body.ELBOW_L]).angle()-float(actor.body.extensions.shield.angle0)
					max_strap=maxf(max_strap,absf(wrapf(actor.body.shield_theta115-physical_forearm,-PI,PI)))
					max_error=maxf(max_error,error);max_joint_turn=maxf(max_joint_turn,absf(turn))
					var step_turn=absf(last.angle_to(t.x))
					if step_turn>max_step:peak_frame={"tick":tick,"age":actor.age,"turn":step_turn,"shield_world":actor.body.shield_theta115,"root":actor.rotation,"strap":wrapf(actor.body.shield_theta115-physical_forearm,-PI,PI),"grounded":actor.grounded}
					max_step=maxf(max_step,step_turn);last=t.x.normalized()
					max_grip=maxf(max_grip,(t*Vector2(-10,4)).distance_to(p.left.hand))
					if tick%60==0:samples.append({"age":actor.age,"forearm_turn":turn,"shield_error":error,"grounded":actor.grounded})
				check(max_joint_turn>.1,"Fall fixture actually moves the shield arm")
				check(max_error<.002,"Drawn shield follows its physical rotation: "+str([facing,zone,guard]))
				check(max_strap<2.05,"Shield strap stays within its finite angular range")
				check(max_grip<.002,"Shield handle stays in the same hand")
				check(max_step<.15,"Shield cannot snap between fall frames")
				rows.append({"facing":facing,"zone":zone,"guard":guard,"max_relative_angle_error":max_error,"max_strap_angle":max_strap,"max_grip_error":max_grip,"max_frame_turn":max_step,"settled":actor.settled,"samples":samples,"peak_frame":peak_frame})
				if is_instance_valid(actor.loose_lance):actor.loose_lance.free()
				actor.free()
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"18 real articulated falls, anatomical forearm/strapped shield orientation, handle continuity and finite turn. No mounted collision or human quality claim."},"\t"))
	print("SHIELD105 ",failures);quit(0 if failures.is_empty() else 1)
