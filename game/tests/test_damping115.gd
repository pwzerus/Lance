extends "test_support115.gd"
## Reproduce the shoulder wrap defect through actual velocity impulses.
const Pair115=preload("test_solver_pair115.gd")
func run() -> void:
	var path="";var solver=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):path=arg.trim_prefix("--report=")
		if arg.begins_with("--solver="):solver=arg.trim_prefix("--solver=")
	if path.is_empty() or FileAccess.file_exists(path) or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	var rows=[]
	for facing in [-1,1]:
		for angle in [3.10,3.20,3.20-TAU,-1.10]:
			var model=Model.new();model.fighters[0].direction=facing;model._ensure_body115(0)
			var actual=model.bodies115[0].body
			if not solver.is_empty():actual=Pair115.clone_body115(actual,load(solver))
			var joint=actual.fast_joints115[0]
			var pivot=actual.anchor("shoulder_l")
			var length=actual.p[Body.ELBOW_L].distance_to(pivot)
			var arm=actual.down_axis().rotated(-angle*facing)*length
			var shift=pivot+arm-actual.p[Body.ELBOW_L]
			actual.p[Body.ELBOW_L]+=shift;actual.p[Body.HAND_L]+=shift
			actual.v=Vector2.ZERO;actual.pelvis_v=Vector2.ZERO;actual.omega=0;actual.pelvis_omega=0;actual.shield_omega115=0
			actual.vel.fill(Vector2.ZERO)
			actual.vel[Body.ELBOW_L]=Vector2(-arm.y,arm.x)
			actual.vel[Body.HAND_L]=actual.vel[Body.ELBOW_L]
			actual.fast_joints115.clear();actual.fast_joints115.append(joint)
			var initial=[actual.v,actual.pelvis_v,actual.omega,actual.pelvis_omega,actual.shield_omega115,actual.vel.duplicate()]
			var feet=actual.get("feet115")
			if feet is Dictionary:feet=feet.duplicate(true)
			# Overhead arms on either side of PI are ordinary damping. Only the
			# explicitly backward-extended example uses the terminal resistance.
			var rate=24.0 if angle==-1.10 else 2.6
			actual._project_angle115(joint,0.0,exp(-rate/120.0))
			actual.fast_joints115.clear()
			actual._damp_joints(1.0/120.0)
			var expected=[actual.v,actual.pelvis_v,actual.omega,actual.pelvis_omega,actual.shield_omega115,actual.vel.duplicate()]
			actual.v=initial[0];actual.pelvis_v=initial[1];actual.omega=initial[2];actual.pelvis_omega=initial[3];actual.shield_omega115=initial[4];actual.vel=initial[5]
			if feet is Dictionary:actual.feet115=feet
			actual.fast_joints115.append(joint)
			actual._damp_joints(1.0/120.0)
			var error=actual.v.distance_to(expected[0])+absf(actual.omega-expected[2])
			for i in range(Body.COUNT):error=maxf(error,actual.vel[i].distance_to(expected[5][i]))
			if error>.001:failures.append("Shoulder damping misclassified "+str([facing,angle]))
			rows.append({"facing":facing,"angle":angle,"expected_rate":rate,"velocity_error":error})
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":rows},"\t"))
	quit(0 if failures.is_empty() else 1)
