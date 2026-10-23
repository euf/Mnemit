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
SCHED = 'plain'  # due dates: 'plain' (the interval), 'fuzz' (Mnemit's fuzz, py-fsrs ranges), 'balance' (fuzz + Anki's load balancer)
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

def newwin(k, up, down, n0, lo=1., hi=100.):
    """EF's queue: the state is N, the new cards of a day. After each study day, all of the last k rings closed: N * up; most
    of them open: N * down; else N stays. With k 1 it is the closure tracker on N."""
    def mk(B):
        h, n = np.zeros((B, k)), np.zeros(B, int)
        def step(N, st, cl, inf, wk, g):
            h[st] = np.roll(h[st], 1, 1); h[st, 0] = cl[st]; n[st] = np.minimum(n[st] + 1, k)
            p = h.sum(1) / np.maximum(n, 1)
            f = np.where(p >= 1 - 1e-9, up, np.where(p < 0.5, down, 1.))
            return np.where(st, np.clip(N * f, lo, hi), N)
        return np.full(B, n0), step
    return mk

def staircase(k, up, down, hold=True, lo=LO, hi=HI, t0=T0):
    """T grows by up only after k closed rings in a row that filled T, an open ring takes it down by down, anything else
    keeps it: the ring tests the learner once a run of k days instead of after every closed ring."""
    def mk(B):
        run = np.zeros(B, int)
        def step(T, st, cl, inf, wk, g):
            ok = st & cl & (inf | (not hold)); run[ok] += 1; run[st & ~cl] = 0
            grow = run >= k; run[grow] = 0
            f = np.where(st & ~cl, down, np.where(grow, up, 1.))
            return np.where(st, np.clip(T * f, lo, hi), T)
        return np.full(B, t0), step
    return mk

def pest(c, a0=2 * np.log(1.075 / .775), amin=np.log(1.075 / .775) / 2, amax=2 * np.log(1.075 / .775), hold=True):
    """Kaernbach's weighted up-down with PEST's step rule (Taylor & Creelman 1967): log-step a, closed T * exp(a (1 - c)),
    open T * exp(-a c), so the closure share stays c; a halves at each reversal and doubles after three moves the same way."""
    def mk(B):
        a, last, same = np.full(B, a0), np.zeros(B), np.zeros(B)
        def step(T, st, cl, inf, wk, g):
            go = st & (inf | ~cl | (not hold)); d = np.where(cl, 1., -1.)
            rev = go & (last != 0) & (d != last); run = go & (d == last)
            same[go] = np.where(run[go], same[go] + 1, 1)
            a[rev] = np.maximum(amin, a[rev] / 2); grow = go & (same >= 3); a[grow] = np.minimum(amax, a[grow] * 2); same[grow] = 0
            last[go] = d[go]
            f = np.where(cl, np.exp(a * (1 - c)), np.exp(-a * c))
            return np.where(go, np.clip(T * f, LO, HI), T)
        return np.full(B, T0), step
    return mk

def bayes(c, keep=.97, sigmas=(.2, .35, .5, .7, .9, 1.2, 1.5)):
    """QUEST-like (Watson & Pelli 1983): a posterior over the learner's typical log seconds mu and day-to-day spread sigma.
    An open ring shows the day's willingness (the work done); a closed one only that it was at least the work. Old evidence
    fades by `keep` a study day. T is the (1 - c) quantile of willingness at the posterior means of mu and sigma."""
    from statistics import NormalDist
    mu = np.arange(np.log(60), np.log(7200), .05)[:, None]; sg = np.array(sigmas)[None]; z = NormalDist().inv_cdf(1 - c)
    def mk(B):
        lp = np.broadcast_to(-0.5 * ((mu - np.log(600)) / 1.0) ** 2, (len(mu), len(sigmas))) + np.zeros((B, len(mu), len(sigmas)))
        def step(T, st, cl, inf, wk, g):
            x = np.log(np.maximum(wk, 1.))[:, None, None]; zz = (x - mu[None]) / sg[None]
            open_ = -0.5 * zz ** 2 - np.log(sg[None]); closed = np.log(np.maximum(0.5 * (1 - erf(zz / np.sqrt(2))), 1e-12))
            ll = np.where(cl[:, None, None], closed, open_)
            upd = st & (wk > 0)
            lp[upd] = keep * lp[upd] + ll[upd]
            w = np.exp(lp - lp.max((1, 2), keepdims=True)); w /= w.sum((1, 2), keepdims=True)
            m, s = (w * mu[None]).sum((1, 2)), (w * sg[None]).sum((1, 2))
            return np.where(upd, np.clip(np.exp(m + s * z), LO, HI), T)
        return np.full(B, T0), step
    return mk

