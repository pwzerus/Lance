class_name FallenRider
extends Node2D
const Trace099 = preload("res://scripts/core/frame_trace099.gd")
## A single articulated rider, captured from the mounted renderer at contact.
## Visual ballistics do not feed back into scoring, damage or death decisions.
signal landed(point: Vector2, strength: float)

const Rider = preload("res://scripts/visual/rider_view.gd")
const Model = preload("res://scripts/core/joust_match.gd")
var visual: RiderView
var far_leg: RiderView
var fighter: Dictionary = {}
var initial_pose: Dictionary = {}
var initial_legs: Dictionary = {}
var initial_position = Vector2.ZERO
var velocity = Vector2.ZERO
var angular_velocity = 0.0
var age = 0.0
var ground_y = 12.0
var zone = "body"
var strength = .5
var direction = 1
var settled = false
var grounded = false
var ground_age = 0.0
var target_rotation = 0.0
var source_recoil = 0.0
var landing_speed = 0.0
var loose_lance: RigidBody2D
var joints: Dictionary = {}
var initial_aim = 0.0
var roll_direction = 1.0
var landing_count = 0
var step_remainder = 0.0
var toppled = false
var stopped = 0.0
const STEP_SECONDS = 1.0/120.0
var pose_points099 = PackedVector2Array()
var support_hull099 = PackedVector2Array()
var rest_targets: Dictionary = {}
var rest_angle = 0.0

func setup(value: Dictionary, event: Dictionary, mounted: RiderView = null) -> void:
	fighter = value.duplicate(true)
	direction = int(event.get("direction",-int(fighter.direction)))
	zone = str(event.get("zone","body"))
	strength = clampf(float(event.get("impulse",70.0))/110.0,.15,1.0)
	initial_aim = float(fighter.get("aim",0.0))
	initial_pose = Rider.arm_pose(fighter).duplicate(true)
	# Capture the mounted neck/gaze registration before the detached head
	# gains its own hinge. Zero hinge angle must preserve the exact old pose.
	initial_pose["head_base_transform"] = Rider._head_hinge(initial_pose,fighter)
	position = initial_pose.torso_transform.origin
	initial_position = position
	ground_y = float(fighter.get("lane_y",0.0))+12.0
	var mirror = Vector2(int(fighter.direction),1)
	var mounted_origin = Vector2(float(fighter.x),float(fighter.get("lane_y",0.0)))
	var relative_hip = (position-mounted_origin)*mirror
	initial_legs = Rider.seated_leg_pose(fighter).duplicate(true)
	for side in ["near","far"]:
		# The saddle bar and iron are drawn in the same torso-relative space as
		# the boot; leaving them mount-relative put the fading leather off-body.
		for joint in ["hip","knee","ankle","foot","bar","stirrup"]:
			if initial_legs[side].has(joint):
				initial_legs[side][joint] -= relative_hip
	for side in ["left","right"]:
		for joint in ["shoulder","elbow","hand"]:
			initial_pose[side][joint] -= position
	initial_pose.shield_center -= position
	initial_pose.shield_grip -= position
	initial_pose.torso_transform.origin = Vector2.ZERO
	# FEEL-097: momentum instead of one fixed throw. The rider leaves with his
	# horse's ground velocity and the lance carries him toward the attacker's;
	# the harder the strike, the more of the attacker's motion he takes. Equal
	# speeds drop him near the contact; a fast rider meeting a slow lance keeps
	# travelling while his torso is stopped (the horse runs on from under him);
	# a slow rider met by a fast lance is driven back the way it came. A seat
	# lost to balance alone slides off with the horse's momentum, slowly.
	toppled = str(event.get("ko_reason","impact"))=="balance"
	var own = float(event.get("defender_speed",fighter.speed))*int(fighter.direction)
	var other = float(event.get("attacker_speed",fighter.speed))*direction
	var carry = (lerpf(.16,.30,strength) if toppled else lerpf(.42,.80,strength))*float({"head":.85,"flank":.80}.get(zone,1.0))
	var carried = lerpf(own,other,carry)
	# How hard the upper body was stopped relative to the horse (facing frame).
	stopped = clampf((own-carried)*int(fighter.direction)/600.0,-1.0,1.0)
	var lever = float({"head":1.25,"flank":.55}.get(zone,1.0))
	var lift = lerpf(10,35,strength) if toppled else lerpf(40,125,strength)*float({"head":1.2,"flank":.55}.get(zone,1.0))+45.0*absf(stopped)*lever
	velocity = Vector2(carried,-lift)
	roll_direction = float(direction if zone!="flank" else -direction)
	target_rotation = roll_direction*PI*.47-float(initial_pose.torso_transform.get_rotation())
	var spin = lerpf(.55,.95,strength) if toppled else (1.0+1.3*absf(stopped)*lever)*lerpf(.85,1.12,strength)
	angular_velocity = roll_direction*clampf(spin,.4,4.6)
	_make_joints()
	for far_only in [true,false]:
		var renderer = Rider.new()
		renderer.fighter = fighter
		renderer.red = bool(fighter.get("red",false))
		renderer.mode = mounted.mode if is_instance_valid(mounted) else "arena"
		renderer.blood_enabled = mounted.blood_enabled if is_instance_valid(mounted) else false
		renderer.detached_far_only = far_only
		renderer.detached_far_visible = false
		renderer.detached_pose = initial_pose.duplicate(true)
		renderer.detached_legs = initial_legs.duplicate(true)
		if is_instance_valid(mounted):
			renderer.impact_recoil = mounted.impact_recoil
			renderer.lance_recoil = mounted.lance_recoil
			renderer.shield_recoil = mounted.shield_recoil
			renderer.impact_velocity = mounted.impact_velocity
			renderer.lance_velocity = mounted.lance_velocity
			renderer.shield_velocity = mounted.shield_velocity
		add_child(renderer)
		if far_only:
			far_leg = renderer
			# The far boot starts on the far side of the departing horse.
			far_leg.z_index = -3 if ground_y>12 else -1
		else:
			visual = renderer
	source_recoil = visual.impact_recoil

