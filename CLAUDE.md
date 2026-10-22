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
  ключ `format` внутри `deck.json` (`de.fluch-it-consulting.voctrain.deck`).
- Колода — пакет `X.mnemit` (`deck.json` + `reviews.jsonl`). Тип `com.euf.mnemit.deck`
  экспортируется из обоих `Info.plist` и объявлен в `Shared/Document/ContentTypes.swift`
  (`UTType.vocabularyDeck`). Расширение и проверку имени держит VocabCore:
  `DeckFile.fileExtension`, `DeckFile.isDeckName`; остальной код расширения не пишет.
  Файлы `.voctrain` (импортируемый тип `de.fluch-it-consulting.voctrain.deck`,
  `UTType.legacyVocabularyDeck`) читаются так же: открываются, стоят в списках папки рядом
  с `.mnemit`, правятся и сохраняются на месте под своим именем; приложение их не
  переименовывает. `UTType.deckTypes` — оба типа, новый первым: это
  `readableContentTypes` и `writableContentTypes` документа на Mac (первый тип получают
  новые колоды) и фильтр пикера на iPhone. Внутри `deck.json` у обоих расширений один ключ
  `format`, содержимое одно.
- Раздел Workflow ниже — правила апстрима (issue, ветка, PR, немецкие заголовки). В форке
  они не действуют: коммит в `main` и пуш без вопроса. Правка, полезная апстриму, —
  отдельной веткой и PR туда по их правилам.
- Апстрим: `git fetch upstream && git merge upstream/main`. Конфликты ждать в
  `project.pbxproj` (имена продуктов и bundle id) и в строках с именем приложения.
- Mac: `Scripts/install-mac.sh` → `~/Applications/Mnemit.app`, подпись `euf-sign` с
  entitlements сборки.
- iPhone: `~/dotfiles/ios-renew --force` — Personal Team, приложение и виджет; подробности в HANDOFF.md.
- Синхронизация колоды с TSV на месте, без потери прогресса:
  `swift run -c release --package-path Tools/deck-from-tsv deck-from-tsv <tsv> <deck.mnemit | deck.voctrain> [--dry-run] [--suspend-missing] [--backup-dir DIR] [--new-per-session N|none] [--new-production-per-session N|none] [--unlock-days N] [--new-order deck|newest]`.
  TSV с шапкой `note⇥kind⇥question⇥answer⇥hint` (kind — `recognition` или `production`,
  `\n` в полях — перенос строки). Карточка находится по (note, kind); старая карточка без
  note усыновляется (id и повторения остаются), если её ответ равен первой строке ответа
  строки или, для production, этой строке без окончаний и артикля; иначе создаётся новая с
  id UUID v5 от `note|kind`. Текст правится на месте, удалений нет, `--suspend-missing`
  замораживает карточки с note, которого в TSV нет. Перед записью копия колоды уходит в
  `<каталог колоды>/.backups` (10 свежих; копия получает `.mnemit`, при чистке считаются
  копии обоих расширений). Колода с `.voctrain` пишется на месте под своим именем. TSV без
  шапки (вопрос, ответ, подсказка) работает как раньше: добавляются только новые вопросы. Модель и правила выбора карточек
  (разблокировка production, прятание сиблингов) — в VocabCore: `Card.note`/`kind`,
  `LearningOptions.productionUnlockDays` и соседние, `StudySession.selectCards`.
- Правка колоды на iPhone и Mac — одни и те же методы `VocabularyDocument+Editing` в `Shared`
  (undo и имена действий общие; на iPhone документ сохраняет `OpenDeck` через UIDocument и
  `SaveScheduler`). Слияние версий при правках на обоих устройствах: карточки объединяются,
  текст/note/kind берёт версия с более поздним `Card.contentChanged` (undo штампует заново),
  опции — с более поздним `Deck.learningOptionsChanged`, удаление помнит `Deck.deletedCards` и
  выигрывает, только если оно позже всего, что сделали с карточкой (правка, сброс, пауза,
  повторение); при равенстве карточка остаётся. Ключи `contentChanged`, `learningOptionsChanged`,
  `deletedCards` в `deck.json` без смены версии формата. Файловые операции колоды на iPhone
  (создать `<имя>.mnemit`, переименовать, в корзину) — `DeckFiles` в `Shared/Document`: через
  `NSFileCoordinator`, `async`, не на главном потоке; корзина без поддержки места (папка
  приложения на iPhone) переносит колоду в соседнюю папку `Deleted Decks`, насовсем не удаляет.
