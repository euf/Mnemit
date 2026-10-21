# MacVocTrain NG

## Mnemit — форк euf, читать первым

- Mnemit (mnem- от «память», + it: «запомни это») — форк `Fluch-IT-Consulting/MacVocTrainNg` под одну задачу EF: учить
  греческий A2–B1 на Mac и iPhone. `origin` — `euf/Mnemit`, `upstream` — апстрим. Состояние,
  подпись iPhone, колода — `HANDOFF.md`.
- Имя Mnemit — всё, что видит человек и система: `Mnemit.app` на Mac и iPhone, bundle id
  `com.euf.mnemit` (`.ios`, `.tests`), репозиторий, каталог, папка в iCloud Drive, About.
  Внутренние имена апстрима оставлены сознательно, чтобы слияния с апстримом не превращались
  в ручную работу: проект `MacVocTrainNg.xcodeproj`, схемы и таргеты `MacVocTrainNg` и
  `VocTrain`, каталоги исходников, модули `MacVocTrain`/`VocTrain` (`PRODUCT_MODULE_NAME`),
  формат колоды `.voctrain` и его UTType.
- Раздел Workflow ниже — правила апстрима (issue, ветка, PR, немецкие заголовки). В форке
  они не действуют: коммит в `main` и пуш без вопроса. Правка, полезная апстриму, —
  отдельной веткой и PR туда по их правилам.
- Апстрим: `git fetch upstream && git merge upstream/main`. Конфликты ждать в
  `project.pbxproj` (имена продуктов и bundle id) и в строках с именем приложения.
- Mac: `Scripts/install-mac.sh` → `~/Applications/Mnemit.app`, подпись `euf-sign` с
  entitlements сборки.
- iPhone: `Scripts/install-iphone.sh` — Release без подписи, переподпись сертификатом iApps,
  `devicectl` на iPhone 13 mini. Bundle id берётся из профиля. Телефон должен быть
  разблокирован.
- Синхронизация колоды с TSV на месте, без потери прогресса:
  `swift run -c release --package-path Tools/deck-from-tsv deck-from-tsv <tsv> <deck.voctrain> [--dry-run] [--suspend-missing] [--backup-dir DIR] [--new-per-session N|none] [--new-production-per-session N|none] [--unlock-days N] [--new-order deck|newest]`.
  TSV с шапкой `note⇥kind⇥question⇥answer⇥hint` (kind — `recognition` или `production`,
  `\n` в полях — перенос строки). Карточка находится по (note, kind); старая карточка без
  note усыновляется (id и повторения остаются), если её ответ равен первой строке ответа
  строки или, для production, этой строке без окончаний и артикля; иначе создаётся новая с
  id UUID v5 от `note|kind`. Текст правится на месте, удалений нет, `--suspend-missing`
  замораживает карточки с note, которого в TSV нет. Перед записью копия колоды уходит в
  `<каталог колоды>/.backups` (10 свежих). TSV без шапки (вопрос, ответ, подсказка) работает
  как раньше: добавляются только новые вопросы. Модель и правила выбора карточек
  (разблокировка production, прятание сиблингов) — в VocabCore: `Card.note`/`kind`,
  `LearningOptions.productionUnlockDays` и соседние, `StudySession.selectCards`.
- Числа «сегодня» (New · Learning · Review, размер плана, ближайшая дата) — только
  `StudySession.counts(for:at:calendar:)`: тот же отбор, что у плана дня, поэтому цифры на
  экране колоды, в тулбаре и в статусной строке совпадают с тем, что поток возьмёт.
  Лимиты `newCardsPerSession` и `newProductionPerSession` считаются на учебный день
  (смена в 4 утра), имена остались ради `deck.json`: карточка, чья первая оценка пришлась
  на текущий день, вычитается из лимита, поэтому повторный вход в поток новых сверх
  лимита не берёт, а следующий день возвращает полный счёт. Флаги `deck-from-tsv`
  `--new-per-session` и `--new-production-per-session` тоже называются по-старому и
  задают дневной лимит. `Deck.dueCount` считает каждую нетронутую карточку, им кнопку
  «Study» и строки со счётом не кормить.
- Повторения `.revealed` (карточки: весь iPhone и Mac в режиме Flashcards) в форке главный
  сигнал, как в Anki: `LearningOptions.revealedRecallWeight` (1/3…1, по умолчанию 1)
  заменил жёсткую треть из ADR 0004, `optimizeFromRevealed` (по умолчанию `true`) пускает
  такие повторения в оптимизатор целями. Откат к ADR 0004: вес 0.33 и выключатель в
  Learning Options (ADR 0005).
- Leech: `LearningOptions.leechThreshold` (8 провалов, 0 — выкл). Провал, доводящий
  `lapses` до порога и до каждого следующего кратного, `StudySession.review` сразу
  превращает в suspend (оба приложения, одним `DeckChange` с отменой), карточка уходит
  из сессии, `GradeReceipt` говорит «leech, suspended». Флага в файле нет: `Card.isLeech(
  threshold:)` выводится из `lapses`, поэтому фильтр «Leeches» на Mac показывает и
  возобновлённые карточки, а слияния нового правила не требуют.