def erf(x):  # Abramowitz-Stegun 7.1.26
    t = 1 / (1 + 0.3275911 * np.abs(x))
    y = 1 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * np.exp(-x * x)
    return np.sign(x) * y

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
def schedule(t, ivl, upd, due, intro, rng):
    """Due days for the cards in `upd` with intervals `ivl`: as they are, fuzzed in py-fsrs's ranges (Scheduler.fuzzed), or
    load-balanced as Anki 24.11 does (rslib load_balancer.rs): within the fuzz range of an interval up to 90 days, a day
    with nothing due weighs 1, another (1 / its cards)^2.15 * (1 / the interval)^3, drawn at random; the cards of a day
    are placed in four batches, each seeing the loads the earlier ones made."""
    plain = t + ivl
    if SCHED == 'plain':
        return np.where(upd, plain, due)
    d = 1 + .15 * np.clip(ivl - 2.5, 0, 4.5) + .1 * np.clip(ivl - 7, 0, 13) + .05 * np.maximum(ivl - 20, 0)
    lo = np.maximum(2, np.round(ivl - d)).astype(int); hi = np.round(ivl + d).astype(int); lo = np.minimum(lo, hi)
    fz = upd & (ivl >= 3)
    out = np.where(upd, plain, due)
    u = lo + np.floor(rng.random(ivl.shape) * (hi - lo + 1)).astype(int)
    out = np.where(fz, t + u, out)
    if SCHED != 'balance':
        return out
    H = 110; B = due.shape[0]
    counts = np.zeros((B, H))
    rel = due - t; keep = intro & ~upd & (rel > 0) & (rel < H)
    rb, cj = np.nonzero(keep); np.add.at(counts, (rb, rel[rb, cj]), 1)
    rb, cj = np.nonzero(fz & (ivl <= 90))
    if not len(rb):
        return out
    order = rng.permutation(len(rb)); rb, cj = rb[order], cj[order]
    K = int((hi[rb, cj] - lo[rb, cj]).max()) + 1
    for part in np.array_split(np.arange(len(rb)), 4):
        b, j = rb[part], cj[part]
        cand = lo[b, j][:, None] + np.arange(K)[None]; valid = cand <= hi[b, j][:, None]; cand = np.minimum(cand, H - 1)
        cnt = counts[b[:, None], cand]
        w = np.where(cnt == 0, 1., (1 / np.maximum(cnt, 1)) ** 2.15 * (1. / cand) ** 3) * valid
        cum = np.cumsum(w, 1); r = rng.random(len(b)) * cum[:, -1]
        pick = cand[np.arange(len(b)), np.minimum((cum < r[:, None]).sum(1), K - 1)]
        out[b, j] = t + pick; np.add.at(counts, (b, pick), 1)
    return out

def load30():
    """Reviews in the H days after its first day of a new card answered right at 0.9 on each due day, over 0.9 for the
    lapses: what one more new card a day adds to each later day's reviews once the intake runs steady."""
    S, D, t, n = W[2], d0(3), 0, 0
    while t + max(1, round(S)) <= H:
        t += max(1, round(S)); n += 1; S, D = srecall(D, S, .9), dnext(D, 3)
    return n / .9

