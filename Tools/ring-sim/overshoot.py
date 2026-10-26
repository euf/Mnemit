#!/usr/bin/env -S /opt/homebrew/bin/uv run --script --quiet --managed-python
# /// script
# requires-python = ">=3.10"
# dependencies = ["numpy", "pyarrow"]
# ///
"""Sustained-overshoot rules for the day's time T, on cards.py's card-level model (FSRS-6 cards, the ring in cards:
done cards / the plan's goal cards, closure = the goal reached). The staircase as in the app, with and without a rule
that lifts T to the learner's sustained minutes when they go past the ring on most of the last days.
Usage: overshoot.py [--real <revlog folder>] [--seeds 30] [--days 120] [--resp S|E|M|R] [--rules <substr;substr>]
                    [--ef <folder with the .mnemit decks>] [--selftest]
Responses: S stops at the ring, E goes on every day, M goes on at random on 30 % of days, R goes on in stretches (a two-state
chain that stays in its state with probability 0.9). Method and numbers: Tools/ring-sim/overshoot.md."""
import sys
sys.dont_write_bytecode = True
import argparse, json, glob, os, datetime
import numpy as np
import cards
from cards import staircase, run, metrics, scenarios, load_real


def overshoot(base, f=1.5, m=3, n=4, q=.25, per=None, window=False, after=0, hi=cards.HI):
    """base's T, but when the work of at least m of the last n study days was >= f x that day's T, T is the q-quantile of the
    minutes of those days (of all n with window), never below base's T and at most hi. per: the overshoot's jump is at most
    per x the day's T (base's own step is never held back). after: the rule acts from the study day after the first `after` ones."""
    def mk(B):
        T0_, step0 = base(B)
        cnt = np.zeros(B, int); h, r = np.full((B, n), np.nan), np.full((B, n), np.nan)  # study days so far; work (s) and its ratio to the day's T, last n study days
        def step(T, st, cl, inf, wk, g):
            T1 = step0(T, st, cl, inf, wk, g); go = st & (wk > 0)
            h[go] = np.roll(h[go], 1, 1); h[go, 0] = wk[go]; r[go] = np.roll(r[go], 1, 1); r[go, 0] = wk[go] / T[go]
            cnt[go] += 1; hit = r >= f; ok = go & (hit.sum(1) >= m) & (cnt > after)
            qv = np.nanquantile(h if window else np.where(hit, h, np.nan), q, 1)
            tgt = np.minimum(np.maximum(T1, np.where(ok, qv, 0)), hi)
            if per: tgt = np.minimum(tgt, np.maximum(T1, per * T))
            return np.where(ok, tgt, T1)
        return T0_, step
    return mk


BASE = staircase(2, 1.15, .775)  # the app's rule: x1.15 after the second closed ring in a row that filled T, x0.775 after an open one
RULES = {'1 staircase (baseline)': BASE}
for _f in (1.3, 1.5, 2):
    for _m, _n in ((2, 3), (3, 4), (4, 5)):
        RULES[f'2 overshoot {_f}x, {_m} of {_n}'] = overshoot(BASE, _f, _m, _n)
for _f in (1.3, 1.5, 2):
    for _m, _n in ((2, 3), (3, 4), (4, 5)):
        RULES[f'3 overshoot {_f}x, {_m} of {_n}, jump <= x1.5'] = overshoot(BASE, _f, _m, _n, per=1.5)
for _f in (1.3, 1.5, 2):  # the 25th percentile of all n days of the window, not only of the days past the ring
    for _m, _n in ((2, 3), (3, 4), (4, 5)):
        RULES[f'2w overshoot {_f}x, {_m} of {_n}, q25 of all {_n} days'] = overshoot(BASE, _f, _m, _n, window=True)
for _f in (1.5, 2):
    for _m, _n in ((3, 4), (4, 5)):
        RULES[f'3w overshoot {_f}x, {_m} of {_n}, q25 of all {_n} days, jump <= x1.5'] = overshoot(BASE, _f, _m, _n, per=1.5, window=True)

