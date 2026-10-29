class_name ImpactFX
extends Node2D
const Art = preload("res://scripts/visual/equipment_art.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const Shard = preload("res://scripts/visual/lance_shard.gd")
const Cues = preload("res://scripts/visual/combat_cues.gd")
const Face = preload("res://scripts/visual/character_face.gd")

class FallenHead extends Node2D:
	var stats: Dictionary = {}
	var facing = 1
	func _draw() -> void:
		var tier = int(stats.get("helmet_tier",0))
		var width = 84.0 if tier==4 else 70.0
		var rectangle = Rect2(-width*.5,-40,width,80)
		draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))
		if tier==0:
			var appearance: Dictionary = stats.get("appearance",Face.Appearance.variant(hash(str(stats.get("armor_color",""))+str(stats.get("shield_color","")))))
			Face.draw_head(self,appearance,tier,Color(str(stats.get("helmet_color","8e999c"))),rectangle)
		else:
			draw_texture_rect(Art.helmet(tier,bool(stats.get("gilt",false))),rectangle,false)

var particles: Array = []
var stains: Array = []
var bodies: Array = []
var blood_enabled = false
var bursts: Array = []
var debris: Array = []
var rng = RandomNumberGenerator.new()
var far_dust: Node2D

func _ready() -> void:
	rng.randomize()
	far_dust = Node2D.new()
	far_dust.z_index = -11 # Parent effects is +10; far dust belongs behind rail +1.
	far_dust.draw.connect(_draw_far_dust)
	add_child(far_dust)

func clear_blood() -> void:
	stains.clear()
	particles = particles.filter(func(p): return not p.get("blood", false))
	queue_redraw()

func hit(point: Vector2, direction: int, damage: float, shield: bool, broke: bool, zone: String = "body", impulse_strength: float = .5) -> void:
	# The caller supplies strength from this actual contact. No anticipation
	# marker, target prediction, or blood setting creates a contact flash.
	var strength = clampf(impulse_strength,0.0,1.0) if is_finite(impulse_strength) else .5
	var duration = lerpf(.28,.36,strength)
	bursts.append({"p":point,"life":duration,"duration":duration,"shield":shield,
		"zone":"shield" if shield else zone,"direction":-1 if direction<0 else 1,
		"strength":strength,"size":lerpf(18.0,28.0,strength)})
	var blood = blood_enabled and not shield and damage > 11.0
	for i in range(18 if broke else 11):
		var velocity = Vector2(rng.randf_range(-150,150) + direction * 65, rng.randf_range(-165,-35))
		var color = Color("c89b55") if broke else Color("f4dda0")
		particles.append({"p": point, "v": velocity, "life": rng.randf_range(.35,.8), "color": color, "size": rng.randf_range(2,5), "blood": false})
	if blood:
		for i in range(12):
			particles.append({"p":point,"v":Vector2(direction*rng.randf_range(30,160),rng.randf_range(-100,5)),"life":rng.randf_range(.3,.7),"color":Color("8b2c24"),"size":rng.randf_range(2,4),"blood":true})
		stains.append({"p": Vector2(point.x, rng.randf_range(-2,8)), "radius": rng.randf_range(10,19)})
	queue_redraw()

func break_lance(event: Dictionary, mode: String) -> void:
	var ray = Vector2(cos(float(event.break_angle))*int(event.break_direction),sin(float(event.break_angle)))
	var start = Vector2(event.break_hand)+ray*66
	var remaining = maxf(10,float(event.break_reach)-66)
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
		body.linear_velocity = Vector2(int(event.break_direction)*(190+i*55),-125-i*45)
		body.angular_velocity = int(event.break_direction)*(-3.0 if i==0 else 5.0)
		var collider = CollisionShape2D.new()
		var rectangle = RectangleShape2D.new()
		rectangle.size = Vector2(length,6)
		collider.shape = rectangle
		body.add_child(collider)
		var sprite = Shard.new()
		sprite.length = length
		sprite.pointed = i==1
		sprite.war_tip = mode=="war"
		body.add_child(sprite)
		add_child(body)
		debris.append(body)
		cursor += length

