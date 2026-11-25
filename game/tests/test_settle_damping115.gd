extends "test_energy115.gd"
## Internal dissipation on a supported torso must not become a hidden
## world-space brake: conserve net momentum and never move the pose.
func total_energy115(body) -> float:
	var total=energy115(body)
	for foot in body.feet115.values():total+=.5*float(foot.inertia)*float(foot.omega)*float(foot.omega)
	return total

func run() -> void:
	var path=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):path=arg.trim_prefix("--report=")
	if path.is_empty() or FileAccess.file_exists(path) or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	var rows=[]
	for facing in [-1,1]:
		for rest in [0.0,.5,1.0]:
			var model=Model.new();model.fighters[0].direction=facing;model.fighters[0].x=0;model.fighters[0].lane_y=0
			model._ensure_body115(0);var body=model.bodies115[0].body
			var rng=RandomNumberGenerator.new();rng.seed=115180
			body.rest=rest;body.chest_contact115=rest==.5;body.pelvis_contact115=rest==1.0
			if rest>0.0:body.contacts["torso"]=true
			body.v=Vector2(21,-13);body.pelvis_v=Vector2(-17,31)
			body.omega=1.8;body.pelvis_omega=-.7;body.shield_omega115=2.1
			for foot in body.feet115.values():foot.omega=-1.2
			for i in range(Body.COUNT):body.vel[i]=Vector2(rng.randf_range(-50,50),rng.randf_range(-50,50))
			var before=total_energy115(body);var linear=sum_momentum(body);var angular=body.angular_momentum(Vector2.ZERO)
			var points=body.p.duplicate();var chest=body.x;var pelvis=body.pelvis_x
			body._damp_joints(1.0/120)
			var after=total_energy115(body);var linear_error=(sum_momentum(body)-linear).length();var angular_error=absf(body.angular_momentum(Vector2.ZERO)-angular)
			if after>before+.1 or linear_error>.03 or angular_error>2.0:failures.append("Supported damping conservation "+str([facing,rest]))
			if points!=body.p or chest!=body.x or pelvis!=body.pelvis_x:failures.append("Dissipation changed position")
			rows.append({"facing":facing,"rest":rest,"dry_arm_friction_active":not body.contacts.is_empty(),"energy_before":before,"energy_after":after,"linear_error":linear_error,"angular_error":angular_error})
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows},"\t"))
	quit(0 if failures.is_empty() else 1)
