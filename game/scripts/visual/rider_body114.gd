extends RefCounted
## PHYS-114 body extended by PHYS-115 to riding and loss of saddle support.
## Chest and pelvis are rigid bodies joined at the waist; nine mass points
## form head/arm/leg chains. Finite muscles, passive coupled tissue, joint
## limits and unilateral contacts govern motion. The strapped shield has
## its own angular inertia. Boots and helmet rotate with their bone chains.
##
## Fixed 120 game-Hz; two riding or four free-body PBD substeps. Rendering and hit anchors read
## this same body. Drawing restores exact captured bone lengths without
## replacing the underlying state. Contact/strain-rate projection is a
## numerical approximation, not fully energy-conserving XPBD or a medical
## model. Production riding bodies disable the legacy airborne guide; there
## is no random pose, imposed final posture or timed freeze in that path.

const GRAVITY = 900.0
const SUBSTEPS = 2
# A reflex can swing a limb fast, but not faster than a person can: the
# first uncapped muscle closed a 2 rad error at ~45 rad/s and flung arms.
const MUSCLE_MAX_SPEED = 7.0
const FRICTION = .25
const SHIELD_FRICTION = .22
const SHIELD_ROLL_MAX = 1.25
const SHIELD_ROLL_RATE = 2.6
const LANDING_THUD = .80
const EXTENSION_PUSH = 2.5
const AIR_DRAG = .12
const JOINT_DAMPING = 2.6
const MUSCLE_RATE = 55.0
const MAX_SPEED = 1500.0
# Passive angular resistance bounds strain rate; applied to physical joints,
# not only to a smoothed rendering pose. Units: radians per game second.
const JOINT_RATE115 = {"shoulder":5.5,"elbow":5.5,"hip":5.0,"knee":6.0}
const SPINE_RANGE115 = Vector2(-.55,.90)
const SPINE_RATE115 = 3.5

# Immutable joint registration is compiled once. Public dictionaries remain
# available to geometry/QA readers; the hot solver avoids string-key lookup
# in every one of its contact iterations.
class Bone115:
	var rooted: bool
	var pelvic: bool
	var a: int
	var b: int
	var local: Vector2
	var length: float

class Joint115:
	var name: String
	var kind: String
	var child: int
	var parent: int
	var rooted: bool
	var pelvic: bool
	var local: Vector2
	var lo: float
	var hi: float
	var maximum_rate: float
	var active_target115: bool
	var target115: float
	var strength115: float

enum {ELBOW_L, HAND_L, ELBOW_R, HAND_R, KNEE_N, ANKLE_N, KNEE_F, ANKLE_F, HEAD, COUNT}
const HINGE_AXES115 = [Vector2.RIGHT,Vector2.DOWN]
const FLOOR_PARTICLES115 = [ELBOW_L,HAND_L,ELBOW_R,HAND_R,KNEE_N,KNEE_F]
const SHOULDER_ANCHORS115 = ["shoulder_l","shoulder_r"]
const SHOULDER_PARTS115 = ["left_shoulder","right_shoulder"]
const PARTICLE_NAMES = ["left_elbow","left_hand","right_elbow","right_hand","near_thigh","near_shin","far_thigh","far_shin","head"]

# Anatomical ranges in the rider's facing frame (radians). See _flex().
# Overhead reach includes the shoulder blade (about 186 deg); at 175 deg an arm
# thrown overhead was held off the floor by the stop with its shield raised.
const RANGES = {"shoulder":Vector2(-1.20,3.25),"elbow":Vector2(0.0,2.60),"hip":Vector2(-.45,2.15),"knee":Vector2(0.0,2.60)}

var facing: int = 1
var ground: float = 0.0
var age: float = 0.0
# Rigid torso.
var x: Vector2 = Vector2.ZERO
var x_prev: Vector2 = Vector2.ZERO
var v: Vector2 = Vector2.ZERO
var theta: float = 0.0
var theta_prev: float = 0.0
var omega: float = 0.0
var mass: float = 40.0
var inertia: float = 45000.0
var down0: Vector2 = Vector2.DOWN
var corners: PackedVector2Array = PackedVector2Array()
var anchors: Dictionary = {}
# A separate pelvis shares a waist hinge with the chest. A rigid chest/hip
# block could balance a limp body on folded knees through its hip stop.
var pelvis_x: Vector2 = Vector2.ZERO
var pelvis_prev: Vector2 = Vector2.ZERO
var pelvis_v: Vector2 = Vector2.ZERO
var pelvis_theta: float = 0.0
var pelvis_theta_prev: float = 0.0
var pelvis_omega: float = 0.0
var pelvis_mass: float = 18.0
var pelvis_inertia: float = 4500.0
var pelvis_down0: Vector2 = Vector2.DOWN
var pelvis_anchors: Dictionary = {}
var pelvis_corners: PackedVector2Array = PackedVector2Array()
var pelvis_initial: Vector2 = Vector2.ZERO
var waist_chest: Vector2 = Vector2.ZERO
var waist_pelvis: Vector2 = Vector2.ZERO
var spine_range: Vector2 = SPINE_RANGE115
var spine_captured: float = 0.0
# Mass points.
var p: PackedVector2Array = PackedVector2Array()
var prev: PackedVector2Array = PackedVector2Array()
var vel: PackedVector2Array = PackedVector2Array()
var inv_mass: PackedFloat32Array = PackedFloat32Array()
var radius: PackedFloat32Array = PackedFloat32Array()
var bones: Array = []
var fast_bones115: Array[Bone115] = []
var joints: Array = []
var fast_joints115: Array[Joint115] = []
var posterior_pairs115: Array = []
var neck0: float = 0.0
var neck_limit: float = .34
# Rigid extensions: [segment start, segment end, offset from end, angle0].
var extensions: Dictionary = {}
# Muscles.
var conscious: bool = true
var tone: float = 0.0
var targets: Dictionary = {}
var brace_direction: Vector2 = Vector2(-.45,1.0)
var grounded_age: float = -1.0
# Contact bookkeeping (per completed step).
var contacts: Dictionary = {}
var core_contact: bool = false
var torso_contact: bool = false
var chest_contact115: bool = false
var pelvis_contact115: bool = false
var touching: PackedByteArray = PackedByteArray()
var shield_roll: float = 0.0
# The shield has rotational inertia about its hand strap. In 2.5D the
# projected forearm can turn while the forearm/wrist adjusts the shield face.
# Locking the face rigidly to the projected forearm inverted a low guard.
var shield_theta115: float = 0.0
var shield_previous115: float = 0.0
var shield_strap_previous115: float = 0.0
var shield_omega115: float = 0.0
var shield_inertia115: float = 3000.0
var shield_mass115: float = 3.0
var shield_centre115: Vector2 = Vector2.ZERO
var thudded: bool = false
var trunk_speed: float = 0.0
var trunk_turn: float = 0.0
var trunk_drift: Vector2 = Vector2.ZERO
var trunk_spin: float = 0.0
var last_x: Vector2 = Vector2.ZERO
var last_theta: float = 0.0
var has_last: bool = false
var guide_angle: float = 0.0
var guide_strength: float = 0.0
var shield_axis0: Vector2 = Vector2.RIGHT
var torso_reach: float = 0.0
# 0..1 extra energy loss once a body lies on the floor (armour, cloth and
# flesh absorb; the fall must come to rest rather than rock for seconds).
var rest: float = 0.0
# Legacy diagnostic field, retained for old snapshots. Floor dissipation
# now affects only the actual contacting body/limb, never every loose part.
var rest_all: bool = false
# Floor contact couples the waist, two legs and the strapped shield. Five
# sweeps left enough residual to prop the trunk on a straight arm or make a
# resting pelvis creep sideways. Forward/backward sweeps carry endpoint
# contacts back to the trunk; ten resolves these chains without changing
# the two-sweep mounted/airborne budget.
var contact_iterations115: int = 10
# Optional riding contacts. Values only: the solver never retains its owner.
var support_contacts115: Dictionary = {}
# Also bounds compatibility captures and standalone bodies. An empty map
# made their reflex motors effectively infinite while mounted bodies had
# finite muscle torque, producing different landings from the same anatomy.
var motor_torque115: Dictionary = {"shoulder":1800000.0,"elbow":1500000.0,"hip":3500000.0,"knee":2400000.0,"spine":8000000.0,"neck":450000.0}
var motor_step115: float = 0.0

