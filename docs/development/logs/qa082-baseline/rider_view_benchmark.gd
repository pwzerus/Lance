
extends Node2D
signal hoof_contact(leg_index: int)

const ATLAS = preload("res://assets/art/pixel_v03/rider_atlas.png")
const WindowActivity = preload("res://scripts/core/window_activity.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const Art = preload("res://scripts/visual/equipment_art.gd")
const HorseArt = preload("res://scripts/visual/horse_art.gd")
const Gait = preload("res://scripts/visual/horse_gait.gd")
const Condition = preload("res://scripts/core/horse_condition.gd")
const ShieldArt = preload("res://scripts/visual/shield_art.gd")
const Shield = preload("res://scripts/core/shield_geometry.gd")
const ContactCues = preload("res://scripts/visual/combat_cues.gd")
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
var contact_mark: Dictionary = {}
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
var horse_coat_key = ""
var far_hind_skin: RefCounted
var far_fore_skin: RefCounted

func _init() -> void:
	var pixel_material = ShaderMaterial.new()
	pixel_material.shader = PIXEL_SHADER
	material = pixel_material

func _process(delta: float) -> void:
	if WindowActivity.suspended():
		return
	if not contact_mark.is_empty():
		contact_mark.age += maxf(0.0,delta)
		if contact_mark.age>.62:
			contact_mark.clear()
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
				release_cycles[index] = cycle if leg_pose.nominal_contact else minf(cycle,float(leg_pose.duty))
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
	impact_velocity = minf(impact_velocity+clampf(strength,0,1)*(30.0 if on_shield else 52.0),60.0)
	if on_shield:
		shield_velocity = minf(shield_velocity+clampf(strength,0,1)*48.0,56.0)

func receive_lance_contact(strength: float) -> void:
	lance_velocity = minf(lance_velocity+clampf(strength,0,1)*40.0,46.0)

func receive_contact(event: Dictionary) -> void:
	var zone = str(event.zone)
	var pose = arm_pose(fighter)
	var surface: Transform2D = Model.shield_transform(fighter) if zone=="shield" else (head_transform(pose,fighter) if zone=="head" else pose.torso_transform)
	contact_mark = {"zone":zone,"age":0.0,"local":Vector2(event.get("contact_local",Vector2.ZERO)) if zone=="shield" else surface.affine_inverse()*Vector2(event.position),
		"color":ContactCues.contact_color(event),"rim":event.get("shield_region","")=="rim"}

func _draw_contact_trace(pose: Dictionary, origin: Vector2) -> void:
	# A confirmed surface mark, never a prediction. Follow the struck part
	# through its continuous recoil instead of leaving the cue on the track.
	if contact_mark.is_empty() or not detached_pose.is_empty(): return
	var zone = str(contact_mark.zone)
	var surface: Transform2D = Model.shield_transform(fighter) if zone=="shield" else (head_transform(pose,fighter) if zone=="head" else pose.torso_transform)
	surface.origin -= origin
	draw_set_transform_matrix(surface)
	var point: Vector2 = contact_mark.local
	var alpha = 1.0-smoothstep(.24,.62,float(contact_mark.age))
	var color = Color(contact_mark.color,alpha)
	# Four short broken strokes leave the actual contact visible.
	for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
		draw_line(point+direction*4,point+direction*10,Color(.08,.10,.09,alpha),5)
		draw_line(point+direction*4,point+direction*10,color,2.5)
	if zone=="shield":
		var outline = Shield.polygon(str(fighter.stats.get("shield_shape","kite")))
		var nearest = 0
		var distance = INF
		for i in range(outline.size()):
			var candidate = Geometry2D.get_closest_point_to_segment(point,outline[i],outline[(i+1)%outline.size()]).distance_squared_to(point)
			if candidate<distance:
				distance = candidate
				nearest = i
		var a = outline[nearest]
		var b = outline[(nearest+1)%outline.size()]
		var along = (b-a).normalized()
		var spot = Geometry2D.get_closest_point_to_segment(point,a,b)
		draw_line(spot-along*minf(12,spot.distance_to(a)),spot+along*minf(12,spot.distance_to(b)),color,3)

func draw_part(part: String, destination: Rect2, color: Color = Color.WHITE) -> void:
	draw_texture_rect_region(ATLAS,destination,PARTS[part],color)

func _draw() -> void:
	# A redraw queued just before minimization must also be discarded.
	if WindowActivity.suspended():
		return
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
	var horse_pose = Gait.body(stride,float(fighter.get("speed",0.0)),moving,float(fighter.stats.get("stability",1.0)),float(fighter.get("motion_drive",0.0)),Condition.fatigue(float(fighter.get("stamina",100.0))))
	var cloth_style = str(fighter.stats.get("caparison_style","none"))
	# EQUIP-067: facing left mirrors the horse; the bend uses a pre-mirrored
	# cloth so it stays dexter chief to sinister base on screen.
	var cloth_design = design+("_l" if design=="bend" and int(fighter.direction)<0 else "")
	var coat_key = str(fighter.stats.get("horse_coat","bay"))+"/"+cloth_style+"/"+cloth_design
	if horse_coat_key!=coat_key:
		var coat_name = str(fighter.stats.get("horse_coat","bay"))
		for skin in [horse_skin,far_hind_skin,far_fore_skin]:
			skin.set_coat(coat_name)
			# EQUIP-066: the caparison bears the rider's arms.
			skin.set_caparison(cloth_style,cloth_design)
		horse_coat_key=coat_key
	# Independent coat textures carry markings; do not tint the saddle/white socks.
	var horse_tint = Color.WHITE
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
	var rein_hand = (Model.shield_grip(fighter)-Vector2(fighter.x,fighter.get("lane_y",0)))*Vector2(facing,1)
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
	var far_arm: Dictionary = left_arm if facing==1 else right_arm
	var near_arm: Dictionary = right_arm if facing==1 else left_arm
	var far_side = "left" if facing==1 else "right"
	var near_side = "right" if facing==1 else "left"
	draw_set_transform_matrix(torso_transform)
	_draw_anatomical_arm(far_side,far_arm,Color(.70,.73,.76),true,true)
	var head_fit = HeadFit.layout(fighter.stats)
	var head_draw_transform = head_transform(pose,fighter)
	head_draw_transform.origin -= origin
	var appearance: Dictionary = fighter.stats.get("appearance",Face.Appearance.variant(hash(str(fighter.stats.get("armor_color",""))+str(fighter.stats.get("shield_color","")))))
	draw_set_transform_matrix(torso_transform)
	_draw_pose_neck(pose,head_fit,appearance,facing)
	_draw_impact_torso()
	_draw_armor_detail()
	_draw_anatomical_arm(near_side,near_arm,Color.WHITE,true,true)
	# Shoulder caps overlap the rotating upper sleeves, closing the socket.
	_draw_shoulder_seal(right_arm,Color.WHITE if facing==1 else Color(.76,.79,.82))
	_draw_shoulder_seal(left_arm,Color(.76,.79,.82) if facing==1 else Color.WHITE)
	# The distant forearm can cross in front of the chest to reach its grip;
	# its upper arm remains behind the torso instead of painting over it.
	_draw_anatomical_arm(far_side,far_arm,Color(.78,.81,.84),false,true)
	# The rear handle runs across the chest but behind the head/neck. Drawing
	# the whole lance after the face made it pass through both faces on lean.
	var hand_local: Vector2 = (pose.right.hand-origin)*Vector2(facing,1)
	if detached_lance_visible:
		draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))
		_draw_lance(hand_local,float(fighter.aim),Model.lance_length(fighter),bool(fighter.broken),Lance.Layer.REAR)
	draw_set_transform_matrix(torso_transform)
	_draw_pose_neck(pose,head_fit,appearance,facing)
	HeadFit.draw_collar_lip(self,head_fit,torso_texture,_torso_surface_point)
	draw_set_transform_matrix(head_draw_transform)
	var helmet_art = Art.descriptor(fighter.stats,"helmet")
	var head_box: Rect2 = head_fit.helmet
	if not helmet_art.is_empty() and head_texture!=null:
		if bool(helmet_art.get("open_face",false)):
			Face.draw_face(self,appearance,head_fit.face,head_fit.face_clip,false)
		draw_texture_rect(head_texture,head_box,false)
	elif head_tier==0:
		Face.draw_head(self,appearance,head_tier,Color(str(fighter.stats.get("helmet_color","8e999c"))),head_box)
	else:
		# Keep enclosed/gilt equipment intact; it naturally hides facial detail.
		draw_texture_rect(head_texture,head_box,false)
		if fighter.stats.has("helmet_color"):
			draw_line(Vector2(-20,-109),Vector2(20,-109),Color(str(fighter.stats.helmet_color)),3)
	draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))
	_draw_seated_leg(seated.near,Color.WHITE,true)
	if detached_lance_visible:
		_draw_lance(hand_local,float(fighter.aim),Model.lance_length(fighter),bool(fighter.broken),Lance.Layer.FRONT)
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
	shield_transform = shield_transform*Transform2D(float(fighter.get("shield_twist",0.0)),Vector2.ZERO)
	shield_transform.origin = pose.shield_center-origin
	draw_set_transform_matrix(shield_transform)
	_draw_shield(Vector2.ZERO,design)
	draw_set_transform_matrix(torso_transform)
	for wound in fighter.get("wounds",[]):
		var mark = Vector2(-18,-125) if wound.zone=="head" else Vector2(-25,-50)
		draw_line(mark,mark+Vector2(10,12),Color("35352f"),2)
		if blood_enabled:
			var stain = Vector2(0,-106 if head_tier==0 else -84) if wound.zone=="head" else Vector2(-8,-48)
			for offset in [Vector2.ZERO,Vector2(7,7),Vector2(-4,13)]:
				draw_circle(stain+offset,2.5,Color("69251e"))
	_draw_contact_trace(pose,origin)
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
	if leg_poses.size()==4:
		return leg_poses[index]
	# _process already solved and planted all four legs. Only solve here when
	# drawing before the first process tick; do not discard a fresh IK solve.
	return Gait.leg(index,stride_phase,float(fighter.get("speed",210.0)),moving,float(fighter.stats.get("stability",1.0)),INF,Vector2.INF,float(fighter.get("motion_drive",0.0)))

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
	# moving both thighs to the visible side.
	# RIDER-064: the hip rides with the rider (seat lag, impact shift) while
	# the foot stands in a stirrup hung from the SADDLE, which moves with the
	# horse. A two-bone knee solves between them with the measured thigh and
	# shin lengths, so the legs absorb the stride instead of moving as one
	# block with the seat. At rest every joint equals the former fixed pose.
	var body = Model.gait_pose(value)
	var pitch = float(body.pitch)
	var pivot = Model.HIP+Model.saddle_offset(value)
	var saddle = Model.HIP+Vector2(body.offset)
	var speed = float(value.get("speed",0.0))
	var phase = float(value.get("gait_phase",0.0))
	var w = Gait.weights(speed)
	var run = w.z+w.w
	var activity = smoothstep(0,85,speed) if bool(value.get("gait_moving",false)) else 0.0
	var lean = clampf(float(value.get("lean",0.0)),-1.0,1.0)
	var result = {}
	var reaction_slide = clampf(float(value.get("reaction_shift",0.0)),-6.0,6.0)
	for side in ["far","near"]:
		var far = side=="far"
		var hip_offset = Vector2(14,-8) if far else Vector2(-11,3)
		var rest_knee = Vector2(21,24) if far else Vector2(23,29)
		var rest_ankle = Vector2(10,78) if far else Vector2(7,82)
		var hip = pivot+hip_offset
		hip.x += reaction_slide
		# The stirrup leather swings a little behind the stride; bracing in a
		# lean pushes the feet forward (more when leaning back) and heels down.
		var swing = Vector2(-sin(phase-1.1+(.35 if far else 0.0))*(1.4*w.y+2.8*run),
			cos(phase-1.1)*(.5*w.y+.9*run))*activity
		var brace = Vector2((3.0 if lean>0.0 else 8.0)*absf(lean),-1.5*absf(lean))
		var ankle = saddle+(hip_offset+rest_ankle).rotated(pitch*.6)+swing+brace
		var thigh = rest_knee.length()
		var shin = (rest_ankle-rest_knee).length()
		var reach = ankle-hip
		var distance = clampf(reach.length(),absf(thigh-shin)+.5,thigh+shin-.5)
		ankle = hip+reach.normalized()*distance
		var bend = acos(clampf((thigh*thigh+distance*distance-shin*shin)/(2.0*thigh*distance),-1.0,1.0))
		# Knee in front of the hip-ankle line, the branch of the measured rest pose.
		var knee = hip+reach.normalized().rotated(-bend)*thigh
		var bar = saddle+(hip_offset+Vector2(-3,-1)).rotated(pitch)
		result[side] = {"hip":hip,"knee":knee,"ankle":ankle,"foot":ankle+Vector2(17,8).rotated(pitch*.6),"bar":bar}
	return result

