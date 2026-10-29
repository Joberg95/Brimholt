extends RefCounted
## Builds the game's UI (plan 48): the game window and every panel from the components in game/ui/,
## stacked in order, with main's references to them (game.hud, game.inventory, ...) set; and the
## per-frame refresh of everything shown.

const GameWindow = preload("res://game/ui/game_window.gd")
const Hud = preload("res://game/ui/hud.gd")
const InventoryPanel = preload("res://game/ui/inventory_panel.gd")
const WorldMaps = preload("res://game/ui/world_maps.gd")
const ActionBar = preload("res://game/ui/action_bar.gd")
const NpcDialogs = preload("res://game/ui/npc_dialogs.gd")
const StartPanel = preload("res://game/ui/start_panel.gd")
const QuestList = preload("res://game/ui/quest_list.gd")
const SpellBook = preload("res://game/ui/spell_book.gd")
const CharacterWindow = preload("res://game/ui/character_window.gd")
const GameMenu = preload("res://game/ui/game_menu.gd")
const ProfessionsWindow = preload("res://game/ui/professions_window.gd")
const PartyWindow = preload("res://game/ui/party_window.gd")
const MicroMenu = preload("res://game/ui/micro_menu.gd")
const LexiconWindow = preload("res://game/ui/lexicon_window.gd")


static func build(game: Node) -> void:
	var layer := CanvasLayer.new()
	game.add_child(layer)
	var view := GameWindow.new()
	view.setup(game)
	layer.add_child(view)
	game._view = view
	game._world_view = view.world_view
	var hud := Hud.new()
	var inventory := InventoryPanel.new()
	var maps := WorldMaps.new()
	var action_bar := ActionBar.new()
	var dialogs := NpcDialogs.new()
	game.hud = hud
	game.inventory = inventory
	game.maps = maps
	game.action_bar = action_bar
	game.dialogs = dialogs
	for component: Node in [hud, inventory, maps, action_bar, dialogs]:
		game.add_child(component)
	hud.build(game, layer)
	inventory.build(game, layer)
	maps.build(game, layer)
	action_bar.build(game, layer)
	dialogs.build(game, layer)
	# The start screen covers the whole window, above every other UI, until you host or join.
	var start_layer := CanvasLayer.new()
	start_layer.layer = layer.layer + 5
	game.add_child(start_layer)
	var start_panel := StartPanel.new()
	start_layer.add_child(start_panel)
	start_panel.setup(game, hud.address)
	game.start_panel = start_panel
	var windows: Dictionary = {"quest_list": QuestList.new(), "spell_book": SpellBook.new(), "character_window": CharacterWindow.new(),
		"professions_window": ProfessionsWindow.new(), "party_window": PartyWindow.new(), "lexicon": LexiconWindow.new()}
	for key: String in windows:
		var window: Control = windows[key]
		window.set("game", game)
		layer.add_child(window)
		game.set(key, window)
	var micro_menu := MicroMenu.new()
	game.add_child(micro_menu)
	micro_menu.build(game, layer)
	game.micro_menu = micro_menu
	var game_menu := GameMenu.new()
	layer.add_child(game_menu)
	game_menu.build(game, func() -> void: hud.controls.show())
	game.game_menu = game_menu
	# Stacking, bottom to top: the panels above, then the start menu, zone banner, vitals, quest
	# list, location line, spell book, character window, lexicon, world map, dialog panel, and Controls menu.
	for top: Control in [hud.zone_label, hud.vitals, windows["quest_list"], hud.location_label, windows["spell_book"],
			windows["character_window"], windows["professions_window"], windows["party_window"], windows["lexicon"],
			maps.world_map, dialogs.panel, game_menu, hud.controls]:
		layer.move_child(top, -1)
	game._address = hud.address
	game._controls = hud.controls
	game._zone_label = hud.zone_label
	game._minimap = maps.minimap
	game._world_map = maps.world_map
	game._travel_panel = dialogs.panel
	game._travel_list = dialogs.list
	game._npc_menu = dialogs.npc_menu


## The status labels, the cogwheel menu, and the character stats.
static func update_labels(game: Node) -> void:
	game.hud.update_labels()
	game.game_menu.refresh()
	game.inventory.update_stats()


## The backpack slots and open bags (before the world view redraws).
static func refresh_inventory(game: Node) -> void:
	game.inventory.redraw_slots()
	game.inventory.refresh_bags()


## Every window and the maps.
static func refresh_windows(game: Node) -> void:
	game.dialogs.refresh()
	game.hud.refresh()
	game.quest_list.refresh()
	game.spell_book.refresh()
	game.character_window.refresh()
	game.professions_window.refresh()
	game.party_window.refresh()
	game.start_panel.refresh()
	game.action_bar.redraw()
	game.micro_menu.redraw()
	game.maps.redraw()
