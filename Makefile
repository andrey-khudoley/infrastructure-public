# Минимальные цели для bootstrap-репозитория.
.PHONY: help init start update git-public git-private
ARGS ?=

help: ## Показать подсказку
	@echo "infrastructure-public:"
	@echo "  make init   — скопировать config/*.example в рабочие файлы (перезапись)"
	@echo "  make start  — полный bootstrap"
	@echo "  make update — синхронизация public+private git"
	@echo "  make git-public  — только синхронизация public git"
	@echo "  make git-private — только синхронизация private git"
	@echo "  Запуск с окружением: sudo env VAR=value make <target>"
	@echo "  Проброс позиционных параметров: make <target> ARGS='…' (логируются; конфиг — через env, см. README)"
	@echo "  Внимание: Make разбивает ARGS по пробелам; сложные значения задавайте через переменные окружения."

init: ## Развернуть config/*.env и config/disk.env из шаблонов *.example (перезапись)
	@bash "$(CURDIR)/scripts/init-config.sh"

start: ## Запустить полный bootstrap-сценарий
	@ROOT="$(CURDIR)" bash "$(CURDIR)/scripts/run-start.sh" $(ARGS)

update: ## Обновить public и private репозитории
	@ROOT="$(CURDIR)" bash "$(CURDIR)/scripts/run-update.sh" $(ARGS)

git-public: ## Обновить только public-репозиторий
	@ROOT="$(CURDIR)" bash "$(CURDIR)/scripts/run-git-public.sh" $(ARGS)

git-private: ## Обновить только private-репозиторий
	@ROOT="$(CURDIR)" bash "$(CURDIR)/scripts/run-git-private.sh" $(ARGS)
