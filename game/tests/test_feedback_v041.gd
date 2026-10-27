extends SceneTree

const Model = preload("res://scripts/core/joust_match.gd")
const Report = preload("res://scripts/ui/combat_report.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func hit(mode: String, hp: float, balance: float, stability: float) -> Dictionary:
	var model = Model.new(mode)
	model.fighters[1].hp = hp
	model.fighters[1].balance = balance
	model.fighters[1].stats.stability = stability
	model._apply_contact({"type":"hit","attacker":0,"defender":1,"zone":"body","speed":700.0,"position":Vector2.ZERO})
	return model.drain_events()[0]

func run() -> void:
	check(root.get_node("GameState").save_path.contains("qa_"),"Use isolated QA profile")
	var regular = hit("arena",100,100,1)
	var impact = hit("arena",100,100,.3)
	var balance = hit("arena",100,1,1)
	var health = hit("arena",1,100,1)
	var fatal = hit("war",1,100,1)
	check(not regular.ko and regular.ko_reason.is_empty(),"Non-KO must not invent a fall cause")
	check(impact.ko_reason=="impact","A single excessive impulse is distinguished from attrition")
	check(balance.ko_reason=="balance","Accumulated balance loss has its own explanation")
	check(health.ko_reason=="health" and not health.dead,"Arena depletion is nonfatal")
	check(fatal.ko_reason=="fatal" and fatal.dead,"War lethal wounds have an explicit cause")
	check(Report.summarize([impact]).contains("冲击超过坐稳能力"),"Result uses the resolved rule event")
	check(Report.summarize([]).contains("未接触"),"A miss must not be reported as blocked or head contact")
	var counter = balance.duplicate(true)
	counter.attacker = 1
	counter.defender = 0
	var summary = Report.summarize([regular,impact,counter])
	check(summary.contains("你落马") and summary.contains("对手落马"),"Simultaneous falls must explain both riders")
	print("FEEDBACK_V041 "+JSON.stringify({"passed":failures.is_empty(),"failures":failures,"sample":summary}))
	quit(0 if failures.is_empty() else 1)
