extends RefCounted
## PHYS-115 shared, texture-free registration of the rider skeleton.
## Kinematic targets, physics capture and rendering use the same joint lengths
## and head/arm/boot registration. No dependency on JoustMatch or RiderView.
const HeadFit = preload("res://scripts/visual/head_fit.gd")
const Shield = preload("res://scripts/core/shield_geometry.gd")
const ShieldArt = preload("res://scripts/visual/shield_art.gd")
const Gait = preload("res://scripts/visual/horse_gait.gd")
const ARM_UPPER = 44.0
const ARM_LOWER = 46.0
const LANCE_SHOULDER = Vector2(-25,-64)
const SHIELD_SHOULDER = Vector2(25,-64)
const DETACHED_NECK_LIMIT113 = .34
const TORSO_OUTLINE = [Vector2(-34,-84),Vector2(34,-84),Vector2(-41,-46),Vector2(41,-46),Vector2(-31,-8),Vector2(31,-8),Vector2(-7,9),Vector2(7,9)]
const BOOT_OUTLINE113 = [Vector2(744,736),Vector2(868,736),Vector2(873,900),Vector2(873,926),Vector2(872,928),Vector2(870,930),Vector2(798,930),Vector2(761,918),Vector2(749,912),Vector2(744,813)]

static func arms(value: Dictionary, transform: Transform2D, hand_right: Vector2, hand_left: Vector2, shield_center: Vector2) -> Dictionary:
	var facing = int(value.direction)
	var inverse = transform.affine_inverse()
	var right_hand: Vector2 = inverse*hand_right
	var left_hand: Vector2 = inverse*hand_left
	var result = {"torso_transform":transform,"shield_center":shield_center,"shield_grip":transform*left_hand}
	for side in ["right","left"]:
		var shoulder = LANCE_SHOULDER if side=="right" else SHIELD_SHOULDER
		var hand = right_hand if side=="right" else left_hand
		# The distant arm points partly into depth. Keeping both of its bones
		# at full frontal length made the left-facing lance elbow hang at the
		# belt. Project those bones, preserving both real hand/collision anchors.
		# Both anatomical arms need depth projection when distant. A full-
		# length far shield arm folded past its natural elbow range near the
		# upper chest, then left a strapped shield propping up the fallen body.
		# The new shield-aware ground solver preserves this captured geometry.
		var distant = (side=="right" and facing<0) or (side=="left" and facing>0)
		var projection = clampf((shoulder.distance_to(hand)+1.0)/(ARM_UPPER+ARM_LOWER),.64,1.0) if distant else 1.0
		var elbow = arm_elbow(shoulder,hand,ARM_UPPER*projection,ARM_LOWER*projection)
		result[side] = {"shoulder":transform*shoulder,"elbow":transform*elbow,"hand":transform*hand,"projection":projection}
	return result

