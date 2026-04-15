# Скрипты первичной настройки хоста (bootstrap)

**Репозиторий:** [https://github.com/andrey-khudoley/infrastructure-public.git](https://github.com/andrey-khudoley/infrastructure-public.git)

Репозиторий содержит цепочку shell-скриптов для подготовки **dnf**-системы под инфраструктурный Ansible: пакеты, диски и swap, клон **приватного** репозитория с плейбуками, установка коллекций Galaxy через **`run.sh`** из клонированного репо и первый запуск **`ansible-pull`** с тегом `stage1`.

## Алгоритм вызова

1. **Склонировать этот репозиторий целиком** (нужны `start.sh` и каталог `scripts/` с библиотеками и шагами; одного `start.sh` недостаточно).
2. **Перейти в корень клона** — туда, где лежат `start.sh` и `scripts/`.
3. **Запустить оркестратор от root** с переменными окружения (ниже примеры). Удобно: `sudo bash` или `sudo env … bash start.sh`.

Минимальный пример (подставьте URL своего приватного репо с плейбуками):

```bash
git clone https://github.com/andrey-khudoley/infrastructure-public.git
cd infrastructure-public
sudo env ENV=stage REF=main REPO_URL=git@github.com:andrey-khudoley/infrastructure-private.git bash start.sh
```

Запуск **только** через `curl …/start.sh | bash` **не поддерживается**: `start.sh` вычисляет корень по пути к себе и подключает файлы из `scripts/`; при выполнении скрипта со stdin путь к каталогу с репозиторием не определяется, а без остальных файлов цепочка не работает.

## Точка входа

Единственный сценарий верхнего уровня — **`start.sh`**: последовательно подключает шаги из `scripts/` и вызывает функции `step_*`. Все примеры ниже предполагают запуск **от root** (или через `sudo bash`).

### Репозиторий и окружение Ansible

Базовый запуск: ветка `main`, окружение `stage`, приватный репо по SSH:

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

Полезно для проверки разметки дисков без клона и `ansible-pull`:

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

Увеличить таймаут и число повторов для `run.sh` / `ansible-galaxy` в приватном репо:

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
├── start.sh                 # оркестратор: source scripts/lib/*.sh и scripts/NN-*.sh, затем step_*()
├── scripts/
│   ├── lib/
│   │   ├── env.sh           # значения по умолчанию для переменных окружения
│   │   ├── common.sh        # логирование, dnf, git, проверки sshd/NM, deploy key
│   │   ├── disk.sh          # диски, LVM, swap, /var, /minio
│   │   └── ansible.sh       # sync репозитория, ansible-pull
│   ├── 10-require-runtime.sh
│   ├── 20-install-packages.sh
│   ├── 30-ssh-deploy-key.sh
│   ├── 40-disk-storage.sh
│   ├── 50-sync-repository.sh
│   ├── 60-ansible-collections.sh
│   ├── 70-ansible-pull-stage1.sh
│   └── 90-finalize.sh
```

## Переменные окружения

Значения по умолчанию задаются в `scripts/lib/env.sh` и могут быть переопределены перед запуском `start.sh`.

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `ENV` | `ctl` | Окружение для `ansible-pull`: `ctl`, `stage`, `prod` (передаётся как `-e env=…`). |
| `REPO_URL` | `https://git.example.com/infra.git` | URL приватного репозитория с плейбуками. |
| `REF` | `main` | Ветка, тег или коммит. |
| `PULL_DIR` | `/var/lib/infra/src` | Каталог клона и рабочая директория `ansible-pull`. |
| `SKIP_ANSIBLE` | `0` | При `1` — не клонировать репо, не ставить коллекции, не запускать `ansible-pull`. |
| `GALAXY_INSTALL_TIMEOUT` | `300` | Таймаут `ansible-galaxy` (сек), прокидывается в `run.sh`. |
| `GALAXY_DOWNLOAD_DIR` | `/var/lib/infra/galaxy-download` | Кэш скачанных коллекций. |
| `GALAXY_INSTALL_RETRIES` | `5` | Число повторов сетевых шагов в репо (через `run.sh`). |
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

## Библиотеки `scripts/lib/`

Общие функции подключаются из `start.sh` до выполнения пошаговых сценариев.

### `env.sh`

Объявляет переменные окружения с значениями по умолчанию (таблица выше).

### `common.sh`

- Логирование: `log_info`, `log_warn`, `log_err`, `section`, `fail`.
- `has_cmd`, `dnf_install`, `git_repo` (клон без интерактивного `credential.helper` для HTTPS).
- `repo_url_is_ssh` — определяет, нужен ли SSH-ключ для `REPO_URL`.
- `ensure_infra_deploy_key` — создание ed25519 и вывод публичной части для Deploy keys.
- `distro_sync_system` — `dnf distro-sync -y`.
- `verify_sshd`, `verify_network_stack_if_managed`, `verify_critical_services` — проверки после обновлений пакетов.
- `require_runtime` — root, наличие `dnf` и базовых утилит (`lsblk`, `findmnt`, …).

### `disk.sh`

Функции разметки и переноса данных: определение дисков, профиль из файла или временного клона, swap, расширение root LV, перенос `/var` и создание `/minio` на отдельном разделе или в LVM. Подробнее — раздел **«Шаг 40 — disk-storage»** ниже.

### `ansible.sh`

- `sync_repository` — `git clone` или `fetch`/`checkout` в `PULL_DIR`.
- `run_stage1_ansible_pull` — **`${PULL_DIR}/run.sh stage1-pull`** (в клоне: **make** цель **`stage1-pull`**, внутри — `scripts/stage1-ansible-pull.sh`; то же, что **`make stage1-pull-*`** при заданных `REPO_URL`, `REF`, `PULL_DIR`).

## Шаги сценария (порядок в `start.sh`)

### Шаг 10 — `require-runtime`

**Файл:** `scripts/10-require-runtime.sh`  
**Функция:** `step_require_runtime`

Проверяет, что скрипт запущен от **root**, в системе есть **dnf**, и доступны утилиты: `lsblk`, `findmnt`, `awk`, `sed`, `blkid`, `mount`, `umount`.

При невыполнении условий вызывается `fail` с сообщением и ненулевым кодом выхода. Реализация: `require_runtime` в `scripts/lib/common.sh`.

### Шаг 20 — `install-packages`

**Файл:** `scripts/20-install-packages.sh`  
**Функция:** `step_install_packages`

1. Устанавливает базовые пакеты через `dnf`:
   - при **`SKIP_ANSIBLE=1`**: `epel-release`, `git`, `curl`, `parted`;
   - иначе: `epel-release`, `git`, `curl`, `ansible-core`, `parted`, **`make`** (нужен для `run.sh` → `make install-deps` в приватном репозитории).

2. Выполняет **`dnf distro-sync -y`** — выравнивание версий установленных пакетов с репозиториями (в т.ч. после подключения EPEL).

Повторный `distro-sync` выполняется в конце цепочки в шаге **90 — finalize**.

### Шаг 30 — `ssh-deploy-key`

**Файл:** `scripts/30-ssh-deploy-key.sh`  
**Функция:** `step_ssh_deploy_key`

Если `REPO_URL` начинается с **`git@`** или **`ssh://`**, для доступа к приватному репозиторию создаётся ключ **`INFRA_SSH_KEY`** (ed25519), печатается публичная часть — её нужно добавить в **Deploy keys** (read-only) на GitHub/GitLab.

Пока ключ не добавлен, скрипт может ждать нажатия Enter (отключается **`INFRA_SSH_SKIP_PROMPT=1`**).

Для **HTTPS**-URL этот шаг ничего не делает. Для приватного репозитория на GitHub без токена в URL используйте SSH.

Реализация: `ensure_infra_deploy_key` в `scripts/lib/common.sh`.

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

Детали реализации — в `scripts/lib/disk.sh`.

### Шаг 50 — `sync-repository`

**Файл:** `scripts/50-sync-repository.sh`  
**Функция:** `step_sync_repository`

При **`SKIP_ANSIBLE=1`** шаг пропускается (репозиторий не нужен для последующих шагов в этом режиме).

Иначе выполняется **`sync_repository`**: каталог `PULL_DIR` создаётся при необходимости; если репозиторий уже клонирован, обновляется `origin` на `REPO_URL`, выполняются `fetch` и `checkout` на `REF`; если нет — выполняется `git clone -b REF REPO_URL PULL_DIR`.

Используется обёртка `git_repo` без интерактивного запроса учётных данных для HTTPS.

Реализация: `scripts/lib/ansible.sh`.

### Шаг 60 — `ansible-collections`

**Файл:** `scripts/60-ansible-collections.sh`  
**Функция:** `step_ansible_collections`

После успешного клона в `PULL_DIR` ожидается приватный репозиторий с **`run.sh`** в корне. Выполняется:

```bash
cd PULL_DIR
./run.sh install-deps
```

В окружение передаются **`GALAXY_*`** и при необходимости **`COLLECTIONS_REQ`** (по умолчанию `PULL_DIR/collections/requirements.yml`). Установка коллекций (скачивание, кэш, offline install, ретраи) реализована в приватном репозитории через **Makefile** и `scripts/galaxy-offline-install.sh`.

Если **`run.sh`** отсутствует, шаг завершается с ошибкой.

При **`SKIP_ANSIBLE=1`** шаг не выполняется.

### Шаг 70 — `ansible-pull-stage1`

**Файл:** `scripts/70-ansible-pull-stage1.sh`  
**Функция:** `step_ansible_pull_stage1`

При **`SKIP_ANSIBLE=1`** пропускается.

Иначе вызывается **`run_stage1_ansible_pull`** (`scripts/lib/ansible.sh`):

1. Копируется `inventory.ini` → `inventory.pull.ini` (без лишних алиасов хостов).
2. Запускается **`ansible-pull`** с URL `REPO_URL`, веткой `REF`, каталогом `PULL_DIR`, инвентарём `inventory.pull.ini`, плейбуком **`bootstrap.yml`**, тегами **`stage1`**, extra vars **`env=ENV_VALUE`**.

Для git внутри pull отключается интерактивный `credential.helper`; сбрасывается `ANSIBLE_INVENTORY`, чтобы не ломать инвентарь.

### Шаг 90 — `finalize`

**Файл:** `scripts/90-finalize.sh`  
**Функция:** `step_finalize`

1. Повторный **`dnf distro-sync -y`** после установки пакетов и stage1.
2. **`verify_critical_services`** — `sshd -t`, при необходимости проверка **NetworkManager**, если он включён.

Выводится итоговое сообщение: с `SKIP_ANSIBLE=1` или после полного прохода.

## Связь с приватным репозиторием

Список коллекций и установка через **Make** живут в приватном репозитории (`collections/requirements.yml`, `run.sh`, `Makefile`). Скрипт `60-ansible-collections.sh` после клона вызывает `./run.sh install-deps` в каталоге `PULL_DIR`.
