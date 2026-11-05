extends SceneTree
## Hoof delivery and rigid skull regression. No screen/input or player saves.
const Gait = preload("res://scripts/visual/horse_gait.gd")
const Coat = preload("res://scripts/visual/horse_skin.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok and message not in failures: failures.append(message)

func run() -> void:
	var path = ""
	var gait = Gait
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report-path="): path = arg.trim_prefix("--report-path=")
		if arg.begins_with("--probe-gait="): gait = load(arg.trim_prefix("--probe-gait="))
	if OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not root.get_node("GameState").save_path.contains("qa_") or path.is_empty() or FileAccess.file_exists(path):
		quit(2)
		return
	var worst_velocity_jump = 0.0
	for front in [true,false]:
		for run_weight in [0.0,.5,1.0]:
			var reach = 40.0
			var lift = lerpf(15,46,run_weight)
			var previous = gait._swing_point(front,0,reach,lift,run_weight)
			check(previous.distance_to(Vector2(-reach,0))<.001,"Lift-off location changed")
			for step in range(1,1001):
				var point: Vector2 = gait._swing_point(front,step/1000.0,reach,lift,run_weight)
				check(point.x>=previous.x-.001 and point.x<=reach+.001,"Hoof overshoots or reverses before landing")
				check(point.y<=.001 and point.y>=-lift-.001,"Hoof delivery exceeds its lift envelope")
				previous=point
			check(previous.distance_to(Vector2(reach,0))<.001,"Touchdown location changed")
			# Test old segment boundaries and the new apex, not just uniform points.
			var apex = (.36 if front else .40)-.03*run_weight
			for knot in [.18,.22,.42,.55,.75,.84,apex]:
				var epsilon = .0005
				var a: Vector2 = gait._swing_point(front,knot-epsilon,reach,lift,run_weight)
				var b: Vector2 = gait._swing_point(front,knot,reach,lift,run_weight)
				var c: Vector2 = gait._swing_point(front,knot+epsilon,reach,lift,run_weight)
				var jump = ((c-b)-(b-a)).length()/epsilon
				worst_velocity_jump=maxf(worst_velocity_jump,jump)
				check(jump<5.0,"Hoof curve has a velocity discontinuity at an interior knot")
			for endpoint in [0.0,1.0]:
				var inner = .0005 if endpoint==0 else .9995
				var a: Vector2 = gait._swing_point(front,endpoint,reach,lift,run_weight)
				var b: Vector2 = gait._swing_point(front,inner,reach,lift,run_weight)
				check(a.distance_to(b)/.0005<1.0,"Hoof starts/stops with a velocity jump against the planted target")
	var skull_error = 0.0
	var expected = Coat.rest_point(Coat.POLL).distance_to(Coat.rest_point(Coat.MUZZLE))
	var skin = Coat.new()
	var vertex_count = skin.vertices.size()
	for speed in [0.0,100.0,210.0,320.0,480.0,600.0]:
		for frame in range(60):
			var phase = frame*TAU/60
			var body = Gait.body(phase,speed,speed>0,1,sin(phase))
			var error = absf(Coat.neck_point(Coat.POLL,body).distance_to(Coat.muzzle_point(body))-expected)
			skull_error=maxf(skull_error,error)
			check(error<.001,"Neck motion stretches the rigid skull or disconnects the rein anchor")
			skin.update(body,Gait.leg(1,phase,speed,speed>0),Gait.leg(3,phase,speed,speed>0))
			check(skin.vertices.size()==vertex_count and skin.mesh.get_surface_count()==1,"Animation grows mesh topology")
			for point in skin.vertices:
				check(point.is_finite(),"Animation produced non-finite mesh coordinates")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file = FileAccess.open(path,FileAccess.WRITE)
	if file==null:
		quit(2)
		return
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"maximum_curve_velocity_jump":worst_velocity_jump,"maximum_skull_length_error":skull_error,"fixed_vertices":vertex_count,"scope":"Curve continuity, no overshoot, rigid poll/muzzle and bounded mesh topology. Not a human feel verdict."},"\t"))
	file.close()
	print("MOTION_REGRESSION061 "+str(failures.is_empty())+" "+str(failures))
	quit(0 if failures.is_empty() else 1)
