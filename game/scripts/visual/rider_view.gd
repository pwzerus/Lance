class_name RiderView
extends Node2D
signal hoof_contact(leg_index: int)

const ATLAS = preload("res://assets/art/pixel_v03/rider_atlas.png")
const Model = preload("res://scripts/core/joust_match.gd")
const Art = preload("res://scripts/visual/equipment_art.gd")
const HorseArt = preload("res://scripts/visual/horse_art.gd")
const Gait = preload("res://scripts/visual/horse_gait.gd")
const Shield = preload("res://scripts/core/shield_geometry.gd")
const ArmArt = preload("res://scripts/visual/rider_arm_art.gd")
const Face = preload("res://scripts/visual/character_face.gd")
const HeadFit = preload("res://scripts/visual/head_fit.gd")
const HorseSkin = preload("res://scripts/visual/horse_skin.gd")
const Lance = preload("res://scripts/visual/lance_art.gd")
const PIXEL_SHADER = preload("res://scripts/visual/mounted_pixel.gdshader")
const ARM_UPPER = 44.0
const ARM_LOWER = 46.0
const LANCE_SHOULDER = Vector2(-25,-64)
const SHIELD_SHOULDER = Vector2(25,-64)
const SHIELD_UPPER = ARM_UPPER
const SHIELD_LOWER = ARM_LOWER
const PARTS = {
	"horse_body":Rect2(14,364,407,259),"horse_head":Rect2(424,324,309,300),
	"horse_upper":Rect2(776,344,146,274),"horse_lower":Rect2(1067,357,125,252),
	"rider_leg":Rect2(687,633,204,288),"banner":Rect2(947,700,285,192),
	"coronel":Rect2(630,994,287,169),"point":Rect2(935,1048,298,87)}
var detached_lance_visible = true
var lance_only = false
var detached_pose: Dictionary = {}
var detached_legs: Dictionary = {}
var detached_far_only = false
var detached_far_visible = true
var stirrup_alpha = 1.0
var fighter: Dictionary = {}
var red = false
var clock = 0.0
var moving = false
var blood_enabled = false
var mode = "arena"
var impact_recoil = 0.0
var lance_recoil = 0.0
var shield_recoil = 0.0
var impact_velocity = 0.0
var lance_velocity = 0.0
var shield_velocity = 0.0
var stride_phase = 0.0
var preview = false
var last_cycles = [0.0,0.0,0.0,0.0]
var early_release = [false,false,false,false]
var release_cycles = [0.0,0.0,0.0,0.0]
var previous_contacts = [false,false,false,false]
var torso_texture: Texture2D
var head_texture: Texture2D
var shield_texture: Texture2D
var art_key = ""
var planted_feet: Array[float] = [INF,INF,INF,INF]
var leg_poses: Array[Dictionary] = []
var swing_starts: Array[Vector2] = [Vector2.INF,Vector2.INF,Vector2.INF,Vector2.INF]
var swing_durations: Array[float] = [.3,.3,.3,.3]
var last_feet: Array[Vector2] = [Vector2.INF,Vector2.INF,Vector2.INF,Vector2.INF]
var previous_stride_phase = 0.0
var cycles_initialized = false
var horse_skin: RefCounted
var far_hind_skin: RefCounted
var far_fore_skin: RefCounted

func _init() -> void:
	var pixel_material = ShaderMaterial.new()
	pixel_material.shader = PIXEL_SHADER
	material = pixel_material

