"""Compact factual summaries of bounded campaign probes (stdlib only)."""
import argparse
import json
from pathlib import Path
from collections import Counter

p=argparse.ArgumentParser()
p.add_argument('reports',nargs='+')
p.add_argument('--out')
a=p.parse_args()
reports=[]
for name in a.reports:
    path=Path(name)
    doc=json.loads(path.read_text(encoding='utf-8-sig'))
    summary={'file':str(path),'complete':doc.get('complete',False),'passed':doc.get('passed'),
             'kit':doc.get('kit'), 'fixed_ai':doc.get('fixed_ai'),
             'fixed_gear':doc.get('fixed_gear'),'pace_override':doc.get('pace_override'),
             'levels':[],'failures':doc.get('failures',[])}
    for key,level in doc.get('levels',{}).items():
        rows=level.get('rows',[])
        if not rows:
            continue
        outcomes={}
        taken=Counter()
        falls=Counter()
        damage=[]
        actual_change_leads=[]
        side_wins=Counter()
        for row in rows:
            s=row['strategy']
            outcomes.setdefault(s,Counter())
            outcomes[s]['win' if row['winner']==0 else 'loss' if row['winner']==1 else 'draw']+=1
            if row['winner']==0:side_wins[str(row['side'])]+=1
            own_damage=0
            for hit in row['hits']:
                if not hit['player']:
                    taken[hit['zone']]+=1
                    own_damage+=hit['damage']
                    if hit['ko']:falls[hit.get('reason','')+':'+hit['zone']]+=1
            damage.append(own_damage)
            grouped={}
            for line in row['lines']:
                grouped.setdefault(line['pass'],[]).append(line)
            for pass_id,lines in grouped.items():
                contacts=[h['time'] for h in row['hits'] if h['pass']==pass_id]
                if not contacts:continue
                first=min(contacts)
                for line in lines[1:]:
                    if line['time']<first:actual_change_leads.append(round(first-line['time'],3))
        data={'level':int(key),'outcomes':outcomes,'side_wins':side_wins,
              'taken_zones':taken,'lost_by_fall':falls,'mean_damage':round(sum(damage)/max(1,len(damage)),2),
              'min_actual_change_lead':min(actual_change_leads,default=None),
              'changes_measured':len(actual_change_leads)}
        summary['levels'].append(data)
    reports.append(summary)
print(json.dumps(reports,ensure_ascii=False,indent=2))
if a.out:
    out=Path(a.out)
    if out.exists():raise SystemExit('Refusing to overwrite evidence')
    out.write_text(json.dumps(reports,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
