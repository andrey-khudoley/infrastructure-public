# Скрипты первичной настройки хоста (bootstrap)

**Репозиторий:** [https://github.com/andrey-khudoley/infrastructure-public.git](https://github.com/andrey-khudoley/infrastructure-public.git)

Репозиторий содержит цепочку shell-скриптов для подготовки **dnf**-системы под инфраструктурный Ansible: диски и swap, пакеты, клон **приватного** репозитория с плейбуками и установка зависимостей Ansible (Python `.venv` из `config/constraints.txt` + коллекции Galaxy в `collections/ansible_collections`). Единый контур версий: **никаких** параллельных установок ansible-core из dnf.

Запуск самих фаз `stage1` → `stage2` → `runtime` — это **отдельные ручные шаги** на стороне приватного репозитория (`make stage1`, затем `make stage2`, затем при необходимости `make runtime`). Никаких systemd-юнитов и автоматических переходов между фазами bootstrap **не используется**: после `make install-deps` шаг **90** вызывает интерактивное **`make update-sysuser`** (имя и пароль администратора в `vars/all.yml`), затем `make start` печатает подсказку с командой запуска `stage1`.

## Роль репозиториев

| Репозиторий | Роль |
|-------------|------|
| **Этот (public)** | Подготовка хоста: диски и swap (**20**), пакеты (**30**); шаг **40** при необходимости приводит **`REPO_URL`** с **`github.com`** по HTTPS к **`git@…`** и готовит deploy key; иначе задайте SSH-URL сами; клон в `PULL_DIR`, **`make install-deps`** в каталоге клона; шаг **90** — повторный `distro-sync`, проверки сервисов, **`make update-sysuser`** в клоне; затем подсказка с командой `make stage1`. |
| **Приватный** | Вся прикладная Ansible-логика: единый `playbooks/site.yml` с фазами `stage1` → `stage2` → `runtime` и **`Makefile`** с целями **`install-deps`**, **`update-sysuser`**, **`stage1`**, **`stage2`**, **`runtime`** и другими. Запуск каждой фазы Ansible — вручную; **`update-sysuser`** при первичной установке вызывается из шага **90** `make start`. |

Публичный сценарий **не** дублирует содержимое приватного **`Makefile`**: он гарантирует окружение, вызывает **`make install-deps`** с согласованным набором переменных (см. раздел **«Контракт: переменные для `make install-deps`»**), а на шаге **90** — **`make update-sysuser`**. Запуск `make stage1` — за пользователем.

## Алгоритм вызова

Bootstrap и синхронизация репозиториев выполняются **только через цели `Makefile`** в корне клона (`make start`, `make update`, `make git-public`, `make git-private`, `make init`). Дополнительные **позиционные** аргументы для соответствующего `scripts/run-*.sh`: **`make <цель> ARGS='…'`** — они выводятся в лог и пока не меняют поведение сценариев; конфигурация задаётся **переменными окружения** (`sudo env VAR=value make <цель>`). Подробнее — **`make help`**.

1. **Склонировать этот репозиторий целиком** (нужны каталог `scripts/` с библиотеками и шагами и остальные файлы проекта).
2. **Перейти в корень клона** и выполнить **`make init`** (копирует шаблоны `config/*.example` в рабочие `config/*.env` и `config/disk.env` с перезаписью). При необходимости отредактировать файлы в **`config/`** (см. [config/README.md](config/README.md) и таблицу ниже).
3. **Запустить оркестратор от root** с переменными окружения: `sudo env … make start`.
4. После завершения `make start` (включая интерактивное **`make update-sysuser`** на шаге **90**) напечатает подсказку — вручную выполнить `cd $PULL_DIR && sudo make stage1 ENV=$ENV`.
5. По окончании `make stage1` будет напечатана подсказка про `make stage2` (если `stage1` потребовал ребут — после загрузки выполнить `make stage2` вручную).
6. Аналогично после `make stage2` появится подсказка про `make runtime` (запускается по необходимости — никаких таймеров).

Минимальный пример с **дефолтами из `config/*.env`** после **`make init`** (ветка `main`, окружение `stage`; **`REPO_URL`** по умолчанию — HTTPS на GitHub, в шаге **40** он приводится к **`git@github.com:…`**, затем выводится deploy key — добавьте его в репозиторий на GitHub):

```bash
git clone https://github.com/andrey-khudoley/infrastructure-public.git
cd infrastructure-public
make init
sudo env ENV=stage REF=main make start
# по окончании:
cd /var/lib/infra/src        # PULL_DIR из config/host.env
sudo make stage1 ENV=stage   # после успеха — подсказка про stage2 (или ребут)
sudo make stage2 ENV=stage   # после успеха — подсказка про runtime
sudo make runtime ENV=stage  # по необходимости
```

Типичный вариант для **приватного** репо на GitHub **без** токена в URL — явный **`git@…`** и deploy key (шаг **40** создаст ключ и покажет публичную часть):

```bash
make init
sudo env ENV=stage REF=main REPO_URL=git@github.com:andrey-khudoley/infrastructure-private.git make start
```

Запуск **только** через `curl … | bash` **не поддерживается**: bootstrap требует полный клон репозитория с каталогом `scripts/` и запуск `make start` из корня клона.

## Точки входа

Основной вход — **`scripts/run-start.sh`** (полная цепочка bootstrap), вызывается через `make start`.

Для обновления git-клонов:
- **`scripts/run-update.sh`** — публичный + приватный sync (`make update`);
- **`scripts/run-git-public.sh`** — только публичный sync (`make git-public`);
- **`scripts/run-git-private.sh`** — только приватный sync (`make git-private`).

Цели `make` задают `ROOT="$(CURDIR)"` для `run-*`; сами скрипты используют `ROOT`, если он уже в окружении, иначе вычисляют корень как родитель каталога `scripts/` (должно совпадать с корнем клона). Переменные окружения (`ENV`, `REF`, `REPO_URL`, `PULL_DIR`, `PUBLIC_*`, `INFRA_SSH_*`, `GALAXY_*`) наследуются при запуске `sudo env ... make <target>`.

### Контракт: переменные для `make install-deps`

После успешного клона в **`PULL_DIR`** выполняется только подготовка зависимостей:

```
make -C "${PULL_DIR}" install-deps
```

`install-deps` сначала создаёт `.venv` и ставит из `config/constraints.txt` закреплённый `ansible-core` и Python-зависимости (`scripts/install-python-deps.sh`), затем устанавливает коллекции Galaxy (офлайн-кэш + `--offline`) в repo-local путь `collections/ansible_collections`. На шаге **90** (`scripts/90-finalize.sh`) выполняются повторный `distro-sync`, проверки **sshd**/при необходимости **NetworkManager** и интерактивное **`make update-sysuser`** в корне клона (имя и пароль системного администратора в `vars/all.yml`). **Сам `ansible-playbook` bootstrap не запускает** — фазы `stage1`, `stage2`, `runtime` инициирует пользователь вручную через `make stage1`/`make stage2`/`make runtime` уже в каталоге клона после подсказки.

В процесс **make** передаётся такое окружение (имена переменных — часть контракта с приватным репозиторием):

| Переменная | Источник | Назначение |
|------------|----------|------------|
| `REPO_URL` | **`config/repos.env`** (если не переопределён окружением) | URL приватного репозитория (тот же, что для `git clone`). |
| `REF` | значение **`REF_VALUE`** (из `REF=…` при запуске и/или из **`config/repos.env`**) | Ветка, тег или коммит; в скриптах после **`load-env.sh`** хранится как **`REF_VALUE`**, в **export** для **`make`** — имя **`REF`**, как ожидает приватный **Makefile**. |
| `ENV` | значение **`ENV_VALUE`** (из `ENV` при запуске) | Логическое окружение (`ctl`, `stage`, `prod`); выбирает `vars/{{ env }}.yml` на стороне приватного репо. |
| `PULL_DIR` | абсолютный путь к клону | Рабочий каталог клона; совпадает с каталогом, из которого выполняется `make install-deps`. |
| `GALAXY_*` | см. таблицу ниже | Таймауты, ретраи и каталог кэша для `scripts/galaxy-offline-install.sh` (используется целью `install-deps`). |
| `COLLECTIONS_REQ` | переменная окружения или по умолчанию `PULL_DIR/collections/requirements.yml` | Путь к `requirements.yml` коллекций. |

Приватный **`Makefile`** может не использовать часть переменных — это нормально; публичный bootstrap всё равно их выставляет для единообразия и обратной совместимости.

### Репозиторий и окружение Ansible

Базовый запуск: ветка `main`, окружение `stage`, **`REPO_URL`** из **`config/repos.env`** (HTTPS на `github.com` обрабатывается в начале шага **40**). Для другого хоста (не `github.com`) или нестандартного URL задайте **`REPO_URL`** сразу как **`git@…`** или **`ssh://…`** (см. шаг **40**):

```bash
ENV=stage REF=main make start
```

Тот же сценарий с явным SSH-URL:

```bash
ENV=stage REF=main REPO_URL=git@github.com:andrey-khudoley/infrastructure-private.git make start
```

Production и фиксированный релиз (тег вместо ветки):

```bash
ENV=prod REF=v1.2.0 REPO_URL=git@github.com:andrey-khudoley/infrastructure-private.git make start
```

Control-узел с веткой по умолчанию (`ENV` по умолчанию — `ctl`):

```bash
REF=main REPO_URL=git@github.com:andrey-khudoley/infrastructure-private.git make start
```

Другой каталог клона (не `/var/lib/infra/src`):

```bash
PULL_DIR=/opt/infra/src ENV=stage REF=main REPO_URL=git@github.com:andrey-khudoley/infrastructure-private.git make start
```

### Без Ansible (только ОС, диски, пакеты)

Полезно для проверки разметки дисков без клона и без **`make install-deps`** в приватном репо:

```bash
SKIP_ANSIBLE=1 make start
```

С теми же переменными, что и для полного прогона (для согласованности профиля дисков), но без клона:

```bash
SKIP_ANSIBLE=1 ENV=stage REPO_URL=git@github.com:andrey-khudoley/infrastructure-private.git make start
```

### Диски: `/var`, `/minio`, LVM

По умолчанию разрешена разметка на диске с root (**`VAR_ALLOW_ROOT_DISK=1`**). Перед созданием разделов или LV на этом диске скрипт выводит предупреждение и ждёт нажатия Enter. Отключить (только отдельные диски): **`VAR_ALLOW_ROOT_DISK=0`**. Для CI и неинтерактивного запуска: **`VAR_ALLOW_ROOT_DISK_SKIP_PROMPT=1`**.

```bash
ENV=stage REPO_URL=git@github.com:andrey-khudoley/infrastructure-private.git make start
```

### SSH deploy key и автоматизация

После первого показа ключа скрипт ждёт Enter. Для CI/автоматизации, когда ключ уже добавлен в GitHub:

```bash
INFRA_SSH_SKIP_PROMPT=1 ENV=stage REPO_URL=git@github.com:andrey-khudoley/infrastructure-private.git make start
```

Для приватного GitHub по HTTPS без токена используйте **`git@...`** или `ssh://` и deploy key (см. раздел **«Шаг 40 — ssh-deploy-key»** ниже).

### Galaxy и медленная сеть

Переменные **`GALAXY_*`** и **`COLLECTIONS_REQ`** передаются в окружение процесса **`make install-deps`** (используются в `scripts/galaxy-offline-install.sh` из приватного репо). Увеличить таймаут и число повторов:

```bash
GALAXY_INSTALL_TIMEOUT=600 GALAXY_INSTALL_RETRIES=10 GALAXY_RETRY_SLEEP_SEC=15 \
  ENV=stage REPO_URL=git@github.com:andrey-khudoley/infrastructure-private.git make start
```

Другой каталог кэша коллекций:

```bash
GALAXY_DOWNLOAD_DIR=/var/lib/infra/galaxy-cache \
  ENV=stage REPO_URL=git@github.com:andrey-khudoley/infrastructure-private.git make start
```

Нестандартный путь к `requirements.yml` коллекций в клоне (редко):

```bash
COLLECTIONS_REQ=/var/lib/infra/src/collections/requirements.yml \
  ENV=stage REPO_URL=git@github.com:andrey-khudoley/infrastructure-private.git make start
```

### Переопределение матрицы дисков

По умолчанию шаг **20** использует только **`config/disk-profiles.sh`**. Файл **`config/disk.env`** создаётся при **`make init`** из **`disk.env.example`**; при необходимости отредактируйте **`config/disk.env`** перед **`make start`**. Рабочие **`config/*.env`** и **`disk.env`** в **`.gitignore`** — в git только шаблоны `*.example`.

Явно указать блочное устройство для расчёта профиля (без файла, одной переменной окружения):

```bash
MAIN_DISK_DEVICE=/dev/sda ENV=stage REPO_URL=git@github.com:andrey-khudoley/infrastructure-private.git make start
```

## Обновление кода на уже настроенном узле

Если **infrastructure-public** уже склонирован рядом с клоном приватного репо (тот же **`config/`** и `PULL_DIR`):

```bash
cd /путь/к/infrastructure-public
sudo env ENV=stage REF=main make update
```

`make update` выполняет sync публичного и **приватного** клонов (`PULL_DIR` из **`config/host.env`** или окружения), без установки каких-либо systemd-юнитов. В конце напечатает подсказку: в корне **приватного** клона вручную запустить `sudo make runtime ENV=…` (и при необходимости снова `make stage1` / `make stage2`).

Точечные git-режимы:

```bash
sudo env ENV=stage REF=main make git-public   # только public sync
sudo env ENV=stage REF=main make git-private  # только private sync
```

## Структура репозитория

```
├── README.md
├── Makefile                 # make init/start/update/git-public/git-private
├── .gitignore               # рабочие config/*.env и disk.env (на узле после make init)
├── config/                  # шаблоны *.example, disk-profiles.sh; см. config/README.md
├── scripts/
│   ├── run-start.sh         # полный bootstrap (запуск через make start)
│   ├── run-update.sh        # public + private git sync (запуск через make update)
│   ├── run-git-public.sh    # только public sync
│   ├── run-git-private.sh   # только private sync
│   ├── init-config.sh       # копирование *.example → рабочие имена (вызывается из make init)
│   ├── lib/
│   │   ├── load-env.sh      # читает config/*.env (в т.ч. disk.env); env побеждает config; ENV_VALUE/…
│   │   ├── require-bootstrap-config.sh  # проверка наличия рабочих *.env перед start/update
│   │   ├── common.sh        # логирование, dnf, git, distro-sync (общее для шагов)
│   │   └── update-repos.sh  # sync_public_repository + print_next_steps_hint
│   ├── 10-require-runtime.sh
│   ├── 20-disk-storage.sh
│   ├── 30-install-packages.sh
│   ├── 40-ssh-deploy-key.sh
│   ├── 50-sync-repository.sh
│   ├── 70-install-deps.sh   # make install-deps в PULL_DIR (без stage1)
│   └── 90-finalize.sh       # distro-sync, проверки, make update-sysuser, подсказка про make stage1
```

## Миграция с корневого `.env`

Раньше настройки лежали в одном файле `.env` в корне клона. Теперь они разнесены по **`config/*.env`** (рабочие файлы создаются **`make init`** из шаблонов **`*.example`**). После `git pull` на уже развёрнутом узле перенесите строки из старого `.env` в соответствующие файлы (или заново **`make init`** и перенос вручную — перезапишет локальные конфиги):

| Было в `.env` | Куда |
|---------------|------|
| `ENV`, `PULL_DIR`, `SKIP_ANSIBLE` | `config/host.env` |
| `PUBLIC_REPO_URL`, `PUBLIC_REF`, `REPO_URL`, `REF` | `config/repos.env` |
| `INFRA_SSH_*` | `config/ssh.env` |
| `GALAXY_*`, `COLLECTIONS_REQ` | `config/galaxy.env` |
| `DISK_*`, `DISK_PROFILE_USE_MATRIX`, `MAIN_DISK_DEVICE`, `VAR_ALLOW_ROOT_DISK*` | опционально **`config/disk.env`** в клоне (из **`config/disk.env.example`**) или переменные окружения перед **`make start`** |

## Переменные окружения

Приоритет: **переменные окружения** (в т.ч. `sudo env KEY=…`) **>** строки в **`config/*.env`**. В git коммитятся только шаблоны **`config/*.example`**; рабочие **`config/*.env`** и **`disk.env`** на узле не коммитятся (**`.gitignore`**). Секреты в шаблоны не кладём.

### Файлы в `config/`

| Файл в репозитории (шаблон) | Рабочий файл после `make init` | Назначение |
|------|------|------------|
| [config/host.env.example](config/host.env.example) | `config/host.env` | `ENV`, `PULL_DIR`, `SKIP_ANSIBLE` |
| [config/repos.env.example](config/repos.env.example) | `config/repos.env` | `PUBLIC_REPO_URL`, `PUBLIC_REF`, `REPO_URL`, `REF` |
| [config/ssh.env.example](config/ssh.env.example) | `config/ssh.env` | `INFRA_SSH_KEY`, `INFRA_SSH_KEY_COMMENT`, `INFRA_SSH_SKIP_PROMPT` |
| [config/galaxy.env.example](config/galaxy.env.example) | `config/galaxy.env` | `GALAXY_*`, опционально `COLLECTIONS_REQ` |
| [config/disk.env.example](config/disk.env.example) | `config/disk.env` | Переопределения матрицы **`config/disk-profiles.sh`** |

Подробнее — [config/README.md](config/README.md).

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `ENV` | `ctl` | Окружение: `ctl`, `stage`, `prod` (экспортируется в **`make install-deps`**, повторно подставляется в подсказке про `make stage1`). |
| `REPO_URL` | в **`config/repos.env`** по умолчанию HTTPS на `github.com/…`; в шаге **40** такой URL приводится к **`git@github.com:…`**. Итоговый URL — тот же, что для `git clone`. Там же готовится deploy key для `git@…` / `ssh://…`. Другой хост или клон строго по HTTPS — задайте URL вручную (для HTTPS без конвертации нужны учётные данные git). |
| `REF` | `main` | Ветка, тег или коммит. |
| `PULL_DIR` | `/var/lib/infra/src` | Каталог клона; отсюда выполняется **`make install-deps`** и далее запускается `make stage1` вручную. |
| `SKIP_ANSIBLE` | `0` | При `1` — не клонировать репо и не запускать **`make install-deps`**. Подсказка в финале сообщит, что зависимости и stage1 нужно запустить вручную позже. |
| `GALAXY_INSTALL_TIMEOUT` | `300` | Таймаут `ansible-galaxy` (сек), передаётся в окружение **`make install-deps`**. |
| `GALAXY_DOWNLOAD_DIR` | `/var/lib/infra/galaxy-download` | Кэш скачанных коллекций (для целей приватного **Makefile**). |
| `GALAXY_INSTALL_RETRIES` | `5` | Число повторов сетевых шагов (окружение **`make install-deps`**). |
| `GALAXY_RETRY_SLEEP_SEC` | `10` | Пауза между повторами. |
| `COLLECTIONS_REQ` | *(не задано)* | Если задать, путь к `requirements.yml` для коллекций; иначе `PULL_DIR/collections/requirements.yml`. |
| `INFRA_SSH_KEY` | `/root/.ssh/id_ed25519_infra` | Ключ для `git@` / `ssh://`. |
| `INFRA_SSH_KEY_COMMENT` | `infra@repo` | Комментарий к ключу. |
| `INFRA_SSH_SKIP_PROMPT` | `0` | При `1` — не ждать Enter после показа публичного ключа. |
| `DISK_PROFILE_USE_MATRIX` | `1` | При `1` в шаге **20** матрица **`config/disk-profiles.sh`** подставляет **`ROOT_TARGET_G`**, **`VAR_SIZE_G`**, **`MINIO_SIZE_G`**, **`SWAP_SIZE_G`**, **`VAR_MIN_FREE_MIB`** по размеру диска, не перезаписывая переменные, уже заданные в **`config/disk.env`** или в окружении. При `0` — только **`config/disk.env`** (если есть) и **`apply_disk_defaults`**. |
| `MAIN_DISK_DEVICE` | *(пусто)* | Принудительно указать основной диск для расчёта профиля. |
| `VAR_ALLOW_ROOT_DISK` | `1` | Разрешить разметку на диске с корнем (разделы в хвосте или LV в VG root). При фактическом использовании — предупреждение и ожидание Enter. `0` — не трогать root-диск. |
| `VAR_ALLOW_ROOT_DISK_SKIP_PROMPT` | `0` | При `1` — не ждать Enter после предупреждения о разметке root-диска (автоматизация). |

Дополнительно для разметки дисков (в **`config/disk.env`** в клоне или в окружении; см. **`config/disk.env.example`**): `ROOT_TARGET_G`, `VAR_MIN_FREE_MIB`, `VAR_SIZE_G`, `SWAP_SIZE_G`, `MINIO_SIZE_G`, `VAR_DISK_DEVICE`, `MIN_MINIO_G` — раздел **«Шаг 20 — disk-storage»** ниже.

## `scripts/lib/load-env.sh`

Читает файлы **`config/host.env`**, **`config/repos.env`**, **`config/ssh.env`**, **`config/galaxy.env`**, **`config/disk.env`** по порядку; отсутствующий файл пропускается. Для каждого ключа выставляет значение только если переменная **ещё не задана** в окружении процесса (**переменные окружения побеждают** `config/`). Затем задаёт **`ENV_VALUE`** и **`REF_VALUE`** из **`ENV`** и **`REF`** (с запасными значениями `ctl` и `main`), **`PUBLIC_REF_VALUE`** из **`PUBLIC_REF`**. Преобразований URL здесь нет: приведение **`https://github.com/…`** к **`git@…`** выполняется в шаге **40** (`normalize_github_https_repo_url` в **`scripts/lib/common.sh`**). Пояснения к переменным — в **`config/*.env`** и в номерных скриптах **`scripts/NN-*.sh`**.

## Библиотека `scripts/lib/common.sh`

Подключается из `scripts/run-start.sh` после `load-env.sh`, до пошаговых сценариев. Содержит то, что используется **несколькими** шагами:

- Логирование: `log_info`, `log_warn`, `log_err`, `section`, `fail`.
- `has_cmd`, `dnf_install`, `git_repo` (git без интерактивного `credential.helper` для HTTPS — см. комментарий в начале файла).
- `normalize_github_https_repo_url` — GitHub HTTPS → `git@…` (вызывается из шага **40**).
- `distro_sync_system` — `dnf distro-sync -y`.

Остальная логика шагов — в файлах `scripts/NN-*.sh` (см. разделы ниже).

## Шаги сценария (порядок в `make start`)

В `make start` порядок совпадает с номерами скриптов: **10 → 20 → 30 → 40 → 50 → 70 → 90**. Диски и swap (**20**) идут до **`dnf install`** (**30**), чтобы уменьшить риск зависания из‑за нехватки RAM.

### Шаг 10 — `require-runtime`

**Файл:** `scripts/10-require-runtime.sh`  
**Функция:** `step_require_runtime`

Проверяет, что скрипт запущен от **root**, в системе есть **dnf**, и доступны утилиты: `lsblk`, `findmnt`, `awk`, `sed`, `blkid`, `mount`, `umount`.

При невыполнении условий вызывается `fail` с сообщением и ненулевым кодом выхода. Реализация: `require_runtime` в этом же файле.

### Шаг 20 — `disk-storage`

**Файл:** `scripts/20-disk-storage.sh`  
**Функция:** `step_disk_storage`

Последовательно:

1. **`resolve_main_disk` / `resolve_disk_size_group`** — определение основного диска и условной группы размера для профиля.
2. **`load_disk_profile`** — подстановка по матрице **`config/disk-profiles.sh`** (если не отключено **`DISK_PROFILE_USE_MATRIX=0`**): для дисков **2–20 GiB** в профиле **1 GiB** под swap, под корень **`DISK_SIZE_G − 1`**; значения, уже заданные в **`config/disk.env`** (через **`load-env.sh`**) или в окружении, матрица не перезаписывает.
3. **`apply_disk_defaults`** — значения по умолчанию для размеров и лимитов (то, что ещё не задано).
4. **`ensure_swap`** — при необходимости создание файла подкачки `/swapfile`.
5. **`expand_root_lv_if_needed`** — расширение root LV до **`ROOT_TARGET_G`** при LVM и наличии места в VG (growpart/pvresize при необходимости).
6. **`prepare_var_and_minio`** — перенос `/var` на отдельный раздел или LV и при необходимости создание `/minio` (при необходимости ставится **`parted`** через **`dnf`** — уже после swap).
7. **`expand_root_lv_consume_vg_free`** — если корень на LVM: **`lvextend -l +100%FREE`** для root LV и расширение ФС — весь **оставшийся** свободный объём в VG после шагов 5–6 добавляется к корню (отключить: **`ROOT_LV_FILL_VG_FREE=0`**).

Перед разметкой на диске с корнем при **`VAR_ALLOW_ROOT_DISK=1`** (значение по умолчанию) выводится предупреждение и ожидается Enter, если не задано **`VAR_ALLOW_ROOT_DISK_SKIP_PROMPT=1`** и stdin — TTY.

Параметры (в т.ч. `VAR_SIZE_G`, `MINIO_SIZE_G`) задаются в **`config/disk.env`**, матрице или через переменные окружения — см. таблицу **«Переменные окружения»** и раздел **«Переопределение матрицы дисков»** выше.

Детали реализации — в `scripts/20-disk-storage.sh`.

### Шаг 30 — `install-packages`

**Файл:** `scripts/30-install-packages.sh`  
**Функция:** `step_install_packages`

1. Устанавливает базовые пакеты через `dnf`:
   - при **`SKIP_ANSIBLE=1`**: `epel-release`, `git`, `curl`, `parted`;
   - иначе: `epel-release`, `git`, `curl`, `parted`, **`make`** (нужен для целей **`install-deps`** и фаз **`stage1`/`stage2`/`runtime`** приватного **Makefile**). **`ansible-core` из dnf не ставится** — единый контур: ansible-core и коллекции ставятся в приватном `.venv` из `config/constraints.txt` / `collections/requirements.yml`.

2. Выполняет **`dnf distro-sync -y`** — выравнивание версий установленных пакетов с репозиториями (в т.ч. после подключения EPEL).

Повторный `distro-sync` выполняется в конце цепочки в шаге **90 — finalize**.

### Шаг 40 — `ssh-deploy-key`

**Файл:** `scripts/40-ssh-deploy-key.sh`  
**Функция:** `step_ssh_deploy_key`

Сначала вызывается **`normalize_github_https_repo_url`** из **`scripts/lib/common.sh`**: если **`REPO_URL`** — **`https://`** или **`http://`** на **`github.com`** в форме **`/владелец/репозиторий`**, подставляется **`git@github.com:владелец/репозиторий.git`**; остальные URL не меняются.

Затем, если `REPO_URL` начинается с **`git@`** или **`ssh://`**, для доступа к приватному репозиторию создаётся ключ **`INFRA_SSH_KEY`** (ed25519), печатается публичная часть — её нужно добавить в **Deploy keys** (read-only) на GitHub/GitLab.

Пока ключ не добавлен, скрипт может ждать нажатия Enter (отключается **`INFRA_SSH_SKIP_PROMPT=1`**).

Если после нормализации **`REPO_URL`** остаётся **HTTPS** (другой хост или не `github.com`), создание ключа пропускается — нужны учётные данные git для HTTPS.

Реализация: `step_ssh_deploy_key` → `normalize_github_https_repo_url` (`common.sh`), затем `ensure_infra_deploy_key` в `scripts/40-ssh-deploy-key.sh`.

### Шаг 50 — `sync-repository`

**Файл:** `scripts/50-sync-repository.sh`  
**Функция:** `step_sync_repository`

При **`SKIP_ANSIBLE=1`** шаг пропускается (репозиторий не нужен для последующих шагов в этом режиме).

Иначе выполняется **`sync_repository`**: каталог `PULL_DIR` создаётся при необходимости; если репозиторий уже клонирован, обновляется `origin` на `REPO_URL`, выполняются `fetch` и `checkout` на `REF`; если нет — выполняется `git clone -b REF REPO_URL PULL_DIR`.

Используется обёртка `git_repo` без интерактивного запроса учётных данных для HTTPS.

Реализация: `sync_repository` в `scripts/50-sync-repository.sh`.

### Шаг 70 — `install-deps` (вызов `make install-deps`)

**Файл:** `scripts/70-install-deps.sh`  
**Функция:** `step_install_deps`

При **`SKIP_ANSIBLE=1`** пропускается.

Иначе после клона в **`PULL_DIR`** ожидается **`Makefile`** с целью **`install-deps`**. В каталоге клона выполняется:

```bash
cd PULL_DIR
make install-deps    # .venv из config/constraints.txt + коллекции Galaxy в collections/ansible_collections
```

Запуск **самих фаз** Ansible (`stage1`, `stage2`, `runtime`) на этом шаге **не делается**: пользователь запускает их вручную через `make stage1`/`make stage2`/`make runtime` в каталоге клона. В окружение `make install-deps` передаются **`REPO_URL`**, **`REF`**, **`ENV`**, **`PULL_DIR`**, а также **`GALAXY_*`** и при необходимости **`COLLECTIONS_REQ`** (по умолчанию `PULL_DIR/collections/requirements.yml`).

Если **`Makefile`** отсутствует, шаг завершается с ошибкой.

### Шаг 90 — `finalize`

**Файл:** `scripts/90-finalize.sh`  
**Функция:** `step_finalize`

1. Повторный **`dnf distro-sync -y`** после установки пакетов и цели **`make install-deps`**.
2. **`verify_critical_services`** — `sshd -t`, при необходимости проверка **NetworkManager**, если он включён (реализация в `scripts/90-finalize.sh`).
3. **`run_update_sysuser`** — в каталоге клона **`PULL_DIR`** вызывается **`make update-sysuser`** (интерактивно: имя и пароль администратора в `vars/all.yml` приватного репозитория). Требуется **`Makefile`** с этой целью.
4. **`print_next_step_hint`** — итоговая подсказка с готовой командой `cd ${PULL_DIR} && sudo make stage1 ENV=${ENV}` (с учётом `SKIP_ANSIBLE`). Дальше пользователь сам запускает фазы Ansible.

## Связь с приватным репозиторием

Точка входа на стороне приватного репозитория — **`Makefile`** с целями **`install-deps`** (Ansible Galaxy + venv), **`update-sysuser`** (интерактивная правка `vars/all.yml`; вызывается из шага **90** после `install-deps`), **`stage1`** / **`stage2`** / **`runtime`** (фазы единого `playbooks/site.yml`). Публичный bootstrap после клона в **`PULL_DIR`** выполняет **`make install-deps`**, затем на шаге **90** — **`make update-sysuser`**, передавая в окружение **`ENV`**, **`REPO_URL`**, **`REF`**, **`PULL_DIR`** (как и для `install-deps`). Сами фазы Ansible запускает пользователь:

```bash
sudo make stage1 ENV=...   # подскажет команду для stage2; при необходимости перезагрузит сервер
sudo make stage2 ENV=...   # подскажет команду для runtime
sudo make runtime ENV=...  # по необходимости (никаких таймеров и юнитов больше нет)
```

### Что править при изменении контракта

1. **Приватный репо:** цели **`install-deps`**, **`update-sysuser`**, **`stage1`**, **`stage2`**, **`runtime`** в **`Makefile`**, теги в **`playbooks/site.yml`**, использование переменных окружения.
2. **Публичный репо:** функция **`run_install_deps`** в **`scripts/70-install-deps.sh`** (список **`export`**), функция **`run_update_sysuser`** в **`scripts/90-finalize.sh`**, при изменении **`REPO_URL`** — **`normalize_github_https_repo_url`** в **`scripts/lib/common.sh`**, дефолт **`REPO_URL`** в **`config/repos.env`**, таблицы в этом **README**, текст подсказки в **`scripts/90-finalize.sh`**.
3. Сохраняйте согласованность имён: внешний интерфейс для **`make`** — **`REF`** и **`ENV`**, а не **`REF_VALUE`** / **`ENV_VALUE`** (последние — только внутри shell после **`load-env.sh`**).

### Комментарии в коде

В номерных файлах **`scripts/NN-*.sh`** перед функциями используются блоки в духе **JSDoc**: краткое описание, теги **`@param`** (аргументы **`$1`**, …), **`@globals`**, при необходимости **`@stdout`** / **`@return`** / **`@exit`**. Это упрощает навигацию по длинному шагу **40** и единообразно документирует остальные шаги.

Подробные пояснения по сценарию находятся в:

- **`scripts/run-start.sh`** — порядок шагов и ограничения запуска;
- **`config/`**, **`scripts/lib/load-env.sh`** — модульный конфиг и загрузка переменных;
- **`scripts/lib/common.sh`** — **`git_repo`**, **`normalize_github_https_repo_url`**, **`dnf_install`**;
- **`scripts/10-require-runtime.sh`** … **`scripts/50-sync-repository.sh`** — шапка файла и JSDoc у **`step_*`** и вспомогательных функций;
- **`scripts/20-disk-storage.sh`** — шапка файла и JSDoc у каждой функции (включая вложенную **`pick_disk`**);
- **`scripts/70-install-deps.sh`** — контракт **`make install-deps`**, JSDoc у **`run_install_deps`** / **`step_install_deps`**;
- **`scripts/90-finalize.sh`** — `verify_critical_services`, `run_update_sysuser` (`make update-sysuser`) и `print_next_step_hint` (итоговая подсказка про `make stage1`).
