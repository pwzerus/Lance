class_name ImpactFX
extends Node2D
const Art = preload("res://scripts/visual/equipment_art.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const Shard = preload("res://scripts/visual/lance_shard.gd")

var particles: Array = []
var stains: Array = []
var bodies: Array = []
var blood_enabled = false
var bursts: Array = []
var debris: Array = []
var rng = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

func clear_blood() -> void:
	stains.clear()
	particles = particles.filter(func(p): return not p.get("blood", false))
	queue_redraw()

func hit(point: Vector2, direction: int, damage: float, shield: bool, broke: bool) -> void:
	bursts.append({"p":point,"life":.26,"shield":shield,"size":clampf(13+damage*.38,16,34)})
	var blood = blood_enabled and not shield and damage > 11.0
	for i in range(18 if broke else 11):
		var velocity = Vector2(rng.randf_range(-150,150) + direction * 65, rng.randf_range(-165,-35))
		var color = Color("c89b55") if broke else Color("f4dda0")
		particles.append({"p": point, "v": velocity, "life": rng.randf_range(.35,.8), "color": color, "size": rng.randf_range(2,5), "blood": false})
	if blood:
		for i in range(12):
			particles.append({"p":point,"v":Vector2(direction*rng.randf_range(30,160),rng.randf_range(-100,5)),"life":rng.randf_range(.3,.7),"color":Color("8b2c24"),"size":rng.randf_range(2,4),"blood":true})
		stains.append({"p": Vector2(point.x, rng.randf_range(-2,8)), "radius": rng.randf_range(10,19)})

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

func dust(point: Vector2, direction: int) -> void:
	particles.append({"p": point, "v": Vector2(-direction * rng.randf_range(25,65), -rng.randf_range(8,25)), "life": .42,
		"color": Color(.70,.59,.39,.24), "size": rng.randf_range(3,7), "blood": false})

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
		var sprite = Sprite2D.new()
		var part_index = pieces.size()
		var texture = Art.torso(int(fighter.stats.get("armor_tier",0)),bool(fighter.stats.get("armor_red",fighter.get("red",false))))
		if part_index == 1:
			texture = Art.helmet(int(fighter.stats.get("helmet_tier",0)),bool(fighter.stats.get("gilt",false)))
		elif part_index in [2,3]:
			texture = Art.region(Art.BASE,Rect2(710,47,152,266))
		elif part_index in [4,5]:
			texture = Art.region(Art.BASE,Rect2(687,633,204,288))
		sprite.texture = texture
		sprite.scale = Vector2(info.s) / texture.get_size()
		sprite.flip_h = int(fighter.direction)==-1
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
		particle.v.y += delta * 380.0
	particles = particles.filter(func(p): return p.life > 0.0)
	queue_redraw()

func _draw() -> void:
	for burst in bursts:
		var alpha = clampf(float(burst.life)/.20,0,1)
		var radius = float(burst.size)*(1.2-float(burst.life))
		var color = Color(1,.88,.55,alpha) if burst.shield else Color(1,.94,.78,alpha)
		for i in range(8):
			var ray = Vector2.from_angle(i*TAU/8)
			draw_line(Vector2(burst.p)+ray*radius*.25,Vector2(burst.p)+ray*radius,color,3)
		draw_circle(burst.p,3.5,Color(1,1,.9,alpha))
	if blood_enabled:
		for stain in stains:
			draw_set_transform(stain.p, 0, Vector2(1,.22))
			draw_circle(Vector2.ZERO, stain.radius, Color(.31,.09,.07,.60))
		draw_set_transform(Vector2.ZERO)
	for particle in particles:
		var color = Color(particle.color)
		color.a *= clampf(float(particle.life) * 3.0,0,1)
		draw_rect(Rect2(Vector2(particle.p), Vector2.ONE * float(particle.size)), color)
