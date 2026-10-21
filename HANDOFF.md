# HANDOFF — Mnemit

## Состояние

- Mac: `~/Applications/Mnemit.app`, `com.euf.mnemit`, ставится `Scripts/install-mac.sh`.
- iPhone 13 mini (UDID `00008110-000411010C68401E`): Mnemit (bundle id из профиля), ставится
  `Scripts/install-iphone.sh`. Приложение на iPhone только учит, карточки правятся на Mac.
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

Сертификат куплен у iApps (Telegram, чат Furman, 20.10.2026, сообщения 628351–628353):
ad-hoc distribution, команда `N686NPXZQZ`, профиль с одним App ID
`app.starfruit2689.orange1525` и одним устройством, действует до 14.10.2027. Apple может
отозвать его раньше: тогда приложение перестанет запускаться, а колода в iCloud останется.

Файлы вне репозитория, `~/.local/share/ios-signing/iapps-2026-10-20/` (700):

| файл | что |
|---|---|
| `iapps.p12`, `iapps.mobileprovision` | как пришли из чата |
| `p12.pass` | пароль p12 из сообщения 628353 |
| `iapps-3des.p12` | тот же ключ, перепакованный в 3DES |
| `signing.keychain-db`, `keychain.pass` | отдельная связка только с этой личностью |

Перепаковка нужна: p12 из чата зашифрован AES-256/PBKDF2, `security import` его не читает
(«Unable to decode the provided data»). Собрать заново:

```bash
cd ~/.local/share/ios-signing/iapps-2026-10-20 && umask 077
openssl pkcs12 -in iapps.p12 -passin pass:"$(cat p12.pass)" -nodes -out tmp.pem
openssl pkcs12 -export -in tmp.pem -passout pass:"$(cat p12.pass)" -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES -macalg sha1 -out iapps-3des.p12 && rm tmp.pem
ORIG=$(security list-keychains -d user | tr -d '"' | xargs)
security create-keychain -p "$(cat keychain.pass)" signing.keychain-db
security list-keychains -d user -s $ORIG    # create-keychain дописывает себя в список поиска
security unlock-keychain -p "$(cat keychain.pass)" signing.keychain-db
security import iapps-3des.p12 -k signing.keychain-db -P "$(cat p12.pass)" -f pkcs12 -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$(cat keychain.pass)" signing.keychain-db
```

Скрипт подписывает только тем, что приложению нужно: `application-identifier`,
`team-identifier`, `get-task-allow=false`, `keychain-access-groups`. Профиль разрешает много
больше; лишнее в подписи installd отвергает.

Новый сертификат — новый каталог и `IOS_SIGNING_DIR=<каталог> Scripts/install-iphone.sh`;
bundle id скрипт возьмёт из нового профиля. Другой телефон — `IPHONE_UDID`, и он должен быть в профиле.

## Открыто

- Бесконечный поток с кольцами и стриком — ветка `worktree-agent-aa4d062d083bbd42b` (агент
  21.10), влить и проверить.
- После потока, двумя агентами по разным файлам: (1) экран учёбы — заикание TTS, дрожание
  текста при свайпе, сильная подсветка кнопок, зоны свайпа под дугу большого пальца и
  поворот от точки захвата, цвета оценок по насыщенности, а не яркости (Hard приглушённый,
  Good обычный, Easy насыщенный, одна светлота, белый текст); (2) главный экран и колода по
  `references/design-spec.md` (один тап до учёбы, акцент терракота, Mac phase A).
- Затем 1.0.0 и установка на Mac и iPhone (телефон разблокирован).
- Бэклог — `references/anki-parity.md`.
