from pathlib import Path
import json,re,hashlib
root=Path(__file__).resolve().parents[1]
logroot=root/'docs/development/logs'
def sha(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for block in iter(lambda:f.read(1048576),b''):h.update(block)
 return h.hexdigest().upper()
known={'ux110-copy01':'Test guard treated the fixed protection marker as the actual Job budget; exited before assertions, fixed in copy02 without changing protection.', 'ux110-result-gallery01':'Archived JSON Array assigned to typed contact Array; isolated failed test child stopped and desktop cleaned; fixed with Array.assign in gallery02, presentation cleanup in gallery03.'}
runs=[]
for d in sorted(logroot.glob('ux110-*')):
 if not d.is_dir() or not (d/'memory.log').exists():continue
 mem=(d/'memory.log').read_text(encoding='utf-8-sig')
 engine=(d/'engine.log').read_text(encoding='utf-8-sig') if (d/'engine.log').exists() else ''
 exits=re.findall(r'EXIT code=(\d+) seconds=([\d.]+)',mem)
 peaks=[float(n) for n in re.findall(r'privateMiB=([\d.]+)',mem)]
 report_path=next((p for p in [d/'screens/report.json',d/'evidence/report.json'] if p.exists()),None)
 report=json.loads(report_path.read_text(encoding='utf-8-sig')) if report_path else {}
 images=[{'file':str(p.relative_to(root)).replace('\\','/'),'sha256':sha(p)} for p in sorted(d.glob('screens/*.png'))]
 runs.append({'name':d.name,'exit_code':int(exits[-1][0]) if exits else None,'wall_seconds':float(exits[-1][1]) if exits else None,'private_peak_mib':max(peaks) if peaks else None,'isolated_desktop_closed':'QA_DESKTOP_CLOSED=True' in mem,'passed':report.get('passed'),'completed_segment':report.get('completed_requested_segment'),'script_errors':engine.count('SCRIPT ERROR'),'native_error_lines':len(re.findall(r'^ERROR:',engine,re.M)),'classification':known.get(d.name,'Two deliberate exact blocked_backup copy errors; no unexpected script/native errors.' if d.name in ['ux110-save-ui01','ux110-save-ui02'] else 'Inspect actual report scope; engine or fixture evidence only.'),'scope':report.get('scope',report.get('evidence','Baseline observations / compilation as documented')),'report':str(report_path.relative_to(root)).replace('\\','/') if report_path else None,'report_sha256':sha(report_path) if report_path else None,'images':images})
journey=[]
ledger={"coins":520,"renown":0,"matches":0,"purchases":0,"issues":[]}
previous=None
score_audit={"arena_matches":0,"mismatches":[],"duplicate_cells":[],"natural_losses":[]}
for d in sorted(logroot.glob('ux110-journey[0-9][0-9]')):
 p=d/'screens/report.json'
 if not p.exists():continue
 r=json.loads(p.read_text(encoding='utf-8-sig'))
 if previous is not None and r['initial_profile']!=previous:ledger['issues'].append(d.name+' initial profile differs from previous saved segment')
 ledger['coins']+=sum(int(x['reward']['coins']) for x in r['rows'])-sum(int(x['price']) for x in r['purchases'])
 ledger['renown']+=sum(int(x['reward']['renown']) for x in r['rows'])
 ledger['matches']+=len(r['rows']);ledger['purchases']+=len(r['purchases'])
 for key in ['coins','renown','matches']:
  if ledger[key]!=r['final_profile'][key]:ledger['issues'].append(d.name+' independent '+key+' ledger mismatch')
 for row in r['rows']:
  if int(row['result']['winner'])!=0:score_audit['natural_losses'].append({'level':row['level'],'attempt':row['attempt'],'winner':row['result']['winner']})
  if row['result']['mode']!='arena':continue
  score_audit['arena_matches']+=1
  values=[sum(int(h['points']) for h in row['hits'] if int(h['attacker'])==side) for side in [0,1]]
  if values!=[int(row['result']['player_score']),int(row['result']['enemy_score'])]:score_audit['mismatches'].append({'level':row['level'],'attempt':row['attempt']})
  cells=[(int(h['attacker']),int(h.get('pass',1))) for h in row['hits']]
  if len(cells)!=len(set(cells)):score_audit['duplicate_cells'].append({'level':row['level'],'attempt':row['attempt']})
 previous=r['final_profile']
 journey.append({'run':d.name,'passed':r['passed'],'completed':r['completed_requested_segment'],'first':r['first'],'last':r['last'],'attempts':[{'level':x['level'],'attempt':x['attempt'],'winner':x['result']['winner'],'reason':x['result']['reason'],'reward':x['reward']} for x in r['rows']],'navigation':r['navigation'],'coins':r['final_profile']['coins'],'renown':r['final_profile']['renown'],'clears':len(r['final_profile']['campaign_cleared']),'purchases':len(r['purchases'])})
result={'memory_note':'Private-byte samples at one-second intervals, not kernel high-water marks; null means no sample.','scope':'UX110 source evidence. Automated viewport/button navigation and engine controls, not OS or human evidence; archived-result and layout fixtures explicitly identified. No final package acceptance here.','journey_snapshot':json.loads((logroot/'ux110-journey-source.json').read_text(encoding='utf-8')),'runs':runs,'journey':journey,'independent_ledger':ledger,'score_audit':score_audit,'all_runs_closed':all(x['exit_code'] is not None for x in runs),'actual_journey_complete':len(journey)==16 and all(x['passed'] and x['completed'] for x in journey) and journey[-1]['clears']==80,'remaining':'Final release/package and separate 60-minute integration must be documented in QA111.'}
before=json.loads((logroot/'econ109-formal-after02.json').read_text(encoding='utf-8-sig'))
after=json.loads((logroot/'ux110-formal-after02.json').read_text(encoding='utf-8-sig'))
assert before==after
result['formal_save_check']={'before':'docs/development/logs/econ109-formal-after02.json','after':'docs/development/logs/ux110-formal-after02.json','unchanged':True,'files':after}
(root/'docs/development/UX110_EVIDENCE.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'runs':len(runs),'journey_segments':len(journey),'all_closed':result['all_runs_closed'],'journey_complete':result['actual_journey_complete']}))