func _joint(name: String, velocity_value: float, stiffness: float, damping: float, minimum: float, maximum: float, bend_sign: float = 1.0) -> void:
	# All angles start at zero: only velocities receive the impact. Capturing
	# the mounted pose must not snap any limb, helmet or held weapon.
	joints[name] = {"angle":0.0,"velocity":velocity_value,"stiffness":stiffness,"damping":damping,"minimum":minimum,"maximum":maximum,"bend_sign":bend_sign}

func _hinge(name: String, upper: Vector2, lower: Vector2, velocity_value: float, stiffness: float, damping: float) -> void:
	var bend = upper.angle_to(lower)
	var bend_sign = 1.0 if bend>=0.0 else -1.0
	# Keep the source bend side; elbows/knees cannot reverse through a
	# straight joint. Include zero exactly for the captured source pose.
	var lower_limit = minf(0.0,.06-bend) if bend_sign>0 else minf(0.0,maxf(-1.10,-2.60-bend))
	var upper_limit = maxf(0.0,minf(1.10,2.60-bend)) if bend_sign>0 else maxf(0.0,-.06-bend)
	_joint(name,velocity_value*bend_sign,stiffness,damping,maxf(-1.10,lower_limit),minf(1.10,upper_limit),bend_sign)

func _make_joints() -> void:
	# FEEL-097: limb loading spans light to full strikes more widely; a topple
	# keeps the limbs loose rather than whipped.
	var load = lerpf(.40,.60,strength) if toppled else lerpf(.50,1.20,strength)
	var spinal_impulse = 2.7 if zone=="body" else (-2.5 if zone=="flank" else 1.4)
	# The rule reaction has only velocity on the contact frame. Inherit a
	# small share instead of applying the full mounted reaction twice.
	var inherited = float(fighter.get("reaction_angular_velocity",0.0))*int(fighter.direction)*.16
	_joint("spine",direction*spinal_impulse*load+inherited,38.0,6.2,-.42,.42)
	_joint("head",direction*(1.55 if zone=="head" else (-.65 if zone=="body" else .55))*load,65.0,7.2,-.20,.20)
	for side in ["right","left"]:
		var arm: Dictionary = initial_pose[side]
		var upper: Vector2 = arm.elbow-arm.shoulder
		var lower: Vector2 = arm.hand-arm.elbow
		var arm_impulse = 1.5 if side=="right" else -.7
		if zone=="body": arm_impulse = 2.0 if side=="right" else 1.05
		if zone=="flank": arm_impulse = -.6 if side=="right" else .8
		_joint(side+"_upper",direction*arm_impulse*load,18.0,4.6,-1.0,1.0)
		_hinge(side+"_elbow",upper,lower,(1.8 if zone=="head" else .9)*load,22.0,5.0)
	for side in ["near","far"]:
		var leg: Dictionary = initial_legs[side]
		var hip_impulse = 1.25 if side=="near" else -.85
		if zone=="flank": hip_impulse *= -1.25
		# The horse carries the legs on while the lance stops the torso: they
		# swing up over the cantle in proportion to that deceleration.
		hip_impulse += stopped*(1.1 if side=="near" else .7)
		_joint(side+"_hip",hip_impulse*load,19.0,4.5,-.85,.85)
		_hinge(side+"_knee",leg.knee-leg.hip,leg.ankle-leg.knee,(1.9 if zone=="flank" else 1.2)*load,24.0,5.0)

