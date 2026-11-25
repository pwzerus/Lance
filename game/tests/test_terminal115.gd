extends "test_rules115.gd"
## One exchange can release two supports at different physical instants.
## Neither enumeration order nor the first visible fall decides it early.
func run115() -> void:
	var path=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):path=arg.trim_prefix("--report=")
	if path.is_empty() or FileAccess.file_exists(path) or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	items=Catalogue.load_items()
	var records=[]
	for reverse in [false,true]:
		var m=prepare115(0,-1,0)
		var order=[1,0] if reverse else [0,1]
		for index in order:
			var f:Dictionary=m.fighters[index]
			m.bodies115[index].queue_hit({"zone":"head","position":Model.head_position(f),"direction":-int(f.direction),"impulse":95.0 if index==0 else 70.0,"attacker":1-index})
		var times=[-1.0,-1.0];var end_count=0;var first={}
		for tick in range(480):
			if m.phase=="ended":m.advance_terminal_pose113(1.0/120.0)
			else:
				advance115(m,1.0/120.0)
				if m.fighters[0].ko or m.fighters[1].ko:
					m._finish("terminal");first=m.result.duplicate(true)
			for index in range(2):
				if m.fighters[index].unseated and times[index]<0:times[index]=(tick+1)/120.0
			for event in m.drain_events():
				if event.type=="end":end_count+=1
		check(times[0]>0 and times[1]>0,"Both committed blows physically release support")
		check(absf(float(times[0])-float(times[1]))>.008,"Fixture exercises distinct release times")
		check(end_count==1,"Late physical loss does not repeat terminal notification")
		check(m.result.winner==-1,"Two incapacitated riders from one exchange yield a draw")
		records.append({"reverse":reverse,"detach_times":times,"first_result":first,"final_result":m.result,"end_count":end_count})
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":records},"\t"))
	print("TERMINAL115 ",failures);quit(0 if failures.is_empty() else 1)
