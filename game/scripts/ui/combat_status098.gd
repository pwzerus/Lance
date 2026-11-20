extends Control
## Presentation reads resolved state. No hit prediction and no rules here.
# Keep the base-font reference for existing shield/heraldry QA consumers.
# Actual HUD text uses the shared 500-weight variation below.
const FONT = preload("res://assets/fonts/NotoSansSC.ttf")
const INK = Color("eee6cc")
const MUTED = Color("9fae9f")
var fighters: Array = []
var events: Array = []
var pass_number = 1
var history = false
var arena = true
var _signature = ""
var _backdrop: Node2D

func _ready() -> void:
	_backdrop = Node2D.new()
	# Behind the HUD's labels, not over the contact messages at y=110.
	_backdrop.z_index = -1
	_backdrop.draw.connect(_draw_backdrop)
	add_child(_backdrop)

func _draw_backdrop() -> void:
	if history or fighters.size()!=2: return
	for panel in [Rect2(14,58,538,84),Rect2(908,58,518,84)]:
		_backdrop.draw_rect(panel,Color("14231d"))
		_backdrop.draw_line(panel.position+Vector2(0,83),panel.end,Color("435244"),1)
	_backdrop.draw_rect(Rect2(686,58,68,22),Color("14231d"))

func refresh(current: Array, contacts: Array, pass_index: int) -> void:
	fighters=current
	events=contacts
	pass_number=pass_index
	# Quantise only the readout, never physics. Redraw only while visible and
	# when an actual meter or contact changes (prevents hidden result churn).
	var values: Array = [history,pass_number,contacts.size()]
	for f in fighters:
		values.append(bool(f.get("broken",false)))
		for key in ["hp","balance","shield","score","stamina","speed","lance_stability"]:
			values.append(roundi(float(f.get(key,0))* (100 if key=="lance_stability" else 1)))
	var signature=str(values)
	if signature!=_signature:
		_signature=signature
		if is_visible_in_tree():
			queue_redraw()
			if _backdrop: _backdrop.queue_redraw()

func text(value: String, at: Vector2, color: Color=INK, font_size: int=14) -> void:
	var font = UIFactory.theme().default_font
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func bar(rect: Rect2, fraction: float, color: Color, reverse: bool=false) -> void:
	draw_rect(rect,Color("111c18"))
	var fill=rect.grow(-1)
	var amount=clampf(fraction,0,1)
	fill.size.x*=amount
	if reverse: fill.position.x=rect.end.x-1-fill.size.x
	draw_rect(fill,color)
	draw_rect(rect,Color("536258"),false,1)

func pips(origin: Vector2, count: int, reverse: bool=false) -> void:
	for i in range(15):
		var at=origin+Vector2((-1 if reverse else 1)*i*12,0)
		draw_circle(at,3.3,Color("e2bd66") if i<count else Color("34483d"))

static func contact_text(hit: Dictionary) -> String:
	var part={"head":"头","body":"胸","flank":"腹","shield":"盾"}.get(str(hit.get("zone","")),"")
	if hit.get("dead",false): return part+" 致命"
	if hit.get("ko",false): return part+" 击落"
	if part=="盾":return preload("res://scripts/core/contact_feedback.gd").shield_text(hit)
	if hit.get("glanced",false): return part+(" 滑开" if part=="盾" else "擦过")
	return part+(" 重击" if float(hit.get("damage",0))>=35 else " 命中")

