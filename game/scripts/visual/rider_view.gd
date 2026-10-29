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
var fighter: Dictionary = {}
var red = false
var clock = 0.0
var moving = false
var blood_enabled = false
var mode = "arena"
var impact_recoil = 0.0
var lance_recoil = 0.0
var shield_recoil = 0.0
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

func _process(delta: float) -> void:
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
			var target_x = Gait.HIP_POINTS[index].x+(8 if leg_pose.front else -8)+float(leg_pose.reach)
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
	impact_recoil = move_toward(impact_recoil,0,delta*3)
	lance_recoil = move_toward(lance_recoil,0,delta*4)
	shield_recoil = move_toward(shield_recoil,0,delta*4)
	queue_redraw()
func draw_part(part: String, destination: Rect2, color: Color = Color.WHITE) -> void:
	draw_texture_rect_region(ATLAS,destination,PARTS[part],color)

func _draw() -> void:
	if fighter.is_empty():
		return
	var tier = int(fighter.stats.get("armor_tier",0))
	var head_tier = int(fighter.stats.get("helmet_tier",0))
	var design = str(fighter.stats.get("heraldry","bend"))
	var armor_red = bool(fighter.stats.get("armor_red",red))
	var next_key = "%d/%d/%s/%s/%s" % [tier,head_tier,design,armor_red,fighter.stats.get("gilt",false)]
	if next_key != art_key:
		art_key = next_key
		torso_texture = Art.torso(tier,armor_red)
		head_texture = Art.helmet(head_tier,bool(fighter.stats.get("gilt",false)))
		shield_texture = Art.shield(design)
	var facing = int(fighter.direction)
	draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))
	var stride = stride_phase
	var horse_pose = Gait.body(stride,float(fighter.get("speed",0.0)),moving,float(fighter.stats.get("stability",1.0)),float(fighter.get("motion_drive",0.0)))
	var horse_tint = Color(str(fighter.stats.get("horse_color","a87950"))).lerp(Color.WHITE,.48)
	_draw_horse_leg(0,horse_tint.darkened(.29))
	_draw_horse_leg(2,horse_tint.darkened(.25))
	_draw_horse_leg(1,horse_tint,true,false)
	_draw_horse_leg(3,horse_tint,true,false)
	var tail_root = Model.HIP+(Vector2(-134,-170)-Model.HIP).rotated(horse_pose.pitch)+horse_pose.offset
	draw_set_transform_matrix(mirrored_transform(tail_root,horse_pose.pitch,facing))
	_draw_flexible_horse_part("tail",Rect2(-78,-5,84,127),horse_pose.tail,horse_tint,false)
	var neck_root = Model.HIP+(Vector2(80,-124)-Model.HIP+horse_pose.neck_offset).rotated(horse_pose.pitch)+horse_pose.offset
	draw_set_transform_matrix(mirrored_transform(neck_root,horse_pose.pitch,facing))
	_draw_flexible_horse_part("head",Rect2(-31,-126,130,150),horse_pose.neck,horse_tint,true)
	draw_set_transform_matrix(mirrored_transform(Model.HIP+horse_pose.offset,horse_pose.pitch,facing))
	draw_texture_rect_region(HorseArt.ATLAS,Rect2(-137,-20,247,106),HorseArt.PARTS.body,horse_tint)
	draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))
	_draw_horse_leg(1,horse_tint,false,true)
	_draw_horse_leg(3,horse_tint,false,true)
	var muzzle = neck_root+Vector2(95,-31).rotated(horse_pose.pitch+horse_pose.neck)
	var rein_hand = ((Model.shield_position(fighter)-Vector2(fighter.x,fighter.get("lane_y",0)))*Vector2(facing,1))+Vector2(-10,4).rotated(Model.pose_angle(fighter))
	if fighter.get("ko",false) or fighter.get("dead",false):
		rein_hand = Model.HIP+Vector2(8,20)+horse_pose.offset
	draw_polyline(PackedVector2Array([muzzle,muzzle.lerp(rein_hand,.55)+Vector2(0,20),rein_hand]),Color("493628"),2.5,true)
	if bool(fighter.get("ko",false)) or bool(fighter.get("dead",false)):
		draw_set_transform(Vector2.ZERO)
		return
	var lean_angle = Model.pose_angle(fighter)
	var pivot = Model.HIP+Model.saddle_offset(fighter)
	_draw_rider_leg(pivot+Vector2(3,-1),-.05,Color(.65,.64,.61))
	# One camera-facing torso space carries anatomical shoulders, both arm
	# chains and the actual rule grips. Turning changes depth, not handedness.
	var origin = Vector2(float(fighter.x),float(fighter.get("lane_y",0.0)))
	var pose = arm_pose(fighter)
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
	draw_texture_rect(torso_texture,Rect2(-47,-94,94,104),false)
	_draw_armor_detail()
	_draw_shoulder_seal(right_arm,Color.WHITE if facing==1 else Color(.76,.79,.82))
	_draw_shoulder_seal(left_arm,Color(.76,.79,.82) if facing==1 else Color.WHITE)
	_draw_anatomical_arm(near_side,near_arm,Color.WHITE,true,true)
	# The distant forearm can cross in front of the chest to reach its grip;
	# its upper arm remains behind the torso instead of painting over it.
	_draw_anatomical_arm(far_side,far_arm,Color(.78,.81,.84),false,true)
	var head_transform = torso_transform
	head_transform.x *= facing
	draw_set_transform_matrix(head_transform)
	var head_width = 84.0 if head_tier==4 else 70.0
	draw_texture_rect(head_texture,Rect2(-head_width*.5,-151,head_width,80),false)
	if fighter.stats.has("helmet_color"):
		draw_line(Vector2(-20,-109),Vector2(20,-109),Color(str(fighter.stats.helmet_color)),3)
	draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))
	_draw_rider_leg(pivot+Vector2(-11,4),.07-horse_pose.pitch*.3,Color.WHITE)
	var hand_local: Vector2 = (pose.right.hand-origin)*Vector2(facing,1)
	_draw_lance(hand_local,float(fighter.aim),Model.lance_length(fighter),bool(fighter.broken))
	draw_set_transform_matrix(torso_transform)
	_draw_grip("right",right_arm,Color.WHITE if facing==1 else Color(.83,.85,.88))
	# Left hand grips the rear handle. The shield face then occludes fingers
	# naturally; the independently drawn palm is visible around the inner rim.
	draw_line(left_arm.hand+Vector2(-3,-9),left_arm.hand+Vector2(-3,10),Color("30251e"),5)
	_draw_grip("left",left_arm,Color(.86,.88,.90) if facing==1 else Color.WHITE)
	var shield_transform = torso_transform
	shield_transform.x *= facing
	draw_set_transform_matrix(shield_transform)
	_draw_shield(shield_center*Vector2(facing,1),design)
	draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))
	for wound in fighter.get("wounds",[]):
		var mark = Vector2(-18,-125) if wound.zone=="head" else Vector2(-25,-50)
		draw_line(pivot+mark.rotated(lean_angle),pivot+(mark+Vector2(10,12)).rotated(lean_angle),Color("35352f"),2)
		if blood_enabled:
			var stain = Vector2(0,-106 if head_tier==0 else -84) if wound.zone=="head" else Vector2(-8,-48)
			for offset in [Vector2.ZERO,Vector2(7,7),Vector2(-4,13)]:
				draw_circle(pivot+(stain+offset).rotated(lean_angle),2.5,Color("69251e"))
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