for _f, _m, _n, _p in ((1.5, 3, 4, 1.5), (2, 4, 5, 1.5), (1.3, 3, 4, 1.5), (2, 3, 4, 1.5), (1.5, 4, 5, 1.5), (1.5, 3, 4, None)):  # not in the first week
    RULES[f'4 overshoot {_f}x, {_m} of {_n}, q25 of all {_n} days' + (', jump <= x1.5' if _p else '') + ', from study day 8'] = overshoot(BASE, _f, _m, _n, per=_p, window=True, after=7)

def extra(log):
    """Per learner: the ring in cards (cards done / the plan's goal cards), the open runs, the ask against the work."""
    st = log['study'] > 0; goal = log['due'] - log['over'] + log['gn']  # goal cards: the plan's reviews that fit T, plus new cards
    done = log['rev'] + log['new']; ok = st & (goal > 0); ratio = np.where(ok, done / np.maximum(goal, 1), np.nan)
    cl = log['closed'] > 0; B = st.shape[0]; cur, tot, cnt = np.zeros(B), np.zeros(B), np.zeros(B)
    for t in range(st.shape[1]):  # runs of open rings over study days
        end = ok[:, t] & cl[:, t] & (cur > 0); tot += np.where(end, cur, 0); cnt += end
        cur = np.where(ok[:, t], np.where(cl[:, t], 0, cur + 1), cur)
    tot += cur; cnt += cur > 0
    share = lambda x, s=slice(None): np.nanmean(np.where(np.isnan(ratio[:, s]), np.nan, x[:, s]), 1)
    w = log['worked']; ask = np.where(ok & (w > 0), log['T'] / np.maximum(w, 1), np.nan)
    return dict(meanrun=tot / np.maximum(cnt, 1), dbl=share(ratio >= 2), tpl=share(ratio >= 3), dbl30=share(ratio >= 2, slice(30, None)),
                tpl30=share(ratio >= 3, slice(30, None)), ask30=np.nanmedian(ask[:, 30:], 1))


def stats(m, x, sel):
    """Means over the learners in sel; a learner with no open run counts 0 in the mean run length."""
    a = lambda v: float(np.nanmean(v[sel]))
    return dict(closure=a(m['closure']), run=a(x['meanrun']), longest=a(m['openrun']), week1=a(m['week1']), words=a(m['words']),
                dbl=a(x['dbl']), tpl=a(x['tpl']), dbl30=a(x['dbl30']), tpl30=a(x['tpl30']), ask30=a(x['ask30']), t14=a(m['T14']))


def responses(resp, shape, seed):
    if resp == 'R':  # stretches: the state flips with probability 0.1 a study day
        rng = np.random.default_rng(seed); s = rng.random(shape[0]) < .5; E = np.zeros(shape, bool)
        for t in range(shape[1]): E[:, t] = s; s = s ^ (rng.random(shape[0]) < .1)
        return E
    return np.random.default_rng(seed).random(shape) < .3 if resp == 'M' else np.full(shape, resp == 'E')


def ef_minutes(folder, rollover=4):
    """EF's daily minutes from the decks' reviews.jsonl: days at Anki's 4 a.m. rollover, local time of Cyprus, each answer capped at
    60 s, an answer without a duration at 10 s."""
    from zoneinfo import ZoneInfo
    tz, days = ZoneInfo('Europe/Nicosia'), {}
    for f in glob.glob(os.path.join(folder, '*.mnemit', 'reviews.jsonl')):
        for line in open(f):
            r = json.loads(line); d = (datetime.datetime.fromtimestamp(r['date'], tz) - datetime.timedelta(hours=rollover)).date()
            days[d] = days.get(d, 0) + min(r.get('ms', 10000), 60000) / 60000
    first, last = min(days), max(days)
    return [(first + datetime.timedelta(i), days.get(first + datetime.timedelta(i), 0.)) for i in range((last - first).days + 1)]


def ef_replay(folder, rules):
    """EF's minutes as the willingness of a learner who goes on every day: each rule's T for the study days and the ring's laps."""
    series = ef_minutes(folder); Wm = np.array([[x[1] for x in series]]); n = Wm.shape[1]
    print(f"## EF's log, {n} calendar days from {series[0][0]}; minutes: " + ' '.join(f"{x[1]:.1f}" for x in series) + '\n')
    rows = []
    for name, rule in rules.items():
        log, w, nn = run(rule, 'cut', Wm, np.ones(Wm.shape, bool), np.zeros(1, bool), np.random.default_rng(308), None, False)
        st = log['study'][0] > 0; goal = (log['due'] - log['over'] + log['gn'])[0]
        lap = np.where(st & (goal > 0), (log['rev'] + log['new'])[0] / np.maximum(goal, 1), np.nan)
        rows.append([name, ' '.join(f"{t / 60:.1f}" for t in log['T'][0][st]), ' '.join(f"{v:.1f}" for v in lap[st])])
    cards.table(['rule', "T of each study day (min)", 'laps (cards done / goal)'], rows)


