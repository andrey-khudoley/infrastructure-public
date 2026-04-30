# Каталог `config/` (infrastructure-public)

Модульная конфигурация bootstrap: **без секретов в git**.

## Первый запуск после `git clone`

В репозитории — только шаблоны `*.example`. Рабочие файлы на узле:

```bash
make init    # host.env, repos.env, ssh.env, galaxy.env, disk.env ← из соответствующих *.example
```

Повторный **`make init`** снова **перезаписывает** рабочие файлы содержимым шаблонов (полный сброс к образцу).

## Формат

Файлы `*.env` — строки `KEY=VALUE`, комментарии с `#`.

## Приоритет

**Переменные окружения процесса** (в т.ч. `sudo env ENV=stage REF=main make start`) **выше**, чем значения из `config/*.env`. Это нужно, чтобы одноразово переопределять параметры без правки файлов.

Если переменная уже задана в окружении до загрузки `scripts/lib/load-env.sh`, строка с тем же ключом из `config/` **не применяется**.

Порядок чтения файлов (отсутствующий файл пропускается):

1. `config/host.env`
2. `config/repos.env`
3. `config/ssh.env`
4. `config/galaxy.env`
5. `config/disk.env` — переопределения матрицы **`config/disk-profiles.sh`**; после `make init` создаётся из `disk.env.example` (при необходимости отредактируйте или оставьте как есть).

Матрица профилей разметки по размеру диска для шага 20 задаётся в **`config/disk-profiles.sh`** (подключается из `scripts/20-disk-storage.sh`, не через `load-env.sh`).

## Подключение

`scripts/run-start.sh`, `scripts/run-update.sh`, `scripts/run-git-public.sh` и `scripts/run-git-private.sh` подключают `scripts/lib/load-env.sh`, который читает эти файлы. Запускайте их **только через `Makefile`**: `make start`, `make update`, `make git-public`, `make git-private`. Позиционные параметры из **`make <цель> ARGS='…'`** пробрасываются в run-скрипт и логируются (конфигурация — через env и `config/*.env`, см. **`make help`**). Перед запуском должны существовать четыре основных `*.env` — см. **`make init`**. Полный bootstrap дополнительно проходит проверку окружения в шаге **10** (`step_require_runtime`); сценарии только git (`run-update`, `run-git-*`) вызывают `require_bootstrap_config_files` без шага 10.

## Пример

```bash
make init
sudo env ENV=stage REF=main make start
```

Значения `ENV` и `REF` из командной строки имеют приоритет над `config/host.env` и `config/repos.env`.