func _draw_horse_leg(index: int, tint: Color, upper: bool = true, lower: bool = true) -> void:
	var pose = Gait.leg(index,stride_phase,float(fighter.get("speed",210.0)),moving,float(fighter.stats.get("stability",1.0)),INF,Vector2.INF,float(fighter.get("motion_drive",0.0)))
	if leg_poses.size()==4:
		pose = leg_poses[index]
	var prefix = "fore" if pose.front else "hind"
	if upper:
		_draw_horse_upper(prefix+"_upper",pose.hip,pose.proximal,pose.knee,46 if pose.front else 65,tint)
	if not lower:
		return
	_draw_horse_bone(prefix+"_lower",pose.knee,pose.ankle,14 if pose.front else 16,tint)
	_draw_horse_bone(prefix+"_lower",pose.ankle,pose.foot,12,tint)
	var facing = int(fighter.direction)
	draw_set_transform_matrix(mirrored_transform(pose.foot,pose.toe_angle,facing))
	draw_texture_rect_region(HorseArt.ATLAS,Rect2(-11,-14,22,14),HorseArt.PARTS.hoof,tint)
	draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))

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

func _draw_rider_leg(hip: Vector2, angle: float, tint: Color) -> void:
	var facing = int(fighter.direction)
	draw_set_transform_matrix(mirrored_transform(hip,angle,facing))
	draw_part("rider_leg",Rect2(-22,-12,61,91),tint)
	draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))

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
	var contour = PackedVector2Array([center+Vector2(-12,-9),center+Vector2(outward*19,-5),center+Vector2(outward*18,13),center+Vector2(-outward*8,15)])
	draw_colored_polygon(contour,Color("343c40")*tint)
	draw_line(center+Vector2(outward*10,-4),center+Vector2(outward*10,11),Color("717b83")*tint,6)

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
	var direction = Vector2(cos(angle),sin(angle))
	var tip = hand+direction*length
	var butt = hand-direction*67
	var normal = Vector2(-direction.y,direction.x)
	var middle = hand.lerp(tip,.55)+normal*lance_recoil*10*(0 if broken else 1)
	var shaft = PackedVector2Array([butt,hand,middle,tip])
	var type = str(fighter.stats.get("lance_type","standard"))
	var width = 6.0 if type=="light" else (10.0 if type=="stout" else 8.0)
	draw_polyline(shaft,Color("302318"),width,true)
	draw_polyline(shaft,Color("bb8c50"),width-2.5,true)
	var highlight = PackedVector2Array()
	for point in shaft:
		highlight.append(point+Vector2(0,-1.5))
	draw_polyline(highlight,Color("dfbb76"),1.2,true)
	var quality = int(fighter.stats.get("lance_quality",0))
	if fighter.stats.has("lance_color"):
		var paint = Color(str(fighter.stats.lance_color))
		for band in range(quality+1):
			var mark = hand+direction*(25+band*14)
			if 25+band*14<length-26:
				draw_line(mark-normal*(width*.45),mark+normal*(width*.45),paint,5)
		if quality>=3:
			var guard = hand+direction*14
			draw_line(guard-normal*12,guard+normal*12,Color("383d3b"),7)
			draw_line(guard-normal*10,guard+normal*10,Color("bea05d"),3)
	if not broken:
		var facing = int(fighter.direction)
		draw_set_transform_matrix(mirrored_transform(tip,angle,facing))
		draw_part("point" if mode=="war" else "coronel",Rect2(-24,-7,24,14))
		# A small glint belongs to the weapon tip, not a floating aim cursor.
		draw_line(Vector2(-5,-3),Vector2(0,0),Color("fff1c4"),2)
		draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))
	else:
		draw_line(tip+Vector2(-3,-4),tip+Vector2(3,3),Color("ebd5a0"),2)

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
	var tint = Color.WHITE.darkened(.18 if ratio<.32 else 0).lerp(Color(2,2,1.5),shield_recoil*.55)
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
			inner.append(center+shield_projection(point*.87))
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
	_draw_heraldry(center,design)
	if ratio<.54:
		draw_polyline(PackedVector2Array([center+Vector2(-5,-27),center+Vector2(3,-9),center+Vector2(-4,7),center+Vector2(4,24)]),Color("302d28"),2,true)

static func shield_projection(point: Vector2) -> Vector2:
	return Shield.project(point)

func _draw_armor_detail() -> void:
	if not fighter.stats.has("armor_color"):
		return
	var color = Color(str(fighter.stats.armor_color))
	var quality = int(fighter.stats.get("armor_quality",0))
	var cloth = PackedVector2Array([Vector2(-25,-65),Vector2(16,-64),Vector2(25,-22),Vector2(-22,-19)])
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
