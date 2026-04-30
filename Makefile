# Минимальные цели для bootstrap-репозитория (основной сценарий — start.sh).
.PHONY: help init

help: ## Показать подсказку
	@echo "infrastructure-public:"
	@echo "  make init   — скопировать config/*.example в рабочие файлы (перезапись)"
	@echo "  Затем отредактируйте config/*.env при необходимости и запустите start.sh (см. README.md)."

init: ## Развернуть config/*.env и config/disk.env из шаблонов *.example (перезапись)
	@bash "$(CURDIR)/scripts/init-config.sh"
