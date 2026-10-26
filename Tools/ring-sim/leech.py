#!/usr/bin/env -S /opt/homebrew/bin/uv run --script --quiet --managed-python
# /// script
# requires-python = ">=3.10"
# dependencies = ["numpy", "pyarrow"]
# ///
"""Leech sizing on real review logs (anki-revlogs-10k) and on EF's own Mnemit decks.
Usage: leech.py [folder with user_id=<n>/data.parquet] [--mnemit <dir with a1a2.jsonl, a1a2.deck.json, b1.*>] [--no-anki] [--selftest]
Markdown on stdout. A lapse = rating 1 on a state-2 (Review) row, as Anki and FSRS count it; state-4 rows and ratings outside 1..4 are dropped.
Time = sum of duration capped at 60 s over all kept rows (every state). Rows are ordered by (day_offset, __index_level_0__) per card."""
import glob, json, os, sys
from multiprocessing import Pool
import numpy as np, pyarrow.parquet as pq

CAP, KS, TS, AGED, SIL, FU = 60.0, (4, 6, 8), (1, 2, 3, 4, 6, 8, 12, 16), 365, 90, 180
COLS = ['card_id', 'day_offset', 'rating', 'state', 'duration', '__index_level_0__']
NAN = float('nan')


def core(c):
    """c: numpy columns card_id, day_offset, rating, state, duration, __index_level_0__ -> small dict of counts and arrays for one user."""
    keep = (c['state'] != 4) & (c['rating'] >= 1) & (c['rating'] <= 4)
    if not keep.any():
        return None
    card, day, rat, st, dur, idx = (c[k][keep] for k in COLS)
    _, ci = np.unique(card, return_inverse=True)
    o = np.lexsort((idx, day, ci))  # card, then chronological
    ci, day, rat, st = ci[o], day[o], rat[o], st[o]
    sec = np.minimum(np.maximum(dur[o] / 1000.0, 0), CAP)
    n = int(ci[-1]) + 1
    starts = np.searchsorted(ci, np.arange(n)); cnt = np.diff(np.r_[starts, len(ci)]); ends = starts + cnt - 1
    pos = np.arange(len(ci)) - starts[ci]
    rev, rec = st == 2, rat > 1
    lap = rev & ~rec
    cs = np.cumsum(lap); incl = cs - (cs[starts] - lap[starts])[ci]; excl = incl - lap  # lapses up to / before this row, per card
    tot = incl[ends]
    rc = np.cumsum(rev); rrank = rc - (rc[starts] - rev[starts])[ci]  # rank among the card's Review rows
    end, first, last = day.max(), day[starts], day[ends]
    aged = end - first >= AGED
    silent = last <= end - SIL
    out = dict(drop=int((~keep).sum()), rows=len(ci), cards=n, aged=int(aged.sum()), sec=float(sec.sum()),
               rev_n=int(rev.sum()), rev_ok=int(rec[rev].sum()),
               thr=[int((tot >= t).sum()) for t in TS], thr_aged=[int((tot[aged] >= t).sum()) for t in TS],
               sil_aged={g: (int((aged & m).sum()), int((aged & m & silent).sum()))
                         for g, m in (('0', tot == 0), ('2-3', (tot >= 2) & (tot <= 3)), ('4+', tot >= 4), ('8+', tot >= 8))})
    for k in KS:
        ki = np.flatnonzero(lap & (incl == k)); kc = ci[ki]  # the k-th lapse row of each card that reaches k
        Rk = np.full(n, 1 << 30); Rk[kc] = rrank[ki]
        aft = rev & (excl >= k)
        nxt = rev & (rrank > Rk[ci]) & (rrank <= Rk[ci] + 5)
        bef = rev & (excl < k) & ~(lap & (incl == k)) & (tot[ci] >= k)
        dd = day[ki] - first[kc]; ra = cnt[kc] - pos[ki] - 1; fu = end - day[ki] >= FU
        out[k] = dict(n=len(ki), aft_n=int(aft.sum()), aft_ok=int(rec[aft].sum()), nxt_n=int(nxt.sum()), nxt_ok=int(rec[nxt].sum()),
                      bef_n=int(bef.sum()), bef_ok=int(rec[bef].sum()), later=int((rrank[ends][kc] > rrank[ki]).sum()),
                      t_all=float(sec[tot[ci] >= k].sum()), t_aft=float(sec[excl >= k].sum()),
                      days=dd, revs=pos[ki] + 1, after=ra, fu=fu, aged=aged[kc])
    return out


def load(p):
    try:
        t = pq.read_table(p, columns=COLS)
    except Exception:  # no index column: file order is chronological within a day
        t = pq.read_table(p, columns=COLS[:-1]); t = t.append_column('__index_level_0__', [np.arange(t.num_rows)])
    return core({k: t[k].to_numpy() for k in COLS})


def pc(a, b):
    return '%.2f%%' % (100 * a / b) if b else '-'


