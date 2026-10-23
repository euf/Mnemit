# Real review logs: ring-sim calibration statistics

Users: 2000 (user_id 1..2000). Reviews: 144400187. Ratings {1: 25231002, 2: 23255881, 3: 82510103, 4: 13403201}. States {0: 18843583, 1: 32801825, 2: 74600108, 3: 16191229, 4: 1963442} (0 New, 1 Learning, 2 Review, 3 Relearning, 4 Filtered; state 0 occurs only on a card's first review).
Durations: 1356051 reviews (0.94%) exceed 60 s and are capped to 60 s; 96009 reviews have duration 0 (kept). Minutes = sum of capped durations per day.

### 1. Activity (span and study_days in days; gap-x = share of the user's missed-day runs of length x)
| statistic (per user) | N users | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|
| span | 2000 | 1118 | 584 | 934 | 1690 | 2693 |
| study_days | 2000 | 278 | 89 | 145 | 532 | 891 |
| share | 2000 | 0.245 | 0.086 | 0.139 | 0.432 | 0.651 |
| longest_gap | 2000 | 189 | 37 | 98 | 368 | 738 |
| gap 1 | 2000 | 0.388 | 0.224 | 0.298 | 0.483 | 0.600 |
| gap 2-3 | 2000 | 0.244 | 0.138 | 0.192 | 0.286 | 0.333 |
| gap 4-7 | 2000 | 0.139 | 0.056 | 0.095 | 0.183 | 0.225 |
| gap 8-30 | 2000 | 0.118 | 0.028 | 0.071 | 0.172 | 0.227 |
| gap >30 | 2000 | 0.072 | 0.007 | 0.035 | 0.128 | 0.198 |

| missed-day run (days) | runs (pooled) | % of runs | missed days | % of missed days |
|---|---|---|---|---|
| 1 | 71435 | 41.8 | 71435 | 3.53 |
| 2-3 | 44150 | 25.8 | 103883 | 5.14 |
| 4-7 | 24790 | 14.5 | 126297 | 6.25 |
| 8-30 | 19595 | 11.5 | 288698 | 14.3 |
| >30 | 11059 | 6.47 | 1431452 | 70.8 |

### 2. Daily minutes on study days (log_sd and autocorrelations on ln minutes, consecutive study days; autocorrelation needs >= 20 study days)
| statistic (per user) | N users | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|
| min_med | 2000 | 20.8 | 6.79 | 11.7 | 34.8 | 54.5 |
| min_p10 | 2000 | 2.51 | 0.632 | 1.20 | 5.17 | 10.7 |
| min_p90 | 2000 | 65.3 | 22.6 | 37.9 | 108 | 160 |
| log_sd | 2000 | 1.34 | 0.885 | 1.10 | 1.58 | 1.83 |
| ac_lag1 | 1997 | 0.370 | 0.141 | 0.249 | 0.507 | 0.664 |
| ac_lag7 | 1997 | 0.185 | -0.023 | 0.067 | 0.337 | 0.502 |

| users whose median daily minutes are | share of users |
|---|---|
| > 30 | 31.9% |
| > 45 | 14.9% |
| > 60 | 7.65% |
| < 5 | 5.80% |
| < 2 | 1.35% |

| pooled over all study days | study days | share > 30 min | share > 60 min |
|---|---|---|---|
| all users | 830510 | 36.7% | 18.2% |

### 3. Card prices: seconds per card-day (all reviews of the card that day), new = first review ever that day; ratio = new/other
| statistic (per user) | N users | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|
| new_med | 2000 | 18.2 | 7.87 | 11.8 | 29.5 | 46.7 |
| other_med | 2000 | 9.24 | 4.11 | 6.01 | 14.6 | 22.9 |
| ratio_med | 2000 | 1.92 | 1.18 | 1.48 | 2.46 | 3.08 |
| new_mean | 2000 | 29.9 | 14.3 | 21.0 | 43.3 | 59.4 |
| other_mean | 2000 | 16.8 | 7.96 | 11.3 | 25.0 | 33.3 |
| ratio_mean | 2000 | 1.78 | 1.20 | 1.44 | 2.16 | 2.63 |

### 4. Load of new cards (mean reviews per introduced card; windows beyond the end of the user's log excluded)
| statistic (per user) | N users | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|
| reviews/new card, day 0 (incl. the first review) | 2000 | 2.07 | 1.38 | 1.73 | 2.50 | 3.01 |
| reviews/new card, days 1-7 | 2000 | 1.55 | 0.570 | 0.949 | 2.12 | 2.75 |
| reviews/new card, days 8-30 | 1999 | 1.18 | 0.281 | 0.634 | 1.81 | 2.52 |
| reviews/new card, days 31-90 | 1982 | 0.783 | 0.071 | 0.273 | 1.50 | 2.48 |

### 5. First 14 calendar days of fresh starts (first review state 0, no state-2 review on day one, log >= 14 days): 1969 users qualify
| statistic (per user) | N users | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|
| first14 min/study day | 1969 | 10.2 | 0.714 | 2.98 | 23.0 | 43.0 |
| first14 new cards/study day | 1969 | 15 | 2 | 6.20 | 28.2 | 55 |
| first14 study days of 14 | 1969 | 6 | 1 | 2 | 11 | 13 |
| first14 median min, calendar days 1-7 | 1969 | 7.15 | 0.535 | 1.97 | 18.0 | 36.2 |
| first14 median min, calendar days 8-14 | 1319 | 14.1 | 1.68 | 5.04 | 29.3 | 52.6 |

| pooled study days of fresh starts | study days | median min | p25 | p75 | p90 |
|---|---|---|---|---|---|
| calendar days 1-7 | 7263 | 10.1 | 2.87 | 24.9 | 50.8 |
| calendar days 8-14 | 5449 | 16.2 | 5.86 | 34.8 | 68.1 |

### 6. Return after a gap of 4-30 missed days (needs 14 study days before the gap; "back" = >= 5 study days in the next 7, excludes returns within 7 days of the log end)
| gap (days) | returns | p10 | p25 | median | p75 | p90 | share back (>=5 of 7) | n uncensored |
|---|---|---|---|---|---|---|---|---|
| all 4-30 | 41325 | 0.066 | 0.281 | 0.872 | 1.88 | 3.57 | 0.207 | 40677 |
| 4-7 | 23288 | 0.084 | 0.337 | 0.942 | 1.91 | 3.50 | 0.228 | 22993 |
| 8-14 | 10783 | 0.057 | 0.245 | 0.818 | 1.88 | 3.70 | 0.180 | 10589 |
| 15-30 | 7254 | 0.041 | 0.190 | 0.696 | 1.75 | 3.67 | 0.181 | 7095 |

### Return ratio = minutes on the first day back / median daily minutes of the 14 study days before the gap
| statistic (per user) | N users | median | p10 | p25 | p75 | p90 |
|---|---|---|---|---|---|---|
| return ratio, user median (>=3 returns) | 1824 | 0.820 | 0.296 | 0.525 | 1.15 | 1.62 |

### 7. Big days: minutes / median of the previous 14 study days (>= 14 prior study days; last study day excluded, successor unknown)
| bin | user-days (pooled) | P(next day studied), pooled | P(gap >= 7 starts), pooled | users (>= 5 days in bin) | P(next day), user median | P(gap >= 7), user median |
|---|---|---|---|---|---|---|
| <0.5 | 160681 | 0.663 | 0.085 | 1973 | 0.613 | 0.095 |
| 0.5-1 | 241316 | 0.835 | 0.026 | 1971 | 0.762 | 0.034 |
| 1-1.5 | 192041 | 0.860 | 0.020 | 1944 | 0.799 | 0.023 |
| 1.5-2 | 81139 | 0.827 | 0.027 | 1886 | 0.805 | 0.018 |
| >2 | 125334 | 0.791 | 0.039 | 1947 | 0.792 | 0.032 |

