"""Index actual economy evidence without promoting partial runs to success."""
import hashlib
import datetime
import json
import pathlib
import re

ROOT = pathlib.Path('E:/GALUMU')
LOGS = ROOT / 'docs/development/logs'

def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()

result = {'task': 'ECON-109', 'baseline': '851600b7afadfc8ca59967e999ceb6f9db29ce21',
          'generated_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'source_hashes': {}, 'runs': [], 'earned_segments': [], 'heavy_comparison': [], 'real_replays': [], 'scope':
          'Protected isolated source-engine tests. Ledger/fault outcomes supplied to API; earned segments use actual battle outcomes and UI purchase/equip. No OS input, human skill/feel, hardware audio or new package acceptance.'}
for name in ('game_state', 'catalogue', 'campaign', 'horse_condition'):
    path = ROOT / f'game/scripts/core/{name}.gd'
    result['source_hashes'][path.relative_to(ROOT).as_posix()] = sha(path)
for path in sorted((ROOT / 'game/tests').glob('*109*.gd')):
    result['source_hashes'][path.relative_to(ROOT).as_posix()] = sha(path)
result['driver_revision_note'] = ('Current fixture hashes are final reproducibility references. During the natural route, '
    'purchase-only trace collection was added, followed by suppressing redundant _select_guard calls when the same '
    'slot was already selected. The latter changes only the click flash/sound and learned flag; guard targets, '
    '600ms decisions, finite motion, seeds and production rule code are unchanged. Historical evidence is retained.')
previous = None
coins = 520
renown = 0
earned_rows = []
transaction_count = 0
continuity = []
for directory in sorted(LOGS.glob('econ109-*')):
    memory = directory / 'memory.log'
    if not directory.is_dir() or not memory.exists():
        continue
    content = memory.read_text(encoding='utf-8-sig', errors='replace')
    exits = [line for line in content.splitlines() if line.startswith(('EXIT ', 'TIMEOUT', 'STOP', 'ABORT', 'QA_DESKTOP_CLOSED'))]
    peaks = [float(v) for v in re.findall(r'privateMiB=([0-9.]+)', content)]
    row = {'run': directory.name, 'memory_sha256': sha(memory), 'exit_lines': exits,
           'private_peak_mib': max(peaks) if peaks else None,
           'finished': any(v.startswith(('EXIT ', 'TIMEOUT', 'STOP', 'ABORT')) for v in exits)}
    engine = directory / 'engine.log'
    if engine.exists():
        text = engine.read_text(encoding='utf-8-sig', errors='replace')
        row['engine_issues'] = [line for line in text.splitlines() if any(v in line for v in ('ERROR:', 'SCRIPT ERROR', 'WARNING:'))]
        row['parse_result'] = [line for line in text.splitlines() if 'PARSE065_RESULT' in line]
    diagnostic_review = directory / 'diagnostic-review.json'
    if diagnostic_review.exists():
        row['diagnostic_review'] = read(diagnostic_review)
        row['diagnostic_review_sha256'] = sha(diagnostic_review)
    for path in (directory / 'screens/report.json', directory / 'evidence/report.json'):
        if not path.exists():
            continue
        data = read(path)
        row.update({'report': path.relative_to(ROOT).as_posix(), 'report_sha256': sha(path),
                    'passed': data.get('passed'), 'failures': data.get('failures', [])})
        if 'routes' in data:
            row['ledger_routes'] = [{'route': r['route'], 'spent': r['spent'], 'first_clear_coins': r['first_clear_coins'],
                                     'first_clear_renown': r['first_clear_renown'], 'last_purse': r['rows'][-1]['coins_after']} for r in data['routes']]
        if 'public_items' in data:
            row['public_item_count'] = len(data['public_items'])
            row['hidden_unowned_legacy'] = data['hidden_unowned_legacy']
            row['slot_counts'] = {slot: sum(x['slot'] == slot for x in data['public_items'])
                                  for slot in sorted({x['slot'] for x in data['public_items']})}
        if directory.name.startswith('econ109-recovery'):
            row['natural_recovery'] = {'purchases': data.get('purchases', []),
                'matches': [{k: x[k] for k in ('attempt', 'result', 'reward', 'coins_before', 'coins_after')}
                            for x in data.get('rows', [])], 'final_coins': data.get('final_profile', {}).get('coins')}
        if directory.name.startswith('econ109-heavy'):
            result['heavy_comparison'].append({'run': directory.name, 'first': data['first'], 'last': data['last'],
                'passed': data['passed'], 'completed_requested_segment': data['completed_requested_segment'],
                'initial_profile': data['initial_profile'], 'final_profile': data['final_profile'],
                'purchases': data['purchases'], 'matches': [{k: x[k] for k in
                 ('level', 'attempt', 'strategy', 'result', 'reward', 'coins', 'renown')} for x in data['rows']],
                'scope': 'Fork of genuinely earned first-five-level profile; subsequent purchases/results are real. Not independent re-earning of levels 1–5.'})
        if directory.name.startswith('econ109-replay'):
            result['real_replays'].append({'run': directory.name, 'first': data['first'], 'last': data['last'],
                'passed': data['passed'], 'completed_requested_segment': data['completed_requested_segment'],
                'initial_profile': data['initial_profile'], 'final_profile': data['final_profile'],
                'matches': [{k: x[k] for k in ('level', 'attempt', 'strategy', 'result', 'reward', 'coins', 'renown')}
                            for x in data['rows']],
                'scope': 'Actual replay from an exact fork of the earned 80-clear profile; no new first-clear reward.'})
        if not directory.name.startswith('econ109-earned'):
            continue
        if previous is not None:
            continuity.append({'segment': directory.name, 'initial_equals_previous_final': data['initial_profile'] == previous})
        previous = data['final_profile']
        purchases = [{'id': p['id'], 'price': p['price'], 'coins_before': p['coins_before'], 'coins_after': p['coins_after'],
                      'save_total_ms': [(x['end_us']-x['start_us'])/1000 for x in p.get('transaction_trace', [])
                                        if x['stage'] == 'save_total']} for p in data['purchases']]
        transaction_count += len(purchases)
        coins -= sum(p['price'] for p in purchases)
        cases = []
        for case in data['rows']:
            coins += case['reward']['coins']
            renown += case['reward']['renown']
            small = {'level': case['level'], 'attempt': case['attempt'], 'strategy': case['strategy'],
                     'winner': case['result']['winner'], 'reason': case['result']['reason'],
                     'reward': case['reward'], 'coins': case['coins'], 'renown': case['renown']}
            cases.append(small)
            earned_rows.append(small)
        result['earned_segments'].append({'run': directory.name, 'completed_requested_segment': data['completed_requested_segment'],
                                         'first': data['first'], 'last': data['last'], 'purchases': purchases, 'matches': cases,
                                         'final_coins': previous['coins'], 'final_renown': previous['renown'],
                                         'cleared': previous['campaign_cleared'],
                                         'ledger_matches_final': coins == previous['coins'] and renown == previous['renown']})
    result['runs'].append(row)
