.PHONY: test

test:
	NVIM_LOG_FILE=/dev/null nvim --clean -n -i NONE --headless -l tests/render_lifecycle.lua
