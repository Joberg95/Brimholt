extends Node3D
## A player, NPC, or humanoid monster in the 3D view: a KayKit character for the vocation, the
## gear of its equipped items attached to the hand slots by item look, its helmet and cape
## meshes shown only while worn, and idle, walk, and attack animations.

const World = preload("res://game/core/world.gd")
const CHARACTERS: String = "res://assets/third_party/kaykit_adventurers/characters/"
const GEAR: String = "res://assets/third_party/kaykit_adventurers/gear/"
## Vocation -> KayKit character.
const MODELS: Dictionary = {
	"knight": CHARACTERS + "Knight.glb", "paladin": CHARACTERS + "Rogue_Hooded.glb", "sorcerer": CHARACTERS + "Mage.glb",
	"druid": CHARACTERS + "Barbarian.glb", "adventurer": CHARACTERS + "Rogue.glb",
}
## Item look -> gear model (bows use the crossbow until a bow model exists; maces the big axe).
const GEAR_MODELS: Dictionary = {
	"sword": "sword_1handed", "greatsword": "sword_2handed", "axe": "axe_1handed", "mace": "axe_2handed",
	"hammer": "axe_2handed", "bow": "crossbow_2handed", "crossbow": "crossbow_1handed", "wand": "wand", "rod": "staff",
	"buckler": "shield_round", "heater": "shield_badge", "tower": "shield_square", "book": "spellbook_closed",
}
## KayKit characters are about 2.4 units tall: this makes one a little over a tile.
const SCALE: float = 0.5
const LOOPING: Array[String] = ["Idle", "Walking_A", "Running_A"]
const ATTACKS: Dictionary = {"paladin": "1H_Ranged_Shoot", "sorcerer": "Spellcast_Shoot", "druid": "Spellcast_Shoot"}

var vocation: String = ""
var _model: Node3D
var _player: AnimationPlayer
var _right: Node3D
var _left: Node3D
var _helmets: Array[Node3D] = []
var _capes: Array[Node3D] = []
var _gear_key: String = "-"
var _playing: String = ""


func setup(kind: String) -> void:
	vocation = kind
	_model = (load(MODELS.get(kind, MODELS["adventurer"])) as PackedScene).instantiate()
	_model.scale = Vector3.ONE * SCALE
	add_child(_model)
	_player = _model.find_children("*", "AnimationPlayer", true, false)[0]
	for attachment: Node in _model.find_children("*", "BoneAttachment3D", true, false):
		match String(attachment.name):
			"handslot_r":
				_right = attachment
			"handslot_l":
				_left = attachment
			"head":
				for child: Node in attachment.get_children():
					_helmets.append(child)
			"chest":
				for child: Node in attachment.get_children():
					_capes.append(child)
	# The built-in hand items are replaced by the equipped gear's own models.
	for slot: Node3D in [_right, _left]:
		for child: Node in slot.get_children():
			(child as Node3D).visible = false
	for animation: String in LOOPING:
		if _player.has_animation(animation):
			_player.get_animation(animation).loop_mode = Animation.LOOP_LINEAR
	play("Idle")


## Shows the equipment's weapon, off-hand, helmet, and cape; rebuilt only when it changes.
func set_gear(equipment: Dictionary) -> void:
	var key: String = str(equipment)
	if key == _gear_key:
		return
	_gear_key = key
	for slot: Node3D in [_right, _left]:
		for child: Node in slot.get_children():
			if child.has_meta("gear"):
				child.queue_free()
	_attach(_right, String(equipment.get("main_hand", "")))
	_attach(_left, String(equipment.get("off_hand", "")))
	for helmet: Node3D in _helmets:
		helmet.visible = equipment.has("helmet")
	for cape: Node3D in _capes:
		cape.visible = equipment.has("cape")


func _attach(slot: Node3D, entry: String) -> void:
	if entry.is_empty():
		return
	var item: Dictionary = World.ITEMS.get(World.kind_of(entry), {})
	var shape: String = String(item.get("look", "")).get_slice("+", 0)
	if shape == "torch":
		slot.add_child(_torch())
		return
	if not GEAR_MODELS.has(shape):
		return
	var gear: Node3D = (load(GEAR + GEAR_MODELS[shape] + ".gltf") as PackedScene).instantiate()
	gear.set_meta("gear", true)
	if item.has("glow"):
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color(item["glow"], 0.35)
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow.emission_enabled = true
		glow.emission = item["glow"]
		glow.emission_energy_multiplier = 2.0
		for mesh: Node in gear.find_children("*", "MeshInstance3D", true, false):
			(mesh as MeshInstance3D).material_overlay = glow
	slot.add_child(gear)


## A held torch: a stick and a glowing flame (its light comes from the world's light pool).
static func _torch() -> Node3D:
	var torch := Node3D.new()
	torch.set_meta("gear", true)
	var stick := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.06
	rod.bottom_radius = 0.05
	rod.height = 0.9
	stick.mesh = rod
	stick.position = Vector3(0, 0.3, 0)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("#6b4a2c")
	stick.material_override = wood
	torch.add_child(stick)
	var flame := MeshInstance3D.new()
	var blob := SphereMesh.new()
	blob.radius = 0.16
	blob.height = 0.4
	flame.mesh = blob
	flame.position = Vector3(0, 0.85, 0)
	var fire := StandardMaterial3D.new()
	fire.albedo_color = Color("#ffb040")
	fire.emission_enabled = true
	fire.emission = Color("#ff8a20")
	fire.emission_energy_multiplier = 4.0
	flame.material_override = fire
	torch.add_child(flame)
	return torch


## Walk while moving, attack while striking (by attack style: melee, ranged, or spell), else idle.
func animate(moving: bool, attacking: bool, style: String) -> void:
	var wanted: String = "Idle"
	if attacking:
		wanted = ATTACKS.get(style, "1H_Melee_Attack_Chop")
	elif moving:
		wanted = "Running_A"
	play(wanted)


func play(animation: String) -> void:
	if animation == _playing or not _player.has_animation(animation):
		return
	_playing = animation
	_player.play(animation, 0.12, 1.4 if animation == "Running_A" else 1.0)
