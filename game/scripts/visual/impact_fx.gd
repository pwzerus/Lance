class_name ImpactFX
extends Node2D
signal rider_landed(impact_speed: float)
const Shard = preload("res://scripts/visual/lance_shard.gd")
const Cues = preload("res://scripts/visual/combat_cues.gd")
const WindowActivity = preload("res://scripts/core/window_activity.gd")
const ShieldArt = preload("res://scripts/visual/shield_art.gd")
const ShieldGeometry = preload("res://scripts/core/shield_geometry.gd")
const Model = preload("res://scripts/core/joust_match.gd")

var particles: Array = []
var stains: Array = []
var bodies: Array = []
var blood_enabled = false
var bursts: Array = []
var debris: Array = []
var shield_fragments113: Array = []
var rng = RandomNumberGenerator.new()
var far_dust: Node2D

func _ready() -> void:
	rng.randomize()
	far_dust = Node2D.new()
	far_dust.z_index = -11 # Parent effects is +10; ground marks/dust stay below actors and rail.
	far_dust.draw.connect(_draw_far_dust)
	add_child(far_dust)

func clear_blood() -> void:
	stains.clear()
	particles = particles.filter(func(p): return not p.get("blood", false))
	# The pause menu can clear blood while _process is suspended. Invalidate
	# the ground canvas too, rather than retaining its cached stain geometry.
	if far_dust: far_dust.queue_redraw()
	queue_redraw()

func hit(point: Vector2, direction: int, damage: float, shield: bool, broke: bool, zone: String = "body", impulse_strength: float = .5, contact: Dictionary = {}) -> void:
	# The caller supplies strength from this actual contact. No anticipation
	# marker, target prediction, or blood setting creates a contact flash.
	var strength = clampf(impulse_strength,0.0,1.0) if is_finite(impulse_strength) else .5
	var duration = lerpf(.22,.36,strength)
	bursts.append({"p":point,"life":duration,"duration":duration,"shield":shield,
		"zone":"shield" if shield else zone,"direction":-1 if direction<0 else 1,
		"strength":strength,"size":lerpf(12.0,34.0,strength),"slide":shield and bool(contact.get("glanced",false)),"lever":float(contact.get("lever",0))})
	var blood = blood_enabled and not shield and damage > 11.0
	# Bounded contact fan: low-speed taps must not look like a full charge.
	for i in range(roundi(lerpf(5,15,strength))+(4 if broke else 0)):
		var velocity = Vector2(rng.randf_range(-150,150) + direction * 65, rng.randf_range(-165,-35))*lerpf(.45,1.25,strength)
		var color = Color("c89b55") if broke else Color("f4dda0")
		particles.append({"p": point, "v": velocity, "life": rng.randf_range(.35,.8), "color": color, "size": rng.randf_range(2,5), "blood": false})
	if blood:
		for i in range(12):
			particles.append({"p":point,"v":Vector2(direction*rng.randf_range(30,160),rng.randf_range(-100,5)),"life":rng.randf_range(.3,.7),"color":Color("8b2c24"),"size":rng.randf_range(2,4),"blood":true})
		stains.append({"p": Vector2(point.x,float(contact.get("defender_ground_y",12.0))+rng.randf_range(-2,8)), "radius": rng.randf_range(10,19)})
		if far_dust: far_dust.queue_redraw()
	queue_redraw()

func break_lance(event: Dictionary, mode: String, equipment: Dictionary = {}) -> void:
	var ray = Vector2(cos(float(event.break_angle))*int(event.break_direction),sin(float(event.break_angle)))
	var start = Vector2(event.break_hand)+ray*66
	var remaining = maxf(10,float(event.break_reach)-66)
	var direction = int(event.break_direction)
	var carry = Vector2(event.get("break_hand_velocity",Vector2(direction*float(event.get("attacker_speed",190.0)),0)))
	if not carry.is_finite(): carry = Vector2.ZERO
	carry = carry.limit_length(1100.0)
	var shaft_spin = clampf(float(event.get("break_angular_velocity",0.0)),-8.0,8.0)
	if not is_finite(shaft_spin): shaft_spin = 0.0
	var load = smoothstep(150.0,1000.0,float(event.get("speed",380.0)))
	# Real impact sheds momentum; this bounded visual approximation retains
	# charge/hand motion and rotational velocity, then adds a small fracture fan.
	# It does not feed back into damage, rider contacts or the rules RNG.
	var retention = lerpf(.92,.70,load)
	var cursor = 0.0
	for i in range(2):
		var length = remaining*(.56 if i==0 else .44)
		var body = RigidBody2D.new()
		body.position = start+ray*(cursor+length*.5)
		body.rotation = ray.angle()
		body.mass = .35
		body.collision_layer = 4
		body.collision_mask = 32 if int(event.break_direction)==1 else 16
		body.gravity_scale = 1.0
		body.z_index = -8 if int(event.break_direction)==1 else -10
		var center_offset = 66.0+cursor+length*.5
		var tangential = Vector2(-ray.y,ray.x)*shaft_spin*center_offset
		body.linear_velocity = ((carry+tangential)*retention+Vector2(direction*(-18.0 if i==0 else 18.0),-lerpf(32.0,100.0,load)-i*12.0)).limit_length(1250.0)
		body.angular_velocity = clampf(shaft_spin+direction*lerpf(1.2,4.8,load)*(-.8 if i==0 else 1.0),-12.0,12.0)
		var collider = CollisionShape2D.new()
		var rectangle = RectangleShape2D.new()
		rectangle.size = Vector2(length,6)
		collider.shape = rectangle
		body.add_child(collider)
		var sprite = Shard.new()
		sprite.length = length
		sprite.pointed = i==1
		sprite.war_tip = mode=="war"
		sprite.equipment = equipment.duplicate(true)
		sprite.source_start = 66.0+cursor
		sprite.full_length = float(event.break_reach)
		body.add_child(sprite)
		add_child(body)
		debris.append(body)
		cursor += length

