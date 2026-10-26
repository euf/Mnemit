#!/usr/bin/env -S /opt/homebrew/bin/uv run --script --quiet --managed-python
# /// script
# requires-python = ">=3.10"
# dependencies = ["numpy", "pyarrow"]
# ///
"""Grade use on anki-revlogs-10k (first 2000 users). Usage: grades.py [folder] [--selftest]. Markdown on stdout.
Rows: state 4 and ratings outside 1..4 dropped; per card ordered by (day_offset, __index_level_0__). state 0 new, 1 learning, 2 review, 3 relearning."""
import glob, os, sys
from multiprocessing import Pool
import numpy as np, pyarrow.parquet as pq

COLS = ['card_id', 'day_offset', 'rating', 'state', '__index_level_0__']
EDGES = [1, 2, 7, 21, 61, 181]          # day-gap bins: 1 | 2-6 | 7-20 | 21-60 | 61-180 | 181+
BN = ['1d', '2-6d', '7-20d', '21-60d', '61-180d', '181d+']
NB = len(EDGES)
MINREV, TWO = 300, 0.05                 # users with >= MINREV review rows are classified; two-button = Hard+Easy < 5 %


def gbin(g):
    return np.searchsorted(EDGES, g, side='right') - 1


def core(c):
    keep = (c['state'] != 4) & (c['rating'] >= 1) & (c['rating'] <= 4)
    if not keep.any():
        return None
    card, day, rat, st, idx = (c[k][keep] for k in COLS)
    _, ci = np.unique(card, return_inverse=True)
    o = np.lexsort((idx, day, ci)); ci, day, rat, st = ci[o], day[o], rat[o], st[o]
    N = len(ci)
    out = {'by_state': np.array([[np.sum((st == s) & (rat == r)) for r in (1, 2, 3, 4)] for s in range(4)])}
    same_prev = np.r_[False, ci[1:] == ci[:-1]]
    pg = np.where(same_prev, day - np.r_[day[:1], day[:-1]], -1)          # gap to the previous row of the card
    r2 = np.flatnonzero(st == 2)
    if not len(r2):
        out['cells'] = np.zeros((NB, NB, 4, 2), np.int64); out['prevrate'] = np.zeros((NB, 4), np.int64); return out
    j = np.searchsorted(r2, np.arange(N), side='right')                  # first review-state row after i
    has = j < len(r2); jj = r2[np.minimum(j, len(r2) - 1)]
    has &= ci[jj] == ci
    ng = np.where(has, day[jj] - day, -1)
    rev = st == 2
    # recall by previous-gap bin among review rows (prev gap >= 1)
    m = rev & (pg >= 1)
    rb = np.zeros((NB, 4), np.int64)
    np.add.at(rb, (gbin(pg[m]), rat[m] - 1), 1)
    # cells: review row with prev gap >= 1 and a later review row >= 1 day on: [prev bin, next bin, rating] -> (n, next recalled)
    m2 = rev & (pg >= 1) & (ng >= 1)
    cells = np.zeros((NB, NB, 4, 2), np.int64)
    nrec = (rat[jj] > 1)[m2].astype(np.int64)
    np.add.at(cells, (gbin(pg[m2]), gbin(ng[m2]), rat[m2] - 1, 0), 1)
    np.add.at(cells, (gbin(pg[m2]), gbin(ng[m2]), rat[m2] - 1, 1), nrec)
    out['cells'] = cells
    out['prevrate'] = rb                                         # rating counts by prev-gap bin, review rows
    return out


def load(p):
    try:
        t = pq.read_table(p, columns=COLS)
    except Exception:
        t = pq.read_table(p, columns=COLS[:-1]); t = t.append_column('__index_level_0__', [np.arange(t.num_rows)])
    return core({k: t[k].to_numpy() for k in COLS})


def pc(a, b):
    return '%.1f%%' % (100 * a / b) if b else '-'


