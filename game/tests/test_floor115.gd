extends "test_games115.gd"
## Actual production camera; compare physical lane projection with the
## observed ground boundary in the unchanged backdrop, without moving actors.
func configure_game(index: int, battle) -> void:
	super.configure_game(index,battle)
	if "--resize" in OS.get_cmdline_user_args():
		root.size=[Vector2i(1024,768),Vector2i(1280,720),Vector2i(1600,900),Vector2i(960,720)][index%4]

func fall_shape(actor) -> Dictionary:
	var value=super.fall_shape(actor)
	var battle=actor.get_parent().get_parent().get_parent()
	var lane_screen:Vector2=battle.world.get_global_transform_with_canvas()*Vector2(actor.position.x,actor.ground_y)
	var backdrop_floor:Vector2=battle.backdrop.get_global_transform_with_canvas()*Vector2(0,battle.backdrop.size.y*.59)
	var cover=Rect2(battle.backdrop.position,battle.backdrop.size)
	var viewport=Rect2(Vector2.ZERO,root.get_visible_rect().size)
	var lane_clearances=[]
	for fighter in battle.match_model.fighters:
		var projected:Vector2=battle.world.get_global_transform_with_canvas()*Vector2(float(fighter.x),float(fighter.lane_y)+12.0)
		lane_clearances.append(projected.y-backdrop_floor.y)
		if projected.y-backdrop_floor.y<18.0:failures.append("Lane ground projects above backdrop floor: facing %d" % int(fighter.direction))
	value.ground_projection={"window":str(root.size),"lane_y":lane_screen.y,"backdrop_floor_y":backdrop_floor.y,"clearance":lane_screen.y-backdrop_floor.y,"both_lane_clearances":lane_clearances,"covers_viewport":cover.encloses(viewport)}
	if lane_screen.y-backdrop_floor.y<18.0:failures.append("Fallen lane projects above background ground: facing %d" % int(actor.fighter.direction))
	if not cover.encloses(viewport):failures.append("Backdrop exposes an image edge during fall closeup")
	return value
