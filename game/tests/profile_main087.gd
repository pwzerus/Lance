extends "res://scripts/main.gd"
const TimedRider=preload("res://tests/profile_rider087.gd")
var costs={}
var shared_material:ShaderMaterial
func note(key:String,started:int)->void:
	costs[key]=float(costs.get(key,0))+(Time.get_ticks_usec()-started)/1000.0
func _clear_screen()->void:
	var start=Time.get_ticks_usec();super._clear_screen();note("clear_screen",start)
func _close_battle()->void:
	var start=Time.get_ticks_usec();super._close_battle();note("close_battle",start)
func _add_preview(point:Vector2,preview_scale:float=1,stats:Dictionary={})->void:
	var start=Time.get_ticks_usec();super._add_preview(point,preview_scale,stats);note("create_preview",start)
	if shared_material:preview.material=shared_material
func _start_match(mode:String,practice:bool=false,guide:PracticeGuide=null)->void:
	var start=Time.get_ticks_usec();super._start_match(mode,practice,guide);note("production_start",start)
	# Diagnostic substitutions only, before any rider's first draw. Their
	# extra construction is measured separately, not release frame proof.
	start=Time.get_ticks_usec()
	for i in range(battle.riders.size()):
		var old=battle.riders[i];var rider=TimedRider.new()
		for key in ["fighter","red","mode","blood_enabled","z_index","stride_phase","position","moving"]:rider.set(key,old.get(key))
		old.hide();old.set_process(false)
		battle.world.add_child(rider);battle.world.move_child(rider,old.get_index())
		rider.hoof_contact.connect(battle._on_hoof_contact.bind(i));battle.riders[i]=rider
		if shared_material:rider.material=shared_material
		old.queue_free()
	note("diagnostic_substitution",start)
