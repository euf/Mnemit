#!/usr/bin/env -S /opt/homebrew/bin/uv run --script --quiet --managed-python
# /// script
# requires-python = ">=3.10"
# dependencies = ["numpy", "pyarrow"]
# ///
"""Ring-time simulation: which rule should learn the day's time T from the work done?
Usage: sim.py [--real <folder with anki-revlogs-10k parquet files>] [--seeds 200] [--detail] [--selftest]
Model, scenarios and the numbers: Tools/ring-sim/minutes.md."""
import argparse, glob, os
from itertools import product
import numpy as np

DAYS, LO, HI, T0 = 90, 2.0, 30.0, 4.0
BAND, FLOOR = (0.8, 0.9), 0.7  # target mean closure; lowest closure allowed in any cell


# ---------- scenarios: W[c, seed, n] = willingness on the n-th study day (missed days are dropped:
# a day without work changes nothing, so compacting the study days is exact) ----------
def synthetic(seeds, rng):
    d = np.arange(DAYS)
    c = lambda x: np.full(DAYS, float(x))
    ramp = lambda a, b, n: np.interp(d, [0, n], [a, b])
    off = lambda a, b: (d >= a) & (d < b)
    none = d < 0
    sc = {  # name: (median minutes by day, lognormal sigma, missed days, responses)
        'steady 5': (c(5), .25, none, 'SE'), 'steady 10': (c(10), .25, none, 'SE'),
        'steady 20': (c(20), .25, none, 'SE'), 'weekdays only': (c(10), .25, d % 7 >= 5, 'SE'),
        'vacation 10 d': (c(10), .25, off(40, 50), 'SE'),
        'sick week 3 min': (np.where(off(40, 47), 3., 10.), .25, none, 'SE'),
        'increase 5-15': (ramp(5, 15, 30), .25, none, 'SE'), 'decline 15-6': (ramp(15, 6, 30), .25, none, 'SE'),
        'erratic': (c(10), .6, none, 'SE'), 'eager learner': (c(12), .35, none, 'E'),
        'newcomer 5-12': (ramp(5, 12, 14), .25, none, 'SE'),
        'alternating 20/5': (np.where(d % 2 == 0, 20., 5.), .25, none, 'SE'),
        'step up 6-14': (np.where(d < 30, 6., 14.), .25, none, 'SE'),
        'step down 14-6': (np.where(d < 30, 14., 6.), .25, none, 'SE')}
    Ws, Es, Vs, Ls, Sg, names, sel = [], [], [], [], [], [], []
    for name, (lv, sg, zero, resp) in sc.items():
        W = (lv * np.exp(sg * rng.standard_normal((seeds, DAYS))))[:, ~zero]
        Wp = np.zeros((seeds, DAYS)); Wp[:, :W.shape[1]] = W
        Lp = np.zeros(DAYS); Lp[:W.shape[1]] = lv[~zero]
        for r in resp + ('M' if resp == 'SE' else ''):  # M = eager on 30 % of days, outside the selection
            Ws.append(Wp); Vs.append(d < W.shape[1]); Ls.append(Lp); Sg.append(sg); names.append((name, r)); sel.append(r != 'M')
            Es.append(rng.random((seeds, DAYS)) < .3 if r == 'M' else np.full((seeds, DAYS), r == 'E'))
    sel = np.array(sel); G = np.array([[(n[0] == s) * 1. for n in names] for s in sc]) * sel
    lc = [i for i, n in enumerate(names) if n[0].startswith('step')]
    lr = [names.index((names[i][0], 'E')) for i in lc]
    return dict(W=np.stack(Ws), E=np.stack(Es), V=np.stack(Vs), L=np.stack(Ls), sg=np.array(Sg), names=names, sel=sel, scen=list(sc),
                G=G / G.sum(1, keepdims=True), lc=lc, lr=lr, lsel=sel[lc])


def load_real(folder):
    """One cell per user with >= 60 study days: first 90 study days of daily minutes, review
    durations capped at 60 s. day_offset is Anki's own day number (4 a.m. rollover)."""
    import pyarrow.parquet as pq
    S = []
    for f in sorted(glob.glob(os.path.join(folder, '**', '*.parquet'), recursive=True)):
        t = pq.read_table(f, columns=['day_offset', 'duration'])
        d = t['day_offset'].to_numpy().astype(int); m = np.minimum(t['duration'].to_numpy(), 60000) / 60000
        s = np.bincount(d - d.min(), weights=m); s = s[s > 0]
        if len(s) >= 60: S.append(s[:DAYS])
    if not S: return None
    W = np.zeros((len(S), 1, DAYS))
    for i, s in enumerate(S): W[i, 0, :len(s)] = s
    return dict(W=W, E=np.zeros(W.shape, bool), V=np.array([np.arange(DAYS) < len(s) for s in S]),
                sel=np.ones(len(S), bool), G=np.full((1, len(S)), 1 / len(S)), lc=[], names=[],
                first_week=float(np.median([np.median(s[:7]) for s in S])), n=len(S))


