"""Compact existing evidence; never launches engines or changes player saves."""
import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LOG = ROOT / 'docs/development/logs'

def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def read(p):
    return json.loads(p.read_text(encoding='utf-8-sig'))

def report(name):
    p = LOG / name
    if not p.exists():
        return {'path': name, 'status': 'not yet run'}
    data = read(p)
    out = {'path': name, 'sha256': digest(p)}
    for key in ('passed', 'failures', 'version', 'scope', 'all_frames', 'phases', 'wall_seconds', 'executable', 'mode', 'kit', 'blood'):
        if key in data:
            out[key] = data[key]
    if 'matches' in data:
        out['matches'] = len(data['matches'])
    if 'rows' in data:
        rows = data['rows']
        out['row_count'] = len(rows)
        if rows and 'result_frames' in rows[0]:
            out.update(first_result=rows[0]['result_frames'], max_result_ms=max(r['result_frames']['max_ms'] for r in rows), max_start_ms=max(r['start_ms'] for r in rows), resources=[r['resources'] for r in rows])
        if rows and 'max_point_error' in rows[0]:
            old = sum(r['old_us'] for r in rows)
            new = sum(r['new_us'] for r in rows)
            out.update(max_point_error=max(r['max_point_error'] for r in rows), old_total_us=old, new_total_us=new, integration_cost_reduction_percent=100*(old-new)/old)
    if 'battle' in data:
        out['camera'] = [{k:r[k] for k in ('case','cropped_frames','max_zoom','restored_time_scale') if k in r} for r in data['battle']]
    return out

def trace(name):
    p = LOG / name / 'trace.json'
    if not p.exists():
        return {'status': 'not yet run'}
    data = read(p)
    durations = {}
    for row in data['stages']:
        durations.setdefault(row['stage'], []).append((row['end_us']-row['start_us'])/1000)
    return {'sha256':digest(p), 'stages':{k:{'count':len(v),'max_ms':max(v),'mean_ms':sum(v)/len(v)} for k,v in durations.items()}, 'largest_spikes':sorted(data['spikes'], key=lambda r:r['gap_ms'], reverse=True)[:6]}

names = [
    'perf099-before01/report.json', 'perf099-deep01/report.json',
    'perf099-package01/report.json', 'perf099-result-before/report.json',
    'perf099-result-after03/report.json', 'perf099-result-after04/report.json',
    'perf099-result-package01/report.json', 'perf099-result-old02/report.json',
    'perf099-equivalence01.json', 'perf099-fall72.json',
    'perf099-timing057.json', 'perf099-controls.json', 'feel099-timing01.json',
    'feel099-camera03.json', 'feel099-camera-package01.json',
    'feel099-timing-package01.json', 'perf099-controls-package01.json',
    'perf099-ui01/report.json', 'perf099-preparation02/report.json',
]
guards = []
engines = []
for p in sorted(LOG.glob('*099*-memory.log')):
    s = p.read_text(encoding='utf-8-sig')
    private = [float(x) for x in re.findall(r'privateMiB=([\d.]+)', s)]
    ram = [int(x) for x in re.findall(r'availableRamMiB=(\d+)', s)]
    guards.append({'path':p.name,'sha256':digest(p),'memory_samples':len(private),'peak_private_mib':max(private,default=None),'min_system_available_mib':min(ram,default=None),'start':s.splitlines()[:1],'end':s.splitlines()[-2:]})
for p in sorted(LOG.glob('*099*-engine.log')):
    lines = p.read_text(encoding='utf-8-sig',errors='replace').splitlines()
    issues = [l for l in lines if re.search(r'(?i)(SCRIPT ERROR|ERROR:|WARNING:)',l)]
    engines.append({'path':p.name,'sha256':digest(p),'issues':issues})
package = ROOT/'builds/LanceAndLaurel-v0.4.52-c1'
manifest = read(package/'build-manifest.json')
bundle = {'version':manifest['version'],'source_revision':manifest['source_revision'],'manifest_sha256':digest(package/'build-manifest.json'),'files':manifest['files']}
out = {
    'generated_utc':datetime.now(timezone.utc).isoformat(),
    'baseline':'c27ce93668802be46f548e719f5c73ed9142657c',
    'scope':'Protected headless diagnostics and isolated rendered engine injection. No OS input or human play. Screenshot runs excluded from performance claims.',
    'limits':'Original 93.553ms event has not been reproduced or conclusively attributed. Deep source charge spikes are distinct from result/save. Do not claim all stutter eliminated.',
    'reports':[report(n) for n in names],
    'traces':{n:trace(n) for n in ['perf099-before01','perf099-deep01','perf099-package01']},
    'guards':guards,'engine_logs':engines,'package':bundle,
}
(ROOT/'docs/development/PERF099_EVIDENCE.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Wrote compact evidence; missing reports:',[r['path'] for r in out['reports'] if r.get('status')])
