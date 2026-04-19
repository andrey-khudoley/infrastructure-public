# Скрипты первичной настройки хоста (bootstrap)

**Репозиторий:** [https://github.com/andrey-khudoley/infrastructure-public.git](https://github.com/andrey-khudoley/infrastructure-public.git)

Репозиторий содержит цепочку shell-скриптов для подготовки **dnf**-системы под инфраструктурный Ansible: пакеты, диски и swap, клон **приватного** репозитория с плейбуками и запуск в каталоге клона двух целей **`Makefile`** — сначала **`make install-deps`** (коллекции Ansible Galaxy), затем **`make bootstrap`** (фаза `stage1` единого `playbooks/site.yml`).

## Роль репозиториев

| Репозиторий | Роль |
|-------------|------|
| **Этот (public)** | Подготовка хоста: пакеты, диски; шаг **30** при необходимости приводит **`REPO_URL`** с **`github.com`** по HTTPS к **`git@…`** и готовит deploy key; иначе задайте SSH-URL сами; клон в `PULL_DIR`, **`make install-deps`** + **`make bootstrap`**, `distro-sync` и проверки. |
| **Приватный** | Вся прикладная Ansible-логика: единый `playbooks/site.yml` с фазами `stage1` → `stage2` → `runtime` и **`Makefile`** с целями **`install-deps`**, **`bootstrap`** (= `stage1`), **`stage2`**, **`runtime`** и другими. |

Публичный сценарий **не** дублирует содержимое приватного **`Makefile`**: он только гарантирует окружение и вызывает **`make install-deps`** + **`make bootstrap`** с согласованным набором переменных (см. раздел **«Контракт: переменные для `make install-deps` и `make bootstrap`»**).

## Алгоритм вызова

1. **Склонировать этот репозиторий целиком** (нужны `start.sh` и каталог `scripts/` с библиотеками и шагами; одного `start.sh` недостаточно).
2. **Перейти в корень клона** — туда, где лежат `start.sh` и `scripts/`. При необходимости отредактировать **`.env`** в корне (единственный файл настроек: `ENV`, `REPO_URL`, `REF` и остальное из таблицы ниже).
3. **Запустить оркестратор от root** с переменными окружения (ниже примеры). Удобно: `sudo bash` или `sudo env … bash start.sh`.

Минимальный пример с **дефолтами из `.env`** (ветка `main`, окружение `stage`; **`REPO_URL`** по умолчанию — HTTPS на GitHub, в шаге **30** он приводится к **`git@github.com:…`**, затем выводится deploy key — добавьте его в репозиторий на GitHub):

```bash
git clone https://github.com/andrey-khudoley/infrastructure-public.git
cd infrastructure-public
sudo env ENV=stage REF=main bash start.sh
```

Типичный вариант для **приватного** репо на GitHub **без** токена в URL — явный **`git@…`** и deploy key (шаг **30** создаст ключ и покажет публичную часть):

```bash
sudo env ENV=stage REF=main REPO_URL=git@github.com:andrey-khudoley/infrastructure-private.git bash start.sh
```

Запуск **только** через `curl …/start.sh | bash` **не поддерживается**: `start.sh` вычисляет корень по пути к себе и подключает файлы из `scripts/`; при выполнении скрипта со stdin путь к каталогу с репозиторием не определяется, а без остальных файлов цепочка не работает.

## Точка входа

Единственный сценарий верхнего уровня — **`start.sh`**: последовательно подключает шаги из `scripts/` и вызывает функции `step_*`. Порядок шагов и назначение задокументированы в **комментариях в начале `start.sh`**. Все примеры ниже предполагают запуск **от root** (или через `sudo bash`).

### Контракт: переменные для `make install-deps` и `make bootstrap`

После успешного клона в **`PULL_DIR`** выполняются две цели:

```
make -C "${PULL_DIR}" install-deps
make -C "${PULL_DIR}" bootstrap
```

`install-deps` устанавливает коллекции Galaxy (офлайн-кэш + `--offline`), `bootstrap` — алиас для фазы `stage1` единого `playbooks/site.yml` (эквивалент: `ansible-playbook playbooks/site.yml --tags stage1 -e env="${ENV}"`). Дальнейшие фазы (`stage2`, `runtime`) активируются уже на стороне узла через systemd-таймеры, которые ставятся задачами роли `bootstrap`.

В процесс **make** передаётся такое окружение (имена переменных — часть контракта с приватным репозиторием):

| Переменная | Источник | Назначение |
|------------|----------|------------|
| `REPO_URL` | **`.env`** (если не переопределён окружением) | URL приватного репозитория (тот же, что для `git clone`). |
| `REF` | значение **`REF_VALUE`** (из `REF=…` при запуске и/или из **`.env`**) | Ветка, тег или коммит; в скриптах после **`load-env.sh`** хранится как **`REF_VALUE`**, в **export** для **`make`** — имя **`REF`**, как ожидает приватный **Makefile**. |
| `ENV` | значение **`ENV_VALUE`** (из `ENV` при запуске) | Логическое окружение (`ctl`, `stage`, `prod`); выбирает `vars/{{ env }}.yml` на стороне приватного репо. |
| `PULL_DIR` | абсолютный путь к клону | Рабочий каталог клона; совпадает с каталогом, из которого выполняются цели make. |
| `GALAXY_*` | см. таблицу ниже | Таймауты, ретраи и каталог кэша для `scripts/galaxy-offline-install.sh` (используется целью `install-deps`). |
| `COLLECTIONS_REQ` | переменная окружения или по умолчанию `PULL_DIR/collections/requirements.yml` | Путь к `requirements.yml` коллекций. |

Приватный **`Makefile`** может не использовать часть переменных — это нормально; публичный bootstrap всё равно их выставляет для единообразия и обратной совместимости.

### Репозиторий и окружение Ansible

Базовый запуск: ветка `main`, окружение `stage`, **`REPO_URL`** из **`.env`** (HTTPS на `github.com` обрабатывается в начале шага **30**). Для другого хоста (не `github.com`) или нестандартного URL задайте **`REPO_URL`** сразу как **`git@…`** или **`ssh://…`** (см. шаг **30**):

```bash
ENV=stage REF=main bash start.sh
```

Тот же сценарий с явным SSH-URL:

```bash
ENV=stage REF=main REPO_URL=git@github.com:andrey-khudoley/infrastructure-private.git bash start.sh
```

Production и фиксированный релиз (тег вместо ветки):

```bash
ENV=prod REF=v1.2.0 REPO_URL=git@github.com:andrey-khudoley/infrastructure-private.git bash start.sh
```

Control-узел с веткой по умолчанию (`ENV` по умолчанию — `ctl`):

```bash
REF=main REPO_URL=git@github.com:andrey-khudoley/infrastructure-private.git bash start.sh
```

Другой каталог клона (не `/var/lib/infra/src`):

```bash
PULL_DIR=/opt/infra/src ENV=stage REF=main REPO_URL=git@github.com:andrey-khudoley/infrastructure-private.git bash start.sh
```

### Без Ansible (только ОС, диски, пакеты)

Полезно для проверки разметки дисков без клона и без **`make install-deps`** / **`make bootstrap`** в приватном репо:

```bash
SKIP_ANSIBLE=1 bash start.sh
```

С теми же переменными, что и для полного прогона (для согласованности профиля дисков), но без клона:

```bash
SKIP_ANSIBLE=1 ENV=stage REPO_URL=git@github.com:andrey-khudoley/infrastructure-private.git bash start.sh
```

### Диски: `/var`, `/minio`, LVM

Выделение `/var` и при необходимости `/minio` из свободного места в VG на том же диске, что и root (нужно явное разрешение):

```bash
VAR_ALLOW_ROOT_DISK=1 ENV=stage REPO_URL=git@github.com:andrey-khudoley/infrastructure-private.git bash start.sh
```

### SSH deploy key и автоматизация

После первого показа ключа скрипт ждёт Enter. Для CI/автоматизации, когда ключ уже добавлен в GitHub:

```bash
INFRA_SSH_SKIP_PROMPT=1 ENV=stage REPO_URL=git@github.com:andrey-khudoley/infrastructure-private.git bash start.sh
```

Для приватного GitHub по HTTPS без токена используйте **`git@...`** или `ssh://` и deploy key (см. раздел **«Шаг 30 — ssh-deploy-key»** ниже).

### Galaxy и медленная сеть

Переменные **`GALAXY_*`** и **`COLLECTIONS_REQ`** передаются в окружение процессов **`make install-deps`** и **`make bootstrap`** (используются в `scripts/galaxy-offline-install.sh` из приватного репо). Увеличить таймаут и число повторов:

```bash
GALAXY_INSTALL_TIMEOUT=600 GALAXY_INSTALL_RETRIES=10 GALAXY_RETRY_SLEEP_SEC=15 \
  ENV=stage REPO_URL=git@github.com:andrey-khudoley/infrastructure-private.git bash start.sh
```

Другой каталог кэша коллекций:

```bash
GALAXY_DOWNLOAD_DIR=/var/lib/infra/galaxy-cache \
  ENV=stage REPO_URL=git@github.com:andrey-khudoley/infrastructure-private.git bash start.sh
```

Нестандартный путь к `requirements.yml` коллекций в клоне (редко):

```bash
COLLECTIONS_REQ=/var/lib/infra/src/collections/requirements.yml \
  ENV=stage REPO_URL=git@github.com:andrey-khudoley/infrastructure-private.git bash start.sh
```

### Профиль дисков из файла

Локальный профиль уже лежит на машине:

```bash
DISK_VARS_FILE=/etc/infra/bootstrap-disk.env \
  ENV=stage REPO_URL=git@github.com:andrey-khudoley/infrastructure-private.git bash start.sh
```

Явно указать блочное устройство для расчёта профиля:

```bash
MAIN_DISK_DEVICE=/dev/sda ENV=stage REPO_URL=git@github.com:andrey-khudoley/infrastructure-private.git bash start.sh
```

## Структура репозитория

```
├── README.md
├── .env                     # обязательный файл настроек (коммитится; см. комментарии в файле)
├── start.sh                 # оркестратор: комментарии в шапке; source lib и scripts/NN-*.sh; step_*()
├── scripts/
│   ├── lib/
│   │   ├── load-env.sh      # обязательный корневой .env; нормализация ENV_VALUE/REF_VALUE
│   │   └── common.sh        # логирование, dnf, git, distro-sync (общее для шагов)
│   ├── 10-require-runtime.sh
│   ├── 20-install-packages.sh
│   ├── 30-ssh-deploy-key.sh
│   ├── 40-disk-storage.sh
│   ├── 50-sync-repository.sh
│   ├── 70-ansible-pull-stage1.sh   # make install-deps + make bootstrap в PULL_DIR
│   └── 90-finalize.sh
```

## Переменные окружения

Приоритет: **переменные окружения** (в т.ч. `sudo env KEY=…`) **>** строки в **`.env`** в корне клона. Файл **`.env`** обязателен (входит в репозиторий); секреты туда не кладём.

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `ENV` | `ctl` | Окружение: `ctl`, `stage`, `prod` (экспортируется в **`make install-deps`** / **`make bootstrap`**). |
| `REPO_URL` | в **`.env`** по умолчанию HTTPS на `github.com/…`; в шаге **30** такой URL приводится к **`git@github.com:…`**. Итоговый URL — тот же, что для `git clone`. Там же готовится deploy key для `git@…` / `ssh://…`. Другой хост или клон строго по HTTPS — задайте URL вручную (для HTTPS без конвертации нужны учётные данные git). |
| `REF` | `main` | Ветка, тег или коммит. |
| `PULL_DIR` | `/var/lib/infra/src` | Каталог клона; отсюда выполняются **`make install-deps`** и **`make bootstrap`**. |
| `SKIP_ANSIBLE` | `0` | При `1` — не клонировать репо, не запускать **`make install-deps`** / **`make bootstrap`**. |
| `GALAXY_INSTALL_TIMEOUT` | `300` | Таймаут `ansible-galaxy` (сек), передаётся в окружение **`make install-deps`**. |
| `GALAXY_DOWNLOAD_DIR` | `/var/lib/infra/galaxy-download` | Кэш скачанных коллекций (для целей приватного **Makefile**). |
| `GALAXY_INSTALL_RETRIES` | `5` | Число повторов сетевых шагов (окружение **`make install-deps`**). |
| `GALAXY_RETRY_SLEEP_SEC` | `10` | Пауза между повторами. |
| `COLLECTIONS_REQ` | *(не задано)* | Если задать, путь к `requirements.yml` для коллекций; иначе `PULL_DIR/collections/requirements.yml`. |
| `INFRA_SSH_KEY` | `/root/.ssh/id_ed25519_infra` | Ключ для `git@` / `ssh://`. |
| `INFRA_SSH_KEY_COMMENT` | `infra@repo` | Комментарий к ключу. |
| `INFRA_SSH_SKIP_PROMPT` | `0` | При `1` — не ждать Enter после показа публичного ключа. |
| `DISK_VARS_FILE` | `/etc/infra/bootstrap-disk.env` | Локальный профиль дисков. |
| `DISK_VARS_REPO_PATH` | `bootstrap-disk.env` | Путь к файлу профиля внутри репозитория. |
| `DISK_PROFILE_FETCH_FROM_REPO` | `1` | Подтянуть профиль дисков из репо, если локального файла нет. |
| `MAIN_DISK_DEVICE` | *(пусто)* | Принудительно указать основной диск для расчёта профиля. |

Дополнительно для разметки дисков (часто задаются в `bootstrap-disk.env`): `ROOT_TARGET_G`, `VAR_MIN_FREE_MIB`, `VAR_SIZE_G`, `SWAP_SIZE_G`, `MINIO_SIZE_G`, `VAR_ALLOW_ROOT_DISK`, `VAR_DISK_DEVICE`, `MIN_MINIO_G` — см. раздел **«Шаг 40 — disk-storage»** ниже.

## `scripts/lib/load-env.sh`

Читает обязательный корневой **`.env`** и выставляет только те переменные, которые ещё не заданы в окружении процесса. Затем задаёт **`ENV_VALUE`** и **`REF_VALUE`** из **`ENV`** и **`REF`** (с запасными значениями `ctl` и `main`). Преобразований URL здесь нет: приведение **`https://github.com/…`** к **`git@…`** выполняется в шаге **30** (`normalize_github_https_repo_url` в **`scripts/lib/common.sh`**). Пояснения к переменным и шагам — в комментариях в **`.env`** и в номерных скриптах **`scripts/NN-*.sh`**.

## Библиотека `scripts/lib/common.sh`

Подключается из `start.sh` после `load-env.sh`, до пошаговых сценариев. Содержит то, что используется **несколькими** шагами:

- Логирование: `log_info`, `log_warn`, `log_err`, `section`, `fail`.
- `has_cmd`, `dnf_install`, `git_repo` (git без интерактивного `credential.helper` для HTTPS — см. комментарий в начале файла).
- `normalize_github_https_repo_url` — GitHub HTTPS → `git@…` (вызывается из шага **30**).
- `distro_sync_system` — `dnf distro-sync -y`.

Остальная логика шагов — в файлах `scripts/NN-*.sh` (см. разделы ниже).

## Шаги сценария (порядок в `start.sh`)

### Шаг 10 — `require-runtime`

**Файл:** `scripts/10-require-runtime.sh`  
**Функция:** `step_require_runtime`

Проверяет, что скрипт запущен от **root**, в системе есть **dnf**, и доступны утилиты: `lsblk`, `findmnt`, `awk`, `sed`, `blkid`, `mount`, `umount`.

При невыполнении условий вызывается `fail` с сообщением и ненулевым кодом выхода. Реализация: `require_runtime` в этом же файле.

### Шаг 20 — `install-packages`

**Файл:** `scripts/20-install-packages.sh`  
**Функция:** `step_install_packages`

1. Устанавливает базовые пакеты через `dnf`:
   - при **`SKIP_ANSIBLE=1`**: `epel-release`, `git`, `curl`, `parted`;
   - иначе: `epel-release`, `git`, `curl`, `ansible-core`, `parted`, **`make`** (нужен для целей **`install-deps`** и **`bootstrap`** приватного **Makefile**).

2. Выполняет **`dnf distro-sync -y`** — выравнивание версий установленных пакетов с репозиториями (в т.ч. после подключения EPEL).

Повторный `distro-sync` выполняется в конце цепочки в шаге **90 — finalize**.

### Шаг 30 — `ssh-deploy-key`

**Файл:** `scripts/30-ssh-deploy-key.sh`  
**Функция:** `step_ssh_deploy_key`

Сначала вызывается **`normalize_github_https_repo_url`** из **`scripts/lib/common.sh`**: если **`REPO_URL`** — **`https://`** или **`http://`** на **`github.com`** в форме **`/владелец/репозиторий`**, подставляется **`git@github.com:владелец/репозиторий.git`**; остальные URL не меняются.

Затем, если `REPO_URL` начинается с **`git@`** или **`ssh://`**, для доступа к приватному репозиторию создаётся ключ **`INFRA_SSH_KEY`** (ed25519), печатается публичная часть — её нужно добавить в **Deploy keys** (read-only) на GitHub/GitLab.

Пока ключ не добавлен, скрипт может ждать нажатия Enter (отключается **`INFRA_SSH_SKIP_PROMPT=1`**).

Если после нормализации **`REPO_URL`** остаётся **HTTPS** (другой хост или не `github.com`), создание ключа пропускается — нужны учётные данные git для HTTPS.

Реализация: `step_ssh_deploy_key` → `normalize_github_https_repo_url` (`common.sh`), затем `ensure_infra_deploy_key` в `scripts/30-ssh-deploy-key.sh`.

### Шаг 40 — `disk-storage`

**Файл:** `scripts/40-disk-storage.sh`  
**Функция:** `step_disk_storage`

Последовательно:

1. **`resolve_main_disk` / `resolve_disk_size_group`** — определение основного диска и условной группы размера для профиля.
2. **`load_disk_profile`** — загрузка параметров из `DISK_VARS_FILE` или однократного shallow-клона репозитория для файла `DISK_VARS_REPO_PATH`.
3. **`apply_disk_defaults`** — значения по умолчанию для размеров и лимитов.
4. **`ensure_swap`** — при необходимости создание файла подкачки `/swapfile`.
5. **`expand_root_lv_if_needed`** — расширение root LV при LVM и свободном месте.
6. **`prepare_var_and_minio`** — перенос `/var` на отдельный раздел или LV и при необходимости создание `/minio`.

Параметры (в т.ч. `VAR_ALLOW_ROOT_DISK`, `VAR_SIZE_G`, `MINIO_SIZE_G`) задаются в профиле дисков или через переменные окружения — см. таблицу **«Переменные окружения»** выше.

Детали реализации — в `scripts/40-disk-storage.sh`.

### Шаг 50 — `sync-repository`

**Файл:** `scripts/50-sync-repository.sh`  
**Функция:** `step_sync_repository`

При **`SKIP_ANSIBLE=1`** шаг пропускается (репозиторий не нужен для последующих шагов в этом режиме).

Иначе выполняется **`sync_repository`**: каталог `PULL_DIR` создаётся при необходимости; если репозиторий уже клонирован, обновляется `origin` на `REPO_URL`, выполняются `fetch` и `checkout` на `REF`; если нет — выполняется `git clone -b REF REPO_URL PULL_DIR`.

Используется обёртка `git_repo` без интерактивного запроса учётных данных для HTTPS.

Реализация: `sync_repository` в `scripts/50-sync-repository.sh`.

### Шаг 70 — `ansible-pull-stage1` (вызов `make install-deps` + `make bootstrap`)

**Файл:** `scripts/70-ansible-pull-stage1.sh`  
**Функция:** `step_ansible_pull_stage1`

Имя файла историческое (раньше здесь вызывался другой сценарий); фактически в каталоге клона последовательно выполняются две цели Make — **`install-deps`** и **`bootstrap`**. Подробные комментарии — в **начале `scripts/70-ansible-pull-stage1.sh`** (контракт с приватным репо, зачем subshell, почему **`REF`** в export берётся из **`REF_VALUE`**).

При **`SKIP_ANSIBLE=1`** пропускается.

Иначе после клона в **`PULL_DIR`** ожидается **`Makefile`** с целями **`install-deps`** и **`bootstrap`**. В каталоге клона выполняется:

```bash
cd PULL_DIR
make install-deps    # коллекции Ansible Galaxy (офлайн-кэш)
make bootstrap       # stage1 единого playbooks/site.yml
```

В окружение процесса передаются **`REPO_URL`**, **`REF`**, **`ENV`**, **`PULL_DIR`**, а также **`GALAXY_*`** и при необходимости **`COLLECTIONS_REQ`** (по умолчанию `PULL_DIR/collections/requirements.yml`), чтобы приватный **Makefile** мог установить коллекции и запустить `playbooks/site.yml --tags stage1`. Полный перечень и смысл — в разделе **«Контракт: переменные для `make install-deps` и `make bootstrap`»** выше.

Если **`Makefile`** отсутствует, шаг завершается с ошибкой.

### Шаг 90 — `finalize`

**Файл:** `scripts/90-finalize.sh`  
**Функция:** `step_finalize`

1. Повторный **`dnf distro-sync -y`** после установки пакетов и целей **`make install-deps`** / **`make bootstrap`**.
2. **`verify_critical_services`** — `sshd -t`, при необходимости проверка **NetworkManager**, если он включён (реализация в `scripts/90-finalize.sh`).

Выводится итоговое сообщение: с `SKIP_ANSIBLE=1` или после полного прохода.

## Связь с приватным репозиторием

Точка входа на стороне приватного репозитория — **`Makefile`** с целями **`install-deps`** (коллекции Ansible Galaxy) и **`bootstrap`** (алиас для фазы `stage1` единого `playbooks/site.yml`). Публичный bootstrap после клона в **`PULL_DIR`** последовательно выполняет **`make install-deps`** и **`make bootstrap`**, передавая в окружение **`ENV`**, **`REPO_URL`**, **`REF`**, **`PULL_DIR`** и при необходимости **`GALAXY_*`** / **`COLLECTIONS_REQ`**. Дальнейшие фазы (`stage2`, `runtime`) активируются на стороне узла через systemd-таймеры, которые ставятся ролью `bootstrap`.

### Что править при изменении контракта

1. **Приватный репо:** цели **`install-deps`** и **`bootstrap`** в **`Makefile`**, теги в **`playbooks/site.yml`**, использование переменных окружения.
2. **Публичный репо:** функция **`run_stage1_ansible_pull`** в **`scripts/70-ansible-pull-stage1.sh`** (список **`export`** и последовательность `make`-целей), при изменении **`REPO_URL`** — **`normalize_github_https_repo_url`** в **`scripts/lib/common.sh`**, дефолт **`REPO_URL`** в **`.env`**, таблицы в этом **README**.
3. Сохраняйте согласованность имён: внешний интерфейс для **`make`** — **`REF`** и **`ENV`**, а не **`REF_VALUE`** / **`ENV_VALUE`** (последние — только внутри shell после **`load-env.sh`**).

### Комментарии в коде

В номерных файлах **`scripts/NN-*.sh`** перед функциями используются блоки в духе **JSDoc**: краткое описание, теги **`@param`** (аргументы **`$1`**, …), **`@globals`**, при необходимости **`@stdout`** / **`@return`** / **`@exit`**. Это упрощает навигацию по длинному шагу **40** и единообразно документирует остальные шаги.

Подробные пояснения по сценарию находятся в:

- **`start.sh`** — порядок шагов и ограничения запуска;
- **`.env`**, **`scripts/lib/load-env.sh`** — корневой конфиг и загрузка переменных;
- **`scripts/lib/common.sh`** — **`git_repo`**, **`normalize_github_https_repo_url`**, **`dnf_install`**;
- **`scripts/10-require-runtime.sh`** … **`scripts/50-sync-repository.sh`**, **`scripts/90-finalize.sh`** — шапка файла и JSDoc у **`step_*`** и вспомогательных функций;
- **`scripts/40-disk-storage.sh`** — шапка файла и JSDoc у каждой функции (включая вложенную **`pick_disk`**);
- **`scripts/70-ansible-pull-stage1.sh`** — контракт **`make install-deps`** + **`make bootstrap`**, связка **`REF`** / **`REF_VALUE`**, историческое имя файла, JSDoc у **`run_stage1_ansible_pull`** / **`step_ansible_pull_stage1`**.
