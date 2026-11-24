extends RefCounted
## PHYS-114: a whole articulated rider body for falls.
##
## The DEV-113 fall moved one root rigid body and let every limb swing only a
## few tenths of a radian around the CAPTURED SADDLE POSE. A body lying on its
## back therefore kept seated thighs pointing up and the riding arms held in
## front of the chest. Here the body is a real articulated mechanism:
##
## * the torso is one rigid body (the torso art is one plate) with mass,
##   inertia and four collision corners;
## * elbows, hands, knees, ankles and the head are mass points joined by
##   fixed-length bones to torso anchors (shoulders, hips, collar);
## * every joint has an ANATOMICAL range measured from its parent bone
##   (hip -26..123 deg, knee 0..149, shoulder -69..175, elbow 0..149, neck
##   limited by the existing head/neck art), not a band around the seat pose;
## * boots, the strapped shield and the helmet are rigid extensions of their
##   bones and collide with the floor; the trunk collides with a rounded
##   outline (narrow seat), shoulders and hips;
## * muscles pull joints toward a protective/relaxed target with a tone that
##   depends on consciousness; unconscious riders are fully limp.
##
## Position-based dynamics at 2 substeps per 1/120 s step (per-substep rates
## such as EXTENSION_PUSH, LIMB_DROP and KNEE_BUCKLE were tuned at 2): deterministic for
## identical inputs (no random source, fixed step), bone lengths exact.
## Visual only; no rule, score or damage reads it. 2D game approximation,
## not a medical or armour-safety model.

const GRAVITY = 900.0
const SUBSTEPS = 2
# A reflex can swing a limb fast, but not faster than a person can: the
# first uncapped muscle closed a 2 rad error at ~45 rad/s and flung arms.
const MUSCLE_MAX_SPEED = 7.0
# Above roughly a right angle; lower values propped a limp trunk upright in
# a long sit (phys114-body09).
const SOFT_LIMITS = {"hip":1.50,"knee":1.75,"elbow":2.10}
# Passive tissue yields under body weight (at 9/s it braced a limp body
# upright between two legs, phys114-body11).
const SOFT_RATE = 3.0
const FRICTION = .62
const SHIELD_FRICTION = .22
const SHIELD_ROLL_MAX = 1.25
const SHIELD_ROLL_RATE = 2.6
const PROP_GIVE = .9
const LANDING_THUD = .80
const EXTENSION_PUSH = 2.5
const LIMB_DROP = 4.5
const KNEE_BUCKLE = 14.0
const KNEE_BUCKLE_END = 3.0
const STOP_CREEP = .35
const STOP_CREEP_MAX = .50
const KNEEL_KNEE = 1.6
const KNEEL_GIVE = .8
const KNEEL_GIVE_MAX = 1.2
const AIR_DRAG = .12
const JOINT_DAMPING = 2.6
const MUSCLE_RATE = 55.0
const MAX_SPEED = 1500.0

enum {ELBOW_L, HAND_L, ELBOW_R, HAND_R, KNEE_N, ANKLE_N, KNEE_F, ANKLE_F, HEAD, COUNT}
const PARTICLE_NAMES = ["left_elbow","left_hand","right_elbow","right_hand","near_thigh","near_shin","far_thigh","far_shin","head"]

# Anatomical ranges in the rider's facing frame (radians). See _flex().
# Overhead reach includes the shoulder blade (about 186 deg); at 175 deg an arm
# thrown overhead was held off the floor by the stop with its shield raised.
const RANGES = {"shoulder":Vector2(-1.20,3.25),"elbow":Vector2(0.0,2.60),"hip":Vector2(-.45,2.15),"knee":Vector2(0.0,2.60)}

var facing = 1
var ground = 0.0
var age = 0.0
# Rigid torso.
var x = Vector2.ZERO
var x_prev = Vector2.ZERO
var v = Vector2.ZERO
var theta = 0.0
var theta_prev = 0.0
var omega = 0.0
var mass = 40.0
var inertia = 45000.0
var down0 = Vector2.DOWN
var corners = PackedVector2Array()
var anchors: Dictionary = {}
# Mass points.
var p = PackedVector2Array()
var prev = PackedVector2Array()
var vel = PackedVector2Array()
var inv_mass = PackedFloat32Array()
var radius = PackedFloat32Array()
var bones: Array = []
var joints: Array = []
var neck0 = 0.0
var neck_limit = .34
# Rigid extensions: [segment start, segment end, offset from end, angle0].
var extensions: Dictionary = {}
# Muscles.
var conscious = true
var tone = 0.0
var targets: Dictionary = {}
var brace_direction = Vector2(-.45,1.0)
var grounded_age = -1.0
# Contact bookkeeping (per completed step).
var contacts: Dictionary = {}
var core_contact = false
var torso_contact = false
var touching = PackedByteArray()
var shield_roll = 0.0
var thudded = false
var trunk_speed = 0.0
var trunk_turn = 0.0
var trunk_drift = Vector2.ZERO
var trunk_spin = 0.0
var last_x = Vector2.ZERO
var last_theta = 0.0
var has_last = false
var guide_angle = 0.0
var guide_strength = 0.0
var shield_axis0 = Vector2.RIGHT
var torso_reach = 0.0
# 0..1 extra energy loss once a body lies on the floor (armour, cloth and
# flesh absorb; the fall must come to rest rather than rock for seconds).
var rest = 0.0
# After the trunk has lain still for a while every part loses energy, so a
# loose limb finishes its last sway instead of creeping (fall057 head/-1).
var rest_all = false

static func wrap_angle(angle: float) -> float:
	return wrapf(angle,-PI,PI)

