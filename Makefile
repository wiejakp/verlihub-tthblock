LUA ?= lua
LUAC ?= luac
PYTHON ?= python3

.PHONY: check syntax test validate ai-init ai-check cce-status cce-refresh

check: syntax test validate

syntax:
	$(LUAC) -p tthblock.lua
	$(LUAC) -p tests/tthblock_test.lua

test:
	$(LUA) tests/tthblock_test.lua

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
