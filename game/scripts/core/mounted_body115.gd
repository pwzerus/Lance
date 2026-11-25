extends RefCounted
## One physical rider from the saddle through loss of support. No render nodes,
## model references, callbacks, random source or unbounded frame history.
const Body=preload("res://scripts/visual/rider_body114.gd")
const Rig=preload("res://scripts/core/rider_rig115.gd")
const Trace115=preload("res://scripts/core/frame_trace099.gd")
const STEP=1.0/120.0
const IMPULSE_SCALE=500.0
const CONTACT_TIME=.045
var body
var captured: Dictionary={}
var snapshot: Dictionary={}
var previous_snapshot: Dictionary={}
var current_snapshot: Dictionary={}
var shaft_aim=0.0
var previous_targets: Dictionary={}
var simulated_targets: Dictionary={}
var seat_points=PackedVector2Array([Vector2(-11,10),Vector2(11,10)])
var detached=false
var transferred=false
var unsupported_time=0.0
var age=0.0
var impact_age=10.0
var impact_unrecovered=false
var recovery_time=0.0
var last_hit_magnitude=0.0
var pending: Array=[]
var last_support: Dictionary={}
var last_hit: Dictionary={}
var accumulator=0.0
var shield_broken=false

func initialize(value: Dictionary, targets: Dictionary) -> void:
	captured=Rig.capture(value,targets.pose,targets.legs,float(targets.get("gait_pitch",0.0)))
	var data: Dictionary=captured.data
	var velocity=Vector2(float(value.get("speed",0.0))*int(value.direction),float(value.get("mount_velocity_y",0.0)))
	data.com_velocity=velocity
	data.velocities.fill(velocity)
	body=Body.new()
	body.build(data)
	shield_broken=float(value.get("shield",0.0))<=0.0
	body.guide_strength=0.0
	# Muscle bounds belong to Body so riding and compatibility falls agree.
	previous_targets=targets
	simulated_targets=targets
	snapshot=Rig.body_pose(body,captured,targets)
	shaft_aim=float(value.get("aim",0.0))
	snapshot.lance_aim=shaft_aim
	previous_snapshot=snapshot
	current_snapshot=snapshot

func _af(vector: Vector2) -> float:
	return atan2(vector.y,vector.x*body.facing)

func _muscles(value: Dictionary, targets: Dictionary) -> void:
	var awake=not bool(value.get("unconscious",false)) and not bool(value.get("dead",false))
	body.conscious=awake
	if not awake:
		body.set_muscles(0.0,{})
		return
	# A coarse callback may contain several fixed steps. Its control targets
	# must progress with the same interpolation as the saddle, not jump to the
	# final lean/guard on the first substep.
	value=value.duplicate()
	for key in ["lean","guard","aim"]:value[key]=targets.get(key,value.get(key,0.0))
	var pose: Dictionary=targets.pose
	var down=Transform2D(pose.torso_transform).basis_xform(Vector2.DOWN)
	var desired_hip=float(value.get("lean",0.0))*.14*body.facing
	var result={"spine":body.facing*wrapf(down.angle()-PI*.5-desired_hip,-PI,PI),"neck":0.0}
	var head_fit=Rig.HeadFit.layout(value.stats)
	var collar=Vector2(float(head_fit.collar.center[0]),float(head_fit.collar.center[1])+2.0)
	var target_head=Rig.head_transform(pose,value,float(targets.get("gait_pitch",0.0)))*Rect2(head_fit.helmet).get_center()
	var desired_root_turn=Transform2D(pose.torso_transform).get_rotation()-Transform2D(captured.pose.torso_transform).get_rotation()
	result.neck=wrapf((target_head-Transform2D(pose.torso_transform)*collar).angle()-desired_root_turn-body.neck0,-PI,PI)
	var desired_shield=Rig.shield_pose_transform(pose,value)
	var wanted_turn=wrapf(desired_shield.x.angle()-Transform2D(captured.shield_frame).x.angle(),-PI,PI)
	var arm_turn=wrapf((Vector2(pose.left.hand)-Vector2(pose.left.elbow)).angle()-float(body.extensions.shield.angle0),-PI,PI)
	result.shield_relative=wrapf(wanted_turn-arm_turn,-PI,PI)
	for side in ["left","right"]:
		var arm: Dictionary=pose[side]
		var upper=Vector2(arm.elbow)-Vector2(arm.shoulder)
		var lower=Vector2(arm.hand)-Vector2(arm.elbow)
		result[side+"_upper"]=wrapf(_af(down)-_af(upper),-PI,PI)
		result[side+"_elbow"]=wrapf(_af(upper)-_af(lower),-PI,PI)
	for side in ["near","far"]:
		var leg: Dictionary=targets.legs[side]
		var upper=Vector2(leg.knee)-Vector2(leg.hip)
		var lower=Vector2(leg.ankle)-Vector2(leg.knee)
		result[side+"_hip"]=wrapf(_af(Vector2.DOWN)-_af(upper),-PI,PI)
		result[side+"_knee"]=wrapf(_af(lower)-_af(upper),-PI,PI)
	var strength=clampf(float(value.get("arm",100.0))/100.0,.25,1.0)
	var seat_fatigue=clampf(float(value.get("seat_strain",0.0)),0.0,1.0)
	for side in ["near","far"]:
		result[side+"_hip_tone"]=1.0-seat_fatigue*.97
		result[side+"_knee_tone"]=1.0-seat_fatigue*.97
	result.spine_tone=1.0-seat_fatigue*.60
	result.left_upper_tone=lerpf(.65,1.0,strength)
	result.left_elbow_tone=result.left_upper_tone
	result.right_upper_tone=result.left_upper_tone
	result.right_elbow_tone=result.left_upper_tone
	body.set_muscles(1.0,result)

