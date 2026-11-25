extends "test_fall_v057.gd"
## Independent rotor freedoms must prevent visual sleep even when the
## point-mass skeleton stays fixed. This deliberately injects rotor motion.
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report_path=arg.trim_prefix("--report=")
	if report_path.is_empty() or FileAccess.file_exists(report_path) or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	var rows=[]
	var quiet=PackedVector2Array([Vector2.ZERO])
	var moving=PackedVector2Array([Vector2(Fallen.SETTLE_TRAVEL114+.25,0)])
	check(Fallen.samples_still115([quiet,quiet,quiet,quiet]),"Motionless full window can settle")
	check(not Fallen.samples_still115([quiet,moving,quiet,quiet]),"Returning rotor cannot hide intermediate movement")
	for facing in [-1,1]:
		for rotor in ["boot_n","boot_f","shield","shield_roll"]:
			var stage=Node2D.new();root.add_child(stage)
			var actor=make_actor(stage,"body",facing,false,false)
			var mass_before=actor.body.display_points()
			var visible_before=actor.settle_pose115()
			if rotor in ["boot_n","boot_f"]:actor.body.feet115[rotor].angle+=.25*facing
			elif rotor=="shield":actor.body.shield_theta115+=.25*facing
			else:actor.body.shield_roll=.6
			actor._update_pose()
			var visible_after=actor.settle_pose115()
			var skeleton_error=points_error(mass_before,actor.body.display_points())
			var visible_travel=points_error(visible_before,visible_after)
			check(skeleton_error==0.0,"Rotor fixture keeps mass points fixed")
			check(visible_travel>Fallen.SETTLE_TRAVEL114,"Moving skin prevents premature visual sleep",{"rotor":rotor,"facing":facing,"travel":visible_travel})
			stage.scale=Vector2(2.0,2.0);stage.position=Vector2(500,-200)
			check(points_error(visible_after,actor.settle_pose115())==0.0,"Rest uses game coordinates independent of view transform")
			rows.append({"rotor":rotor,"facing":facing,"mass_point_error":skeleton_error,"skin_travel":visible_travel})
			remove_stage(stage)
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"Injected independent rotor movement, not natural gameplay or a rest-time acceptance gate."},"\t"))
	quit(0 if failures.is_empty() else 1)
