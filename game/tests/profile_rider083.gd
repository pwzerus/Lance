extends "res://scripts/visual/rider_view.gd"
const Probe = preload("res://tests/profiler083.gd")
const TimedSkin = preload("res://tests/profile_skin083.gd")
var suppress_draw = false
func _process(delta: float) -> void:
	var start = Time.get_ticks_usec()
	super._process(delta)
	Probe.record("rider.process",start)
func _draw() -> void:
	if suppress_draw: return
	if horse_skin==null:
		horse_skin=TimedSkin.new()
		far_hind_skin=TimedSkin.new("hind")
		far_fore_skin=TimedSkin.new("fore")
	var start = Time.get_ticks_usec()
	super._draw()
	Probe.record("rider.draw",start)
func _draw_rider(pose: Dictionary, seated: Dictionary, origin: Vector2) -> void:
	var start = Time.get_ticks_usec()
	super._draw_rider(pose,seated,origin)
	Probe.record("rider.draw_human",start)
func _draw_anatomical_arm(side: String, arm: Dictionary, tint: Color, upper: bool, lower: bool) -> void:
	var start = Time.get_ticks_usec()
	super._draw_anatomical_arm(side,arm,tint,upper,lower)
	Probe.record("human.arms",start)
func _draw_lance(hand: Vector2, angle: float, length: float, broken: bool, layer: int = Lance.Layer.WHOLE) -> void:
	var start = Time.get_ticks_usec()
	super._draw_lance(hand,angle,length,broken,layer)
	Probe.record("human.lance",start)
func _draw_shield(center: Vector2, design: String) -> void:
	var start = Time.get_ticks_usec()
	super._draw_shield(center,design)
	Probe.record("human.shield",start)
func _draw_seated_leg(pose: Dictionary, tint: Color, near: bool) -> void:
	var start = Time.get_ticks_usec()
	super._draw_seated_leg(pose,tint,near)
	Probe.record("human.leg",start)
func _draw_impact_torso() -> void:
	var start = Time.get_ticks_usec()
	super._draw_impact_torso()
	Probe.record("human.torso",start)
