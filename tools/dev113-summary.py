"""Derive release metrics from completed c5 receipts; never runs the game."""
from pathlib import Path
import json

root = Path('E:/GALUMU')
docs = root / 'docs/development'
logs = docs / 'logs'


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


audit = read(docs / 'DEV113_FINAL_AUDIT.json')
flow = read(docs / 'DEV113_FLOW_EVIDENCE.json')
assert audit['passed'] and not audit['issues'], 'Final audit must actually pass first'
assert flow['all_80_cleared'] and len(flow['soaks']) == 8
result = read(logs / 'dev113-c5-result01/screens/report.json')
art = read(logs / 'dev113-c5-articulation01/screens/report.json')
incapacity = read(logs / 'dev113-c5-incapacity02/report.json')
slumps = [row['final_state']['slump'] for row in incapacity['battle'] if not row['final_state']['unseated']]
summary = {
    'candidate': '0.4.60-c5',
    'source_revision': audit['source_revision'],
    'final_gates': len(audit['gates']),
    'campaign_clears': flow['clears'],
    'campaign_matches': flow['independent_ledger']['matches'],
    'campaign_purchases': flow['independent_ledger']['purchases'],
    'campaign_coins': flow['independent_ledger']['coins'],
    'campaign_renown': flow['independent_ledger']['renown'],
    'natural_losses': flow['score']['natural_losses'],
    'campaign_living_unseated': flow['score']['living_unseated'],
    'campaign_positive_health_incapacitations': flow['score']['positive_health_incapacitations'],
    'soak_processes': len(flow['soaks']),
    'soak_seconds': flow['measured_soak_seconds'],
    'soak_matches': flow['completed_soak_matches'],
    'soak_frames': sum(row['frames']['frames'] for row in flow['soaks']),
    'soak_minimum_average_fps': min(row['frames']['fps'] for row in flow['soaks']),
    'soak_maximum_average_fps': max(row['frames']['fps'] for row in flow['soaks']),
    'soak_longest_frame_ms': max(row['frames']['max_ms'] for row in flow['soaks']),
    'soak_frames_over_33ms': sum(row['frames']['over_33ms'] for row in flow['soaks']),
    'soak_frames_over_50ms': sum(row['frames']['over_50ms'] for row in flow['soaks']),
    'soak_private_peak_mib': max(row['proof']['private_peak_mib'] for row in flow['soaks']),
    'final_gates_private_peak_mib': max(row['private_peak_mib'] or 0 for row in audit['gates']),
    'state_counts': {key: sum(row['state_counts'][key] for row in flow['soaks']) for key in flow['soaks'][0]['state_counts']},
    'result_replay_cycles': len(result['rows']),
    'maximum_synchronous_start_ms': max(row['start_ms'] for row in result['rows']),
    'maximum_result_frame_ms': max(row['result_frames']['max_ms'] for row in result['rows']),
    'result_frames_over_33ms': sum(row['result_frames']['over_33ms'] for row in result['rows']),
    'articulation_cases': len(art['cases']),
    'maximum_articulation_penetration_px': max(row['maximum_penetration'] for row in art['cases']),
    'maximum_bone_error_px': max(row['maximum_bone_error'] for row in art['cases']),
    'minimum_final_slump': min(slumps),
    'maximum_final_slump': max(slumps),
    'formal_save_unchanged': audit['formal_save_unchanged'],
    'scope': 'Eight separate finite sustained runs, not one continuous 48-minute process. Isolated GPU and explicit headless rule gates; engine input, no OS input or human acceptance. Frame and memory samples do not guarantee all-PC or unlimited-time stability.'
}
(docs / 'DEV113_SUMMARY.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(summary, ensure_ascii=False, indent=2))
