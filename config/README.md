# Каталог `config/` (infrastructure-public)

Модульная конфигурация bootstrap: **без секретов в git**.

## Формат

Файлы `*.env` — строки `KEY=VALUE`, комментарии с `#`.

## Приоритет

**Переменные окружения процесса** (в т.ч. `sudo env ENV=stage REF=main bash start.sh`) **выше**, чем значения из `config/*.env`. Это нужно, чтобы одноразово переопределять параметры без правки файлов.

Если переменная уже задана в окружении до загрузки `scripts/lib/load-env.sh`, строка с тем же ключом из `config/` **не применяется**.

Порядок чтения файлов (отсутствующий файл пропускается):

1. `config/host.env`
2. `config/repos.env`
3. `config/ssh.env`
4. `config/galaxy.env`
5. `config/disk.env`

Матрица профилей разметки по размеру диска для шага 40 задаётся в **`config/disk-profiles.sh`** (подключается из `scripts/40-disk-storage.sh`, не через `load-env.sh`).

## Подключение

`start.sh` и `update.sh` подключают `scripts/lib/load-env.sh`, который читает эти файлы.

## Пример

```bash
sudo env ENV=stage REF=main bash start.sh
```

Значения `ENV` и `REF` из командной строки имеют приоритет над `config/host.env` и `config/repos.env`.
