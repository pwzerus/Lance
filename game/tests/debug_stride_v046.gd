extends SceneTree
const M=preload("res://scripts/core/joust_match.gd")
const R=preload("res://scripts/visual/rider_view.gd")
func _initialize():
	call_deferred("run")
func run():
	var model=M.new()
	model.phase="charge"
	model.fighters[0].x=-100000
	model.fighters[1].x=100000
	for f in model.fighters: f.acted=true
	var f=model.fighters[1]
	var view=R.new()
	view.fighter=f
	view.moving=true
	root.add_child(view)
	view.set_process(false)
	for tick in range(66):
		model.set_controls(1,0,0,true,1.0/120,.43)
		model.step(1.0/120)
		view.position=Vector2(f.x,f.lane_y)
		view._process(1.0/120)
		if tick>=48:
			var p=view.leg_poses[1]
			print(JSON.stringify({"tick":tick,"x":f.x,"speed":f.speed,"foot":str(p.foot),"cycle":p.cycle,"swing":p.swing,"reach":p.reach,"start":str(view.swing_starts[1]),"duration":view.swing_durations[1],"release":view.release_cycles[1],"path":str(view.Gait._swing_point(false,p.swing,p.reach,p.lift,0.0)),"hip":str(p.hip),"proximal":str(p.proximal)}))
	view.free()
	quit()
