"""Read actual c5 gameplay evidence; do not run the engine or alter QA saves."""
from pathlib import Path
import argparse
import hashlib
import json
import re
import statistics

ROOT = Path('E:/GALUMU')
LOGS = ROOT / 'docs/development/logs'
PCK = json.loads((ROOT / 'docs/development/DEV113_PACKAGE_C5.json').read_text(encoding='utf-8-sig'))['pck_sha256']


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1048576), b''):
            h.update(block)
    return h.hexdigest().upper()


def proof(directory):
    memory = (directory / 'memory.log').read_text(encoding='utf-8-sig')
    engine = (directory / 'engine.log').read_text(encoding='utf-8-sig')
    exit_rows = re.findall(r'EXIT code=(-?\d+) seconds=([\d.]+)', memory)
    values = [float(x) for x in re.findall(r'privateMiB=([\d.]+)', memory)]
    target = read(directory / 'target.json')
    expected_pck = PCK
    if directory.name.startswith('dev113-c5-'):
        meta = ROOT / 'docs/development/DEV113_PACKAGE_C5.json'
        expected_pck = read(meta)['pck_sha256'] if meta.exists() else None
    return {
        'exit_code': int(exit_rows[-1][0]) if exit_rows else None,
        'desktop_closed': 'QA_DESKTOP_CLOSED=True' in memory,
        'private_peak_mib': max(values) if values else None,
        'errors': [s for s in engine.splitlines() if 'ERROR:' in s or 'SCRIPT ERROR' in s],
        'warnings': [s for s in engine.splitlines() if 'WARNING:' in s],
        'correct_pck': expected_pck is not None and target.get('pck_sha256') == expected_pck,
        'report_sha256': digest(directory / 'screens/report.json'),
        'memory_sha256': digest(directory / 'memory.log'),
        'engine_sha256': digest(directory / 'engine.log'),
        'target_sha256': digest(directory / 'target.json'),
    }


