extends "test_support115.gd"
## Independent mechanical checks of all internal dampers, including compressed
## abdomen, neck and loaded arm cases. No prescribed pose or decay rate.
func kinetic(body) -> float:
	var e=.5*body.mass*body.v.length_squared()+.5*body.inertia*body.omega*body.omega
	e+=.5*body.pelvis_mass*body.pelvis_v.length_squared()+.5*body.pelvis_inertia*body.pelvis_omega*body.pelvis_omega
	e+=.5*body.shield_inertia115*body.shield_omega115*body.shield_omega115
	for foot in body.feet115.values():e+=.5*float(foot.inertia)*float(foot.omega)*float(foot.omega)
	for i in range(Body.COUNT):e+=.5*body.vel[i].length_squared()/body.inv_mass[i]
	return e
func run() -> void:
	var path=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):path=arg.trim_prefix("--report=")
	if path.is_empty() or FileAccess.file_exists(path) or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	var rows=[]
	for facing in [-1,1]:
		for pose in range(3):
			for sample in range(8):
				var model=Model.new();model.fighters[0].direction=facing;model._ensure_body115(0)
				var body=model.bodies115[0].body
				if pose==1:
					body.theta+=.9*facing
					var pivot=body.anchor("hip_n");var length=body.p[Body.KNEE_N].distance_to(pivot)
					body.p[Body.KNEE_N]=pivot+body.hip_down_axis().rotated(-2.3*facing)*length
				if pose==2:body.chest_contact115=true;body.contacts.chest=true
				var rng=RandomNumberGenerator.new();rng.seed=116940+sample
				body.v=Vector2(37,-21);body.pelvis_v=Vector2(-17,28);body.omega=1.6;body.pelvis_omega=-.8;body.shield_omega115=1.2
				for i in range(Body.COUNT):body.vel[i]=Vector2(rng.randf_range(-80,80),rng.randf_range(-80,80))
				for foot in body.feet115.values():foot.omega=-.7
				var linear=sum_momentum(body);var angular=body.angular_momentum(Vector2.ZERO);var energy=kinetic(body)
				var points=body.p.duplicate();var origin=body.x;var pelvis=body.pelvis_x
				body._damp_joints(1.0/120.0)
				var linear_error=(sum_momentum(body)-linear).length();var angular_error=absf(body.angular_momentum(Vector2.ZERO)-angular);var after=kinetic(body)
				if linear_error>.04 or angular_error>3.0 or after>energy+.1:failures.append("Dissipation invariant "+str([facing,pose,sample]))
				if points!=body.p or origin!=body.x or pelvis!=body.pelvis_x:failures.append("Damper changed pose")
				rows.append({"facing":facing,"pose":pose,"linear_error":linear_error,"angular_error":angular_error,"energy_before":energy,"energy_after":after})
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":rows,"scope":"Local internal impulse invariants, no force contact, unchanged positions. Not human motion acceptance."},"\t"))
	quit(0 if failures.is_empty() else 1)