- Study открывает поток без конца, сессий нет (`StudyStream` в VocabCore, на обоих
  приложениях его ведёт `SessionDriver`): каждая оценка пишется сразу, выход ничего не
  теряет. Порядок: план дня (`StudySession.counts`, тот же отбор и лимиты; пока план
  непуст, он пересчитывается после каждого сегмента) → пауза «Done for today» (размер
  плана, доля вспомненных, ближайшая дата; кнопки «Keep Going» и «+10 new») → review ahead
  (не наступившие Review по возрастанию текущей вероятности вспомнить, обычные
  повторения; сиблинги и карточки, оценённые сегодня, пропускаются) → практика без
  влияния на расписание (`Deck.mistakes(onDayOf:calendar:)`, затем `Deck.newestBatchIDs`,
  по кругу). Новые сверх дневного лимита — только `addNewCards(10)` с оценкой «≈ +N
  повторений в день на следующей неделе» (`NewCardLoad`: симуляция FSRS, все Good, без
  лапсов). Undo идёт через весь поток: снимок `UndoCompanion` — это значение
  `StudyStream` целиком. «Practice Mistakes» и «Practice Newest Words» — входы отдельных
  потоков (`practicingMistakesIn:`, `practicingNewestWordsIn:`), они кончаются паузой с
  итогами.
- Кольцо и streak (`DailyProgress` в VocabCore, `DailyRingModel` и `DailyRingView` в
  `Shared/Session`) — только из review-логов, ничего не хранится. Цель дня — 20
  повторений или весь план, если он меньше (`DailyGoal.goal(reviews:owed:)`); считаются
  все оценки, включая review ahead, практика в лог не пишется и не считается. После цели
  кольцо идёт кругами (×2 с 200 %). Streak — подряд дни с выполненной целью, один
  пропущенный день закрывают 40 повторений на следующий. Прошлый день судится по
  `StudySession.counts` на конец того дня, то есть по плану, который он ещё был должен:
  день, наверстанный позже, засчитывается. iPhone считает по всем колодам из
  `KnownDecks` (файлы читает `DeckFileReader`), Mac — по открытым документам
  (`OpenDecks`).
- Последняя партия слов: `Deck.newestBatchIDs` — карточки с тем же `created` (до секунды),
  что и самая свежая в колоде, без suspended; `deck-from-tsv` ставит один `created` на
  прогон. Практика партии расписание не трогает: Mac — Study ▸ Practice Newest Words
  (`SessionViewModel(entry: .practiceNewest)`), iPhone — кнопка на экране колоды
  (`StudyModel(entry: .practiceNewest)`). Карточка, добавленная руками позже, начинает свою
  партию.
- Версия — `VERSION`, патч бампает pre-commit-хук; после клона
  `ln -sf ~/dotfiles/claude/version-hook .git/hooks/pre-commit`.

## Upstream

macOS vocabulary trainer (SwiftUI, Swift 6, macOS 14+) with an iPhone app to study on
the go (iOS 17+). The user writes German; code, comments and base UI strings are
English, German comes from the String Catalog.

## Commands