def run(rule, comp, Wm, E, vet, rng, size=None, weekly=True, vt0=None, heavy=None, refill=None, ceil=None, smooth=None):
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
    T, step = rule(B); wasopen = np.zeros(B, bool); avgnew = np.full(B, np.nan)
    if vt0 is not None: T = np.where(np.isnan(vt0), T, vt0)
    log = {k: np.zeros((B, days)) for k in ('study', 'closed', 'goal', 'worked', 'T', 'due', 'overdue', 'new', 'rev', 'ok', 'week', 'none', 'kept', 'over', 'gn')}
    for t in range(days):
        st = (Wm[:, t] > 0) & ~(wasopen & (rng.random(B) < SKIP)); intro = ix < nn[:, None]; isdue = intro & (due <= t); R = retr(t - last, S)
        nd = isdue.sum(1); ahead = (intro & (due > t) & (due <= t + 7)).sum(1); rem = np.where(t >= refill, N, size) - nn
        a30 = (intro & (due > t) & (due <= t + H)).sum(1) / H
        room = T / P_OTHER - ahead / 7
        week = np.where(room >= 0, np.floor(room / LOAD + 1e-9), 0) if weekly else np.full(B, np.inf)
        if comp == 'anki':
            go, gn = np.minimum(nd, 200), np.minimum(ceil, rem); inf = np.ones(B, bool); wb = np.zeros(B, bool); none = gn == 0
        elif comp in ('queue', 'queue200'):  # EF's queue: every card due (up to 200 a day in queue200) + N new, N from the rule
            go = np.minimum(nd, 200) if comp == 'queue200' else nd; gn = np.minimum(np.round(T), rem)
            inf = np.ones(B, bool); wb = np.zeros(B, bool); none = gn == 0
        elif comp == 'load':  # EF's idea 1: every card due + X new, X the steady intake that T carries with its later reviews, at least 1
            x = np.floor(np.maximum(T - a30 * P_OTHER, 0) / (P_NEW + R30 * P_OTHER) + 1e-9)
            go, gn = nd, np.minimum(np.maximum(x, 1), np.minimum(ceil, rem)); inf = x <= np.minimum(ceil, rem); wb = np.zeros(B, bool); none = gn == 0
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
            inf = np.ones(B, bool); wb = np.zeros(B, bool); none = gn == 0
        else:
            left = T - nd * P_OTHER if comp in ('cut', 'cutload', 'cut1in', 'cut1top') else np.maximum(T - nd * P_OTHER, 0)
            if comp == 'cutload':
                x = np.floor(np.maximum(T - a30 * P_OTHER, 0) / (P_NEW + R30 * P_OTHER) + 1e-9)
                left = np.minimum(left, np.maximum(x, 1) * P_NEW); week = np.full(B, np.inf)
            newok = np.minimum.reduce([np.floor(np.maximum(left, 0) / P_NEW + 1e-9), week, ceil * 1., rem])
            if smooth:  # new cards no more than `smooth` times their recent average (an EWMA over study days), at least 2
                newok = np.where(np.isnan(avgnew), newok, np.minimum(newok, np.maximum(2, np.ceil(smooth * avgnew))))
            cut = (nd * P_OTHER > T) & (comp in ('cut', 'cutload', 'cut1in', 'cut1top'))
            go = np.where(cut, np.floor(T / P_OTHER + 1e-9), nd); gn = np.where(cut, 0, newok)
            go = np.where((go + gn == 0) & (nd + newok > 0), 1, go)
            inf = go * P_OTHER + gn * P_NEW + P_NEW >= T  # the goal filled T: a closed ring says the learner gave T
            none = (gn == 0) & (np.minimum(ceil, rem) > 0)  # the time admitted no new card though the decks had some
            if comp in ('cut1in', 'cut1top'):  # at least one new card a day: inside T, in place of the last reviews, or on top of it
                if comp == 'cut1in': go = np.where(none, np.minimum(go, np.floor(np.maximum(T - P_NEW, 0) / P_OTHER + 1e-9)), go)
                gn = np.where(none, 1, gn)
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
        upd = done | new; last = np.where(upd, t, last); due = schedule(t, np.maximum(1, np.round(S)).astype(int), upd, due, intro, rng)
        nn = nn + nw; wk = no * P_OTHER + nw * P_NEW
        for k, x in (('study', st), ('closed', closed), ('goal', gc), ('worked', wk), ('T', T), ('due', nd),
                     ('overdue', (intro & (due < t)).sum(1)), ('new', nw), ('rev', done.sum(1)), ('ok', ok.sum(1)), ('week', wb & st), ('none', none & st), ('kept', st & (no >= nd)), ('over', np.where(st, np.maximum(nd - go, 0), 0)), ('gn', np.where(st, gn, 0))):
            log[k][:, t] = x
        avgnew = np.where(st, np.where(np.isnan(avgnew), gn, 0.75 * np.nan_to_num(avgnew) + 0.25 * gn), avgnew)
        T = step(T, st & (gc > 0), closed, inf, wk, gc); wasopen = np.where(st & (gc > 0), ~closed, wasopen)
    words = np.where(ix < nn[:, None], retr(days - last, S), 0).sum(1)
    return log, words, nn


