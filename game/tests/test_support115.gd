extends SceneTree
## Physical support/release and ownership continuity. Rule damage and automatic
## presentation are separate; these hits apply impulses without reducing HP.
const Model=preload("res://scripts/core/joust_match.gd")
const Fallen=preload("res://scripts/visual/fallen_rider.gd")
const Body=preload("res://scripts/visual/rider_body114.gd")
var failures=[]

func _initialize() -> void:call_deferred("run")

func sum_momentum(body) -> Vector2:
	var sum=body.v*body.mass+body.pelvis_v*body.pelvis_mass
	for i in range(Body.COUNT):sum+=body.vel[i]/body.inv_mass[i]
	return sum

func point_for(body, zone: String, edge: bool = false) -> Vector2:
	if zone=="head":return body.p[Body.HEAD]+Vector2(18,-10)
	if zone=="flank":return body.pelvis_x+Vector2(15,-12)
	if zone=="shield":return body.p[Body.HAND_L]+Vector2(0,-42 if edge else 0)
	return body.x+Vector2(22,-7)

func run() -> void:
	var path=""
	var scale=1.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):path=arg.trim_prefix("--report=")
		if arg.begins_with("--scale="):scale=float(arg.trim_prefix("--scale="))
	if path.is_empty() or FileAccess.file_exists(path) or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	var invariant=[]
	for zone in ["body","head","flank","shield","lance"]:
		var model=Model.new()
		model._ensure_body115(0)
		var body=model.bodies115[0].body
		var point=point_for(body,zone,true)
		var impulse=Vector2(-1200,-210)
		var momentum=sum_momentum(body)
		var spin=body.angular_momentum(Vector2.ZERO)
		var positions=body.p.duplicate()
		body.apply_impulse115(zone,point,impulse)
		var linear_error=(sum_momentum(body)-momentum-impulse).length()
		var angular_error=absf(body.angular_momentum(Vector2.ZERO)-spin-point.cross(impulse))
		var pose_error=0.0
		for i in range(Body.COUNT):pose_error=maxf(pose_error,positions[i].distance_to(body.p[i]))
		if linear_error>.02 or angular_error>10.0 or pose_error>.0001:failures.append("Contact impulse invariant: "+zone)
		invariant.append({"zone":zone,"linear_error":linear_error,"angular_error":angular_error,"pose_error":pose_error})
	var rows=[]
	for facing in [1,-1]:
		for zone in ["body","head","flank","shield"]:
			for force in [12.0,95.0]:
				var model=Model.new()
				var f:Dictionary=model.fighters[0]
				f.x=0.0;f.direction=facing;f.lane_y=0.0;f.speed=380.0;f.gait_moving=true;f.guard=.5
				model._ensure_body115(0)
				var actor=null
				var detach=-1.0
				var position_error=0.0
				var velocity_error=0.0
				var drawn_error=0.0
				var lance_error=0.0
				var identity=false
				var max_spine=0.0
				var max_turn=0.0
				var surface_penetration=0.0
				var surface_gap=0.0
				var samples=[]
				for tick in range(720):
					f.x+=380.0*facing/120.0
					f.gait_phase+=TAU*Model.Gait.frequency(380.0)/120.0
					if tick==120:
						var rider=model.bodies115[0]
						var hit={"zone":zone,"position":point_for(rider.body,zone),"direction":-facing,"impulse":force,"defender_speed":380.0,"ko_reason":"impact"}
						rider.queue_hit(hit,scale)
					if actor==null:
						model._advance_body115(0,1.0/120.0)
						var rider=model.bodies115[0]
						max_spine=maxf(max_spine,absf(rider.body.spine_flex()))
						max_turn=maxf(max_turn,absf(rider.body.theta))
						if rider.detached:
							detach=float(tick)/120.0
							var old_body=rider.body
							var old_points=old_body.p.duplicate()
							var old_vel=old_body.vel.duplicate()
							var old_x=old_body.x
							var old_v=old_body.v
							var payload=model.take_body115(0)
							var shown:Dictionary=payload.snapshot
							actor=Fallen.new();root.add_child(actor)
							actor.setup(f,{"zone":zone,"direction":-facing,"impulse":force,"ko_reason":"impact"},null,payload)
							actor.set_process(false);actor.visual.set_process(false);actor.far_leg.set_process(false)
							identity=actor.body==old_body and rider.body==null and rider.transferred
							position_error=old_x.distance_to(actor.body.x)
							velocity_error=old_v.distance_to(actor.body.v)
							for i in range(Body.COUNT):
								position_error=maxf(position_error,old_points[i].distance_to(actor.body.p[i]))
								velocity_error=maxf(velocity_error,old_vel[i].distance_to(actor.body.vel[i]))
							for side in ["left","right"]:
								for key in ["shoulder","elbow","hand"]:
									var world=actor.position+Vector2(actor.visual.detached_pose[side][key]).rotated(actor.rotation)
									drawn_error=maxf(drawn_error,world.distance_to(shown.pose[side][key]))
							for side in ["near","far"]:
								for key in ["hip","knee","ankle","foot"]:
									var world=actor.position+(Vector2(actor.visual.detached_legs[side][key])*Vector2(facing,1)).rotated(actor.rotation)
									drawn_error=maxf(drawn_error,world.distance_to(shown.legs[side][key]))
							var ray=Vector2(cos(Model.lance_angle(f))*facing,sin(Model.lance_angle(f)))
							var local_aim=float(actor.visual.fighter.aim)
							var shown_ray=Vector2(cos(local_aim)*facing,sin(local_aim)).rotated(actor.rotation)
							lance_error=absf(ray.angle_to(shown_ray))
					else:
						actor.advance(1.0/120.0)
						surface_penetration=maxf(surface_penetration,actor.position.y+actor.lowest_body_point()-actor.ground_y)
						if actor.settled:surface_gap=actor.support_gap()
					if tick in [119,126,144,180,240,360,719]:
						var body=actor.body if actor!=null else model.bodies115[0].body
						samples.append({"tick":tick,"detached":actor!=null,"x":[body.x.x,body.x.y],"pelvis":[body.pelvis_x.x,body.pelvis_x.y],"angle":body.theta,"spine":body.spine_flex()})
				if detach>=0.0 and (not identity or position_error>.001 or velocity_error>.001):failures.append("Discontinuous ownership transfer: %s/%s/%s" % [facing,zone,force])
				if drawn_error>.002 or lance_error>.0001:failures.append("Drawing/weapon jumps on transfer: %s/%s/%s" % [facing,zone,force])
				if force==12.0 and detach>=0.0:failures.append("Minor blow ejects settled rider: %s/%s" % [facing,zone])
				rows.append({"facing":facing,"zone":zone,"force":force,"detach_time":detach,"max_spine":max_spine,"max_turn":max_turn,"surface_penetration":surface_penetration,"surface_gap":surface_gap,"same_body":identity,"position_error":position_error,"velocity_error":velocity_error,"drawing_error":drawn_error,"lance_error":lance_error,"settled":actor.settled if actor!=null else false,"samples":samples})
				if actor!=null:actor.free()
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"invariants":invariant,"cases":rows},"\t"))
	print("SUPPORT115 ",failures)
	quit(0 if failures.is_empty() else 1)
