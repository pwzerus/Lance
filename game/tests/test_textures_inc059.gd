extends SceneTree
const Art = preload("res://scripts/visual/equipment_art.gd")
func _initialize() -> void:
 var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://data/equipment_art_v051.json"))
 var report = []
 for id in manifest:
  var e = manifest[id]
  var t = load(e.image_path)
  var image = t.get_image()
  var slot = "helmet" if "helmet" in id else "armor"
  var atlas = Art.equipment_texture({slot+"_art":id},slot)
  assert(atlas != null)
  assert(Rect2(Vector2.ZERO,t.get_size()).encloses(atlas.region))
  assert(Art._textures.size()<=12)
  assert(image.get_width()<=512 and image.get_height()<=512)
  report.append({"id":id,"logical":str(t.get_size()),"physical":str(image.get_size()),"bytes":image.get_data_size()})
 var f = FileAccess.open("E:/GALUMU/docs/development/logs/inc059/textures.json",FileAccess.WRITE)
 f.store_string(JSON.stringify(report,"  "))
 quit()
