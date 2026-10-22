"""Builds the Anki packages in Packages/VocabCore/Tests/VocabCoreTests/Resources/Anki.

Run:  uv run --with anki --python 3.12 python make_anki_fixtures.py <out dir>

The collection is made with Anki's own library (26.09.3), so the layouts, schemas and
protobuf columns are the real ones:
  greek-latest.apkg   Latest: meta (version 3), collection.anki21b (zstd), dummy collection.anki2
  greek-legacy2.apkg  Legacy 2: meta (version 2), collection.anki21, dummy collection.anki2
  greek-legacy1.apkg  Legacy 1: the schema-11 collection of Legacy 2 as collection.anki2, no meta
  greek-latest-cli.apkg  Latest again, with the collection recompressed by the `zstd` command line tool
                      from a pipe, so its frame has no content size in the header (needs `zstd` in PATH)
The deck of the four packages above uses the preset "Greek FSRS": 21 FSRS-6 parameters
(`fsrsParams6`) and a desired retention of 0.85.
  presets-latest.apkg, presets-legacy2.apkg
                      Two decks with a preset each, as an older Anki leaves them: "Mix::A" (two cards)
                      with 19 FSRS-5 parameters (`fsrsParams5`) and a retention of 0.95, "Mix::B" (one
                      card) with 17 FSRS-4.5 parameters (`fsrsWeights`) and 0.8. A card in no deck of
                      its own preset has none: "Mix::C" uses the stock "Default" preset.
  media-fields-latest.apkg, media-fields-legacy2.apkg
                      The shape of a shared deck that imported with no card: the note type "Front, Image,
                      Audio, Back, ExamplesBlock, FrequencyBlock", whose question template shows Front and
                      Image (with a stray brace, "{{{Image}}") and whose answer template adds Back and the
                      blocks; a note type that asks with its audio only; a note with no word and one with no translation.
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

# FSRS-6 parameters in the ranges of the optimizer, not the defaults.
GREEK_PARAMETERS = [
    0.3178, 1.4204, 3.1073, 9.3125, 6.0231, 0.9166, 3.2872, 0.0010, 1.7841, 0.1502, 0.8873,
    1.5340, 0.0580, 0.2487, 1.5792, 0.5538, 1.8995, 0.6270, 0.1024, 0.0701, 0.1730,
]


def make_preset(name, retention, **parameters):
    """A new deck preset with the FSRS keys of the legacy JSON: fsrsWeights (17 values of
    FSRS-4.5), fsrsParams5 (19 of FSRS-5), fsrsParams6 (21 of FSRS-6)."""
    config = col.decks.add_config(name)
    config["desiredRetention"] = retention
    config.update(parameters)
    col.decks.update_config(config)
    return config["id"]


def use_preset(deck_id, config_id):
    deck_dict = col.decks.get(deck_id)
    deck_dict["conf"] = config_id
    col.decks.save(deck_dict)


use_preset(deck, make_preset("Greek FSRS", 0.85, fsrsParams6=GREEK_PARAMETERS))


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

# Presets of the older FSRS versions, in a collection of their own.
col = Collection(os.path.join(work, "presets.anki2"))
mix = col.decks.id("Mix")
basic = col.models.by_name("Basic")
use_preset(col.decks.id("Mix::A"), make_preset(
    "Five", 0.95, fsrsParams5=[
        0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046, 1.54575, 0.1192,
        1.01925, 1.9395, 0.11, 0.29605, 2.2698, 0.2315, 2.9898, 0.51655, 0.6621]))
use_preset(col.decks.id("Mix::B"), make_preset(
    "Four", 0.8, fsrsWeights=[
        0.4872, 1.4003, 3.7145, 13.8206, 5.1618, 1.2298, 0.8975, 0.031, 1.6474, 0.1367,
        1.0461, 2.1072, 0.0793, 0.3246, 1.587, 0.2272, 2.8755]))
for deck_name, words in [("Mix::A", [("ένα", "one"), ("δύο", "two")]), ("Mix::B", [("τρία", "three")]), ("Mix::C", [("τέσσερα", "four")])]:
    for front, back in words:
        note = col.new_note(basic)
        note.fields[0], note.fields[1] = front, back
        col.add_note(note, col.decks.id(deck_name))
col.export_anki_package(out_path=os.path.join(out_dir, "presets-latest.apkg"), options=options(False), limit=DeckIdLimit(mix))
col.export_anki_package(out_path=os.path.join(out_dir, "presets-legacy2.apkg"), options=options(True), limit=DeckIdLimit(mix))
col.close()

# A shared deck whose first two fields are not the front and the back: the image sits in the second.
col = Collection(os.path.join(work, "media-fields.anki2"))
media_deck = col.decks.id("Media")
col.media.write_data("15.jpg", b"\xff\xd8\xff\xd9")
col.media.write_data("15.mp3", b"ID3")


def make_note_type(name, fields, question, answer):
    notetype = col.models.new(name)
    for field in fields:
        col.models.add_field(notetype, col.models.new_field(field))
    template = col.models.new_template("Card 1")
    template["qfmt"], template["afmt"] = question, answer
    col.models.add_template(notetype, template)
    col.models.add_dict(notetype)
    return col.models.by_name(name)


vocabulary = make_note_type(
    "Front, Image, Audio, Back, ExamplesBlock, FrequencyBlock",
    ["Front", "Image", "Audio", "Back", "ExamplesBlock", "FrequencyBlock"],
    '<div class="word">{{Front}}</div>\n{{{Image}}',
    '{{FrontSide}}\n\n<hr class="divider">\n\n<div class="translation">{{Back}}</div>\n{{{ExamplesBlock}}\n{{{FrequencyBlock}}')
listening = make_note_type("Audio, Text", ["Audio", "Text"], "{{Audio}}", '{{FrontSide}}<hr id="answer">{{Text}}')
image = '<div class="image-wrapper"><img class="card-image" src="15.jpg"></div>'
for model, fields in [
    (vocabulary, ["παίρνω", image, "[sound:15.mp3]", "get", '<div class="examples"><div>Παίρνω τον καφέ μου στις οκτώ.</div>[sound:15.mp3]<div>I get my coffee at eight.</div></div>', ""]),
    (vocabulary, ["χρόνος", image, "[sound:15.mp3]", "time", "", "<b>1</b>"]),
    (vocabulary, ["", image, "[sound:15.mp3]", "no word", "", ""]),
    (vocabulary, ["κανένα", image, "[sound:15.mp3]", "", "", ""]),
    (listening, ["[sound:15.mp3]", "ακούω"]),
]:
    note = col.new_note(model)
    for index, value in enumerate(fields):
        note.fields[index] = value
    col.add_note(note, media_deck)
col.export_anki_package(out_path=os.path.join(out_dir, "media-fields-latest.apkg"), options=options(False), limit=DeckIdLimit(media_deck))
col.export_anki_package(out_path=os.path.join(out_dir, "media-fields-legacy2.apkg"), options=options(True), limit=DeckIdLimit(media_deck))
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
