extends "test_support115.gd"
## Internal joint damping must remove kinetic energy without creating a net
## linear/angular impulse. This audits the shared solver, not visual appeal.
func energy115(body) -> float:
	var total=.5*body.mass*body.v.length_squared()+.5*body.inertia*body.omega*body.omega
	total+=.5*body.pelvis_mass*body.pelvis_v.length_squared()+.5*body.pelvis_inertia*body.pelvis_omega*body.pelvis_omega
	total+=.5*body.shield_inertia115*body.shield_omega115*body.shield_omega115
	for i in range(Body.COUNT):total+=.5*body.vel[i].length_squared()/body.inv_mass[i]
	return total

func run() -> void:
	var path=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):path=arg.trim_prefix("--report=")
	if path.is_empty() or FileAccess.file_exists(path) or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	var rows=[]
	for facing in [1,-1]:
		for index in range(8):
			var model=Model.new();var fighter:Dictionary=model.fighters[0]
			fighter.x=0.0;fighter.direction=facing;fighter.lane_y=0.0
			model._ensure_body115(0);var body=model.bodies115[0].body
			var rng=RandomNumberGenerator.new();rng.seed=115330+index
			body.v=Vector2(45,-27);body.pelvis_v=Vector2(-19,34)
			body.omega=1.8;body.pelvis_omega=-.7
			for i in range(Body.COUNT):body.vel[i]=Vector2(rng.randf_range(-60,60),rng.randf_range(-60,60))
			var momentum=sum_momentum(body);var angular=body.angular_momentum(Vector2.ZERO);var energy=energy115(body)
			var points=body.p.duplicate();var origin=body.x;var pelvis=body.pelvis_x
			body._project_angle115(body.fast_joints115[index],0.0,.7)
			var linear_error=(sum_momentum(body)-momentum).length()
			var angular_error=absf(body.angular_momentum(Vector2.ZERO)-angular)
			var after=energy115(body)
			if linear_error>.03 or angular_error>2.0 or after>energy+.1:failures.append("Internal damping invariant "+str([facing,index]))
			if points!=body.p or origin!=body.x or pelvis!=body.pelvis_x:failures.append("Velocity impulse moved pose")
			rows.append({"facing":facing,"joint":index,"linear_error":linear_error,"angular_error":angular_error,"energy_before":energy,"energy_after":after})
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":rows,"scope":"Finite-precision internal damping invariants before contact; not exact long-term solver conservation or human naturalness."},"\t"))
	quit(0 if failures.is_empty() else 1)