func _joint_targets() -> Dictionary:
	# A brief regional protective reaction yields to freely hanging limbs.
	# Targets change smoothly; angles themselves are integrated, never lerped.
	if not rest_targets.is_empty():
		return rest_targets
	var reaction = exp(-age*2.8)
	var ground_blend = 1.0-exp(-ground_age*9.0) if grounded else 0.0
	var spine_air = direction*(.25 if zone=="body" else (-.32 if zone=="flank" else .15))*reaction
	var head_air = direction*(.12 if zone=="head" else -.055)*reaction
	var targets = {"spine":lerpf(spine_air,direction*(-.17 if zone=="flank" else .075),ground_blend),"head":lerpf(head_air,-direction*.035,ground_blend)}
	for side in ["right","left"]:
		var air_upper = direction*(.35 if side=="right" else -.18)*reaction
		if zone=="body": air_upper = direction*(.48 if side=="right" else .25)*reaction
		if zone=="flank": air_upper *= -.5
		targets[side+"_upper"] = lerpf(air_upper,direction*(.14 if side=="right" else -.12),ground_blend)
		targets[side+"_elbow"] = float(joints[side+"_elbow"].bend_sign)*lerpf((.68 if zone=="head" else .34)*reaction+.12,.48,ground_blend)
	for side in ["near","far"]:
		var hip_air = (.34 if side=="near" else -.24)*reaction
		if zone=="flank": hip_air *= -1.35
		targets[side+"_hip"] = lerpf(hip_air,.28 if side=="near" else -.12,ground_blend)
		targets[side+"_knee"] = float(joints[side+"_knee"].bend_sign)*lerpf((.72 if zone=="flank" else .34)*reaction+.12,.50 if side=="near" else .30,ground_blend)
	if grounded and not visual.detached_pose.is_empty():
		_ground_targets(targets,ground_blend)
	return targets

