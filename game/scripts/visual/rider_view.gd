class_name RiderView
extends Node2D
signal hoof_contact(leg_index: int)

const ATLAS = preload("res://assets/art/pixel_v03/rider_atlas.png")
const Model = preload("res://scripts/core/joust_match.gd")
const Art = preload("res://scripts/visual/equipment_art.gd")
const HorseArt = preload("res://scripts/visual/horse_art.gd")
const Gait = preload("res://scripts/visual/horse_gait.gd")
const Shield = preload("res://scripts/core/shield_geometry.gd")
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
var last_feet: Array[Vector2] = [Vector2.INF,Vector2.INF,Vector2.INF,Vector2.INF]

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
	for index in range(4):
		var stability = float(fighter.get("stats",{}).get("stability",1.0))
		var drive = float(fighter.get("motion_drive",0.0))
		var leg_pose = Gait.leg(index,stride_phase,speed,moving,stability,INF,Vector2.INF,drive)
		var facing = int(fighter.get("direction",1))
		var cycle = float(leg_pose.cycle)
		if cycle<float(last_cycles[index])-.5 or not moving:
			planted_feet[index] = INF
			early_release[index] = false
			swing_starts[index] = Vector2.INF
		if moving and leg_pose.contact and not early_release[index]:
			if not is_finite(planted_feet[index]):
				planted_feet[index] = position.x+leg_pose.foot.x*facing
			leg_pose = Gait.leg(index,stride_phase,speed,true,stability,(planted_feet[index]-position.x)*facing,Vector2.INF,drive)
			if not leg_pose.contact:
				early_release[index] = true
				release_cycles[index] = cycle
		if moving and (not leg_pose.contact or early_release[index]):
			if is_finite(planted_feet[index]) or not swing_starts[index].is_finite():
				swing_starts[index] = last_feet[index] if last_feet[index].is_finite() else Vector2(position.x+leg_pose.foot.x*facing,leg_pose.foot.y)
				release_cycles[index] = cycle
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
			var foot = Vector2((lerpf(swing_starts[index].x,position.x+target_x*facing,protraction)-position.x)*facing,lerpf(swing_starts[index].y,Gait.GROUND,progress)+trajectory.y)
			leg_pose = Gait.leg(index,stride_phase,speed,true,stability,INF,foot,drive)
			leg_pose.contact = false
		if moving and leg_pose.contact and not previous_contacts[index]:
			landed.append(index)
		previous_contacts[index] = leg_pose.contact if moving else false
		last_cycles[index] = cycle
		last_feet[index] = Vector2(position.x+leg_pose.foot.x*facing,leg_pose.foot.y)
		leg_poses.append(leg_pose)
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
	var neck_root = Model.HIP+(Vector2(80,-124)-Model.HIP).rotated(horse_pose.pitch)+horse_pose.offset
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
	# Shared rule anchors keep the visible lance grip and shield on target.
	var origin = Vector2(float(fighter.x),float(fighter.get("lane_y",0.0)))
	var hand_local = (Model.hand_position(fighter)-origin)*Vector2(facing,1)
	var shoulder = pivot+lance_shoulder(facing).rotated(lean_angle)
	var elbow = arm_elbow(shoulder,hand_local,ARM_UPPER,ARM_LOWER)
	draw_set_transform_matrix(mirrored_transform(pivot,lean_angle,facing))
	var shield_center = ((Model.shield_position(fighter)-origin)*Vector2(facing,1)-pivot).rotated(-lean_angle)
	draw_texture_rect(torso_texture,Rect2(-47,-94,94,104),false)
	_draw_armor_detail()
	var head_width = 84.0 if head_tier==4 else 70.0
	draw_texture_rect(head_texture,Rect2(-head_width*.5,-151,head_width,80),false)
	if fighter.stats.has("helmet_color"):
		draw_line(Vector2(-20,-109),Vector2(20,-109),Color(str(fighter.stats.helmet_color)),3)
	# Chest faces the camera on both orientations: preserve anatomical hands
	# instead of mirroring right into left. Depth tint changes with the yaw.
	draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))
	_draw_rider_leg(pivot+Vector2(-11,4),.07-horse_pose.pitch*.3,Color.WHITE)
	_draw_arm(shoulder,elbow,hand_local,Color(.71,.74,.77) if facing==-1 else Color.WHITE)
	_draw_lance(hand_local,float(fighter.aim),Model.lance_length(fighter),bool(fighter.broken))
	draw_circle(hand_local,6,Color("795239"))
	draw_set_transform_matrix(mirrored_transform(pivot,lean_angle,facing))
	var shield_hand = shield_center+Vector2(-10,4)
	var shield_origin = shield_shoulder(facing)
	_draw_arm(shield_origin,arm_elbow(shield_origin,shield_hand,ARM_UPPER,ARM_LOWER),shield_hand,Color.WHITE if facing==-1 else Color(.81,.83,.85))
	_draw_shield(shield_center,design)
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
		_draw_horse_bone(prefix+"_upper",pose.hip,pose.knee,.70 if pose.front else .72,tint)
	if not lower:
		return
	_draw_horse_bone(prefix+"_lower",pose.knee,pose.ankle,.75,tint)
	var facing = int(fighter.direction)
	draw_set_transform_matrix(mirrored_transform(pose.foot,pose.toe_angle,facing))
	draw_texture_rect_region(HorseArt.ATLAS,Rect2(-11,-14,22,14),HorseArt.PARTS.hoof,tint)
	draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))

