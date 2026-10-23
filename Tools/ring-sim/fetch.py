#!/usr/bin/python3
"""Downloads revlogs/user_id=1..N of the gated open-spaced-repetition/anki-revlogs-10k into a folder for
sim.py --real. Needs a read token of an account that accepted the dataset's conditions in
~/.cache/huggingface/token. Files already there are skipped, so a cut run resumes.
Usage: fetch.py [N=300] [folder=~/Library/Caches/anki-revlogs-10k]"""
import os, sys, urllib.request

n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
dest = os.path.expanduser(sys.argv[2] if len(sys.argv) > 2 else '~/Library/Caches/anki-revlogs-10k')
tok = open(os.path.expanduser('~/.cache/huggingface/token')).read().strip()
base = 'https://huggingface.co/datasets/open-spaced-repetition/anki-revlogs-10k/resolve/main/revlogs/user_id=%d/data.parquet'
for u in range(1, n + 1):
    d = os.path.join(dest, 'user_id=%d' % u)
    f = os.path.join(d, 'data.parquet')
    if os.path.exists(f):
        continue
    os.makedirs(d, exist_ok=True)
    req = urllib.request.Request(base % u, headers={'Authorization': 'Bearer ' + tok})
    with urllib.request.urlopen(req, timeout=60) as r, open(f + '.part', 'wb') as o:
        o.write(r.read())
    os.rename(f + '.part', f)
print('users', len(os.listdir(dest)), 'in', dest)