static func wrap_angle(angle: float) -> float:
	return wrapf(angle,-PI,PI)

func af(vector: Vector2) -> float:
	# Angle in the facing frame, where the rider faces +x and y points down.
	return atan2(vector.y,vector.x*facing)

func anchor(name: String) -> Vector2:
	if pelvis_anchors.has(name):
		return pelvis_x+Vector2(pelvis_anchors[name]).rotated(pelvis_theta)
	return x+Vector2(anchors[name]).rotated(theta)

func anchor_previous(name: String) -> Vector2:
	if pelvis_anchors.has(name):
		return pelvis_prev+Vector2(pelvis_anchors[name]).rotated(pelvis_theta_prev)
	return x_prev+Vector2(anchors[name]).rotated(theta_prev)

func anchor_velocity(name: String) -> Vector2:
	var r: Vector2 =anchor(name)-(pelvis_x if pelvis_anchors.has(name) else x)
	return (pelvis_v if pelvis_anchors.has(name) else v)+Vector2(-r.y,r.x)*(pelvis_omega if pelvis_anchors.has(name) else omega)

func hip_down_axis() -> Vector2:
	return pelvis_down0.rotated(pelvis_theta)

func spine_flex() -> float:
	return facing*wrapf(down0.rotated(theta).angle()-pelvis_down0.rotated(pelvis_theta).angle(),-PI,PI)

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
	pelvis_x=(Vector2(data.anchors.hip_n)+Vector2(data.anchors.hip_f))*.5
	pelvis_initial=pelvis_x
	pelvis_prev=pelvis_x
	pelvis_theta=0.0
	pelvis_theta_prev=0.0
	pelvis_mass=float(data.get("pelvis_mass",18.0))
	mass=maxf(20.0,mass-pelvis_mass)
	inertia=mass*(size.x*size.x+size.y*size.y*.60)/12.0
	pelvis_inertia=pelvis_mass*(42.0*42.0+32.0*32.0)/12.0
	pelvis_down0=Vector2(data.get("pelvis_down",Vector2.DOWN)).normalized()
	pelvis_omega=omega
	var pelvis_arm: Vector2 =pelvis_x-x
	pelvis_v=v+Vector2(-pelvis_arm.y,pelvis_arm.x)*omega
	for name in ["hip_n","hip_f"]:
		pelvis_anchors[name]=Vector2(data.anchors[name])-pelvis_x
	var waist: Vector2 =Vector2(data.get("waist",pelvis_x-down0*25.0))
	waist_chest=waist-x
	waist_pelvis=waist-pelvis_x
	spine_captured=spine_flex()
	spine_range=Vector2(minf(SPINE_RANGE115.x,spine_captured-.02),maxf(SPINE_RANGE115.y,spine_captured+.02))
	# The source's lower outline belongs to the pelvis, not the chest plate.
	var upper_corners: PackedVector2Array =PackedVector2Array()
	for corner in corners:
		var world: Vector2 =x+corner
		if (world-waist).dot(down0)>0.0:
			pelvis_corners.append(world-pelvis_x)
		else:
			upper_corners.append(corner)
	corners=upper_corners
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
		var captured: float = _flex(joint)
		var limits: Vector2 = RANGES[joint.kind]
		# A captured riding pose slightly outside the textbook range is kept
		# reachable; the body must not snap on its first step.
		joint.lo = minf(limits.x,captured-.02)
		joint.hi = maxf(limits.y,captured+.02)
		joint.base_lo = joint.lo
		joint.base_hi = joint.hi
		joint.captured = captured
	compile_joints115()
	neck0 = (p[HEAD]-anchor("neck")).angle()
	neck_limit = float(data.get("neck_limit",.34))
	for key in ["boot_n","boot_f","shield","head"]:
		if not data.has(key): continue
		var segment: Array = {"boot_n":[KNEE_N,ANKLE_N],"boot_f":[KNEE_F,ANKLE_F],"shield":[ELBOW_L,HAND_L],"head":["neck",HEAD]}[key]
		var start: Vector2 = end_position(segment[0])
		var finish: Vector2 = p[segment[1]]
		var offsets: PackedVector2Array = PackedVector2Array()
		var reach: float = 0.0
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
	configure_shield115(float(data.get("shield_mass",3.0)))

func compile_joints115() -> void:
	fast_bones115.clear()
	for source in bones:
		var bone=Bone115.new()
		bone.rooted=source[0] is String
		bone.a=-1 if bone.rooted else int(source[0]);bone.b=int(source[1])
		bone.length=float(source[2])
		if bone.rooted:
			bone.pelvic=pelvis_anchors.has(source[0])
			bone.local=pelvis_anchors[source[0]] if bone.pelvic else anchors[source[0]]
		fast_bones115.append(bone)
	fast_joints115.clear()
	for source in joints:
		var joint=Joint115.new()
		joint.name=source.name; joint.kind=source.kind; joint.child=int(source.child)
		joint.rooted=source.pivot is String
		joint.parent=-1 if joint.rooted else int(source.pivot)
		joint.pelvic=joint.kind in ["hip","knee"]
		var anchor_name: String=source.pivot if joint.rooted else source["from"]
		joint.local=pelvis_anchors[anchor_name] if joint.pelvic else anchors[anchor_name]
		joint.lo=float(source.lo);joint.hi=float(source.hi)
		joint.maximum_rate=float(JOINT_RATE115[joint.kind])
		fast_joints115.append(joint)
	posterior_pairs115=[[fast_joints115[4],fast_joints115[5]],[fast_joints115[6],fast_joints115[7]]]

func configure_shield115(value_mass: float) -> void:
	shield_mass115=maxf(.2,value_mass)
	shield_centre115=Vector2.ZERO
	var radius_squared: float =0.0
	if extensions.has("shield"):
		var outline:PackedVector2Array=extensions.shield.offsets
		for point in outline:
			shield_centre115+=point
			radius_squared+=point.length_squared()
		if not outline.is_empty():
			shield_centre115/=outline.size()
			radius_squared/=outline.size()
	# Area inertia is smaller than the boundary's mean squared distance.
	shield_inertia115=maxf(150.0,shield_mass115*radius_squared*.55)

## Flexion of a joint in the facing frame. Positive = anatomical flexion.
func _flex(joint: Dictionary) -> float:
	match str(joint.kind):
		"shoulder","hip":
			return wrap_angle(af(hip_down_axis() if joint.kind=="hip" else down_axis())-af(p[joint.child]-anchor(joint.pivot)))
		"elbow":
			return wrap_angle(af(p[joint.pivot]-anchor(joint["from"]))-af(p[joint.child]-p[joint.pivot]))
		_:
			return wrap_angle(af(p[joint.child]-p[joint.pivot])-af(p[joint.pivot]-anchor(joint["from"])))

func _joint_anchor115(joint: Joint115) -> Vector2:
	return pelvis_x+joint.local.rotated(pelvis_theta) if joint.pelvic else x+joint.local.rotated(theta)

func _fast_flex115(joint: Joint115) -> float:
	# Same atan2/subtraction/wrap arithmetic as af()/wrap_angle(), inlined
	# inside the solver to avoid hundreds of interpreted calls per body tick.
	var base:Vector2=pelvis_x+joint.local.rotated(pelvis_theta) if joint.pelvic else x+joint.local.rotated(theta)
	var upper:Vector2
	var lower:Vector2
	if joint.rooted:
		upper=pelvis_down0.rotated(pelvis_theta) if joint.pelvic else down0.rotated(theta)
		lower=p[joint.child]-base
	else:
		upper=p[joint.parent]-base
		lower=p[joint.child]-p[joint.parent]
	var upper_angle:float=atan2(upper.y,upper.x*facing)
	var lower_angle:float=atan2(lower.y,lower.x*facing)
	return wrapf(lower_angle-upper_angle if joint.kind=="knee" else upper_angle-lower_angle,-PI,PI)

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
	var lo: float = float(joint.lo)
	var hi: float = float(joint.hi)
	var target: float = _in_range(float(targets[joint.name]),lo)
	if target>hi: target = hi if target-hi<=lo+TAU-target else lo
	return target

