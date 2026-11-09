extends SceneTree
const Model=preload("res://scripts/core/joust_match.gd")
const Rider=preload("res://scripts/visual/rider_view.gd")
var failures: Array=[]
func _initialize() -> void:
	var rows: Array=[]
	for facing in [1,-1]:
		for zone in ["head","body","shield","flank"]:
			var m=Model.new("arena",{"stability":2.0},{"stability":2.0})
			var di=0 if facing==1 else 1
			var f: Dictionary=m.fighters[di]
			m.fighters[1-di].speed=480.0
			var start=Model.head_position(f)
			var event={"type":"hit","attacker":1-di,"defender":di,"zone":zone,"speed":960.0,"position":Model.shield_position(f) if zone=="shield" else start}
			m._apply_contact(event)
			if Model.head_position(f).distance_to(start)>.001: failures.append("Contact teleported rider")
			var peak=0.0
			var arm_error=0.0
			for tick in range(360):
				Model.advance_reaction(f,1.0/120.0)
				peak=maxf(peak,absf(f.reaction_angle))
				var pose=Rider.arm_pose(f)
				for side in ["left","right"]:
					var arm: Dictionary=pose[side]
					arm_error=maxf(arm_error,absf(arm.shoulder.distance_to(arm.elbow)-Rider.ARM_UPPER))
					arm_error=maxf(arm_error,absf(arm.hand.distance_to(arm.elbow)-Rider.ARM_LOWER))
			if arm_error>.05: failures.append("Arm disconnected")
			if zone=="head" and peak<deg_to_rad(20): failures.append("Full head hit has insufficient torso follow-through")
			if peak>.481 or absf(f.reaction_angle)>.001: failures.append("Reaction unbounded or does not settle")
			if f.dead: failures.append("Arena became lethal")
			rows.append({"facing":facing,"zone":zone,"peak_degrees":rad_to_deg(peak),"arm_error":arm_error})
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows},"\t"))
	print("REACTION075 ",failures)
	quit(0 if failures.is_empty() else 1)
