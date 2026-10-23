#!/usr/bin/env -S /opt/homebrew/bin/uv run --script --quiet --managed-python
# /// script
# requires-python = ">=3.10"
# dependencies = ["numpy", "pyarrow"]
# ///
"""Card-level ring simulation: FSRS-6 memory, a learner with a willingness in minutes a day, and the
rules that size the ring. Where sim.py compares rules on minutes alone, this one lets the ring
admit new cards, lets those cards come back as reviews, and scores words in memory.
Usage: cards.py [--real <revlog folder>] [--seeds 40] [--days 120] [--selftest]
Model, rules and numbers: references/ring-design.md."""
import argparse, glob, os, warnings
import numpy as np
warnings.filterwarnings('ignore', category=RuntimeWarning)

# FSRS-6 defaults (py-fsrs), the same as FSRSParameters.default in VocabCore
W = np.array([0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001, 1.8722, 0.1666, 0.796, 1.4835, 0.0614,
              0.2629, 1.6483, 0.6014, 1.8729, 0.5425, 0.0912, 0.0658, 0.1542])
DECAY = -W[20]; FACTOR = 0.9 ** (1 / DECAY) - 1
N = 5000  # words in the deck
P_NEW, P_OTHER = 30., 10.  # seconds per done card, new and other: DailyGoal's fallbacks; --prices changes them
A_NEW = 0.22  # share of new cards whose first answer is Again: median of 2,000 real users 0.225 (p25 0.057, p75 0.407)
LOAD = 2 / 7  # reviews a day over the next week from one new card, NewCardLoad with default options (days 1-7: 2 reviews)
CEIL = 20  # a deck's new-card ceiling a day (newCardsPerSession)
H = 30  # days ahead that EF's idea 1 reserves for a new card's reviews
SKIP = 0.  # the chance that an open ring makes the learner skip the next day (--skip)

def retr(el, S): return (1 + FACTOR * np.maximum(el, 0) / S) ** DECAY
def d0(g): return W[4] - np.exp(W[5] * (g - 1)) + 1
def dnext(D, g): return np.clip(W[7] * d0(4) + (1 - W[7]) * (D + (10 - D) * (-W[6] * (g - 3)) / 9), 1, 10)
def sshort(S, g):
    inc = np.exp(W[17] * (g - 3 + W[18])) * S ** -W[19]
    return S * (np.maximum(inc, 1) if g >= 2 else inc)
def srecall(D, S, R): return S * (1 + np.exp(W[8]) * (11 - D) * S ** -W[9] * (np.exp((1 - R) * W[10]) - 1))
def sforget(D, S, R): return np.minimum(W[11] * D ** -W[12] * ((S + 1) ** W[13] - 1) * np.exp((1 - R) * W[14]), S / np.exp(W[17] * W[18]))


# ---------- rules for the day's time T (seconds): mk(B) -> step(T, study, closed, informative, worked, goal) -> T ----------
LO, HI, T0 = 120., 3600., 150.  # DailyGoal.timeRange and initialSeconds

def tracker(up, down, hold=False, lo=LO, hi=HI, t0=T0, slow=None, flat=0):
    """Closed ring: T * up; open: T * down. hold: a closed ring whose goal didn't fill T (the plan was smaller) holds T.
    slow: the factor of a closed ring until the first open one (TCP's slow start). flat: study days at the start before any step."""
    def mk(B):
        opened, n = np.zeros(B, bool), np.zeros(B, int)
        def step(T, st, cl, inf, wk, g):
            n[st] += 1
            u = np.where(opened, up, slow) if slow else up
            f = np.where(cl, np.where(inf | (not hold), u, 1.), down); opened[st & ~cl] = True
            return np.where(st & (n > flat), np.clip(T * f, lo, hi), T)
        return np.full(B, t0), step
    return mk

A = np.log(1.075) + np.log(1 / .775)  # the app's step: closed and open together move log T by 0.327
def target(c, a=A): return np.exp(a * (1 - c)), np.exp(-a * c)  # factors whose log-equilibrium closure is c

def window(c, k=7, a=None, hold=True, t0=T0):
    """T * exp(a (p - c)), p the share of closed rings over the last k study days (EF's idea 2); a ring closed on a
    small plan is no step."""
    a = a or A
    def mk(B):
        h, n = np.zeros((B, k)), np.zeros(B, int)
        def step(T, st, cl, inf, wk, g):
            go = st & (inf | ~cl | (not hold))
            h[go] = np.roll(h[go], 1, 1); h[go, 0] = cl[go]; n[go] = np.minimum(n[go] + 1, k)
            p = h.sum(1) / np.maximum(n, 1)
            return np.where(go, np.clip(T * np.exp(a * (p - c)), LO, HI), T)
        return np.full(B, t0), step
    return mk