func _process(delta: float) -> void:
	if not detached_pose.is_empty() or lance_only:
		_advance_recoil(delta)
		queue_redraw()
		return
	clock += delta
	var speed = float(fighter.get("speed",0.0))
	if fighter.has("gait_phase") and not preview:
		stride_phase = float(fighter.gait_phase)
	else:
		stride_phase += delta*TAU*Gait.frequency(speed) if moving else delta*1.2
		if preview:
			fighter.gait_phase = stride_phase
			fighter.gait_moving = moving
	leg_poses.clear()
	var landed: Array[int] = []
	var phase_step = (stride_phase-previous_stride_phase)/TAU
	var reset_cycles = not moving or phase_step<0 or phase_step>=.5
	for index in range(4):
		var stability = float(fighter.get("stats",{}).get("stability",1.0))
		var drive = float(fighter.get("motion_drive",0.0))
		var leg_pose = Gait.leg(index,stride_phase,speed,moving,stability,INF,Vector2.INF,drive)
		var facing = int(fighter.get("direction",1))
		var cycle = float(leg_pose.cycle)
		if cycles_initialized and moving and phase_step>=0 and phase_step<.5:
			# Retiming towards a new footfall pattern must never rewind a
			# leg or cut its swing short when walk/trot/canter weights change.
			var expected = fposmod(float(last_cycles[index])+phase_step,1)
			var error = wrapf(cycle-expected,-.5,.5)
			cycle = fposmod(expected+clampf(error,-phase_step*.25,phase_step*.25),1)
			leg_pose = Gait.leg(index,stride_phase,speed,moving,stability,INF,Vector2.INF,drive,-1,cycle)
		if cycle<float(last_cycles[index])-.5 or reset_cycles:
			planted_feet[index] = INF
			early_release[index] = false
			swing_starts[index] = Vector2.INF
			if reset_cycles:
				last_feet[index] = Vector2.INF
				previous_contacts[index] = false
		if moving and leg_pose.contact and not early_release[index]:
			if not is_finite(planted_feet[index]):
				planted_feet[index] = position.x+leg_pose.foot.x*facing
			leg_pose = Gait.leg(index,stride_phase,speed,true,stability,(planted_feet[index]-position.x)*facing,Vector2.INF,drive,-1,cycle)
			if not leg_pose.contact:
				early_release[index] = true
				release_cycles[index] = cycle
		if moving and (not leg_pose.contact or early_release[index]):
			if is_finite(planted_feet[index]) or not swing_starts[index].is_finite():
				swing_starts[index] = last_feet[index] if last_feet[index].is_finite() else Vector2(position.x+leg_pose.foot.x*facing,leg_pose.foot.y)
				release_cycles[index] = cycle
				swing_durations[index] = maxf(.08,(1-cycle)/maxf(.1,Gait.frequency(speed)))
			# Once lifted, finish the swing. A slower gait's longer duty must
			# not replant a hoof halfway through the air on the following tick.
			early_release[index] = true
			planted_feet[index] = INF
			var progress = float(leg_pose.swing)
			if early_release[index]:
				progress = clampf((cycle-float(release_cycles[index]))/maxf(.01,1.0-float(release_cycles[index])),0,1)
			var target_x = Gait.rest_foot(index).x+float(leg_pose.reach)
			var trajectory = Gait._swing_point(leg_pose.front,progress,float(leg_pose.reach),float(leg_pose.lift),Gait.weights(speed).z+Gait.weights(speed).w)
			var protraction = (trajectory.x+float(leg_pose.reach))/maxf(1,2.0*float(leg_pose.reach))
			# Aim the swing at where the body WILL be at landing. Chasing the
			# body's current position made every step stall then whip forward.
			# Recompute remaining time from the current continuous cycle. A
			# duration captured near standstill can be >3s; after acceleration
			# it predicted a landing far beyond reach, then whipped back late.
			var remaining_travel = speed*(1-cycle)/maxf(.1,Gait.frequency(speed))
			var landing_x = position.x+(target_x+remaining_travel)*facing
			var foot = Vector2((lerpf(swing_starts[index].x,landing_x,protraction)-position.x)*facing,lerpf(swing_starts[index].y,Gait.GROUND,progress)+trajectory.y)
			leg_pose = Gait.leg(index,stride_phase,speed,true,stability,INF,foot,drive,progress,cycle)
			leg_pose.contact = false
		if moving and leg_pose.contact and not previous_contacts[index]:
			landed.append(index)
		previous_contacts[index] = leg_pose.contact if moving else false
		last_cycles[index] = cycle
		last_feet[index] = Vector2(position.x+leg_pose.foot.x*facing,leg_pose.foot.y)
		leg_poses.append(leg_pose)
	previous_stride_phase = stride_phase
	cycles_initialized = moving
	if moving and delta>0 and delta<.2:
		for index in landed:
			hoof_contact.emit(index)
	_advance_recoil(delta)
	queue_redraw()

func _advance_recoil(delta: float) -> void:
	# Contact adds momentum; the mesh never jumps to a new weapon/guard pose.
	# Stable small game-time steps keep recoil independent of render rate.
	var remaining = minf(delta,.25)
	while remaining>0.000001:
		var dt = minf(remaining,1.0/120.0)
		impact_velocity += (-310.0*impact_recoil-25.0*impact_velocity)*dt
		lance_velocity += (-520.0*lance_recoil-22.0*lance_velocity)*dt
		shield_velocity += (-460.0*shield_recoil-28.0*shield_velocity)*dt
		impact_recoil += impact_velocity*dt
		lance_recoil += lance_velocity*dt
		shield_recoil += shield_velocity*dt
		remaining -= dt

func receive_impact(strength: float, on_shield: bool) -> void:
	impact_velocity = minf(impact_velocity+clampf(strength,0,1)*(17.0 if on_shield else 42.0),48.0)
	if on_shield:
		shield_velocity = minf(shield_velocity+clampf(strength,0,1)*36.0,42.0)

func receive_lance_contact(strength: float) -> void:
	lance_velocity = minf(lance_velocity+clampf(strength,0,1)*32.0,36.0)

func draw_part(part: String, destination: Rect2, color: Color = Color.WHITE) -> void:
	draw_texture_rect_region(ATLAS,destination,PARTS[part],color)

