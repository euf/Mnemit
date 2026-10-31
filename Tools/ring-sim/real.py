#!/usr/bin/env -S /opt/homebrew/bin/uv run --script --quiet --managed-python
# /// script
# requires-python = ">=3.10"
# dependencies = ["numpy", "pyarrow"]
# ///
"""Real-log statistics for the ring simulation: per-user numbers from anki-revlogs-10k, then their distribution across users.
Usage: real.py [folder with user_id=<n>/data.parquet (default ~/Library/Caches/anki-revlogs-10k)] [--selftest]
Markdown on stdout; saved as real-stats.md. Each review is capped at 60 s. A gap is a run of missed days between two study days."""
import glob, os, re, sys
from collections import Counter
import numpy as np, pyarrow.parquet as pq
from numpy.lib.stride_tricks import sliding_window_view as swv

CAP, NAN, MIN = 60.0, float('nan'), 1 / 60  # cap in s; floor of a day's minutes / the baseline median for ratios and logs (1 s)
GB, GN = [1, 2, 4, 8, 31], ['1', '2-3', '4-7', '8-30', '>30']          # missed-day runs
BB, BN = [0.5, 1, 1.5, 2], ['<0.5', '0.5-1', '1-1.5', '1.5-2', '>2']   # minutes / median of previous 14 study days
RB, RN = [4, 8, 15, 31], ['4-7', '8-14', '15-30']                       # return gaps 4-30 split
med = lambda a: float(np.median(a)) if len(a) else NAN
mean = lambda a: float(np.mean(a)) if len(a) else NAN

def prep(c):
    """c: dict of numpy columns sorted by day_offset (file order) -> adds capped seconds, study days, per-day minutes, card codes, first day per card."""
    u = dict(c)
    u['sec'] = np.minimum(np.maximum(c['duration'] / 1000.0, 0), CAP)
    u['days'], u['di'] = np.unique(c['day_offset'], return_inverse=True)
    u['mins'] = np.bincount(u['di'], weights=u['sec']) / 60
    _, u['ci'] = np.unique(c['card_id'], return_inverse=True)
    u['fd'] = c['day_offset'][np.unique(u['ci'], return_index=True)[1]]  # first review of each card (rows are day-sorted)
    n = len(u['days'])
    u['med14'] = np.full(n, NAN)  # median minutes of the 14 study days before study day j
    if n > 14:
        u['med14'][14:] = np.median(swv(u['mins'], 14)[:n - 14], axis=1)
    return u

def activity(u):
    d = u['days']; r = np.diff(d); r = r[r > 1] - 1; b = np.digitize(r, GB) - 1
    out = {'reviews': len(u['sec']), 'span': d[-1] - d[0] + 1, 'study_days': len(d), 'share': len(d) / (d[-1] - d[0] + 1), 'longest_gap': int(r.max()) if len(r) else 0}
    out.update({'gap ' + g: float((b == i).mean()) if len(r) else NAN for i, g in enumerate(GN)})
    out['P:gaprun'] = r
    return out

def daily(u):
    m = u['mins']; x = np.log(np.maximum(m, MIN)); n = len(m)
    ac = lambda k: float(np.corrcoef(x[:-k], x[k:])[0, 1]) if n >= 20 else NAN
    with np.errstate(all='ignore'):
        return {'min_med': med(m), 'min_p10': float(np.percentile(m, 10)), 'min_p90': float(np.percentile(m, 90)),
                'log_sd': float(x.std(ddof=1)) if n > 1 else NAN, 'ac_lag1': ac(1), 'ac_lag7': ac(7), 'P:daymins': m}