func _fast_target115(joint: Joint115) -> float:
	# Muscle target on the same turn as the range; a target in the gap goes to
	# the nearer stop. A plain clamp of a wrapped target sent a shoulder target
	# of -2.4 to the far stop (-1.2) instead of its equal 3.9 near hi 3.25.
	var lo: float = float(joint.lo)
	var hi: float = float(joint.hi)
	var target: float = _in_range(float(targets[joint.name]),lo)
	if target>hi: target = hi if target-hi<=lo+TAU-target else lo
	return target


func _world_turn(joint: Dictionary, flex_change: float) -> float:
	# World rotation of the CHILD bone that changes flexion by flex_change.
	return flex_change*facing*(1.0 if joint.kind=="knee" else -1.0)

func _rotate_chain(chain: Array, pivot: Vector2, angle: float) -> void:
	for index in chain:
		p[index] = pivot+(p[index]-pivot).rotated(angle)

func _project_angle115(joint: Joint115, change: float, damping_keep: float = -1.0, limit: float = INF) -> void:
	# Angle-constraint Jacobians distribute the correction to every incident
	# mass and the trunk anchor. The former rotate-chain heuristic moved the
	# parent about a different pivot, then globally counter-rotated the body;
	# contact corrections therefore became large opposite limb velocities.
	# Internal gradient impulses have zero net force and net torque (to the
	# solver's first-order position accuracy), without whole-body after-fixes.
	if change == 0.0 and damping_keep < 0.0: return
	var child: int = joint.child
	var root_gradient: Vector2 = Vector2.ZERO
	var parent_gradient: Vector2 = Vector2.ZERO
	var child_gradient: Vector2 = Vector2.ZERO
	var theta_gradient: float = 0.0
	var parent: int = -1
	var pelvic: bool = joint.kind == "hip" or joint.kind == "knee"
	var root_x: Vector2 = pelvis_x if pelvic else x
	var root_mass: float = pelvis_mass if pelvic else mass
	var root_inertia: float = pelvis_inertia if pelvic else inertia
	if joint.rooted:
		var pivot: Vector2 = pelvis_x+joint.local.rotated(pelvis_theta) if joint.pelvic else x+joint.local.rotated(theta)
		var arm: Vector2 = p[child]-pivot
		child_gradient = -facing*Vector2(-arm.y,arm.x)/maxf(arm.length_squared(),.001)
		root_gradient = -child_gradient
		var r: Vector2 = pivot-root_x
		theta_gradient = facing+root_gradient.dot(Vector2(-r.y,r.x))
	else:
		parent = joint.parent
		var pivot: Vector2 = pelvis_x+joint.local.rotated(pelvis_theta) if joint.pelvic else x+joint.local.rotated(theta)
		var upper: Vector2 = p[parent]-pivot
		var lower: Vector2 = p[child]-p[parent]
		var sense: float = float(facing)*(1.0 if joint.kind=="elbow" else -1.0)
		root_gradient = -sense*Vector2(-upper.y,upper.x)/maxf(upper.length_squared(),.001)
		child_gradient = -sense*Vector2(-lower.y,lower.x)/maxf(lower.length_squared(),.001)
		parent_gradient = -root_gradient-child_gradient
		var r: Vector2 = pivot-root_x
		theta_gradient = root_gradient.dot(Vector2(-r.y,r.x))
	var weight: float = root_gradient.length_squared()/root_mass+theta_gradient*theta_gradient/root_inertia+child_gradient.length_squared()*inv_mass[child]
	if parent>=0: weight+=parent_gradient.length_squared()*inv_mass[parent]
	if weight<.000000001: return
	var impulse: float = clampf(change/weight,-limit,limit)
	if damping_keep>=0.0:
		var rate: float = root_gradient.dot(pelvis_v if pelvic else v)+theta_gradient*(pelvis_omega if pelvic else omega)+child_gradient.dot(vel[child])
		if parent>=0: rate+=parent_gradient.dot(vel[parent])
		impulse = -rate*(1.0-damping_keep)/weight
		if pelvic:
			pelvis_v+=root_gradient*impulse/pelvis_mass
			pelvis_omega+=theta_gradient*impulse/pelvis_inertia
		else:
			v+=root_gradient*impulse/mass
			omega+=theta_gradient*impulse/inertia
		vel[child] = vel[child]+child_gradient*impulse*inv_mass[child]
		if parent>=0: vel[parent]=vel[parent]+parent_gradient*impulse*inv_mass[parent]
	else:
		if pelvic:
			pelvis_x+=root_gradient*impulse/pelvis_mass
			pelvis_theta+=theta_gradient*impulse/pelvis_inertia
		else:
			x+=root_gradient*impulse/mass
			theta+=theta_gradient*impulse/inertia
		p[child] = p[child]+child_gradient*impulse*inv_mass[child]
		if parent>=0: p[parent]=p[parent]+parent_gradient*impulse*inv_mass[parent]

func _turn_joint(joint: Joint115, flex_change: float, _stop: bool = false) -> void:
	_project_angle115(joint,flex_change)

func _solve_joint(joint: Joint115, h: float) -> void:
	var value: float = _in_range(_fast_flex115(joint),float(joint.lo))
	if value>float(joint.hi):
		# Outside the anatomical range: return to the nearer stop.
		var to_hi: float = value-float(joint.hi)
		var to_lo: float = float(joint.lo)+TAU-value
		_turn_joint(joint,-to_hi if to_hi<=to_lo else to_lo,true)
		value=float(joint.hi) if to_hi<=to_lo else float(joint.lo)
	# Passive tissue compression near deep hip/knee flexion. A perfectly
	# free hinge followed by an infinitely hard end-stop can lock a folded leg
	# above the body. This bounded elastic torque releases stored compression;
	# it is not the former straightening motor acting through the whole range.
	var soft_end: float =1.75 if joint.kind=="hip" else 2.10 if joint.kind=="knee" else INF
	if value>soft_end:
		var stiffness: float =8000000.0 if joint.kind=="hip" else 800000.0
		var torque: float =minf(1800000.0 if joint.kind=="hip" else 400000.0,stiffness*pow(value-soft_end,2))
		_project_angle115(joint,soft_end-value,-1.0,torque*motor_step115*h)
	# Passive terminal extension resistance in the elbow/knee capsule. A
	# perfectly straight, freely hinged limb with an infinitely hard stop
	# acts as a rigid prop under compression; a relaxed joint yields slightly.
	var soft_start:float=.12 if joint.kind=="elbow" else .08 if joint.kind=="knee" else -INF
	if value<soft_start:
		var torque:float=minf(1200000.0,80000000.0*pow(soft_start-value,2))
		_project_angle115(joint,soft_start-value,-1.0,torque*motor_step115*h)
	if joint.kind=="shoulder" and value<-.90:
		var torque:float=minf(1200000.0,18000000.0*pow(-.90-value,2))
		_project_angle115(joint,-.90-value,-1.0,torque*motor_step115*h)
	# Limp limbs have damping and anatomical end stops, not a straightening
	# motor. The old broad 'soft range' extended a knee under body weight,
	# lifting an unconscious chest back up after it had reached the floor.
	if not joint.active_target115:return
	var target: float = joint.target115
	var strength: float = joint.strength115
	var cap: float = MUSCLE_MAX_SPEED*h
	var limit: float =float(motor_torque115.get(joint.kind,INF))*motor_step115*h*strength
	_project_angle115(joint,clampf((target-value)*(1.0-exp(-MUSCLE_RATE*strength*h)),-cap,cap),-1.0,limit)

func _joint_rates115(previous: PackedFloat32Array, h: float) -> void:
	for index in range(fast_joints115.size()):
		var joint: Joint115 = fast_joints115[index]
		var change: float =wrap_angle(_fast_flex115(joint)-previous[index])
		var maximum: float =joint.maximum_rate*h
		if absf(change)>maximum:
			_project_angle115(joint,clampf(change,-maximum,maximum)-change)

