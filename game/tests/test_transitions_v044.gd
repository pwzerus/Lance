extends SceneTree
const Model = preload("res://scripts/core/joust_match.gd")
const Rider = preload("res://scripts/visual/rider_view.gd")
const Gait = preload("res://scripts/visual/horse_gait.gd")
const Catalogue = preload("res://scripts/core/catalogue.gd")
var failures: Array[String] = []
var rows: Array = []

func _initialize() -> void:
 call_deferred("run")

func fail(message: String) -> void:
 if message not in failures:
  failures.append(message)

func run() -> void:
 var state = root.get_node("GameState")
 if not state.save_path.contains("qa_"):
  quit(1)
  return
 var horses: Array = []
 for item in Catalogue.load_items():
  if item.slot=="horse":
   horses.append(item)
 for horse in horses:
  for hz in [30,120]:
   for facing in [1,-1]:
    var model = Model.new("arena",horse.stats,horse.stats)
    model.phase = "charge"
    var index = 0 if facing==1 else 1
    var f = model.fighters[index]
    model.fighters[0].x = -100000
    model.fighters[1].x = 100000
    for fighter in model.fighters:
     fighter.acted = true
    var view = Rider.new()
    view.fighter = f
    view.moving = true
    root.add_child(view)
    view.set_process(false)
    var previous_feet: Array = []
    var max_speed = 0.0
    var worst: Dictionary = {}
    var max_locked_slide = 0.0
    var contacts = 0
    for tick in range(hz*14):
     var seconds = float(tick)/hz
     var urge = seconds<2.4 or (seconds>4.1 and seconds<4.9) or (seconds>6.2 and seconds<8.5) or (seconds>10 and seconds<11)
     model.set_controls(index,0,0,urge,1.0/hz,.43)
     model.step(1.0/hz)
     view.position = Vector2(f.x,f.lane_y)
     view._process(1.0/hz)
     var current: Array = []
     for i in range(4):
      var leg = view.leg_poses[i]
      var foot = Vector2(f.x+leg.foot.x*facing,leg.foot.y)
      current.append({"position":foot,"contact":leg.contact})
      if leg.foot.y>Gait.GROUND+.02:
       fail("Visual hoof penetrated ground")
      if absf(leg.knee.distance_to(leg.ankle)-Gait.LOWER)>.1:
       fail("Visual lower limb stretched")
      if leg.contact:
       contacts += 1
       if absf(leg.foot.y-Gait.GROUND)>.02:
        fail("Visual support foot floated")
      if not previous_feet.is_empty():
       var velocity = foot.distance_to(previous_feet[i].position)*hz
       if velocity>max_speed:
        worst = {"tick":tick,"seconds":seconds,"speed":f.speed,"leg":i,"cycle":leg.cycle,"swing":leg.swing,"foot":str(foot),"previous":str(previous_feet[i].position),"contact":leg.contact,"previous_contact":previous_feet[i].contact,"early_release":view.early_release[i]}
       max_speed = maxf(max_speed,velocity)
       if leg.contact and previous_feet[i].contact:
        max_locked_slide = maxf(max_locked_slide,absf(foot.x-previous_feet[i].position.x))
     previous_feet = current
    if max_locked_slide>.08:
     fail("Planted hoof slid during hold/release transitions")
    if max_speed>2600:
     fail("Gait transitions caused a visible hoof discontinuity")
    rows.append({"horse":horse.id,"hz":hz,"facing":facing,"max_hoof_velocity":max_speed,"max_support_slide":max_locked_slide,"contact_samples":contacts,"worst":worst})
    view.queue_free()
    await process_frame
 var report={"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"10 horses, both directions, 30/120Hz, repeated acceleration/deceleration, actual RiderView world-planted support and swing; not human quality rating"}
 var file=FileAccess.open("E:/GALUMU/docs/development/logs/v044/transitions-04.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"\t"))
 file.close()
 print("TRANSITIONS_V044 ",report.passed," failures=",failures)
 quit(0 if failures.is_empty() else 1)


