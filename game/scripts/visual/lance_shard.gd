class_name LanceShard
extends Node2D

var length = 100.0
var source_start = 66.0
var full_length = 247.0
var pointed = false
var war_tip = false
var age = 0.0
var equipment: Dictionary = {}
const Lance = preload("res://scripts/visual/lance_art.gd")

func _process(delta: float) -> void:
	age += delta
	if age>4.0:
		get_parent().queue_free()
	modulate.a = clampf(4.0-age,0,1)

func _draw() -> void:
	Lance.draw_fragment(self,equipment,source_start,length,full_length,pointed,"war" if war_tip else "arena")