def logmean(k):
    """T = the geometric mean of the work of the last k study days, days without work left out (EF's idea 3)."""
    def mk(B):
        h = np.full((B, k), np.nan)
        def step(T, st, cl, inf, wk, g):
            go = st & (wk > 0); h[go] = np.roll(h[go], 1, 1); h[go, 0] = np.log(wk[go])
            return np.where(go, np.clip(np.exp(np.nanmean(h, 1)), LO, HI), T)
        return np.full(B, T0), step
    return mk

def fixed(t):
    return lambda B: (np.full(B, t), lambda T, *a: T)

def km(q, k, lo=LO, hi=HI, t0=T0):
    """Kaplan-Meier q-quantile of the work of the last k study days, a ring-stop (closed, work within 10 % of the goal)
    right-censored at the work; T = 1.1 x the top when the curve never reaches q."""
    def mk(B):
        v, c, n = np.zeros((B, k)), np.zeros((B, k), bool), np.zeros(B, int)
        def step(T, st, cl, inf, wk, g):
            v[st] = np.roll(v[st], 1, 1); c[st] = np.roll(c[st], 1, 1); v[st, 0] = wk[st]; c[st, 0] = (cl & (wk <= 1.1 * g))[st]
            n[st] = np.minimum(n[st] + 1, k); ok = np.arange(k)[None] < n[:, None]
            key = np.where(ok, v + 1e-9 * c, np.inf); o = np.argsort(key, 1, kind='stable')
            vs, ev = np.take_along_axis(v, o, 1), np.take_along_axis(ok & ~c, o, 1)
            j = np.arange(k)[None]; S = np.cumprod(np.where(ev, 1 - 1 / np.maximum(n[:, None] - j, 1), 1.), 1)
            hit = ev & (1 - S >= q); t = np.take_along_axis(vs, hit.argmax(1)[:, None], 1)[:, 0]
            top = np.where(ok, v, 0).max(1)
            return np.where(st, np.clip(np.where(hit.any(1), t, 1.1 * top), lo, hi), T)
        return np.full(B, t0), step
    return mk

def median(k):
    def mk(B):
        h = np.full((B, k), np.nan)
        def step(T, st, cl, inf, wk, g):
            h[st] = np.roll(h[st], 1, 1); h[st, 0] = wk[st]
            return np.where(st, np.clip(np.nanmedian(np.where(np.isnan(h), np.nan, h), 1), LO, HI), T)
        return np.full(B, T0), step
    return mk


# ---------- one run ----------
def load30():
    """Reviews in the H days after its first day of a new card answered right at 0.9 on each due day, over 0.9 for the
    lapses: what one more new card a day adds to each later day's reviews once the intake runs steady."""
    S, D, t, n = W[2], d0(3), 0, 0
    while t + max(1, round(S)) <= H:
        t += max(1, round(S)); n += 1; S, D = srecall(D, S, .9), dnext(D, 3)
    return n / .9

