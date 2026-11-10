extends "res://scripts/main.gd"
var costs={}
func record(key: String, start: int) -> void: costs[key]=float(costs.get(key,0))+(Time.get_ticks_usec()-start)/1000.0
func _clear_screen() -> void:
 var t=Time.get_ticks_usec();super._clear_screen();record("clear",t)
func _update_item_panel() -> void:
 var t=Time.get_ticks_usec();super._update_item_panel();record("detail",t)
func _add_item_icon(parent: Control,item: Dictionary,point: Vector2,dimensions: Vector2,deferred_card: bool=false) -> Control:
 var t=Time.get_ticks_usec();var n=super._add_item_icon(parent,item,point,dimensions,deferred_card);record("icons_deferred" if deferred_card else "icons_eager",t);return n
