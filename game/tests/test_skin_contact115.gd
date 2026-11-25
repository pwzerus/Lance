extends "test_energy115.gd"
## Independent display registration and finite-difference contact derivatives.
func point115(body,data:Dictionary,sample:Array)->Vector2:
	var ids:Vector3i=sample[0];var weights:Vector3=sample[1];var point=Vector2.ZERO
	for index in range(3):point+=body._extension_point(data,false,data.skin_offsets115[ids[index]])*weights[index]
	return point

func run()->void:
	var path=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):path=arg.trim_prefix("--report=")
	if path.is_empty() or FileAccess.file_exists(path) or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	var rows=[]
	for facing in [-1,1]:
		for side in ["near","far"]:
			for turn in [-.50,0.0,.65]:
				var model=Model.new();var f:Dictionary=model.fighters[0]
				f.x=0.0;f.lane_y=0.0;f.direction=facing;model._ensure_body115(0)
				var wrapper=model.bodies115[0];var body=wrapper.body;var key="boot_n" if side=="near" else "boot_f"
				var data:Dictionary=body.extensions[key];var foot:Dictionary=body.feet115[key];foot.angle=turn*facing
				var frame=Model.Rig115.body_pose(body,wrapper.captured);var leg:Dictionary=frame.legs[side].duplicate(true)
				var mirror=Vector2(facing,1)
				for name in ["hip","knee","ankle","foot"]:leg[name]=Vector2(leg[name])*mirror
				var outline=Model.Rig115.boot_skin_outline115(leg);var registration=0.0;var derivative=0.0
				for index in range(data.skin_samples115.size()):
					var sample:Array=data.skin_samples115[index];var ids:Vector3i=sample[0];var weights:Vector3=sample[1]
					var point=point115(body,data,sample);registration=maxf(registration,point.distance_to(outline[index]*mirror))
					var foot_lever=Vector2.ZERO
					for vertex in range(3):
						var lever:Vector2=body._extension_point(data,false,data.skin_offsets115[ids[vertex]])-body.p[data.b]
						foot_lever+=lever*float(data.skin_weights115[ids[vertex]])*weights[vertex]
					var epsilon=.002;var original:float=foot.angle
					foot.angle=original+epsilon;var plus=point115(body,data,sample)
					foot.angle=original-epsilon;var minus=point115(body,data,sample);foot.angle=original
					derivative=maxf(derivative,((plus-minus)/(2*epsilon)).distance_to(Vector2(-foot_lever.y,foot_lever.x)))
					var shin_lever:Vector2=point-body.p[data.b]-foot_lever;original=data.angle0
					data.angle0=original-epsilon;plus=point115(body,data,sample)
					data.angle0=original+epsilon;minus=point115(body,data,sample);data.angle0=original
					derivative=maxf(derivative,((plus-minus)/(2*epsilon)).distance_to(Vector2(-shin_lever.y,shin_lever.x)))
				if registration>.005 or derivative>.12:failures.append("Skin contact registration/Jacobian "+str([facing,side,turn]))
				rows.append({"facing":facing,"side":side,"turn":turn,"registration_error":registration,"derivative_error":derivative,"samples":outline.size()})
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows},"\t"))
	quit(0 if failures.is_empty() else 1)
