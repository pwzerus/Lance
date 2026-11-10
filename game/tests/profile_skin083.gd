extends "res://scripts/visual/horse_skin.gd"
const Probe = preload("res://tests/profiler083.gd")
func _init(limb: String = "") -> void: super(limb)
func update(body_pose: Dictionary, hind_pose: Dictionary, fore_pose: Dictionary) -> void:
	var start = Time.get_ticks_usec()
	super.update(body_pose,hind_pose,fore_pose)
	Probe.record("skin.update",start)
func draw(canvas: CanvasItem, tint: Color) -> void:
	var start = Time.get_ticks_usec()
	super.draw(canvas,tint)
	Probe.record("skin.submit",start)