func dust(point: Vector2, direction: int, pace: float = 0.0) -> void:
	pace = clampf(pace,0,1)
	for i in range(1+int(pace*3)):
		particles.append({"p": point, "v": Vector2(-direction*rng.randf_range(30,75)*(1+pace),-rng.randf_range(12,32)), "life": lerpf(.28,.48,pace),
			"color": Color(.70,.59,.39,lerpf(.24,.42,pace)), "size": rng.randf_range(3,6+pace*4), "blood": false, "dust":true,"floor":point.y+2,
			"trail":pace*pace*18.0,"direction":direction})

func break_shield(fighter: Dictionary, event: Dictionary) -> void:
	if not bool(event.get("shield_broke",false)):return
	var transform=Model.shield_transform(fighter)
	var field=Color(str(ShieldArt.ShieldArms.record(ShieldArt.device(fighter.stats)).field))
	var heading=int(fighter.direction)
	for polygon in ShieldArt.fracture_parts(fighter.stats):
		var world=PackedVector2Array();var center=Vector2.ZERO
		for point in polygon:
			var transformed=transform*ShieldGeometry.project(point)
			world.append(transformed);center+=transformed
		center/=world.size()
		for i in range(world.size()):world[i]-=center
		var outward=center-transform.origin
		var velocity=Vector2(heading*float(fighter.speed)*.8,0)+outward*3.0+Vector2(-heading*90,-70)
		shield_fragments113.append({"p":center,"v":velocity,"polygon":world,"angle":0.0,"spin":clampf(outward.x*.15,-5,5),"life":3.0,"ground":float(event.get("defender_ground_y",12)),"field":field})
	while shield_fragments113.size()>16:shield_fragments113.pop_front()

func fall(fighter: Dictionary, direction: int, event: Dictionary = {}, mounted: RiderView = null, shared: Dictionary = {}) -> void:
	# Capture the same skeleton, face, armor and hands used on horseback.
	fighter.unseated=true
	var fall_event = event.duplicate(true)
	fall_event.direction = direction
	var rider = preload("res://scripts/visual/fallen_rider.gd").new()
	rider.z_index = -8 if float(fighter.get("lane_y",0))>=0 else -10
	add_child(rider)
	rider.setup(fighter,fall_event,mounted,shared)
	rider.landed.connect(func(point: Vector2, force: float):
		dust(point,-direction,force)
		dust(point,direction,force)
		rider_landed.emit(rider.landing_speed))
	bodies.append(rider)

func falls_settled() -> bool:
	for body in bodies:
		if is_instance_valid(body) and not body.settled:
			return false
	return true

func _process(delta: float) -> void:
	if WindowActivity.suspended():
		return
	for burst in bursts:
		burst.life -= delta
	bursts = bursts.filter(func(b):return b.life>0)
	debris = debris.filter(func(b):return is_instance_valid(b))
	for piece in shield_fragments113:
		piece.life-=delta;piece.v.y+=900.0*delta;piece.p+=Vector2(piece.v)*delta;piece.angle+=float(piece.spin)*delta
		var low=-INF
		for point in piece.polygon:low=maxf(low,Vector2(point).rotated(float(piece.angle)).y)
		if float(piece.p.y)+low>float(piece.ground):
			piece.p.y=float(piece.ground)-low
			piece.v.y=-absf(float(piece.v.y))*.12 if absf(float(piece.v.y))>35 else 0.0
			piece.v.x*=exp(-10.0*delta);piece.spin*=exp(-14.0*delta)
	shield_fragments113=shield_fragments113.filter(func(piece):return piece.life>0)
	for particle in particles:
		particle.life -= delta
		particle.p += Vector2(particle.v) * delta
		particle.v.y += delta * (100.0 if particle.get("dust",false) else 380.0)
		if particle.get("dust",false) and particle.p.y>particle.floor:
			particle.p.y = particle.floor
			particle.v *= exp(-17.0*delta)
	particles = particles.filter(func(p): return p.life > 0.0)
	if far_dust:
		far_dust.queue_redraw()
	queue_redraw()