func _draw() -> void:
	if fighter.is_empty():
		return
	if lance_only:
		_draw_lance(Vector2.ZERO,0.0,Model.lance_length(fighter),bool(fighter.broken))
		return
	var tier = int(fighter.stats.get("armor_tier",0))
	var head_tier = int(fighter.stats.get("helmet_tier",0))
	var design = str(fighter.stats.get("heraldry","bend"))
	var armor_red = bool(fighter.stats.get("armor_red",red))
	var next_key = "%d/%d/%s/%s/%s/%s/%s" % [tier,head_tier,design,armor_red,fighter.stats.get("gilt",false),fighter.stats.get("armor_art",""),fighter.stats.get("helmet_art","")]
	if next_key != art_key:
		art_key = next_key
		torso_texture = Art.torso_for(fighter.stats,armor_red)
		head_texture = Art.helmet_for(fighter.stats)
		shield_texture = Art.shield(design)
	var facing = int(fighter.direction)
	if not detached_pose.is_empty():
		if detached_far_visible or detached_far_only:
			draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))
			_draw_seated_leg(detached_legs.far,Color(.63,.66,.69),false)
		if not detached_far_only:
			_draw_rider(detached_pose,detached_legs,Vector2.ZERO)
		return
	draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))
	if horse_skin==null:
		horse_skin = HorseSkin.new()
		far_hind_skin = HorseSkin.new("hind")
		far_fore_skin = HorseSkin.new("fore")
	var stride = stride_phase
	var horse_pose = Gait.body(stride,float(fighter.get("speed",0.0)),moving,float(fighter.stats.get("stability",1.0)),float(fighter.get("motion_drive",0.0)))
	var horse_tint = Color(str(fighter.stats.get("horse_color","a87950"))).lerp(Color.WHITE,.48)
	var seated = seated_leg_pose(fighter)
	var rider_visible = not bool(fighter.get("ko",false)) and not bool(fighter.get("dead",false))
	_draw_horse_leg(0,horse_tint.darkened(.29))
	_draw_horse_leg(2,horse_tint.darkened(.25))
	# A straddling rider's far thigh and shin are behind the horse barrel.
	# Drawing both after the barrel made the rider appear side-saddle.
	if rider_visible:
		_draw_seated_leg(seated.far,Color(.63,.66,.69),false)
	var hind_pose = _horse_leg_pose(1)
	var fore_pose = _horse_leg_pose(3)
	horse_skin.update(horse_pose,hind_pose,fore_pose)
	horse_skin.draw(self,horse_tint)
	var muzzle = HorseSkin.muzzle_point(horse_pose)
	var rein_hand = ((Model.shield_position(fighter)-Vector2(fighter.x,fighter.get("lane_y",0)))*Vector2(facing,1))+Vector2(-10,4).rotated(Model.pose_angle(fighter))
	if fighter.get("ko",false) or fighter.get("dead",false):
		rein_hand = Model.HIP+Vector2(8,20)+horse_pose.offset
	draw_polyline(PackedVector2Array([muzzle,muzzle.lerp(rein_hand,.55)+Vector2(0,20),rein_hand]),Color("493628"),2.5,true)
	if bool(fighter.get("ko",false)) or bool(fighter.get("dead",false)):
		draw_set_transform(Vector2.ZERO)
		return
	_draw_rider(arm_pose(fighter),seated,Vector2(float(fighter.x),float(fighter.get("lane_y",0.0))))