func dust(point: Vector2, direction: int, pace: float = 0.0) -> void:
	for i in range(1+int(pace*3)):
		particles.append({"p": point, "v": Vector2(-direction*rng.randf_range(30,75)*(1+pace),-rng.randf_range(12,32)), "life": lerpf(.28,.48,pace),
			"color": Color(.70,.59,.39,lerpf(.24,.42,pace)), "size": rng.randf_range(3,6+pace*4), "blood": false, "dust":true,"floor":point.y+2})

func fall(fighter: Dictionary, direction: int) -> void:
	# Independent ragdoll pieces use RigidBody2D and PinJoint2D; horses continue on their own lanes.
	var origin = Model.body_position(fighter)
	var pieces: Array = []
	for info in [{"o":Vector2(0,0),"s":Vector2(78,94)},
		{"o":Vector2(0,-67),"s":Vector2(58,68)},
		{"o":Vector2(-40,4),"s":Vector2(18,56)},
		{"o":Vector2(40,5),"s":Vector2(18,56)},
		{"o":Vector2(-19,91),"s":Vector2(24,77)},
		{"o":Vector2(19,91),"s":Vector2(24,77)}]:
		var body = RigidBody2D.new()
		var facing = int(fighter.direction)
		var pose_rotation = Model.pose_angle(fighter)*facing
		body.position = origin + (Vector2(info.o)*Vector2(facing,1)).rotated(pose_rotation)
		body.rotation = pose_rotation
		body.z_index = -8 if float(fighter.get("lane_y",0))>=0 else -10
		body.mass = 3.0 if pieces.is_empty() else 1.0
		body.collision_layer = 4
		body.collision_mask = 32 if float(fighter.get("lane_y",0))>=0 else 16
		body.gravity_scale = 1.1
		body.linear_velocity = Vector2(direction * 170, -95)
		body.angular_velocity = rng.randf_range(-3.5,3.5)
		var collision = CollisionShape2D.new()
		var rectangle = RectangleShape2D.new()
		rectangle.size = info.s
		collision.shape = rectangle
		body.add_child(collision)
		var part_index = pieces.size()
		var sprite: Node2D
		var texture = Art.torso(int(fighter.stats.get("armor_tier",0)),bool(fighter.stats.get("armor_red",fighter.get("red",false))))
		if part_index == 1:
			# Preserve the mounted rider's actual face/helmet at impact. The old
			# ragdoll swapped a nasal-helmet pixel face for the original AI head.
			sprite = FallenHead.new()
			sprite.stats = fighter.stats.duplicate(true)
			sprite.facing = facing
		elif part_index in [2,3]:
			texture = Art.region(Art.BASE,Rect2(710,47,152,266))
		elif part_index in [4,5]:
			texture = Art.region(Art.BASE,Rect2(687,633,204,288))
		if part_index!=1:
			sprite = Sprite2D.new()
			sprite.texture = texture
			sprite.scale = Vector2(info.s) / texture.get_size()
			sprite.flip_h = facing==-1
		body.add_child(sprite)
		add_child(body)
		pieces.append(body)
		bodies.append(body)
	for index in range(1,pieces.size()):
		var joint = PinJoint2D.new()
		joint.position = (pieces[0].position + pieces[index].position) * .5
		add_child(joint)
		joint.node_a = joint.get_path_to(pieces[0])
		joint.node_b = joint.get_path_to(pieces[index])
		joint.disable_collision = true
		joint.softness = .35

func _process(delta: float) -> void:
	for burst in bursts:
		burst.life -= delta
	bursts = bursts.filter(func(b):return b.life>0)
	debris = debris.filter(func(b):return is_instance_valid(b))
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
	for particle in particles:
		if particle.get("dust",false) and float(particle.floor)<0:
			var color = Color(particle.color)
			color.a *= clampf(float(particle.life)*3.0,0,1)
			far_dust.draw_rect(Rect2(Vector2(particle.p),Vector2.ONE*float(particle.size)),color)

func _draw() -> void:
	for burst in bursts:
		_draw_contact_burst(burst)
	if blood_enabled:
		for stain in stains:
			draw_set_transform(stain.p, 0, Vector2(1,.22))
			draw_circle(Vector2.ZERO, stain.radius, Color(.31,.09,.07,.60))
		draw_set_transform(Vector2.ZERO)
	for particle in particles:
		if particle.get("dust",false) and float(particle.floor)<0:
			continue
		var color = Color(particle.color)
		color.a *= clampf(float(particle.life) * 3.0,0,1)
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