# ---------- rules: factory(params) -> step(T, work, closed, censored) -> new T (before the 2-30 clamp).
# "censored" = the learner stopped at the ring: the log shows work == T, the willingness is only >= T ----------
def window(stat, k, s, u):  # s * median|mean of the last k study days; u lifts a ring-stop to T(1+u)
    h = []
    def step(T, work, cl, ce):
        h.append(np.where(ce, T * (1 + u), work)); return s * stat(np.stack(h[-k:]), axis=0)
    return step

def ewma(au, ad, c, u):
    def step(T, work, cl, ce):
        w = np.minimum(np.where(ce, T * (1 + u), work), c * T)
        return T + np.where(w > T, au, ad) * (w - T)
    return step

def tracker(q, k):  # Robbins-Monro, sees closed/open only; P(closed) q = P(open) (1-q) gives closure 1-q
    return lambda T, work, cl, ce: T * np.where(cl, 1 + k * q, 1 - k * (1 - q))

def aimd(x, m):
    return lambda T, work, cl, ce: np.where(cl, T + x, T * m)

def km(q, k):  # Kaplan-Meier over the last k days (ring-stops right-censored at T), T = q-quantile
    hv, hc = [], []
    def step(T, work, cl, ce):
        hv.append(np.where(ce, T, work)); hc.append(ce)
        v, c = np.stack(hv[-k:]), np.stack(hc[-k:]); w = len(v)
        o = np.argsort(v + 1e-9 * c, axis=0, kind='stable')  # events before censored at ties
        vs, ev = np.take_along_axis(v, o, 0), ~np.take_along_axis(c, o, 0)
        S = np.cumprod(np.where(ev, 1 - 1 / (w - np.arange(w)).reshape(-1, 1, 1), 1.), 0)
        hit = ev & (1 - S >= q)
        t = np.take_along_axis(vs, hit.argmax(0)[None], 0)[0]
        return np.where(hit.any(0), t, 1.1 * vs.max(0))  # quantile beyond the data: 10 % above the top
    return step

def erf(x):  # Abramowitz-Stegun 7.1.26, |error| < 1.5e-7
    t = 1 / (1 + 0.3275911 * abs(x))
    y = 1 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * np.exp(-x * x)
    return np.sign(x) * y

def kalman(Q, R, d, mode):  # level m of log-minutes; T = exp(m - d); ring-stops: Tobit update or skip
    st = {}
    def step(T, work, cl, ce):
        if not st: st.update(m=np.log(T) + d, P=np.ones_like(T))
        m, P = st['m'], st['P'] + Q; S = P + R; sd = np.sqrt(S)
        K = P / S; me, Pe = m + K * (np.log(np.maximum(work, .05)) - m), (1 - K) * P
        a = np.clip((np.log(T) - m) / sd, -8, 4)  # censored at log T: expected excess via the inverse Mills ratio
        lam = np.exp(-a * a / 2) / np.sqrt(2 * np.pi) / np.maximum(.5 * (1 - erf(a / np.sqrt(2))), 1e-9)
        mc, Pc = m + P / sd * lam, P * (1 - P / S * lam * (lam - a))
        if mode == 'skip': mc, Pc = m, P
        st['m'], st['P'] = np.where(ce, mc, me), np.where(ce, Pc, Pe)
        return np.exp(st['m'] - d)
    return step

