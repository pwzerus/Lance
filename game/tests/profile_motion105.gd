extends "profile_result099.gd"
## Actual GPU loop capped at 30 FPS by a QA-only late process node. Production
## physics, assets, animation and window/memory protection stay unchanged.
const Rider=preload("res://scripts/visual/rider_view.gd")
class RenderLimit extends Node:
	func _ready()->void:
		process_mode=Node.PROCESS_MODE_ALWAYS;process_priority=10000
	func _process(_delta:float)->void:
		Engine.max_fps=30 if DisplayServer.window_can_draw() else 10
var cap:Node
var pose_metrics={"frames":0,"arms":0,"maximum_bone_error":0.0,"maximum_anchor_error":0.0,"nonfinite":0}
func prepare(battle,seed_value:int)->void:
	super.prepare(battle,seed_value)
	if not is_instance_valid(cap):
		cap=RenderLimit.new();root.add_child(cap)
func probe()->void:
	super.probe()
	var battle=watched.get_ref() if watched else null
	if not is_instance_valid(battle) or not battle.presentation_ready:return
	pose_metrics.frames+=1
	for fighter in battle.match_model.fighters:
		if fighter.ko:continue
		var pose=Rider.arm_pose(fighter)
		for side in ["left","right"]:
			var arm=pose[side];pose_metrics.arms+=1
			for key in ["shoulder","elbow","hand"]:
				if not Vector2(arm[key]).is_finite():pose_metrics.nonfinite+=1
			var projection=float(arm.projection)
			var error=maxf(absf(arm.shoulder.distance_to(arm.elbow)-44*projection),absf(arm.hand.distance_to(arm.elbow)-46*projection))
			pose_metrics.maximum_bone_error=maxf(pose_metrics.maximum_bone_error,error)
			check(error<.05,"Actual 30FPS loop disconnects an arm bone")
			var anchor=battle.Model.hand_position(fighter) if side=="right" else battle.Model.shield_grip(fighter)
			var anchor_error=Vector2(arm.hand).distance_to(anchor)
			pose_metrics.maximum_anchor_error=maxf(pose_metrics.maximum_anchor_error,anchor_error)
			check(anchor_error<.002,"Actual 30FPS rendered arm drifts from rule grip")
	check(pose_metrics.nonfinite==0,"Actual 30FPS loop has non-finite mounted joints")
func run()->void:
	await super.run()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):
			FileAccess.open(arg.trim_prefix("--folder=")+"/motion.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"metrics":pose_metrics,"target_render_fps":30,"physics_hz":Engine.physics_ticks_per_second,"scope":"Normal Main/Battle results/replay and actual rendered frames, QA-only 30FPS cap. No physics-rate or art reduction. Joint bounds do not establish human motion quality."},"\t"))