- Числа «сегодня» (New · Learning · Review, размер плана, ближайшая дата) — только
  `StudySession.counts(for:at:calendar:)`: тот же отбор, что у плана дня, поэтому цифры на
  экране колоды, в тулбаре и в статусной строке совпадают с тем, что поток возьмёт: с планом целиком, `cardsPerSession` в счёт не идёт.
  Лимиты `newCardsPerSession` и `newProductionPerSession` считаются на учебный день
  (смена в 4 утра), имена остались ради `deck.json`: карточка, чья первая оценка пришлась
  на текущий день, вычитается из лимита, поэтому повторный вход в поток новых сверх
  лимита не берёт, а следующий день возвращает полный счёт. Строка колоды на Today читает колоду
  целиком, с `reviews.jsonl` (`KnownDeckCounts` через `DeckFileReader`), как документ на экране
  колоды: карточки, начатые сегодня, знает только лог, и счёт по одному `deck.json`
  (`DeckFile.decode(_ data:)`) показывал полный лимит. Флаги `deck-from-tsv`
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
  threshold:)` выводится из `lapses`, поэтому фильтр Difficult показывает и возобновлённые
  карточки, а слияния нового правила не требуют.
- Автоподгонка параметров FSRS (`ParameterRefit` в VocabCore, `ParameterRefitter` в
  `Shared/Document`). Срок: первая подгонка, когда в колоде набралось
  `FSRSOptimizer.minimumReviewCount` (400) годных оценок, вторая на 1500, дальше не чаще
  чем раз в 30 дней или через 1000 новых оценок, что раньше; колода, пришедшая с длинным
  логом, подгоняется один раз сразу. Судит холдаут по времени: оптимизатор учится на старых
  80 % оценок, а текущие и новые параметры оцениваются по log loss на новых 20 %
  (`FSRSOptimizer.compareOnNewest`); новые остаются, если их log loss ниже текущего хоть на сколько-то
  (`requiredImprovement` = 0, порог — эта константа), иначе параметры целы, а попытка записывается. Ручное
  «Compute from Review Log» сравнивает по всему логу (`compare(with:)`) и решает человек.
  Состояние в `LearningOptions`: `lastAutoFit` (дата, число годных оценок, принята ли) и
  `updatesParametersAutomatically` (по умолчанию да); в `deck.json` оба ключа без смены
  версии и пишутся, только когда не по умолчанию. Оптимизатор идёт вне главного потока с
  приоритетом background, по одной колоде на всё приложение (`ParameterRefitter.run`);
  результат применяет `VocabularyDocument.applyParameterRefit` одним шагом Undo «Update
  Parameters» и бросает его, если выключатель снят или чужая подгонка новее. Mac: при
  открытии документа (`DocumentView`), не при потоке Study. iPhone: после запуска, когда
  Today прочитан и ничего не открыто (`StartScreen.canRefitParameters`), `DeckRefits` читает
  файл каждой известной колоды, готовую открывает через `OpenDeck`, применяет и закрывает.
  Выключатель и строка о последней подгонке — в `ParametersSection` (iPhone: Options →
  Advanced, Mac: лист Learning Options).
- Браузер карточек: фильтры **All · Due · New · Learning · Suspended · Difficult** — одни и
  те же имена на обоих приложениях, правила в `CardFilter` (VocabCore: `matches`,
  `Deck.filterCounts(at:)`; Due, New и Learning не берут suspended, Difficult берёт),
  названия — `CardFilter.title` в `Shared/Support/Presentation.swift`. На Mac это
  сегментный контрол `ScopeBar` над таблицей (`searchScopes` на Mac живёт только пока идёт
  поиск, а фильтры должны быть видны всегда), со счётом в каждом сегменте. Поиск
  (`CardSearchIndex`) смотрит и в `note`; колонка Kind сортируется по `CardRow.kindRank`;
  инспектор ведёт к сиблингу ссылкой (`Deck.siblings(of:)`), лист правки меняет ключ
  слова через `VocabularyDocument.setNote` (`DeckChange.settingNote`, kind остаётся) и
  прячет его, пока сессия ещё спрашивает карточку: ключ карточки «перевод → греческий»
  и есть ответ.
  Клик по строке `Table` на macOS 27 выделяет строку, но фокус не берёт (`NSTableView.mouseDown`
  не вызывается, замер живым кликом 22.10.2026), и поле формы остаётся первым респондером:
  Delete, ⌘E и стрелки уходят в него. `TableClickFocus` (фон таблицы) переводит фокус в таблицу
  после клика мышью по ней; выделение, меняющееся само, фокус не трогает.
- Study открывает поток без конца, сессий нет (`StudyStream` в VocabCore, на обоих
  приложениях его ведёт `SessionDriver`): каждая оценка пишется сразу, выход ничего не
  теряет. Порядок: план дня (`StudySession.counts`, тот же отбор и лимиты; пока план
  непуст, он пересчитывается после каждого сегмента) → пауза «Done for today» (размер
  плана, доля вспомненных, ближайшая дата; кнопки «Keep Going» и «+10 new») → `Stage.catchUp`
  (остаток хвоста: просроченные Review, не вошедшие в план дня, `StudyCounts.catchUp`;
  они due, поэтому оценки обычные, а сделанные карточки идут в круги) → review ahead
  (не наступившие Review по возрастанию текущей вероятности вспомнить, оценки
  обычные; сиблинги и карточки, оценённые сегодня, пропускаются) → практика без
  влияния на расписание (`Deck.mistakes(onDayOf:calendar:)`, затем `Deck.newestBatchIDs`,
  по кругу). Новые сверх лимита — только `addNewCards(10)` со строкой «≈ +N cards/day next
  week» (карточек в день на следующей неделе; `NewCardLoad`: симуляция FSRS, все оценки Good,
  без лапсов, день due — одна оценка и одна карточка плана). Undo идёт через весь поток:
  снимок `UndoCompanion` — это значение `StudyStream` целиком. «Practice Mistakes» и
  «Practice Newest Words» — входы отдельных потоков (`practicingMistakesIn:`,
  `practicingNewestWordsIn:`), они кончаются паузой с итогами.
- Кольцо и streak (`DailyProgress` в VocabCore, `DailyRingModel` и `DailyRingView` в
  `Shared/Session`) — только из лога оценок (`reviews.jsonl`), ничего не хранится. День меряется
  в карточках: кольцо, «M of K cards», «N cards left», виджет и streak считают карточки. Оценка
  (одна оценка одной карточки) в цель, кольцо и streak не входит: оценки считают оптимизатор,
  статистика и темп. **План дня** — карточки, которых день просит по FSRS (`StudySession.counts`:
  карточки due, просроченные тоже, и новые в пределах лимитов дня; хвост входит долей, ниже).
  **Цель дня** — число карточек в плане на начало дня (04:00), `StudyCounts.total` плана. План на
  начало дня — `DeckActivity.plan(onDayOf:calendar:)`: карточки, оценённые сегодня, возвращаются
  к состоянию последней оценки до дня (`Scheduler.replaying`, только пока есть что откатывать),
  карточки, созданные позже, в план не входят (`StudySession.DayIndex`). Цель дня не меняется:
  Add Cards, «+10 new» и Again её не поднимают. **Сделанная карточка**
  (`DeckActivity.done(onDayOf:calendar:)`) — карточка, которую оценили в этот учебный день и чей
  due позже конца дня, то есть FSRS отпустила её на другой день: Review, оценённая Hard, Good или
  Easy, сделана сразу, новая — после последнего шага обучения, Forgot — когда карточка выйдет из
  learning. Считается один раз в день, сколько бы оценок ей ни понадобилось (оценки по дням,
  `reviewsByDay`, нужны только для начала streak и дней до `planRuleStart`). **Кольцо** —
  сделанные карточки к цели дня; сверх цели сделанные идут в круги (в потоке в центре ×2 на
  втором круге, ×3 на третьем): catch-up, review ahead и «+10 new» заполняют круги. **Осталось** —
  карточки плана, ещё не сделанные: `StudySession.counts(...).total` сейчас, строка «N cards
  left»; сделанные + осталось = цель, пока в план ничего не добавили. Рядом с ней «≈ 7 min»
  (строка Today, шапка потока пока цель открыта, виджет, подсказка кольца на Mac):
  `DailyGoal.minutesLeft` = ceil((новые × темп новых + прочие × темп прочих) / 60), меньше
  минуты — «< 1 min», без карточек строки нет. Новые — оставшиеся карточки, бывшие новыми на
  начало дня, включая новую, начатую сегодня и ещё в шагах (`StudyCounts.newAtDayStart`); прочие —
  остальные оставшиеся. **Темп** — секунды на сделанную карточку в двух ценах (`Pace`,
  `DailyGoal.pace`): для карточек, бывших новыми на начало их учебного дня (до дня оценок нет), и
  для прочих (review, relearning, learning с прошлых дней). Промежуток между соседними оценками
  учебного дня (по всем колодам вместе), любой длины, идёт карточке более поздней оценки, в
  категорию, которую карточка имела в этот день: шаги новой — в новые, Again на review-карточке и
  её relearning — в прочие. Цена категории — типичные секунды на оценку, умноженные на число оценок,
  которое потребовалось её сделанной карточке. Типичные секунды — среднее логнормали, к которой
  принадлежат промежутки категории, по медиане m и межквартильному размаху логарифмов промежутков
  (промежуток не короче 1 с, s = IQR / 1,349): exp(m + s² / 2). Перерыв — редкий промежуток далёкого
  хвоста, он не двигает ни медиану, ни IQR, пока перерывов меньше четверти промежутков. Оценок на
  сделанную карточку — все оценки категории за 7 учебных дней до сегодня и сегодня, первая оценка
  каждого дня (промежутка у неё нет) тоже, делённые на карточки категории, сделанные в эти дни
  (`DeckActivity.paceLog`, воспроизведение лога через `Scheduler`); шаги и Again входят в цену.
  Меньше 20 промежутков или меньше 10 сделанных карточек категории — 30 с для новых, 10 с для
  прочих (`DailyGoal.paceMinimumGaps`, `paceMinimumCards`). Промежуток включает и время между
  карточками (меню, экран отдыха): длительностей в логе нет. `DailyProgress.cardsLeft`, `.newCardsLeft`,
  `.pace`, `.minutesLeft`; прогноз виджета знает только число карточек на час, поэтому снимок держит
  одну цену (`WidgetSnapshot.secondsPerCard` = `DailyProgress.secondsPerCardLeft`: время оставшихся
  сейчас карточек, делённое на их число, без карточек — цена прочих) и считает по ней минуты
  каждого часа. Практика в лог не пишется и не считается. Правило
  целиком в `DailyGoal` (VocabCore): `goal(done:owed:plan:)` берёт план на начало дня;
  единственное исключение: плану нечего ждать (`owed == 0`), а сделано меньше (карточки
  приостановили или удалили посреди дня), тогда цель — сделанные, чтобы кольцо не стояло открытым
  рядом с «0 cards left»; день, начавшийся с пустым планом (первая колода, наполненная днём),
  берёт план как он есть, `done + owed`, чтобы у первого дня была цель. Кап цели или другой
  разброс хвоста — правка этого типа. `cardsPerSession` — размер сегмента потока, план он не
  режет: `counts` его не знает, и ничего из видимого не растёт по сегментам. **Хвост** (backlog) —
  Review, что были due до начала учебного дня — просит от дня долю хвоста
  `DailyGoal.backlogShare(of:onTime:)` = min(хвост, max(ceil(хвост / `backlogSpreadDays`),
  `onTime`)), где `onTime` — Review, due в этот учебный день: хвост не больше обычного дня
  уходит за день (один пропущенный день не оставляет недельного хвоста), большой — по седьмой
  части; самые забытые первыми. Доля не уменьшается по мере работы: хвост и `onTime` на начало
  дня = остаток + оценённые сегодня, их состояние на начало дня — воспроизведение лога
  (`Scheduler.replaying`, только пока есть просроченные). Остаток — catch-up,
  `StudyCounts.catchUp`. Карточка делается в любом режиме, включая catch-up и review ahead. День
  засчитывается, когда кольцо замкнуто (сделано ≥ цели), пустой план тоже; сегодня судится по
  кольцу, прошлый день — по `StudySession.counts` на конец того дня (`DeckActivity.owed`, через
  `DayIndex`, без карточек, созданных позже), то есть по тому, что осталось от его плана: день,
  наверстанный позже, засчитывается. Дни до `DailyGoal.planRuleStart` (23.10.2026) засчитываются
  с одной оценкой, чтобы не оборвать streak, начатый по старому правилу с фиксированным числом
  оценок в день (маркер `ponytail:`, убрать вместе с условием в `Streak.evaluate`); пропущенный
  день не рвёт streak, если выполнен план следующего (в нём уже лежит остаток пропущенного;
  `Streak.repairCards` — сколько карточек плана осталось сделать); два пропуска подряд рвут.
  iPhone считает по всем колодам из `KnownDecks` (файлы читает `DeckFileReader`), Mac — по
  открытым документам (`OpenDecks`). Снимок виджета (`WidgetSnapshot.done`, `.goal`) держит
  сделанные карточки и цель; ключ JSON остался `reviews` через `CodingKeys`, чтобы сохранённый
  снимок читался.
- iPhone запускается на Today (`StartScreen` держит состояние, `TodayScreen` рисует): «N cards left» (карточки плана, ещё
  не сделанные, не сырой due) и «M of K cards» (сделанные карточки против цели дня: M, N и K в одной
  единице, M + N = K, пока в план ничего не добавили; Forgot его не нарушает), «+N to catch up this week» при хвосте, кольцо
  и streak по всем колодам, колоды строками. Study открывает поток одним касанием поверх экрана
  (`StudyRunView`). Строка колоды толкает на стек Today экран колоды (`DeckScreen`/`DeckContent`:
  счётчики дня, Study This Deck, Cards → браузер, Add Cards, практики, Statistics, Options; меню:
  Rename…, Delete Deck). Колоды стека держит открытыми `PushedDecks`: открывает при пуше маршрута
  (`DeckRoute`, колода назвала слотом, а не файлом — переименование не меняет маршрут), закрывает, когда
  маршрут ушёл из `path`; экраны выше (`CardBrowserScreen`, `CardDetailScreen`, опции) показывают один
  документ. Study This Deck идёт по колоде экрана (`StudyRun(ownsDeck: false)`: поток её не закрывает;
  после потока `undoManager.removeAllActions()`, чтобы Undo браузера не откатывал оценки). Rename и
  Delete закрывают колоду до `DeckFiles.rename`/`trash` и обновляют `KnownDecks` (`replace`, `forget`).
  Поиск Today (`AllCardsSearch`) читает файлы всех колод без открытия, `CardSearchIndex` ищет и по word
  key; результат толкает `CardDetailScreen` на колоде, открытой слотом. Меню «+»: Add Cards в колоду,
  использованную последней (`KnownDecks.last`: изучена или пополнена), New Deck (в папку колод,
  без папки — в Documents приложения). Браузер карточек: фильтры All · Due · New · Learning ·
  Suspended · Difficult (`CardFilter` из VocabCore, счета — `Deck.filterCounts(at:)`: приостановленная карточка только в All,
  Suspended и, если leech, Difficult), сортировки `BrowserSort`, логика в `CardBrowserList` без экрана и с тестами.
  Undo правок — `UndoWatch` (кнопка в панели, пока есть что откатить) и встряска (`StartScreen`, если
  не открыт лист). Карточка из потока (`CardInfoSheet`) — тот же `CardDetailScreen`. Study без
  колоды ведёт колоды с планом по очереди (`StudyRun`: использованная последней первой, дальше по
  списку); пока поток колоды отдыхает, кнопка «Next: …» открывает следующую. Последнюю колоду
  приложение само не открывает. Акцент — системный индиго `#5856D6` в `AccentColor` (все три каталога ассетов:
  iPhone, Mac, виджет): заливка кнопки, кольцо, глиф, но не текст; счётчики New/Learning/Review нейтральные. Спека —
  `references/design-spec.md`, контракт экранов — `references/flows.md`. Кадры: Today и экран колоды —
  `VocTrainTests/HomeSnapshotTests` (каталог — `TEST_RUNNER_HOME_SHOTS_DIR`), браузер, карточка и
  правка — `BrowserSnapshotTests` (`TEST_RUNNER_STUDY_SHOTS_DIR`).