def table(head, rows):
    print('| ' + ' | '.join(head) + ' |\n|' + '---|' * len(head))
    for r in rows:
        print('| ' + ' | '.join(str(x) for x in r) + ' |')
    print()


def matched(cells, target, ref):
    """target rating's next-recall vs what `ref` rating gets in the same (prev bin, next bin) cells, weighted by the target's cell counts."""
    nt, kt = cells[..., target - 1, 0], cells[..., target - 1, 1]
    nr, kr = cells[..., ref - 1, 0], cells[..., ref - 1, 1]
    ok = (nt > 0) & (nr >= 20)
    if not ok.any():
        return None
    w = nt[ok]; return int(w.sum()), kt[ok].sum() / w.sum(), (w * kr[ok] / nr[ok]).sum() / w.sum()


def report(R):
    R = [r for r in R if r]
    print('# Grade use on real logs (users %d)\n' % len(R))
    bs = sum(r['by_state'] for r in R)
    print('### 1. Grade shares by state, all users pooled\n')
    table(['state', 'rows', 'Again', 'Hard', 'Good', 'Easy'],
          [[n, int(bs[s].sum())] + [pc(bs[s][k], bs[s].sum()) for k in range(4)] for s, n in enumerate(['0 new (first rating)', '1 learning', '2 review', '3 relearning'])])
    # per user
    U = []
    for r in R:
        a = r['by_state'][2]; n = int(a.sum())
        if n >= MINREV:
            U.append(dict(n=n, hard=a[1] / n, easy=a[3] / n, rec=(a[1] + a[2] + a[3]) / n, good=a[2] / n, again=a[0] / n, cells=r['cells'], a=a, prev=r['prevrate']))
    he = np.array([u['hard'] + u['easy'] for u in U]); print('### 2. Who is two-button (review-state rows, users with >= %d: %d)\n' % (MINREV, len(U)))
    hs, es = np.array([u['hard'] for u in U]), np.array([u['easy'] for u in U])
    q = lambda a: ' / '.join('%.1f' % (100 * x) for x in np.percentile(a, [25, 50, 75]))
    print('Share of review ratings, p25 / median / p75 over users: Hard %s %%, Easy %s %%, Hard+Easy %s %%.\n' % (q(hs), q(es), q(he)))
    table(['Hard+Easy share', 'users', 'share of users'], [[l, int(((he >= lo) & (he < hi)).sum()), pc(((he >= lo) & (he < hi)).sum(), len(U))] for l, lo, hi in
          [('< 1 %', 0, .01), ('< 5 %  (two-button)', 0, .05), ('5-10 %', .05, .10), ('10-25 %', .10, .25), ('>= 25 %', .25, 9)]])
    print('(the second row includes the first)\n')
    two = he < TWO; four = he >= 0.10
    print('### 3. Recall (rating > 1) in the review state\n')
    def grp(mask, name):
        a = sum(u['a'] for u, m in zip(U, mask) if m); n = a.sum()
        per = np.array([u['rec'] for u, m in zip(U, mask) if m])
        return [name, int(mask.sum()), int(n), pc(a[1:].sum(), n), pc(a[2:].sum(), n), '%.1f%%' % (100 * np.median(per)), pc(a[1], n), pc(a[3], n)]
    table(['group', 'users', 'review rows', 'recall pooled', 'recall, Hard counted as fail', 'recall, user median', 'Hard', 'Easy'],
          [grp(two, 'two-button (H+E < 5 %)'), grp((he >= .05) & (he < .10), '5-10 %'), grp(four, 'four-button (H+E >= 10 %)'), grp(np.ones(len(U), bool), 'all')])
    print('Recall by previous gap (review rows with gap >= 1 d), pooled:\n')
    rows = []
    for b in range(NB):
        rr = []
        for mask in (two, four):
            a = sum(u['prev'][b] for u, m in zip(U, mask) if m); rr += [pc(a[1:].sum(), a.sum()), int(a.sum())]
        rows.append([BN[b]] + rr)
    table(['previous gap', 'two-button recall', 'n', 'four-button recall', 'n'], rows)
    print('### 4. Hard by previous gap, and what the next review shows (review rows with prev gap >= 1 d and a later review row)\n')
    allc = sum(u['cells'] for u in U) if U else 0
    rows = []
    for b in range(NB):
        a = sum(u['prev'][b] for u in U)
        rows.append([BN[b], int(a.sum()), pc(a[1], a.sum()), pc(a[3], a.sum()), pc(a[0], a.sum())])
    table(['gap before', 'rows', 'Hard share', 'Easy share', 'Again share'], rows)
    print('Next-review recall after the grade, against Good in the same cells (previous-gap bin x next-gap bin, cells with >= 20 Good); Good-expected is weighted by the graded rows\' own cells.\n')
    def block(name, cellsum, bins):
        rows = []
        for g, gn in ((1, 'Again'), (2, 'Hard'), (4, 'Easy')):
            m = [matched(cellsum[bsel], g, 3) for bsel in bins]
            rows.append([gn] + [('%d: %.1f%% vs Good %.1f%%' % (x[0], 100 * x[1], 100 * x[2]) if x else '-') for x in m])
        return rows
    sel = [(slice(None)), (slice(0, 3)), (slice(3, 6))]
    head = ['grade', 'all prev gaps', 'prev gap < 21 d', 'prev gap >= 21 d']
    table(head, block('all', allc, sel))
    for lbl, mask in (('four-button users (H+E >= 10 %)', four), ('users with H+E 5-10 %', (he >= .05) & (he < .10))):
        c = sum(u['cells'] for u, m in zip(U, mask) if m)
        print('%s only:\n' % lbl); table(head, block(lbl, c, sel))
    # per user: target next-review recall minus Good in the same cells, by previous-gap class
    for g, gn in ((2, 'Hard'), (1, 'Again'), (4, 'Easy')):
        for lbl, sl in (('all prev gaps', slice(None)), ('prev gap < 21 d', slice(0, 3)), ('prev gap >= 21 d', slice(3, 6))):
            d = []
            for u in U:
                x = matched(u['cells'][sl], g, 3)
                if x and x[0] >= 50: d.append((x[1] - x[2]) * 100)
            print('Per user, %s vs Good in the same cells, %s (users with >= 50 matched rows: %d): p25 / median / p75 = %s points.\n' % (gn, lbl, len(d), ' / '.join('%.1f' % v for v in np.percentile(d, [25, 50, 75]))))


