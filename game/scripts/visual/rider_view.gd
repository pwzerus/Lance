class_name RiderView
extends Node2D

const ATLAS = preload("res://assets/art/rider_atlas.png")
const Model = preload("res://scripts/core/joust_match.gd")
const Art = preload("res://scripts/visual/equipment_art.gd")
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

func _process(delta: float) -> void:
	clock += delta
	var pace = clampf((float(fighter.get("speed",210.0))-Model.TROT_SPEED)/(Model.GALLOP_SPEED-Model.TROT_SPEED),0,1)
	stride_phase += delta*lerpf(8.0,18.0,pace) if moving else delta*1.2
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
	var bounce = sin(stride*2)*(lerpf(1.8,4.0,pace) if moving else .6)
	var horse_tint = Color(str(fighter.stats.get("horse_color","a87950"))).lerp(Color.WHITE,.72)
	_draw_horse_leg(Vector2(-96,-61),stride+PI,Color(.60,.57,.55))
	_draw_horse_leg(Vector2(65,-65),stride+lerpf(0.0,3.7,pace),Color(.62,.59,.56))
	draw_part("horse_body",Rect2(-160,-191+bounce,257,166),horse_tint)
	draw_part("horse_head",Rect2(61,-222+bounce,148,145),horse_tint)
	_draw_horse_leg(Vector2(-105,-65),stride,horse_tint)
	_draw_horse_leg(Vector2(63,-63),stride+lerpf(PI,3.0,pace),horse_tint)
	draw_polyline(PackedVector2Array([Vector2(168,-126+bounce),Vector2(65,-156),Vector2(2,-200)]),Color("493628"),2.5,true)
	if bool(fighter.get("ko",false)) or bool(fighter.get("dead",false)):
		draw_set_transform(Vector2.ZERO)
		return
	var lean_angle = Model.pose_angle(fighter)-impact_recoil*.22
	var pivot = Model.HIP+Vector2(0,bounce)
	_draw_rider_leg(pivot+Vector2(3,-1),-.05,Color(.65,.64,.61))
	# Shared rule anchors keep the visible lance grip and shield on target.
	var hand_local = (Model.hand_position(fighter)-Vector2(float(fighter.x),0))*Vector2(facing,1)
	var shoulder = pivot+Vector2(34 if facing==1 else -34,-65).rotated(lean_angle)
	var elbow = pivot+Vector2(49 if facing==1 else -48,-25).rotated(lean_angle)
	draw_set_transform(pivot*Vector2(facing,1),lean_angle*facing,Vector2(facing,1))
	var shield_center = ((Model.shield_position(fighter)-Vector2(float(fighter.x),0))*Vector2(facing,1)-pivot).rotated(-lean_angle)
	draw_texture_rect(torso_texture,Rect2(-47,-94,94,104),false)
	var head_width = 84.0 if head_tier==4 else 70.0
	draw_texture_rect(head_texture,Rect2(-head_width*.5,-151,head_width,80),false)
	# Both elbows have their own visible silhouette. A far arm remains darker
	# but is not completely buried under the chest sprite. Shield projects
	# forward of the torso on either facing, matching its actual hit circle.
	_draw_arm(Vector2(-34 if facing==1 else 34,-67),Vector2(-53 if facing==1 else 64,-19),shield_center+Vector2(-12,14),Color.WHITE if facing==1 else Color(.76,.78,.78))
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

func _draw_horse_leg(hip: Vector2, phase: float, tint: Color) -> void:
	var facing = int(fighter.direction)
	var cycle = fposmod(phase/TAU,1.0)
	var foot = Vector2(hip.x,12)
	if moving:
		if cycle<.58:
			foot.x += lerpf(37,-37,cycle/.58)
		else:
			var swing = (cycle-.58)/.42
			foot.x += lerpf(-37,37,swing)
			foot.y -= sin(swing*PI)*35
	var to_foot = foot-hip
	var length = clampf(to_foot.length(),15,95.5)
	var bend = acos(clampf((51.0*51.0+length*length-45.0*45.0)/(2.0*51.0*length),-1,1))
	var knee = hip+to_foot.normalized().rotated(bend*(-1 if hip.x>0 else 1))*51
	var upper_angle = (knee-hip).angle()-PI*.5
	var lower_angle = (foot-knee).angle()-PI*.5
	draw_set_transform(hip*Vector2(facing,1),upper_angle*facing,Vector2(facing,1))
	draw_part("horse_upper",Rect2(-16,-6,31,61),tint)
	draw_set_transform(knee*Vector2(facing,1),lower_angle*facing,Vector2(facing,1))
	draw_part("horse_lower",Rect2(-11,-4,25,53),tint)
	draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))

func _draw_rider_leg(hip: Vector2, angle: float, tint: Color) -> void:
	var facing = int(fighter.direction)
	draw_set_transform(hip*Vector2(facing,1),angle*facing,Vector2(facing,1))
	draw_part("rider_leg",Rect2(-22,-12,61,91),tint)
	draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))

func _draw_arm(shoulder: Vector2, elbow: Vector2, hand: Vector2, tint: Color) -> void:
	_draw_arm_segment(Rect2(710,47,152,266),shoulder,elbow,19,true,tint)
	_draw_arm_segment(Rect2(943,155,284,119),elbow,hand,18,false,tint)
	draw_circle(hand,8,Color("795239"))

func _draw_arm_segment(source: Rect2, start: Vector2, end: Vector2, width: float, vertical: bool, tint: Color) -> void:
	var direction = (end-start).normalized()
	var side = Vector2(-direction.y,direction.x)*width*.5
	var first = start-direction*5
	var last = end+direction*5
	var points = PackedVector2Array([first-side,first+side,last+side,last-side]) if vertical else PackedVector2Array([first-side,last-side,last+side,first+side])
	var extent = ATLAS.get_size()
	var a = source.position/extent
	var b = source.end/extent
	var uv = PackedVector2Array([a,Vector2(b.x,a.y),b,Vector2(a.x,b.y)])
	draw_polygon(points,PackedColorArray([tint,tint,tint,tint]),uv,ATLAS)

func _draw_lance(hand: Vector2, angle: float, length: float, broken: bool) -> void:
	var direction = Vector2(cos(angle),sin(angle))
	var tip = hand+direction*length
	var butt = hand-direction*67
	var normal = Vector2(-direction.y,direction.x)
	var middle = hand.lerp(tip,.55)+normal*lance_recoil*10*(0 if broken else 1)
	var shaft = PackedVector2Array([butt,hand,middle,tip])
	draw_polyline(shaft,Color("302318"),8,true)
	draw_polyline(shaft,Color("bb8c50"),5.5,true)
	var highlight = PackedVector2Array()
	for point in shaft:
		highlight.append(point+Vector2(0,-1.5))
	draw_polyline(highlight,Color("dfbb76"),1.2,true)
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
	var tint = Color.WHITE.darkened(.18 if float(fighter.shield)<25 else 0).lerp(Color(2,2,1.5),shield_recoil*.55)
	draw_texture_rect(shield_texture,Rect2(center-Vector2(40,52),Vector2(80,104)),false,tint)
	_draw_heraldry(center,design)
	if float(fighter.shield)<42:
		draw_polyline(PackedVector2Array([center+Vector2(-5,-27),center+Vector2(3,-9),center+Vector2(-4,7),center+Vector2(4,24)]),Color("302d28"),2,true)