func af(vector: Vector2) -> float:
	# Angle in the facing frame, where the rider faces +x and y points down.
	return atan2(vector.y,vector.x*facing)

func anchor(name: String) -> Vector2:
	return x+Vector2(anchors[name]).rotated(theta)

func down_axis() -> Vector2:
	return down0.rotated(theta)

func end_position(end) -> Vector2:
	return anchor(end) if end is String else p[end]

## Build from world-space capture data. Every point must be in world space.
func build(data: Dictionary) -> void:
	facing = int(data.facing)
	ground = float(data.ground)
	mass = float(data.torso_mass)
	x = data.com
	x_prev = x
	v = data.com_velocity
	omega = float(data.angular_velocity)
	theta = 0.0
	theta_prev = 0.0
	down0 = Vector2(data.down).normalized()
	var size: Vector2 = data.get("torso_size",Vector2(76,88))
	inertia = mass*(size.x*size.x+size.y*size.y)/12.0
	corners = PackedVector2Array()
	for point in data.corners:
		corners.append(Vector2(point)-x)
	for name in data.anchors:
		anchors[name] = Vector2(data.anchors[name])-x
	p = PackedVector2Array(data.points)
	prev = p.duplicate()
	vel = PackedVector2Array(data.velocities)
	inv_mass = PackedFloat32Array()
	for m in data.masses:
		inv_mass.append(1.0/maxf(.1,float(m)))
	radius = PackedFloat32Array(data.radii)
	bones = [["shoulder_l",ELBOW_L],[ELBOW_L,HAND_L],["shoulder_r",ELBOW_R],[ELBOW_R,HAND_R],
		["hip_n",KNEE_N],[KNEE_N,ANKLE_N],["hip_f",KNEE_F],[KNEE_F,ANKLE_F],["neck",HEAD]]
	for bone in bones:
		bone.append(end_position(bone[0]).distance_to(p[bone[1]]))
	joints = [
		{"name":"left_upper","kind":"shoulder","pivot":"shoulder_l","child":ELBOW_L,"chain":[ELBOW_L,HAND_L]},
		{"name":"left_elbow","kind":"elbow","from":"shoulder_l","pivot":ELBOW_L,"child":HAND_L,"chain":[HAND_L]},
		{"name":"right_upper","kind":"shoulder","pivot":"shoulder_r","child":ELBOW_R,"chain":[ELBOW_R,HAND_R]},
		{"name":"right_elbow","kind":"elbow","from":"shoulder_r","pivot":ELBOW_R,"child":HAND_R,"chain":[HAND_R]},
		{"name":"near_hip","kind":"hip","pivot":"hip_n","child":KNEE_N,"chain":[KNEE_N,ANKLE_N]},
		{"name":"near_knee","kind":"knee","from":"hip_n","pivot":KNEE_N,"child":ANKLE_N,"chain":[ANKLE_N]},
		{"name":"far_hip","kind":"hip","pivot":"hip_f","child":KNEE_F,"chain":[KNEE_F,ANKLE_F]},
		{"name":"far_knee","kind":"knee","from":"hip_f","pivot":KNEE_F,"child":ANKLE_F,"chain":[ANKLE_F]}]
	for joint in joints:
		var captured = _flex(joint)
		var limits: Vector2 = RANGES[joint.kind]
		# A captured riding pose slightly outside the textbook range is kept
		# reachable; the body must not snap on its first step.
		joint.lo = minf(limits.x,captured-.02)
		joint.hi = maxf(limits.y,captured+.02)
		joint.base_lo = joint.lo
		joint.base_hi = joint.hi
		joint.captured = captured
	neck0 = (p[HEAD]-anchor("neck")).angle()
	neck_limit = float(data.get("neck_limit",.34))
	for key in ["boot_n","boot_f","shield","head"]:
		if not data.has(key): continue
		var segment: Array = {"boot_n":[KNEE_N,ANKLE_N],"boot_f":[KNEE_F,ANKLE_F],"shield":[ELBOW_L,HAND_L],"head":["neck",HEAD]}[key]
		var start = end_position(segment[0])
		var finish: Vector2 = p[segment[1]]
		var offsets = PackedVector2Array()
		var reach = 0.0
		for point in data[key]:
			offsets.append(Vector2(point)-finish)
			reach = maxf(reach,(Vector2(point)-finish).length())
		extensions[key] = {"a":segment[0],"b":segment[1],"offsets":offsets,"angle0":(finish-start).angle(),"reach":reach,"roll":key=="shield",
			"basis_x":data.get("shield_basis_x",Vector2.RIGHT),"basis_y":data.get("shield_basis_y",Vector2.DOWN)}
	torso_reach = 0.0
	for point in corners: torso_reach = maxf(torso_reach,point.length())
	for name in anchors: torso_reach = maxf(torso_reach,Vector2(anchors[name]).length()+9.0)
	conscious = bool(data.get("conscious",true))
	brace_direction = data.get("brace_direction",brace_direction)

## Flexion of a joint in the facing frame. Positive = anatomical flexion.
func _flex(joint: Dictionary) -> float:
	match str(joint.kind):
		"shoulder","hip":
			return wrap_angle(af(down_axis())-af(p[joint.child]-anchor(joint.pivot)))
		"elbow":
			return wrap_angle(af(p[joint.pivot]-anchor(joint["from"]))-af(p[joint.child]-p[joint.pivot]))
		_:
			return wrap_angle(af(p[joint.child]-p[joint.pivot])-af(p[joint.pivot]-anchor(joint["from"])))