def metrics(log, words):
    st = log['study'] > 0; ns = np.maximum(st.sum(1), 1); cl = log['closed'] > 0
    first = st[:, :14]; o7 = np.cumsum(st, 1) <= 7; runs = np.zeros(st.shape[0]); cur = np.zeros(st.shape[0])
    nr, ncur, no = np.zeros(st.shape[0]), np.zeros(st.shape[0]), log['none'] > 0
    for t in range(st.shape[1]):  # the longest runs of open rings and of rings without a new card, over study days
        cur = np.where(st[:, t], np.where(cl[:, t], 0, cur + 1), cur); runs = np.maximum(runs, cur)
        ncur = np.where(st[:, t], np.where(no[:, t], ncur + 1, 0), ncur); nr = np.maximum(nr, ncur)
    cut = (log['over'] > 0) & st; crun, ccur = np.zeros(st.shape[0]), np.zeros(st.shape[0])
    for t in range(st.shape[1]):  # the longest run of days whose plan didn't fit the time
        ccur = np.where(st[:, t], np.where(cut[:, t], ccur + 1, 0), ccur); crun = np.maximum(crun, ccur)
    over = np.where(cut, log['over'], np.nan); gnm = np.where(st[:, 30:], log['gn'][:, 30:], np.nan)
    med = np.nanmedian(gnm, 1)
    extra = dict(cutshare=cut.sum(1) / ns, cutrun=crun, catch50=np.nan_to_num(np.nanmedian(over, 1)), catch90=np.nan_to_num(np.nanpercentile(over, 90, 1)),
                 newcv=np.nan_to_num(np.nanstd(gnm, 1) / np.maximum(np.nanmean(gnm, 1), 1e-9)), surge=np.nan_to_num(np.nanmean(np.where(st[:, 30:], log['gn'][:, 30:] >= 2 * np.maximum(med, 1)[:, None], np.nan), 1)))
    Ts = np.where(st, log['T'], np.nan); prev = np.full(st.shape[0], np.nan); chg = np.zeros(st.shape[0]); nst = np.zeros(st.shape[0])
    for t in range(st.shape[1]):  # the share of study days whose ring differs in size from the study day before
        x = Ts[:, t]; ok = ~np.isnan(x) & ~np.isnan(prev); chg += ok & (np.abs(x - np.nan_to_num(prev)) > 1e-6); nst += ok; prev = np.where(np.isnan(x), prev, x)
    opn = st & ~cl & (log['goal'] > 0)
    extra.update(tchange=chg / np.maximum(nst, 1), missdepth=np.nan_to_num(np.nanmean(np.where(opn, log['worked'] / np.maximum(log['goal'], 1e-9), np.nan), 1)),
                 grow=np.nan_to_num(np.nanmean(np.where(st[:, 1:] & st[:, :-1], np.log(np.maximum(log['T'][:, 1:], 1) / np.maximum(log['T'][:, :-1], 1)), np.nan), 1)))
    return dict(**extra, closure=cl.sum(1) / ns, c14=(cl[:, :14] & first).sum(1) / np.maximum(first.sum(1), 1),
                words=words, minutes=log['worked'].sum(1) / ns / 60, openrun=runs,
                retention=log['ok'].sum(1) / np.maximum(log['rev'].sum(1), 1),
                overdue=(log['overdue'] * st).sum(1) / ns, T14=log['T'][:, 13] / 60,
                peak=(log['goal'].max(1) / 60), week1=(cl | ~st | ~o7).all(1) * 1., goalcv=np.array([np.std(g[x]) / max(np.mean(g[x]), 1e-9) for g, x in zip(log['goal'], st)]), wkbound=log['week'].sum(1) / ns, nonew=log['none'].sum(1) / ns, fsrs=log['kept'].sum(1) / ns, nonewrun=nr, new1=(log['new'][:, :7] * st[:, :7]).sum(1) / np.maximum(st[:, :7].sum(1), 1), new4=(log['new'][:, 30:] * st[:, 30:]).sum(1) / np.maximum(st[:, 30:].sum(1), 1))


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
    'new cards at most 1.25x their average': (tracker(*C, hold=True), 'cut', False, 1.25),
    'new cards at most 1.5x their average': (tracker(*C, hold=True), 'cut', False, 1.5),
    'new cards at most 2x their average': (tracker(*C, hold=True), 'cut', False, 2.),
    'at least 1 new card, inside T': (tracker(*C, hold=True), 'cut1in', False),
    'at least 1 new card, on top of T': (tracker(*C, hold=True), 'cut1top', False),
    'new cards for 30 days ahead': (tracker(*C, hold=True), 'cutload', False),
    'EF1: every card due + X new for 30 days ahead': (tracker(*C, hold=True), 'load', False),
    'EF2: closed share of 7 days': (window(.779), 'cut', False),
    'EF3 max: every card due, new up to the log-mean': (logmean(14), 'all', False),
    'EF3 min: the plan cut at the log-mean': (logmean(14), 'cut', False),
    'EF4: the ring holds words in memory': (fixed(600), 'memory', False),
    'Levitt: 2 closed in a row x1.10, open x0.85': (staircase(2, 1.10, .85), 'cut', False),
    'Levitt: 2 closed in a row x1.15, open x0.775': (staircase(2, 1.15, .775), 'cut', False),
    'PEST steps, closure .78': (pest(.779), 'cut', False),
    'Bayes (QUEST-like), closure .78': (bayes(.779), 'cut', False),
    'Bayes (QUEST-like), closure .85': (bayes(.85), 'cut', False),
    'staircase 7, x1.10 / x0.775': (staircase(7, 1.10, .775), 'cut', False),
    'staircase 7, x1.15 / x0.85': (staircase(7, 1.15, .85), 'cut', False),
    'staircase 5, x1.10 / x0.85': (staircase(5, 1.10, .85), 'cut', False),
    'staircase 3, x1.10 / x0.85': (staircase(3, 1.10, .85), 'cut', False),
    'queue: all due + N new, N tracker 1.075/0.775, start 20': (newwin(1, 1.075, .775, 20), 'queue', False),
    'queue: all due + N new, N by last 5 rings, start 20': (newwin(5, 1.15, .8, 20), 'queue', False),
    'queue: all due + N new, N by last 5 rings, start 10': (newwin(5, 1.15, .8, 10), 'queue', False),
    'queue: all due + N new, N by last 5 rings, start 5': (newwin(5, 1.15, .8, 5), 'queue', False),
    'queue: all due + N new, N by last 3 rings, start 10': (newwin(3, 1.15, .8, 10), 'queue', False),
    'queue: up to 200 due + N new, N by last 5 rings, start 10': (newwin(5, 1.15, .8, 10), 'queue200', False),
    'Kaplan-Meier q .15, 21 d': (km(.15, 21), 'cut', False),
    'median of 7 study days': (median(7), 'cut', False),
    'fixed 10 min': (fixed(600), 'cut', False),
    'Anki: all due + 20 new': (fixed(600), 'anki', False),
}
COLS = ('tchange', 'missdepth', 'closure', 'cl_p10', 'cl_p90', 'fsrs', 'fs_p10', 'fs_p90', 'cutshare', 'cutrun', 'catch50', 'catch90', 'newcv', 'surge', 'c14', 'week1', 'openrun', 'words', 'minutes', 'retention', 'overdue', 'T14', 'peak', 'goalcv', 'wkbound', 'nonew', 'nonewrun', 'new1', 'new4')