func _draw_seated_leg(pose: Dictionary, tint: Color, near: bool) -> void:
	# Measured joints from the existing rider atlas; keep the decorative
	# thigh and boot, but give their knee a shared attachment.
	# The leather hangs from the saddle bar, not from the rider's moving seat.
	var strap_top: Vector2 = pose.get("bar",pose.hip+Vector2(-3,-1))
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
	var transform = Transform2D(Model.pose_angle(value)*facing,Model.rider_origin(value))
	var inverse = transform.affine_inverse()
	var right_hand: Vector2 = inverse*Model.hand_position(value)
	var left_hand: Vector2 = inverse*Model.shield_grip(value)
	var result = {"torso_transform":transform,"shield_center":Model.shield_position(value),"shield_grip":transform*left_hand}
	for side in ["right","left"]:
		var shoulder = LANCE_SHOULDER if side=="right" else SHIELD_SHOULDER
		var hand = right_hand if side=="right" else left_hand
		var elbow = arm_elbow(shoulder,hand,ARM_UPPER,ARM_LOWER)
		result[side] = {"shoulder":transform*shoulder,"elbow":transform*elbow,"hand":transform*hand}
	return result

static func _head_hinge(pose: Dictionary, value: Dictionary) -> Transform2D:
	# Detached neck articulation only; mounted head/target follows the core
	# reaction pose. The default is precisely the previous head registration.
	var angle = clampf(float(pose.get("head_rotation",0.0)),-.2,.2)
	var fit = HeadFit.layout(value.stats)
	var pivot = Vector2(float(fit.collar.center[0]),float(fit.collar.center[1])+2.0)
	var hinge = Transform2D(angle,Vector2.ZERO)
	hinge.origin = pivot-hinge.basis_xform(pivot)
	if not pose.has("head_rotation"):
		# RIDER-064, mounted only: the head keeps ~30% of a deliberate lean out
		# of its orientation so the rider keeps looking at the opponent. It
		# turns about the model's head anchor (torso-local 0,-111), so the
		# visible helmet stays on the head hit target; the neck bridge stretches.
		var lean = float(value.get("lean",0.0))
		var lean_angle = lean*(deg_to_rad(25.0) if lean>=0.0 else deg_to_rad(45.0))
		var counter = Transform2D((-.30*lean_angle+float(value.get("reaction_neck",0.0)))*int(value.get("direction",1)),Vector2.ZERO)
		var anchor = Vector2(0,-111)
		counter.origin = anchor-counter.basis_xform(anchor)
		hinge = counter*hinge
	return hinge