func _posterior_tissue115(h: float) -> void:
	# A hip and knee do not have independent passive ranges: the posterior
	# two-joint tissue becomes taut with a deeply flexed hip AND straight knee.
	# Independent hard stops allowed a limp rider to balance in an inverted
	# pike, both feet hanging over the head forever. Finite coupled tension
	# extends the hip and flexes the knee; it never rotates the whole body or
	# chooses a world-space final pose. Angles/torques are game-scale estimates.
	for pair in posterior_pairs115:
		var hip: Joint115 = pair[0]
		var knee: Joint115 = pair[1]
		var strain: float =maxf(0.0,_fast_flex115(hip)-.70*_fast_flex115(knee)-1.45)
		if strain<=0.0:continue
		var tension: float =minf(2000000.0,8000000.0*strain*strain)
		_project_angle115(hip,-strain,-1.0,tension*motor_step115*h)
		_project_angle115(knee,strain*.70,-1.0,tension*.70*motor_step115*h)

func _anterior_tissue115(h: float) -> void:
	# The anterior thigh crosses the hip and knee as well. Deep knee flexion
	# together with an extended hip cannot sit at two unrelated hard stops.
	for pair in posterior_pairs115:
		var hip: Joint115 = pair[0]
		var knee: Joint115 = pair[1]
		var strain: float=maxf(0.0,_fast_flex115(knee)-.70*_fast_flex115(hip)-2.15)
		if strain<=0.0:continue
		var tension: float=minf(1800000.0,8000000.0*strain*strain)
		_project_angle115(knee,-strain,-1.0,tension*motor_step115*h)
		_project_angle115(hip,strain*.70,-1.0,tension*.70*motor_step115*h)

func _shield_joint115(h: float) -> void:
	if not extensions.has("shield"):return
	var bone: Vector2 = p[HAND_L]-p[ELBOW_L]
	var turn: float =wrapf(bone.angle()-float(extensions.shield.angle0),-PI,PI)
	var relative: float =wrapf(shield_theta115-turn,-PI,PI)
	var wanted: float =clampf(relative,-1.95,1.95)
	var hard_limit: bool =not is_equal_approx(wanted,relative)
	if hard_limit or (tone>0.0 and targets.has("shield_relative")):
		if not hard_limit:wanted=clampf(float(targets.shield_relative),-1.95,1.95)
		var change: float =wrapf(wanted-relative,-PI,PI)
		if not hard_limit:change=clampf(change*(1.0-exp(-38.0*tone*h)),-5.5*h,5.5*h)
		_project_shield115(change,INF if hard_limit else 600000.0*tone*motor_step115*h)
	# The strap/wrist has finite strain rate even when muscles are limp.
	# A velocity clamp alone cannot limit a contact's positional correction.
	# Share this reaction with the forearm instead of rotating only the art.
	turn=(p[HAND_L]-p[ELBOW_L]).angle()-float(extensions.shield.angle0)
	var change: float =wrapf(shield_theta115-turn-shield_strap_previous115,-PI,PI)
	var maximum: float =5.5*motor_step115
	if absf(change)>maximum:_project_shield115(clampf(change,-maximum,maximum)-change)

func _project_shield115(change: float, limit: float = INF) -> void:
	if change==0.0:return
	var bone:Vector2=p[HAND_L]-p[ELBOW_L]
	var gradient: Vector2 =Vector2(-bone.y,bone.x)/maxf(bone.length_squared(),.001)
	var weight: float =1.0/shield_inertia115+gradient.length_squared()*(inv_mass[HAND_L]+inv_mass[ELBOW_L])
	var impulse: float =clampf(change/weight,-limit,limit)
	shield_theta115+=impulse/shield_inertia115
	p[HAND_L]=p[HAND_L]-gradient*impulse*inv_mass[HAND_L]
	p[ELBOW_L]=p[ELBOW_L]+gradient*impulse*inv_mass[ELBOW_L]

func _solve_neck(h: float) -> void:
	var neck: Vector2 = anchor("neck")
	var angle: float = neck_angle()
	var change: float = 0.0
	var hard_limit: bool =absf(angle)>neck_limit
	if absf(angle)>neck_limit:
		change = signf(angle)*neck_limit-angle
	elif tone>0.0 and targets.has("neck"):
		var cap: float = MUSCLE_MAX_SPEED*h
		change = clampf((clampf(float(targets.neck),-neck_limit,neck_limit)-angle)*(1.0-exp(-MUSCLE_RATE*tone*h)),-cap,cap)
	if change==0.0: return
	var arm: Vector2 = p[HEAD]-neck
	var g: Vector2 = Vector2(-arm.y,arm.x)/maxf(arm.length_squared(),.001)
	var root_gradient: Vector2 = -g
	var r: Vector2 = neck-x
	var theta_gradient: float = -1.0+root_gradient.dot(Vector2(-r.y,r.x))
	var weight: float = root_gradient.length_squared()/mass+theta_gradient*theta_gradient/inertia+g.length_squared()*inv_mass[HEAD]
	var impulse: float = change/maxf(weight,.000000001)
	if not hard_limit:
		var limit: float =float(motor_torque115.get("neck",450000.0))*tone*motor_step115*h
		impulse=clampf(impulse,-limit,limit)
	x += root_gradient*impulse/mass
	theta += theta_gradient*impulse/inertia
	p[HEAD] = p[HEAD]+g*impulse*inv_mass[HEAD]

func _root_impulse115(pelvic: bool, linear: Vector2, angular: float, impulse: float, velocity: bool) -> void:
	if pelvic:
		if velocity:
			pelvis_v+=linear*impulse/pelvis_mass
			pelvis_omega+=angular*impulse/pelvis_inertia
		else:
			pelvis_x+=linear*impulse/pelvis_mass
			pelvis_theta+=angular*impulse/pelvis_inertia
	else:
		if velocity:
			v+=linear*impulse/mass
			omega+=angular*impulse/inertia
		else:
			x+=linear*impulse/mass
			theta+=angular*impulse/inertia

func _anchor_weight115(name: String, axis: Vector2) -> float:
	var pelvic: bool =pelvis_anchors.has(name)
	var r: Vector2 =anchor(name)-(pelvis_x if pelvic else x)
	return 1.0/(pelvis_mass if pelvic else mass)+pow(r.cross(axis),2)/(pelvis_inertia if pelvic else inertia)

func _anchor_push115(name: String, impulse: Vector2) -> void:
	var pelvic: bool =pelvis_anchors.has(name)
	var r: Vector2 =anchor(name)-(pelvis_x if pelvic else x)
	_root_impulse115(pelvic,impulse,r.cross(impulse),1.0,false)

func _waist_hinge115() -> void:
	for axis in HINGE_AXES115:
		var chest_r: Vector2 = waist_chest.rotated(theta)
		var hip_r: Vector2 = waist_pelvis.rotated(pelvis_theta)
		var error: float =(pelvis_x+hip_r-x-chest_r).dot(axis)
		var wa: float =1.0/mass+pow(chest_r.cross(axis),2)/inertia
		var wb: float =1.0/pelvis_mass+pow(hip_r.cross(axis),2)/pelvis_inertia
		var impulse: Vector2 = axis*(-error/(wa+wb))
		x+=-impulse/mass
		theta+=chest_r.cross(-impulse)/inertia
		pelvis_x+=impulse*1.0/pelvis_mass
		pelvis_theta+=hip_r.cross(impulse)*1.0/pelvis_inertia

func _spine_angle115(change: float, limit: float = INF) -> void:
	if change == 0.0: return
	var impulse: float =clampf(change/(1.0/inertia+1.0/pelvis_inertia),-limit,limit)
	theta+=facing*impulse/inertia
	pelvis_theta-=facing*impulse/pelvis_inertia