def run(rule, comp, Wm, E, vet, rng, size=None, weekly=True, vt0=None, heavy=None, refill=None, ceil=None):
    """Wm[B, days]: willingness in minutes (0 = no study). E[B, days]: the learner goes on past the ring (catch up,
    then more new cards). vet[B]: rows that start with an Anki collection. comp: 'cut' (the app: the plan's
    cards that fit T, new cards only in what T and next week leave), 'all' (every card due, new cards in what T
    leaves), 'anki' (every card due up to 200 + `ceil` new, T unused)."""
    B, days = Wm.shape; ix = np.arange(N)[None]; R30 = load30(); refill = np.full(B, 1 << 30) if refill is None else refill; heavy = np.zeros(B, bool) if heavy is None else heavy; rows = np.arange(B); size = np.full(B, N) if size is None else size; ceil = np.full(B, CEIL) if ceil is None else ceil
    S, D = np.full((B, N), 1.), np.full((B, N), 5.)
    last, due, nn = np.zeros((B, N), int), np.full((B, N), 1 << 30), np.zeros(B, int)
    nv = vet.sum()
    if nv:  # a veteran: 2000 cards learned in Anki, stability lognormal around 30 days, due spread over one interval
        m = vet[:, None] & (ix < np.where(heavy, 4000, 2000)[:, None])
        S[m] = np.exp(np.log(np.where(heavy[:, None], 15, 30) * np.ones((1, N)))[m] + rng.standard_normal(m.sum())); D[m] = rng.uniform(3, 8, m.sum())
        last[m] = -np.floor(rng.random(m.sum()) * S[m]).astype(int); due[m] = last[m] + np.maximum(1, np.round(S[m])).astype(int)
        nn[vet] = np.where(heavy[vet], 4000, 2000)
    T, step = rule(B); wasopen = np.zeros(B, bool)
    if vt0 is not None: T = np.where(np.isnan(vt0), T, vt0)
    log = {k: np.zeros((B, days)) for k in ('study', 'closed', 'goal', 'worked', 'T', 'due', 'overdue', 'new', 'rev', 'ok', 'week')}
    for t in range(days):
        st = (Wm[:, t] > 0) & ~(wasopen & (rng.random(B) < SKIP)); intro = ix < nn[:, None]; isdue = intro & (due <= t); R = retr(t - last, S)
        nd = isdue.sum(1); ahead = (intro & (due > t) & (due <= t + 7)).sum(1); rem = np.where(t >= refill, N, size) - nn
        a30 = (intro & (due > t) & (due <= t + H)).sum(1) / H
        room = T / P_OTHER - ahead / 7
        week = np.where(room >= 0, np.floor(room / LOAD + 1e-9), 0) if weekly else np.full(B, np.inf)
        if comp == 'anki':
            go, gn = np.minimum(nd, 200), np.minimum(ceil, rem); inf = np.ones(B, bool); wb = np.zeros(B, bool)
        elif comp == 'load':  # EF's idea 1: every card due + X new, X the steady intake that T carries with its later reviews, at least 1
            x = np.floor(np.maximum(T - a30 * P_OTHER, 0) / (P_NEW + R30 * P_OTHER) + 1e-9)
            go, gn = nd, np.minimum(np.maximum(x, 1), np.minimum(ceil, rem)); inf = x <= np.minimum(ceil, rem); wb = np.zeros(B, bool)
        elif comp == 'memory':  # EF's idea 4: the ring is the cards, in stream order, whose expected recall tomorrow makes up
            # for the day's forgetting: words in memory tomorrow morning at least those of this morning
            loss = np.where(intro, R - retr(t + 1 - last, S), 0).sum(1)
            Rt = retr(t + 1 - last, S)
            gain = R * retr(1, srecall(D, S, R)) + (1 - R) * retr(1, sshort(sforget(D, S, R), 3)) - Rt
            key = np.where(isdue, R, np.inf); o = np.argsort(key, 1)
            cg = np.cumsum(np.where(np.take_along_axis(isdue, o, 1), np.take_along_axis(gain, o, 1), 0), 1)
            gnew = (1 - A_NEW) * retr(1, W[2]) + A_NEW * retr(1, sshort(sshort(W[0], 3), 3))
            k = np.where(cg[:, -1] >= loss, (cg < loss[:, None]).sum(1) + 1, nd)
            go = np.minimum(k, nd); gn = np.where(cg[:, -1] >= loss, 0, np.minimum(np.ceil(np.maximum(loss - cg[:, -1], 0) / gnew), rem))
            go = np.where((go + gn == 0) & (rem > 0), 0, go); gn = np.where((go + gn == 0) & (rem > 0), 1, gn)
            inf = np.ones(B, bool); wb = np.zeros(B, bool)
        else:
            left = T - nd * P_OTHER if comp in ('cut', 'cutload') else np.maximum(T - nd * P_OTHER, 0)
            if comp == 'cutload':
                x = np.floor(np.maximum(T - a30 * P_OTHER, 0) / (P_NEW + R30 * P_OTHER) + 1e-9)
                left = np.minimum(left, np.maximum(x, 1) * P_NEW); week = np.full(B, np.inf)
            newok = np.minimum.reduce([np.floor(np.maximum(left, 0) / P_NEW + 1e-9), week, ceil * 1., rem])
            cut = (nd * P_OTHER > T) & (comp in ('cut', 'cutload'))
            go = np.where(cut, np.floor(T / P_OTHER + 1e-9), nd); gn = np.where(cut, 0, newok)
            go = np.where((go + gn == 0) & (nd + newok > 0), 1, go)
            inf = go * P_OTHER + gn * P_NEW + P_NEW >= T  # the goal filled T: a closed ring says the learner gave T
            wb = week < np.minimum(np.floor(np.maximum(left, 0) / P_NEW + 1e-9), np.minimum(ceil, rem))  # next week set the new cards
        gc = go * P_OTHER + gn * P_NEW; ws = Wm[:, t] * 60 * st; e = E[:, t]
        closed = st & (ws >= gc - 1e-9)
        bud = np.where(e, ws, np.minimum(ws, gc)) * st
        no = np.where(e, np.minimum(nd, np.floor(bud / P_OTHER + 1e-9)), np.minimum(go, np.floor(bud / P_OTHER + 1e-9)))
        nw = np.floor(np.maximum(bud - no * P_OTHER, 0) / P_NEW + 1e-9)
        nw = np.where(e, np.minimum(nw, rem), np.minimum(nw, gn)).astype(int); no = no.astype(int)
        key = np.where(isdue, R, np.inf); thr = np.sort(key, 1)[rows, np.maximum(no - 1, 0)]
        done = isdue & (key <= thr[:, None]) & (no > 0)[:, None]
        ok = done & (rng.random((B, N)) < R)
        bad = done & ~ok
        Sn = np.where(ok, srecall(D, S, R), sshort(sforget(D, S, R), 3))
        D = np.where(ok, dnext(D, 3), np.where(bad, dnext(dnext(D, 1), 3), D)); S = np.where(done, Sn, S)
        new = (ix >= nn[:, None]) & (ix < (nn + nw)[:, None]); ag = new & (rng.random((B, N)) < A_NEW)
        S = np.where(new, np.where(ag, sshort(sshort(W[0], 3), 3), sshort(sshort(W[2], 3), 3)), S)
        D = np.where(new, np.where(ag, dnext(dnext(d0(1), 3), 3), dnext(dnext(d0(3), 3), 3)), D)
        upd = done | new; last = np.where(upd, t, last); due = np.where(upd, t + np.maximum(1, np.round(S)).astype(int), due)
        nn = nn + nw; wk = no * P_OTHER + nw * P_NEW
        for k, x in (('study', st), ('closed', closed), ('goal', gc), ('worked', wk), ('T', T), ('due', nd),
                     ('overdue', (intro & (due < t)).sum(1)), ('new', nw), ('rev', done.sum(1)), ('ok', ok.sum(1)), ('week', wb & st)):
            log[k][:, t] = x
        T = step(T, st & (gc > 0), closed, inf, wk, gc); wasopen = np.where(st & (gc > 0), ~closed, wasopen)
    words = np.where(ix < nn[:, None], retr(days - last, S), 0).sum(1)
    return log, words, nn


