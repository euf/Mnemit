#!/usr/bin/python3
# EF's grades on first showing (first log entry of a card) vs later. Reads the copies a1a2.jsonl, b1.jsonl beside it.
import json, os, collections, datetime
d = os.path.dirname(os.path.abspath(__file__))
N = {1: 'Forgot', 2: 'Hard', 3: 'Good', 4: 'Easy'}
def show(name, rows):
    c = collections.Counter(r['grade'] for r in rows); n = len(rows)
    print('%-28s n=%3d  ' % (name, n) + '  '.join('%s %d (%.0f%%)' % (N[g], c[g], 100 * c[g] / n if n else 0) for g in (1, 2, 3, 4))
          + '   Hard+Easy %.1f%%' % (100 * (c[2] + c[4]) / n if n else 0))
allr = []
for f in ('a1a2', 'b1'):
    rv = [json.loads(l) for l in open(os.path.join(d, f + '.jsonl')) if l.strip()]
    rv.sort(key=lambda r: r['date'])
    seen = set(); first = []; later = []
    for r in rv:
        (later if r['card'] in seen else first).append(r); seen.add(r['card'])
    print('==', f, 'cards', len(seen), 'span', datetime.date.fromtimestamp(rv[0]['date']), datetime.date.fromtimestamp(rv[-1]['date']),
          'modes', dict(collections.Counter(r.get('mode') for r in rv)))
    show('all', rv); show('first showing', first); show('later', later)
    allr += [(f, r) for r in rv]
rv = [r for _, r in allr]
by = collections.defaultdict(list)
for f, r in allr: by[(f, r['card'])].append(r)
first = [v[0] for v in by.values()]; later = [r for v in by.values() for r in v[1:]]
print('== both decks'); show('all', rv); show('first showing', first); show('later', later)
# later reviews after a gap > 1 day vs same day
gl = []; sd = []
for v in by.values():
    for a, b in zip(v, v[1:]):
        (gl if b['date'] - a['date'] > 86400 else sd).append(b)
show('later, gap > 1 day', gl); show('later, same day / <1 day', sd)
# ms
ms = sorted(r['ms'] for r in rv if r.get('ms'))
print('ms present on', len(ms), 'of', len(rv))
for g in (1, 2, 3, 4):
    m = sorted(r['ms'] for r in rv if r.get('ms') and r['grade'] == g)
    if m: print(N[g], 'median ms', m[len(m)//2], 'n', len(m))