func _spine_constraint115(h: float, previous: float, motor_h: float) -> void:
	var flexion: float =spine_flex()
	var target: float =clampf(flexion,spine_range.x,spine_range.y)
	if not is_equal_approx(target,flexion):
		_spine_angle115(target-flexion)
	elif tone>0.0 and targets.has("spine"):
		var wanted: float =clampf(float(targets.spine),spine_range.x,spine_range.y)
		var strength: float =tone*float(targets.get("spine_tone",1.0))
		_spine_angle115(clampf((wanted-flexion)*(1.0-exp(-MUSCLE_RATE*strength*motor_h)),-SPINE_RATE115*motor_h,SPINE_RATE115*motor_h),float(motor_torque115.get("spine",INF))*h*motor_h*strength)
	var compressed: float =maxf(0.0,spine_flex()-.68)
	if compressed>0.0:_spine_angle115(-compressed,minf(300000.0,3000000.0*compressed*compressed)*h*motor_h)
	var change: float =wrap_angle(spine_flex()-previous)
	_spine_angle115(clampf(change,-SPINE_RATE115*h,SPINE_RATE115*h)-change)

func _rigid_weight(r: Vector2, n: Vector2) -> float:
	var arm = r.cross(n)
	return 1.0/mass+arm*arm/inertia

func _rigid_push(r: Vector2, impulse: Vector2) -> void:
	x += impulse/mass
	theta += r.cross(impulse)/inertia

func _solve_bone(bone: Bone115) -> void:
	var a: int = bone.a
	var b: int = bone.b
	var start: Vector2 = ((pelvis_x+bone.local.rotated(pelvis_theta)) if bone.pelvic else (x+bone.local.rotated(theta))) if bone.rooted else p[a]
	var delta: Vector2 = p[b]-start
	var length: float = delta.length()
	if length<.0001: return
	var n: Vector2 = delta/length
	var error: float = length-bone.length
	var wb: float = inv_mass[b]
	if bone.rooted:
		# The root does not move between reading this anchor and applying the
		# correction. Reuse its lever instead of recomputing three rotations.
		var pelvic: bool = bone.pelvic
		var r: Vector2 = start-(pelvis_x if pelvic else x)
		var wa: float = 1.0/(pelvis_mass if pelvic else mass)+pow(r.cross(n),2)/(pelvis_inertia if pelvic else inertia)
		var s: float = error/(wa+wb)
		p[b] -= n*s*wb
		var impulse: Vector2 = n*s
		if pelvic:
			pelvis_x+=impulse*1.0/pelvis_mass
			pelvis_theta+=r.cross(impulse)*1.0/pelvis_inertia
		else:
			x+=impulse*1.0/mass
			theta+=r.cross(impulse)*1.0/inertia
	else:
		var wa: float = inv_mass[a]
		var s: float = error/(wa+wb)
		p[b] -= n*s*wb
		p[a] += n*s*wa

func _record(part: String) -> void:
	if not contacts.has(part): contacts[part] = age

func system_centre() -> Vector2:
	var total: float = mass+pelvis_mass
	var sum: Vector2 = x*mass+pelvis_x*pelvis_mass
	for i in range(COUNT):
		var m: float = 1.0/inv_mass[i]
		sum += p[i]*m
		total += m
	return sum/total

func _total_inertia(centre: Vector2) -> float:
	var total: float = inertia+mass*(x-centre).length_squared()+pelvis_inertia+pelvis_mass*(pelvis_x-centre).length_squared()+shield_inertia115
	for i in range(COUNT):
		total += (p[i]-centre).length_squared()/inv_mass[i]
	return maxf(total,1.0)

func translate(offset: Vector2) -> void:
	# Positional correction of the whole body without changing any velocity.
	x += offset
	x_prev += offset
	pelvis_x+=offset
	pelvis_prev+=offset
	for i in range(COUNT):
		p[i] = p[i]+offset
		prev[i] = prev[i]+offset

func _solve_torso_contacts() -> void:
	if x.y+torso_reach<ground: return
	for index in range(corners.size()+2):
		# Chest outline and shoulders. Pelvis contacts use its separate inertia.
		var lift: float = 0.0
		var local: Vector2
		if index<corners.size():
			local = corners[index]
		else:
			var name: String = SHOULDER_ANCHORS115[index-corners.size()]
			local = anchors[name]
			lift = 9.0 if name.begins_with("shoulder") else 8.0
		var r: Vector2 = local.rotated(theta)
		var point: Vector2 = x+r+Vector2(0,lift)
		var depth: float = point.y-ground
		if depth<=0.0: continue
		var before: Vector2 = x_prev+local.rotated(theta_prev)+Vector2(0,lift)
		var n: Vector2 = Vector2.UP
		var normal: float = depth/_rigid_weight(r,n)
		_rigid_push(r,n*normal)
		var w_t: float = _rigid_weight(r,Vector2.RIGHT)
		var tangent: float = clampf(-(point.x-before.x)/w_t,-FRICTION*normal,FRICTION*normal)
		_rigid_push(r,Vector2(tangent,0))
		if index<corners.size():
			core_contact = true
			torso_contact = true
			chest_contact115=true
			_record("chest" if local.y<-40.0 else "pelvis")
		else:
			_record(SHOULDER_PARTS115[index-corners.size()])

func _solve_pelvis_contacts115() -> void:
	if pelvis_x.y+60.0<ground: return
	for index in range(pelvis_corners.size()+2):
		var local: Vector2
		var lift: float =0.0
		if index<pelvis_corners.size():
			local=pelvis_corners[index]
		else:
			local=pelvis_anchors["hip_n" if index==pelvis_corners.size() else "hip_f"]
			lift=8.0
		var r: Vector2 = local.rotated(pelvis_theta)
		var point: Vector2 = pelvis_x+r+Vector2(0,lift)
		var depth: float =point.y-ground
		if depth<=0.0: continue
		var before: Vector2 =pelvis_prev+local.rotated(pelvis_theta_prev)+Vector2(0,lift)
		var normal: float =depth/(1.0/pelvis_mass+r.x*r.x/pelvis_inertia)
		_root_impulse115(true,Vector2.UP,r.cross(Vector2.UP),normal,false)
		var tangent: float =clampf(-(point.x-before.x)/(1.0/pelvis_mass+r.y*r.y/pelvis_inertia),-FRICTION*normal,FRICTION*normal)
		_root_impulse115(true,Vector2.RIGHT,r.cross(Vector2.RIGHT),tangent,false)
		core_contact=true
		torso_contact=true
		pelvis_contact115=true
		_record("pelvis")

func _point_contact(index: int, lift: float, part: String) -> void:
	# Packed arrays return copies; always write a whole element back.
	var q: Vector2 = p[index]
	var depth: float = q.y+lift-ground
	if depth<=0.0: return
	q.y -= depth
	q.x -= clampf(q.x-prev[index].x,-FRICTION*depth,FRICTION*depth)
	p[index] = q
	touching[index] = 1
	_record(part)

func _extension_point(data: Dictionary, previous: bool, offset: Vector2) -> Vector2:
	var start: Vector2 = end_position(data.a)
	var finish: Vector2 = p[data.b]
	if previous:
		start = anchor_previous(data.a) if data.a is String else prev[data.a]
		finish = prev[data.b]
	if data.get("roll",false) and shield_roll>0.0:
		# Rolling flat about the forearm shortens the face along the shield's
		# own long (y) axis; its x axis keeps following the forearm exactly.
		var bx: Vector2 = data.basis_x
		var by: Vector2 = data.basis_y
		var det: float = bx.cross(by)
		if absf(det)>.0001:
			var a = offset.cross(by)/det
			var b = bx.cross(offset)/det
			offset = bx*a+by*b*cos(shield_roll)
	var turn: float =(shield_previous115 if previous else shield_theta115) if bool(data.get("roll",false)) else (finish-start).angle()-float(data.angle0)
	return finish+offset.rotated(turn)

