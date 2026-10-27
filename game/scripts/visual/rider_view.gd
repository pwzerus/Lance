class_name RiderView
extends Node2D
signal hoof_contact(leg_index: int)

const ATLAS = preload("res://assets/art/pixel_v03/rider_atlas.png")
const Model = preload("res://scripts/core/joust_match.gd")
const Art = preload("res://scripts/visual/equipment_art.gd")
const HorseArt = preload("res://scripts/visual/horse_art.gd")
const Gait = preload("res://scripts/visual/horse_gait.gd")
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
var torso_texture: Texture2D
var head_texture: Texture2D
var shield_texture: Texture2D
var art_key = ""
var planted_feet: Array[float] = [INF,INF,INF,INF]
var leg_poses: Array[Dictionary] = []

func _process(delta: float) -> void:
	clock += delta
	var speed = float(fighter.get("speed",210.0))
	var previous_phase = stride_phase
	if fighter.has("gait_phase") and not preview:
		stride_phase = float(fighter.gait_phase)
	else:
		stride_phase += delta*TAU*Gait.frequency(speed) if moving else delta*1.2
		if preview:
			fighter.gait_phase = stride_phase
			fighter.gait_moving = moving
	leg_poses.clear()
	for index in range(4):
		var leg_pose = Gait.leg(index,stride_phase,speed,moving,float(fighter.get("stats",{}).get("stability",1.0)))
		if moving and leg_pose.contact:
			if not is_finite(planted_feet[index]):
				planted_feet[index] = position.x+leg_pose.foot.x*int(fighter.direction)
			leg_pose = Gait.leg(index,stride_phase,speed,moving,float(fighter.stats.get("stability",1.0)),(planted_feet[index]-position.x)*int(fighter.direction))
		else:
			planted_feet[index] = INF
		leg_poses.append(leg_pose)
	if moving and delta>0 and delta<.2:
		for leg_index in Gait.touchdown_indices(previous_phase,stride_phase,speed):
			hoof_contact.emit(leg_index)
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
	var pace = clampf((float(fighter.get("speed",210.0))-Model.TROT_SPEED)/(Model.GALLOP_SPEED-Model.TROT_SPEED),0,1)
	var horse_pose = Gait.body(stride,pace,moving,float(fighter.stats.get("stability",1.0)))
	var bounce = float(horse_pose.offset.y)
	var horse_tint = Color(str(fighter.stats.get("horse_color","a87950"))).lerp(Color.WHITE,.48)
	_draw_horse_leg(0,horse_tint.darkened(.29))
	_draw_horse_leg(2,horse_tint.darkened(.25))
	var tail_root = Model.HIP+(Vector2(-134,-170)-Model.HIP).rotated(horse_pose.pitch)+horse_pose.offset
	draw_set_transform(tail_root*Vector2(facing,1),(horse_pose.pitch+horse_pose.tail)*facing,Vector2(facing,1))
	draw_texture_rect_region(HorseArt.ATLAS,Rect2(-78,-5,84,127),HorseArt.PARTS.tail,horse_tint)
	var neck_root = Model.HIP+(Vector2(80,-124)-Model.HIP).rotated(horse_pose.pitch)+horse_pose.offset
	draw_set_transform(neck_root*Vector2(facing,1),(horse_pose.pitch+horse_pose.neck)*facing,Vector2(facing,1))
	draw_texture_rect_region(HorseArt.ATLAS,Rect2(-31,-126,130,150),HorseArt.PARTS.head,horse_tint)
	draw_set_transform((Model.HIP+horse_pose.offset)*Vector2(facing,1),horse_pose.pitch*facing,Vector2(facing,1))
	draw_texture_rect_region(HorseArt.ATLAS,Rect2(-137,-20,247,106),HorseArt.PARTS.body,horse_tint)
	draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))
	_draw_horse_leg(1,horse_tint)
	_draw_horse_leg(3,horse_tint)
	var muzzle = neck_root+Vector2(95,-31).rotated(horse_pose.pitch+horse_pose.neck)
	draw_polyline(PackedVector2Array([muzzle,Vector2(65,-163+bounce),Vector2(2,-200)]),Color("493628"),2.5,true)
	if bool(fighter.get("ko",false)) or bool(fighter.get("dead",false)):
		draw_set_transform(Vector2.ZERO)
		return
	var lean_angle = Model.pose_angle(fighter)
	var pivot = Model.HIP+Vector2(0,bounce)
	_draw_rider_leg(pivot+Vector2(3,-1),-.05,Color(.65,.64,.61))
	# Shared rule anchors keep the visible lance grip and shield on target.
	var origin = Vector2(float(fighter.x),float(fighter.get("lane_y",0.0)))
	var hand_local = (Model.hand_position(fighter)-origin)*Vector2(facing,1)
	var shoulder = pivot+Vector2(26,-65).rotated(lean_angle)
	var elbow = arm_elbow(shoulder,hand_local,38,42)
	draw_set_transform(pivot*Vector2(facing,1),lean_angle*facing,Vector2(facing,1))
	var shield_center = ((Model.shield_position(fighter)-origin)*Vector2(facing,1)-pivot).rotated(-lean_angle)
	draw_texture_rect(torso_texture,Rect2(-47,-94,94,104),false)
	_draw_armor_detail()
	var head_width = 84.0 if head_tier==4 else 70.0
	draw_texture_rect(head_texture,Rect2(-head_width*.5,-151,head_width,80),false)
	if fighter.stats.has("helmet_color"):
		draw_line(Vector2(-20,-109),Vector2(20,-109),Color(str(fighter.stats.helmet_color)),3)
	# Both elbows have their own visible silhouette. A far arm remains darker
	# but is not completely buried under the chest sprite. Shield projects
	# forward of the torso on either facing, matching its actual hit circle.
	var shield_shoulder = Vector2(-28,-64)
	var shield_hand = shield_center+Vector2(-10,9)
	_draw_arm(shield_shoulder,arm_elbow(shield_shoulder,shield_hand,47,53),shield_hand,Color(.76,.78,.78))
	_draw_shield(shield_center,design)
	draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))
	_draw_rider_leg(pivot+Vector2(-11,4),.07,Color.WHITE)
	_draw_arm(shoulder,elbow,hand_local,Color(.84,.86,.86) if facing==1 else Color.WHITE)
	_draw_lance(hand_local,float(fighter.aim),Model.lance_length(fighter),bool(fighter.broken))
	draw_circle(hand_local,6,Color("795239"))
	for wound in fighter.get("wounds",[]):
		var mark = Vector2(-18,-125) if wound.zone=="head" else Vector2(-25,-50)
		draw_line(pivot+mark.rotated(lean_angle),pivot+(mark+Vector2(10,12)).rotated(lean_angle),Color("35352f"),2)
		if blood_enabled:
			var stain = Vector2(0,-106 if head_tier==0 else -84) if wound.zone=="head" else Vector2(-8,-48)
			for offset in [Vector2.ZERO,Vector2(7,7),Vector2(-4,13)]:
				draw_circle(pivot+(stain+offset).rotated(lean_angle),2.5,Color("69251e"))
	draw_set_transform(Vector2.ZERO)

