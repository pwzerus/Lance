extends "test_energy115.gd"
## Verify the new independent foot inertia and the SAME skinned contact outline.
func run() -> void:
	var path=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):path=arg.trim_prefix("--report=")
	if path.is_empty() or FileAccess.file_exists(path) or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	var rows=[]
	for facing in [-1,1]:
		for side in ["near","far"]:
			for flexion in [-.50,0.0,.65]:
				var model=Model.new();var f:Dictionary=model.fighters[0]
				f.x=0.0;f.lane_y=0.0;f.direction=facing;model._ensure_body115(0)
				var wrapper=model.bodies115[0];var body=wrapper.body
				var key="boot_n" if side=="near" else "boot_f"
				body.feet115[key].angle=flexion*facing
				var frame=Model.Rig115.body_pose(body,wrapper.captured)
				var leg:Dictionary=frame.legs[side].duplicate(true)
				var mirror=Vector2(facing,1)
				for part in ["hip","knee","ankle","foot"]:leg[part]=Vector2(leg[part])*mirror
				var outline=Model.Rig115.boot_outline113(leg)
				var data:Dictionary=body.extensions[key];var registration=0.0
				for i in range(outline.size()):registration=maxf(registration,(outline[i]*mirror).distance_to(body._extension_point(data,false,data.offsets[i])))
				if registration>.002:failures.append("Foot art/contact differs "+str([facing,side,flexion]))
				body.v=Vector2(35,-12);body.pelvis_v=Vector2(-17,20)
				body.omega=1.5;body.pelvis_omega=-.3;body.feet115[key].omega=3.0
				body.vel[data.a]=Vector2(18,40);body.vel[data.b]=Vector2(-20,-30)
				var p0=sum_momentum(body);var l0=body.angular_momentum(Vector2.ZERO)
				var e0=energy115(body)+foot_energy115(body)
				body._foot_impulse115(key,0.0,INF,.70)
				var pe=sum_momentum(body).distance_to(p0);var le=absf(body.angular_momentum(Vector2.ZERO)-l0)
				var e1=energy115(body)+foot_energy115(body)
				if pe>.03 or le>2.0 or e1>e0+.1:failures.append("Foot impulse invariant "+str([facing,side,flexion]))
				rows.append({"facing":facing,"side":side,"flexion":flexion,"registration_error":registration,"linear_error":pe,"angular_error":le,"energy_before":e0,"energy_after":e1})
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":rows},"\t"))
	quit(0 if failures.is_empty() else 1)

func foot_energy115(body) -> float:
	var total=0.0
	for foot in body.feet115.values():total+=.5*float(foot.inertia)*float(foot.omega)*float(foot.omega)
	return total
