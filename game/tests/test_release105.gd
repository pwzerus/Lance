extends SceneTree
## Compare the carried lance's measured motion with its free-body velocity.
## This is a numerical release fixture, not an OS-input or human playtest.
const Model=preload("res://scripts/core/joust_match.gd")
const Fallen=preload("res://scripts/visual/fallen_rider.gd")

class ReleaseProbe extends Fallen:
	var previous_center=Vector2.INF
	var previous_ray=Vector2.RIGHT
	var measured_velocity=Vector2.ZERO
	var measured_spin=0.0
	var release_record={}
	func _update_pose()->void:
		super._update_pose()
		var ray=Vector2(cos(float(fighter.aim))*int(fighter.direction),sin(float(fighter.aim))).rotated(rotation)
		var center=position+Vector2(visual.detached_pose.right.hand).rotated(rotation)+ray*(Model.lance_length(fighter)-67.0)*.5
		if previous_center.is_finite():
			measured_velocity=(center-previous_center)/STEP_SECONDS
			measured_spin=previous_ray.angle_to(ray)/STEP_SECONDS
		previous_center=center;previous_ray=ray
	func _release_lance()->void:
		super._release_lance()
		release_record={"age":age,"velocity_error":loose_lance.linear_velocity.distance_to(measured_velocity),"angular_error":absf(loose_lance.angular_velocity-measured_spin),"measured_velocity":[measured_velocity.x,measured_velocity.y],"released_velocity":[loose_lance.linear_velocity.x,loose_lance.linear_velocity.y],"measured_spin":measured_spin,"released_spin":loose_lance.angular_velocity,"center_error":loose_lance.position.distance_to(previous_center),"ray_error":absf(previous_ray.angle_to(Vector2.from_angle(loose_lance.rotation)))}

var failures=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	if not ok and message not in failures:failures.append(message);push_error(message)
func run()->void:
	var path=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):path=arg.trim_prefix("--report=")
	if path.is_empty() or FileAccess.file_exists(path) or not "qa_" in root.get_node("GameState").save_path or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024":quit(2);return
	var rows=[]
	for facing in [-1,1]:
		for zone in ["head","body","flank"]:
			for speeds in [Vector2(180,480),Vector2(480,180),Vector2(480,480)]:
				for impulse in [45.0,110.0]:
					for broken in [false,true]:
						var model=Model.new();var f=model.fighters[0]
						f.x=0.0;f.lane_y=0.0;f.direction=facing;f.speed=speeds.x;f.aim=-.18;f.lean=-.3;f.guard=.43;f.gait_moving=true;f.broken=broken
						var actor=ReleaseProbe.new();root.add_child(actor)
						actor.setup(f,{"zone":zone,"direction":-facing,"impulse":impulse,"attacker_speed":speeds.y,"defender_speed":speeds.x})
						actor.set_process(false);actor.visual.set_process(false);actor.far_leg.set_process(false)
						for tick in range(30):
							actor.advance(1.0/120)
							if not actor.release_record.is_empty():break
						var record=actor.release_record.duplicate(true)
						record.merge({"facing":facing,"zone":zone,"own_speed":speeds.x,"other_speed":speeds.y,"impulse":impulse,"broken":broken})
						check(not actor.release_record.is_empty(),"Lance released within the fixture window")
						if not actor.release_record.is_empty():
							check(record.velocity_error<18.0,"Release retains carried linear motion: "+str([facing,zone,speeds,impulse]))
							check(record.angular_error<.25,"Release retains carried rotation: "+str([facing,zone,speeds,impulse]))
							check(record.center_error<.002 and record.ray_error<.0001,"Release keeps exact center and direction")
						rows.append(record)
						if is_instance_valid(actor.loose_lance):actor.loose_lance.free()
						actor.free()
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"72 real articulated releases, intact and broken weapons; finite-difference carried centre/ray versus free-body initial velocity, allowing one 120Hz derivative step. No collision or human quality verdict."},"\t"))
	print("RELEASE105 ",failures);quit(0 if failures.is_empty() else 1)
