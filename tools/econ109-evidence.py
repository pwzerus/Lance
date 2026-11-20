"""Index actual economy evidence without promoting partial runs to success."""
import hashlib
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
          'source_hashes': {}, 'runs': [], 'earned_segments': [], 'scope':
          'Protected isolated source-engine tests. Ledger/fault outcomes supplied to API; earned segments use actual battle outcomes and UI purchase/equip. No OS input, human skill/feel, hardware audio or new package acceptance.'}
for name in ('game_state', 'catalogue', 'campaign', 'horse_condition'):
    path = ROOT / f'game/scripts/core/{name}.gd'
    result['source_hashes'][path.relative_to(ROOT).as_posix()] = sha(path)
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
    for path in (directory / 'screens/report.json', directory / 'evidence/report.json'):
        if not path.exists():
            continue
        data = read(path)
        row.update({'report': path.relative_to(ROOT).as_posix(), 'report_sha256': sha(path),
                    'passed': data.get('passed'), 'failures': data.get('failures', [])})
        if 'routes' in data:
            row['ledger_routes'] = [{'route': r['route'], 'spent': r['spent'], 'first_clear_coins': r['first_clear_coins'],
                                     'first_clear_renown': r['first_clear_renown'], 'last_purse': r['rows'][-1]['coins_after']} for r in data['routes']]
        if not directory.name.startswith('econ109-earned'):
            continue
        if previous is not None:
            continuity.append({'segment': directory.name, 'initial_equals_previous_final': data['initial_profile'] == previous})
        previous = data['final_profile']
        purchases = [{'id': p['id'], 'price': p['price'], 'coins_before': p['coins_before'], 'coins_after': p['coins_after']} for p in data['purchases']]
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
formal = LOGS / 'econ109-formal-after01.json'
if formal.exists():
    before = {x['name']: (x['sha256'] if x['exists'] else 'absent') for x in read(LOGS / 'art108-formal-after01.json')}
    after = {x['name']: (x['sha256'] if x['exists'] else 'absent') for x in read(formal)}
    result['formal_profile_unchanged'] = before == after
    result['formal_evidence_sha256'] = sha(formal)
    if before != after:
        raise SystemExit('Formal profile mismatch: inspect, never overwrite')
out = ROOT / 'docs/development/ECON109_EVIDENCE.json'
out.write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print('ECON109 evidence:', len(result['runs']), 'runs;', len(result['earned_progress']['completed_levels']), 'earned clears;', len(earned_rows), 'matches')