func flex(name: String) -> float:
	for joint in joints:
		if joint.name==name: return _flex(joint)
	return 0.0

func captured(name: String) -> float:
	for joint in joints:
		if joint.name==name: return float(joint.captured)
	return 0.0

func neck_angle() -> float:
	return wrap_angle((p[HEAD]-anchor("neck")).angle()-theta-neck0)

static func _in_range(value: float, lo: float) -> float:
	# Unwrap into [lo, lo+TAU) so a range never routes through its gap.
	return lo+fposmod(value-lo,TAU)

func range_flex(joint: Dictionary) -> float:
	# Flexion on the same turn as the joint range (a shoulder range is wider
	# than pi, so a wrapped value can read 2 pi away from its true place).
	return _in_range(_flex(joint),float(joint.lo))

func target_flex(joint: Dictionary) -> float:
	# Muscle target on the same turn as the range; a target in the gap goes to
	# the nearer stop. A plain clamp of a wrapped target sent a shoulder target
	# of -2.4 to the far stop (-1.2) instead of its equal 3.9 near hi 3.25.
	var lo = float(joint.lo)
	var hi = float(joint.hi)
	var target = _in_range(float(targets[joint.name]),lo)
	if target>hi: target = hi if target-hi<=lo+TAU-target else lo
	return target

func _world_turn(joint: Dictionary, flex_change: float) -> float:
	# World rotation of the CHILD bone that changes flexion by flex_change.
	return flex_change*facing*(1.0 if joint.kind=="knee" else -1.0)

func _rotate_chain(chain: Array, pivot: Vector2, angle: float) -> void:
	for index in chain:
		p[index] = pivot+(p[index]-pivot).rotated(angle)

func _chain_inertia(chain: Array, pivot: Vector2) -> float:
	var total = 0.0
	for index in chain:
		total += (p[index]-pivot).length_squared()/inv_mass[index]
	return maxf(total,1.0)

func _turn_joint(joint: Dictionary, flex_change: float, stop: bool = false) -> void:
	# Internal torque: child and parent turn in opposite senses in proportion
	# to their inertia about the joint, so muscles and stops do not invent
	# angular momentum for the body as a whole.
	# Stops share the correction by inertia too: a stop that turned only the
	# limb let a spinning trunk drag its limbs round for free and pumped
	# energy into the body (phys114-body06).
	var turn = _world_turn(joint,flex_change)
	if joint.pivot is String:
		var pivot = anchor(joint.pivot)
		var share = inertia/(inertia+_chain_inertia(joint.chain,pivot))
		_rotate_chain(joint.chain,pivot,turn*share)
		theta -= turn*(1.0-share)
	else:
		var shoulder = anchor(joint["from"])
		var elbow: Vector2 = p[joint.pivot]
		var upper_inertia = (elbow-shoulder).length_squared()/inv_mass[joint.pivot]
		var lower_inertia = _chain_inertia(joint.chain,elbow)
		var share = upper_inertia/(upper_inertia+lower_inertia)
		var lower = p[joint.child]-elbow
		var moved = shoulder+(elbow-shoulder).rotated(-turn*(1.0-share))
		p[joint.pivot] = moved
		p[joint.child] = moved+lower.rotated(turn*share)

func _solve_joint(joint: Dictionary, h: float) -> void:
	var value = _in_range(_flex(joint),float(joint.lo))
	if value>float(joint.hi):
		# Outside the anatomical range: return to the nearer stop.
		var to_hi = value-float(joint.hi)
		var to_lo = float(joint.lo)+TAU-value
		_turn_joint(joint,-to_hi if to_hi<=to_lo else to_lo,true)
		return
	# Passive tissue: hamstrings and the hip capsule resist deep flexion even
	# in a limp body, so flipped legs fall back instead of resting folded
	# over the chest (no force inside the comfortable range).
	if SOFT_LIMITS.has(joint.kind) and value>float(SOFT_LIMITS[joint.kind]) and value<=float(joint.hi):
		_turn_joint(joint,(float(SOFT_LIMITS[joint.kind])-value)*SOFT_RATE*h)
		value = _in_range(_flex(joint),float(joint.lo))
	if tone<=0.0 or not targets.has(joint.name): return
	var target = target_flex(joint)
	var strength = float(targets.get(joint.name+"_tone",1.0))*tone
	var cap = MUSCLE_MAX_SPEED*h
	_turn_joint(joint,clampf((target-value)*(1.0-exp(-MUSCLE_RATE*strength*h)),-cap,cap))

func _solve_neck(h: float) -> void:
	var neck = anchor("neck")
	var angle = neck_angle()
	var change = 0.0
	if absf(angle)>neck_limit:
		change = signf(angle)*neck_limit-angle
	elif tone>0.0 and targets.has("neck"):
		var cap = MUSCLE_MAX_SPEED*h
		change = clampf((clampf(float(targets.neck),-neck_limit,neck_limit)-angle)*(1.0-exp(-MUSCLE_RATE*tone*h)),-cap,cap)
	if change==0.0: return
	var head_inertia = (p[HEAD]-neck).length_squared()/inv_mass[HEAD]
	var share = inertia/(inertia+head_inertia)
	p[HEAD] = neck+(p[HEAD]-neck).rotated(change*share)
	theta -= change*(1.0-share)

func _rigid_weight(r: Vector2, n: Vector2) -> float:
	var arm = r.cross(n)
	return 1.0/mass+arm*arm/inertia

func _rigid_push(r: Vector2, impulse: Vector2) -> void:
	x += impulse/mass
	theta += r.cross(impulse)/inertia

