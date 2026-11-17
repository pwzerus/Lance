"""Compact measured campaign results; never turn proxy wins into human claims."""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[2]
LOG = ROOT / 'docs/development/logs'
NAMES = {
    'before': 'balance103-before.json',
    'equipment_only': 'balance103-after01.json',
    'pace_first': 'balance103-after02.json',
    'intermediate_broad': 'balance103-final.json',
    'pace_second': 'balance103-after04.json',
    'final': 'balance103-release.json',
    'counter': 'balance103-counter.json',
    'fixed_guard': 'balance103-fixed-guard.json',
    'rules': 'balance103-rules.json',
    'beginner': 'balance103-beginner.json',
    'controls': 'balance103-controls.json',
    'source_scene': 'balance103-source-scene/report.json',
    'text_fixed': 'balance103-text-fixed/report.json',
    'package_scene': 'balance103-package-scene/report.json',
    'package_beginner': 'balance103-package-beginner/report.json',
}
result = {'baseline': 'c7028aa08a7ccf03627aec5baabda6bde411844b',
          'version': '0.4.55-c1', 'reports': {}, 'memory': {},
          'scope': 'Protected background QA only. Rule proxies and engine input/rendering are not human difficulty or listening acceptance.'}
for name, relative in NAMES.items():
    path = LOG / relative
    if not path.exists():
        result['reports'][name] = {'not_run': True}
        continue
    data = json.loads(path.read_text(encoding='utf-8'))
    row = {'path': str(path.relative_to(ROOT)).replace('\\', '/'),
           'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
           'passed': data.get('passed'), 'failures': data.get('failures', []),
           'scope': data.get('scope', 'See review')}
    if 'levels' in data:
        row['levels'] = {}
        for n, level in data['levels'].items():
            if 'wins' not in level:
                row['levels'][n] = level.get('summary')
                continue
            row['levels'][n] = {'wins': level['wins'], 'losses': level['losses'],
                'draws': level['draws'], 'games': len(level['rows']),
                'kind': level['level']['archetype'], 'mode': level['level']['mode'],
                'equipment': level['level']['equipment'], 'ai': level['level']['ai'],
                'matches': [{k: r[k] for k in ['strategy', 'side', 'seed', 'winner', 'ended']} for r in level['rows']]}
            if name not in ['before', 'final', 'fixed_guard']:
                row['levels'][n].pop('matches')
    elif name == 'rules':
        row['approaches'] = data.get('rows')
    else:
        row['results'] = [{k: r[k] for k in ['level', 'winner', 'result', 'reward', 'lines'] if k in r} for r in data.get('rows', [])]
    result['reports'][name] = row
for path in sorted(LOG.glob('balance103-*-memory.log')):
    text = path.read_text(encoding='utf-8-sig')
    samples = [float(s) for s in re.findall(r'privateMiB=([\d.]+)', text)]
    result['memory'][path.name] = {'sampled_peak_mib': max(samples, default=None),
                                  'exit': re.findall(r'(?:EXIT|STOP|GUARD|TIMEOUT).*', text)[-1:]}
package = ROOT / 'builds/LanceAndLaurel-v0.4.55-c1'
pixels = LOG / 'balance103-text-pixels.json'
if pixels.exists():
    groups = {}
    pixel_rows = json.loads(pixels.read_text(encoding='utf-8-sig'))
    for r in pixel_rows:
        g = groups.setdefault(r['group']+'/'+str(r['cycle']), {})
        for name, metric in r['metrics'].items():
            g.setdefault(name, set()).add(metric['hash'])
    result['static_text_audit'] = {
        'path': str(pixels.relative_to(ROOT)).replace('\\', '/'),
        'sha256': hashlib.sha256(pixels.read_bytes()).hexdigest(),
        'frames': len(pixel_rows),
        'distinct_masks_per_sequence': {g: {n: len(v) for n, v in metrics.items()} for g, metrics in groups.items()},
        'passed': all(len(v)==1 for g in groups.values() for v in g.values()),
        'method': 'Original PNG RGB max>70 glyph masks: progress x326..512/y470..483; hint x846..903/y127..140; timeline x380..922/y277..400. Five consecutive frames per sequence, nine sequences. No image modifications.',
        'limitation': 'Stable masks contradict the apparent flicker in inline previews; they do not prove text completeness for every screen or all hardware.'}
manifest = package / 'build-manifest.json'
if manifest.exists():
    result['package'] = json.loads(manifest.read_text(encoding='utf-8-sig'))
    pck = package / 'runtime/LanceAndLaurel.pck'
    result['pck'] = {'bytes': pck.stat().st_size, 'sha256': hashlib.sha256(pck.read_bytes()).hexdigest()}
(ROOT / 'docs/development/BALANCE103_EVIDENCE.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print('Missing reports:', [k for k, v in result['reports'].items() if v.get('not_run')])