static func seated_legs(value: Dictionary, body: Dictionary, pivot: Vector2, saddle: Vector2, inertia: float, lift: float) -> Dictionary:
	# Local side-view projection. Depth is supplied by draw order, not by
	# moving both thighs to the visible side.
	# RIDER-064: the hip rides with the rider (seat lag, impact shift) while
	# the foot stands in a stirrup hung from the SADDLE, which moves with the
	# horse. A two-bone knee solves between them with the measured thigh and
	# shin lengths, so the legs absorb the stride instead of moving as one
	# block with the seat. At rest every joint equals the former fixed pose.
	var pitch = float(body.pitch)
	var speed = float(value.get("speed",0.0))
	var phase = float(value.get("gait_phase",0.0))
	var w = Gait.weights(speed)
	var run = w.z+w.w
	var activity = smoothstep(0,85,speed) if bool(value.get("gait_moving",false)) else 0.0
	var lean = clampf(float(value.get("lean",0.0)),-1.0,1.0)
	var result = {}
	var reaction_slide = clampf(float(value.get("reaction_shift",0.0)),-6.0,6.0)
	# ANIM-091: the spur is a visible heel jab. Holding the spur kicks once per
	# stride (fading as the horse reaches full gallop); the moment the horse
	# surges ahead of the seat both heels drive back hard. Checking the horse
	# braces the legs forward, heels down. Legs are art only, not hit targets.
	var drive = float(value.get("motion_drive",0.0))
	var kick = 0.0
	if bool(value.get("boost",false)) and activity>0.0:
		var urge = 1.0-.65*smoothstep(380,480,speed)
		kick = pow(maxf(0.0,sin(phase-.6)),6.0)*urge
	kick = clampf(maxf(kick,inertia*1.7),0.0,1.0)
	var check = clampf(-drive,0.0,1.0)*activity
	# FEEL-094: an unsteady rider bounces out of the saddle (same lift as the
	# rule torso) and the lower legs flap instead of hanging quiet.
	var unsteady = clampf(float(value.get("unsteady",0.0)),0.0,1.0)
	var flap_wave = sin(phase+.4)
	var flap = Vector2(-flap_wave*9.0,-flap_wave*flap_wave*4.0)*unsteady*activity
	# FEEL-097: a lance blow throws the lower legs forward and up, out of the
	# stirrups, while the torso is carried back; the spring overshoot swings
	# them back past the girth before they find the irons again.
	var fling = clampf(float(value.get("reaction_legs",0.0)),-.6,1.5)
	# The negative spring half is a small BACKWARD/downward recovery. The
	# old negative-vector * negative-value product kicked forward twice.
	# Blend gains through neutral so crossing it has no velocity corner.
	var response = Vector2(16.0,-6.0).lerp(Vector2(42.0,-38.0),smoothstep(-.12,.12,fling))
	var thrown = response*fling
	for side in ["far","near"]:
		var far = side=="far"
		var hip_offset = Vector2(14,-8) if far else Vector2(-11,3)
		var rest_knee = Vector2(21,24) if far else Vector2(23,29)
		var rest_ankle = Vector2(10,78) if far else Vector2(7,82)
		var hip = pivot+hip_offset
		hip.x += reaction_slide+float(value.get("seat_offset",0.0))
		hip.y -= lift
		# The stirrup leather swings a little behind the stride; bracing in a
		# lean pushes the feet forward (more when leaning back) and heels down.
		var swing = Vector2(-sin(phase-1.1+(.35 if far else 0.0))*(1.4*w.y+2.8*run),
			cos(phase-1.1)*(.5*w.y+.9*run))*activity
		var brace = Vector2((3.0 if lean>0.0 else 8.0)*absf(lean),-1.5*absf(lean))
		var spur = Vector2(-15.0,-8.0)*kick*(1.0 if far else .9)+Vector2(9.0,3.0)*check
		var ankle = saddle+(hip_offset+rest_ankle).rotated(pitch*.6)+swing+brace+spur+flap*(1.0 if far else .85)
		# The iron hangs from its leather and trails only a fraction of a thrown
		# foot. Without a blow it stays exactly under the boot as before.
		var free_iron = ankle+thrown*(.30 if far else .26)+Vector2(9,11)
		ankle += thrown*(.85 if far else 1.0)
		var thigh = rest_knee.length()
		var shin = (rest_ankle-rest_knee).length()
		var reach = ankle-hip
		var distance = clampf(reach.length(),absf(thigh-shin)+.5,thigh+shin-.5)
		ankle = hip+reach.normalized()*distance
		var bend = acos(clampf((thigh*thigh+distance*distance-shin*shin)/(2.0*thigh*distance),-1.0,1.0))
		# Knee in front of the hip-ankle line, the branch of the measured rest pose.
		var knee = hip+reach.normalized().rotated(-bend)*thigh
		var bar = saddle+(hip_offset+Vector2(-3,-1)).rotated(pitch)
		var stirrup = (ankle+Vector2(9,11)).lerp(free_iron,smoothstep(.05,.35,absf(fling)))
		result[side] = {"hip":hip,"knee":knee,"ankle":ankle,"foot":ankle+Vector2(17,8).rotated(pitch*.6),"bar":bar,"stirrup":stirrup}
	return result

