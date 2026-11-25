extends "test_body114.gd"
## PHYS-114 diagnostic: per-step trunk rotation, spin and joint flexion of one
## captured fall, to locate where angular momentum comes from. No assertions.

func run() -> void:
	var zone = "body"
	var steps = 48
	var every = 1
	var facing = 1
	var impulse = 105.0
	var reason = "impact"
	var conscious = true
	var speeds = Vector2(480,480)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): report_path = argument.trim_prefix("--report=")
		if argument.begins_with("--zone="): zone = argument.trim_prefix("--zone=")
		if argument.begins_with("--steps="): steps = int(argument.trim_prefix("--steps="))
		if argument.begins_with("--every="): every = int(argument.trim_prefix("--every="))
		if argument.begins_with("--facing="): facing = int(argument.trim_prefix("--facing="))
		if argument.begins_with("--impulse="): impulse = float(argument.trim_prefix("--impulse="))
		if argument.begins_with("--reason="): reason = argument.trim_prefix("--reason=")
		if argument.begins_with("--unconscious"): conscious = false
		if argument.begins_with("--speeds="):
			var pair = argument.trim_prefix("--speeds=").split(",")
			speeds = Vector2(float(pair[0]),float(pair[1]))
	var stage = Node2D.new()
	root.add_child(stage)
	var actor = make_actor(stage,zone,facing,impulse,reason,conscious,speeds)
	var rows = []
	var body = actor.body
	rows.append({"t":0.0,"theta":body.theta,"omega":body.omega,"v":[body.v.x,body.v.y],
		"vel":vector_list(body.vel),"flex":flexes(body),"L":angular_momentum(body)})
	for frame in range(steps):
		actor.advance(1.0/120.0)
		if (frame+1)%every!=0: continue
		var down = body.down_axis()
		rows.append({"t":actor.age,"theta":body.theta,"omega":body.omega,"v":[body.v.x,body.v.y],"tone":body.tone,
			"flex":flexes(body),"L":angular_momentum(body),"contacts":body.contacts.keys(),"down":[down.x,down.y],
			"core":body.core_contact,"trunk_speed":body.trunk_speed,"x":[body.x.x,body.x.y],"drift":[body.trunk_drift.x,body.trunk_drift.y],"trunk_turn":body.trunk_turn,"to_flat":body._to_flat(),"rest":body.rest,"torso":body.torso_contact,"grounded_age":body.grounded_age,"gap":actor.support_gap(),"spine":body.spine_flex(),"art_lift":actor.surface_correction115,"surface":surface115(actor),"shape":final_shape(actor),"pelvis_theta":body.pelvis_theta,"pelvis_x":[body.pelvis_x.x,body.pelvis_x.y],
			"hips":[body.anchor("hip_n").y,body.anchor("hip_f").y],"knees":[body.p[body.KNEE_N].y,body.p[body.KNEE_F].y],
			"ankles":[body.p[body.ANKLE_N].y,body.p[body.ANKLE_F].y],"limits":limits(body)})
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"rows":rows},"\t"))
	file.close()
	quit(0)

func vector_list(values: PackedVector2Array) -> Array:
	var out = []
	for value in values: out.append([snappedf(value.x,.1),snappedf(value.y,.1)])
	return out

func flexes(body) -> Dictionary:
	var out = {}
	for joint in body.joints: out[joint.name] = snappedf(body._flex(joint),.001)
	out["neck"] = snappedf(body.neck_angle(),.001)
	return out

func limits(body) -> Dictionary:
	var out = {}
	for joint in body.joints: out[joint.name] = [snappedf(float(joint.lo),.01),snappedf(float(joint.hi),.01)]
	return out

func angular_momentum(body) -> float:
	# About the system centre, torso spin included.
	var c = body.system_centre()
	var total = body.inertia*body.omega+(body.x-c).cross(body.v)*body.mass
	for i in range(body.COUNT):
		total += (body.p[i]-c).cross(body.vel[i])/body.inv_mass[i]
	return snappedf(total,1.0)

func surface115(actor) -> Dictionary:
	var b=actor.body
	var result={}
	for side in ["near","far"]:
		var key="boot_n" if side=="near" else "boot_f"
		var raw=-INF
		for offset in b.extensions[key].offsets:
			raw=maxf(raw,b._extension_point(b.extensions[key],false,offset).y)
		var shown=-INF
		for point in Rider.boot_outline113(actor.visual.detached_legs[side]):
			shown=maxf(shown,world(actor,point*Vector2(int(actor.fighter.direction),1)).y)
		result[side]={"raw":raw,"shown":shown,"difference":shown-raw}
	var highest=-INF
	var index=-1
	var vertices=actor.body_points()
	for i in range(vertices.size()):
		var height=world(actor,vertices[i]).y
		if height>highest:
			highest=height
			index=i
	result["lowest_index"]=index
	result["ground"]=b.ground
	return result
