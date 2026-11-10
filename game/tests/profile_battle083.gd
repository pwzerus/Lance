extends "res://scripts/battle.gd"
const Probe = preload("res://tests/profiler083.gd")
const TimedRider = preload("res://tests/profile_rider083.gd")
func _ready() -> void:
	super._ready()
	for i in range(riders.size()):
		var old = riders[i]
		var rider = TimedRider.new()
		for key in ["fighter","red","mode","blood_enabled","z_index","stride_phase","position"]:
			rider.set(key,old.get(key))
		old.set_process(false)
		old.hide()
		world.add_child(rider)
		world.move_child(rider,old.get_index())
		rider.hoof_contact.connect(_on_hoof_contact.bind(i))
		riders[i]=rider
		old.queue_free()
func _process(delta: float) -> void:
	var start = Time.get_ticks_usec()
	super._process(delta)
	Probe.record("battle.process",start)
func _physics_process(delta: float) -> void:
	var start = Time.get_ticks_usec()
	super._physics_process(delta)
	Probe.record("battle.physics",start)
func _update_views() -> void:
	var start = Time.get_ticks_usec()
	super._update_views()
	Probe.record("battle.views",start)
func _update_hud() -> void:
	var start = Time.get_ticks_usec()
	super._update_hud()
	Probe.record("battle.hud",start)
func _update_camera(real_delta: float, now: int) -> void:
	var start = Time.get_ticks_usec()
	super._update_camera(real_delta,now)
	Probe.record("battle.camera",start)
func _draw_rail() -> void:
	var start = Time.get_ticks_usec()
	super._draw_rail()
	Probe.record("battle.rail",start)
func _draw_track() -> void:
	var start = Time.get_ticks_usec()
	super._draw_track()
	Probe.record("battle.track",start)
