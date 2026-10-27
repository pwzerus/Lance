extends Node2D
## Read-only projection of the current tip height. It neither aims nor predicts AI decisions.
const Model = preload("res://scripts/core/joust_match.gd")
const COLORS = {"head":Color("f18d83"),"body":Color("7bd9e3"),"flank":Color("efb566"),"shield":Color("f4dc82"),"miss":Color("a8ad9b")}
const NAMES = {"head":"头部","body":"胸部","flank":"腰腹","shield":"盾牌格挡","miss":"偏离骑手"}
var match_model: JoustMatch
var enabled = true
var reading: Dictionary = {"zone":"miss","point":Vector2.ZERO}

static func project(model: JoustMatch, attacker_index: int = 0) -> Dictionary:
	var attacker = model.fighters[attacker_index]
	var defender = model.fighters[1-attacker_index]
	var tip = Model.tip_position(attacker)
	var result = {"zone":"miss","point":tip,"tip":tip,"active":false}
	if model.phase not in ["ready","charge"] or attacker.ko or defender.ko or attacker.dead or defender.dead or attacker.acted:
		return result
	var direction = int(attacker.direction)
	if (float(defender.x)-float(attacker.x))*direction<0:
		return result
	result.active = true
	var nearest = INF
	for zone in ["head","body","flank","shield"]:
		if zone=="shield" and float(defender.shield)<=0:
			continue
		var center = Model.head_position(defender) if zone=="head" else (Model.body_position(defender) if zone=="body" else (Model.flank_position(defender) if zone=="flank" else Model.shield_position(defender)))
		var radius = {"head":24.0,"body":30.0,"flank":22.0,"shield":38.0}[zone]
		var dy = tip.y-center.y
		if absf(dy)>radius:
			continue
		var half_chord = sqrt(maxf(0,radius*radius-dy*dy))
		var horizontal = (center.x-tip.x)*direction
		if horizontal+half_chord<0:
			continue # The entire region has already passed the tip.
		var entry = maxf(0,horizontal-half_chord)
		if entry<nearest:
			nearest = entry
			result.zone = zone
			result.point = center
	return result

func _process(_delta: float) -> void:
	if match_model:
		reading = project(match_model)
	queue_redraw()

func _draw() -> void:
	if not enabled or not reading.get("active",false):
		return
	var color = COLORS[reading.zone]
	var tip = Vector2(reading.tip)
	# A hollow diamond leaves the actual point and the opponent silhouette visible.
	draw_polyline(PackedVector2Array([tip+Vector2(0,-9),tip+Vector2(9,0),tip+Vector2(0,9),tip+Vector2(-9,0),tip+Vector2(0,-9)]),color,2)
	if reading.zone=="miss":
		return
	var point = Vector2(reading.point)
	var size = 29.0 if reading.zone=="head" else 35.0
	for x in [-1,1]:
		for y in [-1,1]:
			var corner = point+Vector2(x,y)*size
			draw_line(corner,corner-Vector2(x*10,0),Color(color,.8),2)
			draw_line(corner,corner-Vector2(0,y*10),Color(color,.8),2)
