# Brimholt developer commands. Run `make` for the list.
# Override the engine with GODOT=/path/to/godot and the port with PORT=1235.

GODOT ?= godot
PYTHON ?= python3
ADDR ?= 127.0.0.1
PORT ?= 1234
RL_PYTHON ?= .tools/rl-venv/bin/python
GAME_ARGS := --port=$(PORT)

.DEFAULT_GOAL := help
.PHONY: help run editor host join server import lint test test-unit test-lan test-visual soak fight-sim duel-sim duel-eval train-setup train export-policy bench playtest check \
	sprites landscape cliffs hunts camp-density world-map void-throne reedmere swamp town-paths caves frost-isles fill-gaps clear-walls cobble-towns clear-boulders move-bands sectors islands region bake-map relocate mainland orcs underground caves-below map map-force endgame-zone dungeons desert towns island bot-tree gear-table balance-table export-windows clean

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

fight-sim: ## Balance a monster: MONSTER=field_vole LEVELS=1,10,20,30,40 COUNT=3 [OFF_HAND=torch] [GEAR=boots:hastewind_boots] (auto-attack vs spells+potions); SURVEY=1 fights every elite and champion solo
	@$(GODOT) --headless --path . --script res://tools/testing/fight_sim.gd -- --monster=$(or $(MONSTER),field_vole) \
		--levels=$(or $(LEVELS),1,10,20,30,40) --count=$(or $(COUNT),1) $(if $(PLAYER_LEVEL),--player-level=$(PLAYER_LEVEL)) $(if $(OFF_HAND),--off-hand=$(OFF_HAND)) $(if $(GEAR),--gear=$(GEAR)) $(if $(SURVEY),--survey=1) 2>&1 \
		| grep -vE '^Godot Engine|^$$'

duel-sim: ## Same-level PvP duels with spells and potions per vocation pair (LEVELS=20,30,45)
	@$(GODOT) --headless --path . --script res://tools/testing/duel_sim.gd -- --levels=$(or $(LEVELS),20,30,45) 2>&1 \
		| grep -vE '^Godot Engine|^$$'

duel-eval: ## Trained PvP policy vs the scripted bot per vocation pair (GAMES=10 LEVELS=10,20,30,40,50 DIFFICULTY=hard [BASELINE=1] [POLICY=res://...json] [RIVAL=res://...json])
	@$(GODOT) --headless --path . --script res://tools/testing/duel_eval.gd -- --games=$(or $(GAMES),10) \
		$(if $(LEVELS),--levels=$(LEVELS)) --difficulty=$(or $(DIFFICULTY),hard) $(if $(BASELINE),--baseline) \
		$(if $(POLICY),--policy=$(POLICY)) $(if $(RIVAL),--rival=$(RIVAL)) 2>&1 \
		| grep -vE '^Godot Engine|^$$'

train-setup: ## Create the training venv in .tools/rl-venv (uv, Python 3.12, tools/training/requirements.txt)
	uv venv --python 3.12 .tools/rl-venv
	uv pip install --python $(RL_PYTHON) -r tools/training/requirements.txt

train: ## Train the PvP duel policy with PPO (STEPS=10000000 PROCESSES=8 [RESUME=.tools/rl/pvp_duel.zip] [SELF_PLAY=0.5]); see docs/bot-training.md
	$(RL_PYTHON) tools/training/train.py --steps=$(or $(STEPS),10000000) --processes=$(or $(PROCESSES),8) $(if $(RESUME),--resume=$(RESUME)) $(if $(SELF_PLAY),--self-play=$(SELF_PLAY))

export-policy: ## Write the trained model (MODEL=.tools/rl/pvp_duel.zip) to game/data/policies/pvp_duel.json
	$(RL_PYTHON) tools/training/export_policy.py $(if $(MODEL),--model=$(MODEL))

bench: ## Frame benchmark: solo town, hunt, and raid offscreen; prints frame times and where they go
	$(GODOT) --position 99999,99999 --resolution 64x64 --path . --script res://tools/testing/bench.gd 2>&1 | grep BENCH

playtest: ## Two-bot full-game playthrough (about 5 minutes); writes .tools/playtest/report.html
	$(PYTHON) tools/testing/playtest.py --godot $(GODOT)

check: import test test-visual soak ## Everything except the long playthrough

# --------------------------------------------------------------------- release
export-windows: import ## Build build/windows/Brimholt.exe (needs Godot 4.7.2 export templates)
	@mkdir -p build/windows
	$(GODOT) --headless --path . --export-release "Windows Desktop" build/windows/Brimholt.exe
	@cp docs/windows.md build/windows/README.txt
	@cp addons/limboai/LICENSE.md build/windows/LimboAI-LICENSE.txt
	@cp assets/third_party/fonts/dejavu/LICENSE build/windows/DejaVu-LICENSE.txt
	@cp assets/third_party/CREDITS.md build/windows/CREDITS.txt
	@ls -lh build/windows

