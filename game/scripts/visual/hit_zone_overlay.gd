extends Node2D

const Model = preload("res://scripts/core/joust_match.gd")
var match_model: JoustMatch

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	if not match_model:
		return
	for f in match_model.fighters:
		if f.ko or f.dead:
			continue
		for zone in ["head","body","flank","shield"]:
			if zone=="shield" and float(f.shield)<=0:
				continue
			var p = Model.head_position(f) if zone=="head" else (Model.body_position(f) if zone=="body" else (Model.shield_position(f) if zone=="shield" else Model.flank_position(f)))
			if zone=="shield":
				var outline = Model.Shield.world_polygon(p,Model.pose_angle(f),int(f.direction),str(f.stats.get("shield_shape","kite")))
				draw_colored_polygon(outline,Color(Color("ffe08c"),.10))
				outline.append(outline[0])
				draw_polyline(outline,Color("ffe08c"),1.8)
				continue
			var radius = {"head":24,"body":30,"flank":22,"shield":38}[zone]
			var color = Color("ffe08c") if zone=="shield" else Color("80e8ed")
			draw_circle(p,radius,Color(color,.10))
			draw_arc(p,radius,0,TAU,48,color,1.8,true)