func _solve_bone(bone: Array) -> void:
	var a = bone[0]
	var b: int = bone[1]
	var start = end_position(a)
	var delta = p[b]-start
	var length = delta.length()
	if length<.0001: return
	var n = delta/length
	var error = length-float(bone[2])
	var wb = inv_mass[b]
	if a is String:
		var r = start-x
		var wa = _rigid_weight(r,n)
		var s = error/(wa+wb)
		p[b] -= n*s*wb
		_rigid_push(r,n*s)
	else:
		var wa = inv_mass[a]
		var s = error/(wa+wb)
		p[b] -= n*s*wb
		p[a] += n*s*wa

func _record(part: String) -> void:
	if not contacts.has(part): contacts[part] = age

func system_centre() -> Vector2:
	var total = mass
	var sum = x*mass
	for i in range(COUNT):
		var m = 1.0/inv_mass[i]
		sum += p[i]*m
		total += m
	return sum/total

func _total_inertia(centre: Vector2) -> float:
	var total = inertia+mass*(x-centre).length_squared()
	for i in range(COUNT):
		total += (p[i]-centre).length_squared()/inv_mass[i]
	return maxf(total,1.0)

func _rotate_all(centre: Vector2, angle: float, quasi_static: bool = false) -> void:
	# quasi_static also turns the previous positions, so the turn is a slow
	# repositioning that adds no momentum (a buckling prop must not leave the
	# body rolling on: phys114-articulation14 tumbled over twice).
	x = centre+(x-centre).rotated(angle)
	theta += angle
	if quasi_static:
		x_prev = centre+(x_prev-centre).rotated(angle)
		theta_prev += angle
	for i in range(COUNT):
		p[i] = centre+(p[i]-centre).rotated(angle)
		if quasi_static: prev[i] = centre+(prev[i]-centre).rotated(angle)

func _restore_spin(centre: Vector2, before_points: PackedVector2Array, before_x: Vector2, before_theta: float) -> void:
	# Net angular displacement (angular momentum x step) the internal pass
	# added about the body's centre; turn the whole body back by it.
	var turned = inertia*(theta-before_theta)+mass*(x-centre).cross(x-before_x)
	for i in range(COUNT):
		turned += (p[i]-centre).cross(p[i]-before_points[i])/inv_mass[i]
	_rotate_all(centre,-turned/_total_inertia(centre))

func _shift_positions(offset: Vector2) -> void:
	# Moves current positions only: within a substep this cancels a spurious
	# displacement instead of preserving it as velocity.
	x += offset
	for i in range(COUNT):
		p[i] = p[i]+offset

func translate(offset: Vector2) -> void:
	# Positional correction of the whole body without changing any velocity.
	x += offset
	x_prev += offset
	for i in range(COUNT):
		p[i] = p[i]+offset
		prev[i] = prev[i]+offset

func _solve_torso_contacts() -> void:
	if x.y+torso_reach<ground: return
	for index in range(corners.size()+4):
		# Trunk outline, then shoulders (sleeve radius 9) and hips (8).
		var lift = 0.0
		var local: Vector2
		if index<corners.size():
			local = corners[index]
		else:
			var name = ["shoulder_l","shoulder_r","hip_n","hip_f"][index-corners.size()]
			local = anchors[name]
			lift = 9.0 if name.begins_with("shoulder") else 8.0
		var r = local.rotated(theta)
		var point = x+r+Vector2(0,lift)
		var depth = point.y-ground
		if depth<=0.0: continue
		var before = x_prev+local.rotated(theta_prev)+Vector2(0,lift)
		var n = Vector2.UP
		var normal = depth/_rigid_weight(r,n)
		_rigid_push(r,n*normal)
		var w_t = _rigid_weight(r,Vector2.RIGHT)
		var tangent = clampf(-(point.x-before.x)/w_t,-FRICTION*normal,FRICTION*normal)
		_rigid_push(r,Vector2(tangent,0))
		if index<corners.size():
			core_contact = true
			torso_contact = true
			_record("chest" if local.y<-40.0 else "pelvis")
		else:
			_record(["left_shoulder","right_shoulder","near_thigh","far_thigh"][index-corners.size()])

func _point_contact(index: int, lift: float, part: String) -> void:
	# Packed arrays return copies; always write a whole element back.
	var q: Vector2 = p[index]
	var depth = q.y+lift-ground
	if depth<=0.0: return
	q.y -= depth
	q.x -= clampf(q.x-prev[index].x,-FRICTION*depth,FRICTION*depth)
	p[index] = q
	touching[index] = 1
	_record(part)

func _extension_point(data: Dictionary, previous: bool, offset: Vector2) -> Vector2:
	var start = end_position(data.a)
	var finish: Vector2 = p[data.b]
	if previous:
		start = (x_prev+Vector2(anchors[data.a]).rotated(theta_prev)) if data.a is String else prev[data.a]
		finish = prev[data.b]
	if data.get("roll",false) and shield_roll>0.0:
		# Rolling flat about the forearm shortens the face along the shield's
		# own long (y) axis; its x axis keeps following the forearm exactly.
		var bx: Vector2 = data.basis_x
		var by: Vector2 = data.basis_y
		var det = bx.cross(by)
		if absf(det)>.0001:
			var a = offset.cross(by)/det
			var b = bx.cross(offset)/det
			offset = bx*a+by*b*cos(shield_roll)
	return finish+offset.rotated((finish-start).angle()-float(data.angle0))