result['earned_progress'] = {'completed_levels': previous['campaign_cleared'] if previous else [],
                             'completed_matches': len(earned_rows), 'purchase_count': transaction_count,
                             'losses': [x for x in earned_rows if x['winner'] != 0],
                             'cross_process_continuity': continuity}
for key, source_run in [('heavy_comparison', 'econ109-earned01'), ('real_replays', 'econ109-earned16')]:
    source_path = LOGS / source_run / 'screens/report.json'
    if not source_path.exists():
        continue
    preceding = read(source_path)['final_profile']
    for segment in result[key]:
        segment['initial_matches_preceding_checkpoint'] = segment['initial_profile'] == preceding
        expected_coins = preceding['coins'] + sum(m['reward']['coins'] for m in segment['matches'])
        expected_coins -= sum(p['price'] for p in segment.get('purchases', []))
        expected_renown = preceding['renown'] + sum(m['reward']['renown'] for m in segment['matches'])
        segment['ledger_matches_final'] = (expected_coins == segment['final_profile']['coins']
                                          and expected_renown == segment['final_profile']['renown'])
        preceding = segment['final_profile']
formal = LOGS / 'econ109-formal-after02.json'
if not formal.exists():
    formal = LOGS / 'econ109-formal-after01.json'
if formal.exists():
    before = {x['name']: (x['sha256'] if x['exists'] else 'absent') for x in read(LOGS / 'art108-formal-after01.json')}
    after = {x['name']: (x['sha256'] if x['exists'] else 'absent') for x in read(formal)}
    result['formal_profile_unchanged'] = before == after
    result['formal_evidence_path'] = formal.relative_to(ROOT).as_posix()
    result['formal_evidence_sha256'] = sha(formal)
    if before != after:
        raise SystemExit('Formal profile mismatch: inspect, never overwrite')
out = ROOT / 'docs/development/ECON109_EVIDENCE.json'
out.write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print('ECON109 evidence:', len(result['runs']), 'runs;', len(result['earned_progress']['completed_levels']), 'earned clears;', len(earned_rows), 'matches')