func _extension_contact(key: String, part: String) -> void:
	if not extensions.has(key): return
	var data: Dictionary = extensions[key]
	var finish: Vector2 = p[data.b]
	if finish.y+float(data.reach)<ground: return
	var start: Vector2 = end_position(data.a)
	var deepest: float = 0.0
	var point: Vector2 = Vector2.ZERO
	var chosen: Vector2 = Vector2.ZERO
	var rolling: bool = bool(data.get("roll",false))
	var turn: float = shield_theta115 if rolling else (finish-start).angle()-float(data.angle0)
	var bx: Vector2 = data.basis_x
	var by: Vector2 = data.basis_y
	var det: float = bx.cross(by)
	var roll_cos: float = cos(shield_roll)
	for original in data.offsets:
		var offset: Vector2 = original
		if rolling and shield_roll>0.0 and absf(det)>.0001:
			var a: float = offset.cross(by)/det
			var b: float = bx.cross(offset)/det
			offset=bx*a+by*b*roll_cos
		var q: Vector2 = finish+offset.rotated(turn)
		if q.y-ground>deepest:
			deepest = q.y-ground
			point = q
			chosen = original
	if deepest<=0.0: return
	# A long lever (shield rim, helmet edge) turned its whole limb by up to
	# 0.5 rad in one step on first contact (shield105). Resolve a deep entry
	# over a few substeps instead; the drawn outline is kept on the floor by
	# FallenRider's final positional correction.
	deepest = minf(deepest,EXTENSION_PUSH)
	_record(part)
	# The outline's friction is already distributed through its Jacobian.
	# A boot touching the floor does not mean its elevated knee is touching,
	# nor does a shield rim place the elbow on the floor. Extra rest damping
	# belongs only to actual joint-disc/chest/pelvis contact.
	# Friction acts on the actual contact point's travel this substep.
	var travel: float = point.x-_extension_point(data,true,chosen).x
	# A rim sits OFF the forearm/shin line. Its contact Jacobian must include
	# that rotational lever; barycentric weights along the line alone gave
	# the shield an incorrect impulse and flung the arm at first contact.
	var normal_impulse: float = _push_extension115(data,point,Vector2.UP,deepest)
	var grip: float = SHIELD_FRICTION if key=="shield" else FRICTION
	_push_extension115(data,point,Vector2.RIGHT,-travel,grip*normal_impulse)
	if key=="head": core_contact=true

func _push_extension115(data: Dictionary, point: Vector2, axis: Vector2, distance: float, limit: float = INF) -> float:
	var start: Vector2 = end_position(data.a)
	var finish: Vector2 = p[data.b]
	var bone: Vector2 = finish-start
	var lever: Vector2 = point-finish
	if bool(data.get("roll",false)):
		# A rim force turns the shield and pushes its actual hand; the finite
		# strap joint transmits that torque onward to the forearm and shoulder.
		var angular: float =lever.cross(axis)
		var weight115: float =inv_mass[data.b]+angular*angular/shield_inertia115
		var impulse115: float =clampf(distance/maxf(weight115,.000000001),-limit,limit)
		p[data.b]=p[data.b]+axis*impulse115*inv_mass[data.b]
		shield_theta115+=angular*impulse115/shield_inertia115
		return absf(impulse115)
	var angle_gradient: Vector2 = Vector2(-bone.y,bone.x)/maxf(bone.length_squared(),.001)
	var g_a: Vector2 = -angle_gradient*Vector2(-lever.y,lever.x).dot(axis)
	var g_b: Vector2 = axis-g_a
	var theta_gradient: float = 0.0
	var weight: float = g_b.length_squared()*inv_mass[data.b]
	if data.a is String:
		var r: Vector2 = start-x
		theta_gradient=g_a.dot(Vector2(-r.y,r.x))
		weight+=g_a.length_squared()/mass+theta_gradient*theta_gradient/inertia
	else:
		weight+=g_a.length_squared()*inv_mass[data.a]
	var impulse: float =clampf(distance/maxf(weight,.000000001),-limit,limit)
	p[data.b]=p[data.b]+g_b*impulse*inv_mass[data.b]
	if data.a is String:
		x+=g_a*impulse/mass
		theta+=theta_gradient*impulse/inertia
	else:
		p[data.a]=p[data.a]+g_a*impulse*inv_mass[data.a]
	return absf(impulse)

func angular_momentum(centre: Vector2) -> float:
	var total: float = inertia*omega+mass*(x-centre).cross(v)+pelvis_inertia*pelvis_omega+pelvis_mass*(pelvis_x-centre).cross(pelvis_v)+shield_inertia115*shield_omega115
	for i in range(COUNT):
		total += (p[i]-centre).cross(vel[i])/inv_mass[i]
	return total

func _landing_thud() -> void:
	# The first time the trunk meets the floor, armour, padding and flesh
	# deform and take out most of the body's tumble: an inelastic impact.
	# Without it a rider landing on his back at ~110 degrees kept rolling
	# heels over head onto his helmet (phys114-articulation09).
	thudded = true
	var centre: Vector2 = system_centre()
	var correction: float = -LANDING_THUD*angular_momentum(centre)/_total_inertia(centre)
	omega += correction
	pelvis_omega+=correction
	shield_omega115+=correction
	pelvis_v+=Vector2(-(pelvis_x-centre).y,(pelvis_x-centre).x)*correction
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

func _to_flat() -> float:
	# Turn that lays the trunk flat on the nearer side. Near upright the side
	# is the guide's (back/side landing), so the guide and a giving prop agree;
	# opposite targets held a kneeling rider upright between them for seconds
	# (phys114-trace07).
	var down: Vector2 = down_axis()
	var a = wrap_angle(-down.angle())
	var b = wrap_angle(PI-down.angle())
	var nearer: float = a if absf(a)<=absf(b) else b
	if absf(down.x)<.35 and guide_strength>0.0:
		var want: float = signf(wrap_angle(guide_angle-theta))
		if signf(nearer)!=want: return b if nearer==a else a
	return nearer

func linear_momentum() -> Vector2:
	var total: Vector2 = v*mass+pelvis_v*pelvis_mass
	for i in range(COUNT):
		total += vel[i]/inv_mass[i]
	return total

func total_mass() -> float:
	var total: float = mass+pelvis_mass
	for i in range(COUNT):
		total += 1.0/inv_mass[i]
	return total

func _damp_joints(h: float) -> void:
	# Apply dissipative internal angular impulses through the same Jacobian
	# as the joint limit. Contact need not borrow a global momentum correction.
	var keep: float = exp(-JOINT_DAMPING*h)
	var limit_keep: float = exp(-24.0*h)
	for joint in fast_joints115:
		var angle: float=_fast_flex115(joint)
		var strained: bool=(joint.kind=="hip" and angle>1.75) or (joint.kind=="knee" and (angle>2.10 or angle<.08)) or (joint.kind=="elbow" and angle<.12) or (joint.kind=="shoulder" and angle<-.90)
		_project_angle115(joint,0.0,limit_keep if strained else keep)
	var impulse: float =-(omega-pelvis_omega)*(1.0-keep)/(1.0/inertia+1.0/pelvis_inertia)
	omega+=impulse/inertia
	pelvis_omega-=impulse/pelvis_inertia
	var bone: Vector2 = p[HAND_L]-p[ELBOW_L]
	var gradient: Vector2 =Vector2(-bone.y,bone.x)/maxf(bone.length_squared(),.001)
	var rate: float =shield_omega115-gradient.dot(vel[HAND_L]-vel[ELBOW_L])
	var weight: float =1.0/shield_inertia115+gradient.length_squared()*(inv_mass[HAND_L]+inv_mass[ELBOW_L])
	var strap_impulse: float =-rate*(1.0-keep)/weight
	shield_omega115+=strap_impulse/shield_inertia115
	vel[HAND_L]=vel[HAND_L]-gradient*strap_impulse*inv_mass[HAND_L]
	vel[ELBOW_L]=vel[ELBOW_L]+gradient*strap_impulse*inv_mass[ELBOW_L]

func set_muscles(value_tone: float, value_targets: Dictionary) -> void:
	tone = value_tone
	targets = value_targets