- Последняя партия слов: `Deck.newestBatchIDs` — карточки с тем же `created` (до секунды),
  что и самая свежая в колоде, без suspended; `deck-from-tsv` ставит один `created` на
  прогон. Практика партии расписание не трогает: Mac — Study ▸ Practice Newest Words
  (`SessionViewModel(entry: .practiceNewest)`), iPhone — строка в листе деталей колоды
  (`StudyModel(entry: .practiceNewest)`). Карточка, добавленная руками позже, начинает свою
  партию.
- Импорт Anki (`.apkg`, `.colpkg`; VocabCore, `Import/Anki`, экраны — следующий пункт): `AnkiImport.read(url)`
  читает три раскладки (`collection.anki2`, `.anki21`, `.anki21b` под zstd с protobuf `meta`) и
  отдаёт `notes` (front, back, `reviews`, `isSuspended`, `preset`), счётчики пропусков (`skippedCloze`,
  `skippedMediaRefs`, `skippedEmpty`), `deckNames` и `presets`; синхронный и тяжёлый, звать не с главного
  потока. Карточки с историей — `AnkiImport.cards(from:learningOptions:calendar:created:)`: состояние
  берётся повтором повторений через `Scheduler.replaying` с параметрами FSRS колоды (память самого
  Anki не читается), в колоду их кладёт `DeckChange.importing(_:into:learningOptions:)` (`adding` берёт
  только новые карточки без лога). Пресеты (`AnkiPreset`: имя, `parameters`, `desiredRetention`) идут
  из `col.dconf` схемы 11 (ключи `fsrsWeights`, `fsrsParams5`, `fsrsParams6`, `desiredRetention`) и
  таблицы `deck_config` схемы 18 (protobuf-поля 3, 5, 6 и 37; `decks.kind` ведёт к пресету колоды);
  берётся самый новый непустой список, как в `DeckConfig::fsrs_params` rslib. `fsrsParameters` даёт
  21 значение: 17 и 19 дополняются как `check_and_fill_parameters_fsrs6` в fsrs-rs 6.6.2 и
  прижимаются к диапазонам (`clip_parameters`), другая длина не берётся.
  `AnkiImport.learningOptions(applyingTo:)` ставит параметры и запоминаемость (в
  `LearningOptions.sanitize`) пресета, которым пользуется больше всего карточек; пресет без
  настроек FSRS (нет читаемых параметров, запоминаемость 0.9 как у Anki по умолчанию) даёт `nil`.
  Не читаются: запоминаемость колоды (`Deck.Normal.desired_retention`) поверх пресета и `dr` карточки
  из `cards.data`. Зависимость одна: `facebook/zstd` (SwiftPM, BSD, в `THIRD_PARTY_NOTICES.md`);
  Compression zstd не знает. Фикстуры настоящих пакетов — `Tests/VocabCoreTests/Resources/Anki`,
  скрипт их сборки лежит рядом (`uv run --with anki`).
