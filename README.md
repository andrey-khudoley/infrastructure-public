# Скрипты первичной настройки хоста (bootstrap)

**Репозиторий:** [https://github.com/andrey-khudoley/infrastructure-public.git](https://github.com/andrey-khudoley/infrastructure-public.git)

Репозиторий содержит цепочку shell-скриптов для подготовки **dnf**-системы под инфраструктурный Ansible: пакеты, диски и swap, клон **приватного** репозитория с плейбуками и установка зависимостей Ansible (Python `.venv` из `constraints.txt` + коллекции Galaxy в `collections/ansible_collections`). Единый контур версий: **никаких** параллельных установок ansible-core из dnf.

Запуск самих фаз `stage1` → `stage2` → `runtime` — это **отдельные ручные шаги** на стороне приватного репозитория (`make stage1`, затем `make stage2`, затем при необходимости `make runtime`). Никаких systemd-юнитов и автоматических переходов между фазами bootstrap **не используется**: `start.sh` лишь готовит хост и в конце печатает подсказку с командой запуска `stage1`.

## Роль репозиториев

| Репозиторий | Роль |
|-------------|------|
| **Этот (public)** | Подготовка хоста: пакеты, диски; шаг **30** при необходимости приводит **`REPO_URL`** с **`github.com`** по HTTPS к **`git@…`** и готовит deploy key; иначе задайте SSH-URL сами; клон в `PULL_DIR`, **`make install-deps`** в каталоге клона, `distro-sync` и проверки. В конце — подсказка с командой `make stage1`. |
| **Приватный** | Вся прикладная Ansible-логика: единый `playbooks/site.yml` с фазами `stage1` → `stage2` → `runtime` и **`Makefile`** с целями **`install-deps`**, **`stage1`**, **`stage2`**, **`runtime`** и другими. Запуск каждой фазы — вручную. |

Публичный сценарий **не** дублирует содержимое приватного **`Makefile`**: он только гарантирует окружение и вызывает **`make install-deps`** с согласованным набором переменных (см. раздел **«Контракт: переменные для `make install-deps`»**). Запуск `make stage1` — за пользователем.

## Алгоритм вызова

1. **Склонировать этот репозиторий целиком** (нужны `start.sh` и каталог `scripts/` с библиотеками и шагами; одного `start.sh` недостаточно).
2. **Перейти в корень клона** — туда, где лежат `start.sh` и `scripts/`. При необходимости отредактировать **`.env`** в корне (единственный файл настроек: `ENV`, `REPO_URL`, `REF` и остальное из таблицы ниже).
3. **Запустить оркестратор от root** с переменными окружения (ниже примеры). Удобно: `sudo bash` или `sudo env … bash start.sh`.
4. После завершения `start.sh` напечатает подсказку — вручную выполнить `cd $PULL_DIR && sudo make stage1 ENV=$ENV`.
5. По окончании `make stage1` будет напечатана подсказка про `make stage2` (если `stage1` потребовал ребут — после загрузки выполнить `make stage2` вручную).
6. Аналогично после `make stage2` появится подсказка про `make runtime` (запускается по необходимости — никаких таймеров).

Минимальный пример с **дефолтами из `.env`** (ветка `main`, окружение `stage`; **`REPO_URL`** по умолчанию — HTTPS на GitHub, в шаге **30** он приводится к **`git@github.com:…`**, затем выводится deploy key — добавьте его в репозиторий на GitHub):

```bash
git clone https://github.com/andrey-khudoley/infrastructure-public.git
cd infrastructure-public
sudo env ENV=stage REF=main bash start.sh
# по окончании:
cd /var/lib/infra/src        # PULL_DIR из .env
sudo make stage1 ENV=stage   # после успеха — подсказка про stage2 (или ребут)
sudo make stage2 ENV=stage   # после успеха — подсказка про runtime
sudo make runtime ENV=stage  # по необходимости
```

Типичный вариант для **приватного** репо на GitHub **без** токена в URL — явный **`git@…`** и deploy key (шаг **30** создаст ключ и покажет публичную часть):

```bash
sudo env ENV=stage REF=main REPO_URL=git@github.com:andrey-khudoley/infrastructure-private.git bash start.sh
```

Запуск **только** через `curl …/start.sh | bash` **не поддерживается**: `start.sh` вычисляет корень по пути к себе и подключает файлы из `scripts/`; при выполнении скрипта со stdin путь к каталогу с репозиторием не определяется, а без остальных файлов цепочка не работает.

## Точка входа

Единственный сценарий верхнего уровня — **`start.sh`**: последовательно подключает шаги из `scripts/` и вызывает функции `step_*`. Порядок шагов и назначение задокументированы в **комментариях в начале `start.sh`**. Все примеры ниже предполагают запуск **от root** (или через `sudo bash`).

### Контракт: переменные для `make install-deps`

После успешного клона в **`PULL_DIR`** выполняется только подготовка зависимостей:

```
make -C "${PULL_DIR}" install-deps
```

`install-deps` сначала создаёт `.venv` и ставит из `constraints.txt` закреплённый `ansible-core` и Python-зависимости (`scripts/install-python-deps.sh`), затем устанавливает коллекции Galaxy (офлайн-кэш + `--offline`) в repo-local путь `collections/ansible_collections`. **Сам `ansible-playbook` `start.sh` не запускает** — фазы `stage1`, `stage2`, `runtime` инициирует пользователь вручную через `make stage1`/`make stage2`/`make runtime` уже в каталоге клона.

В процесс **make** передаётся такое окружение (имена переменных — часть контракта с приватным репозиторием):

| Переменная | Источник | Назначение |
|------------|----------|------------|
| `REPO_URL` | **`.env`** (если не переопределён окружением) | URL приватного репозитория (тот же, что для `git clone`). |
| `REF` | значение **`REF_VALUE`** (из `REF=…` при запуске и/или из **`.env`**) | Ветка, тег или коммит; в скриптах после **`load-env.sh`** хранится как **`REF_VALUE`**, в **export** для **`make`** — имя **`REF`**, как ожидает приватный **Makefile**. |
| `ENV` | значение **`ENV_VALUE`** (из `ENV` при запуске) | Логическое окружение (`ctl`, `stage`, `prod`); выбирает `vars/{{ env }}.yml` на стороне приватного репо. |
| `PULL_DIR` | абсолютный путь к клону | Рабочий каталог клона; совпадает с каталогом, из которого выполняется `make install-deps`. |
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

Полезно для проверки разметки дисков без клона и без **`make install-deps`** в приватном репо:

```bash
SKIP_ANSIBLE=1 bash start.sh
```

С теми же переменными, что и для полного прогона (для согласованности профиля дисков), но без клона:

```bash
SKIP_ANSIBLE=1 ENV=stage REPO_URL=git@github.com:andrey-khudoley/infrastructure-private.git bash start.sh
```

### Диски: `/var`, `/minio`, LVM

По умолчанию разрешена разметка на диске с root (**`VAR_ALLOW_ROOT_DISK=1`**). Перед созданием разделов или LV на этом диске скрипт выводит предупреждение и ждёт нажатия Enter. Отключить (только отдельные диски): **`VAR_ALLOW_ROOT_DISK=0`**. Для CI и неинтерактивного запуска: **`VAR_ALLOW_ROOT_DISK_SKIP_PROMPT=1`**.

```bash
ENV=stage REPO_URL=git@github.com:andrey-khudoley/infrastructure-private.git bash start.sh
```

### SSH deploy key и автоматизация

После первого показа ключа скрипт ждёт Enter. Для CI/автоматизации, когда ключ уже добавлен в GitHub:

```bash
INFRA_SSH_SKIP_PROMPT=1 ENV=stage REPO_URL=git@github.com:andrey-khudoley/infrastructure-private.git bash start.sh
```

Для приватного GitHub по HTTPS без токена используйте **`git@...`** или `ssh://` и deploy key (см. раздел **«Шаг 30 — ssh-deploy-key»** ниже).

### Galaxy и медленная сеть

Переменные **`GALAXY_*`** и **`COLLECTIONS_REQ`** передаются в окружение процесса **`make install-deps`** (используются в `scripts/galaxy-offline-install.sh` из приватного репо). Увеличить таймаут и число повторов:

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

## Обновление кода на уже настроенном узле

Если **infrastructure-public** уже склонирован рядом с клоном приватного репо (тот же `.env` и `PULL_DIR`):

```bash
cd /путь/к/infrastructure-public
sudo bash update.sh
```

Скрипт выполнит `git pull` / синхронизацию публичного клона и **приватного** (`PULL_DIR` из `.env`), без установки каких-либо systemd-юнитов. В конце напечатает подсказку: в корне **приватного** клона вручную запустить `sudo make runtime ENV=…` (и при необходимости снова `make stage1` / `make stage2`). Конфиг — тот же корневой `.env` (см. `scripts/lib/load-env.sh`).

## Структура репозитория

```
├── README.md
├── .env                     # обязательный файл настроек (коммитится; см. комментарии в файле)
├── start.sh                 # оркестратор: комментарии в шапке; source lib и scripts/NN-*.sh; step_*()
├── update.sh                # обновить оба клона (git); дальше вручную `make runtime` в приватном
├── scripts/
│   ├── lib/
│   │   ├── load-env.sh      # обязательный корневой .env; нормализация ENV_VALUE/REF_VALUE
│   │   └── common.sh        # логирование, dnf, git, distro-sync (общее для шагов)
│   ├── 10-require-runtime.sh
│   ├── 20-install-packages.sh
│   ├── 30-ssh-deploy-key.sh
│   ├── 40-disk-storage.sh
│   ├── 50-sync-repository.sh
│   ├── 70-install-deps.sh   # make install-deps в PULL_DIR (без stage1)
│   └── 90-finalize.sh       # distro-sync, проверки и подсказка про make stage1
```

## Переменные окружения

Приоритет: **переменные окружения** (в т.ч. `sudo env KEY=…`) **>** строки в **`.env`** в корне клона. Файл **`.env`** обязателен (входит в репозиторий); секреты туда не кладём.

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `ENV` | `ctl` | Окружение: `ctl`, `stage`, `prod` (экспортируется в **`make install-deps`**, повторно подставляется в подсказке про `make stage1`). |
| `REPO_URL` | в **`.env`** по умолчанию HTTPS на `github.com/…`; в шаге **30** такой URL приводится к **`git@github.com:…`**. Итоговый URL — тот же, что для `git clone`. Там же готовится deploy key для `git@…` / `ssh://…`. Другой хост или клон строго по HTTPS — задайте URL вручную (для HTTPS без конвертации нужны учётные данные git). |
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
| `DISK_VARS_FILE` | `/etc/infra/bootstrap-disk.env` | Локальный профиль дисков. |
| `DISK_VARS_REPO_PATH` | `bootstrap-disk.env` | Путь к файлу профиля внутри репозитория. |
| `DISK_PROFILE_FETCH_FROM_REPO` | `1` | Подтянуть профиль дисков из репо, если локального файла нет. |
| `MAIN_DISK_DEVICE` | *(пусто)* | Принудительно указать основной диск для расчёта профиля. |
| `VAR_ALLOW_ROOT_DISK` | `1` | Разрешить разметку на диске с корнем (разделы в хвосте или LV в VG root). При фактическом использовании — предупреждение и ожидание Enter. `0` — не трогать root-диск. |
| `VAR_ALLOW_ROOT_DISK_SKIP_PROMPT` | `0` | При `1` — не ждать Enter после предупреждения о разметке root-диска (автоматизация). |

Дополнительно для разметки дисков (часто задаются в `bootstrap-disk.env`): `ROOT_TARGET_G`, `VAR_MIN_FREE_MIB`, `VAR_SIZE_G`, `SWAP_SIZE_G`, `MINIO_SIZE_G`, `VAR_DISK_DEVICE`, `MIN_MINIO_G` — см. раздел **«Шаг 40 — disk-storage»** ниже.

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
   - иначе: `epel-release`, `git`, `curl`, `parted`, **`make`** (нужен для целей **`install-deps`** и фаз **`stage1`/`stage2`/`runtime`** приватного **Makefile**). **`ansible-core` из dnf не ставится** — единый контур: ansible-core и коллекции ставятся в приватном `.venv` из `constraints.txt` / `collections/requirements.yml`.

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

Перед разметкой на диске с корнем при **`VAR_ALLOW_ROOT_DISK=1`** (значение по умолчанию) выводится предупреждение и ожидается Enter, если не задано **`VAR_ALLOW_ROOT_DISK_SKIP_PROMPT=1`** и stdin — TTY.

Параметры (в т.ч. `VAR_SIZE_G`, `MINIO_SIZE_G`) задаются в профиле дисков или через переменные окружения — см. таблицу **«Переменные окружения»** выше.

Детали реализации — в `scripts/40-disk-storage.sh`.

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
make install-deps    # .venv из constraints.txt + коллекции Galaxy в collections/ansible_collections
```

Запуск **самих фаз** Ansible (`stage1`, `stage2`, `runtime`) на этом шаге **не делается**: пользователь запускает их вручную через `make stage1`/`make stage2`/`make runtime` в каталоге клона. В окружение `make install-deps` передаются **`REPO_URL`**, **`REF`**, **`ENV`**, **`PULL_DIR`**, а также **`GALAXY_*`** и при необходимости **`COLLECTIONS_REQ`** (по умолчанию `PULL_DIR/collections/requirements.yml`).

Если **`Makefile`** отсутствует, шаг завершается с ошибкой.

### Шаг 90 — `finalize`

**Файл:** `scripts/90-finalize.sh`  
**Функция:** `step_finalize`

1. Повторный **`dnf distro-sync -y`** после установки пакетов и цели **`make install-deps`**.
2. **`verify_critical_services`** — `sshd -t`, при необходимости проверка **NetworkManager**, если он включён (реализация в `scripts/90-finalize.sh`).
3. **`print_next_step_hint`** — итоговая подсказка с готовой командой `cd ${PULL_DIR} && sudo make stage1 ENV=${ENV}` (с учётом `SKIP_ANSIBLE`). Дальше пользователь сам запускает фазы.

## Связь с приватным репозиторием

Точка входа на стороне приватного репозитория — **`Makefile`** с целями **`install-deps`** (Ansible Galaxy + venv), **`stage1`** / **`stage2`** / **`runtime`** (фазы единого `playbooks/site.yml`). Публичный bootstrap после клона в **`PULL_DIR`** выполняет **только** `make install-deps`, передавая в окружение **`ENV`**, **`REPO_URL`**, **`REF`**, **`PULL_DIR`** и при необходимости **`GALAXY_*`** / **`COLLECTIONS_REQ`**. Сами фазы запускает пользователь:

```bash
sudo make stage1 ENV=...   # подскажет команду для stage2; при необходимости перезагрузит сервер
sudo make stage2 ENV=...   # подскажет команду для runtime
sudo make runtime ENV=...  # по необходимости (никаких таймеров и юнитов больше нет)
```

### Что править при изменении контракта

1. **Приватный репо:** цели **`install-deps`**, **`stage1`**, **`stage2`**, **`runtime`** в **`Makefile`**, теги в **`playbooks/site.yml`**, использование переменных окружения.
2. **Публичный репо:** функция **`run_install_deps`** в **`scripts/70-install-deps.sh`** (список **`export`**), при изменении **`REPO_URL`** — **`normalize_github_https_repo_url`** в **`scripts/lib/common.sh`**, дефолт **`REPO_URL`** в **`.env`**, таблицы в этом **README**, текст подсказки в **`scripts/90-finalize.sh`**.
3. Сохраняйте согласованность имён: внешний интерфейс для **`make`** — **`REF`** и **`ENV`**, а не **`REF_VALUE`** / **`ENV_VALUE`** (последние — только внутри shell после **`load-env.sh`**).

### Комментарии в коде

В номерных файлах **`scripts/NN-*.sh`** перед функциями используются блоки в духе **JSDoc**: краткое описание, теги **`@param`** (аргументы **`$1`**, …), **`@globals`**, при необходимости **`@stdout`** / **`@return`** / **`@exit`**. Это упрощает навигацию по длинному шагу **40** и единообразно документирует остальные шаги.

Подробные пояснения по сценарию находятся в:

- **`start.sh`** — порядок шагов и ограничения запуска;
- **`.env`**, **`scripts/lib/load-env.sh`** — корневой конфиг и загрузка переменных;
- **`scripts/lib/common.sh`** — **`git_repo`**, **`normalize_github_https_repo_url`**, **`dnf_install`**;
- **`scripts/10-require-runtime.sh`** … **`scripts/50-sync-repository.sh`** — шапка файла и JSDoc у **`step_*`** и вспомогательных функций;
- **`scripts/40-disk-storage.sh`** — шапка файла и JSDoc у каждой функции (включая вложенную **`pick_disk`**);
- **`scripts/70-install-deps.sh`** — контракт **`make install-deps`**, JSDoc у **`run_install_deps`** / **`step_install_deps`**;
- **`scripts/90-finalize.sh`** — `verify_critical_services` и `print_next_step_hint` (итоговая подсказка про `make stage1`).