static func head_transform(pose: Dictionary, value: Dictionary) -> Transform2D:
	var torso: Transform2D = pose.torso_transform
	var fit = HeadFit.layout(value.stats)
	var local = Transform2D(Vector2(float(value.direction),0),Vector2.DOWN,Vector2(float(fit.head_offset),0))
	return torso*_head_hinge(pose,value)*local

static func neck_geometry(pose: Dictionary, value: Dictionary) -> Dictionary:
	# A short continuous bridge: jaw end follows the head, root stays buried
	# inside the original breastplate collar. Coordinates remain torso-local.
	var fit = HeadFit.layout(value.stats)
	var facing = int(value.direction)
	var base = Vector2(float(fit.collar.center[0]),float(fit.collar.center[1])+2.0)
	var face: Rect2 = fit.face
	var top = Vector2((face.position.x+face.size.x*.515-3.0)*facing+float(fit.head_offset),face.position.y+face.size.y*.69)
	var neck_half = face.size.x*.14
	if not bool(fit.open):
		top = Vector2(float(fit.neck_x)*facing+float(fit.head_offset),-101)
		neck_half = 8.0
	top.y = minf(top.y,base.y-6.0)
	var hinge = _head_hinge(pose,value)
	return {"base":base,"top":hinge*top,"across":hinge.basis_xform(Vector2.RIGHT),
		"down":hinge.basis_xform(Vector2.DOWN),"half":neck_half,"collar_half":float(fit.collar.width)*.5,"open":bool(fit.open)}