- Экраны импорта Anki (`Shared/Support/CardImport+Anki.swift`, `.apkg` принимают пикер iPhone,
  панель Mac и «Open in Mnemit»): тип `UTType.ankiPackage`, импортируемый
  `com.euf.mnemit.anki-package` (расширение `apkg`, conforms `public.zip-archive` и `public.data`),
  в обоих `Info.plist` — тип документа Viewer, `LSHandlerRank` Alternate. Предпросмотр тот же, что у
  CSV (`CardImport.Preview`, у пакета `anki: AnkiSummary` — названия колод Anki, сколько карточек с
  историей, пропуски cloze, медиа, пустых); дубликаты по вопросу против целевой колоды без галки
  (`CardImporter.candidates(of:existing:)`, общий с CSV). Пакет читает `CardImport.loadAnki(at:)`
  вне главного потока (доступ, `NSFileCoordinator`), карточки считает `ankiPreview` там же:
  параметры FSRS и календарь берутся из целевой колоды, а у новой колоды (`isNewDeck`, без карточек)
  параметры и запоминаемость — из пресета Anki (`Preview.learningOptions`). «Add N Cards» —
  `importCards(_:learningOptions:)` → `DeckChange.importing`, один Undo: карточки и опции новой
  колоды уходят одним изменением. В предпросмотре строка `AnkiSummary.settings`: «Uses Anki's FSRS
  settings: 90 % target» у новой колоды, «Anki's settings for this deck are not applied to an
  existing deck.» у существующей; без настроек FSRS в пресете строки нет. iPhone: URL разбирает `IncomingLink` (study, ankiPackage, deck)
  в `StartScreen.open`; пакет копируется в `tmp/IncomingAnki` (`IncomingPackages`: URL бывает
  scoped, в Inbox или в iCloud), лист `AnkiDestinationSheet` читает его и спрашивает, куда: «New
  Deck “<имя>”» (`DeckFiles.create` в текущей папке, имя — `CardImport.deckName`, занятое
  получает « 2», « 3»; файл помечен `ImportedFile.isNewDeck`) или колода из списка; затем тот же
  `AddCardsHost` с `ImportPreviewSheet`.
  Пока накрыто введение или поток Study, пакет ждёт (`waitingAnki`). Ссылка «Shared Decks on
  AnkiWeb» (`AnkiWebLink`) — в меню «+», пустом Today и на экране колоды — открывает браузер
  сайтов с колодами (следующий пункт). Mac: `AppDelegate.application(_:open:)` ведёт `.apkg` из
  Finder тем же путём, что «Import Cards» окна приветствия (`WelcomeRequest.importIntoNewDeck(from:)`:
  запрос и новый документ), окно нового документа зовёт `DocumentView.importCards(from:namesDeck:)` и
  называет безымянную колоду (`displayName`) по колоде Anki и берёт настройки пресета (`isNewDeck`:
  `namesDeck`, документ без файла и карточек); «Import Cards» из меню окна колоды (`namesDeck` ложь)
  оставляет настройки колоды; колоды из Finder уходят оттуда в `NSDocumentController.openDocument`.