def collect():
    ledger = {'coins': 520, 'renown': 0, 'matches': 0, 'purchases': 0, 'issues': []}
    score = {'arena': 0, 'war': 0, 'mismatches': [], 'duplicate_contacts': [], 'natural_losses': []}
    route = []
    previous = None
    # Serialized runs are chronological by their preserved end log. This also
    # retains genuine failed attempts before a same-save changed-input retry.
    directories = [p for p in LOGS.glob('dev113-c5-journey-*') if (p / 'screens/report.json').is_file()]
    for directory in sorted(directories, key=lambda p: (p / 'memory.log').stat().st_mtime_ns):
        report = read(directory / 'screens/report.json')
        if previous is not None and report['initial_profile'] != previous:
            ledger['issues'].append(directory.name + ': cross-process save differs')
        ledger['coins'] += sum(row['reward']['coins'] for row in report['rows']) - sum(p['price'] for p in report['purchases'])
        ledger['renown'] += sum(row['reward']['renown'] for row in report['rows'])
        ledger['matches'] += len(report['rows'])
        ledger['purchases'] += len(report['purchases'])
        previous = report['final_profile']
        for key in ('coins', 'renown', 'matches'):
            if ledger[key] != previous[key]:
                ledger['issues'].append(directory.name + ': independent ledger differs: ' + key)
        for row in report['rows']:
            result = row['result']
            if result['winner'] != 0:
                score['natural_losses'].append({'level': row['level'], 'attempt': row['attempt'], 'winner': result['winner']})
            score[result['mode']] += 1
            hits = [h for h in row['hits'] if h.get('type', 'hit') == 'hit' and int(h['attacker']) in (0, 1)]
            if result['mode'] == 'arena':
                totals = [sum(int(h['points']) for h in hits if int(h['attacker']) == side) for side in (0, 1)]
                if totals != [int(result['player_score']), int(result['enemy_score'])]:
                    score['mismatches'].append({'level': row['level'], 'attempt': row['attempt']})
            cells = [(int(h['attacker']), int(h.get('pass', 1))) for h in hits]
            if len(cells) != len(set(cells)):
                score['duplicate_contacts'].append({'level': row['level'], 'attempt': row['attempt']})
        route.append({'name': directory.name, 'passed': report['passed'], 'failures': report['failures'],
                      'segment_complete': report['completed_requested_segment'], 'first': report['first'], 'last': report['last'],
                      'clears': len(previous['campaign_cleared']), 'matches': len(report['rows']), 'purchases': len(report['purchases']),
                      'attempts': [{k: r[k] for k in ('level', 'attempt', 'strategy', 'result', 'reward')} for r in report['rows']],
                      'proof': proof(directory)})
    soaks = []
    configs = [('arena', 'starter', 0, False, True, True), ('war', 'starter', 1, True, True, True),
               ('war', 'heavy', 2, True, True, True), ('arena', 'heavy', 2, False, True, True),
               ('war', 'steady', 1, False, False, True), ('arena', 'french_light', 1, False, True, False),
               ('war', 'italian_plate', 2, False, True, True), ('war', 'english_late', 2, False, False, False)]
    issues = []
    soak_prefix = 'dev113-c5-soak'
    for n, config in enumerate(configs, 1):
        directory = LOGS / f'{soak_prefix}{n:02d}'
        if not (directory / 'screens/report.json').is_file():
            continue
        report = read(directory / 'screens/report.json')
        actual = tuple(report[k] for k in ('mode', 'kit', 'difficulty', 'blood')) + tuple(report['settings'][k] for k in ('slow_motion', 'shake'))
        if actual != config or report['wall_seconds'] < 360 or not report['matches']:
            issues.append(directory.name + ': configuration or duration differs')
        if n == 7 and report['window']['mode'] != 3:
            issues.append(directory.name + ': private fullscreen not active')
        saved = read(directory / 'screens/qa_profile.json')
        if saved['equipped'] != report['equipped'] or not set(saved['equipped'].values()) <= set(saved['owned']) or saved['matches'] < len(report['matches']):
            issues.append(directory.name + ': final QA equipment/results differ')
        state_counts = {'arena_deaths': 0, 'mounted_incapacitations': 0, 'living_unseated': 0, 'war_deaths': 0}
        for number, match in enumerate(report['matches'], 1):
            result = match['result']
            context = f'{directory.name} match {number}'
            out = []
            for side in ('player', 'enemy'):
                dead = bool(result[side + '_dead'])
                unseated = bool(result[side + '_unseated'])
                unconscious = bool(result[side + '_unconscious'])
                hp = float(result[side + '_hp'])
                out.append(dead or unseated or unconscious)
                state_counts['arena_deaths'] += int(dead and result['mode'] == 'arena')
                state_counts['war_deaths'] += int(dead and result['mode'] == 'war')
                state_counts['living_unseated'] += int(unseated and hp > 0 and not dead)
                state_counts['mounted_incapacitations'] += int(unconscious and not unseated)
                if dead and (result['mode'] != 'war' or hp > 0):
                    issues.append(context + ': invalid fatal state')
                if hp <= 0 and not unconscious:
                    issues.append(context + ': exhausted rider still conscious')
                if result['mode'] == 'war' and hp <= 0 and not dead:
                    issues.append(context + ': war exhaustion lacks fatal state')
            if result['reason'] == 'terminal':
                expected = -1 if out[0] == out[1] else (1 if out[0] else 0)
                if not any(out) or result['winner'] != expected:
                    issues.append(context + ': terminal winner differs from actual state')
            hits = [h for h in match['hits'] if h.get('type', 'hit') == 'hit' and int(h['attacker']) in (0, 1)]
            keys = [(int(h['attacker']), int(h.get('pass', 1))) for h in hits]
            if len(keys) != len(set(keys)):
                issues.append(context + ': repeated weapon contact in one pass')
            if result['mode'] == 'arena':
                totals = [sum(int(h['points']) for h in hits if int(h['attacker']) == side) for side in (0, 1)]
                if totals != [int(result['player_score']), int(result['enemy_score'])]:
                    issues.append(context + ': actual contact score differs')
        trends = {}
        for phase in sorted({s['phase'] for s in report['samples']}):
            samples = [s for s in report['samples'] if s['phase'] == phase]
            window = min(20, len(samples))
            trends[phase] = {key: {'min': min(s[key] for s in samples), 'max': max(s[key] for s in samples),
                                  'first_median': statistics.median(s[key] for s in samples[:window]),
                                  'last_median': statistics.median(s[key] for s in samples[-window:])}
                             for key in ('nodes', 'resources')}
        soaks.append({'name': directory.name, 'passed': report['passed'], 'failures': report['failures'],
                      'configuration': dict(zip(('mode', 'kit', 'difficulty', 'blood', 'slow_motion', 'shake'), actual)),
                      'seconds': report['wall_seconds'], 'matches': len(report['matches']), 'frames': report['all_frames'],
                      'phases': report['phases'], 'trends': trends, 'state_counts': state_counts, 'proof': proof(directory),
                      'qa_save_sha256': digest(directory / 'screens/qa_profile.json'),
                      'image_sha256': digest(directory / 'screens/after_timing.png')})
    after = ROOT / 'docs/development/DEV113_SAVE_AFTER.json'
    formal = {'unchanged': read(ROOT / 'docs/development/DEV113_SAVE_BEFORE.json') == read(after)} if after.exists() else {'unchanged': None}
    opening = None
    opening_dir = LOGS / 'dev113-c5-journey-01-05'
    if (opening_dir / 'screens/report.json').exists():
        report = read(opening_dir / 'screens/report.json')
        opening = {'candidate': '0.4.60-c5', 'passed': report['passed'], 'complete': report['completed_requested_segment'],
                   'clears': report['final_profile']['campaign_cleared'], 'matches': len(report['rows']),
                   'coins': report['final_profile']['coins'], 'renown': report['final_profile']['renown'], 'proof': proof(opening_dir)}
    return {'scope': 'All final campaign, HUD/state/fall gates and sustained configurations use actual c5. Historical c3/c4 evidence is separate. Protected isolated GPU, engine/viewport input, normal rewards and persistence. No OS input or human acceptance.',
            'journey_candidate': '0.4.60-c5', 'soak_prefix': soak_prefix, 'final_candidate_opening': opening,
            'journey': route, 'independent_ledger': ledger, 'score': score,
            'clears': len(previous['campaign_cleared']) if previous else 0,
            'all_80_cleared': previous is not None and {int(v) for v in previous['campaign_cleared']} == set(range(1, 81)),
            'soaks': soaks, 'soak_issues': issues, 'formal_save': formal,
            'measured_soak_seconds': sum(s['seconds'] for s in soaks),
            'completed_soak_matches': sum(s['matches'] for s in soaks),
            'limits': 'Each soak is a separate finite process; memory samples are not kernel high-water marks. Automated results do not certify enjoyment, naturalness, hardware hearing or another PC.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    result = collect()
    if args.write:
        (ROOT / 'docs/development/DEV113_FLOW_EVIDENCE.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: result[k] for k in ('clears', 'all_80_cleared', 'independent_ledger', 'score', 'soak_issues', 'formal_save', 'measured_soak_seconds', 'completed_soak_matches')}, ensure_ascii=False))
