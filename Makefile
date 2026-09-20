.DEFAULT_GOAL := check

NVIM ?= nvim
STYLUA ?= stylua
EMMYLUA_CHECK ?= emmylua_check
TEST ?= tests

.PHONY: fmt fmt-check lint test-deps test check

fmt:
	$(STYLUA) .

fmt-check:
	$(STYLUA) --check .

lint:
	VIMRUNTIME="$$(NVIM_LOG_FILE=/dev/null $(NVIM) --clean --headless \
		-c 'lua io.write(vim.env.VIMRUNTIME)' +q 2>/dev/null)" \
		$(EMMYLUA_CHECK) --warnings-as-errors --ignore '.deps/**' .

test-deps:
	sh tests/deps.sh

test: test-deps
	NVIM_LOG_FILE=/dev/null $(NVIM) --headless -n -i NONE \
		-u tests/minimal_init.lua -l tests/run.lua $(TEST)

check: fmt-check lint test