if __name__ == '__main__':
    a = sys.argv[1:]
    if '--selftest' in a:
        n = 6
        c = dict(card_id=np.array([1, 1, 1, 1, 1, 1]), day_offset=np.array([0, 3, 10, 30, 31, 100]), rating=np.array([3, 2, 3, 1, 3, 3]),
                 state=np.array([0, 2, 2, 2, 3, 2]), __index_level_0__=np.arange(n))
        o = core(c)
        assert o['by_state'][2].tolist() == [1, 1, 2, 0], o['by_state']
        # row 3 (Hard day 3): prev gap 3 -> bin 1, next review row day 10, gap 7 -> bin 2, next rating 3 recalled
        assert o['cells'][1, 2, 1].tolist() == [1, 1], o['cells'][1, 2, 1]
        # row 2 (Good day 10): prev gap 7 -> bin 2, next review day 30 (gap 20, bin 2), recalled? rating 1 -> not
        assert o['cells'][2, 2, 2].tolist() == [1, 0]
        # row 4 (Again day 30): prev gap 20 bin 2; next review state 2 is day 100 gap 70 bin 4, recalled
        assert o['cells'][2, 4, 0].tolist() == [1, 1]
        print('selftest ok'); sys.exit(0)
    root = os.path.expanduser(a[0] if a else '~/Library/Caches/anki-revlogs-10k')
    files = sorted(glob.glob(os.path.join(root, 'user_id=*', 'data.parquet')))
    with Pool(8) as p:
        R = p.map(load, files, chunksize=8)
    report(R)
