"""Read-only release gates; --write saves a receipt, never runs or edits the game."""
from pathlib import Path
import argparse
import hashlib
import json
import re
import subprocess

ROOT = Path('E:/GALUMU')
DOCS = ROOT / 'docs/development'
LOGS = DOCS / 'logs'
GIT = Path('C:/Users/yifei/.cache/codex-runtimes/codex-primary-runtime/dependencies/native/git/mingw64/bin/git.exe')


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1048576), b''):
            h.update(chunk)
    return h.hexdigest().upper()


def audit():
    issues, rows = [], []
    meta = read(DOCS / 'DEV113_PACKAGE_C4.json')
    gates = 'incapacity01 incapacity02 condition01 head01 shield01 hud01 terminal01 articulation01 boot01 shield-visual01 cinema02 motion01 gallery01 save01 guide01 interruption01 result01 window01 journey01'.split()
    gates += [f'soak{n:02d}' for n in range(1, 9)]
    for gate in gates:
        directory = LOGS / ('dev113-c4-' + gate)
        paths = sorted(directory.rglob('report.json'))
        if len(paths) != 1 or not (directory / 'memory.log').exists():
            issues.append(gate + ': missing or ambiguous completed report')
            continue
        report = read(paths[0])
        memory = (directory / 'memory.log').read_text(encoding='utf-8-sig')
        engine = (directory / 'engine.log').read_text(encoding='utf-8-sig')
        target = read(directory / 'target.json')
        errors = [s for s in engine.splitlines() if s.startswith(('ERROR:', 'SCRIPT ERROR', 'WARNING:'))]
        # PowerShell's evidence directory is native Windows; the engine adds
        # a forward-slash suffix. Match this exact injected path, not all IO errors.
        deliberate = f"ERROR: Failed to open '{directory}/screens/blocked_backup'."
        backup_warning = "WARNING: SAVE_IO: 无法备份原进度 [12: Can't open file]"
        expected = [deliberate, backup_warning, deliberate, backup_warning] if gate == 'save01' else []
        exits = re.findall(r'EXIT code=(-?\d+) seconds=([\d.]+)', memory)
        headless = target.get('budget') == 'rules' and gate in ('condition01', 'head01', 'shield01')
        desktop_ok = ('OpenGL API' not in engine) if headless else 'QA_DESKTOP_CLOSED=True' in memory
        ok = (report.get('passed') is True and not report.get('failures') and
              bool(exits) and exits[-1][0] == '0' and desktop_ok and
              errors == expected and target.get('pck_sha256') == meta['pck_sha256'])
        if not ok:
            issues.append(gate + ': report, guarded exit, expected log or PCK mismatch')
        peaks = [float(v) for v in re.findall(r'privateMiB=([\d.]+)', memory)]
        rows.append({'gate': gate, 'passed': ok, 'verification': 'headless rules' if headless else 'isolated GPU',
                     'seconds': float(exits[-1][1]) if exits else None,
                     'private_peak_mib': max(peaks) if peaks else None,
                     'report': paths[0].relative_to(ROOT).as_posix(), 'report_sha256': sha(paths[0]),
                     'memory_sha256': sha(directory / 'memory.log'), 'engine_sha256': sha(directory / 'engine.log'),
                     'target_sha256': sha(directory / 'target.json'), 'expected_errors': expected})

    bundles = []
    for directory in (Path(meta['bundle']), Path(meta['relocation'])):
        manifest = directory / 'build-manifest.json'
        data = read(manifest)
        good = sha(manifest) == meta['manifest_sha256'] and data['source_revision'] == meta['source_revision']
        files = []
        for record in data['files']:
            path = (directory / record['path']).resolve()
            inside = path.is_relative_to(directory.resolve())
            valid = inside and path.is_file() and path.stat().st_size == record['bytes'] and sha(path) == record['sha256']
            files.append({'path': record['path'], 'passed': valid})
            good = good and valid
        if not good or len(files) != 9:
            issues.append(str(directory) + ': manifest mismatch')
        bundles.append({'directory': str(directory), 'passed': good, 'files': files})
    archive_ok = sha(Path(meta['archive'])) == meta['archive_sha256']
    if not archive_ok:
        issues.append('archive hash changed')

    portable_path = LOGS / 'dev113-portable01/results.json'
    portable = read(portable_path) if portable_path.exists() else []
    if len(portable) != 10 or not all(row.get('passed') is True for row in portable):
        issues.append('portable launcher probes incomplete or failed')
    outer_path = ROOT / 'logs/perf088/dev113-outer-c4-receipt.json'
    outer = read(outer_path) if outer_path.exists() else {}
    outer_memory = ROOT / 'logs/perf088/dev113-outer-c4-memory.log'
    outer_text = outer_memory.read_text(encoding='utf-8-sig') if outer_memory.exists() else ''
    if outer.get('passed') is not True or outer.get('exit') != 0 or 'QA_DESKTOP_CLOSED=True' not in outer_text:
        issues.append('actual relocated outer launcher GPU check incomplete or failed')

    after = DOCS / 'DEV113_SAVE_AFTER.json'
    unchanged = after.exists() and read(after) == read(DOCS / 'DEV113_SAVE_BEFORE.json')
    if not unchanged:
        issues.append('formal save receipt missing or differs')
    flow_path = DOCS / 'DEV113_FLOW_EVIDENCE.json'
    flow = read(flow_path) if flow_path.exists() else {}
    flow_ok = (flow.get('all_80_cleared') is True and not flow.get('independent_ledger', {}).get('issues', ['missing']) and
               not flow.get('score', {}).get('mismatches', ['missing']) and not flow.get('score', {}).get('duplicate_contacts', ['missing']) and
               len(flow.get('soaks', [])) == 8 and not flow.get('soak_issues', ['missing']) and
               flow.get('final_candidate_opening', {}).get('passed') is True)
    if not flow_ok:
        issues.append('campaign/sustained-run independent ledger incomplete or failed')
    runtime = subprocess.run([str(GIT), '-c', 'core.commitGraph=false', 'diff', '--name-only', meta['source_revision'], '--',
                              'game/scripts', 'game/data', 'game/assets', 'game/project.godot', 'game/export_presets.cfg'],
                             cwd=ROOT, capture_output=True, text=True, encoding='utf-8', check=True).stdout.splitlines()
    # These source sidecars were generated before the PCK was built, and are
    # being versioned at handoff. They do not change the shipped implementation.
    uid_receipt = read(DOCS / 'DEV113_UIDS.json')
    uid_allowed = {r['path']: r['sha256'] for r in uid_receipt['rows']
                   if r['path'] in ('game/scripts/core/horse_surface.gd.uid', 'game/scripts/core/rider_condition.gd.uid')}
    metadata = [name for name in runtime if name in uid_allowed and sha(ROOT / name) == uid_allowed[name]]
    runtime = [name for name in runtime if name not in metadata]
    if runtime:
        issues.append('production source changed after export')
    return {'task': 'DEV-113', 'candidate': '0.4.60-c4', 'source_revision': meta['source_revision'],
            'passed': not issues, 'issues': issues, 'gates': rows, 'bundles': bundles,
            'archive_unchanged': archive_ok, 'portable': portable, 'outer_gpu': outer,
            'formal_save_unchanged': unchanged, 'production_changes_since_export': runtime,
            'preexisting_uid_sidecars_now_versioned': metadata,
            'scope': 'Actual c4 PCK, protected isolated GPU or explicitly headless rules. C3 full campaign is separate. No OS input, human playtest or hardware hearing.',
            'preserved_failure': 'dev113-c4-cinema01 retains the invalid old double-fall fixture; cinema02 supersedes it without changing game physics.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    result = audit()
    if args.write:
        (DOCS / 'DEV113_FINAL_AUDIT.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'passed': result['passed'], 'issues': result['issues'], 'gates': len(result['gates'])}, ensure_ascii=False))
    raise SystemExit(0 if result['passed'] else 1)