func _support(targets: Dictionary, before: Dictionary, value: Dictionary) -> Dictionary:
	var centre=(Vector2(targets.legs.near.hip)+Vector2(targets.legs.far.hip))*.5+Vector2(0,10)
	var old=(Vector2(before.legs.near.hip)+Vector2(before.legs.far.hip))*.5+Vector2(0,10)
	var rein=Vector2(targets.pose.torso_transform.origin)+Vector2(96*body.facing,-20)
	var rein_old=Vector2(before.pose.torso_transform.origin)+Vector2(96*body.facing,-20)
	return {"saddle":centre,"saddle_previous":old,"seat_points":seat_points,"width":31.0,"friction":.95,
		"pelvis_angle":float(targets.get("lean",value.get("lean",0.0)))*.14*body.facing,
		"brace_torque":3000000.0*(1.0-float(value.get("injury",0.0))*.35)*(1.0-float(value.get("seat_strain",0.0))*.95) if body.conscious else 0.0,
		"feet":{"near":Vector2(targets.legs.near.stirrup)-Vector2(9*body.facing,11),"far":Vector2(targets.legs.far.stirrup)-Vector2(9*body.facing,11)},
		"feet_previous":{"near":Vector2(before.legs.near.stirrup)-Vector2(9*body.facing,11),"far":Vector2(before.legs.far.stirrup)-Vector2(9*body.facing,11)},
		"rein":rein,"rein_previous":rein_old,"rein_length":108.0,"rein_force":10000.0,
		"rein_grip":not bool(value.get("unconscious",false)) and not bool(value.get("dead",false)),
		"crest":targets.get("crest",PackedVector2Array())}

func queue_hit(event: Dictionary, scale: float = 1.0) -> void:
	if body==null or transferred:return
	var part=str(event.get("zone","body"))
	if part not in ["head","body","flank","shield","lance"]:part="body"
	var base=body.p[Body.HAND_L] if part=="shield" else body.p[Body.HEAD] if part=="head" else body.p[Body.HAND_R] if part=="lance" else body.pelvis_x if part=="flank" else body.x
	var point: Vector2=event.get("position",base)
	var direction: Vector2=event.get("impulse_axis115",Vector2(float(event.get("direction",-body.facing)),-.055))
	if direction.length_squared()<.000001:direction=Vector2(-body.facing,0)
	direction=direction.normalized()
	var magnitude=maxf(0.0,float(event.get("impulse",0.0)))*IMPULSE_SCALE*scale
	if pending.size()<4:
		pending.append({"part":part,"offset":point-base,"impulse":direction*magnitude,"remaining":CONTACT_TIME})
	if magnitude>0.0:
		# In a simultaneous exchange a smaller recoil through one's own lance
		# must not replace the head/chest blow that is already moving the rider.
		if not impact_unrecovered or impact_age>.15 or magnitude>=last_hit_magnitude:
			last_hit=event.duplicate(true)
			last_hit_magnitude=magnitude
		impact_age=0.0
		impact_unrecovered=true
		recovery_time=0.0

