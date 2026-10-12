# Brimholt developer commands. Run `make` for the list.
# Override the engine with GODOT=/path/to/godot and the port with PORT=1235.

GODOT ?= godot
PYTHON ?= python3
ADDR ?= 127.0.0.1
PORT ?= 1234
GAME_ARGS := --port=$(PORT)

.DEFAULT_GOAL := help
.PHONY: help run editor host join server import test test-unit test-lan test-visual playtest check \
	sprites map map-force endgame-zone gear-table balance-table clean

help: ## List commands
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  make %-14s %s\n", $$1, $$2}'

# --------------------------------------------------------------------- play
run: ## Open the game with the start menu
	$(GODOT) --path .

editor: ## Open the project in the Godot editor
	$(GODOT) --path . --editor

host: ## Host a game and play (PORT=1234)
	$(GODOT) --path . -- --host $(GAME_ARGS)

join: ## Join a host (ADDR=192.168.1.20 PORT=1234)
	$(GODOT) --path . -- --join=$(ADDR) $(GAME_ARGS)

server: ## Run a dedicated headless server for up to twelve clients
	$(GODOT) --headless --path . -- --headless-server $(GAME_ARGS)

# --------------------------------------------------------------------- checks
import: ## Import assets and parse every script (run after a fresh clone or file moves)
	$(GODOT) --headless --path . --editor --quit

test: test-unit test-lan ## Unit rules and real-ENet scenarios (about 1 minute)

test-unit: ## Deterministic rule checks
	@out=$$($(GODOT) --headless --path . --script res://tests/unit/rules_test.gd 2>&1); \
		echo "$$out" | grep -E 'BRIMHOLT_RULES|FAIL|ERROR|SCRIPT'; \
		echo "$$out" | grep -q 'BRIMHOLT_RULES: [0-9]* checks, 0 failures'

test-lan: ## Real ENet scenarios: playing host, dedicated, host loss, occupied port, persistence
	$(PYTHON) tools/testing/test_lan.py --godot $(GODOT)
	$(PYTHON) tools/testing/test_lan.py --godot $(GODOT) --dedicated
	$(PYTHON) tools/testing/test_lan.py --godot $(GODOT) --host-loss
	$(PYTHON) tools/testing/test_lan.py --godot $(GODOT) --persistence
	$(PYTHON) tools/testing/test_lan.py --godot $(GODOT) --occupied-port

test-visual: ## Offscreen graphical checks; writes .tools/visual-report.html
	$(PYTHON) tools/testing/test_visual.py --godot $(GODOT)

playtest: ## Two-bot full-game playthrough (about 5 minutes); writes .tools/playtest/report.html
	$(PYTHON) tools/testing/playtest.py --godot $(GODOT)

check: import test test-visual ## Everything except the long playthrough

# --------------------------------------------------------------------- content
sprites: ## Regenerate the original sprite sheets in assets/sprites
	$(PYTHON) tools/generators/make_sprites.py

map: ## Generate the overworld draft (refuses to overwrite an edited map)
	$(GODOT) --headless --path . --script res://tools/generators/make_map.gd

endgame-zone: ## Repaint the Hollow Reach into the existing overworld (keeps other map edits)
	$(GODOT) --headless --path . --script res://tools/generators/endgame_zone.gd

map-force: ## Regenerate the overworld draft, overwriting game/maps/overworld.tscn
	$(GODOT) --headless --path . --script res://tools/generators/make_map.gd -- --force

gear-table: ## Print the gear tier and relic tables (paste into docs/balance.md)
	@$(GODOT) --headless --path . --script res://tools/generators/gear_table.gd 2>/dev/null | grep '^|'

balance-table: ## Print the level 1-50 balance table (paste into docs/balance.md)
	@$(GODOT) --headless --path . --script res://tools/generators/balance_table.gd 2>/dev/null | grep '^|'

clean: ## Remove test reports and captures (keeps downloads and the Godot cache)
	rm -rf .tools/playtest .tools/*.png .tools/*.html