# --------------------------------------------------------------------- content
bot-tree: ## Save the player bots' LimboAI behavior tree to game/data/bot_behavior.tres (replaces editor edits)
	$(GODOT) --headless --path . --script res://tools/generators/bot_tree.gd 2>&1 | grep -vE '^Godot Engine|^$$'

sprites: ## Regenerate the original sprite sheets in assets/sprites
	$(PYTHON) tools/generators/make_sprites.py

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

clear-boulders: ## One-time pass: turn the overworld's boulders into the ground around them
	$(GODOT) --headless --path . --script res://tools/generators/clear_boulders.gd

void-throne: ## Build the Void Throne arena and its gateway from the Hollow Sanctum (a re-run changes nothing)
	$(GODOT) --headless --path . --script res://tools/generators/void_throne.gd

reedmere: ## Rebuild Reedmere as an open walled town (keeps the east half; a re-run changes nothing)
	$(GODOT) --headless --path . --script res://tools/generators/reedmere.gd

world-map: ## Bake the painted world map pages (assets/sprites/world_map/) after editing the map; only changed pages are painted again ([FORCE=1] paints all)
	$(GODOT) --headless --path . --script res://tools/generators/world_map.gd $(if $(FORCE),-- --force)

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

fill-gaps: ## Put camps in the countryside's empty stretches, copying each region's camps (a re-run changes nothing)
	$(GODOT) --headless --path . --script res://tools/generators/fill_gaps.gd

cobble-towns: ## Pave every town inside its walls, with a plank quay by its piers (a re-run changes nothing)
	$(GODOT) --headless --path . --script res://tools/generators/cobble_towns.gd

clear-walls: ## Clear stone walls that belong to no building or town wall (a re-run changes nothing)
	$(GODOT) --headless --path . --script res://tools/generators/clear_walls.gd

frost-isles: ## Paint the frost isles and Hrimvik south of the mainland (then make towns town-paths caves world-map)
	$(GODOT) --headless --path . --script res://tools/generators/frost_isles.gd

mainland: ## One-time pass: grow the mainland to 640 x 640 with Brackenford and level 1-30 land (then make towns town-paths cobble-towns world-map)
	$(GODOT) --headless --path . --script res://tools/generators/mainland.gd

orcs: ## One-time pass: build the Grimtusk Hold, the orc fort and its camps east of the Wolfholt (then make towns world-map)
	$(GODOT) --headless --path . --script res://tools/generators/orcs.gd

underground: ## One-time pass: dig the floor below the mainland: tunnel networks with holes, sewers under the bigger towns (then make world-map)
	$(GODOT) --headless --path . --script res://tools/generators/underground.gd

caves-below: ## Move the caves marked "below" in game/data/caves.gd to the floor below, under their mouths (a re-run changes nothing)
	$(GODOT) --headless --path . --script res://tools/generators/caves_below.gd

relocate: ## One-time pass: move the frost isles south and Silverwood east for the 640 x 640 mainland (a re-run changes nothing)
	$(GODOT) --headless --path . --script res://tools/generators/relocate.gd

bake-map: ## Bake the map (game/maps/world.bake) the game loads, after painting in Godot (generators bake it themselves)
	$(GODOT) --headless --path . --script res://tools/generators/bake_map.gd

region: ## Rebuild one region of the world plan from its spec, keeping hand edits (NAME=<id>, e.g. silverwood; then the world map pages)
	$(GODOT) --headless --path . --script res://tools/generators/region.gd -- $(NAME)
	$(GODOT) --headless --path . --script res://tools/generators/world_map.gd

islands: ## Paint the archipelago islands not yet painted (then make towns town-paths world-map; a re-run changes nothing)
	$(GODOT) --headless --path . --script res://tools/generators/islands.gd

sectors: ## Re-split the overworld terrain into sector scenes (after painting across sectors; a re-run changes nothing)
	$(GODOT) --headless --path . --script res://tools/generators/sectors.gd

move-bands: ## One-time pass: move the dungeons, the Void Throne, and the caves past the 1920-column overworld (a re-run changes nothing)
	$(GODOT) --headless --path . --script res://tools/generators/move_bands.gd

caves: ## Carve the elite caves beyond the Void Throne and open their mouths (a re-run changes nothing)
	$(GODOT) --headless --path . --script res://tools/generators/caves.gd

town-paths: ## Pave a cobbled path from every town door to the streets (a re-run changes nothing)
	$(GODOT) --headless --path . --script res://tools/generators/town_paths.gd

swamp: ## Turn Mirewood Fen into bog, giant mushrooms, and pools with walkways (a re-run changes nothing)
	$(GODOT) --headless --path . --script res://tools/generators/swamp.gd

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
