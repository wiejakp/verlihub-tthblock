LUA ?= lua
LUAC ?= luac
PYTHON ?= python3

.PHONY: setup check syntax test badges test-tooling coverage coverage-setup
.PHONY: validation-setup secrets validate
.PHONY: ai-init ai-check
.PHONY: cce-status cce-refresh

check: syntax test-tooling coverage validate secrets

setup: coverage-setup validation-setup

syntax:
	$(LUAC) -p tthblock.lua
	$(LUAC) -p tests/tthblock_test.lua

test: coverage

badges: coverage

test-tooling:
	$(PYTHON) tests/badges_test.py

coverage-setup:
	$(PYTHON) scripts/testing/coverage.py --setup

validation-setup:
	$(PYTHON) -m pip install --disable-pip-version-check --no-deps --no-compile \
		--target .tools/python --cache-dir .tools/pip-cache PyYAML==6.0.3

coverage:
	$(PYTHON) scripts/testing/coverage.py --lua "$(LUA)"

secrets:
	$(PYTHON) tests/secret_scan_test.py
	$(PYTHON) scripts/ai/secret_scan.py

validate:
	$(PYTHON) scripts/ai/validate.py

ai-init:
	bash scripts/ai/bootstrap.sh

ai-check:
	$(PYTHON) scripts/ai/smoke_mcp.py

cce-status:
	bash scripts/ai/cce.sh status

cce-refresh:
	bash scripts/ai/cce.sh index