func _extension_contact(key: String, part: String) -> void:
	if not extensions.has(key): return
	var data: Dictionary = extensions[key]
	var finish: Vector2 = p[data.b]
	if finish.y+float(data.reach)<ground: return
	var start = end_position(data.a)
	var deepest = 0.0
	var point = Vector2.ZERO
	var chosen = Vector2.ZERO
	for offset in data.offsets:
		var q = _extension_point(data,false,offset)
		if q.y-ground>deepest:
			deepest = q.y-ground
			point = q
			chosen = offset
	if deepest<=0.0: return
	# A long lever (shield rim, helmet edge) turned its whole limb by up to
	# 0.5 rad in one step on first contact (shield105). Resolve a deep entry
	# over a few substeps instead; the drawn outline is kept on the floor by
	# FallenRider's final positional correction.
	deepest = minf(deepest,EXTENSION_PUSH)
	_record(part)
	touching[data.b] = 1
	if data.a is int: touching[data.a] = 1
	# Friction acts on the actual contact point's travel this substep.
	var travel = point.x-_extension_point(data,true,chosen).x
	if data.a is String:
		# Head: the collar is rigid with the torso; the skull takes the push,
		# the neck bone hands the rest to the torso on the next projection.
		var head: Vector2 = p[data.b]
		head.y -= deepest
		head.x -= clampf(travel,-FRICTION*deepest,FRICTION*deepest)
		p[data.b] = head
		core_contact = true
		return
	var a: int = data.a
	var b: int = data.b
	var axis = finish-start
	var t = clampf((point-start).dot(axis)/maxf(axis.length_squared(),.0001),-.3,1.6)
	var wa = inv_mass[a]*(1.0-t)
	var wb = inv_mass[b]*t
	var denominator = (1.0-t)*wa+t*wb
	if absf(denominator)<.00001: return
	var s = deepest/denominator
	# A wooden/iron shield rim slides on sand; with full grip a strapped
	# shield stood on its edge and propped the forearm upright (articulation01).
	var grip = SHIELD_FRICTION if key=="shield" else FRICTION
	var slip = clampf(travel,-grip*deepest,grip*deepest)/denominator
	p[a] -= Vector2(wa*slip,wa*s)
	p[b] -= Vector2(wb*slip,wb*s)

func angular_momentum(centre: Vector2) -> float:
	var total = inertia*omega+mass*(x-centre).cross(v)
	for i in range(COUNT):
		total += (p[i]-centre).cross(vel[i])/inv_mass[i]
	return total

func _landing_thud() -> void:
	# The first time the trunk meets the floor, armour, padding and flesh
	# deform and take out most of the body's tumble: an inelastic impact.
	# Without it a rider landing on his back at ~110 degrees kept rolling
	# heels over head onto his helmet (phys114-articulation09).
	thudded = true
	var centre = system_centre()
	var correction = -LANDING_THUD*angular_momentum(centre)/_total_inertia(centre)
	omega += correction
	v += Vector2(-(x-centre).y,(x-centre).x)*correction
	for i in range(COUNT):
		vel[i] = vel[i]+Vector2(-(p[i]-centre).y,(p[i]-centre).x)*correction

func _shield_rolls(h: float) -> void:
	# The shield is strapped ACROSS the forearm, so with the forearm on the
	# floor its face stood upright beside the body like a raised guard
	# (phys114-articulation05/06). A real shield then rolls about the forearm
	# and falls flat; that turn is out of this plane, so it is kept as a roll
	# angle: the face is foreshortened across the forearm (drawing and floor
	# outline alike) and can no longer prop the arm up. It never rolls back.
	# Once the rider lies on the floor a limp arm no longer holds its shield up
	# edge-on, so it also rolls flat after a moment without rim contact (a far
	# arm folded against its stops held a raised shield, articulation08).
	if shield_roll>=SHIELD_ROLL_MAX: return
	if contacts.has("shield") or (grounded_age>.5 and tone<.08):
		shield_roll = minf(SHIELD_ROLL_MAX,shield_roll+SHIELD_ROLL_RATE*h)

func shield_scale_across() -> float:
	return cos(shield_roll)

func _limbs_drop(h: float) -> void:
	# A limp leg or arm balanced pointing up (knee above hip, hand above
	# shoulder) would fall sideways out of this plane in reality. In 2D it is
	# an inverted pendulum that can stand for seconds (articulation19), so it
	# is lowered toward the floor slowly and without adding momentum.
	if tone>0.0 or grounded_age<.6: return
	for joint in joints:
		# Hips/shoulders (thigh, upper arm) and knees/elbows (shin, forearm):
		# a folded knee left its shin and boot standing up (articulation20).
		var pivot = end_position(joint.pivot)
		var child: int = joint.child
		var rise = pivot.y-p[child].y
		if rise<12.0: continue
		var arm = p[child]-pivot
		var step = LIMB_DROP*h
		# Turn the way that lowers the joint.
		var turn = step if arm.rotated(step).y>arm.rotated(-step).y else -step
		# Never past a stop: the stop would push it back with velocity and the
		# limb would buzz at the stop instead of resting (code review 2026-11-24).
		var after = range_flex(joint)+turn*facing*(1.0 if joint.kind=="knee" else -1.0)
		if after<float(joint.lo) or after>float(joint.hi): continue
		for index in joint.chain:
			p[index] = pivot+(p[index]-pivot).rotated(turn)
			prev[index] = pivot+(prev[index]-pivot).rotated(turn)

