# Brimholt developer commands. Run `make` for the list.
# Override the engine with GODOT=/path/to/godot and the port with PORT=1235.

GODOT ?= godot
PYTHON ?= python3
ADDR ?= 127.0.0.1
PORT ?= 1234
GAME_ARGS := --port=$(PORT)

.DEFAULT_GOAL := help
.PHONY: help run editor host join server import lint test test-unit test-lan test-visual soak fight-sim duel-sim playtest check \
	sprites outfits landscape cliffs hunts camp-density map map-force endgame-zone dungeons desert towns island bot-tree gear-table balance-table export-windows clean

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

lint: ## Parse every script with the strict warnings in project.godot
	@out=$$($(GODOT) --headless --path . --script res://tools/testing/lint.gd 2>&1); \
		echo "$$out" | grep -E '^LINT|Parse Error|at: GDScript::reload'; \
		echo "$$out" | grep -q '^LINT [0-9]* scripts, 0 failed'

test: lint test-unit test-lan ## Lint, unit rules, and real-ENet scenarios (about 1 minute)

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

soak: ## Busy hosted session with clock jumps; fails if objects, nodes, or memory keep growing (about 1 minute)
	@out=$$($(GODOT) --position 99999,99999 --resolution 64x64 --path . --script res://tests/integration/soak_test.gd 2>&1); \
		echo "$$out" | grep -E 'SOAK|SCRIPT ERROR'; \
		echo "$$out" | grep -q 'BRIMHOLT_SOAK_PASS'

fight-sim: ## Balance a monster: MONSTER=field_vole LEVELS=1,10,20,30,40 COUNT=3 [OFF_HAND=torch] (auto-attack vs spells+potions)
	@$(GODOT) --headless --path . --script res://tools/testing/fight_sim.gd -- --monster=$(or $(MONSTER),field_vole) \
		--levels=$(or $(LEVELS),1,10,20,30,40) --count=$(or $(COUNT),1) $(if $(PLAYER_LEVEL),--player-level=$(PLAYER_LEVEL)) $(if $(OFF_HAND),--off-hand=$(OFF_HAND)) 2>&1 \
		| grep -vE '^Godot Engine|^$$'

duel-sim: ## Same-level PvP duels with spells and potions per vocation pair (LEVELS=20,30,45)
	@$(GODOT) --headless --path . --script res://tools/testing/duel_sim.gd -- --levels=$(or $(LEVELS),20,30,45) 2>&1 \
		| grep -vE '^Godot Engine|^$$'

playtest: ## Two-bot full-game playthrough (about 5 minutes); writes .tools/playtest/report.html
	$(PYTHON) tools/testing/playtest.py --godot $(GODOT)

check: import test test-visual soak ## Everything except the long playthrough

# --------------------------------------------------------------------- release
export-windows: import ## Build build/windows/Brimholt.exe (needs Godot 4.5.1 export templates)
	@mkdir -p build/windows
	$(GODOT) --headless --path . --export-release "Windows Desktop" build/windows/Brimholt.exe
	@cp docs/windows.md build/windows/README.txt
	@cp addons/limboai/LICENSE.md build/windows/LimboAI-LICENSE.txt
	@ls -lh build/windows

# --------------------------------------------------------------------- content
bot-tree: ## Save the player bots' LimboAI behavior tree to game/data/bot_behavior.tres (replaces editor edits)
	$(GODOT) --headless --path . --script res://tools/generators/bot_tree.gd 2>&1 | grep -vE '^Godot Engine|^$$'

sprites: ## Regenerate the original sprite sheets in assets/sprites
	$(PYTHON) tools/generators/make_sprites.py

outfits: ## Import painted outfits and icons from art/outfits, derive icons for the rest, and repaint worn gear
	$(GODOT) --headless --path . --script res://tools/generators/import_outfits.gd
	$(PYTHON) tools/generators/derive_icons.py
	$(PYTHON) tools/generators/make_sprites.py
	$(GODOT) --headless --path . --import

map: ## Generate the overworld draft (refuses to overwrite an edited map)
	$(GODOT) --headless --path . --script res://tools/generators/make_map.gd

endgame-zone: ## Repaint the Hollow Reach into the existing overworld (keeps other map edits)
	$(GODOT) --headless --path . --script res://tools/generators/endgame_zone.gd

map-force: ## Regenerate the overworld draft, overwriting game/maps/overworld.tscn
	$(GODOT) --headless --path . --script res://tools/generators/make_map.gd -- --force

hunts: ## Place the Hunters' Lodge and level-50 elite hunting camps (keeps existing camps)
	$(GODOT) --headless --path . --script res://tools/generators/hunts.gd

camp-density: ## One-time pass: hunting camps from level 11 become tight packs of 5-7
	$(GODOT) --headless --path . --script res://tools/generators/camp_density.gd

cliffs: ## One-time pass: cliffs along the high ground and 30% fewer forest trees (keeps other edits)
	$(GODOT) --headless --path . --script res://tools/generators/cliffs.gd

landscape: ## One-time countryside pass: bigger walled towns, the capital castle, cobbled roads, woods, rocks (keeps other edits)
	$(GODOT) --headless --path . --script res://tools/generators/landscape.gd

towns: ## Build missing shops and banks and move vendors and bankers indoors (keeps other edits)
	$(GODOT) --headless --path . --script res://tools/generators/towns.gd

island: ## Thin Blackreed Isle's forest to about a quarter of its trees (keeps other edits)
	$(GODOT) --headless --path . --script res://tools/generators/island.gd

desert: ## Repaint the desert's plants and sand into the existing map (keeps other edits)
	$(GODOT) --headless --path . --script res://tools/generators/desert.gd

dungeons: ## Repaint instanced dungeon copies and stairways into the existing map
	$(GODOT) --headless --path . --script res://tools/generators/dungeons.gd

gear-table: ## Print the gear tier and relic tables (paste into docs/balance.md)
	@$(GODOT) --headless --path . --script res://tools/generators/gear_table.gd 2>/dev/null | grep '^|'

balance-table: ## Print the level 1-50 balance table (paste into docs/balance.md)
	@$(GODOT) --headless --path . --script res://tools/generators/balance_table.gd 2>/dev/null | grep '^|'

clean: ## Remove test reports and captures (keeps downloads and the Godot cache)
	rm -rf .tools/playtest .tools/*.png .tools/*.html
