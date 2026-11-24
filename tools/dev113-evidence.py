"""Summarize preserved DEV-113 logs without discarding failed attempts."""
from pathlib import Path
import hashlib, json, re, sys

root = Path('E:/GALUMU')
output = root / 'docs/development/DEV113_EVIDENCE.json'
def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest().upper()

runs = []
logs = root / 'docs/development/logs'
folders = list(logs.glob('dev113-*'))
folders += list(logs.glob('dev113-export*/import')) + list(logs.glob('dev113-export*/export'))
for folder in sorted(folders):
    if not folder.is_dir():
        continue
    memory_path = folder / 'memory.log'
    engine_path = folder / 'engine.log'
    if not memory_path.exists():
        continue
    memory = memory_path.read_text(encoding='utf-8-sig', errors='replace')
    engine = engine_path.read_text(encoding='utf-8-sig', errors='replace') if engine_path.exists() else ''
    ends = re.findall(r'EXIT code=(-?\d+) seconds=([\d.]+)', memory)
    peaks = [float(x) for x in re.findall(r'privateMiB=([\d.]+)', memory)]
    row = {'name': folder.relative_to(logs).as_posix(), 'exit_code': int(ends[-1][0]) if ends else None,
           'wall_seconds': float(ends[-1][1]) if ends else None,
           'private_peak_mib': max(peaks) if peaks else None,
           'isolated_desktop_closed': 'QA_DESKTOP_CLOSED=True' in memory,
           'errors': [s for s in engine.splitlines() if 'ERROR:' in s or 'SCRIPT ERROR' in s],
           'warnings': [s for s in engine.splitlines() if 'WARNING:' in s],
           'memory_log_sha256': sha(memory_path),
           'engine_log_sha256': sha(engine_path) if engine_path.exists() else None,
           'png_count': sum(1 for _ in folder.rglob('*.png')), 'reports': []}
    target_path = folder / 'target.json'
    if target_path.exists():
        target = json.loads(target_path.read_text(encoding='utf-8-sig'))
        row['target'] = {k: target.get(k) for k in ['target', 'source_revision', 'pck_sha256', 'external_test', 'budget', 'extra']}
        row['target_sha256'] = sha(target_path)
    row['expected_errors'] = []
    if str(row.get('target', {}).get('external_test', '')).endswith('test_save_ui087.gd'):
        expected = "ERROR: Failed to open '" + folder.as_posix() + "/screens/blocked_backup'."
        if row['errors'].count(expected) == 2:
            row['expected_errors'] = [expected, expected]
    # Keep the raw error list; classify only the exact two deliberate backup
    # faults already asserted by the runner. Never suppress arbitrary errors.
    row['unexpected_errors'] = [s for s in row['errors'] if s not in row['expected_errors']]
    for path in sorted(folder.rglob('report.json')):
        report = json.loads(path.read_text(encoding='utf-8-sig'))
        result = {'path': path.relative_to(root).as_posix(), 'sha256': sha(path)}
        for key in ['passed', 'failures', 'version', 'scope', 'all_frames', 'wall_seconds', 'completed_requested_segment']:
            if key in report:
                result[key] = report[key]
        for key in ['matches', 'rows', 'cases', 'records', 'battle']:
            if isinstance(report.get(key), list):
                result[key + '_count'] = len(report[key])
        row['reports'].append(result)
    runs.append(row)

evidence = {'task': 'DEV-113', 'source_head_at_summary': (root / '.git/refs/heads/codex/v0.4').read_text().strip(),
            'scope': 'Preserved runs include failed and superseded fixtures. Interpret with DEV113_REVIEW.md; GPU is isolated, input is engine-injected, no OS input or human approval.',
            'runs': runs}
bundle = root / 'builds/LanceAndLaurel-v0.4.60-c4'
if not (bundle / 'build-manifest.json').exists():
    bundle = root / 'builds/LanceAndLaurel-v0.4.60-c3'
manifest = bundle / 'build-manifest.json'
if manifest.exists():
    evidence['bundle_manifest'] = json.loads(manifest.read_text(encoding='utf-8-sig'))
    evidence['bundle_manifest_sha256'] = sha(manifest)
output.write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'runs': len(runs), 'incomplete': [r['name'] for r in runs if r['exit_code'] is None],
                  'failed_engine_runs': [r['name'] for r in runs if r['exit_code'] not in (0, None) or r['unexpected_errors']],
                  'private_peak_mib': max((r['private_peak_mib'] or 0) for r in runs)}, ensure_ascii=False))