def prices(u):
    nd = len(u['days']); k, inv = np.unique(u['ci'] * nd + u['di'], return_inverse=True)  # one entry per (card, day)
    s = np.bincount(inv, weights=u['sec']); new = u['days'][k % nd] == u['fd'][k // nd]
    return {'new_med': med(s[new]), 'other_med': med(s[~new]), 'new_mean': mean(s[new]), 'other_mean': mean(s[~new]),
            'ratio_med': med(s[new]) / med(s[~new]) if (~new).any() else NAN, 'ratio_mean': mean(s[new]) / mean(s[~new]) if (~new).any() else NAN}

def newload(u):
    rel = u['day_offset'] - u['fd'][u['ci']]; out = {}
    for name, a, b in [('day 0 (incl. the first review)', 0, 0), ('days 1-7', 1, 7), ('days 8-30', 8, 30), ('days 31-90', 31, 90)]:
        ok = u['fd'] + b <= u['days'][-1]  # only cards whose window lies inside the log
        cnt = np.bincount(u['ci'][(rel >= a) & (rel <= b)], minlength=len(u['fd']))
        out['reviews/new card, ' + name] = mean(cnt[ok])
    return out

def fresh(u):
    d, s = u['day_offset'], u['state']; d0 = d[0]
    if s[0] != 0 or (s[d == d0] == 2).any() or u['days'][-1] - d0 < 13:
        return {}
    w = d < d0 + 14; sd = len(np.unique(d[w])); rel = u['days'] - d0; a, b = u['mins'][rel < 7], u['mins'][(rel >= 7) & (rel < 14)]
    return {'first14 min/study day': u['sec'][w].sum() / 60 / sd, 'first14 new cards/study day': (u['fd'] < d0 + 14).sum() / sd, 'first14 study days of 14': sd,
            'first14 median min, calendar days 1-7': med(a), 'first14 median min, calendar days 8-14': med(b), 'P:f1': a, 'P:f2': b}

def returns(u):
    d, m, b = u['days'], u['mins'], u['med14']
    g = np.diff(d) - 1; j = np.where((g >= 4) & (g <= 30))[0] + 1  # j: first study day back
    j = j[~np.isnan(b[j])]
    cnt = np.searchsorted(d, d[j] + 7, 'right') - (j + 1)  # study days among the next 7
    ratio = m[j] / np.maximum(b[j], MIN)
    return {'return ratio, user median (>=3 returns)': med(ratio) if len(j) >= 3 else NAN, 'P:ret_ratio': ratio, 'P:ret_gap': g[j - 1],
            'P:ret_back': np.where(d[j] + 7 <= d[-1], (cnt >= 5).astype(float), NAN)}

def bigdays(u):
    d, m, b = u['days'], u['mins'], u['med14']; n = len(d)
    j = np.arange(14, n - 1)  # the last study day has no known successor: censored
    k = np.digitize(m[j] / np.maximum(b[j], MIN), BB); gp = d[j + 1] - d[j] - 1
    nx, g7 = (gp == 0).astype(float), (gp >= 7).astype(float)
    out = {'P:big_bin': k, 'P:big_next': nx, 'P:big_g7': g7}
    for i, name in enumerate(BN):
        ok = k == i
        out['next day studied after %s' % name] = float(nx[ok].mean()) if ok.sum() >= 5 else NAN
        out['gap>=7 starts after %s' % name] = float(g7[ok].mean()) if ok.sum() >= 5 else NAN
    return out

NR, NN = [1, 2, 4, 8, 15], ['1', '2-3', '4-7', '8-14', '15-30']  # runs of study days without a new card

def novelty(u):
    """Days without a new card while the user is still learning new ones (some introduced in the previous 30 study days):
    what follows them, against days with new cards, by the size of the day and by the run of such days."""
    d, m, b = u['days'], u['mins'], u['med14']; n = len(d)
    new = np.bincount(np.searchsorted(d, u['fd']), minlength=n)
    j = np.arange(30, n - 1)  # 30 study days of history; the last study day has no known successor
    if not len(j):
        return {}
    c = np.concatenate([[0], np.cumsum(new > 0)]); active = c[j] - c[j - 30] > 0
    run = np.zeros(n, int)
    for i in range(n):
        run[i] = 0 if new[i] else (run[i - 1] + 1 if i else 1)
    j = j[active]; gp = d[j + 1] - d[j] - 1; none = new[j] == 0
    nx, g7, k = (gp == 0).astype(float), (gp >= 7).astype(float), np.digitize(m[j] / np.maximum(b[j], MIN), BB)
    out = {'P:nv_none': none, 'P:nv_next': nx, 'P:nv_g7': g7, 'P:nv_size': k, 'P:nv_run': np.where(none, np.digitize(run[j], NR), -1)}
    if none.sum() >= 10 and (~none).sum() >= 10:
        out['no-new minus new: P(next day)'] = nx[none].mean() - nx[~none].mean()
        out['no-new minus new: P(gap >= 7)'] = g7[none].mean() - g7[~none].mean()
        out['share of days without a new card'] = none.mean()
    return out

AGE_B, AGE_N = [4, 8, 26, 52], ['1-4', '5-8', '9-26', '27-52', '>52']  # weeks since the user's first review

def weekly(u):
    """Per week since the first review (only weeks with a review): answers, minutes, durable gain (answers passed, rating 2-4,
    21 or more days after the card's previous review), the review-state answers (state 2) and those passed, first answers of
    new cards (state 0) and those Again, the median seconds of an answer (the lower middle one)."""
    wi = (u['day_offset'] - u['day_offset'][0]) // 7; r, s = u['rating'], u['state']; bc = lambda x: np.bincount(wi, weights=x)
    out = {'answers': np.bincount(wi), 'minutes': bc(u['sec']) / 60, 'durable': bc((u['elapsed_days'] >= 21) & (r >= 2)),
           'rev': bc(s == 2), 'pass': bc((s == 2) & (r >= 2)), 'new': bc(s == 0), 'again new': bc((s == 0) & (r == 1))}
    n = out['answers']; o = np.lexsort((u['sec'], wi)); out['med sec'] = np.where(n > 0, u['sec'][o][np.cumsum(n) - n + np.maximum(n - 1, 0) // 2], NAN)
    c4 = lambda a: (lambda c: c - np.concatenate([np.zeros(4), c[:-4]]))(np.cumsum(a))  # the last 4 weeks, this one included
    out['rev4'], out['pass4'] = c4(out['rev']), c4(out['pass']); out['age'] = np.arange(len(out['answers']))
    act = out['answers'] > 0
    return {'P:wk_' + k: v[act] for k, v in out.items()}

STATS = (activity, daily, prices, newload, fresh, returns, bigdays, novelty, weekly)

def user(c):
    u = prep(c); out = {}
    for f in STATS:
        out.update(f(u))
    return out

def fmt(x):
    return '-' if x != x else '%d' % x if x == int(x) and abs(x) >= 1 else ('%.0f' % x if abs(x) >= 100 else '%.1f' % x if abs(x) >= 10 else '%.2f' % x if abs(x) >= 1 else '%.3f' % x)

def table(head, rows):
    print('| ' + ' | '.join(head) + ' |\n|' + '---|' * len(head))
    for r in rows:
        print('| ' + ' | '.join(str(x) for x in r) + ' |')
    print()

def dist(S, keys, title):
    print('### ' + title); rows = []
    for k in keys:
        v = np.array(S[k], float); v = v[~np.isnan(v)]
        rows.append([k, len(v)] + ([fmt(x) for x in np.percentile(v, [50, 10, 25, 75, 90])] if len(v) else ['-'] * 5))
    table(['statistic (per user)', 'N users', 'median', 'p10', 'p25', 'p75', 'p90'], rows)

def pooled_row(label, v):
    v = v[~np.isnan(v)]
    return [label, len(v)] + ([fmt(x) for x in np.percentile(v, [10, 25, 50, 75, 90])] if len(v) else ['-'] * 5)

def report(S, P, tally, ids, per):
    sec = lambda p: S[p]
    print('# Real review logs: ring-sim calibration statistics\n')
    print('Users: %d (%s). Reviews: %d. Ratings %s. States %s (0 New, 1 Learning, 2 Review, 3 Relearning, 4 Filtered; state 0 occurs only on a card\'s first review).' % (
        len(ids), 'user_id %d..%d' % (min(ids), max(ids)), tally['rows'], dict(sorted(tally['rating'].items())), dict(sorted(tally['state'].items()))))
    print('Durations: %d reviews (%.2f%%) exceed 60 s and are capped to 60 s; %d reviews have duration 0 (kept). Minutes = sum of capped durations per day.\n' % (
        tally['over'], 100 * tally['over'] / tally['rows'], tally['zero']))
    dist(S, ['span', 'study_days', 'share', 'longest_gap'] + ['gap ' + g for g in GN], '1. Activity (span and study_days in days; gap-x = share of the user\'s missed-day runs of length x)')
    r = np.concatenate(P['gaprun']); b = np.digitize(r, GB) - 1
    table(['missed-day run (days)', 'runs (pooled)', '% of runs', 'missed days', '% of missed days'], [
        [g, int((b == i).sum()), fmt(100 * (b == i).mean()), int(r[b == i].sum()), fmt(100 * r[b == i].sum() / r.sum())] for i, g in enumerate(GN)])
    dist(S, ['min_med', 'min_p10', 'min_p90', 'log_sd', 'ac_lag1', 'ac_lag7'], '2. Daily minutes on study days (log_sd and autocorrelations on ln minutes, consecutive study days; autocorrelation needs >= 20 study days)')
    mm = np.array(S['min_med'])
    table(['users whose median daily minutes are', 'share of users'], [['> %d' % t, fmt(100 * (mm > t).mean()) + '%'] for t in (30, 45, 60)] + [['< %d' % t, fmt(100 * (mm < t).mean()) + '%'] for t in (5, 2)])
    dm = np.concatenate(P['daymins'])
    table(['pooled over all study days', 'study days', 'share > 30 min', 'share > 60 min'], [['all users', len(dm), fmt(100 * (dm > 30).mean()) + '%', fmt(100 * (dm > 60).mean()) + '%']])
    dist(S, ['new_med', 'other_med', 'ratio_med', 'new_mean', 'other_mean', 'ratio_mean'], '3. Card prices: seconds per card-day (all reviews of the card that day), new = first review ever that day; ratio = new/other')
    dist(S, [k for k in S if k.startswith('reviews/new card')], '4. Load of new cards (mean reviews per introduced card; windows beyond the end of the user\'s log excluded)')
    dist(S, [k for k in S if k.startswith('first14')], '5. First 14 calendar days of fresh starts (first review state 0, no state-2 review on day one, log >= 14 days): %d users qualify' % len(S['first14 study days of 14']))
    table(['pooled study days of fresh starts', 'study days', 'median min', 'p25', 'p75', 'p90'], [[n, len(v)] + [fmt(x) for x in np.percentile(v, [50, 25, 75, 90])] for n, v in (('calendar days 1-7', np.concatenate(P['f1'])), ('calendar days 8-14', np.concatenate(P['f2'])))])
    print('### 6. Return after a gap of 4-30 missed days (needs 14 study days before the gap; "back" = >= 5 study days in the next 7, excludes returns within 7 days of the log end)')
    ra, ga, ba = np.concatenate(P['ret_ratio']), np.concatenate(P['ret_gap']), np.concatenate(P['ret_back'])
    rows = []
    for lab, k in [('all 4-30', ga >= 0)] + [(RN[i], np.digitize(ga, RB) - 1 == i) for i in range(3)]:
        bk = ba[k][~np.isnan(ba[k])]
        rows.append(pooled_row(lab, ra[k]) + [fmt(bk.mean()) if len(bk) else '-', len(bk)])
    table(['gap (days)', 'returns', 'p10', 'p25', 'median', 'p75', 'p90', 'share back (>=5 of 7)', 'n uncensored'], rows)
    dist(S, ['return ratio, user median (>=3 returns)'], 'Return ratio = minutes on the first day back / median daily minutes of the 14 study days before the gap')
    print('### 7. Big days: minutes / median of the previous 14 study days (>= 14 prior study days; last study day excluded, successor unknown)')
    k, nx, g7 = np.concatenate(P['big_bin']), np.concatenate(P['big_next']), np.concatenate(P['big_g7'])
    rows = []
    for i, name in enumerate(BN):
        a, c = np.array(S['next day studied after ' + name]), np.array(S['gap>=7 starts after ' + name])
        a, c = a[~np.isnan(a)], c[~np.isnan(c)]
        rows.append([name, int((k == i).sum()), fmt(nx[k == i].mean()), fmt(g7[k == i].mean()), len(a), fmt(np.median(a)) if len(a) else '-', fmt(np.median(c)) if len(c) else '-'])
    table(['bin', 'user-days (pooled)', 'P(next day studied), pooled', 'P(gap >= 7 starts), pooled', 'users (>= 5 days in bin)', 'P(next day), user median', 'P(gap >= 7), user median'], rows)
    print('### 8. Days without a new card while still learning (some new card in the previous 30 study days; >= 30 study days of history; last study day excluded)')
    none, nx, g7, k, rn = (np.concatenate(P['nv_' + x]) for x in ('none', 'next', 'g7', 'size', 'run'))
    rows = [[lab, int(sel.sum()), fmt(nx[sel].mean()), fmt(g7[sel].mean())] for lab, sel in [('with new cards', ~none), ('without a new card', none)]]
    rows += [['without, size ' + name, int((none & (k == i)).sum()), fmt(nx[none & (k == i)].mean()), fmt(g7[none & (k == i)].mean())] for i, name in enumerate(BN)]
    rows += [['with, size ' + name, int((~none & (k == i)).sum()), fmt(nx[~none & (k == i)].mean()), fmt(g7[~none & (k == i)].mean())] for i, name in enumerate(BN)]
    rows += [['without, run of ' + name, int((rn == i + 1).sum()), fmt(nx[rn == i + 1].mean()), fmt(g7[rn == i + 1].mean())] for i, name in enumerate(NN)]
    table(['study days (pooled)', 'days', 'P(next day studied)', 'P(gap >= 7 starts)'], rows)
    dist(S, ['share of days without a new card', 'no-new minus new: P(next day)', 'no-new minus new: P(gap >= 7)'], 'Per user (>= 10 days of each kind): the same, without a new card minus with')
    competition(P)
    appendix(per)

def competition(P):
    W = {k[3:]: P[k] for k in P if k.startswith('wk_')}; age = np.concatenate(W['age']); dur = np.concatenate(W['durable']); ans = np.concatenate(W['answers'])
    print('### 9. Weekly durable gain: answers passed (Hard, Good, Easy) 21 days or more after the card\'s previous review, per week since the user\'s first review, weeks with a review')
    b = np.digitize(age + 1, [x + 1 for x in AGE_B]); rows = []
    for lab, k in [('all', age >= 0)] + [(n, b == i) for i, n in enumerate(AGE_N)]:
        d = dur[k]; rows.append([lab, len(d), fmt(100 * (d == 0).mean()) + '%'] + [fmt(x) for x in np.percentile(d, [10, 25, 50, 75, 90])] + [fmt(d.mean()), fmt(np.median(d / ans[k]))])
    table(['weeks since first review', 'user-weeks', 'durable = 0', 'p10', 'p25', 'median', 'p75', 'p90', 'mean', 'median durable / answers'], rows)
    late = [(d[a >= 8], n[a >= 8]) for d, a, n in zip(W['durable'], W['age'], W['answers'])]; late = [x for x in late if len(x[0]) >= 4]
    S = {'median durable a week (weeks 9+)': [np.median(d) for d, n in late], 'share of weeks with durable 0 (weeks 9+)': [(d == 0).mean() for d, n in late],
         'median answers a week (weeks 9+)': [np.median(n) for d, n in late]}
    dist(S, list(S), 'Per user with >= 4 weeks of study from week 9 on (%d users)' % len(late))
    print('### 10. Plausibility flags on real users: how often each fires (eligible weeks only; a user fires "persistently" in half or more of their eligible weeks)')
    tr = [p / np.maximum(r, 1) for p, r in zip(W['pass4'], W['rev4'])]; e_tr = [r >= 30 for r in W['rev4']]
    an = [a / np.maximum(n, 1) for a, n in zip(W['again new'], W['new'])]; e_an = [n >= 20 for n in W['new']]
    fs = W['med sec']; e_fs = [n >= 30 for n in W['answers']]
    rows = []
    for name, vals, el, tests in [('true retention, 4 weeks (>= 30 review-state answers)', tr, e_tr, [('>= 0.97', lambda x: x >= .97), ('>= 0.98', lambda x: x >= .98), ('>= 0.99', lambda x: x >= .99), ('= 1', lambda x: x >= 1)]),
                                  ('Again on first answers of new cards (>= 20 new cards in the week)', an, e_an, [('= 0', lambda x: x <= 0), ('< 2 %', lambda x: x < .02), ('< 5 %', lambda x: x < .05)]),
                                  ('median seconds an answer (>= 30 answers in the week)', fs, e_fs, [('< 1.5 s', lambda x: x < 1.5), ('< 2 s', lambda x: x < 2), ('< 3 s', lambda x: x < 3)])]:
        v = [x[e] for x, e in zip(vals, el)]; pooled = np.concatenate(v); users = [x for x in v if len(x)]
        rows.append([name, '', len(pooled), '', len(users), '', ''] )
        rows += [['', lab, '', fmt(100 * f(pooled).mean()) + '%', '', fmt(100 * np.mean([f(x).any() for x in users])) + '%', fmt(100 * np.mean([f(x).mean() >= .5 for x in users])) + '%'] for lab, f in tests]
    table(['indicator', 'fires when', 'eligible user-weeks', 'user-weeks firing', 'users eligible', 'users firing in any week', 'users firing persistently'], rows)
    t = np.concatenate([x[e] for x, e in zip(tr, e_tr)]); q = np.clip(1 - np.abs(t - .9) / .1, 0, 1)
    table(['true retention, 4 weeks, pooled user-weeks', 'p10', 'p25', 'median', 'p75', 'p90', 'closeness to 0.9 = 1 - |TR - 0.9| / 0.1: mean', 'closeness 0', 'closeness < 0.5'],
          [[len(t)] + [fmt(x) for x in np.percentile(t, [10, 25, 50, 75, 90])] + [fmt(q.mean()), fmt(100 * (q == 0).mean()) + '%', fmt(100 * (q < .5).mean()) + '%']])
    m = np.concatenate([x[e] for x, e in zip(fs, e_fs)])
    table(['median seconds an answer, pooled user-weeks (>= 30 answers)', 'p1', 'p5', 'p10', 'p25', 'median', 'p75'], [[len(m)] + [fmt(x) for x in np.percentile(m, [1, 5, 10, 25, 50, 75])]])
    a = np.concatenate([x[e] for x, e in zip(an, e_an)])
    table(['Again share on new cards, pooled user-weeks (>= 20 new)', 'p10', 'p25', 'median', 'p75', 'p90'], [[len(a)] + [fmt(x) for x in np.percentile(a, [10, 25, 50, 75, 90])]])

def appendix(per):
    print('### Per user (one row each; minutes are of capped durations)')
    keys = ['reviews', 'span', 'study_days', 'share', 'min_med', 'min_p90', 'log_sd', 'longest_gap', 'new_med', 'other_med', 'reviews/new card, days 1-7', 'first14 min/study day']
    table(['user'] + keys, [[i] + [fmt(o.get(k, NAN)) for k in keys] for i, o in per])

def selftest():
    """20 study days of 16 s (new card 10 s + old card 6 s; day 0 only the new card), 5 missed days, 8 more study days."""
    days = list(range(20)) + list(range(25, 33)); rows = []
    for i, d in enumerate(days):
        rows.append((i, d, 10000, 0)); rows += [(0, d, 6000, 2)] if i else []
    a = np.array(rows)
    out = user({'card_id': a[:, 0], 'day_offset': a[:, 1], 'duration': a[:, 2], 'state': a[:, 3], 'rating': np.full(len(a), 3), 'elapsed_days': np.full(len(a), -1)})
    assert out['longest_gap'] == 5 and out['gap 4-7'] == 1 and out['new_med'] == 10 and out['other_med'] == 6, out
    assert len(out['P:ret_ratio']) == 1 and abs(out['P:ret_ratio'][0] - 1) < 1e-9 and out['P:ret_back'][0] == 1
    assert (out['P:big_bin'] == 2).all() and out['first14 study days of 14'] == 14 and abs(out['reviews/new card, days 1-7'] - 1 / 3) < 1e-9 and out['reviews/new card, days 8-30'] == 6
    w = weekly(prep({'card_id': np.array([0, 1, 0, 1]), 'day_offset': np.array([0, 0, 30, 31]), 'duration': np.array([5000, 5000, 1000, 3000]),
                      'state': np.array([0, 0, 2, 2]), 'rating': np.array([1, 3, 3, 1]), 'elapsed_days': np.array([-1, -1, 30, 31])}))
    assert list(w['P:wk_age']) == [0, 4] and list(w['P:wk_durable']) == [0, 1] and list(w['P:wk_pass4']) == [0, 1] and w['P:wk_again new'][0] == 1 and list(w['P:wk_med sec']) == [5, 1]
    assert len(out['P:daymins']) == 28 and abs(out['first14 median min, calendar days 8-14'] - 16 / 60) < 1e-9 and len(out['P:f1']) == 7
    print('selftest ok')

def main(folder):
    S, P, per, tally, ids = {}, {}, [], {'rows': 0, 'over': 0, 'zero': 0, 'rating': Counter(), 'state': Counter()}, []
    for f in sorted(glob.glob(os.path.join(folder, 'user_id=*', 'data.parquet')), key=lambda p: int(re.search(r'user_id=(\d+)', p).group(1))):
        t = pq.read_table(f, columns=['card_id', 'day_offset', 'rating', 'state', 'duration', 'elapsed_days'])
        c = {k: t[k].to_numpy() for k in t.schema.names}
        o = np.argsort(c['day_offset'], kind='stable'); c = {k: v[o] for k, v in c.items()}
        if not len(o):
            continue
        ids.append(int(re.search(r'user_id=(\d+)', f).group(1)))
        tally['rows'] += len(o); tally['over'] += int((c['duration'] > CAP * 1000).sum()); tally['zero'] += int((c['duration'] <= 0).sum())
        tally['rating'].update(dict(zip(*[x.tolist() for x in np.unique(c['rating'], return_counts=True)])))
        tally['state'].update(dict(zip(*[x.tolist() for x in np.unique(c['state'], return_counts=True)])))
        out = user(c); per.append((ids[-1], out))
        for k, v in out.items():
            (P if k.startswith('P:') else S).setdefault(k[2:] if k.startswith('P:') else k, []).append(v)
    report(S, P, tally, ids, per)

if __name__ == '__main__':
    if '--selftest' in sys.argv:
        selftest()
    else:
        main(os.path.expanduser(next((a for a in sys.argv[1:] if not a.startswith('-')), '~/Library/Caches/anki-revlogs-10k')))