def metrics(log, words):
    st = log['study'] > 0; ns = np.maximum(st.sum(1), 1); cl = log['closed'] > 0
    first = st[:, :14]; o7 = np.cumsum(st, 1) <= 7; runs = np.zeros(st.shape[0]); cur = np.zeros(st.shape[0])
    for t in range(st.shape[1]):  # the longest run of open rings over study days
        cur = np.where(st[:, t], np.where(cl[:, t], 0, cur + 1), cur); runs = np.maximum(runs, cur)
    return dict(closure=cl.sum(1) / ns, c14=(cl[:, :14] & first).sum(1) / np.maximum(first.sum(1), 1),
                words=words, minutes=log['worked'].sum(1) / ns / 60, openrun=runs,
                retention=log['ok'].sum(1) / np.maximum(log['rev'].sum(1), 1),
                overdue=(log['overdue'] * st).sum(1) / ns, T14=log['T'][:, 13] / 60,
                peak=(log['goal'].max(1) / 60), week1=(cl | ~st | ~o7).all(1) * 1., goalcv=np.array([np.std(g[x]) / max(np.mean(g[x]), 1e-9) for g, x in zip(log['goal'], st)]), wkbound=log['week'].sum(1) / ns, new1=(log['new'][:, :7] * st[:, :7]).sum(1) / np.maximum(st[:, :7].sum(1), 1), new4=(log['new'][:, 30:] * st[:, 30:]).sum(1) / np.maximum(st[:, 30:].sum(1), 1))