def q(a, ps=(50, 25, 75)):
    a = np.asarray(a, float); a = a[~np.isnan(a)]
    return [('%.4g' % x) for x in np.percentile(a, ps)] if len(a) else ['-'] * len(ps)


def table(head, rows):
    print('| ' + ' | '.join(head) + ' |\n|' + '---|' * len(head))
    for r in rows:
        print('| ' + ' | '.join(str(x) for x in r) + ' |')
    print()


def report(R):
    R = [r for r in R if r]
    S = lambda f: sum(f(r) for r in R)
    cards, aged = S(lambda r: r['cards']), S(lambda r: r['aged'])
    print('# Leech sizing on real review logs\n')
    print('Users %d, rows %d (dropped state 4 / bad rating: %d), cards %d, cards with >= %d d of history before the log end: %d. Time capped at 60 s per review.\n' % (
        len(R), S(lambda r: r['rows']), S(lambda r: r['drop']), cards, AGED, aged))
    print('### 1. Lapses per card at the end of the log (per-user columns: users with >= 100 cards)')
    big = [r for r in R if r['cards'] >= 100]; rows = []
    for i, t in enumerate(TS):
        sh = [r['thr'][i] / r['cards'] for r in big]
        rows.append(['>= %d' % t, pc(S(lambda r: r['thr'][i]), cards), pc(S(lambda r: r['thr_aged'][i]), aged)] + [x[:5] for x in q(100 * np.array(sh))] +
                    [pc(sum(r['thr'][i] > 0 for r in R), len(R))])
    table(['lapses', 'all cards, pooled', 'cards >= 365 d old, pooled', 'per-user median %', 'p25', 'p75', 'users with >= 1 such card'], rows)
    print('### 2. Recall (rating > 1) of Review-state reviews after the card reaches k lapses')
    rows = []
    for k in KS:
        d = [r[k] for r in R]; sub = [r for r in R if r[k]['n']]
        ro = S(lambda r: r['rev_ok'] if r[k]['n'] else 0); rn = S(lambda r: r['rev_n'] if r[k]['n'] else 0)
        diff = [100 * (r[k]['aft_ok'] / r[k]['aft_n'] - r['rev_ok'] / r['rev_n']) for r in sub if r[k]['aft_n'] >= 30]
        sm = lambda f: sum(f(x) for x in d)
        rows.append([k, sm(lambda x: x['n']), len(sub), pc(sm(lambda x: x['later']), sm(lambda x: x['n'])),
                     pc(sm(lambda x: x['aft_ok']), sm(lambda x: x['aft_n'])), sm(lambda x: x['aft_n']),
                     pc(sm(lambda x: x['nxt_ok']), sm(lambda x: x['nxt_n'])), sm(lambda x: x['nxt_n']),
                     pc(ro, rn), pc(sm(lambda x: x['bef_ok']), sm(lambda x: x['bef_n'])),
                     '%s (%s..%s) n=%d' % (*q(diff), len(diff))])
    table(['k', 'cards', 'users', 'with a later Review row', 'recall after k', 'reviews', 'recall, next 5', 'reviews', 'recall, all reviews of the same users',
           'recall, same cards before the k-th lapse', 'per-user median of (after - overall), pts (p25..p75)'], rows)
    print('### 3. Share of review time')
    rows = []
    tt = S(lambda r: r['sec'])
    for k in KS:
        ua = [r[k]['t_all'] / r['sec'] for r in big if r['sec']]; ub = [r[k]['t_aft'] / r['sec'] for r in big if r['sec']]
        rows.append(['>= %d' % k, pc(S(lambda r: r[k]['t_all']), tt), '%s%%' % q(100 * np.array(ua))[0], pc(S(lambda r: r[k]['t_aft']), tt), '%s%%' % q(100 * np.array(ub))[0],
                     pc(S(lambda r: r['thr'][TS.index(k)]), cards)])
    table(['cards with', 'all their time, pooled', 'per-user median', 'only time after the k-th lapse, pooled', 'per-user median', 'share of cards, pooled'], rows)
    print('### 4. Time from the first review to the k-th lapse')
    rows = []
    for k in KS:
        dd = np.concatenate([r[k]['days'] for r in R]); rv = np.concatenate([r[k]['revs'] for r in R])
        pu = [np.median(r[k]['days']) for r in R if len(r[k]['days']) >= 5]
        rows.append([k, len(dd)] + q(dd) + q(rv) + [q(pu)[0], len(pu)])
    table(['k', 'cards', 'days median', 'p25', 'p75', 'reviews median', 'p25', 'p75', 'per-user median of median days', 'users (>= 5 cards)'], rows)
    print('### 5. After the k-th lapse: did reviews go on? (reviews = rows of any state after the k-th lapse row)')
    rows = []
    for k in KS:
        ra = np.concatenate([r[k]['after'] for r in R]); fu = np.concatenate([r[k]['fu'] for r in R]); rf = ra[fu]
        rows.append([k, len(ra)] + q(ra) + [pc((ra == 0).sum(), len(ra)), pc((ra <= 2).sum(), len(ra)), len(rf), q(rf)[0], pc((rf == 0).sum(), len(rf)), pc((rf <= 2).sum(), len(rf))])
    table(['k', 'cards', 'median', 'p25', 'p75', 'none', '<= 2', 'cards with >= 180 d of follow-up', 'median', 'none', '<= 2'], rows)
    g = lambda name: (S(lambda r: r['sil_aged'][name][1]), S(lambda r: r['sil_aged'][name][0]))
    table(['cards >= 365 d old, by total lapses', 'cards', 'no review in the last 90 d of the log'], [[n, g(n)[1], pc(*g(n))] for n in ('0', '2-3', '4+', '8+')])