func _ground_targets(targets: Dictionary, blend: float) -> void:
	# A shoulder/hip supported body must be able to descend after the first
	# boot touches. Solve limb TARGETS along the floor, then let angular
	# momentum/damping reach them. Never teleport a joint or shrink a bone.
	var level = lowest_core_point()
	var spine = float(joints.spine.angle)
	var mirror = Vector2(int(fighter.direction),1)
	for side in ["near","far"]:
		var leg: Dictionary = initial_legs[side]
		var foot_turn = float(joints[side+"_hip"].angle)+float(joints[side+"_knee"].angle)
		var foot_below_ankle = ((leg.foot-leg.ankle).rotated(foot_turn)*mirror).rotated(rotation).y
		# On a forward fall the boot points DOWN from its ankle. Account for
		# that live orientation, or a 19-unit ankle margin still leaves the
		# sole supporting the torso sixteen units above the floor.
		var clearance = maxf(19.0,foot_below_ankle+17.0)
		var solution = _ground_chain(leg.hip*mirror,(leg.knee-leg.hip)*mirror,(leg.ankle-leg.knee)*mirror,side+"_hip",side+"_knee",float(fighter.direction),level,-roll_direction,clearance)
		targets[side+"_hip"] = lerpf(float(targets[side+"_hip"]),solution.x,blend)
		targets[side+"_knee"] = lerpf(float(targets[side+"_knee"]),solution.y,blend)
	for side in ["left","right"]:
		var arm: Dictionary = initial_pose[side]
		var margin = 13.0
		var support_offsets = PackedVector2Array()
		if side=="left" and float(fighter.get("shield",0.0))>0.0:
			var initial_frame = Rider.shield_pose_transform(initial_pose,fighter)
			for point in Rider.Shield.polygon(str(fighter.stats.get("shield_shape","kite")),float(fighter.stats.get("shield_scale",1.0))):
				support_offsets.append((initial_frame*point-initial_pose.left.hand).rotated(spine+rotation))
		var solution = _ground_chain(arm.shoulder.rotated(spine),(arm.elbow-arm.shoulder).rotated(spine),(arm.hand-arm.elbow).rotated(spine),side+"_upper",side+"_elbow",1.0,level,roll_direction,margin,true,support_offsets)
		targets[side+"_upper"] = lerpf(float(targets[side+"_upper"]),solution.x,blend)
		targets[side+"_elbow"] = lerpf(float(targets[side+"_elbow"]),solution.y,blend)

func _ground_chain(origin: Vector2, upper: Vector2, lower: Vector2, upper_key: String, lower_key: String, angle_sign: float, level: float, along: float, margin: float, arm_support: bool = false, support_offsets: PackedVector2Array = PackedVector2Array()) -> Vector2:
	var start = origin.rotated(rotation)
	var u = upper.rotated(rotation)
	var v = lower.rotated(rotation)
	var upper_joint: Dictionary = joints[upper_key]
	var lower_joint: Dictionary = joints[lower_key]
	var result = Vector2(float(upper_joint.angle),float(lower_joint.angle))
	var best = INF
	# For a strapped shield the contact endpoint is a shield corner, not a
	# hand plus last frame's vertical clearance. Treat each corner as a rigid
	# extension of the forearm while solving; the actual bones never stretch.
	var endpoints = PackedVector2Array([Vector2.ZERO])
	endpoints.append_array(support_offsets)
	for endpoint in endpoints:
		var distal = v+endpoint
		if distal.length()<.01: continue
		var length = u.length()+distal.length()
		var offsets = [along*length*.62,along*length*.82,along*length*.96]
		if arm_support:
			var present = u.rotated(float(upper_joint.angle)*angle_sign)+distal.rotated((float(upper_joint.angle)+float(lower_joint.angle))*angle_sign)
			offsets.append_array([-along*length*.40,-along*length*.70,present.x,0.0])
		var contact_margin = margin if support_offsets.is_empty() else (13.0 if endpoint==Vector2.ZERO else 7.0)
		for candidate in range(offsets.size()):
			var target = Vector2(start.x+float(offsets[candidate]),level-contact_margin)
			var ray = target-start
			var distance = clampf(ray.length(),absf(u.length()-distal.length())+.01,u.length()+distal.length()-.01)
			var bend = acos(clampf((u.length_squared()+distance*distance-distal.length_squared())/(2*u.length()*distance),-1,1))
			for pole in [-1.0,1.0]:
				var first = angle_difference(u.angle(),ray.angle()+bend*pole)/angle_sign
				first = clampf(first,float(upper_joint.minimum),float(upper_joint.maximum))
				var elbow = start+u.rotated(first*angle_sign)
				var second = angle_difference(distal.angle()+first*angle_sign,(target-elbow).angle())/angle_sign
				second = clampf(second,float(lower_joint.minimum),float(lower_joint.maximum))
				var turn = (first+second)*angle_sign
				var end = elbow+v.rotated(turn)
				var contact_end = elbow+distal.rotated(turn)
				var candidate_margin = margin if support_offsets.is_empty() else 13.0
				var down = Vector2(sin(turn),cos(turn))
				for point in support_offsets:
					candidate_margin = maxf(candidate_margin,point.dot(down)+7.0)
				var below = maxf(0.0,maxf(elbow.y+10.0,end.y+candidate_margin)-level)
				# Clearance dominates, with a preference for the nearby bend
				# branch. This is a spring target, never a joint position write.
				var travel = absf(first-float(upper_joint.angle))+absf(second-float(lower_joint.angle))
				var score = below*40.0+contact_end.distance_to(target)+absf(first)*2.0+absf(second)*2.0+travel*8.0+(8.0 if candidate>=3 else 0.0)
				if score<best:
					best = score
					result = Vector2(first,second)
	return result

