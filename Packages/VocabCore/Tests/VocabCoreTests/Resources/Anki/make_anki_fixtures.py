"""Builds the Anki packages in Packages/VocabCore/Tests/VocabCoreTests/Resources/Anki.

Run:  uv run --with anki --python 3.12 python make_anki_fixtures.py <out dir>

The collection is made with Anki's own library (26.09.3), so the layouts, schemas and
protobuf columns are the real ones:
  greek-latest.apkg   Latest: meta (version 3), collection.anki21b (zstd), dummy collection.anki2
  greek-legacy2.apkg  Legacy 2: meta (version 2), collection.anki21, dummy collection.anki2
  greek-legacy1.apkg  Legacy 1: the schema-11 collection of Legacy 2 as collection.anki2, no meta
  greek-latest-cli.apkg  Latest again, with the collection recompressed by the `zstd` command line tool
                      from a pipe, so its frame has no content size in the header (needs `zstd` in PATH)
"""

import json
import os
import shutil
import subprocess
import sqlite3
import sys
import tempfile
import zipfile

from anki.collection import Collection, DeckIdLimit, ExportAnkiPackageOptions

out_dir = os.path.abspath(sys.argv[1])
os.makedirs(out_dir, exist_ok=True)
work = tempfile.mkdtemp()

col = Collection(os.path.join(work, "collection.anki2"))
parent = col.decks.id("Greek")
deck = col.decks.id("Greek::Lesson 1")
basic = col.models.by_name("Basic")
reversed_ = col.models.by_name("Basic (and reversed card)")
cloze = col.models.by_name("Cloze")

col.media.write_data("paste-1.jpg", b"\xff\xd8\xff\xd9")


def add(model, fields):
    note = col.new_note(model)
    for index, value in enumerate(fields):
        note.fields[index] = value
    col.add_note(note, deck)
    return note


cat = add(basic, ["γάτα", "cat"])
house = add(basic, ["<b>σπίτι</b><br>το", "house &amp; home&nbsp;"])
picture = add(basic, ["εικόνα", '<img src="paste-1.jpg">'])
sound = add(basic, ["ήχος", "sound [sound:x.mp3]"])
water = add(reversed_, ["νερό", "water"])
capital = add(cloze, ["{{c1::Αθήνα}} is the capital of {{c2::Greece}}", ""])
dog = add(basic, ["σκύλος", "dog"])
col.sched.suspend_cards([dog.cards()[0].id])

BASE = 1_768_000_000_000  # ms
MINUTE, DAY = 60_000, 86_400_000


def log(card, offset, ease, type_, factor=2500):
    col.db.execute(
        "insert into revlog values (?, ?, -1, ?, 1, 0, ?, 3000, ?)",
        BASE + offset, card.id, ease, factor, type_)


c = cat.cards()[0]
log(c, 0, 3, 0)
log(c, 10 * MINUTE, 3, 0)
log(c, DAY, 3, 1)
log(c, 5 * DAY, 1, 1)
log(c, 5 * DAY + 5 * MINUTE, 3, 2)
log(c, 6 * DAY, 0, 4, factor=0)  # manual reschedule: skipped
log(c, 6 * DAY + 1000, 0, 5, factor=0)  # rescheduled: skipped
log(house.cards()[0], 123, 4, 0)
forward, backward = sorted(water.cards(), key=lambda card: card.ord)
log(forward, 1000, 3, 0)
log(backward, 2000, 2, 0)
log(capital.cards()[0], 3000, 3, 0)

options = lambda legacy: ExportAnkiPackageOptions(
    with_scheduling=True, with_deck_configs=True, with_media=True, legacy=legacy)
col.export_anki_package(out_path=os.path.join(out_dir, "greek-latest.apkg"), options=options(False), limit=DeckIdLimit(parent))
col.export_anki_package(out_path=os.path.join(out_dir, "greek-legacy2.apkg"), options=options(True), limit=DeckIdLimit(parent))
col.close()

# Legacy 1: the schema-11 collection of Legacy 2 under the old name, without meta.
with zipfile.ZipFile(os.path.join(out_dir, "greek-legacy2.apkg")) as source:
    with zipfile.ZipFile(os.path.join(out_dir, "greek-legacy1.apkg"), "w", zipfile.ZIP_DEFLATED) as target:
        target.writestr("collection.anki2", source.read("collection.anki21"))
        target.writestr("media", source.read("media"))
        for name in source.namelist():
            if name.isdigit():
                target.writestr(name, source.read(name))

# Latest with a frame of the zstd tool: piped, so the frame header holds no content size.
with zipfile.ZipFile(os.path.join(out_dir, "greek-latest.apkg")) as source:
    plain = subprocess.run(["zstd", "-q", "-d", "-c"], input=source.read("collection.anki21b"), capture_output=True, check=True).stdout
    again = subprocess.run(["zstd", "-q", "-19", "-c"], input=plain, capture_output=True, check=True).stdout
    with zipfile.ZipFile(os.path.join(out_dir, "greek-latest-cli.apkg"), "w", zipfile.ZIP_DEFLATED) as target:
        for name in source.namelist():
            target.writestr(name, again if name == "collection.anki21b" else source.read(name))

shutil.rmtree(work)
for name in sorted(os.listdir(out_dir)):
    print(name, os.path.getsize(os.path.join(out_dir, name)))
