extends SceneTree
const Shield = preload("res://scripts/core/shield_geometry.gd")
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _initialize() -> void:
	for shape in ["kite","heater","targe"]:
		var forward = Shield.sweep(Vector2.ZERO,Vector2.ZERO,-.65,.65,247,247,1,Vector2(247,0),Vector2(247,0),0,0,-1,shape,.1)
		var mirror = Shield.sweep(Vector2.ZERO,Vector2.ZERO,-.65,.65,247,247,-1,Vector2(-247,0),Vector2(-247,0),0,0,1,shape,.1)
		check(not forward.is_empty() and not mirror.is_empty(),shape+": rotating lance arc must hit shield")
		if not forward.is_empty() and not mirror.is_empty():
			check(absf(forward.fraction-mirror.fraction)<.0001,shape+": mirrored contacts share time")
			check((Vector2(forward.point)*Vector2(-1,1)).distance_to(mirror.point)<.001,shape+": mirrored contacts share surface")
		var moving = Shield.sweep(Vector2(-247,0),Vector2(-247,0),0,0,247,247,1,Vector2(150,0),Vector2(-150,0),0,0,-1,shape,.1)
		check(not moving.is_empty(),shape+": high-speed moving shield must cross stationary tip")
		var rotated = Shield.sweep(Vector2(-217,0),Vector2(-217,0),0,0,247,247,1,Vector2.ZERO,Vector2.ZERO,0,PI/2,1,shape,.1)
		check(not rotated.is_empty(),shape+": turning shield must catch stationary nearby tip")
		var clear = Shield.sweep(Vector2(-192,55),Vector2(-192,55),0,0,247,247,1,Vector2.ZERO,Vector2.ZERO,0,PI,1,shape,.1)
		check(clear.is_empty(),shape+": rotating shield must not reach a distant tip")
		var points = Shield.world_polygon(Vector2.ZERO,0,1,shape)
		var max_y = -INF
		for point in points:
			max_y = maxf(max_y,point.y)
		check(Shield.segment_fraction(Vector2(-600,max_y+.15),Vector2(19400,max_y+.15),points)<0,shape+": long preview ray must preserve corner near misses")
	print("SHIELD_SWEEP_V043 "+JSON.stringify({"passed":failures.is_empty(),"failures":failures,"scope":"three shield outlines, mirrored lance arcs, moving and rotating shields, long-ray near misses"}))
	quit(0 if failures.is_empty() else 1)