def grid():
    rules = []
    def add(fam, names, p, fn, brief=False): rules.append(dict(fam=fam, names=names, p=p, mk=lambda: fn(*p), brief=brief))
    for k, s, u in product((5, 7, 10, 14), (1, .9, .8, .7), (0, .1, .2)):
        add('median', 'k s u', (k, s, u), lambda k, s, u: window(np.median, k, s, u), s == 1 and u == 0)
        add('mean', 'k s u', (k, s, u), lambda k, s, u: window(np.mean, k, s, u), s == 1 and u == 0)
    for a, c, u in product((.1, .2, .3, .4, .5), (1.5, 2, 3), (0, .1, .2)):
        add('ewma sym', 'a c u', (a, c, u), lambda a, c, u: ewma(a, a, c, u), u == 0)
    for au, ad, c, u in product((.1, .2, .3, .4, .5, .6), (.05, .1, .15, .2, .25, .3, .35, .4), (1.5, 2, 3), (0, .1, .2)):
        add('ewma asym', 'a_up a_down c u', (au, ad, c, u), ewma, u == 0)
    for q, k in product((.1, .15, .2, .25), (.05, .1, .2, .3)): add('tracker', 'q k', (q, k), tracker)
    for q, k in product((.1, .15, .2, .25), (7, 14, 21)): add('Kaplan-Meier', 'q days', (q, k), km)
    for x, m in product((.25, .5, 1), (.7, .8, .9)): add('AIMD', 'x m', (x, m), aimd)
    for Q, R, d, mode in product((.005, .02, .05, .1), (.06, .15, .3), (.1, .2, .3, .4), ('tobit', 'skip')):
        add('Kalman', 'Q R d mode', (Q, R, d, mode), kalman)
    return rules


# ---------- one run: every cell and seed at once ----------
def ev(rule, ds, t0=T0):
    W, E, V = ds['W'], ds['E'], ds['V']; C, S, N = W.shape
    step, T, Ts = rule['mk'](), np.full((C, S), t0), np.empty_like(W)
    for n in range(N):
        w, e = W[:, :, n], E[:, :, n]; Ts[:, :, n] = T
        cl = w >= T  # closed: work >= T (an eager learner works w, a ring-stopper works T)
        T = np.clip(step(T, np.where(e, w, np.minimum(w, T)), cl, cl & ~e), LO, HI)
    v, nv = V[:, None, :], V.sum(1)[:, None]; cl = (W >= Ts) & v
    out = dict(cl=(cl.sum(2) / nv).mean(1),  # capture: minutes the ring asked and got / true willingness
               cap=((np.minimum(W, Ts) * v).sum(2) / (W * v).sum(2)).mean(1),
               fl=(((cl[:, :, 1:] != cl[:, :, :-1]) & v[:, :, 1:]).sum(2) * 30 / np.maximum(nv - 1, 1)).mean(1))
    if ds['lc']:  # lag: days after the step (day 30) until the seed-mean T is within 10 % of the same
        Tb = Ts.mean(1); tg = Tb[ds['lr'], 80:].mean(1)[:, None]  # rule's end level under the eager response
        bad = np.abs(Tb[ds['lc'], 30:] - tg) > .1 * tg
        out['lag'] = np.where(bad.any(1), N - 30 - bad[:, ::-1].argmax(1), 0)
    return out

def score(rule, ds, rd, t0=T0):
    m = ev(rule, ds, t0); g = ds['G']; cl, cap, fl = g @ m['cl'], g @ m['cap'], g @ m['fl']
    cells = m['cl'][ds['sel']]
    if rd:
        r = ev(rule, rd, t0); cl, cap, fl = (np.append(a, r[k].mean()) for a, k in ((cl, 'cl'), (cap, 'cap'), (fl, 'fl')))
        cells = np.append(cells, r['cl'].mean())
    return dict(rule=rule, m=m, cl=cl, closure=cl.mean(), capture=cap.mean(), cmin=cells.min(),
                flips=fl.mean(), lag=m['lag'][ds['lsel']].mean(), rcl=r['cl'].mean() if rd else None,
                rcap=r['cap'].mean() if rd else None,
                ok=BAND[0] <= cl.mean() <= BAND[1] and cells.min() >= FLOOR)


# ---------- output ----------
def label(r): return f"{r['fam']} " + ', '.join(f'{n}={v}' for n, v in zip(r['names'].split(), r['p']))
def table(head, rows): print('| ' + ' | '.join(head) + ' |\n|' + '---|' * len(head)); [print('| ' + ' | '.join(map(str, r)) + ' |') for r in rows]
def row(x): return [label(x['rule']), f"{x['closure']:.3f}", f"{x['cmin']:.3f}", f"{x['capture']:.3f}", f"{x['lag']:.1f}", f"{x['flips']:.1f}"]
HEAD = ['rule', 'closure', 'min cell closure', 'capture', 'lag (days)', 'flips/30 d']

def oracle(ds, q):  # ceiling: T = the true q-quantile of W_t (knows L_t and sigma), closure 1-q
    from statistics import NormalDist
    T = np.clip(ds['L'][:, None, :] * np.exp(ds['sg'][:, None, None] * NormalDist().inv_cdf(q)), LO, HI)
    W, V, nv = ds['W'], ds['V'][:, None, :], ds['V'].sum(1)[:, None]
    return dict(cl=(((W >= T) & V).sum(2) / nv).mean(1), cap=((np.minimum(W, T) * V).sum(2) / (W * V).sum(2)).mean(1))