func _advance_joints(dt: float) -> void:
	var targets = _joint_targets()
	for name in joints:
		var joint: Dictionary = joints[name]
		var target = clampf(float(targets[name]),float(joint.minimum),float(joint.maximum))
		var damping = float(joint.damping)+(4.5 if grounded else 0.0)
		# Root rotation transfers inertia to limbs at different rates. No
		# random kick, identical inputs/blood settings have identical motion.
		var lag = -.26*angular_velocity if name.ends_with("_upper") else 0.0
		if name=="head": lag = -.15*float(joints.spine.velocity)
		joint.velocity += (float(joint.stiffness)*(target-float(joint.angle))-damping*float(joint.velocity)+lag)*dt
		joint.velocity = clampf(float(joint.velocity),-7.0,7.0)
		joint.angle += float(joint.velocity)*dt
		if float(joint.angle)<float(joint.minimum) or float(joint.angle)>float(joint.maximum):
			joint.angle = clampf(float(joint.angle),float(joint.minimum),float(joint.maximum))
			joint.velocity *= -.12

func _landing_response() -> void:
	landing_speed = velocity.length()
	landing_count += 1
	var compression = clampf(absf(velocity.y)/460.0,.2,1.0)
	# The ground arrests translation; head and limbs retain momentum and
	# follow through. Keep the entire skeleton, not separate flying parts.
	joints.spine.velocity += -roll_direction*1.8*compression
	joints.head.velocity += roll_direction*.90*compression
	for side in ["right","left"]:
		joints[side+"_upper"].velocity += -roll_direction*(1.5 if side=="right" else .8)*compression
		joints[side+"_elbow"].velocity += float(joints[side+"_elbow"].bend_sign)*1.4*compression
	for side in ["near","far"]:
		joints[side+"_hip"].velocity += (.95 if side=="near" else -.65)*compression
		joints[side+"_knee"].velocity += float(joints[side+"_knee"].bend_sign)*1.25*compression
	angular_velocity *= .52
	velocity.y = 0.0
	grounded = true
	landed.emit(Vector2(position.x,ground_y),strength)

func _process(delta: float) -> void:
	advance(delta)

func _supported_rest_angle(base_angle: float) -> float:
	var trace_started=Trace099.begin()
	var result = _supported_rest_angle_measured099(base_angle)
	Trace099.measure("fall_support",trace_started)
	return result

