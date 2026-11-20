"""Summarize actual files, retaining failed and incomplete runs.

Does not run Godot, change results, infer human acceptance or touch player saves.
Use --write only after the separate final verification period is complete.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import statistics
from datetime import datetime

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
        # PowerShell Join-Path emits Windows separators, while Path.as_posix()
        # does not. Normalize only the comparison; retain the original log.
        normalized_engine = engine.replace('\\', '/')
        expected_errors = normalized_engine.count(expected_fault) if directory.name == 'qa111-save-ui01' else 0
        unexpected = normalized_engine.replace(expected_fault, 'EXPECTED STORAGE FAULT') if directory.name == 'qa111-save-ui01' else engine
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
            'measured_play_seconds': report.get('wall_seconds'),
            'configuration': {key: report.get(key) for key in ['mode', 'kit', 'difficulty', 'blood', 'settings', 'window']},
            'completed_matches': len(report.get('matches', [])) if isinstance(report.get('matches'), list) else None,
            'sample_trends': {},
        }
        # Compare like phases; an effect-heavy contact is not equivalent to an
        # empty ready screen. Trends remain evidence, not a hidden pass waiver.
        phase_samples = {}
        for sample in report.get('samples', []):
            if isinstance(sample, dict) and all(key in sample for key in ['phase', 'nodes', 'resources']):
                phase_samples.setdefault(sample['phase'], []).append(sample)
        for phase, samples_in_phase in phase_samples.items():
            window = min(20, len(samples_in_phase))
            entry['sample_trends'][phase] = {
                'samples': len(samples_in_phase),
                **{key: {
                    'minimum': min(row[key] for row in samples_in_phase),
                    'maximum': max(row[key] for row in samples_in_phase),
                    'first_median': statistics.median(row[key] for row in samples_in_phase[:window]),
                    'last_median': statistics.median(row[key] for row in samples_in_phase[-window:]),
                } for key in ['nodes', 'resources']},
            }
        if directory.name.startswith('qa111-final-') and exits:
            save_file = directory / 'screens/qa_profile.json'
            saved = read(save_file) if save_file.is_file() else {}
            equipped = report.get('equipped') or {}
            entry['final_qa_save'] = {
                'path': relative(save_file),
                'sha256': digest(save_file) if save_file.is_file() else None,
                'same_equipment': bool(equipped) and saved.get('equipped') == equipped,
                'owned_equipment_retained': bool(equipped) and set(equipped.values()).issubset(set(saved.get('owned', []))),
                'matches': saved.get('matches'),
                # A result may arrive during the explicitly excluded screenshot
                # frames. The in-engine test checks exact timing-sample saves.
                'covers_measured_results': saved.get('matches', -1) >= (entry['completed_matches'] or 0),
            }
        if include_images:
            entry['images'] = [{'file': relative(p), 'sha256': digest(p)} for p in sorted(directory.glob('screens/*.png'))]
        runs.append(entry)

    journey = []
    ledger = {'coins': 520, 'renown': 0, 'matches': 0, 'purchases': 0, 'issues': []}
    score = {'arena_matches': 0, 'war_matches': 0, 'mismatches': [], 'duplicate_cells': [], 'natural_losses': []}
    previous = None
    route = []
    for directory in sorted(LOGS.glob('qa111-journey[0-9][0-9]')):
        route.append(directory)
        # Segment 15 genuinely stopped after three losses at 75. Preserve those
        # losses, then append the changed-control continuation of the same save.
        if directory.name == 'qa111-journey15':
            continuation = LOGS / 'qa111-journey75-defense01'
            if (continuation / 'screens/report.json').is_file():
                route.append(continuation)
    for directory in route:
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
        journey.append({'run': path.parent.parent.name, 'superseded_fixture_run': directory.name if path == retry else None, 'passed': report['passed'], 'completed': report['completed_requested_segment'], 'first': report['first'], 'last': report['last'], 'attempts': [{'level': r['level'], 'attempt': r['attempt'], 'winner': r['result']['winner'], 'reason': r['result']['reason'], 'reward': r['reward'], 'high_guard': r.get('high_guard', False), 'low_line': r.get('low_line', False)} for r in report['rows']], 'navigation': report['navigation'], 'ui_waits': report.get('ui_waits', []), 'coins': previous['coins'], 'renown': previous['renown'], 'clears': len(previous['campaign_cleared']), 'purchases': len(report['purchases'])})

    expected_route = ['qa111-journey%02d' % n for n in range(1, 17)]
    expected_route[1] += '-retry01'
    expected_route.insert(15, 'qa111-journey75-defense01')
    complete_route = (
        [row['run'] for row in journey] == expected_route
        and all(row['passed'] for row in journey)
        and all(row['completed'] or (row['run'] == 'qa111-journey15' and row['clears'] == 74) for row in journey)
        and previous is not None
        and {int(n) for n in previous['campaign_cleared']} == set(range(1, 81))
        and not ledger['issues']
    )

    timing_file = LOGS / 'qa111-phase-timing.json'
    after_file = LOGS / 'qa111-formal-after.json'
    before_file = LOGS / 'ux110-formal-after02.json'
    integration_runs = [run for run in runs if run['name'].startswith('qa111-final-')]
    final_cases = {
        'starter-arena': ('starter', 'arena', 0, False, True, True, 480),
        'starter-war': ('starter', 'war', 1, True, True, True, 480),
        'french-light': ('french_light', 'arena', 2, False, False, True, 480),
        'italian-plate': ('italian_plate', 'war', 2, True, True, False, 480),
        'heavy-arena': ('heavy', 'arena', 2, False, True, True, 480),
        'english-late': ('english_late', 'war', 1, False, False, False, 480),
        'steady-arena': ('steady', 'arena', 1, False, True, True, 480),
        'heavy-fullscreen': ('heavy', 'war', 0, True, False, False, 240),
    }
    integration_issues = []
    for run in integration_runs:
        if run['exit_code'] is None:
            continue
        key = run['name'].removeprefix('qa111-final-').removesuffix('01')
        if key not in final_cases:
            integration_issues.append(run['name'] + ': unrecognized configuration')
            continue
        kit, mode, difficulty, blood, slow, shake, seconds = final_cases[key]
        actual = run['configuration']
        for field, expected in [('kit', kit), ('mode', mode), ('difficulty', difficulty), ('blood', blood)]:
            if actual.get(field) != expected:
                integration_issues.append(run['name'] + ': configuration differs: ' + field)
        settings = actual.get('settings') or {}
        if settings.get('slow_motion') != slow or settings.get('shake') != shake:
            integration_issues.append(run['name'] + ': slow/shake configuration differs')
        if key == 'heavy-fullscreen' and (actual.get('window') or {}).get('mode') != 3:
            integration_issues.append(run['name'] + ': fullscreen was not active')
        if (run['measured_play_seconds'] or 0) < seconds or not run['completed_matches']:
            integration_issues.append(run['name'] + ': measured duration or completed match missing')
        saved = run.get('final_qa_save') or {}
        if not all(saved.get(key) is True for key in ['same_equipment', 'owned_equipment_retained', 'covers_measured_results']):
            integration_issues.append(run['name'] + ': final QA save did not retain equipment or completed results')
    result = {
        'scope': 'Actual v0.4.59 candidate runtime/PCK with external QA drivers, background isolated GPU, engine/viewport input and explicitly identified fixtures. No OS input, human difficulty/feel/hearing or second-machine certification.',
        'memory_note': 'Private-byte one-second samples, not kernel high-water marks. Each process remains protected and serialized.',
        'timing': read(timing_file) if timing_file.is_file() else None,
        'runs': runs, 'journey': journey, 'independent_ledger': ledger, 'score_audit': score,
        'integration': {'runs': [run['name'] for run in integration_runs], 'measured_play_seconds': sum(run['measured_play_seconds'] or 0 for run in integration_runs), 'validation_issues': integration_issues},
        'all_runs_closed': bool(runs) and all(row['exit_code'] is not None for row in runs),
        'actual_journey_complete': complete_route,
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
        if len(result['integration']['runs']) != 8 or result['integration']['measured_play_seconds'] < 3600:
            raise SystemExit('The eight distinct post-stage configurations have not completed 60 minutes of measured play.')
        if result['integration']['validation_issues']:
            raise SystemExit('Post-stage configuration verification differs: ' + str(result['integration']['validation_issues']))
        if result['timing'].get('stage9_seconds', 0) < 5400:
            raise SystemExit('The Windows delivery stage has not reached its own 90-minute minimum.')
        timing = result['timing']
        stamps = {key: datetime.fromisoformat(timing[key].replace('Z', '+00:00')) for key in ['stage9_start_utc', 'stage9_end_utc', 'integration_start_utc', 'integration_end_utc']}
        if stamps['integration_start_utc'] < stamps['stage9_end_utc']:
            raise SystemExit('The separate final period overlaps stage 9.')
        for prefix in ['stage9', 'integration']:
            measured = (stamps[prefix + '_end_utc'] - stamps[prefix + '_start_utc']).total_seconds()
            if abs(measured - timing[prefix + '_seconds']) > 1:
                raise SystemExit('Recorded duration disagrees with UTC endpoints: ' + prefix)
        if result['independent_ledger']['issues'] or result['score_audit']['mismatches'] or result['score_audit']['duplicate_cells']:
            raise SystemExit('The actual earned campaign ledger or scoring still differs.')
        if result['formal_save_check'].get('unchanged') is not True:
            raise SystemExit('Final formal-save preservation has not been verified.')
        for run in result['runs']:
            target = run.get('target') or {}
            if target.get('target') == 'bundle' and target.get('pck_sha256') != '65A6B6D8FF9C4F3B1CEA5E1FBD68E5AA2563FDD50C84870252742884FC9C539C':
                raise SystemExit('Actual tested PCK differs from the sealed candidate: ' + run['name'])
            if run['name'] == 'qa111-save-ui01' and run['expected_storage_errors'] != 2:
                raise SystemExit('Expected storage-fault count differs from the two deliberate probes.')
            reviewed_timing_failure = run['name'] == 'qa111-journey02' and run['exit_code'] == 1 and set(run['failures'] or []) == {'Equip button enabled eng_lance_long_2', 'UI equip persists eng_lance_long_2'}
            if run['script_errors'] or run['unexpected_native_error_lines'] or (not reviewed_timing_failure and (run['exit_code'] != 0 or run['passed'] is False)):
                raise SystemExit('Unresolved run: ' + run['name'])
        if not result['portable'] or not all(probe['passed'] for probe in result['portable']):
            raise SystemExit('Portable launcher probes remain incomplete.')
        (ROOT / 'docs/development/QA111_EVIDENCE.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'closed_segments': len(result['journey']), 'cleared_level_count': result['journey'][-1]['clears'] if result['journey'] else 0, 'actual_journey_complete': result['actual_journey_complete'], 'ledger': result['independent_ledger'], 'score': result['score_audit'], 'active_runs': [row['name'] for row in result['runs'] if row['exit_code'] is None], 'unexpected_errors': [row['name'] for row in result['runs'] if row['script_errors'] or row['unexpected_native_error_lines']], 'reported_failures': [row['name'] for row in result['runs'] if row['passed'] is False], 'artifact_written': args.write}, ensure_ascii=False))