func _knees_buckle(h: float) -> void:
	# A limp body landed upright on spread, straight legs stood braced between
	# the stops (balance-topple fixtures, phys114-body13). With no tone the
	# knees fold under the weight until the trunk is low enough to go over.
	# Only while the body can still go over; a knee held by the floor short of
	# its stop must not keep pushing for ever (it would never come to rest).
	if tone>0.0 or grounded_age<.4 or grounded_age>KNEE_BUCKLE_END: return
	var down = down_axis()
	if absf(down.y)<.6: return
	# A body with a knee already down is kneeling, not standing braced:
	# folding the other knee levered the trunk upright and walked the body
	# 85 px along the floor (phys114-trace08/10).
	if touching[KNEE_N] or touching[KNEE_F]: return
	# As a torque (velocity), not a repositioning: with the boot planted a
	# moved ankle was simply pushed back by the floor, and the hips must sink.
	# Shin and thigh have different masses, so equal spins alone left a net
	# push on the whole body; _conserve removes it (code review 2026-11-24).
	var centre = system_centre()
	var momentum_before = linear_momentum()
	var spin_before = angular_momentum(centre)
	for joint in joints:
		if joint.kind!="knee": continue
		var value = _in_range(_flex(joint),float(joint.lo))
		if value>=float(joint.hi)-.3: continue
		var spin = _world_turn(joint,KNEE_BUCKLE*h)
		var knee: Vector2 = p[joint.pivot]
		var hip = anchor(joint["from"])
		var ankle: Vector2 = p[joint.child]
		# Equal and opposite on shin and thigh (internal). Rotation velocity is
		# (-r.y, r.x)*w; Vector2.orthogonal() is the opposite sense and first
		# straightened the knees instead (phys114-probe02).
		var shin = ankle-knee
		var thigh = knee-hip
		vel[joint.child] = vel[joint.child]+Vector2(-shin.y,shin.x)*spin
		vel[joint.pivot] = vel[joint.pivot]-Vector2(-thigh.y,thigh.x)*spin
	_conserve(centre,momentum_before,spin_before)

func _to_flat() -> float:
	# Turn that lays the trunk flat on the nearer side. Near upright the side
	# is the guide's (back/side landing), so the guide and a giving prop agree;
	# opposite targets held a kneeling rider upright between them for seconds
	# (phys114-trace07).
	var down = down_axis()
	var a = wrap_angle(-down.angle())
	var b = wrap_angle(PI-down.angle())
	var nearer = a if absf(a)<=absf(b) else b
	if absf(down.x)<.35 and guide_strength>0.0:
		var want = signf(wrap_angle(guide_angle-theta))
		if signf(nearer)!=want: return b if nearer==a else a
	return nearer

func _props_give_way(h: float) -> void:
	# A relaxed body cannot stay sitting up on a locked arm or a knee: once the
	# reflex has let go and the trunk rests still but upright, it tips over
	# about its floor contact toward lying (the props buckle).
	# Also a body propped on knees and hands with the trunk off the floor
	# (forward flank falls stayed kneeling, phys114-articulation15).
	# Still = measured trunk motion, not the derived velocity (trace06).
	var propped = grounded_age>.6 and trunk_speed<60.0
	if tone>.08 or grounded_age<.25 or not (core_contact or propped): return
	var down = down_axis()
	var to_flat = _to_flat()
	# A trunk resting on the floor lies within ~11 degrees of flat; 31 degrees
	# let a body propped on knees count as lying (articulation16).
	if absf(to_flat)<.30: return
	# Only in the first two seconds on the floor: afterwards a trunk held off
	# flat by the floor itself must not keep turning the body against its
	# limbs (it fought the limb drop and stalled, phys114-trace05). Extending
	# it to 4 s for kneeling riders only folded them onto the hip stop and let
	# them spring back up afterwards (phys114-trace11).
	if grounded_age>2.0: return
	# Balanced on helmet and shoulders with the legs up (down axis pointing up)
	# is the least stable of all: it goes over fastest.
	var inverted = smoothstep(0.0,.8,-down.y)
	# Tip about what actually rests on the floor (a knee, a boot or the trunk);
	# turning about a trunk corner in the air only fought the kneeling leg.
	var pivot = x
	var lowest = -INF
	for local in corners:
		var point = x+Vector2(local).rotated(theta)
		if point.y>lowest:
			lowest = point.y
			pivot = point
	for i in range(COUNT):
		if p[i].y+radius[i]>lowest:
			lowest = p[i].y+radius[i]
			pivot = p[i]
	var rate = PROP_GIVE*(1.0+2.5*inverted)
	# Still turning by itself (beyond this rule's own slow give): let it fall.
	if trunk_turn>rate+.8: return
	_rotate_all(pivot,clampf(to_flat,-rate*h,rate*h),true)

func linear_momentum() -> Vector2:
	var total = v*mass
	for i in range(COUNT):
		total += vel[i]/inv_mass[i]
	return total

func total_mass() -> float:
	var total = mass
	for i in range(COUNT):
		total += 1.0/inv_mass[i]
	return total

func _conserve(centre: Vector2, momentum_before: Vector2, spin_before: float) -> void:
	# Internal velocity changes (tissue damping, buckling knees) must move
	# neither the centre of mass nor the spin of the whole body. A uniform
	# velocity shift leaves the spin about the centre unchanged, and a rigid
	# turn about the centre leaves the momentum unchanged, so the two
	# corrections are independent.
	var shift = (momentum_before-linear_momentum())/total_mass()
	v += shift
	for i in range(COUNT):
		vel[i] = vel[i]+shift
	var correction = (spin_before-angular_momentum(centre))/_total_inertia(centre)
	omega += correction
	v += Vector2(-(x-centre).y,(x-centre).x)*correction
	for i in range(COUNT):
		vel[i] = vel[i]+Vector2(-(p[i]-centre).y,(p[i]-centre).x)*correction

