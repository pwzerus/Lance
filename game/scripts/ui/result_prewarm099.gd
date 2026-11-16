extends Label
## Actual glyph raster/upload behind the existing opaque preparation layer.
## Never hide text with alpha=0: that can skip rasterisation entirely.
const UI = preload("res://scripts/ui/ui_factory.gd")
const Activity = preload("res://scripts/core/window_activity.gd")
static var complete = false
var drawable_frames = 0
func _ready() -> void:
	theme=UI.theme()
	add_theme_font_size_override("font_size",42)
	text="你赢了 这场输了 平局"
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void:
	if Activity.suspended() or not is_visible_in_tree(): return
	drawable_frames+=1
	if drawable_frames>=2:
		complete=true
		hide()
		queue_free()