func step(dt: float, support: Dictionary = {}) -> void:
	# Free/fallen limbs have a tightly coupled floor/boot/waist contact graph.
	# Four smaller predictions resolve it better than two large predictions
	# with ten repeated sweeps. Riding retains its established two substeps.
	var substeps115: int=4 if support.is_empty() else SUBSTEPS
	var h: float = dt/substeps115
	motor_step115=h
	# Fixed-step targets do not change within the constraint sweeps.
	for joint in fast_joints115:
		joint.active_target115=tone>0.0 and targets.has(joint.name)
		if joint.active_target115:
			joint.target115=_fast_target115(joint)
			joint.strength115=float(targets.get(joint.name+"_tone",1.0))*tone
	support_contacts115.clear()
	contacts.clear()
	core_contact = false
	torso_contact = false
	chest_contact115=false
	pelvis_contact115=false
	touching.resize(COUNT)
	touching.fill(0)
	# Measure the physical trajectory; rendering-only floor correction never
	# writes back into these positions.
	var step_x: Vector2 = last_x if has_last else x
	var step_theta: float = last_theta if has_last else theta
	for substep in range(substeps115):
		age += h
		var previous_spine115: float =spine_flex()
		var previous_flex115: PackedFloat32Array =PackedFloat32Array()
		for joint in fast_joints115: previous_flex115.append(_fast_flex115(joint))
		# Predict.
		x_prev = x
		theta_prev = theta
		pelvis_prev=pelvis_x
		pelvis_theta_prev=pelvis_theta
		shield_previous115=shield_theta115
		shield_strap_previous115=shield_theta115-(p[HAND_L]-p[ELBOW_L]).angle()+float(extensions.shield.angle0) if extensions.has("shield") else 0.0
		v.y += GRAVITY*h
		pelvis_v.y+=GRAVITY*h
		if guide_strength>0.0 and (grounded_age<0.0 or (grounded_age<2.5 and absf(down_axis().y)>.5)):
			# DEV-113's weak airborne orientation bias (3, 1.1): the trunk heads
			# for a back/side landing instead of head first or seated. While the
			# trunk is still upright it lasts up to 1.5 s after landing: a rider
			# landing on his feet or seat otherwise stayed standing or sitting.
			# On the floor it heads for the nearer flat side instead of the
			# airborne target, which could lie across upright (trace07).
			var error: float = wrap_angle(guide_angle-theta) if grounded_age<0.0 else _to_flat()
			omega += (guide_strength*3.0*error-guide_strength*1.1*omega)*h
		x += v*h
		theta += omega*h
		pelvis_x+=pelvis_v*h
		pelvis_theta+=pelvis_omega*h
		shield_omega115+=shield_mass115*GRAVITY*shield_centre115.rotated(shield_theta115).x/shield_inertia115*h
		shield_theta115+=shield_omega115*h
		for i in range(COUNT):
			prev[i] = p[i]
			vel[i] = vel[i]+Vector2(0,GRAVITY*h)
			p[i] = p[i]+vel[i]*h
		# Contact is the LAST constraint of each sweep. A final bone pass used
		# to put boots below the floor again; the renderer then lifted the whole
		# person by ~1.5px each tick, a hidden anti-gravity support at the foot.
		var iterations: int =maxi(3,ceili(contact_iterations115*.5)) if grounded_age>=0.0 and support.is_empty() else contact_iterations115 if grounded_age>=0.0 else 2
		for sweep in range(iterations):
			for bone in fast_bones115: _solve_bone(bone)
			_waist_hinge115()
			for joint in fast_joints115: _solve_joint(joint,h/iterations)
			_posterior_tissue115(h/iterations)
			_anterior_tissue115(h/iterations)
			_shield_joint115(h/iterations)
			_spine_constraint115(h,previous_spine115,h/iterations)
			_solve_neck(h/iterations)
			_joint_rates115(previous_flex115,h)
			for index in range(fast_bones115.size()-1,-1,-1): _solve_bone(fast_bones115[index])
			_waist_hinge115()
			if not support.is_empty(): _mounted_contacts115(support,h,float(substep+1)/substeps115)
			_solve_torso_contacts()
			_solve_pelvis_contacts115()
			for i in FLOOR_PARTICLES115:
				_point_contact(i,radius[i],PARTICLE_NAMES[i])
			_extension_contact("boot_n","near_shin")
			_extension_contact("boot_f","far_shin")
			_extension_contact("shield","shield")
			_extension_contact("head","head")
		_shield_rolls(h)
		# Derive velocities.
		var drag: float = 1.0-AIR_DRAG*h
		v = ((x-x_prev)/h*drag).limit_length(MAX_SPEED)
		omega = clampf(wrap_angle(theta-theta_prev)/h*drag,-14.0,14.0)
		pelvis_v=((pelvis_x-pelvis_prev)/h*drag).limit_length(MAX_SPEED)
		pelvis_omega=clampf(wrap_angle(pelvis_theta-pelvis_theta_prev)/h*drag,-14.0,14.0)
		shield_omega115=clampf(wrap_angle(shield_theta115-shield_previous115)/h*drag,-14.0,14.0)
		for i in range(COUNT):
			vel[i] = ((p[i]-prev[i])/h*drag).limit_length(MAX_SPEED)
		# A torque acts on velocities, so after they are derived from positions
		# (applied before, it was overwritten and never acted: body14-16).
		if support.is_empty():_damp_joints(h)
	if not support.is_empty():_damp_joints(dt)
	# Trunk or helmet: riders often land on head and shoulders first.
	if core_contact and not thudded:
		_landing_thud()
	if rest>0.0:
		# Only the trunk and parts lying on the floor lose energy this way; a
		# limb still dropping must finish its fall (a global damping froze a
		# shield arm in the air, phys114-articulation02).
		var keep: float = exp(-8.0*rest*dt)
		if chest_contact115:
			v *= keep
			omega *= keep
		if pelvis_contact115:
			pelvis_v*=keep
			pelvis_omega*=keep
		if contacts.has("shield"):shield_omega115*=keep
		for i in range(COUNT):
			if touching[i]: vel[i] = vel[i]*keep
	if grounded_age<0.0 and not contacts.is_empty(): grounded_age = 0.0
	elif grounded_age>=0.0: grounded_age += dt
	# Measured trunk motion (smoothed over ~0.15 s). The derived velocity of a
	# trunk braced on a leg carries 40-90 px/s of solver residue while it does
	# not move at all, which kept the props rule from ever acting
	# (phys114-trace06).
	# Signed averages: a still trunk jitters by a fraction of a pixel each step,
	# which an averaged speed read as 45 px/s of motion (phys114-trace08).
	var blend: float = 1.0-exp(-dt/.15)
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
	var solved: PackedVector2Array = p
	p = p.duplicate()
	for bone in bones:
		var start: Vector2 = end_position(bone[0])
		var direction: Vector2 = p[bone[1]]-start
		if direction.length_squared()>.000001:
			var moved: Vector2 = start+direction.normalized()*float(bone[2])
			var shift: Vector2 = moved-p[bone[1]]
			p[bone[1]] = moved
			# Carry the rest of the chain with its parent joint.
			for other in bones:
				if other[0] is int and int(other[0])==bone[1]: p[other[1]] = p[other[1]]+shift
	for joint in joints:
		var value: float = _in_range(_flex(joint),float(joint.lo))
		if value>float(joint.hi):
			var to_hi: float = value-float(joint.hi)
			var to_lo: float = float(joint.lo)+TAU-value
			_rotate_chain(joint.chain,end_position(joint.pivot),_world_turn(joint,-to_hi if to_hi<=to_lo else to_lo))
	var angle: float = neck_angle()
	if absf(angle)>neck_limit:
		var neck: Vector2 = anchor("neck")
		p[HEAD] = neck+(p[HEAD]-neck).rotated(signf(angle)*neck_limit-angle)
	var result: PackedVector2Array = p
	p = solved
	return result

func motion() -> float:
	# Largest speed of any part, including the rim of the spinning torso.
	var fastest: float = maxf(v.length()+absf(omega)*60.0,pelvis_v.length()+absf(pelvis_omega)*30.0)
	for i in range(COUNT):
		fastest = maxf(fastest,vel[i].length())
	return fastest

func point_velocity(index: int) -> Vector2:
	return vel[index]