func _draw_pose_neck(pose: Dictionary, fit: Dictionary, appearance: Dictionary, facing: int) -> void:
	if _head_hinge(pose,fighter).is_equal_approx(Transform2D.IDENTITY):
		HeadFit.draw_neck(self,fit,appearance,facing)
		return
	var neck = neck_geometry(pose,fighter)
	var top: Vector2 = neck.top
	var base: Vector2 = neck.base
	var across: Vector2 = neck.across
	var down: Vector2 = neck.down
	var half = float(neck.half)
	var width = float(neck.collar_half)
	var skin: Color = Face.SKIN[Face.Appearance.sanitize(appearance).skin]
	var material_color = skin.darkened(.17) if neck.open else Color("51595d")
	var shadow = skin.darkened(.39) if neck.open else Color("353d42")
	draw_colored_polygon(PackedVector2Array([top-across*(half+1)-down*3,top+across*(half+1)-down*3,base+Vector2(width-3,-4),base+Vector2(width,0),base+Vector2(-width,0),base+Vector2(-width+3,-4)]),Color("302a28"))
	draw_colored_polygon(PackedVector2Array([top-across*half-down*3,top+across*half-down*3,base+Vector2(width-4,-4),base+Vector2(width-2,-1),base+Vector2(-width+2,-1),base+Vector2(-width+4,-4)]),material_color)
	draw_colored_polygon(PackedVector2Array([top-across*half-down*2,top-across*(half-4)-down*2,base+Vector2(-width+6,-1),base+Vector2(-width+2,-1)]),shadow)
	draw_line(top-across*half-down,top+across*half-down,shadow,2)

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

func _draw_lance(hand: Vector2, angle: float, length: float, broken: bool, layer: int = Lance.Layer.WHOLE) -> void:
	Lance.draw(self,fighter.stats,hand,angle,length,broken,lance_recoil,mode,layer)

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
		# Shared with the armoury icon. EQUIP-066: the crest's arms (field and
		# clipped charge) are painted by ShieldArt; quality shows as build.
		ShieldArt.draw(self,fighter.stats,center,true,tint,shield_recoil,1.0,int(fighter.direction))
		if ratio<.54:
			draw_polyline(PackedVector2Array([center+Vector2(-5,-27),center+Vector2(3,-9),center+Vector2(-4,7),center+Vector2(4,24)]),Color("302d28"),2,true)
		return
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
	# Shared Model reaction now carries the rider/head/arms and colliders.
	# Only a restrained cloth/plate flex remains; a bending chest bitmap is
	# no longer the entire impact response or a substitute for moving joints.
	var t = clampf((point.y+94.0)/104.0,0,1)
	return point+Vector2(-int(fighter.direction)*1.5*clampf(impact_recoil,-1,1)*sin(PI*t),0)

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