static func head_hinge(pose: Dictionary, value: Dictionary, gait_pitch: float = 0.0) -> Transform2D:
	# Detached neck articulation only; mounted head/target follows the core
	# reaction pose. The default is precisely the previous head registration.
	var angle = clampf(float(pose.get("head_rotation",0.0)),-DETACHED_NECK_LIMIT113,DETACHED_NECK_LIMIT113)
	var fit = HeadFit.layout(value.stats)
	var pivot = Vector2(float(fit.collar.center[0]),float(fit.collar.center[1])+2.0)
	var hinge = Transform2D(angle,Vector2.ZERO)
	hinge.origin = pivot-hinge.basis_xform(pivot)
	if pose.has("head_base_transform"):
		# Fall articulation is relative to the captured mounted head, not the
		# upright source sprite. Otherwise the first physics tick erases lean
		# and gaze stabilization and visibly snaps the helmet/neck junction.
		return hinge*Transform2D(pose.head_base_transform)
	if not pose.has("head_rotation"):
		# RIDER-064, mounted only: the head keeps ~30% of a deliberate lean out
		# of its orientation so the rider keeps looking at the opponent. It
		# turns about the model's head anchor (torso-local 0,-111), so the
		# visible helmet stays on the head hit target; the neck bridge stretches.
		var lean = float(value.get("lean",0.0))
		var lean_angle = lean*(deg_to_rad(25.0) if lean>=0.0 else deg_to_rad(45.0))
		# The neck absorbs the smooth mounted stride as well as deliberate lean.
		# Rotate about the SAME head target: gaze stabilizes without moving the
		# helmet off its collision centre or detaching its collar bridge.
		var gait_counter = -.65*clampf(gait_pitch,-.12,.20)
		var counter = Transform2D((-.30*lean_angle+gait_counter+float(value.get("reaction_neck",0.0)))*int(value.get("direction",1)),Vector2.ZERO)
		var slump = float(value.get("slump",0.0))
		counter = Transform2D(lerpf(counter.get_rotation(),.18*int(value.get("direction",1)),slump),Vector2.ZERO)
		var anchor = Vector2(0,-111)
		counter.origin = anchor-counter.basis_xform(anchor)
		hinge = counter*hinge
	return hinge

static func head_transform(pose: Dictionary, value: Dictionary, gait_pitch: float = 0.0) -> Transform2D:
	var torso: Transform2D = pose.torso_transform
	var fit = HeadFit.layout(value.stats)
	var local = Transform2D(Vector2(float(value.direction),0),Vector2.DOWN,Vector2(float(fit.head_offset),0))
	return torso*head_hinge(pose,value,gait_pitch)*local

static func shield_pose_transform(pose: Dictionary, value: Dictionary) -> Transform2D:
	# A detached shield is strapped to the articulated forearm. Mounted
	# poses retain their existing shared rule transform and control motor.
	if pose.has("shield_transform"):
		return pose.shield_transform
	var result: Transform2D = pose.torso_transform
	result.x *= int(value.direction)
	result = result*Transform2D(float(value.get("shield_twist",0.0)),Vector2.ZERO)
	result.origin = pose.shield_center
	return result

static func leg_patch_point113(point: Vector2, source_a: Vector2, source_b: Vector2, a: Vector2, b: Vector2, thickness: float) -> Vector2:
	var source_axis = (source_b-source_a).normalized()
	var source_side = Vector2(-source_axis.y,source_axis.x)
	var axis = (b-a).normalized()
	var side = Vector2(-axis.y,axis.x)
	var longitudinal = a.distance_to(b)/source_a.distance_to(source_b)
	var relative=point-source_a
	return a+axis*relative.dot(source_axis)*longitudinal+side*relative.dot(source_side)*thickness

static func boot_outline113(pose: Dictionary) -> PackedVector2Array:
	var points = PackedVector2Array()
	for point in BOOT_OUTLINE113:
		points.append(leg_patch_point113(point,Vector2(823,748),Vector2(804,862),pose.knee,pose.ankle,.29))
	return points

static func arm_elbow(shoulder: Vector2, hand: Vector2, upper: float, lower: float) -> Vector2:
	var ray = hand-shoulder
	var distance = clampf(ray.length(),absf(upper-lower)+.01,upper+lower-.01)
	var angle = acos(clampf((upper*upper+distance*distance-lower*lower)/(2*upper*distance),-1,1))
	var a = shoulder+ray.normalized().rotated(angle)*upper
	var b = shoulder+ray.normalized().rotated(-angle)*upper
	# Elbow hangs below the direct reach, on either facing and torso angle.
	return a if a.y>b.y else b

