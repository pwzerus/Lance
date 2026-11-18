extends SceneTree
## Fracture pieces share the pre-impact shaft and inherit its motion.
## Their collision impulse may change momentum; speed is not required to be
## continuous across a real impact. Check directional response and geometry.
const FX=preload("res://scripts/visual/impact_fx.gd")
const Model=preload("res://scripts/core/joust_match.gd")
var failures=[]
var rows=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	if not ok and message not in failures:failures.append(message);push_error(message)

func fracture(facing:int,speed:float,aim:float,rate:float)->Array:
	var fx=FX.new();root.add_child(fx);fx.set_process(false)
	var hand=Vector2(facing*20,-160)
	var ray=Vector2(cos(aim)*facing,sin(aim))
	var event={"break_hand":hand,"break_reach":247.0,"break_angle":aim,"break_direction":facing,
		"attacker_speed":speed,"speed":speed*2.0,"break_hand_velocity":Vector2(facing*speed,22.0),"break_angular_velocity":facing*rate}
	fx.break_lance(event,"arena")
	check(fx.debris.size()==2,"Broken shaft makes two pieces")
	var pieces=[];var offset=66.0
	for body in fx.debris:
		var length=float(body.get_child(1).length)
		check(body.position.distance_to(hand+ray*(offset+length*.5))<.001,"Fracture keeps original shaft positions")
		check(absf(Vector2.RIGHT.rotated(body.rotation).angle_to(ray))<.001,"Fracture keeps original shaft direction")
		check(body.collision_mask in [16,32],"Visual fragments collide only with their own lane ground")
		check(body.linear_velocity.is_finite() and absf(body.angular_velocity)<15.0 and body.linear_velocity.length()<1400,"Bounded finite fracture motion")
		pieces.append({"v":body.linear_velocity,"spin":body.angular_velocity,"center":body.position,"length":length})
		offset+=length
	check(absf(offset-247.0)<.001,"No lost or doubled shaft at the cut seams")
	rows.append({"facing":facing,"speed":speed,"aim":aim,"rate":rate,"pieces":pieces})
	fx.free()
	return pieces

func contact_snapshot(facing:int)->void:
	var m=Model.new("arena",{}, {},10503)
	var ai=0 if facing==1 else 1;var di=1-ai
	var a:Dictionary=m.fighters[ai];var d:Dictionary=m.fighters[di]
	a.direction=facing;a.aim=0.0;a.speed=400;a.durability=0.0
	d.shield=0.0;d.x=0.0;d.speed=400
	var target=Model.body_position(d)
	var tip=target+Vector2(facing*3,0)
	a.x+=tip.x-Model.tip_position(a).x
	a.lane_y+=tip.y-Model.tip_position(a).y
	for f in m.fighters:m._cache_pose(f)
	var dt=.1
	a.prev_hand=Model.hand_position(a)-Vector2(facing*400,22)*dt
	a.prev_aim=-.05
	var event=m._detect_contact(ai,dt)
	check(not event.is_empty(),"Real swept contact fixture hits the torso")
	if event.is_empty():return
	var expected=(Model.hand_position(a)-a.prev_hand)/dt
	check(event.has("break_hand_velocity") and event.has("break_angular_velocity"),"Sweep exposes pre-impact hand and shaft motion")
	if event.has("break_hand_velocity"):
		check(Vector2(event.break_hand_velocity).distance_to(expected)<.002,"Sweep velocity uses the same two sampled hands")
		check(absf(float(event.break_angular_velocity)-facing*.5)<.0001,"World angular sign follows shaft facing")
	m._apply_contact(event)
	check(event.broke,"Real impact breaks the exhausted lance")
	check(absf(float(event.break_reach)-247.0)<.001,"Break keeps full pre-break reach")

func run()->void:
	var report=""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--report="):report=a.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report) or not root.get_node("GameState").save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024":quit(2);return
	for facing in [1,-1]:
		contact_snapshot(facing)
		for aim in [-.42,0.0,.32]:
			var slow=fracture(facing,190,aim,0)
			var fast=fracture(facing,480,aim,0)
			var lifting=fracture(facing,400,aim,-.6)
			var lowering=fracture(facing,400,aim,.6)
			for i in range(2):
				check((Vector2(fast[i].v)-Vector2(slow[i].v)).x*facing>90,"Fast charge carries fragments farther than slow charge")
				check(float(lowering[i].v.y)-float(lifting[i].v.y)>45,"Raising and lowering lance influence fragment flight")
	for speed in [190.0,480.0]:
		var right=fracture(1,speed,.2,.5);var left=fracture(-1,speed,.2,.5)
		for i in range(2):
			check(Vector2(right[i].v).distance_to(Vector2(left[i].v)*Vector2(-1,1))<.002,"Fracture momentum mirrors between riders")
			check(absf(float(right[i].spin)+float(left[i].spin))<.002,"Fracture spin mirrors between riders")
	FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"28 synthetic fracture configurations plus two genuine swept contact snapshots. Geometry, velocity response, symmetry and lane masks; not a measured historical material simulation or human motion verdict."},"\t"))
	print("FRACTURE105 ",failures);quit(0 if failures.is_empty() else 1)
