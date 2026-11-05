"""Read-only motion trace comparison; no image or project writes."""
import json, math, sys

for folder in sys.argv[1:]:
    with open(folder + '/trace.jsonl', encoding='utf-8') as source:
        rows = [json.loads(line) for line in source]
    print(folder)
    for run in range(5):
        samples = [row for row in rows if row['run'] == run and row['tick'] > 120]
        print('run', run, 'body span', round(max(s['body'][1] for s in samples)-min(s['body'][1] for s in samples), 2))
        for leg in range(4):
            knee, foot, jerk, slide = [], [], [], []
            for a, b in zip(samples, samples[1:]):
                x, y = a['legs'][leg], b['legs'][leg]
                knee.append(math.dist(x['knee'], y['knee']))
                foot.append(math.dist(x['foot'], y['foot']))
                if x['contact'] and y['contact']:
                    slide.append(abs(y['foot'][0]+b['x']-x['foot'][0]-a['x']))
            for a,b,c in zip(samples,samples[1:],samples[2:]):
                x,y,z=[s['legs'][leg]['knee'] for s in (a,b,c)]
                jerk.append(math.hypot(z[0]-2*y[0]+x[0],z[1]-2*y[1]+x[1]))
            print(leg, 'knee/foot', round(max(knee),2), round(max(foot),2), 'joint delta-v',round(max(jerk),2), 'slide',round(max(slide,default=0),3), 'limited',sum(s['legs'][leg]['limited'] for s in samples))