static func world_legs(value: Dictionary, seated: Dictionary) -> Dictionary:
	var origin=Vector2(float(value.x),float(value.get("lane_y",0.0)))
	var mirror=Vector2(int(value.direction),1)
	var result=seated.duplicate(true)
	for side in ["near","far"]:
		for key in ["hip","knee","ankle","foot","bar","stirrup"]:
			result[side][key]=origin+Vector2(seated[side][key])*mirror
	return result

static func capture_data(value: Dictionary, pose: Dictionary, legs: Dictionary, gait_pitch: float = 0.0) -> Dictionary:
	# Arms, legs and torso are ALL world-space. No renderer or mutable body
	# object is retained in this capture; callers explicitly set velocities.
	var facing=int(value.direction)
	var torso: Transform2D=pose.torso_transform
	var stats: Dictionary=value.stats
	var armor_kg=float(stats.get("armor_kg",12.0))
	var helmet_kg=float(stats.get("helmet_kg",2.4))
	var shield_kg=float(stats.get("shield_kg",3.0)) if float(value.get("shield",0.0))>0.0 else 1.0
	var upper=2.6+armor_kg*.06
	var fore=1.9+armor_kg*.04
	var thigh=9.5+armor_kg*.08
	var shin=4.6+armor_kg*.06
	var fit=HeadFit.layout(stats)
	var neck=torso*Vector2(float(fit.collar.center[0]),float(fit.collar.center[1])+2.0)
	var head_frame=head_transform(pose,value,gait_pitch)
	var helmet: Rect2=fit.helmet
	var corners=PackedVector2Array()
	for point in TORSO_OUTLINE: corners.append(torso*point)
	var head_corners=PackedVector2Array()
	for point in [helmet.position,Vector2(helmet.end.x,helmet.position.y),helmet.end,Vector2(helmet.position.x,helmet.end.y)]:
		head_corners.append(head_frame*point)
	# Open helmets do not cover the jaw. The same visible lower face must
	# contact the horse/ground instead of letting the chin pass through it.
	if bool(fit.open):
		var face:Rect2=fit.face
		var jaw_y=minf(face.end.y,Rect2(fit.face_clip).end.y)
		for fraction in [.30,.50,.70]:head_corners.append(head_frame*Vector2(lerpf(face.position.x,face.end.x,fraction),jaw_y))
	var boots={}
	for side in ["near","far"]:
		var outline=PackedVector2Array()
		for point in BOOT_OUTLINE113:
			outline.append(leg_patch_point113(point,Vector2(823,748),Vector2(804,862),legs[side].knee,legs[side].ankle,.29*facing))
		boots[side]=outline
	var shield=PackedVector2Array()
	var shield_frame=shield_pose_transform(pose,value)
	var polygon=Shield.polygon(str(stats.get("shield_shape","kite")),float(stats.get("shield_scale",1.0))) if float(value.get("shield",0.0))>0.0 else ShieldArt.remnant_polygon(stats)
	for point in polygon: shield.append(shield_frame*point)
	var points=PackedVector2Array([pose.left.elbow,pose.left.hand,pose.right.elbow,pose.right.hand,
		legs.near.knee,legs.near.ankle,legs.far.knee,legs.far.ankle,head_frame*helmet.get_center()])
	var velocities=PackedVector2Array()
	velocities.resize(points.size())
	velocities.fill(Vector2.ZERO)
	return {"facing":facing,"ground":float(value.get("lane_y",0.0))+7.0,
		"torso_mass":38.0+armor_kg*.55+upper+thigh,"com":torso*Vector2(0,-38),"com_velocity":Vector2.ZERO,"angular_velocity":0.0,
		"down":torso.basis_xform(Vector2.DOWN),"waist":torso*Vector2(0,-27),"pelvis_down":Vector2.DOWN,
		"corners":corners,"anchors":{"shoulder_l":pose.left.shoulder,"shoulder_r":pose.right.shoulder,
			"hip_n":legs.near.hip,"hip_f":legs.far.hip,"neck":neck},
		"points":points,"velocities":velocities,
		"masses":[upper*.5+fore*.5,fore*.5+shield_kg,upper*.5+fore*.5,fore*.5+1.0,
			thigh*.5+shin*.5,shin*.5+1.2,thigh*.5+shin*.5,shin*.5+1.2,5.5+helmet_kg],
		"radii":[9.0,9.0,9.0,9.0,8.0,0.0,8.0,0.0,0.0],
		"boot_n":boots.near,"boot_f":boots.far,"shield":shield,"head":head_corners,
		"shield_basis_x":shield_frame.x,"shield_basis_y":shield_frame.y,"shield_mass":shield_kg,
		"neck_limit":DETACHED_NECK_LIMIT113,"conscious":not bool(value.get("unconscious",false)) and not bool(value.get("dead",false))}