def table(head, rows): print('| ' + ' | '.join(head) + ' |\n|' + '---|' * len(head)); [print('| ' + ' | '.join(map(str, r)) + ' |') for r in rows]
def fmt(m, sel): return [f"{np.percentile(m['fsrs'][sel], 10):.3f}" if k == 'fs_p10' else f"{np.percentile(m['fsrs'][sel], 90):.3f}" if k == 'fs_p90' else f"{np.percentile(m['closure'][sel], 10):.3f}" if k == 'cl_p10' else f"{np.percentile(m['closure'][sel], 90):.3f}" if k == 'cl_p90' else f"{m[k][sel].mean():.3f}" if k in ('tchange', 'missdepth', 'closure', 'c14', 'retention', 'week1', 'wkbound', 'goalcv', 'nonew', 'fsrs', 'cutshare', 'newcv', 'surge') else f"{m[k][sel].mean():.1f}" for k in COLS]

def noos(newpd=20, days=365, seeds=20):
    """The routine of Noos's FSRS simulator (noosflashcards.com/resources/fsrs-simulator), as its page describes it: FSRS-6
    defaults, whole-day intervals, no steps within the day, no fuzz, every due card answered and recalled with probability
    R; first answers Again/Hard/Good/Easy 24/9/50/17 %, recalled Hard/Good/Easy 22/63/15 % (the Anki simulator's defaults);
    answers = cards answered a day. Their figures at 80/85/90/95 %: 133/161/204/308 answers a day."""
    rng = np.random.default_rng(7); n = newpd * days
    def srec(D, S, R, g):
        return S * (1 + np.exp(W[8]) * (11 - D) * S ** -W[9] * (np.exp((1 - R) * W[10]) - 1) * np.where(g == 2, W[15], np.where(g == 4, W[16], 1.)))
    for target in (.80, .85, .90, .95):
        ivl = lambda S: np.maximum(1, np.round(S / FACTOR * (target ** (1 / DECAY) - 1)))
        S, D, last, due = np.ones((seeds, n)), np.full((seeds, n), 5.), np.zeros((seeds, n)), np.full((seeds, n), 1e9)
        ans = np.zeros((seeds, days))
        for t in range(days):
            new = (np.arange(n) >= t * newpd) & (np.arange(n) < (t + 1) * newpd)
            g = rng.choice([1, 2, 3, 4], size=(seeds, n), p=[.24, .09, .50, .17])
            S = np.where(new, W[g - 1], S); D = np.where(new, np.clip(d0(g), 1, 10), D); last = np.where(new, t, last); due = np.where(new, t + ivl(S), due)
            isdue = (due <= t) & ~new; R = retr(t - last, S); ok = rng.random((seeds, n)) < R
            gr = rng.choice([2, 3, 4], size=(seeds, n), p=[.22, .63, .15])
            S, D = np.where(isdue, np.where(ok, srec(D, S, R, gr), sforget(D, S, R)), S), np.where(isdue, np.where(ok, dnext(D, gr), dnext(D, 1)), D)
            last = np.where(isdue, t, last); due = np.where(isdue, t + ivl(S), due); ans[:, t] = isdue.sum(1) + newpd
        rem = retr(days - last, S).sum(1).mean()
        print(f"retention {target:.2f}: answers/day {ans[:, -30:].mean():.0f}, busiest {ans.max(1).mean():.0f}, remembered {rem:.0f} ({rem / n:.0%}), total {ans.sum(1).mean():.0f}")

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
    ap.add_argument('--rules'); ap.add_argument('--skip', type=float, default=0.); ap.add_argument('--resp', default='SE'); ap.add_argument('--sched', default='plain'); ap.add_argument('--selftest', action='store_true'); ap.add_argument('--noos', action='store_true'); a = ap.parse_args()
    if a.selftest: return selftest()
    if a.noos: return noos()
    if a.prices: P_NEW, P_OTHER = a.prices
    SKIP = a.skip; global SCHED; SCHED = a.sched
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
            log, w, nn = run(rule, comp, Wm, E, vet, np.random.default_rng(308), size, *ah[:1], smooth=(ah[1] if len(ah) > 1 else None), vt0=vt0, heavy=heavy, refill=refill, ceil=ceil); res[name] = metrics(log, w)
        table(['rule'] + list(COLS), [[n] + fmt(m, ~vet & (names != 'real')) for n, m in res.items()])
        for g, sel in groups:
            print(f'\n### {g}'); table(['rule'] + list(COLS), [[n] + fmt(m, sel) for n, m in res.items()])

if __name__ == '__main__': main()
