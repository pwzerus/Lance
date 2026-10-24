extends SceneTree

const Model = preload("res://scripts/core/joust_match.gd")
var checks = 0
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)
		push_error(description)

func contact_fixture(aim: float, guard: float, lean: float = 0.0, direction: int = 1) -> Dictionary:
	var model = Model.new("arena")
	var a = model.fighters[0]
	var d = model.fighters[1]
	a.x = -500*direction
	a.direction = direction
	a.aim = aim
	d.x = 0
	d.direction = -direction
	d.guard = guard
	d.lean = lean
	model._cache_pose(a)
	model._cache_pose(d)
	for i in range(170):
		a.x += 4*direction
		var contact = model._detect_contact(0,1.0/120)
		if not contact.is_empty():
			return contact
		model._cache_pose(a)
	return {}

func strike(stability: float, lean: float, zone: String, mode: String = "arena") -> Dictionary:
	var model = Model.new(mode)
	model.fighters[0].lance_stability = stability
	model.fighters[0].lean = lean
	model._apply_contact({"type":"hit","attacker":0,"defender":1,"zone":zone,"speed":960.0,"position":Vector2.ZERO})
	return model.drain_events()[0]

func run() -> void:
	for direction in [1,-1]:
		check(contact_fixture(-.23,0,0,direction).get("zone")=="head","Low shield leaves a clean high lane in either direction")
		check(contact_fixture(-.23,1,0,direction).get("zone")=="shield","High shield intercepts the identical head attack")
		check(contact_fixture(.21,0,0,direction).get("zone")=="shield","Low shield intercepts the abdomen lane")
		check(contact_fixture(.21,1,0,direction).get("zone")=="flank","High shield exposes the abdomen lane")
		check(contact_fixture(-.23,0,-1,direction).is_empty(),"Full backward lean dodges a committed high attack")
	var model = Model.new()
	model.phase = "charge"
	model.fighters[0].x = -400
	model.fighters[1].x = 400
	for i in range(120):
		model.set_controls(0,-.23,0,true,1.0/120,1)
	var held = float(model.fighters[0].lance_stability)
	check(held>.95,"A held lance regains stable support")
	for i in range(24):
		model.set_controls(0,.21,0,true,1.0/120,0)
	check(float(model.fighters[0].lance_stability)<held-.2,"A late large redirect sacrifices stable support")
	check(float(model.fighters[0].aim)<.21,"Close range corrections take time rather than teleport")
	check(float(model.fighters[0].guard)>0 and float(model.fighters[0].guard)<1,"Shield switch travels through a vulnerable transition")
	check(float(strike(1,0,"head").damage)>float(strike(.2,0,"head").damage)*1.7,"Stable support changes actual damage, not only the HUD")
	check(float(strike(1,-1,"body").impulse)<float(strike(1,0,"body").impulse)*.8,"Permanent backward lean sacrifices attack support")
	var guard_hit = strike(1,0,"shield")
	check(float(guard_hit.damage)<3 and not guard_hit.ko,"Shield blocks protect without arbitrary instant unseating")
	var lethal = Model.new("war")
	lethal.fighters[1].hp = 12
	lethal.fighters[0].lance_stability = 1.0
	lethal._apply_contact({"type":"hit","attacker":0,"defender":1,"zone":"head","speed":960.0,"position":Vector2.ZERO})
	check(lethal.fighters[1].dead,"A valid exposed war head hit may still be lethal")
	var safe = Model.new("arena")
	safe.fighters[1].hp = 12
	safe._apply_contact({"type":"hit","attacker":0,"defender":1,"zone":"head","speed":960.0,"position":Vector2.ZERO})
	check(safe.fighters[1].ko and not safe.fighters[1].dead,"Arena protection applies even to a lethal-strength head hit")
	var report = {"checks":checks,"failures":failures,"passed":failures.is_empty()}
	var out = FileAccess.open("res://tests/tactics_results.json",FileAccess.WRITE)
	if out:
		out.store_string(JSON.stringify(report,"\t"))
	print("TACTICS_TEST_REPORT "+JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