The active developer dir may be the Command Line Tools; prefix with
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` if needed.

- Core tests: `cd Packages/VocabCore && swift test`
- App build + all tests: `xcodebuild -project MacVocTrainNg.xcodeproj -scheme MacVocTrainNg test`
- iPhone app build + tests: `xcodebuild -project MacVocTrainNg.xcodeproj -scheme VocTrain -destination 'platform=iOS Simulator,name=iPhone 17' test`
- Lint: `xcrun swift-format lint --strict -r MacVocTrainNg MacVocTrainNgTests VocTrain VocTrainTests Shared Packages/VocabCore/Sources Packages/VocabCore/Tests Packages/VocabCore/Package.swift Tools`
  (config in `.swift-format`); `format -i` instead of `lint --strict` fixes the layout.
  Name the paths: `build/` and `.build/` contain generated Swift files.
- Translations: `swift Tools/check-localizations.swift` after the builds of both apps
  with `-derivedDataPath build/DerivedData`.
- CI: `.github/workflows/ci.yml`; its header comment lists what the job `test` checks.
- Signing: `Config/Signing.xcconfig` signs ad hoc, `Config/Signing-iOS.xcconfig` signs
  the iPhone app automatically; the untracked `Config/Signing.local.xcconfig` sets the
  team for both. No team ID in tracked files.

## Architecture

- `Packages/VocabCore`: all domain logic, no UI imports. Value types, `Sendable`.
  `Scheduler` applies a `Grade` to a `Card` (FSRS-6 in `FSRS.swift`, ported from py-fsrs);
  `SessionMode` runs a `StudySession` or a `Practice` and records reviews, each over
  a shared `Session` that only tracks card IDs and order.
- `Shared/Document/VocabularyDocument.swift`: the document, a `ReferenceFileDocument`
  on the Mac only, which also alone has the methods that edit cards and options
  (`MacVocTrainNg/Document/VocabularyDocument+*.swift`, #297). Every change
  must go through its `@MainActor` methods: they register undo, which is also how SwiftUI
  marks the document dirty. They register with the document's own `undoManager`, attached
  with `attachUndoManager(_:)`: on the Mac by the document's view from its environment
  (`attachingUndoManager(to:)`), on the iPhone by `OpenDeck` before it shows the document,
  in tests by the test; callers don't pass one. Until then the document is only read:
  whatever changes it checks `isReadyToEdit` first (#305). Don't mutate `deck` elsewhere. Underneath, cards and learning
  options change only through `Deck.apply(_:at:calendar:)`: it returns the inverse change
  and keeps `progress` and `contentModified` in step. `VocabCore` builds each `DeckChange`; a card's learning state and
  log can't be set from outside it (tests reach the full `Card.init` via `@testable`).
  Outside it there is only the empty `Deck()`; the full `Deck.init`, also via
  `@testable`, throws on duplicate card IDs and clamps the learning options.
- Reviews are undoable: the document applies the change `SessionMode.grade` returns and
  runs the restore of the `Session`, an opaque `UndoCompanion`, in the same undo action,
  after the card. The document knows no sessions.
- NSDocument, or UIDocument on the iPhone, reads a deck again on its own when another
  device changes the file; the window or scene then gets a new document.
  `VersionMerger` (in `Shared/`, used by both apps) outlives it and merges what the
  file lacks and the versions iCloud Drive keeps in conflict, through
  `VocabularyDocument.merge(_:)`. File presenter callbacks must not ask the document
  synchronously: during another process's write, both would wait for each other. The
  iPhone app lets go of the file in the background.
- The Xcode project uses synchronized folders: new files in `MacVocTrainNg/` or
  `MacVocTrainNgTests/` are picked up automatically, likewise in `VocTrain/` (the
  iPhone app, which only studies and never edits cards) and `VocTrainTests/`.
  `Shared/`, compiled into both apps, holds what the Mac app shares with the iPhone
  app (#254): the document and what it needs, and the one String Catalog. Code moves
  there only when the iPhone app uses it and it needs no AppKit; `VocabCore` stays the
  place for domain logic.

## Conventions

- New user-facing strings: add the German translation to
  `Shared/Resources/Localizable.xcstrings`, which both apps share (Xcode may not run to
  sync it), in state `translated`; a string whose wording depends on a count needs
  plural forms in both `en` and `de`. The CI fails on a key missing from the catalog or without German.
- Code ported from another project: add its license to `THIRD_PARTY_NOTICES.md` and
  `MacVocTrainNg/Resources/Credits.html` (the About window).
- Chart/status colours live in `Shared/Support/Presentation.swift`; the maturity ramp is a
  validated one-hue ordinal ramp, keep it that way.
- A deck is a package (`deck.json` + `reviews.jsonl`, see `DeckFile`); its keys are the
  glossary terms. Only the private records in `DeckFile` know its keys; domain types
  are not `Codable`. Versions 1 and 2 predate the first release and are no longer read.
  Missing keys decode with defaults, so newer app versions read older decks. Older app
  versions read newer decks of the same version too, but drop unknown keys and files
  on save. So a new field (in `deck.json` or `reviews.jsonl`) or file in the package
  comes without a bump of `DeckFile.currentVersion` only if losing it that way is
  acceptable; otherwise, and for incompatible changes, bump it: older app versions
  then reject the deck. The review log is encoded incrementally by `ReviewLogEncoder`:
  logs may only grow at the end or be replaced as a whole.

## Workflow

Every change goes through a GitHub issue, its own branch and a pull request; never
commit to `main` directly. Branch `bugfix/<n>`, `feature/<n>` or `task/<n>` after the
issue type; commit titles `typ(#n): Satz` (German), ending with `Teil von #n`; the PR
body closes the issue (`Closes #n`). Merge by rebase. Assign the issue before starting
and don't take over issues assigned to someone else.

Exception: a small change to code comments alone skips the issue. It still gets a branch
`task/<slug>` and a pull request; commit title `docs: Satz`, without `Teil von` or `Closes`.

### Issue tracker

GitHub issues in `Fluch-IT-Consulting/MacVocTrainNg`, via the `gh` CLI.
See `docs/agents/issue-tracker.md`.

### Unattended agents

`Tools/agent-loop.sh` works through the `ready-for-agent` issues, one pull request each.
See `docs/agents/afk-loop.md`; the agent's prompt is `docs/agents/afk-prompt.md`.

### Triage labels

The five standard roles, label equals role name. See `docs/agents/triage-labels.md`.

### Domain docs

Single context: `GLOSSARY.md` and `docs/adr/` at the root, created when needed.
See `docs/agents/domain.md`.

### Wiki

The GitHub wiki (German, a repository of its own: `MacVocTrainNg.wiki.git`) explains how
to use the apps and how the algorithms work; its pages name the code they describe in
a `Code:` line. A pull request that changes what a page describes names the page and
the change in its body under `Wiki:`. After the merge, the page is brought up to date;
pushing to the wiki needs the owner's go-ahead.