def mnemit(d):
    print('### 6. EF\'s own decks (Mnemit, read-only copies)')
    rows = []
    for name, f in (('Greek A1-A2', 'a1a2'), ('Greek B1', 'b1')):
        rv = [json.loads(l) for l in open(os.path.join(d, f + '.jsonl')) if l.strip()]
        deck = json.load(open(os.path.join(d, f + '.deck.json')))
        true = {c['id']: (c.get('learningState') or {}).get('lapses', 0) for c in deck['cards']}  # a never-reviewed card has no learningState
        by = {}
        for r in sorted(rv, key=lambda r: r['date']):
            by.setdefault(r['card'], []).append(r)
        apx = {c: sum(1 for a, b in zip(v, v[1:]) if b['grade'] == 1 and b['date'] - a['date'] > 86400) for c, v in by.items()}
        days = (max(r['date'] for r in rv) - min(r['date'] for r in rv)) / 86400
        a, t = np.array(list(apx.values())), np.array([true.get(c, 0) for c in by])
        rows.append([name, len(deck['cards']), len(rv), len(by), '%.1f' % days, '%d / %d / %d' % ((t >= 1).sum(), (t >= 2).sum(), (t >= 3).sum()),
                     '%d / %d / %d' % ((a >= 1).sum(), (a >= 2).sum(), (a >= 3).sum()), int(t.max()), int(a.max()), sum(1 for c in by if c not in true)])
    table(['deck', 'cards in deck', 'review lines', 'cards reviewed', 'days covered', 'deck.json lapses >= 1 / 2 / 3', 'approx. lapses >= 1 / 2 / 3', 'max true', 'max approx.', 'reviewed cards missing in deck.json'], rows)
    print('Approximation: grade 1 on a card whose previous logged review is more than 1 day (86400 s) earlier; deck.json `learningState.lapses` is the scheduler\'s own count and is exact.\n')


def selftest():
    r = [(0, 0, 0, 3), (0, 5, 2, 1), (0, 6, 3, 3), (0, 10, 2, 1), (0, 11, 3, 3), (0, 20, 2, 3), (0, 30, 2, 1), (0, 31, 3, 3), (0, 40, 2, 3), (0, 50, 2, 2),
         (1, 0, 0, 3), (1, 3, 2, 3), (1, 4, 4, 1)]  # (card, day, state, rating); the last row is state 4 and must vanish
    c = dict(card_id=np.array([x[0] for x in r]), day_offset=np.array([x[1] for x in r]), state=np.array([x[2] for x in r]), rating=np.array([x[3] for x in r]),
             duration=np.full(len(r), 90000), __index_level_0__=np.arange(len(r)))
    global KS
    o = core(c); k = o[4]; assert k['n'] == 0 and o['thr'][TS.index(2)] == 1 and o['thr'][TS.index(3)] == 1 and o['thr'][TS.index(4)] == 0, o['thr']
    assert o['cards'] == 2 and o['rows'] == 12 and o['drop'] == 1 and o['rev_n'] == 7 and o['rev_ok'] == 4 and o['sec'] == 12 * 60, o
    KS = (2,)  # k = 2 for the numbers worked out by hand
    k = core(c)[2]
    assert (k['n'], k['aft_n'], k['aft_ok'], k['nxt_n'], k['nxt_ok'], k['bef_n'], k['bef_ok']) == (1, 4, 3, 4, 3, 1, 0), k
    assert list(k['days']) == [10] and list(k['revs']) == [4] and list(k['after']) == [6] and k['later'] == 1, k
    assert k['t_all'] == 10 * 60 and k['t_aft'] == 6 * 60, k
    print('selftest ok')


if __name__ == '__main__':
    a = sys.argv[1:]
    if '--selftest' in a:
        selftest(); sys.exit()
    mn = a[a.index('--mnemit') + 1] if '--mnemit' in a else None
    rest = [x for x in a if x not in ('--mnemit', '--no-anki', mn)]
    root = os.path.expanduser(rest[0] if rest else '~/Library/Caches/anki-revlogs-10k')
    files = [] if '--no-anki' in a else sorted(glob.glob(os.path.join(root, 'user_id=*', 'data.parquet')))
    if files:
        with Pool(8) as p:
            res = p.map(load, files, chunksize=4)
        report(res)
    if mn:
        mnemit(os.path.expanduser(mn))