func _draw_horse_bone(part: String, start: Vector2, end: Vector2, width_scale: float, tint: Color) -> void:
	# Map measured joint centers, not the rectangle corners, onto the bones.
	# This is what prevents detached knees/hooves when an atlas has padding.
	var region: Rect2 = HorseArt.PARTS[part]
	var joints: Array = HorseArt.JOINTS[part]
	var source_axis: Vector2 = (joints[1]-joints[0]).normalized()
	var source_side = Vector2(-source_axis.y,source_axis.x)
	var axis = (end-start).normalized()
	var side = Vector2(-axis.y,axis.x)
	var ratio = start.distance_to(end)/joints[0].distance_to(joints[1])
	var vertices = PackedVector2Array()
	var uv = PackedVector2Array()
	for corner in [region.position,Vector2(region.end.x,region.position.y),region.end,Vector2(region.position.x,region.end.y)]:
		var relative: Vector2 = corner-joints[0]
		vertices.append(start+axis*relative.dot(source_axis)*ratio+side*relative.dot(source_side)*ratio*width_scale)
		uv.append(corner/HorseArt.ATLAS.get_size())
	draw_polygon(vertices,PackedColorArray([tint,tint,tint,tint]),uv,HorseArt.ATLAS)

func _draw_rider_leg(hip: Vector2, angle: float, tint: Color) -> void:
	var facing = int(fighter.direction)
	draw_set_transform_matrix(mirrored_transform(hip,angle,facing))
	draw_part("rider_leg",Rect2(-22,-12,61,91),tint)
	draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))

func _draw_arm(shoulder: Vector2, elbow: Vector2, hand: Vector2, tint: Color) -> void:
	# Measured opaque joints, not rectangle corners, meet at the IK elbow.
	draw_line(shoulder,elbow,Color("343c40")*tint,12)
	draw_line(elbow,hand,Color("343c40")*tint,10)
	_draw_arm_segment(Rect2(710,47,152,266),shoulder,elbow,19,true,tint)
	_draw_arm_segment(Rect2(943,155,284,119),elbow,hand,17,false,tint)
	draw_circle(hand,5,Color("795239"))

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

func _draw_arm_segment(source: Rect2, start: Vector2, end: Vector2, width: float, vertical: bool, tint: Color) -> void:
	var joint_a = Vector2(788,121) if vertical else Vector2(974,217)
	var joint_b = Vector2(776,280) if vertical else Vector2(1182,220)
	var source_axis = (joint_b-joint_a).normalized()
	var source_side = Vector2(-source_axis.y,source_axis.x)
	var axis = (end-start).normalized()
	var side = Vector2(-axis.y,axis.x)
	var ratio = start.distance_to(end)/joint_a.distance_to(joint_b)
	var thickness = width/(110.0 if vertical else 84.0)
	var points = PackedVector2Array()
	var uv = PackedVector2Array()
	for corner in [source.position,Vector2(source.end.x,source.position.y),source.end,Vector2(source.position.x,source.end.y)]:
		var relative: Vector2 = corner-joint_a
		points.append(start+axis*relative.dot(source_axis)*ratio+side*relative.dot(source_side)*thickness)
		uv.append(corner/ATLAS.get_size())
	draw_polygon(points,PackedColorArray([tint,tint,tint,tint]),uv,ATLAS)

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