func _draw_horse_leg(index: int, tint: Color) -> void:
	var pose = Gait.leg(index,stride_phase,float(fighter.get("speed",210.0)),moving,float(fighter.stats.get("stability",1.0)))
	if leg_poses.size()==4:
		pose = leg_poses[index]
	var prefix = "fore" if pose.front else "hind"
	_draw_horse_bone(prefix+"_upper",pose.hip,pose.knee,.70 if pose.front else .72,tint)
	_draw_horse_bone(prefix+"_lower",pose.knee,pose.ankle,.75,tint)
	var facing = int(fighter.direction)
	draw_set_transform(pose.ankle*Vector2(facing,1),pose.toe_angle*facing,Vector2(facing,1))
	draw_texture_rect_region(HorseArt.ATLAS,Rect2(-8,-2,22,14),HorseArt.PARTS.hoof,tint)
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
	draw_set_transform(hip*Vector2(facing,1),angle*facing,Vector2(facing,1))
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
		draw_set_transform(tip*Vector2(facing,1),angle*facing,Vector2(facing,1))
		draw_part("point" if mode=="war" else "coronel",Rect2(-24,-7,24,14))
		# A small glint belongs to the weapon tip, not a floating aim cursor.
		draw_line(Vector2(-5,-3),Vector2(0,0),Color("fff1c4"),2)
		draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))
	else:
		draw_line(tip+Vector2(-3,-4),tip+Vector2(3,3),Color("ebd5a0"),2)

