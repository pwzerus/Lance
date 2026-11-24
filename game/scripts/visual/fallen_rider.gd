class_name FallenRider
extends Node2D
const Trace099 = preload("res://scripts/core/frame_trace099.gd")
## A single articulated rider, captured from the mounted renderer at contact.
## Visual ballistics do not feed back into scoring, damage or death decisions.
##
## PHYS-114: the body is a RiderBody114 (rigid torso + jointed head and limbs
## with anatomical ranges, masses, floor/horse-back collision and muscles).
## The node's transform IS the torso: position/rotation follow the rigid
## torso, so every renderer, camera, shadow and test that reads body_points(),
## world_body_rect(), rotation or the detached pose keeps working unchanged.
## The former single root body with small spring offsets around the SEAT pose
## (DEV-113 and earlier) could not straighten a hip or lower a riding arm;
## lying on the back left the thighs pointing up and the shield held high.
signal landed(point: Vector2, strength: float)

const Rider = preload("res://scripts/visual/rider_view.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const Body = preload("res://scripts/visual/rider_body114.gd")
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
var contact_history113: Array = []
var contacted_parts113: Dictionary = {}
var trunk_supported113 = false
var shield_contact_outline113 = PackedVector2Array()
# PHYS-114
var body = null
var conscious114 = true
var own_speed114 = 0.0
var com_local114 = Vector2.ZERO
var quiet114 = 0.0
var resting114 = 0.0
var held_aim114 = INF
const WRIST_RATE114 = 9.0
# The drawn skeleton for this step (exact bone lengths and joint ranges).
var display114 = PackedVector2Array()
const SETTLE_TRAVEL114 = 2.0
# The seat is narrow (sitting bones), so a limp trunk cannot balance upright.
const TORSO_OUTLINE114 = [Vector2(-34,-84),Vector2(34,-84),Vector2(-41,-46),Vector2(41,-46),Vector2(-31,-8),Vector2(31,-8),Vector2(-7,9),Vector2(7,9)]
const SETTLE_LIMIT114 = 7.0
var settle_samples114: Array = []

func setup(value: Dictionary, event: Dictionary, mounted: RiderView = null) -> void:
	fighter = value.duplicate(true)
	# A broken remnant still touches the floor, but never regains a combat
	# blocking polygon. Cache this immutable gear outline for the whole fall.
	shield_contact_outline113=Rider.Shield.polygon(str(fighter.stats.get("shield_shape","kite")),float(fighter.stats.get("shield_scale",1.0))) if float(fighter.get("shield",0.0))>0.0 else Rider.ShieldArt.remnant_polygon(fighter.stats)
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
	toppled = str(event.get("ko_reason","impact")) in ["balance","seat","slip"]
	var own = float(event.get("defender_speed",fighter.speed))*int(fighter.direction)
	own_speed114 = own
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
	if str(event.get("ko_reason","")) in ["seat","slip"]:
		# No opposing lance supplied an impulse. Retain ground travel and the
		# actual outward seat velocity instead of inventing a recoil or lift.
		velocity=Vector2(own+float(fighter.get("seat_velocity",0.0))*int(fighter.direction),float(fighter.get("mount_velocity_y",0.0)))
		angular_velocity=float(direction)*.65
	conscious114 = not bool(fighter.get("unconscious",false)) and not bool(fighter.get("dead",false)) and float(fighter.get("consciousness",100.0))>15.0
	_make_body(lift)
	_sync_joints(0.0)
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
			renderer.clock = mounted.clock
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

func _make_body(lift: float) -> void:
	# Capture every part in world space at the exact mounted pose: the first
	# step must not snap a limb, the helmet or the shield.
	var facing = int(fighter.direction)
	var mirror = Vector2(facing,1)
	var origin = position
	var torso: Transform2D = initial_pose.torso_transform
	com_local114 = torso*Vector2(0,-38)
	var stats: Dictionary = fighter.stats
	var armor_kg = float(stats.get("armor_kg",12.0))
	var helmet_kg = float(stats.get("helmet_kg",2.4))
	var shield_kg = float(stats.get("shield_kg",3.0)) if float(fighter.get("shield",0.0))>0.0 else 1.0
	var upper = 2.6+armor_kg*.06
	var fore = 1.9+armor_kg*.04
	var thigh = 9.5+armor_kg*.08
	var shin = 4.6+armor_kg*.06
	var fit = Rider.HeadFit.layout(stats)
	var neck_local = torso*Vector2(float(fit.collar.center[0]),float(fit.collar.center[1])+2.0)
	var head_frame = Rider.head_transform(initial_pose,fighter)
	var helmet: Rect2 = fit.helmet
	var corners = []
	# Rounded trunk outline (shoulders, ribs, pelvis). A flat 68px plate
	# bottom let a limp body sit upright on the ground like a box.
	for point in TORSO_OUTLINE114:
		corners.append(origin+torso*point)
	var head_corners = []
	for point in [helmet.position,Vector2(helmet.end.x,helmet.position.y),helmet.end,Vector2(helmet.position.x,helmet.end.y)]:
		head_corners.append(origin+head_frame*point)
	var boots = {}
	for side in ["near","far"]:
		var outline = []
		for point in Rider.boot_outline113(initial_legs[side]):
			outline.append(origin+point*mirror)
		boots[side] = outline
	var shield = []
	var shield_frame = Rider.shield_pose_transform(initial_pose,fighter)
	for point in shield_contact_outline113:
		shield.append(origin+shield_frame*point)
	var points = [origin+initial_pose.left.elbow,origin+initial_pose.left.hand,origin+initial_pose.right.elbow,origin+initial_pose.right.hand,
		origin+initial_legs.near.knee*mirror,origin+initial_legs.near.ankle*mirror,origin+initial_legs.far.knee*mirror,origin+initial_legs.far.ankle*mirror,
		origin+head_frame*helmet.get_center()]
	var com = origin+com_local114
	# The trunk's own tumble is a small share of the former rigid-body spin:
	# the articulated legs, carried on by the horse, now supply most of the
	# backward turn. Larger shares landed riders past flat, head first.
	# Every lance arrives from the front, so every impact tips the rider
	# backward (direction); the old forward roll for flank hits ended kneeling
	# with a leg standing up (phys114-articulation15-23).
	var spin = absf(angular_velocity)*.12*direction
	var velocities = []
	for point in points:
		var r: Vector2 = point-com
		velocities.append(velocity+Vector2(-r.y,r.x)*spin)
	# The lance stops the trunk; the horse still carries the legs, which
	# makes the body pivot over the cantle instead of being thrown as a block.
	var leg_carry = .22 if toppled else .28
	for index in [Body.KNEE_N,Body.ANKLE_N,Body.KNEE_F,Body.ANKLE_F]:
		velocities[index] = Vector2(velocities[index]).lerp(Vector2(own_speed114,-lift*.25),leg_carry)
	# The head keeps part of its own travel (body hit) or is driven back by
	# the lance itself (head hit), so the neck whips instead of staying rigid.
	if zone=="head":
		velocities[Body.HEAD] = Vector2(velocities[Body.HEAD])+Vector2(direction*lerpf(60,130,strength),-20)
	else:
		velocities[Body.HEAD] = Vector2(velocities[Body.HEAD]).lerp(Vector2(own_speed114,-lift),.30)
	var masses = [upper*.5+fore*.5,fore*.5+shield_kg,upper*.5+fore*.5,fore*.5+1.0,
		thigh*.5+shin*.5,shin*.5+1.2,thigh*.5+shin*.5,shin*.5+1.2,5.5+helmet_kg]
	var data = {"facing":facing,"ground":ground_y-5.0,"torso_mass":38.0+armor_kg*.55+upper+thigh,
		"com":com,"com_velocity":velocity,"angular_velocity":spin,"down":torso.basis_xform(Vector2.DOWN),
		"corners":corners,"anchors":{"shoulder_l":origin+initial_pose.left.shoulder,"shoulder_r":origin+initial_pose.right.shoulder,
			"hip_n":origin+initial_legs.near.hip*mirror,"hip_f":origin+initial_legs.far.hip*mirror,"neck":origin+neck_local},
		"points":points,"velocities":velocities,"masses":masses,"radii":[9.0,9.0,9.0,9.0,8.0,0.0,8.0,0.0,0.0],
		"boot_n":boots.near,"boot_f":boots.far,"shield":shield,"head":head_corners,
		"shield_basis_x":shield_frame.x,"shield_basis_y":shield_frame.y,
		"neck_limit":Rider.DETACHED_NECK_LIMIT113,"conscious":conscious114}
	# No moving horse-back support: in phys114-articulation01 the cantle,
	# running on under the stopped seat, kept lifting it and threw every rider
	# into a high backward somersault (inverted, legs to the sky). The horse
	# still carries the legs through their initial velocity above.
	body = Body.new()
	body.build(data)
	# Back/side landing target, smaller for a flank blow than for chest/helm.
	body.guide_angle = direction*PI*(.40 if zone=="flank" else .47)-float(initial_pose.torso_transform.get_rotation())
	# A rider sliding off with lost balance is steered the same way: at .6 he
	# ended sitting upright in the splits (phys114-edge01/02).
	body.guide_strength = 1.0
	display114 = body.display_points()

func _muscles() -> void:
	# Protective reflex while airborne (reach toward the floor behind/below,
	# tuck the chin and knees), then let go once the body is down. An
	# unconscious or dead rider has no reflex at all.
	var relaxed = {"left_elbow":.30,"right_elbow":.30,"near_hip":.20,"far_hip":.20,"near_knee":.35,"far_knee":.35,"neck":0.0}
	if not conscious114:
		# Limp: no reflex at all, only passive joint damping.
		body.set_muscles(0.0,relaxed)
		return
	var facing = int(fighter.direction)
	var reach = Vector2(.25,1.0) if toppled else Vector2(-.55,1.0)
	var down = body.down_axis()
	var shoulder = wrapf(body.af(down)-atan2(reach.y,reach.x),-PI,PI)
	# In the air the rider keeps his riding seat shape (as unhorsed jousters
	# do) and only reaches back with the arms. Tucking the knees lowered the
	# inertia, and straightening the legs counter-rotated the trunk; either
	# turned the fall into a head-down somersault (phys114-articulation01-03).
	var brace = {"left_upper":shoulder,"right_upper":shoulder,"left_elbow":.35,"right_elbow":.35,
		"near_hip":body.captured("near_hip"),"far_hip":body.captured("far_hip"),
		"near_knee":body.captured("near_knee"),"far_knee":body.captured("far_knee"),"neck":.22*facing,
		"left_elbow_tone":.6,"right_elbow_tone":.6,"near_hip_tone":.5,"far_hip_tone":.5,"near_knee_tone":.5,"far_knee_tone":.5}
	var stunned = .55 if zone=="head" else 1.0
	if body.grounded_age<0.0:
		# Airborne: the seat shape is held loosely and the arms are left to
		# their own inertia. A hard backward arm reach pitched the trunk back by
		# reaction and added to the somersault (phys114-trace01/02).
		var air = brace.duplicate()
		air.erase("left_upper")
		air.erase("right_upper")
		body.set_muscles(smoothstep(.06,.16,age)*.22*stunned,air)
		return
	var settle = smoothstep(0.0,.40,body.grounded_age)
	var blended = relaxed.duplicate()
	for key in brace:
		if relaxed.has(key) and not key.ends_with("_tone"):
			blended[key] = lerpf(float(brace[key]),float(relaxed[key]),settle)
		elif not relaxed.has(key):
			blended[key] = brace[key]
	if settle>=1.0:
		blended.erase("left_upper")
		blended.erase("right_upper")
	# Legs go limp on landing. Actively straightening them while lying on the
	# back pushed the trunk into a backward roll onto the helmet
	# (phys114-articulation12); gravity lowers them instead.
	for key in ["near_hip","far_hip","near_knee","far_knee"]:
		blended.erase(key)
	# On the floor the reflex lets go completely: a residual tone would keep
	# pressing limbs against the ground and the body would never come to rest.
	var tone = .38*exp(-body.grounded_age/.35)*stunned
	body.set_muscles(tone if tone>.01 else 0.0,blended)

func _sync_from_body() -> void:
	rotation = body.theta
	position = body.x-com_local114.rotated(rotation)
	velocity = body.v
	angular_velocity = body.omega

func _local(world: Vector2) -> Vector2:
	return (world-position).rotated(-rotation)

static func _turn(from: Vector2, to: Vector2) -> float:
	return wrapf(to.angle()-from.angle(),-PI,PI)

func _sync_joints(dt: float) -> void:
	# Former joint dictionary kept for camera/QA readers: angles relative to
	# the captured pose in the same frames as before (arms unmirrored, legs in
	# the facing frame). Limits are the anatomical ranges expressed the same way.
	var facing = int(fighter.direction)
	var mirror = Vector2(facing,1)
	var values = {"spine":0.0,"head":clampf(body.neck_angle(),-body.neck_limit,body.neck_limit)}
	var limits = {"spine":Vector2(-.42,.42),"head":Vector2(-body.neck_limit,body.neck_limit)}
	for side in ["left","right"]:
		var arm: Dictionary = initial_pose[side]
		var elbow = _local(display114[Body.ELBOW_L if side=="left" else Body.ELBOW_R])
		var hand = _local(display114[Body.HAND_L if side=="left" else Body.HAND_R])
		var upper_turn = _turn(arm.elbow-arm.shoulder,elbow-arm.shoulder)
		values[side+"_upper"] = upper_turn
		values[side+"_elbow"] = wrapf(_turn(arm.hand-arm.elbow,hand-elbow)-upper_turn,-PI,PI)
	for side in ["near","far"]:
		var leg: Dictionary = initial_legs[side]
		var knee = _local(display114[Body.KNEE_N if side=="near" else Body.KNEE_F])*mirror
		var ankle = _local(display114[Body.ANKLE_N if side=="near" else Body.ANKLE_F])*mirror
		var thigh_turn = _turn(leg.knee-leg.hip,knee-leg.hip)
		values[side+"_hip"] = thigh_turn
		values[side+"_knee"] = wrapf(_turn(leg.ankle-leg.knee,ankle-knee)-thigh_turn,-PI,PI)
	for joint in body.joints:
		var lo = float(joint.lo)-float(joint.captured)
		var hi = float(joint.hi)-float(joint.captured)
		match str(joint.kind):
			"shoulder","elbow": limits[joint.name] = Vector2(minf(-hi*facing,-lo*facing),maxf(-hi*facing,-lo*facing))
			"hip": limits[joint.name] = Vector2(-hi,-lo)
			_: limits[joint.name] = Vector2(lo,hi)
	for name in values:
		var previous: Dictionary = joints.get(name,{})
		var angle = float(values[name])
		var range_value: Vector2 = limits[name]
		# Report the angle on the same turn as its range (a shoulder range is
		# wider than pi, so a wrapped value can sit "outside" it by 2 pi).
		if angle<range_value.x and angle+TAU<=range_value.y+.001: angle += TAU
		elif angle>range_value.y and angle-TAU>=range_value.x-.001: angle -= TAU
		var rate = (angle-float(previous.get("angle",angle)))/dt if dt>0.0 else 0.0
		joints[name] = {"angle":angle,"velocity":rate,"minimum":range_value.x,"maximum":range_value.y,"stiffness":0.0,"damping":0.0,"bend_sign":1.0}

func _joint_targets() -> Dictionary:
	# Current muscle targets in the joint dictionary's relative frames. A joint
	# with no active target (a limp or settled limb) reports its own angle.
	var facing = int(fighter.direction)
	var result = {}
	for name in joints:
		result[name] = float(joints[name].angle)
	for joint in body.joints:
		if not body.targets.has(joint.name) or body.tone<=0.0: continue
		var change = body.target_flex(joint)-body.range_flex(joint)
		match str(joint.kind):
			"shoulder","elbow": result[joint.name] = float(joints[joint.name].angle)-change*facing
			"hip": result[joint.name] = float(joints[joint.name].angle)-change
			_: result[joint.name] = float(joints[joint.name].angle)+change
	if body.targets.has("neck") and body.tone>0.0:
		result.head = float(body.targets.neck)
	return result

func _supported_rest_angle(_base_angle: float) -> float:
	# DEV-113 QA reader. The PHYS-114 body has no imposed rest orientation:
	# it rests where its own contacts hold it, which is the current rotation.
	return rotation

func _landing_response() -> void:
	landing_speed = velocity.length()
	landing_count += 1
	# First ground contact is an event, not a freeze of the complete body.
	grounded = true
	landed.emit(Vector2(position.x,ground_y),strength)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	var trace_started=Trace099.begin()
	advance_measured099(delta)
	Trace099.measure("fall_integrate",trace_started)

func advance_measured099(delta: float) -> void:
	if settled or not is_instance_valid(visual):
		return
	# Keep the fractional render-time tail for the next call. The same
	# captured hit settles on the same 120Hz trajectory at variable FPS.
	step_remainder += clampf(delta,0.0,.25)
	while step_remainder+0.000000001>=STEP_SECONDS:
		var dt = STEP_SECONDS
		step_remainder = maxf(0.0,step_remainder-dt)
		age += dt
		_muscles()
		# Energy loss of armour and body on the floor, but only once the TRUNK
		# lies on it: a body balanced on its helmet with the legs up is not at
		# rest and must be free to topple (the first damping froze it there).
		var lying = absf(wrapf(rotation+float(initial_pose.torso_transform.get_rotation()),-PI,PI))
		var flat = smoothstep(.75,1.10,lying)*(1.0-smoothstep(2.05,2.40,lying))
		resting114 = minf(resting114+dt,2.0) if body.torso_contact and flat>0.0 else maxf(0.0,resting114-2.0*dt)
		# Three seconds after landing every remaining sway is damped whatever the
		# pose, so a slow creep cannot outlast the fall presentation.
		var late = smoothstep(2.6,3.2,ground_age)
		body.rest = maxf(smoothstep(.15,.8,resting114)*flat,late)
		body.rest_all = resting114>1.2 or late>0.0
		body.step(dt)
		_sync_from_body()
		display114 = body.display_points()
		_sync_joints(dt)
		_update_pose()
		# A small positional correction keeps the DRAWN silhouette (boot art,
		# shield rim, helmet box) on the floor; velocities are untouched.
		var overlap = position.y+lowest_body_point()-ground_y
		if overlap>0.0:
			position.y -= overlap
			body.translate(Vector2(0,-overlap))
		if age>=.22 and not is_instance_valid(loose_lance):
			_release_lance()
		if grounded: ground_age += dt
		for part in body.contacts:
			if not contacted_parts113.has(part):
				contacted_parts113[part] = age
				contact_history113.append({"part":part,"age":age,"root_speed_y":velocity.y,"support_gap":support_gap()})
		if not grounded and not body.contacts.is_empty():
			_landing_response()
		if body.core_contact: trunk_supported113 = true
		# Rest is judged by what is SEEN: the drawn joints and the trunk have
		# moved less than a pixel and a half over the last .3 s. A solver's
		# sub-pixel contact jitter reads as speed but is not visible motion.
		if int(round(age/dt))%12==0:
			var sample = display114.duplicate()
			sample.append(position)
			sample.append(Vector2(rotation*60.0,0))
			settle_samples114.append(sample)
			if settle_samples114.size()>4: settle_samples114.pop_front()
			# A body resting on an arm or shield (trunk just off the floor) may
			# also finish once the late damping has stilled it.
			var still = settle_samples114.size()==4 and grounded and (trunk_supported113 or ground_age>3.2) and ground_age>.5
			if still:
				var first: PackedVector2Array = settle_samples114[0]
				for i in range(sample.size()):
					if first[i].distance_to(sample[i])>SETTLE_TRAVEL114:
						still = false
						break
			quiet114 = 1.0 if still else 0.0
		settled = quiet114>0.0 or age>=SETTLE_LIMIT114
		if settled:
			step_remainder = 0.0
			break
	far_leg.z_index = 0 if age>.23 else (-3 if ground_y>12 else -1)
	# After leaving the saddle, a distant fallen rider must remain readable
	# in front of the surviving rider's boots as well as the horse and rail.
	# Keep the initial lane layering for capture continuity; promote once,
	# without fading either person or moving the physical trajectory.
	if age>.23 and ground_y<12.0: z_index=-7
	visual.queue_redraw()
	far_leg.queue_redraw()

func _update_pose() -> void:
	# The shape is immutable between fixed physics steps. Ground support and
	# camera framing reuse it. Every joint position comes from the body.
	pose_points099=PackedVector2Array()
	support_hull099=PackedVector2Array()
	var facing = int(fighter.direction)
	var mirror = Vector2(facing,1)
	var pose = initial_pose.duplicate(true)
	var legs = initial_legs.duplicate(true)
	pose.head_rotation = clampf(body.neck_angle(),-body.neck_limit,body.neck_limit)
	# Bone DIRECTIONS come from the solver; drawn lengths are exactly the
	# captured ones, so a sub-pixel solver residual never stretches the art.
	for side in ["left","right"]:
		var arm: Dictionary = initial_pose[side]
		var elbow = _local(display114[Body.ELBOW_L if side=="left" else Body.ELBOW_R])
		var hand = _local(display114[Body.HAND_L if side=="left" else Body.HAND_R])
		pose[side].elbow = arm.shoulder+(elbow-arm.shoulder).normalized()*arm.shoulder.distance_to(arm.elbow)
		pose[side].hand = pose[side].elbow+(hand-elbow).normalized()*arm.elbow.distance_to(arm.hand)
	# The strapped shield turns with its forearm about the grip.
	var forearm_turn = _turn(initial_pose.left.hand-initial_pose.left.elbow,pose.left.hand-pose.left.elbow)
	var shield_frame = Transform2D(forearm_turn,Vector2.ZERO)*Rider.shield_pose_transform(initial_pose,fighter)
	# PHYS-114: a shield rolled flat on the floor is foreshortened along its
	# own long axis, exactly as its collision outline in the body; the x axis
	# still follows the forearm.
	shield_frame.y *= body.shield_scale_across()
	shield_frame.origin = pose.left.hand-shield_frame.basis_xform(Vector2(-10,4))
	pose["shield_transform"] = shield_frame
	pose.shield_center = shield_frame.origin
	pose.shield_grip = pose.left.hand
	for side in ["near","far"]:
		var leg: Dictionary = initial_legs[side]
		var solved_knee = _local(display114[Body.KNEE_N if side=="near" else Body.KNEE_F])*mirror
		var solved_ankle = _local(display114[Body.ANKLE_N if side=="near" else Body.ANKLE_F])*mirror
		var knee = leg.hip+(solved_knee-leg.hip).normalized()*leg.hip.distance_to(leg.knee)
		var ankle = knee+(solved_ankle-solved_knee).normalized()*leg.knee.distance_to(leg.ankle)
		legs[side].knee = knee
		legs[side].ankle = ankle
		# The boot is part of the shin patch and turns with it.
		legs[side].foot = ankle+(leg.foot-leg.ankle).rotated(_turn(leg.ankle-leg.knee,ankle-knee))
	var wrist_turn = float(joints.right_upper.angle)*.45+float(joints.right_elbow.angle)*.25
	# The held lance follows the freely swinging arm at a wrist's finite rate
	# (a free arm now swings faster than the old spring-limited one).
	var wanted = initial_aim+facing*wrist_turn
	held_aim114 = wanted if held_aim114==INF else move_toward(held_aim114,wanted,WRIST_RATE114*STEP_SECONDS)
	for renderer in [visual,far_leg]:
		if renderer==null: continue
		renderer.detached_pose = pose
		renderer.detached_legs = legs
		renderer.stirrup_alpha = 1.0-smoothstep(.02,.18,age)
		# A continuous wrist response follows the moving arm. Release reads
		# this same hand and ray, rather than spawning a differently aimed lance.
		renderer.fighter.aim = held_aim114

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
	# The same rounded trunk outline the body collides with (8 points).
	for p in TORSO_OUTLINE114:
		points.append(torso*p)
	# Sleeves as discs (radius 9) like the legs: a fixed local +9 turned with
	# the trunk and under-reported a lying body's arms by up to 18 px.
	for side in ["left","right"]:
		for joint in ["shoulder","elbow","hand"]:
			for offset in [Vector2(9,0),Vector2(-9,0),Vector2(0,9),Vector2(0,-9)]:
				points.append(pose[side][joint]+offset)
	var mirror = Vector2(int(fighter.direction),1)
	var shield_frame = Rider.shield_pose_transform(pose,fighter)
	for point in shield_contact_outline113:
		points.append(shield_frame*point)
	for side in ["near","far"]:
		for joint in ["hip","knee"]:
			var point: Vector2 = visual.detached_legs[side][joint]*mirror
			var radius = 8.0
			for offset in [Vector2(radius,0),Vector2(-radius,0),Vector2(0,radius),Vector2(0,-radius)]:
				points.append(point+offset)
		for point in Rider.boot_outline113(visual.detached_legs[side]):
			points.append(point*mirror)
	pose_points099=points
	return points

func lowest_core_point() -> float:
	var pose: Dictionary = visual.detached_pose
	var torso: Transform2D = pose.torso_transform
	var head_transform = Rider.head_transform(pose,fighter)
	var head: Rect2 = Rider.HeadFit.layout(fighter.stats).helmet
	var lowest = -INF
	for point in TORSO_OUTLINE114:
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
	# Carry the velocity of the HELD centre: the real hand velocity of the
	# body plus the shaft's own turn (torso spin and the wrist response).
	var world_hand_rate = body.point_velocity(Body.HAND_R)
	var release_spin = angular_velocity+clampf(float(joints.right_upper.velocity)*.45+float(joints.right_elbow.velocity)*.25,-WRIST_RATE114,WRIST_RATE114)
	var center_rate = world_hand_rate+Vector2(-ray.y,ray.x)*center_from_grip*release_spin
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
	loose_lance.linear_velocity = center_rate
	loose_lance.angular_velocity = release_spin
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
	renderer.clock = visual.clock
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