func _draw_far_dust() -> void:
	if WindowActivity.suspended():
		return
	if blood_enabled:
		for stain in stains:
			far_dust.draw_set_transform(stain.p,0,Vector2(1,.22))
			far_dust.draw_circle(Vector2.ZERO,stain.radius,Color(.31,.09,.07,.60))
		far_dust.draw_set_transform(Vector2.ZERO)
	for particle in particles:
		if particle.get("dust",false) and float(particle.floor)<0:
			var color = Color(particle.color)
			color.a *= clampf(float(particle.life)*3.0,0,1)
			_draw_dust_particle(far_dust,particle,color)

func _draw_dust_particle(canvas: Node2D, particle: Dictionary, color: Color) -> void:
	var point = Vector2(particle.p)
	var size = float(particle.size)
	canvas.draw_rect(Rect2(point,Vector2.ONE*size),color)
	# A short, grounded wake, emitted only by real hoof contacts. Both lanes
	# use the same helper; no screen-space speed lines or persistent nodes.
	var length = float(particle.get("trail",0))*clampf(float(particle.life)*3,0,1)
	if length>1.0:
		var start = point+Vector2(-length if int(particle.get("direction",1))>0 else size,size*.55)
		canvas.draw_rect(Rect2(start,Vector2(length,maxf(2,size*.35))),Color(color,color.a*.45))

func _draw() -> void:
	if WindowActivity.suspended():
		return
	for piece in shield_fragments113:
		var polygon=PackedVector2Array()
		for point in piece.polygon:polygon.append(Vector2(piece.p)+Vector2(point).rotated(float(piece.angle)))
		var alpha=clampf(float(piece.life)*2.0,0,1)
		draw_colored_polygon(polygon,Color(piece.field,alpha))
		polygon.append(polygon[0])
		draw_polyline(polygon,Color(Color("b58b55"),alpha),2.0)
	for burst in bursts:
		_draw_contact_burst(burst)
	for particle in particles:
		if particle.get("dust",false) and float(particle.floor)<0:
			continue
		var color = Color(particle.color)
		color.a *= clampf(float(particle.life) * 3.0,0,1)
		if particle.get("dust",false):
			_draw_dust_particle(self,particle,color)
		else:
			draw_rect(Rect2(Vector2(particle.p), Vector2.ONE * float(particle.size)), color)

func _draw_contact_burst(burst: Dictionary) -> void:
	# A small asymmetric star establishes the exact point, followed by a
	# short directional fan. Keep the defender readable: no expanding ring.
	var duration = float(burst.duration)
	var age = maxf(0.0,duration-float(burst.life))
	var t = clampf(age/duration,0.0,1.0)
	var point: Vector2 = burst.p
	var direction = int(burst.direction)
	var strength = float(burst.strength)
	var radius = float(burst.size)
	var zone_color = Color(Cues.COLORS.get(burst.zone,Cues.COLORS.body))
	if burst.get("slide",false):
		# A tangential scrape, not the same starburst as a braced shield punch.
		var tangent=Vector2(-direction*.35,1.0 if float(burst.get("lever",0))>=0 else -1.0).normalized()
		var alpha=pow(1.0-t,1.4)
		for i in range(3):
			var start=point+tangent*(t*30+i*6)+Vector2(direction*i*3,0)
			draw_line(start,start+tangent*(16.0-i*3),Color("8fcfe0",alpha),2.0)
		return
	var flash = 1.0-smoothstep(.035,.12,age)
	if flash>0.0:
		var size = radius*lerpf(.78,1.0,smoothstep(0.0,.05,age))
		var star = PackedVector2Array()
		for corner in [Vector2(-.56,0),Vector2(-.13,-.13),Vector2(0,-.64),Vector2(.18,-.16),
			Vector2(1.0,0),Vector2(.18,.16),Vector2(0,.64),Vector2(-.13,.13)]:
			star.append(point+corner*Vector2(direction,1)*size)
		draw_colored_polygon(star,Color(zone_color,flash*.92))
		var core = lerpf(4.0,7.0,strength)*flash
		draw_rect(Rect2(point-Vector2.ONE*core*.5,Vector2.ONE*core),Color(1.0,.98,.86,flash))
	# Blocked contacts throw sparks back along the incoming lance; an armor
	# hit carries the fan forward. This is visual direction only, not force.
	var scatter_direction = -direction if bool(burst.shield) else direction
	var fan_alpha = pow(1.0-t,1.5)
	var travel = lerpf(3.0,19.0,t)
	for i in range(5):
		var angle = lerpf(-.92,.92,float(i)/4.0)
		var ray = Vector2(cos(angle)*scatter_direction,sin(angle))
		var length = radius*(.30 if i in [0,4] else .48)*(1.0-t*.6)
		var start = point+ray*(6.0+travel)
		var end = start+ray*length
		draw_line(start,end,Color(zone_color,fan_alpha),3.0 if strength>.6 else 2.0)