func figure(at: Vector2, hit: Dictionary, scale_value: float=1) -> void:
	var base=Color("526357")
	var zone=str(hit.get("zone",""))
	var hit_color=Color("e0ae59") if zone=="shield" else Color("db7357")
	if hit.get("glanced",false): hit_color=Color("8fc3d1")
	var head=at+Vector2(0,-17)*scale_value
	draw_circle(head,6*scale_value,hit_color if zone=="head" else base)
	draw_rect(Rect2(at+Vector2(-9,-8)*scale_value,Vector2(18,16)*scale_value),hit_color if zone=="body" else base)
	draw_rect(Rect2(at+Vector2(-8,9)*scale_value,Vector2(16,10)*scale_value),hit_color if zone=="flank" else base)
	for side in [-1,1]:
		draw_line(at+Vector2(side*6,18)*scale_value,at+Vector2(side*10,31)*scale_value,base,5*scale_value)
		draw_line(at+Vector2(side*10,-3)*scale_value,at+Vector2(side*17,13)*scale_value,base,4*scale_value)
	var shield=PackedVector2Array([Vector2(-25,-9),Vector2(-11,-9),Vector2(-11,10),Vector2(-18,21),Vector2(-25,10)])
	for i in range(shield.size()): shield[i]=at+shield[i]*scale_value
	draw_colored_polygon(shield,hit_color.darkened(.25) if zone=="shield" else base.darkened(.3))
	if zone=="shield":
		var marker={"center":Vector2(-18,2),"face":Vector2(-21,-3),"rim":Vector2(-25,10)}.get(str(hit.get("shield_region","face")),Vector2(-21,-3))
		draw_circle(at+marker*scale_value,3*scale_value,hit_color.lightened(.3))

func _draw() -> void:
	if history:
		_draw_history()
		return
	if fighters.size()!=2: return
	for i in range(2):
		var f: Dictionary=fighters[i]
		var x=24.0 if i==0 else 984.0
		text("你的骑手" if i==0 else "对手",Vector2(x,73),MUTED,15)
		text("生命",Vector2(x,94),INK,15)
		text("平衡",Vector2(x,116),INK,15)
		bar(Rect2(x+42,81,384,13),float(f.hp)/100,Color("b85d4c"),i==1)
		bar(Rect2(x+42,103,384,9),float(f.balance)/100,Color("ed9168") if float(f.balance)<35 else Color("d2b16b"),i==1)
		if arena:
			pips(Vector2(x+(381 if i==1 else 46),130),int(f.get("score",0)),i==1)
		var latest: Dictionary={}
		for event in events:
			if int(event.defender)==i: latest=event
		figure(Vector2(521 if i==0 else 933,89),latest,.85)
	for i in range(3):
		draw_circle(Vector2(702+i*18,69),4,Color("e1c27a") if i<pass_number else Color("394a3e"))
	var player: Dictionary=fighters[0]
	var broken = bool(player.get("broken",false))
	text("残枪" if broken else "枪稳",Vector2(404,772),Color("e0ae59") if broken else MUTED,13)
	bar(Rect2(446,761,194,9),0.0 if broken else float(player.lance_stability),Color("a5b484"))
	text("盾牌",Vector2(658,772),MUTED,13)
	bar(Rect2(700,761,194,9),float(player.shield)/maxf(1,float(player.stats.get("shield_capacity",150))),Color("7da7a6"))

func _draw_history() -> void:
	for attacker in range(2):
		for pass_index in range(1,4):
			var at=Vector2((pass_index-1)*234,attacker*79)
			draw_rect(Rect2(at,Vector2(226,72)),Color("182b23"))
			var hit: Dictionary={}
			for event in events:
				if int(event.attacker)==attacker and int(event.get("pass",1))==pass_index: hit=event
			figure(at+Vector2(36,31),hit,.72)
			text(("你出枪" if attacker==0 else "对手出枪")+"  "+["首轮","次轮","末轮"][pass_index-1],at+Vector2(67,18),MUTED,14)
			var description = ("未进行" if pass_index>pass_number else "未命中") if hit.is_empty() else contact_text(hit)
			text(description,at+Vector2(67,39),INK,17)
			text("损伤",at+Vector2(67,61),MUTED,11)
			bar(Rect2(at+Vector2(97,52),Vector2(114,8)),float(hit.get("damage",0))/100,Color("cc7457"))