- Браузер сайтов с колодами (`Shared/Web/DeckWebBrowser` и `DeckWebBrowserView`, лист на iPhone,
  окно `DeckWebWindow` на Mac из окна приветствия и пункта File «Shared Decks on AnkiWeb…»): обычный
  `WKWebView` под управлением человека, без скриптов в страницах, без своего user agent, без
  разбора и предзагрузки страниц; приложение получает только файл, который человек скачал сам.
  Источники — одна константа `DeckSources.all` в `Shared/Support/DeckSources.swift` (AnkiWeb Shared
  Decks — стартовая страница, MintDeck Free Decks): это и закладки в тулбаре, и список хостов.
  Хост источника или его поддомен (https) остаётся в окне; клик по ссылке на любой другой хост уходит
  в Safari, редиректы источника не считаются кликом. Скачивание: ответ главного фрейма становится
  `.download`, если имя файла (`Content-Disposition` или путь) кончается на `apkg`, `csv`, `tsv`, или
  заголовок `attachment`, или MIME `application/octet-stream`, `zip`, `text/csv`, `text/tab-separated-values`,
  или WebKit показать ответ не умеет (`DeckDownload.shouldDownload`); так же — ссылка с атрибутом
  `download`. `WKDownloadDelegate` кладёт файл в `tmp/DeckDownloads/<uuid>/` (имя без `.apkg`/`.csv`/
  `.tsv` получает `.apkg`, ошибку чтения назовёт импорт); следующая загрузка чистит папку. Файл идёт тем
  же путём, что у «Open in Mnemit» и пикера: iPhone — `StartScreen.receiveDownload` (пакет в
  `receiveAnki`, таблица в предпросмотр колоды, использованной последней, а без колод — в новую по
  имени файла), Mac — `WelcomeRequest.importIntoNewDeck(from:)`. WebKit-файлы исключены из таргета
  виджета (`PBXFileSystemSynchronizedBuildFileExceptionSet` у группы `Shared`); у Mac-приложения
  в песочнице добавлен `com.apple.security.network.client`, без него `WKWebView` ничего не грузит.
