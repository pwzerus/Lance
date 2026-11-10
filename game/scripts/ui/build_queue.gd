extends Node
## Bounded UI construction on the main thread, owned by the current page.
const Activity=preload("res://scripts/core/window_activity.gd")
const BUDGET_USEC=2000
static var budget_frame=-1
static var spent_usec=0
var jobs: Array=[]
var first_frame=0
func _ready() -> void: first_frame=Engine.get_process_frames()+1
func enqueue(action: Callable, area: Control=null) -> void:
 jobs.append({"action":action,"area":area,"has_area":area!=null})
 set_process(true)
func _process(_dt: float) -> void:
 if Engine.get_process_frames()<first_frame or Activity.suspended(): return
 var ancestor=get_parent()
 while ancestor!=null:
  if ancestor.is_queued_for_deletion() or (ancestor is CanvasItem and not ancestor.is_visible_in_tree()):return
  ancestor=ancestor.get_parent()
 var frame=Engine.get_process_frames()
 if budget_frame!=frame:budget_frame=frame;spent_usec=0
 if spent_usec>=BUDGET_USEC:return
 var index=0
 while index<jobs.size():
  var job=jobs[index]
  if job.has_area and not is_instance_valid(job.area):jobs.remove_at(index);continue
  var visible=true
  if is_instance_valid(job.area):
   var clip=job.area.get_parent()
   while clip!=null:
    # Prepare the next row as well so keyboard focus/scrolling has no blank gap.
    if clip is ScrollContainer and not job.area.get_global_rect().intersects(clip.get_global_rect().grow_individual(0,140,0,140)):visible=false;break
    clip=clip.get_parent()
  if not visible:index+=1;continue
  jobs.remove_at(index)
  var start=Time.get_ticks_usec()
  if job.action.is_valid():job.action.call()
  spent_usec+=Time.get_ticks_usec()-start
  if spent_usec>=BUDGET_USEC:break
 if jobs.is_empty():set_process(false)