def selftest():
    Wm = np.full((2, 12), 10.); E = np.ones(Wm.shape, bool); no = np.zeros(2, bool)
    for r, lo, hi in ((BASE, 172.5, 172.5), (overshoot(BASE), 540, 600), (overshoot(BASE, per=1.5), 258.75, 258.75)):
        log, w, nn = run(r, 'cut', Wm, E, no, np.random.default_rng(1), None, False)
        assert lo - 1e-6 <= log['T'][0, 3] <= hi + 1e-6, (log['T'][0, :5], lo, hi)  # day 4 asks what the three days before it set: ~10 min
    S = np.zeros(Wm.shape, bool)
    log, w, nn = run(overshoot(BASE), 'cut', Wm, S, no, np.random.default_rng(1), None, False)
    log0, w0, nn0 = run(BASE, 'cut', Wm, S, no, np.random.default_rng(1), None, False)
    assert (log['T'] == log0['T']).all() and (w == w0).all()  # a learner who stops at the ring never overshoots: the rule is inert
    assert np.nanmax(extra(log)['dbl']) == 0
    print('selftest ok')


def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--real'); ap.add_argument('--seeds', type=int, default=30); ap.add_argument('--days', type=int, default=120)
    ap.add_argument('--resp', default='E'); ap.add_argument('--rules'); ap.add_argument('--ef'); ap.add_argument('--selftest', action='store_true'); a = ap.parse_args()
    if a.selftest: return selftest()
    rules = {k: v for k, v in RULES.items() if not a.rules or any(s in k for s in a.rules.split(';'))}
    if a.ef: return ef_replay(a.ef, rules)
    Wm, vet, names, scen, size, vt0, heavy, refill, ceil = scenarios(a.seeds, a.days, np.random.default_rng(307))
    k = ~vet; Wm, names, size, vt0, heavy, refill, ceil, vet = Wm[k], names[k], size[k], vt0[k], heavy[k], refill[k], ceil[k], vet[k]  # no veterans
    if a.real:
        R = load_real(a.real, a.days); n = len(R); Wm = np.concatenate([Wm, R]); vet = np.append(vet, np.zeros(n, bool)); names = np.append(names, ['real'] * n)
        size = np.append(size, np.full(n, cards.N)); vt0 = np.append(vt0, np.full(n, np.nan)); heavy = np.append(heavy, np.zeros(n, bool))
        refill = np.append(refill, np.full(n, 1 << 30)); ceil = np.append(ceil, np.full(n, cards.CEIL))
    E = responses(a.resp, Wm.shape, 309); groups = {'synthetic': names != 'real', 'real users': names == 'real'}
    print(f"## Response {a.resp}: {sum(names != 'real')} synthetic learners, {sum(names == 'real')} real users, {a.days} days")
    H = ['rule', 'closure', 'open run, mean', 'open run, longest', 'perfect first week', 'words', 'Double', 'Triple', 'Double from day 31', 'Triple from day 31', 'median T / minutes done from day 31', 'T on day 14 (min)']
    out = {g: [] for g in groups}
    for name, rule in rules.items():
        log, w, nn = run(rule, 'cut', Wm, E, vet, np.random.default_rng(308), size, False, vt0=vt0, heavy=heavy, refill=refill, ceil=ceil)
        m, x = metrics(log, w), extra(log)
        for g, sel in groups.items():
            if sel.any(): out[g].append([name] + [f"{v:.1f}" if i == 4 else f"{v:.3f}" for i, v in enumerate(stats(m, x, sel).values())])
        print(f"done {name}", file=sys.stderr, flush=True)
    for g, rows in out.items():
        if rows: print(f'\n### {g}'); cards.table(H, rows)


if __name__ == '__main__': main()