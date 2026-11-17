"""Read existing QA artifacts only; no engine launch or player-save access."""
import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
LOG=ROOT/'docs/development/logs'
def load(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
reports=[]
for name in ['level100-before.json','level100-after01.json','level100-ramp01.json','level100-rules01.json','level100-rules02.json','level100-ui01/report.json','level100-package-ui01/report.json','level100-package-rules01.json']:
    p=LOG/name
    if not p.exists():
        reports.append({'path':name,'status':'not run yet'});continue
    d=load(p);r={'path':name,'sha256':sha(p)}
    for key in ['passed','failures','scope','version','starter','legacy_compared']:
        if key in d:r[key]=d[key]
    if 'levels' in d:r['levels']={n:{'summary':v['summary'],'ai':v['level']['ai'],'equipment':v['level']['equipment']} for n,v in d['levels'].items()}
    if 'rows' in d:r['rows']=[{k:v for k,v in row.items() if k!='hits'} for row in d['rows']]
    reports.append(r)
guards=[];engines=[]
for p in sorted(LOG.glob('level100-*-memory.log')):
    s=p.read_text(encoding='utf-8-sig');samples=[float(v) for v in re.findall(r'privateMiB=([\d.]+)',s)]
    guards.append({'path':p.name,'sha256':sha(p),'samples':len(samples),'peak_private_mib':max(samples,default=None),'start':s.splitlines()[:1],'end':s.splitlines()[-2:]})
for p in sorted(LOG.glob('level100-*-engine.log')):
    lines=p.read_text(encoding='utf-8-sig',errors='replace').splitlines()
    engines.append({'path':p.name,'sha256':sha(p),'issues':[s for s in lines if re.search(r'ERROR:|WARNING:|SCRIPT ERROR',s)]})
package=ROOT/'builds/LanceAndLaurel-v0.4.53-c1'
manifest=load(package/'build-manifest.json')
out={'generated_utc':datetime.now(timezone.utc).isoformat(),'baseline':'f3db4660328083599f335bc62a7c99d25532a758','source_revision':manifest['source_revision'],'scope':'Protected headless rules and isolated rendered engine injection, no OS input or human play. Baseline timeout retained; only completed levels 1/2/3 counted. Source UI save assertion compared raw JSON float IDs with integer arrays; fixed to use production sanitize on re-read, package rerun recorded separately.','reports':reports,'guards':guards,'engine_logs':engines,'package':{'manifest_sha256':sha(package/'build-manifest.json'),'files':manifest['files']}}
(ROOT/'docs/development/LEVEL100_EVIDENCE.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Evidence written; pending:',[r['path'] for r in reports if r.get('status')])