func _draw_rider(pose: Dictionary, seated: Dictionary, origin: Vector2) -> void:
	var facing = int(fighter.direction)
	var head_tier = int(fighter.stats.get("helmet_tier",0))
	var design = str(fighter.stats.get("heraldry","bend"))
	var torso_transform: Transform2D = pose.torso_transform
	torso_transform.origin -= origin
	var torso_inverse: Transform2D = pose.torso_transform.affine_inverse()
	var right_arm = _arm_in_space(pose.right,torso_inverse)
	var left_arm = _arm_in_space(pose.left,torso_inverse)
	var shield_center: Vector2 = torso_inverse*pose.shield_center
	var far_arm: Dictionary = left_arm if facing==1 else right_arm
	var near_arm: Dictionary = right_arm if facing==1 else left_arm
	var far_side = "left" if facing==1 else "right"
	var near_side = "right" if facing==1 else "left"
	draw_set_transform_matrix(torso_transform)
	_draw_anatomical_arm(far_side,far_arm,Color(.70,.73,.76),true,true)
	var head_transform = torso_transform
	head_transform.x *= facing
	var head_fit = HeadFit.layout(fighter.stats)
	draw_set_transform_matrix(head_transform)
	HeadFit.draw_neck(self,head_fit)
	draw_set_transform_matrix(torso_transform)
	_draw_impact_torso()
	_draw_armor_detail()
	_draw_anatomical_arm(near_side,near_arm,Color.WHITE,true,true)
	# Shoulder caps overlap the rotating upper sleeves, closing the socket.
	_draw_shoulder_seal(right_arm,Color.WHITE if facing==1 else Color(.76,.79,.82))
	_draw_shoulder_seal(left_arm,Color(.76,.79,.82) if facing==1 else Color.WHITE)
	# The distant forearm can cross in front of the chest to reach its grip;
	# its upper arm remains behind the torso instead of painting over it.
	_draw_anatomical_arm(far_side,far_arm,Color(.78,.81,.84),false,true)
	draw_set_transform_matrix(head_transform)
	HeadFit.draw_neck(self,head_fit,true)
	var helmet_art = Art.descriptor(fighter.stats,"helmet")
	var head_box: Rect2 = head_fit.helmet
	if not helmet_art.is_empty() and Art.equipment_texture(fighter.stats,"helmet")!=null:
		if bool(helmet_art.get("open_face",false)):
			var appearance: Dictionary = fighter.stats.get("appearance",Face.Appearance.variant(hash(str(fighter.stats.get("armor_color",""))+str(fighter.stats.get("shield_color","")))))
			Face.draw_face(self,appearance,head_fit.face,head_fit.face_clip,false)
		draw_texture_rect(head_texture,head_box,false)
	elif head_tier==0:
		var appearance: Dictionary = fighter.stats.get("appearance",Face.Appearance.variant(hash(str(fighter.stats.get("armor_color",""))+str(fighter.stats.get("shield_color","")))))
		Face.draw_head(self,appearance,head_tier,Color(str(fighter.stats.get("helmet_color","8e999c"))),head_box)
	else:
		# Keep enclosed/gilt equipment intact; it naturally hides facial detail.
		draw_texture_rect(head_texture,head_box,false)
		if fighter.stats.has("helmet_color"):
			draw_line(Vector2(-20,-109),Vector2(20,-109),Color(str(fighter.stats.helmet_color)),3)
	draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))
	_draw_seated_leg(seated.near,Color.WHITE,true)
	var hand_local: Vector2 = (pose.right.hand-origin)*Vector2(facing,1)
	if detached_lance_visible:
		_draw_lance(hand_local,float(fighter.aim),Model.lance_length(fighter),bool(fighter.broken))
	draw_set_transform_matrix(torso_transform)
	_draw_grip("right",right_arm,Color.WHITE if facing==1 else Color(.83,.85,.88))
	# Left hand grips the rear handle. The shield face then occludes fingers
	# naturally; the independently drawn palm is visible around the inner rim.
	draw_line(left_arm.hand+Vector2(-3,-9),left_arm.hand+Vector2(-3,10),Color("30251e"),5)
	var brace_axis: Vector2 = (left_arm.hand-left_arm.elbow).normalized()
	var brace_side = Vector2(-brace_axis.y,brace_axis.x)
	var brace = left_arm.hand-brace_axis*14
	draw_line(brace-brace_side*8,brace+brace_side*8,Color("533925"),5)
	draw_line(brace-brace_side*7,brace+brace_side*7,Color("b08a4b"),2)
	_draw_grip("left",left_arm,Color(.86,.88,.90) if facing==1 else Color.WHITE)
	var shield_transform = torso_transform
	shield_transform.x *= facing
	draw_set_transform_matrix(shield_transform)
	_draw_shield(shield_center*Vector2(facing,1),design)
	draw_set_transform_matrix(torso_transform)
	for wound in fighter.get("wounds",[]):
		var mark = Vector2(-18,-125) if wound.zone=="head" else Vector2(-25,-50)
		draw_line(mark,mark+Vector2(10,12),Color("35352f"),2)
		if blood_enabled:
			var stain = Vector2(0,-106 if head_tier==0 else -84) if wound.zone=="head" else Vector2(-8,-48)
			for offset in [Vector2.ZERO,Vector2(7,7),Vector2(-4,13)]:
				draw_circle(stain+offset,2.5,Color("69251e"))
	draw_set_transform(Vector2.ZERO)

func _draw_flexible_horse_part(part: String, rectangle: Rect2, bend: float, tint: Color, head: bool) -> void:
	# Skin the existing texture along the neck/tail. The neck base stays in
	# the chest while the skull is rigid; tail tips lag progressively behind.
	var region: Rect2 = HorseArt.PARTS[part]
	for row in range(8):
		var vertices = PackedVector2Array()
		var uv = PackedVector2Array()
		for corner in [Vector2(0,row/8.0),Vector2(1,row/8.0),Vector2(1,(row+1)/8.0),Vector2(0,(row+1)/8.0)]:
			var point = rectangle.position+rectangle.size*corner
			var weight = maxf(smoothstep(15,-65,point.y),smoothstep(0,35,point.x)) if head else corner.y
			vertices.append(point.rotated(bend*weight))
			uv.append((region.position+region.size*corner)/HorseArt.ATLAS.get_size())
		draw_polygon(vertices,PackedColorArray([tint]),uv,HorseArt.ATLAS)

