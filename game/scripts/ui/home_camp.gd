extends Control
## Lightweight camp framing built from the existing palette and player arms.
## Draw once; the real equipped rider supplies the menu's idle movement.
const ShieldArt = preload("res://scripts/visual/shield_art.gd")
var equipment: Dictionary = {}
var banner_color = Color("416f8e")
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	# A pennant marks the player's side of the camp, clear of the horse/head.
	draw_line(Vector2(724,126),Vector2(724,436),Color("352e20"),7)
	draw_line(Vector2(723,128),Vector2(723,434),Color("b4965d"),2)
	draw_circle(Vector2(724,123),5,Color("d8bd7b"))
	var points=PackedVector2Array([Vector2(728,142),Vector2(785,142),Vector2(785,260),Vector2(756,246),Vector2(728,267)])
	draw_colored_polygon(points,banner_color.darkened(.35))
	draw_polyline(PackedVector2Array([Vector2(731,146),Vector2(781,146),Vector2(781,254)]),Color("bd9c5b"),2)
	if not equipment.is_empty(): ShieldArt.draw(self,equipment,Vector2(756,198),false,Color.WHITE,0,.42)
	# Small dividers make the left column read as a tournament programme.
	draw_line(Vector2(78,291),Vector2(630,291),Color(.67,.58,.36,.45),1)
	for x in [78,630]:
		draw_colored_polygon(PackedVector2Array([Vector2(x,287),Vector2(x+4,291),Vector2(x,295),Vector2(x-4,291)]),Color("bc9e64"))
