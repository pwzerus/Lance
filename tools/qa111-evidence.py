"""Summarize actual files, retaining failed and incomplete runs.

Does not run Godot, change results, infer human acceptance or touch player saves.
Use --write only after the separate final verification period is complete.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
LOGS = ROOT / 'docs/development/logs'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def digest(path):
    hasher = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1048576), b''):
            hasher.update(block)
    return hasher.hexdigest().upper()


def relative(path):
    return path.relative_to(ROOT).as_posix()


def collect(include_images=False):
    runs = []
    for directory in sorted(LOGS.glob('qa111-*')):
        memory_file = directory / 'memory.log'
        if not directory.is_dir() or not memory_file.is_file():
            continue
        memory = memory_file.read_text(encoding='utf-8-sig')
        engine_file = directory / 'engine.log'
        engine = engine_file.read_text(encoding='utf-8-sig') if engine_file.exists() else ''
        exits = re.findall(r'EXIT code=(\d+) seconds=([\d.]+)', memory)
        samples = [float(n) for n in re.findall(r'privateMiB=([\d.]+)', memory)]
        ram = [float(n) for n in re.findall(r'availableRamMiB=([\d.]+)', memory)]
        report_file = next((p for p in [directory / 'screens/report.json', directory / 'evidence/report.json', directory / 'report.json'] if p.is_file()), None)
        report = read(report_file) if report_file else {}
        expected_fault = "ERROR: Failed to open '%s/screens/blocked_backup'." % directory.as_posix()
        expected_errors = engine.count(expected_fault) if directory.name == 'qa111-save-ui01' else 0
        unexpected = engine.replace(expected_fault, 'EXPECTED STORAGE FAULT') if directory.name == 'qa111-save-ui01' else engine
        target_file = directory / 'target.json'
        entry = {
            'name': directory.name,
            'classification': 'Preserved early QA failure: fixed ten-frame armory wait raced the real bounded panel rebuild. Replaced only for the canonical earned route by a fresh replay from the exact completed level-5 checkpoint; no production change.' if directory.name == 'qa111-journey02' else 'Normal check; inspect actual scope and failures below.',
            'target': read(target_file) if target_file.is_file() else None,
            'exit_code': int(exits[-1][0]) if exits else None,
            'wall_seconds': float(exits[-1][1]) if exits else None,
            'private_peak_mib': max(samples) if samples else None,
            'minimum_available_ram_mib': min(ram) if ram else None,
            'isolated_desktop_closed': 'QA_DESKTOP_CLOSED=True' in memory,
            'passed': report.get('passed'),
            'failures': report.get('failures'),
            'completed_segment': report.get('completed_requested_segment'),
            'script_errors': unexpected.count('SCRIPT ERROR'),
            'unexpected_native_error_lines': len(re.findall(r'^ERROR:', unexpected, re.M)),
            'expected_storage_errors': expected_errors,
            'engine_log_bytes': engine_file.stat().st_size if engine_file.exists() else None,
            'scope': report.get('scope', report.get('evidence', 'Inspect the run-specific review; no implied visual or player acceptance.')),
            'report': relative(report_file) if report_file else None,
            'report_sha256': digest(report_file) if report_file else None,
            'performance': {'all_frames': report.get('all_frames'), 'phases': report.get('phases')},
        }
        if include_images:
            entry['images'] = [{'file': relative(p), 'sha256': digest(p)} for p in sorted(directory.glob('screens/*.png'))]
        runs.append(entry)

    journey = []
    ledger = {'coins': 520, 'renown': 0, 'matches': 0, 'purchases': 0, 'issues': []}
    score = {'arena_matches': 0, 'war_matches': 0, 'mismatches': [], 'duplicate_cells': [], 'natural_losses': []}
    previous = None
    for directory in sorted(LOGS.glob('qa111-journey[0-9][0-9]')):
        path = directory / 'screens/report.json'
        if not path.is_file():
            continue
        retry = directory.with_name(directory.name + '-retry01') / 'screens/report.json'
        if retry.is_file():
            path = retry
        report = read(path)
        if previous is not None and report['initial_profile'] != previous:
            ledger['issues'].append(directory.name + ': previous save differs from next initial profile')
        ledger['coins'] += sum(int(row['reward']['coins']) for row in report['rows']) - sum(int(row['price']) for row in report['purchases'])
        ledger['renown'] += sum(int(row['reward']['renown']) for row in report['rows'])
        ledger['matches'] += len(report['rows'])
        ledger['purchases'] += len(report['purchases'])
        for key in ['coins', 'renown', 'matches']:
            if ledger[key] != report['final_profile'][key]:
                ledger['issues'].append(directory.name + ': independent ' + key + ' ledger differs')
        for row in report['rows']:
            if int(row['result']['winner']) != 0:
                score['natural_losses'].append({'level': row['level'], 'attempt': row['attempt'], 'winner': row['result']['winner']})
            if row['result']['mode'] != 'arena':
                score['war_matches'] += 1
                continue
            score['arena_matches'] += 1
            totals = [sum(int(hit['points']) for hit in row['hits'] if int(hit['attacker']) == side) for side in [0, 1]]
            if totals != [int(row['result']['player_score']), int(row['result']['enemy_score'])]:
                score['mismatches'].append({'level': row['level'], 'attempt': row['attempt']})
            cells = [(int(hit['attacker']), int(hit.get('pass', 1))) for hit in row['hits']]
            if len(cells) != len(set(cells)):
                score['duplicate_cells'].append({'level': row['level'], 'attempt': row['attempt']})
        previous = report['final_profile']
        journey.append({'run': path.parent.parent.name, 'superseded_fixture_run': directory.name if path == retry else None, 'passed': report['passed'], 'completed': report['completed_requested_segment'], 'first': report['first'], 'last': report['last'], 'attempts': [{'level': r['level'], 'attempt': r['attempt'], 'winner': r['result']['winner'], 'reason': r['result']['reason'], 'reward': r['reward']} for r in report['rows']], 'navigation': report['navigation'], 'ui_waits': report.get('ui_waits', []), 'coins': previous['coins'], 'renown': previous['renown'], 'clears': len(previous['campaign_cleared']), 'purchases': len(report['purchases'])})

    timing_file = LOGS / 'qa111-phase-timing.json'
    after_file = LOGS / 'qa111-formal-after.json'
    before_file = LOGS / 'ux110-formal-after02.json'
    result = {
        'scope': 'Actual v0.4.59 candidate runtime/PCK with external QA drivers, background isolated GPU, engine/viewport input and explicitly identified fixtures. No OS input, human difficulty/feel/hearing or second-machine certification.',
        'memory_note': 'Private-byte one-second samples, not kernel high-water marks. Each process remains protected and serialized.',
        'timing': read(timing_file) if timing_file.is_file() else None,
        'runs': runs, 'journey': journey, 'independent_ledger': ledger, 'score_audit': score,
        'all_runs_closed': bool(runs) and all(row['exit_code'] is not None for row in runs),
        'actual_journey_complete': len(journey) == 16 and all(row['passed'] and row['completed'] for row in journey) and journey[-1]['clears'] == 80,
        'archive': read(LOGS / 'qa111-archive01.json'),
        'formal_save_check': {'before': relative(before_file), 'after': relative(after_file), 'unchanged': read(before_file) == read(after_file)} if after_file.is_file() else {'unchanged': None, 'reason': 'Final formal-save comparison not yet performed.'},
        'portable': read(LOGS / 'qa111-portable01/results.json') if (LOGS / 'qa111-portable01/results.json').is_file() else None,
        'limits': 'The original isolated 94 ms spike has not been uniquely attributed; evidence only supports measured cases. Background automation cannot establish player satisfaction, physical hardware audio, multi-DPI or store approval. Historical unrelated worktree changes remain preserved.',
    }
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    result = collect(args.write)
    if args.write:
        if not result['all_runs_closed'] or not result['actual_journey_complete'] or not result['timing']:
            raise SystemExit('Keep final evidence pending until runs, campaign and timing are complete.')
        if result['timing'].get('integration_seconds', 0) < 3600:
            raise SystemExit('The separate final verification hour is not complete.')
        (ROOT / 'docs/development/QA111_EVIDENCE.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'closed_segments': len(result['journey']), 'last_completed_level': result['journey'][-1]['last'] if result['journey'] else 0, 'ledger': result['independent_ledger'], 'score': result['score_audit'], 'active_runs': [row['name'] for row in result['runs'] if row['exit_code'] is None], 'unexpected_errors': [row['name'] for row in result['runs'] if row['script_errors'] or row['unexpected_native_error_lines']], 'reported_failures': [row['name'] for row in result['runs'] if row['passed'] is False], 'artifact_written': args.write}, ensure_ascii=False))
