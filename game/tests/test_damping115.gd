extends "test_support115.gd"
## Preserve the shoulder wrap regression under PHYS-116 mass-aware damping.
## Equivalent directions and continuity across PI are independent of a fixed
## legacy 2.6/24 decay rate. Whole-body energy is checked by dissipation116.
const Pair115=preload("test_solver_pair115.gd")
func velocities(body) -> PackedFloat64Array:
	var result=PackedFloat64Array([body.v.x,body.v.y,body.pelvis_v.x,body.pelvis_v.y,body.omega,body.pelvis_omega,body.shield_omega115])
	for value in body.vel:result.append(value.x);result.append(value.y)
	return result
func difference(a:PackedFloat64Array,b:PackedFloat64Array) -> float:
	var maximum=0.0
	for i in range(a.size()):maximum=maxf(maximum,absf(a[i]-b[i]))
	return maximum
func run() -> void:
	var path="";var solver=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):path=arg.trim_prefix("--report=")
		if arg.begins_with("--solver="):solver=arg.trim_prefix("--solver=")
	if path.is_empty() or FileAccess.file_exists(path) or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	var rows=[];var comparisons=[]
	for facing in [-1,1]:
		var output=[]
		for angle in [3.10,3.20,3.20-TAU,-1.10,PI-.0001,-PI+.0001]:
			var model=Model.new();model.fighters[0].direction=facing;model._ensure_body115(0)
			var actual=model.bodies115[0].body
			if not solver.is_empty():actual=Pair115.clone_body115(actual,load(solver))
			var pivot=actual.anchor("shoulder_l")
			var arm=actual.down_axis().rotated(-angle*facing)*actual.p[Body.ELBOW_L].distance_to(pivot)
			var shift=pivot+arm-actual.p[Body.ELBOW_L]
			actual.p[Body.ELBOW_L]+=shift;actual.p[Body.HAND_L]+=shift
			actual.v=Vector2.ZERO;actual.pelvis_v=Vector2.ZERO;actual.omega=0;actual.pelvis_omega=0;actual.shield_omega115=0
			actual.vel.fill(Vector2.ZERO)
			actual.vel[Body.ELBOW_L]=Vector2(-arm.y,arm.x);actual.vel[Body.HAND_L]=actual.vel[Body.ELBOW_L]
			var points=actual.p.duplicate();var before=velocities(actual)
			actual._damp_joints(1.0/120.0)
			var result=velocities(actual);output.append(result)
			for value in result:
				if not is_finite(value):failures.append("Nonfinite shoulder damping")
			if actual.p!=points:failures.append("Damping changed positions")
			if result==before:failures.append("Damping inactive")
			rows.append({"facing":facing,"angle":angle,"velocities":Array(result)})
		var equivalent=difference(output[1],output[2]);var crossing=difference(output[4],output[5])
		if equivalent>.003:failures.append("Equivalent angle changes damping: "+str(facing))
		if crossing>.1:failures.append("Damping discontinuity at PI: "+str(facing))
		comparisons.append({"facing":facing,"equivalent_error":equivalent,"pi_crossing_error":crossing})
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":rows,"comparisons":comparisons,"scope":"Angle wrapping and continuity; mass-aware damping no longer asserts obsolete fixed decay rates."},"\t"))
	quit(0 if failures.is_empty() else 1)
