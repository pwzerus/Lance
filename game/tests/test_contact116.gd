extends "test_fall_v057.gd"
## Compare native vector-angle evaluation with the independent public
## anatomical angle reader at identical real body states. Not a fun verdict.
func run() -> void:
	var path="";var candidate=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):path=arg.trim_prefix("--report=")
		if arg.begins_with("--candidate="):candidate=arg.trim_prefix("--candidate=")
	if path.is_empty() or FileAccess.file_exists(path) or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	var rows=[]
	var projections=0
	for facing in [-1,1]:
		var model=Model.new()
		model.fighters[0].direction=facing
		model._ensure_body115(0)
		var physical=model.bodies115[0]
		for tick in range(120):
			model._advance_body115(0,1.0/120.0)
			if tick%12!=0:continue
			var points=physical.body.display_points()
			var before=points.duplicate()
			var standard=Model.Rig115.body_pose(physical.body,physical.captured)
			var reused=Model.Rig115.body_pose(physical.body,physical.captured,{},points)
			check(standard==reused,"Projected pose reuse is exactly equal",{"facing":facing,"tick":tick})
			Model.Rig115.translate_frame115(reused,Vector2(0,-5))
			check(points==before,"Translated render frame does not mutate solver projection")
			projections+=1
	for facing in [-1,1]:
		for zone in ["head","body","shield"]:
			var stage=Node2D.new();root.add_child(stage)
			var actor=make_actor(stage,zone,facing,false,false)
			var maximum=0.0;var samples=0
			for tick in range(480):
				actor.advance(1.0/120.0)
				if tick%12!=0:continue
				var current=actor.body if candidate.is_empty() else load("res://tests/test_solver_pair115.gd").clone_body115(actor.body,load(candidate))
				for i in range(current.fast_joints115.size()):
					var error=absf(wrapf(current._fast_flex115(current.fast_joints115[i])-current._flex(current.joints[i]),-PI,PI))
					maximum=maxf(maximum,error);samples+=1
			check(maximum<.000002,"Compiled joint angle agrees with anatomical reader",{"facing":facing,"zone":zone,"error":maximum})
			rows.append({"facing":facing,"zone":zone,"maximum_radians":maximum,"samples":samples})
			stage.free()
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"projection_cases":projections,"scope":"Identical body states sampled through six full falls, independent anatomical angle calculation. No rendered or human acceptance."},"\t"))
	quit(0 if failures.is_empty() else 1)