func _deliver(dt: float) -> void:
	for i in range(pending.size()-1,-1,-1):
		var hit: Dictionary=pending[i]
		var portion=minf(dt,float(hit.remaining))/CONTACT_TIME
		var part=str(hit.part)
		var base=body.p[Body.HAND_L] if part=="shield" else body.p[Body.HEAD] if part=="head" else body.p[Body.HAND_R] if part=="lance" else body.pelvis_x if part=="flank" else body.x
		body.apply_impulse115(part,base+Vector2(hit.offset),Vector2(hit.impulse)*portion)
		hit.remaining=float(hit.remaining)-dt
		if float(hit.remaining)<=.000001:pending.remove_at(i)

func advance(value: Dictionary, targets: Dictionary, dt: float) -> void:
	if transferred:return
	if body==null:initialize(value,targets)
	if not shield_broken and float(value.get("shield",0.0))<=0.0:_break_shield115(value)
	# Engine.time_scale also shrinks physics callback dt. Do not solve contacts
	# on those tiny values: float32 world coordinates then turn one ULP of
	# position correction into an enormous derived velocity. Keep 120 game Hz.
	var h=STEP
	accumulator+=clampf(dt,0.0,.25)
	var before=previous_targets
	while accumulator+.000000001>=STEP:
		var endpoint=dt-(accumulator-STEP)
		var current=_interpolate_targets(before,targets,clampf(endpoint/maxf(dt,.000001),0,1))
		var prior=simulated_targets
		accumulator=maxf(0.0,accumulator-STEP)
		previous_snapshot=current_snapshot
		age+=h
		impact_age+=h
		var muscle_started115=Trace115.begin()
		if detached:body.set_muscles(0.0,{})
		else:_muscles(value,current)
		Trace115.measure("mounted_muscles115",muscle_started115)
		_deliver(h)
		last_support={} if detached else _support(current,prior,value)
		var solve_started115=Trace115.begin()
		body.step(h,last_support)
		Trace115.measure("mounted_solve115",solve_started115)
		if not detached:
			var centre: Vector2=last_support.saddle-Vector2(0,10)
			var offset=body.pelvis_x-centre
			var seat=body.support_contacts115.has("saddle")
			var iron=body.support_contacts115.has("near") or body.support_contacts115.has("far")
			var outside=absf(offset.x)>34.0 or offset.y < -24.0 or offset.y>22.0
			unsupported_time=unsupported_time+h if outside and not seat and not iron else maxf(0.0,unsupported_time-h*2.0)
			if unsupported_time>=.055:detached=true
			# A delayed physical fall is still attributed to the blow until the
			# rider actually regains a quiet seat. A one-second timeout labelled
			# delayed impact losses as voluntary bad balance with zero impulse.
			var relative_speed=absf(body.pelvis_v.x-float(value.get("speed",0.0))*body.facing)
			var torso_error=absf(wrapf(body.down_axis().angle()-Transform2D(current.pose.torso_transform).y.angle(),-PI,PI))
			var quiet=not outside and absf(offset.x)<8.0 and relative_speed<24.0 and torso_error<.14 and (seat or iron)
			recovery_time=recovery_time+h if quiet and pending.is_empty() and impact_age>.25 else 0.0
			if recovery_time>.6:impact_unrecovered=false
		simulated_targets=current
		var pose_started115=Trace115.begin()
		current_snapshot=Rig.body_pose(body,captured,current)
		Trace115.measure("mounted_pose115",pose_started115)
		_advance_lance115(value,current,h)
		current_snapshot.lance_aim=shaft_aim
	previous_targets=targets
	var interpolate_started115=Trace115.begin()
	snapshot=Rig.interpolate115(previous_snapshot,current_snapshot,accumulator/STEP,value).duplicate(true)
	Trace115.measure("mounted_interpolate115",interpolate_started115)
	snapshot.supported=body.support_contacts115.duplicate()
	snapshot.detached=detached
	snapshot.seat_offset=body.pelvis_x-(Vector2(targets.legs.near.hip)+Vector2(targets.legs.far.hip))*.5
	# Leathers remain attached to the current horse; the interpolated boots
	# can move relative to them rather than dragging the saddle endpoints.
	for side in ["near","far"]:
		for key in ["bar","stirrup"]:snapshot.legs[side][key]=targets.legs[side][key]