static func capture(value: Dictionary, pose: Dictionary, legs: Dictionary, gait_pitch: float) -> Dictionary:
	return {"origin":pose.torso_transform.origin,"pose":pose.duplicate(true),"legs":legs.duplicate(true),"stats":value.stats.duplicate(true),
		"head_base":head_hinge(pose,value,gait_pitch),"shield_frame":shield_pose_transform(pose,value),
		"data":capture_data(value,pose,legs,gait_pitch)}

static func body_pose(body, captured: Dictionary, targets: Dictionary = {}) -> Dictionary:
	var original: Dictionary=captured.pose
	var moved=Transform2D(body.theta,body.x)*Transform2D(0.0,-Vector2(captured.data.com))
	var torso: Transform2D=moved*Transform2D(original.torso_transform)
	var lower=Transform2D(body.pelvis_theta,body.pelvis_x)*Transform2D(0.0,-Vector2(body.pelvis_initial))
	var points: PackedVector2Array=body.display_points()
	var pose={"torso_transform":torso,"head_base_transform":captured.head_base,
		"head_rotation":clampf(body.neck_angle(),-body.neck_limit,body.neck_limit),
		"pelvis_deform":torso.affine_inverse()*lower*Transform2D(original.torso_transform)}
	for side in ["left","right"]:
		var elbow=body.ELBOW_L if side=="left" else body.ELBOW_R
		var hand=body.HAND_L if side=="left" else body.HAND_R
		pose[side]={"shoulder":body.anchor("shoulder_l" if side=="left" else "shoulder_r"),
			"elbow":points[elbow],"hand":points[hand],"projection":original[side].get("projection",1.0)}
	var turn=body.shield_theta115
	var shield=Transform2D(turn,Vector2.ZERO)*Transform2D(captured.shield_frame)
	shield.y*=body.shield_scale_across()
	shield.origin=points[body.HAND_L]-shield.basis_xform(Vector2(-10,4))
	pose.shield_transform=shield
	pose.shield_center=shield.origin
	pose.shield_grip=points[body.HAND_L]
	var legs={}
	for side in ["near","far"]:
		var old: Dictionary=captured.legs[side]
		var knee=points[body.KNEE_N if side=="near" else body.KNEE_F]
		var ankle=points[body.ANKLE_N if side=="near" else body.ANKLE_F]
		var angle=wrapf((ankle-knee).angle()-(Vector2(old.ankle)-Vector2(old.knee)).angle(),-PI,PI)
		var iron: Dictionary=targets.get("legs",captured.legs)[side]
		legs[side]={"hip":body.anchor("hip_n" if side=="near" else "hip_f"),"knee":knee,"ankle":ankle,
			"foot":ankle+(Vector2(old.foot)-Vector2(old.ankle)).rotated(angle),"bar":iron.bar,"stirrup":iron.stirrup}
	# Anatomical hit centres retain the original registration; decorative
	# helmet crests never enlarge the skull just because its sprite is taller.
	var head=torso*head_hinge(pose,{"stats":captured.stats,"direction":body.facing})*Vector2(0,-111)
	return {"pose":pose,"legs":legs,"points":points,"head":head,"body":torso*Vector2(0,-44),
		"pelvis_frame":lower*Transform2D(original.torso_transform),
		"flank":lower*Transform2D(original.torso_transform)*Vector2(-6*body.facing,-10),
		"rider_origin":torso.origin,"angle":torso.get_rotation()*body.facing,"hand":points[body.HAND_R],
		"shield_transform":shield,"shield_center":shield.origin,"shield_grip":points[body.HAND_L]}