# ---------- learners ----------
def scenarios(seeds, days, rng):
    d = np.arange(days); c = lambda x: np.full(days, float(x))
    sc = {  # name: (median willingness by day, sigma, share of days skipped, veteran)
        'newcomer 5': (c(5), .5, .15, 0), 'newcomer 10': (c(10), .5, .15, 0), 'newcomer 20': (c(20), .5, .15, 0),
        'ramp 5-15': (np.interp(d, [0, 30], [5, 15]), .5, .15, 0), 'decline 15-6': (np.interp(d, [0, 30], [15, 6]), .5, .15, 0),
        'vacation 10 d': (np.where((d >= 50) & (d < 60), 0., 10.), .5, .15, 0),
        'erratic 10': (c(10), .9, .3, 0), 'small deck 400, 15': (c(15), .5, .15, 2),
        'small deck 400, new deck on day 60': (c(15), .5, .15, 6),
        'deck limit 10 new, 10-day break at day 60': (np.where((d >= 60) & (d < 70), 0., 20.), .5, .15, 7),
        'veteran 25': (c(25), .4, .1, 1), 'veteran 45': (c(45), .4, .1, 1),
        'veteran 25, history': (c(25), .4, .1, 3), 'veteran 45, history': (c(45), .4, .1, 4),
        'heavy veteran 60, history': (c(60), .4, .1, 5)}
    Wm, vet, names, size, vt0, heavy, refill, ceil = [], [], [], [], [], [], [], []
    for name, (lv, sg, skip, v) in sc.items():
        x = lv * np.exp(sg * rng.standard_normal((seeds, days))) * (rng.random((seeds, days)) >= skip)
        Wm.append(x); vet += [v in (1, 3, 4, 5)] * seeds; vt0 += [{3: 1080., 4: 1800., 5: 3000.}.get(v, np.nan)] * seeds; heavy += [v == 5] * seeds; names += [name] * seeds; size += [400 if v in (2, 6) else N] * seeds; refill += [60 if v == 6 else 1 << 30] * seeds; ceil += [10 if v == 7 else CEIL] * seeds
    return np.concatenate(Wm), np.array(vet, bool), np.array(names), list(sc), np.array(size), np.array(vt0), np.array(heavy), np.array(refill), np.array(ceil)

def load_real(folder, days):
    """Each user's minutes a calendar day (durations capped at 60 s) over the first `days` days of the log."""
    import pyarrow.parquet as pq
    out = []
    for f in sorted(glob.glob(os.path.join(folder, '**', '*.parquet'), recursive=True)):
        t = pq.read_table(f, columns=['day_offset', 'duration'])
        dd = t['day_offset'].to_numpy().astype(int); m = np.minimum(t['duration'].to_numpy(), 60000) / 60000
        s = np.bincount(dd - dd.min(), weights=m)
        if len(s) >= days and (s[:days] > 0).sum() >= days // 3: out.append(s[:days])
    return np.array(out)


C = target(.779)  # 1.075 / 0.775
RULES = {  # the chosen rule first, then each alternative changed in one respect; (rule, ring, next-week bound)
    'chosen: tracker 1.075/0.775, hold, 2.5 min, 2-60': (tracker(*C, hold=True), 'cut', False),
    'Mnemit 5.4: no hold, 4 min, 2-30, next-week bound': (tracker(*C, t0=240, hi=1800), 'cut', True),
    'closure .70': (tracker(*target(.70), hold=True), 'cut', False),
    'closure .85': (tracker(*target(.85), hold=True), 'cut', False),
    'closure .90': (tracker(*target(.90), hold=True), 'cut', False),
    'closure .95': (tracker(*target(.95), hold=True), 'cut', False),
    'no hold': (tracker(*C), 'cut', False),
    'start 2 min': (tracker(*C, hold=True, t0=120), 'cut', False),
    'start 3 min': (tracker(*C, hold=True, t0=180), 'cut', False),
    'start 4 min': (tracker(*C, hold=True, t0=240), 'cut', False),
    'start 8 min': (tracker(*C, hold=True, t0=480), 'cut', False),
    'flat first week': (tracker(*C, hold=True, t0=240, flat=7), 'cut', False),
    'slow start x1.15': (tracker(*C, hold=True, slow=1.15), 'cut', False),
    '2-30 min': (tracker(*C, hold=True, hi=1800), 'cut', False),
    'next-week bound': (tracker(*C, hold=True), 'cut', True),
    'every card due': (tracker(*C, hold=True), 'all', False),
    'new cards for 30 days ahead': (tracker(*C, hold=True), 'cutload', False),
    'EF1: every card due + X new for 30 days ahead': (tracker(*C, hold=True), 'load', False),
    'EF2: closed share of 7 days': (window(.779), 'cut', False),
    'EF3 max: every card due, new up to the log-mean': (logmean(14), 'all', False),
    'EF3 min: the plan cut at the log-mean': (logmean(14), 'cut', False),
    'EF4: the ring holds words in memory': (fixed(600), 'memory', False),
    'Kaplan-Meier q .15, 21 d': (km(.15, 21), 'cut', False),
    'median of 7 study days': (median(7), 'cut', False),
    'fixed 10 min': (fixed(600), 'cut', False),
    'Anki: all due + 20 new': (fixed(600), 'anki', False),
}
COLS = ('closure', 'c14', 'week1', 'openrun', 'words', 'minutes', 'retention', 'overdue', 'T14', 'peak', 'goalcv', 'wkbound', 'new1', 'new4')

