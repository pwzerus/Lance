extends Control
## ART-090 helmet sight. A closed helmet lets the rider see only through the
## eye slit or visor sights: during the charge the screen darkens above and
## below a band centred on the player's eye line. The band height comes from
## stats.helmet_vision (1.0 open face = no mask; ~0.5 great helm = narrow
## slit). Purely a view restriction: it never moves the lance, the targets or
## any rule. The AI pays the same cost as a later observation (opponent_ai).
## Drawn on its own CanvasLayer under the HUD, so menus and readouts stay clear.
const Model = preload("res://scripts/core/joust_match.gd")
var battle: Node = null
var strength = 0.0
var eye_y = 405.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

static func gap_for(vision: float, height: float) -> float:
	# vision .50 -> ~150 px slit, .62 -> ~260, .72 -> ~350, >=.97 -> no mask.
	return lerpf(130.0,height*1.05,smoothstep(.45,1.0,clampf(vision,0,1)))

func _process(delta: float) -> void:
	if battle==null or battle.match_model==null or battle.riders.is_empty():
		return
	var fighter: Dictionary = battle.match_model.fighters[0]
	var vision = float(fighter.stats.get("helmet_vision",1.0))
	var enabled = bool(GameState.profile.settings.get("helmet_view",true))
	var charging = battle.match_model.phase=="charge" and not bool(battle.get("is_finished"))
	var target = 1.0 if enabled and charging and vision<.97 and not bool(fighter.get("ko",false)) else 0.0
	strength = move_toward(strength,target,delta*(2.4 if target>strength else 3.2))
	if strength>0.0 and battle.world!=null:
		var head: Vector2 = Model.head_position(fighter)
		eye_y = (battle.world.get_global_transform_with_canvas()*head).y
	queue_redraw()

func _draw() -> void:
	if strength<=.001 or battle==null:
		return
	var fighter: Dictionary = battle.match_model.fighters[0]
	var vision = float(fighter.stats.get("helmet_vision",1.0))
	var slit = str(fighter.stats.get("helmet_slit","open"))
	var area = get_viewport_rect().size
	var gap = gap_for(vision,area.y)
	var top = clampf(eye_y-gap*.45,0,area.y)
	var bottom = clampf(eye_y+gap*.55,0,area.y)
	var dark = Color(.025,.027,.03,.88*strength)
	var feather = 34.0
	var clear = Color(dark.r,dark.g,dark.b,0.0)
	var upper_edge = maxf(0,top-feather)
	var lower_edge = minf(area.y,bottom+feather)
	draw_rect(Rect2(0,0,area.x,upper_edge),dark)
	draw_rect(Rect2(0,lower_edge,area.x,maxf(0,area.y-lower_edge)),dark)
	# Soft inner edges as one gradient each (art090-render01: stacked strips
	# showed banding). The slit reads as looking through, not a letterbox.
	draw_polygon(PackedVector2Array([Vector2(0,upper_edge),Vector2(area.x,upper_edge),Vector2(area.x,top),Vector2(0,top)]),PackedColorArray([dark,dark,clear,clear]))
	draw_polygon(PackedVector2Array([Vector2(0,bottom),Vector2(area.x,bottom),Vector2(area.x,lower_edge),Vector2(0,lower_edge)]),PackedColorArray([clear,clear,dark,dark]))
	# Faint steel edge of the sight; a great helm's slit edge is darker.
	var rim = Color(.45,.48,.50,.30*strength) if slit=="visor" else Color(.28,.30,.31,.40*strength)
	draw_line(Vector2(0,upper_edge),Vector2(area.x,upper_edge),rim,2.0)
	draw_line(Vector2(0,lower_edge),Vector2(area.x,lower_edge),rim,2.0)