func _draw_heraldry(center: Vector2, design: String) -> void:
	if design == "cross":
		draw_line(center+Vector2(-13,0),center+Vector2(13,0),Color("315c7e"),6,true)
		draw_line(center+Vector2(0,-23),center+Vector2(0,22),Color("315c7e"),6,true)
	elif design == "diamond":
		draw_colored_polygon(PackedVector2Array([center+Vector2(0,-18),center+Vector2(12,0),center+Vector2(0,18),center+Vector2(-12,0)]),Color("332d23"))
	elif design == "chevron":
		draw_polyline(PackedVector2Array([center+Vector2(-16,10),center+Vector2(0,-9),center+Vector2(16,10)]),Color("eadfc1"),6,true)
	else:
		var direction = int(fighter.direction)
		draw_line(center+Vector2(-15*direction,-20),center+Vector2(15*direction,20),Color("e9d6a2"),7,true)

func _draw_shield(center: Vector2, design: String) -> void:
	if float(fighter.shield)<=0:
		return
	var ratio = float(fighter.shield)/float(fighter.stats.get("shield_capacity",78.0))
	var tint = Color.WHITE.darkened(.18 if ratio<.32 else 0).lerp(Color(2,2,1.5),shield_recoil*.55)
	if fighter.stats.has("shield_shape"):
		var shape = str(fighter.stats.shield_shape)
		var outline = PackedVector2Array([Vector2(-31,-46),Vector2(29,-48),Vector2(36,-29),Vector2(21,24),Vector2(0,51),Vector2(-28,17)])
		if shape=="heater":
			outline = PackedVector2Array([Vector2(-37,-43),Vector2(35,-43),Vector2(32,15),Vector2(0,49),Vector2(-33,15)])
		elif shape=="targe":
			outline = PackedVector2Array([Vector2(-36,-43),Vector2(16,-43),Vector2(17,-28),Vector2(35,-24),Vector2(36,28),Vector2(5,44),Vector2(-34,32)])
		var outer = PackedVector2Array()
		var inner = PackedVector2Array()
		for point in outline:
			outer.append(center+point)
			inner.append(center+point*.87)
		draw_colored_polygon(outer,Color("292b25"))
		draw_colored_polygon(inner,Color(str(fighter.stats.shield_color))*tint)
		var rim = inner.duplicate()
		rim.append(inner[0])
		draw_polyline(rim,Color("b89b56") if int(fighter.stats.shield_quality)>=3 else Color("887351"),3)
		for point in inner:
			draw_rect(Rect2(point-Vector2(1,1),Vector2(3,3)),Color("d2c8a6"))
	else:
		draw_texture_rect(shield_texture,Rect2(center-Vector2(40,52),Vector2(80,104)),false,tint)
	_draw_heraldry(center,design)
	if ratio<.54:
		draw_polyline(PackedVector2Array([center+Vector2(-5,-27),center+Vector2(3,-9),center+Vector2(-4,7),center+Vector2(4,24)]),Color("302d28"),2,true)

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