func _supported_rest_angle_measured099(base_angle: float) -> float:
	# A fixed flat-body target can leave the whole rider balanced on an
	# elbow at its anatomical limit. Lower the torso's centre of mass over
	# the actual contact envelope instead. This only changes a spring target:
	# joint limits, bone lengths and angular velocity integration stay intact.
	if support_hull099.is_empty(): support_hull099=Geometry2D.convex_hull(body_points())
	var points = support_hull099
	var center: Vector2 = visual.detached_pose.torso_transform*Vector2(0,-38)
	var best_angle = base_angle
	var best_score = INF
	# A deep backward seat can leave the strapped shield at the old 18-degree
	# search boundary. Permit another 14 degrees of settling roll so the
	# shoulder can take weight; the spring still integrates the turn.
	for step in range(-14,15):
		var candidate = base_angle+step*.04
		var down = Vector2(sin(candidate),cos(candidate))
		var floor_offset = -INF
		for point in points: floor_offset = maxf(floor_offset,point.dot(down))
		# Small orientation cost preserves the regional landing direction,
		# while permitting the body to roll past an obstructing elbow/boot.
		var score = floor_offset-center.dot(down)+absf(step*.04)*8.0
		if score<best_score:
			best_score = score
			best_angle = candidate
	return best_angle

func advance(delta: float) -> void:
	var trace_started=Trace099.begin()
	advance_measured099(delta)
	Trace099.measure("fall_integrate",trace_started)

func advance_measured099(delta: float) -> void:
	if settled or not is_instance_valid(visual):
		return
	# Keep the fractional render-time tail for the next call. Integrating an
	# extra tiny step every frame changed which elbow/boot supported the body
	# and repeatedly retargeted the ground solver under slow motion. The same
	# captured hit must settle on the same 120Hz trajectory at variable FPS.
	step_remainder += clampf(delta,0.0,.25)
	while step_remainder+0.000000001>=STEP_SECONDS:
		var dt = STEP_SECONDS
		step_remainder = maxf(0.0,step_remainder-dt)
		age += dt
		_advance_joints(dt)
		_update_pose()
		if age>=.22 and not is_instance_valid(loose_lance):
			_release_lance()
		if not grounded:
			velocity.y += 900.0*dt
			# Airborne rotation keeps impact momentum; a weak orientation bias
			# avoids endless tumbling while the articulated limbs lag behind.
			angular_velocity += (3.0*angle_difference(rotation,target_rotation)-1.1*angular_velocity)*dt
			position += velocity*dt
		else:
			ground_age += dt
			velocity.x *= exp(-6.5*dt)
			position.x += velocity.x*dt
			var support_angle = target_rotation-float(joints.spine.angle)*.65
			if not rest_targets.is_empty():
				support_angle = rest_angle
			elif ground_age>.25:
				support_angle = _supported_rest_angle(support_angle)
			angular_velocity += (34.0*angle_difference(rotation,support_angle)-10.0*angular_velocity)*dt
		angular_velocity = clampf(angular_velocity,-5.0,5.0)
		rotation += angular_velocity*dt
		var lowest = lowest_body_point()
		if position.y+lowest>=ground_y or grounded:
			position.y = ground_y-lowest
			if not grounded:
				_landing_response()
		# Once the trunk has found support, keep its chosen rest TARGETS.
		# Re-solving from the moving elbows/feet every step made quiet limbs
		# slowly chase themselves for seconds. Momentum and damping continue;
		# no joint, velocity or body position is frozen to finish the animation.
		if grounded and ground_age>.65:
			var gap = support_gap()
			if not rest_targets.is_empty() and gap>10.0:
				rest_targets.clear()
			elif rest_targets.is_empty() and gap<8.0 and absf(angular_velocity)<.25:
				rest_angle = _supported_rest_angle(target_rotation-float(joints.spine.angle)*.65)
				rest_targets = _joint_targets().duplicate()
		if grounded and ground_age>.85:
			var remaining_motion = absf(angular_velocity)
			for joint in joints.values():
				remaining_motion = maxf(remaining_motion,absf(float(joint.velocity)))
			settled = remaining_motion<.07 and absf(velocity.x)<1.0 and support_gap()<14.0
		if settled:
			step_remainder = 0.0
			break
	far_leg.z_index = 0 if age>.23 else (-3 if ground_y>12 else -1)
	visual.queue_redraw()
	far_leg.queue_redraw()

