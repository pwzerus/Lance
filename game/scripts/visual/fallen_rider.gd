class_name FallenRider
extends Node2D
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

func setup(value: Dictionary, event: Dictionary, mounted: RiderView = null) -> void:
	fighter = value.duplicate(true)
	direction = int(event.get("direction",-int(fighter.direction)))
	zone = str(event.get("zone","body"))
	strength = clampf(float(event.get("impulse",70.0))/110.0,.15,1.0)
	initial_pose = Rider.arm_pose(fighter).duplicate(true)
	position = initial_pose.torso_transform.origin
	initial_position = position
	ground_y = float(fighter.get("lane_y",0.0))+12.0
	var mirror = Vector2(int(fighter.direction),1)
	var mounted_origin = Vector2(float(fighter.x),float(fighter.get("lane_y",0.0)))
	var relative_hip = (position-mounted_origin)*mirror
	initial_legs = Rider.seated_leg_pose(fighter).duplicate(true)
	for side in ["near","far"]:
		for joint in ["hip","knee","ankle","foot"]:
			initial_legs[side][joint] -= relative_hip
	for side in ["left","right"]:
		for joint in ["shoulder","elbow","hand"]:
			initial_pose[side][joint] -= position
	initial_pose.shield_center -= position
	initial_pose.shield_grip -= position
	initial_pose.torso_transform.origin = Vector2.ZERO
	# Retain some mounted momentum; actual incoming impulse changes its course.
	# One constrained body replaces six unrelated random rigid-body throws.
	velocity = Vector2(float(fighter.speed)*int(fighter.direction)*.18+direction*lerpf(110,225,strength),-lerpf(65,120,strength))
	var sign_of_roll = direction if zone!="flank" else -direction
	target_rotation = sign_of_roll*(PI*.48 if zone=="head" else PI*.44)
	angular_velocity = sign_of_roll*lerpf(.8,1.8,strength)
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

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if settled or not is_instance_valid(visual):
		return
	var remaining = minf(delta,.25)
	while remaining>.000001:
		var dt = minf(remaining,1.0/120.0)
		age += dt
		_update_pose()
		if age>=.22 and not is_instance_valid(loose_lance):
			_release_lance()
		if not grounded:
			velocity.y += 900.0*dt
			angular_velocity += (12.0*angle_difference(rotation,target_rotation)-5.0*angular_velocity)*dt
			position += velocity*dt
			rotation += angular_velocity*dt
		else:
			ground_age += dt
			velocity.x *= exp(-6.5*dt)
			position.x += velocity.x*dt
			rotation = lerp_angle(rotation,target_rotation,1.0-exp(-8.0*dt))
		var lowest = lowest_body_point()
		if position.y+lowest>=ground_y or grounded:
			position.y = ground_y-lowest
			if not grounded:
				grounded = true
				landing_speed = velocity.length()
				landed.emit(Vector2(position.x,ground_y),strength)
				velocity.y = 0.0
				angular_velocity = 0.0
		if grounded and ground_age>.65:
			settled = true
		remaining -= dt
	far_leg.z_index = 0 if age>.23 else (-3 if ground_y>12 else -1)
	visual.queue_redraw()
	far_leg.queue_redraw()

func _update_pose() -> void:
	var t = smoothstep(.035,.38,age)
	var pose = initial_pose.duplicate(true)
	var legs = initial_legs.duplicate(true)
	for side in ["left","right"]:
		var arm: Dictionary = initial_pose[side]
		var upper: Vector2 = arm.elbow-arm.shoulder
		var lower: Vector2 = arm.hand-arm.elbow
		var upper_turn = t*direction*(.42 if side=="right" else -.24)
		var lower_turn = t*direction*(.62 if zone=="head" else .28)
		pose[side].elbow = arm.shoulder+upper.rotated(upper_turn)
		pose[side].hand = pose[side].elbow+lower.rotated(upper_turn+lower_turn)
	pose.shield_center += pose.left.hand-initial_pose.left.hand
	pose.shield_grip = pose.left.hand
	for side in ["near","far"]:
		var leg: Dictionary = initial_legs[side]
		var thigh: Vector2 = leg.knee-leg.hip
		var shin: Vector2 = leg.ankle-leg.knee
		var fold = t*(.55 if side=="near" else -.28)
		legs[side].knee = leg.hip+thigh.rotated(fold)
		legs[side].ankle = legs[side].knee+shin.rotated(-fold*.8)
		legs[side].foot = legs[side].ankle+(leg.foot-leg.ankle).rotated(-fold*.8)
	for renderer in [visual,far_leg]:
		renderer.detached_pose = pose
		renderer.detached_legs = legs
		renderer.stirrup_alpha = 1.0-smoothstep(.02,.18,age)
		# The lance follows the rotating anatomical right hand, never jumps to a new aim.
		renderer.fighter.aim = float(fighter.get("aim",0.0))

func body_points() -> PackedVector2Array:
	var points = PackedVector2Array()
	var pose: Dictionary = visual.detached_pose
	var torso: Transform2D = pose.torso_transform
	var fit: Dictionary = Rider.HeadFit.layout(fighter.stats)
	var head: Rect2 = fit.helmet
	var facing = Vector2(int(fighter.direction),1)
	for p in [head.position,Vector2(head.end.x,head.position.y),head.end,Vector2(head.position.x,head.end.y)]:
		points.append(torso*(p*facing+Vector2(float(fit.head_offset),0)))
	for p in [Vector2(-38,-80),Vector2(38,-80),Vector2(-34,8),Vector2(34,8)]:
		points.append(torso*p)
	for side in ["left","right"]:
		for joint in ["shoulder","elbow","hand"]:
			points.append(pose[side][joint]+Vector2(0,9))
	var mirror = Vector2(int(fighter.direction),1)
	if float(fighter.get("shield",0.0))>0.0:
		for point in Rider.Shield.polygon(str(fighter.stats.get("shield_shape","kite"))):
			points.append(pose.shield_center+torso.basis_xform(point*mirror))
	for side in ["near","far"]:
		for joint in ["hip","knee","ankle","foot"]:
			points.append(visual.detached_legs[side][joint]*mirror)
	return points

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