- Импорт и экспорт CSV/TSV: логика общая, `CardImport` и `CardExport` в `Shared/Support`; на Mac
  к ним добавлены панели файлов (`CardImportPanel`, `CardExportPanel`), на iPhone — листы ниже.
  Выгрузка начинается строками Anki `#separator:tab` (или `comma`), `#html:false`,
  `#columns:Front⇥Back⇥Hint⇥Word Key⇥Kind` (на Mac с состоянием обучения ещё `Maturity`,
  `Due`, `Reviews`), строки-шапки с названиями нет: Anki принял бы её за карточку. Названия
  колонок английские на любом языке; Front и Back — имена полей базового типа заметок Anki, по
  ним его диалог сам сопоставляет первые две колонки. `kind` — `recognition` или `production`,
  у карточки без word key пусто. Чтение: `DelimitedText.decode` пропускает строки `#…` в начале
  файла, берёт разделитель из `#separator` и отдаёт `columns`; `CardImporter` находит
  Question или Front, Answer или Back, Hint, Word Key и Kind по названиям (из `#columns` или
  из строки-шапки), kind без word key отбрасывается. Выгрузки со строкой-шапкой на языке
  приложения, как писались раньше, читаются через `CardImport.isHeader`. Что из Anki не
  читается: колонки `#guid column`, `#notetype column`, `#deck column`, `#tags column` и
  `#html:true` (HTML остаётся в тексте). iPhone: «Import Cards…» на экране колоды и «Import…»
  в меню «+» Today (в колоду, использованную последней) ведут через `cardFileImporter` в
  `ImportPreviewSheet` (дубликаты без галки, «Add N Cards» — один `importCards`, один Undo);
  «Export…» в меню экрана колоды — `ShareLink` с `DeckExport` (TSV во временном файле
  `<колода>.tsv`). Два `fileImporter` на одной вьюхе гасят друг друга: у `StartScreen` пикер
  колод на стеке, пикер карточек на `TodayScreen`.