func _draw_horse_leg(index: int, tint: Color, _upper: bool = true, _lower: bool = true) -> void:
	if index not in [0,2]:
		return
	var pose = _horse_leg_pose(index)
	var skin = far_hind_skin if index==0 else far_fore_skin
	skin.update(Model.gait_pose(fighter),pose,pose)
	skin.draw(self,tint)

func _horse_leg_pose(index: int) -> Dictionary:
	var pose = Gait.leg(index,stride_phase,float(fighter.get("speed",210.0)),moving,float(fighter.stats.get("stability",1.0)),INF,Vector2.INF,float(fighter.get("motion_drive",0.0)))
	if leg_poses.size()==4:
		pose = leg_poses[index]
	return pose

func _draw_horse_upper(part: String, start: Vector2, middle: Vector2, end: Vector2, width: float, tint: Color) -> void:
	# One continuous muscle skin over shoulder/elbow or hip/stifle. Repeating
	# the complete upper-leg sprite twice produced round pasted-on joints.
	var region: Rect2 = HorseArt.PARTS[part]
	var joints: Array = HorseArt.JOINTS[part]
	# Root caps are buried in the body; exclude spare atlas pixels above them.
	var old_bottom = region.end.y
	region.position.y = joints[0].y-8
	region.size.y = old_bottom-region.position.y
	var split = start.distance_to(middle)/(start.distance_to(middle)+middle.distance_to(end))
	var first_axis = (middle-start).normalized()
	var second_axis = (end-middle).normalized()
	for row in range(12):
		var vertices = PackedVector2Array()
		var uv = PackedVector2Array()
		for corner in [Vector2(0,row/12.0),Vector2(1,row/12.0),Vector2(1,(row+1)/12.0),Vector2(0,(row+1)/12.0)]:
			var pixel = region.position+region.size*corner
			var t = (pixel.y-joints[0].y)/(joints[1].y-joints[0].y)
			var center = start.lerp(middle,t/split) if t<split else middle.lerp(end,(t-split)/(1-split))
			var tangent = first_axis.lerp(second_axis,smoothstep(split-.15,split+.15,t)).normalized()
			var transverse = pixel.x-lerpf(joints[0].x,joints[1].x,t)
			vertices.append(center+Vector2(tangent.y,-tangent.x)*transverse*width/float(HorseArt.WIDTHS[part]))
			uv.append(pixel/HorseArt.ATLAS.get_size())
		for triangle in [[0,1,2],[0,2,3]]:
			var points = PackedVector2Array([vertices[triangle[0]],vertices[triangle[1]],vertices[triangle[2]]])
			# A folded strip can briefly collapse to a line during idle breathing.
			# It has no visible surface and cannot be triangulated by the renderer.
			if triangle_has_area(points):
				draw_polygon(points,PackedColorArray([tint]),PackedVector2Array([uv[triangle[0]],uv[triangle[1]],uv[triangle[2]]]),HorseArt.ATLAS)

static func triangle_has_area(points: PackedVector2Array) -> bool:
	if points.size()!=3:
		return false
	for point in points:
		if not point.is_finite():
			return false
	return absf((points[1]-points[0]).cross(points[2]-points[0]))>.01

func _draw_horse_bone(part: String, start: Vector2, end: Vector2, width: float, tint: Color) -> void:
	# Map measured joint centers, not the rectangle corners, onto the bones.
	# This is what prevents detached knees/hooves when an atlas has padding.
	var region: Rect2 = HorseArt.PARTS[part]
	var joints: Array = HorseArt.JOINTS[part]
	var source_axis: Vector2 = (joints[1]-joints[0]).normalized()
	var source_side = Vector2(-source_axis.y,source_axis.x)
	var axis = (end-start).normalized()
	var side = Vector2(-axis.y,axis.x)
	var ratio = start.distance_to(end)/joints[0].distance_to(joints[1])
	# Transverse anatomy is independent of bone length. Short pasterns and
	# shoulder segments must not shrink into matchsticks as they articulate.
	var thickness = width/float(HorseArt.WIDTHS[part])
	var vertices = PackedVector2Array()
	var uv = PackedVector2Array()
	for corner in [region.position,Vector2(region.end.x,region.position.y),region.end,Vector2(region.position.x,region.end.y)]:
		var relative: Vector2 = corner-joints[0]
		vertices.append(start+axis*relative.dot(source_axis)*ratio+side*relative.dot(source_side)*thickness)
		uv.append(corner/HorseArt.ATLAS.get_size())
	draw_polygon(vertices,PackedColorArray([tint,tint,tint,tint]),uv,HorseArt.ATLAS)

static func seated_leg_pose(value: Dictionary) -> Dictionary:
	# Local side-view projection. Depth is supplied by draw order, not by
	# moving both thighs to the visible side. Pelvis stays on the saddle.
	var pivot = Model.HIP+Model.saddle_offset(value)
	var pitch = Model.gait_pose(value).pitch
	var result = {}
	for side in ["far","near"]:
		var far = side=="far"
		var hip = pivot+(Vector2(14,-8) if far else Vector2(-11,3))
		var knee = hip+(Vector2(21,24) if far else Vector2(23,29)).rotated(pitch*.3)
		var ankle = hip+(Vector2(10,78) if far else Vector2(7,82)).rotated(pitch*.15)
		result[side] = {"hip":hip,"knee":knee,"ankle":ankle,"foot":ankle+Vector2(17,8)}
	return result