func _update_pose() -> void:
	# The shape is immutable between fixed physics steps. Ground support and
	# camera framing reuse it; neither pose nor the 120Hz integration changes.
	pose_points099=PackedVector2Array()
	support_hull099=PackedVector2Array()
	var pose = initial_pose.duplicate(true)
	var legs = initial_legs.duplicate(true)
	var spine = float(joints.spine.angle)
	pose.torso_transform = Transform2D(spine,Vector2.ZERO)*initial_pose.torso_transform
	pose.head_rotation = float(joints.head.angle)
	for side in ["left","right"]:
		var arm: Dictionary = initial_pose[side]
		var upper: Vector2 = arm.elbow-arm.shoulder
		var lower: Vector2 = arm.hand-arm.elbow
		var upper_turn = spine+float(joints[side+"_upper"].angle)
		var lower_turn = float(joints[side+"_elbow"].angle)
		pose[side].shoulder = arm.shoulder.rotated(spine)
		pose[side].elbow = pose[side].shoulder+upper.rotated(upper_turn)
		pose[side].hand = pose[side].elbow+lower.rotated(upper_turn+lower_turn)
	# Keep the captured strap/forearm relationship. Following only the spine
	# made the shield rotate independently of its arm by up to 119 degrees.
	# This shared frame also drives the support envelope and floor solver.
	var shield_turn = spine+float(joints.left_upper.angle)+float(joints.left_elbow.angle)
	var shield_frame = Transform2D(shield_turn,Vector2.ZERO)*Rider.shield_pose_transform(initial_pose,fighter)
	shield_frame.origin = pose.left.hand-shield_frame.basis_xform(Vector2(-10,4))
	pose["shield_transform"] = shield_frame
	pose.shield_center = shield_frame.origin
	pose.shield_grip = pose.left.hand
	for side in ["near","far"]:
		var leg: Dictionary = initial_legs[side]
		var thigh: Vector2 = leg.knee-leg.hip
		var shin: Vector2 = leg.ankle-leg.knee
		var hip_turn = float(joints[side+"_hip"].angle)
		var shin_turn = hip_turn+float(joints[side+"_knee"].angle)
		legs[side].knee = leg.hip+thigh.rotated(hip_turn)
		legs[side].ankle = legs[side].knee+shin.rotated(shin_turn)
		# The existing boot is part of the knee-to-ankle patch. Its collision
		# envelope must use that same shin rotation, not an invisible ankle.
		legs[side].foot = legs[side].ankle+(leg.foot-leg.ankle).rotated(shin_turn)
	var wrist_turn = spine+float(joints.right_upper.angle)*.45+float(joints.right_elbow.angle)*.25
	for renderer in [visual,far_leg]:
		renderer.detached_pose = pose
		renderer.detached_legs = legs
		renderer.stirrup_alpha = 1.0-smoothstep(.02,.18,age)
		# A continuous wrist response follows the moving arm. Release reads
		# this same hand and ray, rather than spawning a differently aimed lance.
		renderer.fighter.aim = initial_aim+int(fighter.direction)*wrist_turn