func _damp_joints(h: float) -> void:
	# Tissue damping is internal: it must not change the body's spin, nor in
	# the air its momentum (a damped limb only handed spin to its parent, so a
	# swinging arm shifted the trajectory, code review 2026-11-24). On the
	# floor the limb's reaction goes into its contact instead: spreading it
	# over the whole body slid lying riders along the ground and left three
	# falls unsettled at 7 s (phys114-exp9).
	var centre = system_centre()
	var momentum_before = linear_momentum()
	var spin_before = angular_momentum(centre)
	_damp_joint_velocities(h)
	if grounded_age>=0.0: momentum_before = linear_momentum()
	_conserve(centre,momentum_before,spin_before)

func _damp_joint_velocities(h: float) -> void:
	# Passive tissue: damp each bone's spin relative to its parent.
	var keep = exp(-JOINT_DAMPING*h)
	var torso_spin = omega
	for joint in joints:
		var pivot = end_position(joint.pivot)
		var pivot_velocity = v+Vector2(-(pivot-x).y,(pivot-x).x)*omega if joint.pivot is String else vel[joint.pivot]
		var parent_spin = torso_spin
		if not joint.pivot is String:
			var shoulder = anchor(joint["from"])
			var arm = pivot-shoulder
			var shoulder_velocity = v+Vector2(-(shoulder-x).y,(shoulder-x).x)*omega
			parent_spin = arm.cross(vel[joint.pivot]-shoulder_velocity)/maxf(arm.length_squared(),1.0)
		var child: int = joint.child
		var r = p[child]-pivot
		var spin = r.cross(vel[child]-pivot_velocity)/maxf(r.length_squared(),1.0)
		var relative = (spin-parent_spin)*(1.0-keep)
		var child_inertia = _chain_inertia(joint.chain,pivot)
		# Equal and opposite: tissue damping slows the limb relative to its
		# parent and hands that angular momentum to the parent.
		var parent_inertia = inertia
		if not joint.pivot is String:
			parent_inertia = (pivot-anchor(joint["from"])).length_squared()/inv_mass[joint.pivot]
		var child_share = parent_inertia/(parent_inertia+child_inertia)
		for index in joint.chain:
			var arm = p[index]-pivot
			vel[index] = vel[index]-Vector2(-arm.y,arm.x)*relative*child_share
		var parent_change = relative*(1.0-child_share)
		if joint.pivot is String:
			omega += parent_change
		else:
			var upper = pivot-anchor(joint["from"])
			vel[joint.pivot] = vel[joint.pivot]+Vector2(-upper.y,upper.x)*parent_change

func set_muscles(value_tone: float, value_targets: Dictionary) -> void:
	tone = value_tone
	targets = value_targets

