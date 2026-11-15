extends SceneTree
## FEEL-094 seat-steadiness study (isolated desktop, QA profile). Real match
## model (set_controls + step) for one rider whose opponent is parked far away,
## real RiderView for drawing. Each scenario starts from a full gallop.
##  metrics.json   - per scenario: peak/at-end unsteadiness, sway, seat lift,
##                   head-anchor travel from the sway, threshold/balance factors.
##  strip_calm.png / strip_flail.png - one gallop stride, steady vs flailing.
## Rule simulation and rendering only; not OS input or a playtest.
const Rider = preload("res://scripts/visual/rider_view.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const Gait = preload("res://scripts/visual/horse_gait.gd")
const DT = 1.0/60.0
var folder = ""
var model
var fighter: Dictionary
var rider
var mount: Node2D
var metrics = {"scenarios":{},"nonfinite":0}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): folder = arg.trim_prefix("--report=")
	if OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not root.get_node("GameState").save_path.contains("qa_") or folder.is_empty() or DisplayServer.get_name()=="headless" or DirAccess.dir_exists_absolute(folder):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1440,1080)
	root.content_scale_size = Vector2i(1440,1080)
	RenderingServer.set_default_clear_color(Color("4b5859"))
	var catalogue = load("res://scripts/core/catalogue.gd")
	var items = catalogue.load_items()
	var kits = {"medium":{"armor":"eng_armor_3","helmet":"eng_helmet_1"},"heavy":{"armor":"eng_armor_5","helmet":"eng_helmet_5"}}
	var scenarios = ["calm","brace","brace_release","lean_flail","lance_flail","guard_flail","spur_pump","all_flail"]
	for kit in kits:
		var equipped = {"horse":"horse_bay","crest":"crest_bend","lance":"eng_lance_long_3","shield":"eng_shield_3"}
		equipped.merge(kits[kit],true)
		var stats = catalogue.stats(items,equipped)
		for scenario in scenarios:
			_setup(stats)
			metrics.scenarios[kit+"/"+scenario] = _play(scenario)
	# Strips with the real renderer (medium kit).
	var stats_m = catalogue.stats(items,{"horse":"horse_bay","armor":"eng_armor_3","helmet":"eng_helmet_1","crest":"crest_bend","lance":"eng_lance_long_3","shield":"eng_shield_3"})
	for scenario in ["calm","all_flail"]:
		_setup(stats_m)
		mount = Node2D.new()
		root.add_child(mount)
		rider = Rider.new()
		rider.fighter = fighter
		rider.moving = true
		mount.add_child(rider)
		rider.set_process(false)
		var cells: Array[Image] = []
		var t = 0.0
		while t<2.0:
			_control(scenario,t)
			_advance()
			t += DT
		var period = 1.0/Gait.frequency(float(fighter.speed))
		var per = maxi(1,roundi(period/DT/4.0))
		for tick in range(per*8):
			_control(scenario,t)
			_advance()
			t += DT
			if tick%per==0: cells.append(await _shot())
		_save_strip(cells,"strip_"+("calm" if scenario=="calm" else "flail")+".png")
		metrics["strip_"+scenario+"_unsteady"] = snappedf(float(fighter.unsteady),.001)
		mount.queue_free()
		await process_frame
	var s: Dictionary = metrics.scenarios
	var ok = int(metrics.nonfinite)==0
	for kit in kits:
		ok = ok and float(s[kit+"/calm"].peak)<.05 and float(s[kit+"/brace"].peak)<.12
		ok = ok and float(s[kit+"/all_flail"].peak)>.85 and float(s[kit+"/lean_flail"].peak)>.5 and float(s[kit+"/lance_flail"].peak)>.5
		ok = ok and float(s[kit+"/all_flail"].sway_max)<=.171 and float(s[kit+"/calm"].sway_max)<.01
	# Heavier kit sits deeper: never more unsettled by the same flailing.
	ok = ok and float(s["heavy/all_flail"].fidget_peak)<=float(s["medium/all_flail"].fidget_peak)
	metrics["result"] = "PASS" if ok else "FAIL"
	var file = FileAccess.open(folder+"/metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"\t"))
	file.close()
	print("UNSTEADY094 "+JSON.stringify(metrics.scenarios))
	print("UNSTEADY094_RESULT "+metrics.result+" "+folder)
	quit(0 if ok else 1)

func _setup(stats: Dictionary) -> void:
	model = Model.new("arena",stats,stats)
	fighter = model.fighters[0]
	model.fighters[1].x = 99999.0
	model.phase = "charge"
	fighter.lane_y = 0.0
	# Reach a steady gallop calmly first.
	for tick in range(300):
		fighter.stamina = 100.0
		model.set_controls(0,-.08,0.0,true,DT,.43)
		model.step(DT)
		model.fighters[1].x = 99999.0

func _control(scenario: String, t: float) -> void:
	var aim = -.08
	var lean = 0.0
	var guard = .43
	var boost = true
	var active = t>=1.0 and t<3.0
	match scenario:
		"brace":
			lean = 1.0 if t>=1.0 else 0.0
		"brace_release":
			lean = 1.0 if t>=1.0 and t<1.6 else 0.0
		"lean_flail":
			if active: lean = 1.0 if int((t-1.0)/.3)%2==0 else -1.0
		"lance_flail":
			if active: aim = -.5 if int((t-1.0)/.25)%2==0 else .4
		"guard_flail":
			if active: guard = 1.0 if int((t-1.0)/.3)%2==0 else .43
		"spur_pump":
			if active: boost = int((t-1.0)/.4)%2==0
		"all_flail":
			if t>=1.0:
				lean = 1.0 if int((t-1.0)/.3)%2==0 else -1.0
				aim = -.5 if int((t-1.0)/.25)%2==0 else .4
				guard = 1.0 if int((t-1.0)/.35)%2==0 else .43
	fighter.stamina = 100.0
	model.set_controls(0,aim,lean,boost,DT,guard)

func _advance() -> void:
	model.step(DT)
	model.fighters[1].x = 99999.0
	if mount!=null and is_instance_valid(mount):
		rider.position = Vector2(float(fighter.x),0)
		mount.position = Vector2(720-float(fighter.x),760)
		rider._process(DT)

func _play(scenario: String) -> Dictionary:
	var r = {"peak":0.0,"fidget_peak":0.0,"sway_max":0.0,"lift_max":0.0,"head_shift_max":0.0,"unsteady_at_3s":0.0,"unsteady_at_4s":0.0,"balance_end":0.0}
	var t = 0.0
	while t<4.5:
		_control(scenario,t)
		model.step(DT)
		model.fighters[1].x = 99999.0
		t += DT
		var u = float(fighter.unsteady)
		r.peak = maxf(r.peak,u)
		r.fidget_peak = maxf(r.fidget_peak,float(fighter.fidget))
		r.sway_max = maxf(r.sway_max,absf(float(fighter.sway)))
		r.lift_max = maxf(r.lift_max,Model.seat_lift(fighter))
		var still = fighter.duplicate()
		still.sway = 0.0
		still.unsteady = 0.0
		r.head_shift_max = maxf(r.head_shift_max,Model.head_position(fighter).distance_to(Model.head_position(still)))
		if not Model.head_position(fighter).is_finite(): metrics.nonfinite += 1
		if absf(t-3.0)<DT*.5: r.unsteady_at_3s = u
		if absf(t-4.0)<DT*.5: r.unsteady_at_4s = u
	r.balance_end = float(fighter.balance)
	r["threshold_factor_at_peak"] = 1.0-Model.UNSTEADY_THRESHOLD_LOSS*float(r.peak)
	r["balance_loss_factor_at_peak"] = 1.0+Model.UNSTEADY_BALANCE_GAIN*float(r.peak)
	for key in r:
		r[key] = snappedf(float(r[key]),.001)
	return r

func _shot() -> Image:
	rider.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image().get_region(Rect2i(720-300,760-380,600,440))

func _save_strip(cells: Array[Image], name: String) -> void:
	var columns = 4
	var rows = ceili(cells.size()/float(columns))
	var sheet = Image.create_empty(606*columns,446*rows,false,Image.FORMAT_RGBA8)
	sheet.fill(Color.BLACK)
	for i in range(cells.size()):
		sheet.blit_rect(cells[i],Rect2i(Vector2i.ZERO,cells[i].get_size()),Vector2i((i%columns)*606,(i/columns)*446))
	sheet.save_png(folder+"/"+name)