func _draw_seated_leg(pose: Dictionary, tint: Color, near: bool) -> void:
	# Measured joints from the existing rider atlas; keep the decorative
	# thigh and boot, but give their knee a shared attachment.
	var strap_top: Vector2 = pose.hip+Vector2(-3,-1)
	var stirrup: Vector2 = pose.ankle+Vector2(9,11)
	var stirrup_tint = Color(tint,tint.a*stirrup_alpha)
	draw_line(strap_top,stirrup,Color("30261d")*stirrup_tint,4)
	draw_line(strap_top+Vector2(1,0),stirrup+Vector2(1,0),Color("805b34")*stirrup_tint,2)
	_draw_rider_leg_patch(Rect2(687,633,204,117),Vector2(749,663),Vector2(823,748),pose.hip,pose.knee,.30,tint)
	_draw_rider_leg_patch(Rect2(744,736,148,197),Vector2(823,748),Vector2(804,862),pose.knee,pose.ankle,.29,tint)
	_draw_leg_ornament(pose,tint)
	var loop = PackedVector2Array([stirrup+Vector2(-9,-7),stirrup+Vector2(-12,9),stirrup+Vector2(14,9),stirrup+Vector2(10,-7)])
	draw_polyline(loop,Color("242b2b")*stirrup_tint,4)
	draw_line(stirrup+Vector2(-10,8),stirrup+Vector2(12,8),Color("9b9d8d")*stirrup_tint,2)
	if near:
		draw_line(pose.hip+Vector2(-9,0),pose.hip+Vector2(9,4),Color("b38e47"),3)

func _draw_leg_ornament(pose: Dictionary, tint: Color) -> void:
	var pattern = int(fighter.stats.get("leg_decoration",0))
	if pattern==0:
		return
	var along: Vector2 = (pose.ankle-pose.knee).normalized()
	var across = Vector2(-along.y,along.x)
	var center: Vector2 = pose.knee+along*14.0
	var trim = Color("c5a366")*tint
	match pattern:
		1:
			for offset in [0.0,6.0]:
				draw_polyline(PackedVector2Array([center+along*offset-across*5,center+along*(offset+3),center+along*offset+across*5]),trim,1.5,false)
		2:
			draw_polyline(PackedVector2Array([center-along*5,center+across*4,center+along*5,center-across*4,center-along*5]),trim,1.5,false)
		3:
			draw_line(center-along*5,center+along*5,trim,2,false)
			draw_line(center-across*4,center+across*4,trim,2,false)
		4:
			for sign_value in [-1,1]:
				draw_line(center+along*5,center-along*4+across*4*sign_value,trim,1.5,false)

func _draw_rider_leg_patch(region: Rect2, source_a: Vector2, source_b: Vector2, a: Vector2, b: Vector2, thickness: float, tint: Color) -> void:
	var source_axis = (source_b-source_a).normalized()
	var source_side = Vector2(-source_axis.y,source_axis.x)
	var axis = (b-a).normalized()
	var side = Vector2(-axis.y,axis.x)
	var longitudinal = a.distance_to(b)/source_a.distance_to(source_b)
	var points = PackedVector2Array()
	var uv = PackedVector2Array()
	for corner in [region.position,Vector2(region.end.x,region.position.y),region.end,Vector2(region.position.x,region.end.y)]:
		var relative: Vector2 = corner-source_a
		points.append(a+axis*relative.dot(source_axis)*longitudinal+side*relative.dot(source_side)*thickness)
		uv.append(corner/ATLAS.get_size())
	draw_polygon(points,PackedColorArray([tint]),uv,ATLAS)

static func arm_pose(value: Dictionary) -> Dictionary:
	var facing = int(value.direction)
	var transform = Transform2D(Model.pose_angle(value)*facing,Model.mount_origin(value)+Model.HIP*Vector2(facing,1))
	var inverse = transform.affine_inverse()
	var right_hand: Vector2 = inverse*Model.hand_position(value)
	var shield_center: Vector2 = inverse*Model.shield_position(value)
	var left_hand = shield_center+Vector2(-10*facing,4)
	var result = {"torso_transform":transform,"shield_center":Model.shield_position(value),"shield_grip":transform*left_hand}
	for side in ["right","left"]:
		var shoulder = LANCE_SHOULDER if side=="right" else SHIELD_SHOULDER
		var hand = right_hand if side=="right" else left_hand
		var elbow = arm_elbow(shoulder,hand,ARM_UPPER,ARM_LOWER)
		result[side] = {"shoulder":transform*shoulder,"elbow":transform*elbow,"hand":transform*hand}
	return result