static func interpolate115(a: Dictionary, b: Dictionary, weight: float, value: Dictionary) -> Dictionary:
	# Interpolate directions, not endpoint positions: bone lengths and grip
	# attachments remain exact between fixed game-time solver ticks.
	if a.is_empty() or weight>=.999999:return b
	if weight<=.000001:return a
	var result=b.duplicate(true)
	var pose:Dictionary=result.pose
	var ta:Transform2D=a.pose.torso_transform
	var tb:Transform2D=b.pose.torso_transform
	var torso=ta.interpolate_with(tb,weight)
	var pelvis=Transform2D(a.pelvis_frame).interpolate_with(b.pelvis_frame,weight)
	pose.torso_transform=torso
	pose.pelvis_deform=torso.affine_inverse()*pelvis
	pose.head_rotation=lerp_angle(float(a.pose.head_rotation),float(b.pose.head_rotation),weight)
	for side in ["left","right"]:
		var first:Dictionary=a.pose[side]
		var second:Dictionary=b.pose[side]
		var shoulder=torso*(ta.affine_inverse()*Vector2(first.shoulder))
		var upper=_interpolate_bone115(Vector2(first.elbow)-Vector2(first.shoulder),Vector2(second.elbow)-Vector2(second.shoulder),weight)
		var lower=_interpolate_bone115(Vector2(first.hand)-Vector2(first.elbow),Vector2(second.hand)-Vector2(second.elbow),weight)
		pose[side].shoulder=shoulder
		pose[side].elbow=shoulder+upper
		pose[side].hand=shoulder+upper+lower
	for side in ["near","far"]:
		var first:Dictionary=a.legs[side]
		var second:Dictionary=b.legs[side]
		var hip=pelvis*(Transform2D(a.pelvis_frame).affine_inverse()*Vector2(first.hip))
		var upper=_interpolate_bone115(Vector2(first.knee)-Vector2(first.hip),Vector2(second.knee)-Vector2(second.hip),weight)
		var lower=_interpolate_bone115(Vector2(first.ankle)-Vector2(first.knee),Vector2(second.ankle)-Vector2(second.knee),weight)
		result.legs[side].hip=hip
		result.legs[side].knee=hip+upper
		result.legs[side].ankle=hip+upper+lower
		result.legs[side].foot=hip+upper+lower+_interpolate_bone115(Vector2(first.foot)-Vector2(first.ankle),Vector2(second.foot)-Vector2(second.ankle),weight)
		for key in ["bar","stirrup"]:result.legs[side][key]=Vector2(first[key]).lerp(second[key],weight)
	var shield=Transform2D(a.shield_transform).interpolate_with(b.shield_transform,weight)
	shield.origin=Vector2(pose.left.hand)-shield.basis_xform(Vector2(-10,4))
	pose.shield_transform=shield;pose.shield_center=shield.origin;pose.shield_grip=pose.left.hand
	result.shield_transform=shield;result.shield_center=shield.origin;result.shield_grip=pose.left.hand
	result.rider_origin=torso.origin;result.angle=torso.get_rotation()*int(value.direction)
	result.hand=pose.right.hand;result.body=torso*Vector2(0,-44)
	result.head=torso*head_hinge(pose,value)*Vector2(0,-111)
	result.flank=pelvis*Vector2(-6*int(value.direction),-10)
	result.pelvis_frame=pelvis
	result.points=PackedVector2Array([pose.left.elbow,pose.left.hand,pose.right.elbow,pose.right.hand,
		result.legs.near.knee,result.legs.near.ankle,result.legs.far.knee,result.legs.far.ankle,
		head_transform(pose,value)*Rect2(HeadFit.layout(value.stats).helmet).get_center()])
	if a.has("lance_aim") and b.has("lance_aim"):result.lance_aim=lerp_angle(float(a.lance_aim),float(b.lance_aim),weight)
	return result

static func _interpolate_bone115(a: Vector2, b: Vector2, weight: float) -> Vector2:
	return Vector2.from_angle(lerp_angle(a.angle(),b.angle(),weight))*lerpf(a.length(),b.length(),weight)
