extends "res://scripts/visual/rider_view.gd"
static var samples:Array=[]
static var enabled=false
func _draw() -> void:
	var first=horse_skin==null
	var started=Time.get_ticks_usec()
	super._draw()
	if enabled and samples.size()<300:samples.append({"type":"rider_first_draw" if first else "rider_draw","frame":Engine.get_process_frames(),"ms":(Time.get_ticks_usec()-started)/1000.0})
func _draw_rider(pose:Dictionary,seated:Dictionary,origin:Vector2)->void:
	var started=Time.get_ticks_usec()
	super._draw_rider(pose,seated,origin)
	if enabled and samples.size()<300:samples.append({"type":"human","frame":Engine.get_process_frames(),"ms":(Time.get_ticks_usec()-started)/1000.0})
