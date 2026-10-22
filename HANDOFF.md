# HANDOFF — Mnemit

## Состояние

- Mac: `~/Applications/Mnemit.app`, `com.euf.mnemit`, ставится `Scripts/install-mac.sh`.
- iPhone 13 mini (UDID `00008110-000411010C68401E`): Mnemit `com.euf.mnemit.ios` с виджетом
  `com.euf.mnemit.ios.widget`, ставится `~/dotfiles/ios-renew --force` (см. «Подпись iPhone»).
  На iPhone учат, правят карточки и колоды, добавляют слова после урока.
- Колоды в `iCloud Drive/Mnemit/`, обе собраны `Tools/deck-from-tsv` из словаря
  `~/Documents/greek-lessons/vocab/` (`merge.py` → `greek-vocab.tsv`, `cards.py` → `cards-*.tsv`):
  - `Greek A1–A2.mnemit` — повторение знакомого: 1629 слов, 3258 карточек (узнавание и
    перевод на греческий), 30 + 30 новых за сессию, production не заперта, порядок колоды.
  - `Greek B1.mnemit` — изучение: 1118 слов, 2236 карточек, 20 новых узнавания + 7 production,
    production открывается через 21 день, новые — сначала свежие. 78 старых карточек
    первой колоды заморожены (их слова ушли в A1–A2), 131 усыновлена с прогрессом.
  Вопрос на узнавание — греческая форма, ответ — русский · английский и пример; на перевод —
  русский, подсказка — часть речи и английский, ответ — греческая форма и пример. Греческого
  в подсказке нет никогда. Копии перед каждой записью — `iCloud Drive/Mnemit/.backups`.
- Формат колоды — пакет `.mnemit` (тип `com.euf.mnemit.deck`). Колоды с `.voctrain` открываются,
  перечисляются в папке и сохраняются на месте под своим именем; приложения ничего не
  переименовывают, колоду переименовывают руками в iCloud Drive.
- Синхронизация: один файл-пакет в iCloud Drive, оба приложения открывают его на месте.
  Конфликтные версии сливает `VersionMerger` апстрима. CloudKit и iCloud-entitlement не нужны.

## Подпись iPhone

Бесплатная Personal Team `2NS3PB4YC9` (Apple ID в Xcode → Settings → Accounts), сборка и
установка — `~/dotfiles/ios-renew` по строке в `~/.config/ios-renew/apps`:
`/Users/eugene/Code/Mnemit MacVocTrainNg.xcodeproj VocTrain VocTrain/Mnemit.entitlements`.
Скрипт собирает `main` из своего worktree, Xcode сам выдаёт профили на 7 дней приложению и
виджету, launchd `com.eugene.ios-renew` продлевает их каждую ночь. Entitlements приложения и
виджета — один файл с `keychain-access-groups = $(AppIdentifierPrefix)com.euf.mnemit.shared`:
через этот keychain-элемент приложение отдаёт виджету снимок дня. iCloud-контейнера и Push у
бесплатной команды нет, поэтому папка колод выбирается окном выбора файлов. Лимиты команды:
3 приложения на устройство (сейчас FicTypeApp и Mnemit), 10 App ID в неделю.

## Открыто

- Волна 3 по `references/flows.md`: импорт `.apkg` с историей, CSV/TSV на iPhone, экспорт с
  заголовками Anki, ссылка на общие колоды AnkiWeb.
- Живьём не проверены: виджет на телефоне (снимок через keychain, тап → учёба), «Compute from
  Review Log» на iPhone, клавиатура и фокус в Add Cards.
- Mac: тест `CardListViewTests.firstClickIntoTableSelectsRow` падает, когда тестовое приложение
  не на переднем плане; сам клик и фокус проверены вживую (`vqa`).