func segment_spin(a, b: int) -> float:
	var start: Vector2 = end_position(a)
	var start_velocity: Vector2 = anchor_velocity(a) if a is String else vel[a]
	var r: Vector2 = p[b]-start
	return r.cross(vel[b]-start_velocity)/maxf(r.length_squared(),1.0)

func apply_impulse115(part: String, point: Vector2, impulse: Vector2) -> void:
	# External impulse at the actual contact. In particular a shield-edge hit
	# contributes its lever torque, instead of translating the hand alone.
	if part=="shield" and extensions.has(part):
		vel[HAND_L]=vel[HAND_L]+impulse*inv_mass[HAND_L]
		shield_omega115+=(point-p[HAND_L]).cross(impulse)/shield_inertia115
	elif part=="head" and extensions.has(part):
		var data: Dictionary=extensions[part]
		_impulse_segment115(data.a,data.b,point,impulse)
	elif part=="lance":
		_impulse_segment115(ELBOW_R,HAND_R,point,impulse)
	elif part=="flank":
		pelvis_v+=impulse/pelvis_mass
		pelvis_omega+=(point-pelvis_x).cross(impulse)/pelvis_inertia
	else:
		v+=impulse/mass
		omega+=(point-x).cross(impulse)/inertia

func _impulse_segment115(a, b: int, point: Vector2, impulse: Vector2) -> void:
	var start: Vector2 = end_position(a)
	var axis: Vector2 = p[b]-start
	var gradient: Vector2 =Vector2(-axis.y,axis.x)/maxf(axis.length_squared(),.001)
	var first: Vector2 =-gradient*(point-p[b]).cross(impulse)
	vel[b]=vel[b]+(impulse-first)*inv_mass[b]
	if a is String:
		var pelvic: bool =pelvis_anchors.has(a)
		_root_impulse115(pelvic,first,(start-(pelvis_x if pelvic else x)).cross(first),1.0,true)
	else:
		vel[a]=vel[a]+first*inv_mass[a]

func _support_rigid115(pelvic: bool, local: Vector2, current: Vector2, previous: Vector2, half_width: float, friction: float, tag: String) -> void:
	var angle: float =pelvis_theta if pelvic else theta
	var r: Vector2 =local.rotated(angle)
	var point: Vector2 =(pelvis_x if pelvic else x)+r
	if absf(point.x-current.x)>half_width: return
	# Finite curved saddle, with a shallow seat and rising pommel/cantle.
	# Its normal carries the rider inward; an infinite centre spring would
	# keep a struck pelvis attached even after it clears the saddle rim.
	var dx: float =point.x-current.x
	var curvature: float =.024 if tag=="saddle" else 0.0
	var normal_axis: Vector2 =Vector2(-2.0*curvature*dx,-1).normalized()
	var depth: float =(point.y-current.y+curvature*(dx*dx-121.0))/sqrt(1.0+pow(2.0*curvature*dx,2))
	if depth<=0.0 or depth>22.0: return
	var m: float = pelvis_mass if pelvic else mass
	var moment: float = pelvis_inertia if pelvic else inertia
	var normal: float =depth/(1.0/m+pow(r.cross(normal_axis),2)/moment)
	_root_impulse115(pelvic,normal_axis,r.cross(normal_axis),normal,false)
	var before: Vector2 =(pelvis_prev if pelvic else x_prev)+local.rotated(pelvis_theta_prev if pelvic else theta_prev)
	var axis: Vector2 =Vector2(-normal_axis.y,normal_axis.x)
	var travel: float =(point-before-current+previous).dot(axis)
	var tangent: float =clampf(-travel/(1.0/m+pow(r.cross(axis),2)/moment),-friction*normal,friction*normal)
	_root_impulse115(pelvic,axis,r.cross(axis),tangent,false)
	support_contacts115[tag]=true

func _mounted_contacts115(support: Dictionary, h: float, alpha: float) -> void:
	var saddle_before: Vector2=support.saddle_previous
	var saddle_now: Vector2=support.saddle
	var saddle: Vector2 =saddle_before.lerp(saddle_now,alpha)
	var old: Vector2 =saddle_before.lerp(saddle_now,maxf(0.0,alpha-1.0/SUBSTEPS))
	var upright: bool =hip_down_axis().dot(Vector2.DOWN)>.25
	if upright:
		for local in support.seat_points:
			_support_rigid115(true,local,saddle,old,float(support.width),float(support.friction),"saddle")
	# Conscious thigh/seat bracing applies a bounded torque against the horse,
	# only while the finite saddle is actually carrying the pelvis. It cannot
	# orient a free body in midair or hold the rider through an arbitrarily hard hit.
	if support_contacts115.has("saddle") and float(support.get("brace_torque",0.0))>0.0:
		var turn: float =wrap_angle(hip_down_axis().angle()-PI*.5-float(support.get("pelvis_angle",0.0)))
		var torque: float =clampf(-16000000.0*turn-1300000.0*pelvis_omega,-float(support.brace_torque),float(support.brace_torque))
		pelvis_theta+=torque*h*h*.5/pelvis_inertia
	for side in ["near","far"]:
		var index: int =ANKLE_N if side=="near" else ANKLE_F
		var knee: int =KNEE_N if side=="near" else KNEE_F
		if (p[index]-p[knee]).normalized().y<.25:continue
		var iron_before: Vector2=support.feet_previous[side]
		var iron: Vector2=iron_before.lerp(support.feet[side],alpha)
		var point: Vector2=p[index]
		var depth: float =point.y-iron.y
		if absf(point.x-iron.x)<float(support.get("iron_width",14.0)) and depth>0.0 and depth<12.0:
			p[index]=Vector2(point.x,point.y-depth)
			var travel: float =point.x-prev[index].x-(iron.x-iron_before.lerp(support.feet[side],maxf(0.0,alpha-1.0/SUBSTEPS)).x)
			p[index]=p[index]-Vector2(clampf(travel,-depth*.65,depth*.65),0)
			support_contacts115[side]=true
	# A loose rein has a finite grip. It is not a fixed hand attachment, and
	# becomes ineffective once the wrist is pulled outside its slack range.
	if bool(support.get("rein_grip",false)):
		var rein: Vector2=Vector2(support.rein_previous).lerp(support.rein,alpha)
		var delta: Vector2 =p[HAND_L]-rein
		var length: float = delta.length()
		var slack: float =float(support.rein_length)
		if length>slack and length<slack+20.0:
			var pull: float =minf((length-slack)/inv_mass[HAND_L],float(support.rein_force)*h*h/2.0)
			p[HAND_L]=p[HAND_L]-delta/length*pull*inv_mass[HAND_L]
			support_contacts115.rein=true
	# Horse neck contact supports a limp chest/head. This contact belongs to
	# the mounted phase only; a detached rider cannot be scooped up again.
	if support.has("crest"):
		for index in range(support.crest.size()-1):
			var a: Vector2=support.crest[index]
			var b: Vector2=support.crest[index+1]
			if absf(b.x-a.x)<.01: continue
			for part in ["chest"]:
				var point: Vector2 =x
				var fraction: float =(point.x-a.x)/(b.x-a.x)
				if fraction<0.0 or fraction>1.0: continue
				var floor_y: float =lerpf(a.y,b.y,fraction)-13.0
				var depth: float =point.y-floor_y
				if depth<=0.0 or depth>20.0: continue
				x.y-=depth
				support_contacts115[part]=true
			if not extensions.has("head"):continue
			var head:Dictionary=extensions.head
			var deepest: float =0.0
			var contact: Vector2 =Vector2.ZERO
			for offset in head.offsets:
				var point: Vector2 =_extension_point(head,false,offset)
				var fraction: float =(point.x-a.x)/(b.x-a.x)
				if fraction<0.0 or fraction>1.0:continue
				var depth: float =point.y-lerpf(a.y,b.y,fraction)
				if depth>deepest and depth<24.0:deepest=depth;contact=point
			if deepest>0.0:
				# The jaw/shell contact turns the head about its neck and passes
				# force into the trunk; it does not pin the skull's centre upward.
				_push_extension115(head,contact,Vector2.UP,minf(deepest,EXTENSION_PUSH))
				support_contacts115.head=true