static func _arm_in_space(arm: Dictionary, inverse: Transform2D) -> Dictionary:
	return {"shoulder":inverse*arm.shoulder,"elbow":inverse*arm.elbow,"hand":inverse*arm.hand}

func _draw_shoulder_seal(arm: Dictionary, tint: Color) -> void:
	# Broad mail underlap covers the torso's baked arm socket while the
	# sleeve rotates. It stays on the shoulder, never drags the chest bitmap.
	var center: Vector2 = arm.shoulder
	var outward = -1.0 if center.x<0 else 1.0
	var contour = PackedVector2Array([center+Vector2(-outward*10,-11),center+Vector2(outward*8,-13),center+Vector2(outward*18,-5),center+Vector2(outward*18,9),center+Vector2(outward*8,14),center+Vector2(-outward*9,10)])
	draw_colored_polygon(contour,Color("343c40")*tint)
	draw_line(center+Vector2(outward*11,-5),center+Vector2(outward*11,8),Color("717b83")*tint,5)
	for row in range(3):
		for column in range(3):
			draw_rect(Rect2(center+Vector2(-6+column*6+(row%2)*2,-7+row*6),Vector2(3,2)),Color("929a9d")*tint)

func _draw_anatomical_arm(side: String, arm: Dictionary, tint: Color, upper: bool, lower: bool) -> void:
	if upper:
		ArmArt.draw_segment(self,side+"_upper",arm.shoulder,arm.elbow,30,tint)
	if lower:
		var wrist: Vector2 = arm.hand+(arm.elbow-arm.hand).normalized()*9
		# Mail underlap bridges elbow rotation; forearm and glove stay separate.
		draw_circle(arm.elbow,8.0,Color("555f68")*tint)
		ArmArt.draw_segment(self,side+"_forearm",arm.elbow,wrist,17,tint)

func _draw_grip(side: String, arm: Dictionary, tint: Color) -> void:
	var wrist: Vector2 = arm.hand+(arm.elbow-arm.hand).normalized()*9
	ArmArt.draw_segment(self,side+"_hand",wrist,arm.hand,12,tint)

static func arm_elbow(shoulder: Vector2, hand: Vector2, upper: float, lower: float) -> Vector2:
	var ray = hand-shoulder
	var distance = clampf(ray.length(),absf(upper-lower)+.01,upper+lower-.01)
	var angle = acos(clampf((upper*upper+distance*distance-lower*lower)/(2*upper*distance),-1,1))
	var a = shoulder+ray.normalized().rotated(angle)*upper
	var b = shoulder+ray.normalized().rotated(-angle)*upper
	# Elbow hangs below the direct reach, on either facing and torso angle.
	return a if a.y>b.y else b

static func lance_shoulder(facing: int) -> Vector2:
	return LANCE_SHOULDER*Vector2(facing,1)

static func shield_shoulder(facing: int) -> Vector2:
	return SHIELD_SHOULDER*Vector2(facing,1)

static func mirrored_transform(origin: Vector2, angle: float, facing: int) -> Transform2D:
	# Rotate in rider-local space, then reflect the complete pose. CanvasItem's
	# draw_set_transform scales the basis globally; also reversing its angle
	# reflected rotation twice, detaching the left-facing shield/shoulder.
	var mirror = Vector2(facing,1)
	return Transform2D(Vector2.RIGHT.rotated(angle)*mirror,Vector2.DOWN.rotated(angle)*mirror,origin*mirror)

func _draw_lance(hand: Vector2, angle: float, length: float, broken: bool) -> void:
	Lance.draw(self,fighter.stats,hand,angle,length,broken,lance_recoil,mode)

func _lance_surface_point(hand: Vector2, angle: float, length: float, broken: bool, distance: float) -> Vector2:
	return Lance.surface(hand,angle,distance,0,length,broken,lance_recoil)

func _draw_heraldry(center: Vector2, design: String) -> void:
	if design == "cross":
		draw_line(center+shield_projection(Vector2(-13,0)),center+shield_projection(Vector2(13,0)),Color("315c7e"),5)
		draw_line(center+shield_projection(Vector2(0,-23)),center+shield_projection(Vector2(0,22)),Color("315c7e"),4)
	elif design == "diamond":
		draw_colored_polygon(PackedVector2Array([center+shield_projection(Vector2(0,-18)),center+shield_projection(Vector2(12,0)),center+shield_projection(Vector2(0,18)),center+shield_projection(Vector2(-12,0))]),Color("332d23"))
	elif design == "chevron":
		draw_polyline(PackedVector2Array([center+shield_projection(Vector2(-16,10)),center+shield_projection(Vector2(0,-9)),center+shield_projection(Vector2(16,10))]),Color("eadfc1"),5)
	else:
		var direction = int(fighter.direction)
		draw_line(center+shield_projection(Vector2(-15*direction,-20)),center+shield_projection(Vector2(15*direction,20)),Color("e9d6a2"),6)