func step(dt: float) -> void:
	var h = dt/SUBSTEPS
	contacts.clear()
	core_contact = false
	torso_contact = false
	touching.resize(COUNT)
	touching.fill(0)
	# From the end of the previous step, so a lift applied by the caller between
	# steps (fallen_rider keeps the drawn body out of the floor) counts too.
	var step_x = last_x if has_last else x
	var step_theta = last_theta if has_last else theta
	for substep in range(SUBSTEPS):
		age += h
		# Predict.
		x_prev = x
		theta_prev = theta
		v.y += GRAVITY*h
		if guide_strength>0.0 and (grounded_age<0.0 or (grounded_age<2.5 and absf(down_axis().y)>.5)):
			# DEV-113's weak airborne orientation bias (3, 1.1): the trunk heads
			# for a back/side landing instead of head first or seated. While the
			# trunk is still upright it lasts up to 1.5 s after landing: a rider
			# landing on his feet or seat otherwise stayed standing or sitting.
			# On the floor it heads for the nearer flat side instead of the
			# airborne target, which could lie across upright (trace07).
			var error = wrap_angle(guide_angle-theta) if grounded_age<0.0 else _to_flat()
			omega += (guide_strength*3.0*error-guide_strength*1.1*omega)*h
		x += v*h
		theta += omega*h
		for i in range(COUNT):
			prev[i] = p[i]
			vel[i] = vel[i]+Vector2(0,GRAVITY*h)
			p[i] = p[i]+vel[i]*h
		# Project: bones, joint stops and muscles, then contacts last so the
		# floor always wins over a muscle or a stretched bone.
		for bone in bones: _solve_bone(bone)
		# Joint stops and muscles are INTERNAL: they may bend the body but must
		# not move its centre of mass, or a kicking limb would let the rider
		# swim through the air (the first PHYS-114 run flew bodies away).
		var centre = system_centre()
		var before_points = p.duplicate()
		var before_x = x
		var before_theta = theta
		for joint in joints: _solve_joint(joint,h)
		_solve_neck(h)
		_shift_positions(centre-system_centre())
		# ...nor its angular momentum: the per-joint inertia split is taken about
		# the joint, not the body's centre, and alone let the arm reflex spin a
		# rider through 150 degrees in 0.15 s (phys114-trace01). Undo exactly
		# the net turn the internal step gave the whole body.
		_restore_spin(centre,before_points,before_x,before_theta)
		for bone in bones: _solve_bone(bone)
		_solve_torso_contacts()
		for i in [ELBOW_L,HAND_L,ELBOW_R,HAND_R,KNEE_N,KNEE_F]:
			_point_contact(i,radius[i],PARTICLE_NAMES[i])
		_extension_contact("boot_n","near_shin")
		_extension_contact("boot_f","far_shin")
		_extension_contact("shield","shield")
		_shield_rolls(h)
		_extension_contact("head","head")
		_props_give_way(h)
		_limbs_drop(h)
		# Derive velocities.
		var drag = 1.0-AIR_DRAG*h
		v = ((x-x_prev)/h*drag).limit_length(MAX_SPEED)
		omega = clampf(wrap_angle(theta-theta_prev)/h*drag,-14.0,14.0)
		for i in range(COUNT):
			vel[i] = ((p[i]-prev[i])/h*drag).limit_length(MAX_SPEED)
		# A torque acts on velocities, so after they are derived from positions
		# (applied before, it was overwritten and never acted: body14-16).
		_knees_buckle(h)
	_damp_joints(dt)
	# Only while the trunk is still held off the floor; once it lies, creeping
	# stops would only keep the body slowly moving (fall057 flank/1).
	if tone<=0.0 and grounded_age>1.0 and not torso_contact:
		# Limp joints loaded against a stop creep a little (capsule and
		# ligaments), so a body cannot stay braced kneeling on a leg held at
		# its hip-extension stop (phys114-trace04). Bounded to 0.5 rad.
		for joint in joints:
			# Flexion side only: a creeping hip-extension stop let a seated
			# rider with straight legs slide into the splits (phys114-edge01).
			if joint.kind in ["hip","knee"]:
				joint.hi = minf(float(joint.hi)+STOP_CREEP*dt,float(joint.base_hi)+STOP_CREEP_MAX)
	if tone<=0.0 and grounded_age>1.0:
		# Over a folded knee the hip extension gives way too: a limp rider
		# kneeling upright on his heels sinks back over his legs instead of
		# staying knelt (phys114-games05 shield fall). It keeps giving while
		# that knee still points up, so the thigh can drop once the back is
		# down (otherwise the knees stood up in the air, phys114-body24).
		var knee_flex = {}
		for joint in joints:
			if joint.kind=="knee": knee_flex[str(joint.name).replace("knee","hip")] = range_flex(joint)
		for joint in joints:
			if joint.kind!="hip" or float(knee_flex.get(joint.name,0.0))<=KNEEL_KNEE: continue
			if torso_contact and end_position(joint.pivot).y-p[joint.child].y<12.0: continue
			joint.lo = maxf(float(joint.lo)-KNEEL_GIVE*dt,float(joint.base_lo)-KNEEL_GIVE_MAX)
	# Trunk or helmet: riders often land on head and shoulders first.
	if core_contact and not thudded:
		_landing_thud()
	if rest>0.0:
		# Only the trunk and parts lying on the floor lose energy this way; a
		# limb still dropping must finish its fall (a global damping froze a
		# shield arm in the air, phys114-articulation02).
		var keep = exp(-8.0*rest*dt)
		v *= keep
		omega *= keep
		for i in range(COUNT):
			if touching[i] or rest_all: vel[i] = vel[i]*keep
	if grounded_age<0.0 and not contacts.is_empty(): grounded_age = 0.0
	elif grounded_age>=0.0: grounded_age += dt
	# Measured trunk motion (smoothed over ~0.15 s). The derived velocity of a
	# trunk braced on a leg carries 40-90 px/s of solver residue while it does
	# not move at all, which kept the props rule from ever acting
	# (phys114-trace06).
	# Signed averages: a still trunk jitters by a fraction of a pixel each step,
	# which an averaged speed read as 45 px/s of motion (phys114-trace08).
	var blend = 1.0-exp(-dt/.15)
	trunk_drift = trunk_drift.lerp((x-step_x)/dt,blend)
	trunk_spin = lerpf(trunk_spin,wrap_angle(theta-step_theta)/dt,blend)
	trunk_speed = trunk_drift.length()
	trunk_turn = absf(trunk_spin)
	last_x = x
	last_theta = theta
	has_last = true

func display_points() -> PackedVector2Array:
	# The drawn skeleton: solver directions, but EXACT bone lengths and joint
	# ranges, so a sub-pixel contact residual is never shown as a stretched
	# bone or an over-bent knee. Physics state itself is untouched.
	var solved = p
	p = p.duplicate()
	for bone in bones:
		var start = end_position(bone[0])
		var direction = p[bone[1]]-start
		if direction.length_squared()>.000001:
			var moved = start+direction.normalized()*float(bone[2])
			var shift = moved-p[bone[1]]
			p[bone[1]] = moved
			# Carry the rest of the chain with its parent joint.
			for other in bones:
				if other[0] is int and int(other[0])==bone[1]: p[other[1]] = p[other[1]]+shift
	for joint in joints:
		var value = _in_range(_flex(joint),float(joint.lo))
		if value>float(joint.hi):
			var to_hi = value-float(joint.hi)
			var to_lo = float(joint.lo)+TAU-value
			_rotate_chain(joint.chain,end_position(joint.pivot),_world_turn(joint,-to_hi if to_hi<=to_lo else to_lo))
	var angle = neck_angle()
	if absf(angle)>neck_limit:
		var neck = anchor("neck")
		p[HEAD] = neck+(p[HEAD]-neck).rotated(signf(angle)*neck_limit-angle)
	var result = p
	p = solved
	return result

func motion() -> float:
	# Largest speed of any part, including the rim of the spinning torso.
	var fastest = v.length()+absf(omega)*60.0
	for i in range(COUNT):
		fastest = maxf(fastest,vel[i].length())
	return fastest

func point_velocity(index: int) -> Vector2:
	return vel[index]

func segment_spin(a, b: int) -> float:
	var start = end_position(a)
	var start_velocity = v+Vector2(-(start-x).y,(start-x).x)*omega if a is String else vel[a]
	var r = p[b]-start
	return r.cross(vel[b]-start_velocity)/maxf(r.length_squared(),1.0)