def detail(res, ds, best):  # --detail: what the report's family sections quote
    names = ds['names']; ix = {r: [i for i, n in enumerate(names) if n[1] == r] for r in 'SE'}
    split = lambda x: [f"{x['m'][k][ix[r]].mean():.3f}" for r in 'SE' for k in ('cl', 'cap')]
    def weak(x):
        i = min(ix['S'] + ix['E'], key=lambda i: x['m']['cl'][i]); return f"{names[i][0]} {names[i][1]} {x['m']['cl'][i]:.2f}"
    H = ['rule', 'S closure', 'S capture', 'E closure', 'E capture', 'weakest cell', 'closure', 'capture', 'lag', 'flips']
    line = lambda x: [label(x['rule'])] + split(x) + [weak(x), f"{x['closure']:.3f}", f"{x['capture']:.3f}", f"{x['lag']:.1f}", f"{x['flips']:.1f}"]
    fam = lambda f, c=lambda x: True: sorted((x for x in res if x['rule']['fam'] == f and c(x)), key=lambda x: -x['capture'])
    band = lambda x: BAND[0] <= x['closure'] <= BAND[1]
    print('\n## Detail: ceiling (oracle that knows L_t and sigma)')
    table(['q', 'closure', 'lowest cell', 'capture'], [[q, *(f"{v:.3f}" for v in ((ds['G'] @ o['cl']).mean(), o['cl'][ds['sel']].min(), (ds['G'] @ o['cap']).mean()))] for q in (.1, .15, .2) for o in [oracle(ds, q)]])
    print('\n## Detail: best rule of each family, by response'); table(H, [line(x) for x in best.values()])
    for f in ('closure tracker', 'Kaplan-Meier', 'AIMD'): print(f'\n## Detail: all {f} rules'); table(H, [line(x) for x in fam({'closure tracker': 'tracker'}.get(f, f))])
    print('\n## Detail: median and mean, k = 14'); table(H, [line(x) for f in ('median', 'mean') for x in sorted(fam(f, lambda x: x['rule']['p'][0] == 14 and x['rule']['p'][2] in (0, .2)), key=lambda x: (x['rule']['p'][2], -x['rule']['p'][1]))])
    print('\n## Detail: EWMA, highest closures (symmetric) and best in-band rule per probe u (asymmetric)')
    table(H, [line(x) for x in sorted(fam('ewma sym'), key=lambda x: -x['closure'])[:3]] + [line(fam('ewma asym', lambda x: band(x) and x['rule']['p'][3] == u)[0]) for u in (0, .1, .2)])
    print('\n## Detail: Kalman, best in-band rule per ring-stop mode'); table(H, [line(fam('Kalman', lambda x: band(x) and x['rule']['p'][3] == m)[0]) for m in ('tobit', 'skip')])

def selftest():
    ds = synthetic(40, np.random.default_rng(1)); i = lambda s, r: ds['names'].index((s, r))
    m = ev(dict(mk=lambda: window(np.median, 7, 1, 0)), ds)  # a ring-stopper never lifts T off its start
    assert m['cl'][i('steady 20', 'S')] > .97 and m['cap'][i('steady 20', 'S')] < .25
    m = ev(dict(mk=lambda: tracker(.15, .3)), ds); assert abs(m['cl'][i('steady 10', 'E')] - .87) < .05  # 1-q after the climb from 4
    st, a = km(.3, 5), lambda x: np.full((1, 1), float(x))  # 2 open days (3, 4) + 3 ring-stops at 6: F = .2, .4
    for w, ce in ((6, 1), (3, 0), (6, 1), (4, 0), (6, 1)): t = st(a(6), a(w), a(0) > 1, a(ce) > 0)
    assert abs(t[0, 0] - 4) < 1e-9; print('selftest ok')

