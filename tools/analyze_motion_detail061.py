"""Inspect the largest joint changes in captured state, read-only."""
import json, math, sys
with open(sys.argv[1] + '/trace.jsonl', encoding='utf-8') as source:
    rows = [json.loads(line) for line in source]
for run in (0, 4):
    samples = [row for row in rows if row['run'] == run and row['tick'] > 120]
    for leg in range(4):
        pairs = sorted(zip(samples, samples[1:]), key=lambda ab: math.dist(ab[0]['legs'][leg]['knee'], ab[1]['legs'][leg]['knee']), reverse=True)
        print('run',run,'leg',leg)
        for a,b in pairs[:2]:
            print('change', round(math.dist(a['legs'][leg]['knee'],b['legs'][leg]['knee']),2))
            for s in (a,b):
                print(s['tick'], round(s['speed'],1), round(s['phase'],3), s['legs'][leg])