- Виджет (таргет `MnemitWidget`, папка `MnemitWidget/`, bundle id `com.euf.mnemit.ios.widget`,
  встроен в приложение на iPhone): home screen small и medium, lock screen circular и
  rectangular, тап ведёт по `mnemit://study` сразу в поток (`StartScreen.open`). Данные идут
  одним снимком `WidgetSnapshot` (`Shared/Widget`): дата, сделанные карточки и цель дня, streak и
  замкнуто ли кольцо, цена оставшейся карточки (`secondsPerCard`), прогноз «сколько карточек в плане» на каждый час
  48 часов вперёд по всем колодам, время ближайшего напоминания (`Reminders.nextFire`). Приложение пишет его JSON
  в элемент keychain общей группы `$(AppIdentifierPrefix)com.euf.mnemit.shared`
  (`KeychainSnapshotStore`, `AfterFirstUnlock`), App Groups нет: бесплатная Personal Team
  даёт только keychain sharing. Один `VocTrain/Mnemit.entitlements` стоит
  `CODE_SIGN_ENTITLEMENTS` у приложения и у виджета, скрипт подписи iPhone обязан подписать
  им оба бандла. Префикс команды в коде не пишется: его читают из группы, куда keychain
  кладёт элемент без группы. Писать снимок — `WidgetSync` (после оценки, при запуске, при
  смене колод и напоминания, сразу при уходе в фон; пауза 2 с склеивает серию оценок), потом
  `reloadAllTimelines()`; под тестом он выключен. Таймлайн (`WidgetSnapshot.timeline`) берёт
  записи в часы прогноза, в начало следующего учебного дня (4:00, не полночь: кольцо сбрасывается
  тогда) и на время напоминания; пока снимок не обновлён, streak держится один пропущенный день.
  Таргет виджета собирает всю `Shared` (так лежат `DailyRingView` и всё, что ей нужно, и каталог
  строк): новый файл в `Shared`, которому в расширении нечего делать (`UIApplication.shared`),
  надо исключить из его членства. Кадры — `VocTrainTests/WidgetShotsTests`
  (`TEST_RUNNER_STUDY_SHOTS_DIR`). `PRODUCT_BUNDLE_IDENTIFIER=…` в командной строке `xcodebuild`
  перекрывает и bundle id виджета.
- Версия — `VERSION`, патч бампает pre-commit-хук; после клона
  `ln -sf ~/dotfiles/claude/version-hook .git/hooks/pre-commit`.
- Первый запуск на iPhone (`OnboardingView`, шаги `OnboardingStep`): приветствие с одной
  кнопкой → практика свайпов (`GesturePracticeView`, порядок и образцы карточек —
  `SwipePractice`: ← забыл, ↑ сразу, ↓ с трудом, → помню; четыре значения и есть правила,
  отдельного экрана правил нет; «Пропустить» ведёт к синхронизации) → синхронизация
  (iCloud Drive: пикер папки, `chooseFolder`; «Only on This iPhone»: `useLocalFolder`, папка
  Documents приложения без закладки и scope, в Files — On My iPhone ▸ Mnemit) → напоминание.
  Одиночную колоду открывает «Open Deck…» в меню стартового экрана. Прототип сценариев —
  `docs/prototypes/onboarding.html`. Папка колод:
  iPhone — `KnownDecks.chooseFolder` (закладка папки, колоды из неё в списке, `refreshFolder`
  при pull-to-refresh и выходе на передний план; пустую папку берёт только с именем
  `Mnemit`), Mac — `DeckFolder` (закладка со scope,
  entitlement `bookmarks.app-scope`). Напоминание — `Reminders`: локальные уведомления на
  7 дней вперёд, у каждого дня свои числа `StudySession.counts(for:at:)`, число на значке;
  пересчёт при уходе в фон, после закрытия колоды и при смене времени. Окно приветствия на
  Mac — `AppDelegate` и `WelcomeWindow` (откат: `defaults write <bundle id> showsWelcomeWindow
  -bool NO`). «Add Lesson Words…» (⇧⌘L) — `LessonWords` в VocabCore: `note` по `key()` из
  `greek-lessons/vocab/merge.py`, две карточки на слово, одна отмена; сторону от стороны отделяют `=`, `–`, `—`, табуляция
  и дефис с пробелами с обеих сторон (его печатает клавиатура телефона), дефис внутри слова
  не делит.