def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--real'); ap.add_argument('--seeds', type=int, default=200)
    ap.add_argument('--selftest', action='store_true'); ap.add_argument('--detail', action='store_true'); a = ap.parse_args()
    if a.selftest: return selftest()
    ds = synthetic(a.seeds, np.random.default_rng(307))
    rd = load_real(a.real) if a.real else None
    if rd: print(f"real users: {rd['n']}, median first-week minutes {rd['first_week']:.1f}\n")
    res = [score(r, ds, rd) for r in grid()]
    ok = sorted((x for x in res if x['ok']), key=lambda x: -x['capture'])
    dist = lambda x: max(BAND[0] - x['closure'], x['closure'] - BAND[1], FLOOR - x['cmin'], 0)
    print(f"rules {len(res)}, feasible (closure {BAND}, every cell >= {FLOOR}): {len(ok)}\n\n## Best per family")
    best = {}
    for x in res:
        f = x['rule']['fam']
        if f not in best or (x['ok'], x['ok'] and x['capture'], -dist(x)) > (best[f]['ok'], best[f]['ok'] and best[f]['capture'], -dist(best[f])): best[f] = x
    table(HEAD + ['feasible'], [row(x) + ['yes' if x['ok'] else 'no'] for x in sorted(best.values(), key=lambda x: -(x['ok'] * 10 + x['capture']))])
    print('\n## Brief grid only (median, mean s=1; EWMA without probe)')
    bo = [x for x in ok if x['rule']['brief']]; table(HEAD, [row(x) for x in bo[:3]] or [row(min((x for x in res if x['rule']['brief']), key=dist))])
    if not bo: print('(none feasible; the row is the closest to the band)')
    print('\n## Top 8 feasible'); table(HEAD, [row(x) for x in ok[:8]])
    if a.detail: detail(res, ds, best)
    if not ok: return
    w = ok[0]; r = w['rule']; ru = next((x for x in ok if x['rule']['fam'] != r['fam']), None)
    print(f"\n## Winner: {label(r)}\n"); names = ds['names']
    table(['scenario', 'response', 'closure', 'capture', 'flips/30 d'], [[n, rr, f"{w['m']['cl'][i]:.3f}", f"{w['m']['cap'][i]:.3f}", f"{w['m']['fl'][i]:.1f}"] for i, (n, rr) in enumerate(names)])
    if ds['lc']: print(); table(['step scenario', 'response', 'lag (days)'], [[*names[i], int(l)] for i, l in zip(ds['lc'], w['m']['lag'])])
    if rd: print(f"\nreal users: closure {w['rcl']:.3f}, capture {w['rcap']:.3f}")
    if rd:
        print('\n## Real users by rule (closure: mean over users, and the user at p10)')
        app = next(x for x in res if x['rule']['fam'] == 'tracker' and x['rule']['p'] == (.25, .3))
        rows = [app] + [x for x in best.values() if x is not app]
        table(['rule', 'closure', 'p10 user', 'capture'], [[label(x['rule']), f"{x['rcl']:.3f}", f"{np.percentile(ev(x['rule'], rd)['cl'], 10):.3f}", f"{x['rcap']:.3f}"] for x in rows])
    cur = next(x for x in res if x['rule']['fam'] == 'median' and x['rule']['p'] == (7, 1, 0))
    print('\n## Current rule (median of the last 7 study days) against the winner, by response')
    table(['rule', 'response', 'closure', 'capture'], [[l, rr, *(f"{x['m'][k][[i for i, n in enumerate(names) if n[1] == rr]].mean():.3f}" for k in ('cl', 'cap'))]
          for l, x in (('current', cur), ('winner', w)) for rr in 'SEM'])
    table(HEAD + ['feasible'], [row(cur) + ['yes' if cur['ok'] else 'no']])
    if ru: print('\n## Runner-up (best feasible of another family)'); table(HEAD, [row(ru)])
    print('\n## Hold-out: the top 8 on fresh seeds'); ds2 = synthetic(a.seeds, np.random.default_rng(308))
    table(HEAD + ['feasible'], [row(h) + ['yes' if h['ok'] else 'no'] for h in (score(x['rule'], ds2, rd) for x in ok[:8])])
    print('\n## Sensitivity: one grid step from the winner')
    ax = [sorted({x['rule']['p'][i] for x in res if x['rule']['fam'] == r['fam']}, key=str) for i in range(len(r['p']))]
    nb = [x for x in res if x['rule']['fam'] == r['fam'] and sum(abs(ax[i].index(x['rule']['p'][i]) - ax[i].index(r['p'][i])) for i in range(len(ax))) == 1]
    table(HEAD + ['feasible'], [row(w) + ['yes']] + [row(x) + ['yes' if x['ok'] else 'no'] for x in nb])
    print('\n## Start value of T (winner)'); starts = [2, 4, 8, 12] + ([round(rd['first_week'], 1)] if rd else [])
    table(['T0 (min)', 'closure', 'capture', 'flips/30 d'], [[t, *(f"{score(r, ds, rd, t)[k]:.3f}" for k in ('closure', 'capture', 'flips'))] for t in starts])

if __name__ == '__main__': main()
