# HANDOFF — Mnemit

## Состояние

- Mac: `~/Applications/Mnemit.app`, `com.euf.mnemit`, ставится `Scripts/install-mac.sh`.
- iPhone 13 mini (UDID `00008110-000411010C68401E`): Mnemit (bundle id из профиля), ставится
  `Scripts/install-iphone.sh`. Приложение на iPhone только учит, карточки правятся на Mac.
- Колода: `iCloud Drive/MacVocTrain/Greek B1.voctrain`, 209 карточек, 20 новых за сессию.
  Источник — `~/Documents/greek-lessons/b1/deck-greek-b1.tsv` (индекс источников рядом в
  `README.md`). Вопрос — значение по-английски, ответ — греческое слово, подсказка —
  русский перевод, полная форма прилагательного или пример. Направление выбрано под
  экзамен: печатать греческий. Перевернуть — переставить колонки TSV и собрать колоду заново.
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

- 24 пары «греческая фраза — картинка» из Wordwall в колоду не вошли: у них нет текстового
  ответа. Кандидаты с английскими глоссами, которые написал агент, —
  `~/Documents/greek-lessons/b1/image-pairs-candidates.tsv`; добавить — проверить глоссы и
  прогнать `deck-from-tsv` по этому файлу.
- Интерфейс приложений немецкий и английский; русского нет.
