# Leech sizing on real review logs

Users 2000, rows 142436745 (dropped state 4 / bad rating: 1963442), cards 18843583, cards with >= 365 d of history before the log end: 13429307. Time capped at 60 s per review.

### 1. Lapses per card at the end of the log (per-user columns: users with >= 100 cards)
| lapses | all cards, pooled | cards >= 365 d old, pooled | per-user median % | p25 | p75 | users with >= 1 such card |
|---|---|---|---|---|---|---|
| >= 1 | 22.03% | 23.43% | 20.63 | 9.371 | 35.44 | 99.60% |
| >= 2 | 10.34% | 11.34% | 6.792 | 1.858 | 16.47 | 95.70% |
| >= 3 | 5.91% | 6.63% | 2.496 | 0.390 | 8.511 | 91.25% |
| >= 4 | 3.76% | 4.31% | 1.029 | 0.088 | 4.772 | 84.45% |
| >= 6 | 1.85% | 2.20% | 0.169 | 0 | 1.495 | 69.15% |
| >= 8 | 1.05% | 1.28% | 0.026 | 0 | 0.449 | 55.95% |
| >= 12 | 0.37% | 0.47% | 0 | 0 | 0.019 | 29.35% |
| >= 16 | 0.19% | 0.25% | 0 | 0 | 0 | 19.75% |

### 2. Recall (rating > 1) of Review-state reviews after the card reaches k lapses
| k | cards | users | with a later Review row | recall after k | reviews | recall, next 5 | reviews | recall, all reviews of the same users | recall, same cards before the k-th lapse | per-user median of (after - overall), pts (p25..p75) |
|---|---|---|---|---|---|---|---|---|---|---|
| 4 | 708980 | 1689 | 93.37% | 76.42% | 9941027 | 73.13% | 2850566 | 85.89% | 65.66% | -5.926 (-10.87..-1.901) n=1330 |
| 6 | 349169 | 1383 | 93.98% | 74.40% | 5893732 | 71.69% | 1436689 | 85.54% | 64.08% | -6.234 (-12.37..-1.692) n=977 |
| 8 | 197805 | 1119 | 82.25% | 71.96% | 3752452 | 69.36% | 732436 | 85.17% | 63.03% | -6.521 (-13.62..-2.386) n=646 |

### 3. Share of review time
| cards with | all their time, pooled | per-user median | only time after the k-th lapse, pooled | per-user median | share of cards, pooled |
|---|---|---|---|---|---|
| >= 4 | 18.26% | 4.535% | 8.16% | 1.005% | 3.76% |
| >= 6 | 11.40% | 0.915% | 4.50% | 0.1486% | 1.85% |
| >= 8 | 7.63% | 0.1544% | 2.70% | 0.0027% | 1.05% |

### 4. Time from the first review to the k-th lapse
| k | cards | days median | p25 | p75 | reviews median | p25 | p75 | per-user median of median days | users (>= 5 cards) |
|---|---|---|---|---|---|---|---|---|---|
| 4 | 708980 | 77 | 24 | 226 | 17 | 14 | 22 | 69 | 1495 |
| 6 | 349169 | 125 | 42 | 315 | 26 | 21 | 33 | 104 | 1116 |
| 8 | 197805 | 168 | 62 | 384 | 35 | 28 | 43 | 144 | 805 |

### 5. After the k-th lapse: did reviews go on? (reviews = rows of any state after the k-th lapse row)
| k | cards | median | p25 | p75 | none | <= 2 | cards with >= 180 d of follow-up | median | none | <= 2 |
|---|---|---|---|---|---|---|---|---|---|---|
| 4 | 708980 | 12 | 6 | 24 | 0.61% | 9.29% | 597491 | 13 | 0.51% | 7.79% |
| 6 | 349169 | 13 | 6 | 28 | 1.38% | 7.76% | 292811 | 15 | 1.21% | 6.18% |
| 8 | 197805 | 14 | 4 | 33 | 14.41% | 19.65% | 165808 | 17 | 14.67% | 18.68% |

| cards >= 365 d old, by total lapses | cards | no review in the last 90 d of the log |
|---|---|---|
| 0 | 10282199 | 97.70% |
| 2-3 | 944189 | 90.23% |
| 4+ | 578988 | 78.12% |
| 8+ | 172382 | 72.80% |

### 6. EF's own decks (Mnemit, read-only copies)
| deck | cards in deck | review lines | cards reviewed | days covered | deck.json lapses >= 1 / 2 / 3 | approx. lapses >= 1 / 2 / 3 | max true | max approx. | reviewed cards missing in deck.json |
|---|---|---|---|---|---|---|---|---|---|
| Greek A1-A2 | 3258 | 219 | 39 | 4.8 | 6 / 3 / 0 | 4 / 1 / 0 | 2 | 2 | 0 |
| Greek B1 | 2314 | 104 | 21 | 4.9 | 3 / 1 / 0 | 4 / 1 / 0 | 2 | 2 | 0 |

Approximation: grade 1 on a card whose previous logged review is more than 1 day (86400 s) earlier; deck.json `learningState.lapses` is the scheduler's own count and is exact.

### Reading
1. A threshold of 8 touches 1.05% of cards pooled (1.28% for cards at least a year old) but is a minority event per user: median user 0.03% of cards, 56% of users have at least one, p75 0.45%. A threshold of 4 hits 3.8% of cards, 84% of users.
2. Leeches do not recover: after the 8th lapse recall is 72.0% against 85.2% for the same users overall (about 1.9 times the failure rate), next 5 reviews 69.4%; after the 4th lapse 76.4%. They hold 7.6% of all review time at 8+ lapses (2.7% after the 8th lapse), 18.3% at 4+ (8.2% after the 4th); per-user medians are far smaller (0.15% and 4.5%).
3. Reviews stop at 8 and nowhere else: 14.4% of 8-lapse cards have no review after it (0.6% at 4, 1.4% at 6), the share with a later Review row falls from 94% to 82%. That is Anki's default (threshold 8, suspend); the rest were kept: across all 8-lapse cards the median is 14 reviews afterwards (p25 4, p75 33).
4. The 8th lapse arrives late: median 168 days and 35 reviews after the first review (p25 62 d, p75 384 d); the 4th at 77 d and 17 reviews, so a threshold of 4 or 6 flags the card months earlier.
5. Pooled numbers are dominated by heavy users; "recall after k" is selected on past failures; logs are censored at their end. EF's decks are 5 days old with at most 2 lapses per card, too young to size anything; the grade-1-after-a-day approximation is off by a few cards either way against deck.json.
