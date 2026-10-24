class_name LanceShard
extends Node2D

const ATLAS = preload("res://assets/art/pixel_v03/rider_atlas.png")
var length = 100.0
var pointed = false
var war_tip = false
var age = 0.0

func _process(delta: float) -> void:
	age += delta
	if age>4.0:
		get_parent().queue_free()
	modulate.a = clampf(4.0-age,0,1)

func _draw() -> void:
	var half = length*.5
	draw_line(Vector2(-half,1),Vector2(half,1),Color("302318"),8,true)
	draw_line(Vector2(-half,0),Vector2(half,0),Color("bb8c50"),5.5,true)
	draw_line(Vector2(-half,-2),Vector2(half,-2),Color("dfbb76"),1.4,true)
	for offset in [-3.0,0.0,3.0]:
		draw_line(Vector2(-half,offset),Vector2(-half-8,offset-2),Color("e4c287"),1.5)
	if pointed:
		draw_texture_rect_region(ATLAS,Rect2(half-24,-7,24,14),Rect2(935,1048,298,87) if war_tip else Rect2(630,994,287,169))