func _draw_shield(center: Vector2, design: String) -> void:
	if float(fighter.shield)<=0:
		return
	var ratio = float(fighter.shield)/float(fighter.stats.get("shield_capacity",78.0))
	var tint = Color.WHITE.darkened(.18 if ratio<.32 else 0).lerp(Color(1.5,1.5,1.25),maxf(0,shield_recoil)*.55)
	# A compressed, slanted face plus a visible wooden rear rim makes the
	# shield brace toward the opponent instead of reading as a screen decal.
	var base_outline = Shield.outline(str(fighter.stats.get("shield_shape","kite")))
	var back = PackedVector2Array()
	for point in base_outline:
		back.append(center+shield_projection(point)+Vector2(-7,3))
	draw_colored_polygon(back,Color("30251e"))
	var back_rim = back.duplicate()
	back_rim.append(back[0])
	draw_polyline(back_rim,Color("8a6240"),3)
	if fighter.stats.has("shield_shape"):
		var shape = str(fighter.stats.shield_shape)
		var outline = base_outline
		var outer = PackedVector2Array()
		var inner = PackedVector2Array()
		for point in outline:
			outer.append(center+shield_projection(point))
			inner.append(center+shield_projection(point*.87)+Vector2(-2.5,0)*shield_recoil)
		draw_colored_polygon(outer,Color("292b25"))
		draw_colored_polygon(inner,Color(str(fighter.stats.shield_color))*tint)
		var rim = inner.duplicate()
		rim.append(inner[0])
		draw_polyline(rim,Color("b89b56") if int(fighter.stats.shield_quality)>=3 else Color("887351"),3)
		for point in inner:
			draw_rect(Rect2(point-Vector2(1,1),Vector2(3,3)),Color("d2c8a6"))
	else:
		var face = PackedVector2Array()
		var uv = PackedVector2Array()
		for point in base_outline:
			face.append(center+shield_projection(point))
			uv.append((point+Vector2(40,52))/Vector2(80,104))
		draw_colored_polygon(face,Color("a64132" if red else "27568a")*tint)
		draw_polygon(face,PackedColorArray([tint]),uv,shield_texture)
		face.append(face[0])
		draw_polyline(face,Color("c5a568")*tint,3)
	_draw_heraldry(center+Vector2(-2.5,0)*shield_recoil,design)
	if ratio<.54:
		draw_polyline(PackedVector2Array([center+Vector2(-5,-27),center+Vector2(3,-9),center+Vector2(-4,7),center+Vector2(4,24)]),Color("302d28"),2,true)

static func shield_projection(point: Vector2) -> Vector2:
	return Shield.project(point)

func _torso_surface_point(point: Vector2) -> Vector2:
	# Small armour/cloth compression only. Neck, seat, shoulder sockets and
	# every rule anchor stay fixed; contact feedback cannot fake a dodge.
	var t = clampf((point.y+94.0)/104.0,0,1)
	return point+Vector2(-int(fighter.direction)*5.5*impact_recoil*sin(PI*t),0)

func _draw_impact_torso() -> void:
	for row in range(6):
		var points = PackedVector2Array()
		var uv = PackedVector2Array()
		for corner in [Vector2(0,row/6.0),Vector2(1,row/6.0),Vector2(1,(row+1)/6.0),Vector2(0,(row+1)/6.0)]:
			points.append(_torso_surface_point(Vector2(-47,-94)+corner*Vector2(94,104)))
			uv.append(corner)
		draw_polygon(points,PackedColorArray([Color.WHITE]),uv,torso_texture)

func _draw_armor_detail() -> void:
	if Art.equipment_texture(fighter.stats,"armor")!=null:
		# New plates/mail have their own structure; do not paint the old shared
		# coloured bib over every breastplate.
		return
	if not fighter.stats.has("armor_color"):
		return
	var color = Color(str(fighter.stats.armor_color))
	var quality = int(fighter.stats.get("armor_quality",0))
	var cloth = PackedVector2Array()
	for point in [Vector2(-25,-65),Vector2(16,-64),Vector2(25,-22),Vector2(-22,-19)]:
		cloth.append(_torso_surface_point(point))
	draw_colored_polygon(cloth,color.darkened(.15))
	draw_line(Vector2(-21,-61),Vector2(-18,-23),color.lightened(.25),3)
	if quality>=1:
		draw_line(Vector2(-20,-24),Vector2(20,-26),Color("c4ad70"),3)
	if quality>=2:
		for i in range(quality+1):
			draw_rect(Rect2(-17+i*6,-61,2,2),Color("d2c5a2"))
	if quality>=3:
		draw_polyline(PackedVector2Array([Vector2(-17,-53),Vector2(0,-40),Vector2(14,-54)]),Color("d1ba7e"),3)
	if quality==5:
		for x in [-14,0,14]:
			draw_line(Vector2(x,-36),Vector2(x+3,-30),Color("ecddaa"),2)
