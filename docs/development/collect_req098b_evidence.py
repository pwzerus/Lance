"""Collect final REQ-098 evidence without editing or hiding raw test reports."""
from pathlib import Path
import argparse
import datetime as dt
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[2]
LOGS = ROOT / 'docs/development/logs'
START = '2026-11-16 18:44:38 UTC'
RUNTIME = '8b6135b1b14974f47a83a40f1586ffb4a93b0fb5'

def digest(path):
    value=hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda:source.read(1024*1024),b''): value.update(chunk)
    return value.hexdigest()

def report(name):
    path = LOGS / name
    raw = json.loads(path.read_text(encoding='utf-8-sig'))
    result = {'path': path.relative_to(ROOT).as_posix(), 'sha256': digest(path)}
    for key in ['passed', 'failures', 'shields', 'families', 'combinations', 'rendered',
                'sweep_pairs', 'scope', 'version', 'mode', 'kit', 'wall_seconds', 'all_frames', 'phases']:
        if key in raw: result[key] = raw[key]
    for key in ['rows', 'cases', 'matches']:
        if key in raw: result[key + '_count'] = len(raw[key])
    if 'samples' in raw:
        samples = raw['samples']
        result['first_sample'] = samples[0]
        result['last_sample'] = samples[-1]
    return result

def engine(name):
    path = LOGS / name
    lines = path.read_text(encoding='utf-8-sig', errors='replace').splitlines()
    errors = [line for line in lines if re.match(r'^(?:ERROR|SCRIPT ERROR|WARNING):', line)]
    return {'path': path.relative_to(ROOT).as_posix(), 'sha256': digest(path),
            'diagnostic_count': len(errors), 'first_diagnostics': errors[:6]}

def memory(name):
    path = LOGS / name
    values = re.findall(r'MEM seconds=([0-9.]+) privateMiB=([0-9.]+).*?availableRamMiB=([0-9.]+)',
                        path.read_text(encoding='utf-8-sig', errors='replace'))
    if not values: raise RuntimeError('No memory samples: ' + name)
    return {'path': path.relative_to(ROOT).as_posix(), 'sha256': digest(path),
            'peak_private_mib': max(float(row[1]) for row in values),
            'minimum_system_available_mib': min(float(row[2]) for row in values),
            'last_sample_seconds': float(values[-1][0])}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--finished-utc', required=True)
    args = parser.parse_args()
    start = dt.datetime.strptime(START, '%Y-%m-%d %H:%M:%S UTC').replace(tzinfo=dt.timezone.utc)
    end = dt.datetime.strptime(args.finished_utc, '%Y-%m-%d %H:%M:%S UTC').replace(tzinfo=dt.timezone.utc)
    if end > dt.datetime.now(dt.timezone.utc) or (end-start).total_seconds() < 45*60:
        raise RuntimeError('The actual additional 45 minutes have not finished')
    names = [f'req098b-{name}-final.json' for name in ['controls098','rules098','head098','contact098','fall098']]
    names += ['req098b-timing_v057-03.json','req098b-reaction075-02.json','req098b-arm068-02.json',
              'req098b-heraldry02/report.json','req098b-symbols03/report.json','req098b-ui01/report.json',
              'req098b-war-soak01/report.json','req098b-static01.json']
    package_names = [f'req098b-package-{name}.json' for name in ['rules098','head098','contact098','fall098','controls098','timing_v057']]
    package_names += ['req098b-package-arena01/report.json','req098b-package-war01/report.json','req098b-package-ui01/report.json',
                      'req098b-package-heraldry01/report.json','req098b-package-symbols01/report.json']
    checks = {name: report(name) for name in names + package_names}
    if any(item.get('passed') is False for item in checks.values()):
        raise RuntimeError('A final report failed')
    clean_runs = ['symbols03','war-soak01','ui01','parse065-final','import01','export01',
                  'package-rules098','package-head098','package-contact098','package-fall098',
                  'package-controls098','package-timing_v057','package-arena01','package-war01','package-ui01',
                  'package-heraldry01','package-symbols01']
    logs = {run: engine(f'req098b-{run}-engine.log') for run in clean_runs}
    if any(item['diagnostic_count'] for item in logs.values()):
        raise RuntimeError('A final engine log has diagnostics; review it before claiming clean')
    bundle = ROOT / 'builds/LanceAndLaurel-v0.4.51-c2'
    manifest = json.loads((bundle / 'build-manifest.json').read_text(encoding='utf-8-sig'))
    if manifest['source_revision'] != RUNTIME: raise RuntimeError('Unexpected runtime revision')
    for item in manifest['files']:
        if digest(bundle / item['path']).lower() != item['sha256'].lower():
            raise RuntimeError('Package integrity changed: ' + item['path'])
    balance = json.loads((LOGS / 'req098b-balance01.json').read_text())
    failures = {run: engine(f'req098b-{run}-engine.log') for run in ['shields01','symbols01','symbols02']}
    data = {'task':'REQ-098', 'status':'completed; human feel not certified',
            'baseline_revision':'ee7fe7bab50eaf97465d413c9787053db6003723', 'runtime_revision':RUNTIME,
            'additional_debug':{'start_utc':START,'end_utc':args.finished_utc,'seconds':(end-start).total_seconds()},
            'desktop_takeover':False,'os_input':False,'human_play':False,
            'protection':{'render_job_mib':1024,'render_early_stop_mib':900,'headless_diagnostic_job_mib':512,
                          'system_reserve_mib':500,'cpu_percent':25,'isolated_qa':True},
            'checks':checks,'current_40_match_balance':balance,'final_engine_logs':logs,
            'failed_runs_preserved_locally':failures,
            'memory':{run:memory(f'req098b-{run}-memory.log') for run in ['war-soak01','symbols03','import01','export01',
                                                                 'package-arena01','package-war01','package-ui01','package-heraldry01','package-symbols01']},
            'package':{'path':bundle.relative_to(ROOT).as_posix(),'manifest_sha256':digest(bundle/'build-manifest.json'),
                       'pck_bytes':(bundle/'runtime/LanceAndLaurel.pck').stat().st_size,
                       'pck_sha256':digest(bundle/'runtime/LanceAndLaurel.pck'),'files_verified':len(manifest['files'])},
            'limits':['Historical timing049 immediate-freeze contract is superseded by timing057, not claimed passing.',
                      'Background GPU and engine-injected controls are not human input or subjective feel certification.',
                      'Rare long frames are reported separately; average FPS is not a lock guarantee.',
                      'Raw engine/memory logs and most screenshots stay local; compact evidence and test sources are committed.']}
    target=ROOT/'docs/development/REQ098_COMPLETION_EVIDENCE.json'
    target.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'output':str(target),'checks':len(checks),'debug_seconds':data['additional_debug']['seconds'],
                      'package':data['package']},ensure_ascii=False))

if __name__ == '__main__': main()