def table(head, rows): print('| ' + ' | '.join(head) + ' |\n|' + '---|' * len(head)); [print('| ' + ' | '.join(map(str, r)) + ' |') for r in rows]
def fmt(m, sel): return [f"{m[k][sel].mean():.3f}" if k in ('closure', 'c14', 'retention', 'week1', 'wkbound', 'goalcv') else f"{m[k][sel].mean():.1f}" for k in COLS]

def selftest():
    assert abs(retr(10, 10.) - .9) < 1e-12  # R falls to 0.9 after S days, so the interval at 0.9 is S
    assert abs(sshort(sshort(W[2], 3), 3) - W[2]) < 1e-12  # Good steps keep a Good first answer's stability
    rng = np.random.default_rng(1); Wm = np.full((20, 60), 10.); E = np.zeros_like(Wm, bool)
    log, w, nn = run(tracker(1.075, .775), 'cut', Wm, E, np.zeros(20, bool), rng)
    m = metrics(log, w); assert m['c14'].mean() > .9 and 0.6 < m['closure'].mean() < 0.95, m['closure'].mean()
    log, w, nn = run(fixed(600), 'anki', Wm, E, np.zeros(20, bool), rng); assert (nn == 20 * 60).all() or nn.min() > 0
    print('selftest ok')

def main():
    global P_NEW, P_OTHER, SKIP
    ap = argparse.ArgumentParser(); ap.add_argument('--real'); ap.add_argument('--seeds', type=int, default=40)
    ap.add_argument('--days', type=int, default=120); ap.add_argument('--prices', type=float, nargs=2)
    ap.add_argument('--rules'); ap.add_argument('--skip', type=float, default=0.); ap.add_argument('--resp', default='SE'); ap.add_argument('--selftest', action='store_true'); a = ap.parse_args()
    if a.selftest: return selftest()
    if a.prices: P_NEW, P_OTHER = a.prices
    SKIP = a.skip
    rng = np.random.default_rng(307)
    Wm, vet, names, scen, size, vt0, heavy, refill, ceil = scenarios(a.seeds, a.days, rng)
    if a.real:
        R = load_real(a.real, a.days); print(f'real users with {a.days} days: {len(R)}\n')
        Wm = np.concatenate([Wm, R]); vet = np.append(vet, np.zeros(len(R), bool)); names = np.append(names, ['real'] * len(R)); size = np.append(size, np.full(len(R), N)); vt0 = np.append(vt0, np.full(len(R), np.nan)); heavy = np.append(heavy, np.zeros(len(R), bool)); refill = np.append(refill, np.full(len(R), 1 << 30)); ceil = np.append(ceil, np.full(len(R), CEIL))
    groups = [(s, names == s) for s in scen] + ([('real users', names == 'real')] if a.real else [])
    rules = {k: v for k, v in RULES.items() if not a.rules or any(s in k for s in a.rules.split(';'))}
    for resp in a.resp:
        E = np.full(Wm.shape, resp == 'E')
        print(f"\n## Response {resp}, skip after an open ring {SKIP} ({'stops at the ring' if resp == 'S' else 'goes on: catch up, then more new cards'})")
        res = {}
        for name, (rule, comp, *ah) in rules.items():
            log, w, nn = run(rule, comp, Wm, E, vet, np.random.default_rng(308), size, *ah, vt0=vt0, heavy=heavy, refill=refill, ceil=ceil); res[name] = metrics(log, w)
        table(['rule'] + list(COLS), [[n] + fmt(m, ~vet & (names != 'real')) for n, m in res.items()])
        for g, sel in groups:
            print(f'\n### {g}'); table(['rule'] + list(COLS), [[n] + fmt(m, sel) for n, m in res.items()])

if __name__ == '__main__': main()