func body_points() -> PackedVector2Array:
	if not pose_points099.is_empty(): return pose_points099
	var points = PackedVector2Array()
	var pose: Dictionary = visual.detached_pose
	var torso: Transform2D = pose.torso_transform
	var fit: Dictionary = Rider.HeadFit.layout(fighter.stats)
	var head: Rect2 = fit.helmet
	var head_transform = Rider.head_transform(pose,fighter)
	for p in [head.position,Vector2(head.end.x,head.position.y),head.end,Vector2(head.position.x,head.end.y)]:
		points.append(head_transform*p)
	for p in [Vector2(-38,-80),Vector2(38,-80),Vector2(-34,8),Vector2(34,8)]:
		points.append(torso*p)
	for side in ["left","right"]:
		for joint in ["shoulder","elbow","hand"]:
			points.append(pose[side][joint]+Vector2(0,9))
	var mirror = Vector2(int(fighter.direction),1)
	if float(fighter.get("shield",0.0))>0.0:
		var shield_frame = Rider.shield_pose_transform(pose,fighter)
		for point in Rider.Shield.polygon(str(fighter.stats.get("shield_shape","kite")),float(fighter.stats.get("shield_scale",1.0))):
			points.append(shield_frame*point)
	for side in ["near","far"]:
		for joint in ["hip","knee","ankle","foot"]:
			var point: Vector2 = visual.detached_legs[side][joint]*mirror
			var radius = 12.0 if joint=="foot" else 8.0
			# Include the boot/calf silhouette, not only a zero-width skeleton.
			for offset in [Vector2(radius,0),Vector2(-radius,0),Vector2(0,radius),Vector2(0,-radius)]:
				points.append(point+offset)
	pose_points099=points
	return points

func lowest_core_point() -> float:
	var pose: Dictionary = visual.detached_pose
	var torso: Transform2D = pose.torso_transform
	var head_transform = Rider.head_transform(pose,fighter)
	var head: Rect2 = Rider.HeadFit.layout(fighter.stats).helmet
	var lowest = -INF
	for point in [Vector2(-38,-80),Vector2(38,-80),Vector2(-34,8),Vector2(34,8)]:
		lowest = maxf(lowest,(torso*point).rotated(rotation).y)
	for point in [head.position,Vector2(head.end.x,head.position.y),head.end,Vector2(head.position.x,head.end.y)]:
		lowest = maxf(lowest,(head_transform*point).rotated(rotation).y)
	return lowest+5.0

func support_gap() -> float:
	return maxf(0.0,ground_y-(position.y+lowest_core_point()))

func _release_lance() -> void:
	# Place a separate whole weapon on the exact final grip/ray, before hiding
	# the held draw. Its own collision can rotate it onto the ground without
	# lifting a rider by the tip or leaving a fixed shaft through the floor.
	var facing = int(fighter.direction)
	var ray = Vector2(cos(float(fighter.aim))*facing,sin(float(fighter.aim))).rotated(rotation)
	var grip = position+Vector2(visual.detached_pose.right.hand).rotated(rotation)
	var length = Model.lance_length(fighter)
	var center_from_grip = (length-67.0)*.5
	loose_lance = RigidBody2D.new()
	loose_lance.position = grip+ray*center_from_grip
	loose_lance.rotation = ray.angle()
	loose_lance.z_index = z_index
	loose_lance.mass = 1.2
	loose_lance.collision_layer = 4
	loose_lance.collision_mask = 32 if float(fighter.get("lane_y",0.0))>=0 else 16
	loose_lance.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	loose_lance.linear_damp = .7
	loose_lance.angular_damp = 1.4
	loose_lance.linear_velocity = velocity+Vector2(direction*35,-15)
	loose_lance.angular_velocity = angular_velocity*.65+direction*1.3
	var collider = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(length+67.0,7)
	collider.shape = shape
	loose_lance.add_child(collider)
	var renderer = Rider.new()
	renderer.fighter = fighter.duplicate(true)
	renderer.fighter.direction = 1
	renderer.fighter.aim = 0.0
	renderer.mode = visual.mode
	renderer.lance_only = true
	renderer.position.x = -center_from_grip
	renderer.lance_recoil = visual.lance_recoil
	renderer.lance_velocity = visual.lance_velocity
	loose_lance.add_child(renderer)
	get_parent().add_child(loose_lance)
	visual.detached_lance_visible = false
	far_leg.detached_lance_visible = false

func lowest_body_point() -> float:
	var lowest = -INF
	for point in body_points():
		lowest = maxf(lowest,point.rotated(rotation).y)
	return lowest+5.0

func world_body_rect() -> Rect2:
	var points = body_points()
	var rect = Rect2(to_global(points[0]),Vector2.ZERO)
	for point in points:
		rect = rect.expand(to_global(point))
	return rect.grow(8.0)