- Экран Study на iPhone (`StudyView`): все отступы берутся из шкалы `Spacing` в
  `Shared/Support/Presentation.swift` (4, 8, 12, 16, 24 pt): 16 по бокам, 12 между чипом,
  карточкой и кнопками и под кнопками, 24 внутри карточки. Show Answer лежит оверлеем на
  блоке оценок и занимает его прямоугольник, поэтому карточка не меняет высоту при открытии.
  Касание карточки открывает ответ (`touch`: `DragGesture(minimumDistance: 0)` через
  `simultaneousGesture`); касание, начатое на динамике, остаётся за кнопкой: динамики
  (`SpeakButton`) сообщают свои рамки в `SpeakerPlaces`, и жест карточки такие касания
  пропускает (ни ответа, ни свайпа, ни листа информации). Динамик рядом со словом
  (`SpokenWord`) берёт его шрифт и стоит на первой базовой линии. Чип отмены (`UndoChip`)
  занимает своё место всегда, даже пустой. Кадры состояний пишет
  `VocTrainTests/StudyScreenSnapshotTests` (путь — переменная окружения
  `TEST_RUNNER_STUDY_SHOTS_DIR` у процесса xcodebuild, аргументом она не доходит), замеры по
  пикселям — `SpeakerAlignmentTests` и `PixelBitmap`.
- Свайп карточки (`GradeSwipe`, `CardFlight`): четыре стороны, те же, что стрелки на Mac:
  ← Forgot, → Good, ↑ Easy, ↓ Hard. Угол пальца считается против часовой от востока, y экрана
  вверх, сектора — константы `GradeSwipe` (`goodReach` 55, `easyEnd` 120, `forgotStart` 150,
  `forgotEnd` 210, `hardStart` 240): Good −55°…55°, Easy 55°…120°, Forgot 150°…210°, Hard
  240°…305°. Зазоры 120°…150° и 210°…240° оценки не дают: нет тинта и подсветки кнопки, карточка
  идёт на `gapTravel` (половину) пути пальца, отпускание возвращает её, даже за порогом и фликом.
  Между Good, Easy и Hard зазоров нет. Карточка идёт по нормированному среднему
  единичного направления пальца и цели оценки (Good E, Easy NE, Forgot W, Hard SE) на расстоянии
  пальца (`GradeSwipe.pull`); на смене зоны или зазора её плавит короткая пружина
  (`CardFlight.glide`, 300 мс). Порог 100 pt, мёртвая зона 20 pt, флик 30 pt пути и 300 pt прогноза; вылет
  по цели. Подсказка онбординга играет шаг пальца по оси сектора через `CardFlight.drag`. Спека —
  `references/design-spec.md` §4.7.

## Upstream

macOS vocabulary trainer (SwiftUI, Swift 6, macOS 26+) with an iPhone app to study on
the go (iOS 26+). The user writes German; code, comments and base UI strings are
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
- `Shared/Document/VocabularyDocument.swift`: the document of both apps; only its
  `ReferenceFileDocument` conformance is the Mac's (`MacVocTrainNg/Document/`). The methods
  that edit cards and options (`add`, `editText`, `editCard`, `setNote`, `setKind`, `delete`,
  `resetLearningState`, `updateLearningOptions`, `setSuspended`, the imports) are the
  same on both, in `Shared/Document/VocabularyDocument+Editing.swift`, with the same undo
  action names (#297). Every change must go through its `@MainActor` methods: they register undo, which is also how SwiftUI
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
  iPhone app lets go of the file in the background. Both apps edit cards, so a merge
  (`DeckChange.merging`, rules in its doc comment) settles each part on its own: cards are
  joined, a card's texts by `Card.contentChanged`, the options by
  `Deck.learningOptionsChanged`, a deletion by `Deck.deletedCards` against the latest
  change of the card, reviews are joined and never dropped for a deletion that is earlier.
- The Xcode project uses synchronized folders: new files in `MacVocTrainNg/` or
  `MacVocTrainNgTests/` are picked up automatically, likewise in `VocTrain/` (the
  iPhone app) and `VocTrainTests/`.
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