func _advance_lance115(value: Dictionary, desired: Dictionary, dt: float) -> void:
	var actual:Dictionary=current_snapshot.pose.right
	var target:Dictionary=desired.pose.right
	var turn=wrapf(_af(Vector2(actual.hand)-Vector2(actual.elbow))-_af(Vector2(target.hand)-Vector2(target.elbow)),-PI,PI)
	var wanted=float(desired.get("aim",value.get("aim",0.0)))+turn*.8
	shaft_aim+=clampf(wrapf(wanted-shaft_aim,-PI,PI),-6.0*dt,6.0*dt)

func _break_shield115(value: Dictionary) -> void:
	shield_broken=true
	# Detached fragments carry away their own mass and the hand's existing
	# velocity. The remaining forearm never collides with an invisible full shield.
	var old_mass=1.0/body.inv_mass[Body.HAND_L]
	var removed=maxf(0.0,float(value.stats.get("shield_kg",3.0))-1.0)
	body.inv_mass[Body.HAND_L]=1.0/maxf(1.0,old_mass-removed)
	var frame:Transform2D=captured.shield_frame
	var extension:Dictionary=body.extensions.shield
	var offsets=PackedVector2Array()
	# The visible snapshot can lag the current solver by one fixed step.
	# Capture the outline relative to its grip, never subtract a newer world
	# hand from the old snapshot origin (a speed-dependent collision offset).
	for point in Rig.ShieldArt.remnant_polygon(value.stats):offsets.append(frame.basis_xform(point-Vector2(-10,4)))
	extension.offsets=offsets
	extension.basis_x=frame.x
	extension.basis_y=frame.y
	extension.reach=0.0
	for point in offsets:extension.reach=maxf(float(extension.reach),point.length())
	# Rest-space geometry rotates with the existing independent shield angle;
	# neither an interpolated angle nor its rolled display scale is recaptured.
	body.configure_shield115(1.0)

func _interpolate_targets(a: Dictionary, b: Dictionary, weight: float) -> Dictionary:
	if weight>=.999999:return b
	if weight<=.000001:return a
	var result=b.duplicate(true)
	result.pose.torso_transform=Transform2D(a.pose.torso_transform).interpolate_with(b.pose.torso_transform,weight)
	for side in ["left","right"]:
		for key in ["shoulder","elbow","hand"]:result.pose[side][key]=Vector2(a.pose[side][key]).lerp(b.pose[side][key],weight)
	for key in ["shield_center","shield_grip"]:result.pose[key]=Vector2(a.pose[key]).lerp(b.pose[key],weight)
	for key in ["lean","guard","aim","gait_pitch"]:
		if a.has(key) and b.has(key):result[key]=lerpf(float(a[key]),float(b[key]),weight)
	if a.has("crest") and b.has("crest") and a.crest.size()==b.crest.size():
		for i in range(b.crest.size()):result.crest[i]=Vector2(a.crest[i]).lerp(b.crest[i],weight)
	for side in ["near","far"]:
		for key in ["hip","knee","ankle","foot","bar","stirrup"]:
			result.legs[side][key]=Vector2(a.legs[side][key]).lerp(b.legs[side][key],weight)
	return result

func take_body() -> Dictionary:
	if not detached or transferred or body==null:return {}
	transferred=true
	var result={"body":body,"captured":captured,"snapshot":snapshot,"targets":previous_targets,"pending":pending,
		"previous_snapshot":previous_snapshot,"current_snapshot":current_snapshot,"accumulator":accumulator}
	body=null
	pending=[]
	return result
