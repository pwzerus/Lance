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
    var max_toe_velocity = 0.0
    var toe_worst: Dictionary = {}
    var previous_model_phase = 0.0
    var max_phase_ratio = 0.0
    var min_phase_ratio = INF
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
      current.append({"position":foot,"contact":leg.contact,"toe_angle":leg.toe_angle,"cycle":leg.cycle})
      for key in ["hip","proximal","knee","ankle","foot"]:
       if not leg[key].is_finite():
        fail("Visual joint is non-finite: "+key)
      if not is_finite(leg.toe_angle):
       fail("Visual hoof angle is non-finite")
      if absf(leg.proximal.distance_to(leg.knee)-Gait.UPPER)>.1:
       fail("Visual upper limb stretched")
      if absf(leg.ankle.distance_to(leg.foot)-Gait.PASTERN.length())>.1:
       fail("Visual pastern stretched")
      if leg.foot.y>Gait.GROUND+.02:
       fail("Visual hoof penetrated ground")
      if absf(leg.knee.distance_to(leg.ankle)-Gait.LOWER)>.1:
       fail("Visual lower limb stretched")
      if leg.contact:
       contacts += 1
       if absf(leg.toe_angle)>.02:
        fail("Supporting hoof is tilted instead of flat")
       if absf(leg.foot.y-Gait.GROUND)>.02:
        fail("Visual support foot floated")
      if not previous_feet.is_empty():
       # Check the ACTUAL retimed cycle used by the rendered leg. Blending
       # nominal touchdown offsets must not rewind it or skip part of swing.
       var master_step = (float(f.gait_phase)-previous_model_phase)/TAU
       var cycle_step = fposmod(float(leg.cycle)-float(previous_feet[i].cycle),1.0)
       if master_step>0.000001 and master_step<.5:
        max_phase_ratio = maxf(max_phase_ratio,cycle_step/master_step)
        min_phase_ratio = minf(min_phase_ratio,cycle_step/master_step)
        if cycle_step<master_step*.75-.0001 or cycle_step>master_step*1.25+.0001:
         fail("Actual leg cycle rewound or jumped while retiming gait")
       var toe_velocity = absf(angle_difference(float(previous_feet[i].toe_angle),float(leg.toe_angle)))*hz
       if toe_velocity>max_toe_velocity:
        toe_worst = {"tick":tick,"seconds":seconds,"speed":f.speed,"leg":i,"cycle":leg.cycle,"swing":leg.swing,"angle":leg.toe_angle,"previous_angle":previous_feet[i].toe_angle,"contact":leg.contact,"previous_contact":previous_feet[i].contact}
       max_toe_velocity = maxf(max_toe_velocity,toe_velocity)
       var velocity = foot.distance_to(previous_feet[i].position)*hz
       if velocity>max_speed:
        worst = {"tick":tick,"seconds":seconds,"speed":f.speed,"leg":i,"cycle":leg.cycle,"swing":leg.swing,"foot":str(foot),"previous":str(previous_feet[i].position),"contact":leg.contact,"previous_contact":previous_feet[i].contact,"early_release":view.early_release[i]}
       max_speed = maxf(max_speed,velocity)
       if leg.contact and previous_feet[i].contact:
        max_locked_slide = maxf(max_locked_slide,absf(foot.x-previous_feet[i].position.x))
     previous_feet = current
     previous_model_phase = float(f.gait_phase)
    if max_locked_slide>.08:
     fail("Planted hoof slid during hold/release transitions")
    # Twelve radians/sec exceeds the authored smooth swing roll at all four
    # steady gaits, yet catches a half-radian one-tick hoof rotation pop.
    if max_toe_velocity>12.0:
     fail("Swing hoof angle jumped during gait/stance transition")
    if max_speed>2600:
     fail("Gait transitions caused a visible hoof discontinuity")
    rows.append({"horse":horse.id,"hz":hz,"facing":facing,"max_hoof_velocity":max_speed,"max_support_slide":max_locked_slide,"contact_samples":contacts,"worst":worst,"max_toe_velocity_rad_s":max_toe_velocity,"toe_worst":toe_worst,"min_actual_cycle_ratio":min_phase_ratio,"max_actual_cycle_ratio":max_phase_ratio})
    view.queue_free()
    await process_frame
 var report={"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"10 horses, both directions, 30/120Hz, repeated acceleration/deceleration, actual RiderView world-planted support and swing; not human quality rating"}
 var report_path = "E:/GALUMU/docs/development/logs/v045/transitions-01.json"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report-path="):
   report_path = arg.trim_prefix("--report-path=")
 DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
 var file=FileAccess.open(report_path,FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"\t"))
 file.close()
 print("TRANSITIONS_V045 ",report.passed," failures=",failures)
 quit(0 if failures.is_empty() else 1)



