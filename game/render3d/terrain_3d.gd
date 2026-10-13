extends RefCounted
## Builds one CHUNK x CHUNK block of the map in 3D from World.ROWS (1 unit = 1 tile, ground at y 0):
## a vertex-coloured ground mesh with gentle per-tile colour noise, sunken water beds with a
## glossy water surface and earth banks, walls as boxes (town stone, obsidian, cave rock), and
## trees, dead trees, and desert plants as MultiMesh instances of the KayKit nature models.

const World = preload("res://game/core/world.gd")
const CHUNK: int = 16
const WALL_HEIGHT: float = 1.0
const WATER_BED: float = -0.4
const WATER_LEVEL: float = -0.08
const NATURE: String = "res://assets/third_party/kaykit_medieval_hexagon/nature/"
## Ground colours by terrain (walls and trees stand on their own colour).
const GROUND: Dictionary = {
	".": Color("#5f7d3f"), ",": Color("#9a8058"), ":": Color("#d9c48c"), "=": Color("#a8a39a"), "b": Color("#8a5a34"),
	"d": Color("#4a3e52"), "o": Color("#2e2638"), "c": Color("#5a534c"), "v": Color("#2a2218"), "^": Color("#c9b07a"),
	"T": Color("#56733a"), "D": Color("#3a2e44"), "K": Color("#d2bd86"), "#": Color("#8c8f96"), "O": Color("#3a3050"),
	"C": Color("#6e6258"), "~": Color("#3a5160"),
}
const WALL_COLORS: Dictionary = {"#": Color("#77736c"), "O": Color("#2a2238"), "C": Color("#6a5c50")}
## Tree models per tree terrain; picked per tile by a stable hash.
const TREE_MODELS: Dictionary = {
	"T": ["tree_single_A", "tree_single_B", "trees_A_small", "trees_B_small", "trees_A_medium"],
	"D": ["tree_single_A_cut", "tree_single_B_cut"],
	"K": ["rock_single_A", "rock_single_C", "rock_single_E"],
}

static var _meshes: Dictionary = {}
static var _ground_material: StandardMaterial3D
static var _water_material: StandardMaterial3D
static var _wall_materials: Dictionary = {}


static func noise(cell: Vector2i, salt: int) -> int:
	var value: int = (cell.x * 73856093) ^ (cell.y * 19349663) ^ (salt * 83492791)
	return absi(value) % 1000


## The node for chunk `chunk` (in chunk coordinates), or null when it is entirely outside the map.
static func build(chunk: Vector2i) -> Node3D:
	var origin: Vector2i = chunk * CHUNK
	if origin.x >= World.width() or origin.y >= World.height() or origin.x < 0 or origin.y < 0:
		return null
	_materials()
	var root := Node3D.new()
	root.name = "Chunk_%d_%d" % [chunk.x, chunk.y]
	var ground := SurfaceTool.new()
	ground.begin(Mesh.PRIMITIVE_TRIANGLES)
	var water := SurfaceTool.new()
	water.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_water: bool = false
	var walls: Dictionary = {}
	var trees: Dictionary = {}
	for y: int in range(origin.y, mini(origin.y + CHUNK, World.height())):
		for x: int in range(origin.x, mini(origin.x + CHUNK, World.width())):
			var cell := Vector2i(x, y)
			var tile: String = World.terrain(cell)
			if tile.is_empty() or tile == " ":
				continue
			var shade: float = 0.96 + noise(cell, 1) / 1000.0 * 0.08
			var color: Color = Color(GROUND.get(tile, GROUND["."])) * shade
			color.a = 1.0
			if tile == "~":
				_quad(ground, Vector3(x, WATER_BED, y), color.darkened(0.2))
				_quad(water, Vector3(x, WATER_LEVEL, y), Color.WHITE)
				has_water = true
				continue
			_quad(ground, Vector3(x, 0.0, y), color)
			_banks(ground, cell, color.darkened(0.25))
			if tile in World.WALLS:
				walls.get_or_add(tile, []).append(cell)
			elif tile in World.TREES:
				var choices: Array = TREE_MODELS[tile]
				var model: String = choices[noise(cell, 2) % choices.size()]
				trees.get_or_add(model, []).append(cell)
	ground.generate_normals()
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = ground.commit()
	floor_mesh.material_override = _ground_material
	root.add_child(floor_mesh)
	if has_water:
		water.generate_normals()
		var surface := MeshInstance3D.new()
		surface.mesh = water.commit()
		surface.material_override = _water_material
		surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(surface)
	for tile: String in walls:
		root.add_child(_wall_instances(tile, walls[tile]))
	for model: String in trees:
		root.add_child(_tree_instances(model, trees[model]))
	return root


## A flat tile quad with its top-left corner at `at`.
static func _quad(tool: SurfaceTool, at: Vector3, color: Color) -> void:
	tool.set_color(color)
	var a := at
	var b := at + Vector3(1, 0, 0)
	var c := at + Vector3(1, 0, 1)
	var d := at + Vector3(0, 0, 1)
	for corner: Vector3 in [a, b, c, a, c, d]:
		tool.add_vertex(corner)


## Earth banks down to the water bed along a land tile's water edges.
static func _banks(tool: SurfaceTool, cell: Vector2i, color: Color) -> void:
	tool.set_color(color)
	for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if World.terrain(cell + side) != "~":
			continue
		var top_a: Vector3
		var top_b: Vector3
		match side:
			Vector2i.UP:
				top_a = Vector3(cell.x + 1, 0, cell.y)
				top_b = Vector3(cell.x, 0, cell.y)
			Vector2i.DOWN:
				top_a = Vector3(cell.x, 0, cell.y + 1)
				top_b = Vector3(cell.x + 1, 0, cell.y + 1)
			Vector2i.LEFT:
				top_a = Vector3(cell.x, 0, cell.y)
				top_b = Vector3(cell.x, 0, cell.y + 1)
			_:
				top_a = Vector3(cell.x + 1, 0, cell.y + 1)
				top_b = Vector3(cell.x + 1, 0, cell.y)
		var bottom_a: Vector3 = top_a + Vector3(0, WATER_BED, 0)
		var bottom_b: Vector3 = top_b + Vector3(0, WATER_BED, 0)
		for corner: Vector3 in [top_a, bottom_a, bottom_b, top_a, bottom_b, top_b]:
			tool.add_vertex(corner)


static func _wall_instances(tile: String, cells: Array) -> MultiMeshInstance3D:
	var box := BoxMesh.new()
	box.size = Vector3(1.0, WALL_HEIGHT, 1.0)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = box
	multimesh.instance_count = cells.size()
	for index: int in cells.size():
		var cell: Vector2i = cells[index]
		multimesh.set_instance_transform(index, Transform3D(Basis(), Vector3(cell.x + 0.5, WALL_HEIGHT / 2.0, cell.y + 0.5)))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = _wall_materials[tile]
	return instance


static func _tree_instances(model: String, cells: Array) -> MultiMeshInstance3D:
	var mesh: Mesh = _mesh(model)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = cells.size()
	var grand: float = 1.0 if model.begins_with("rock") else 1.9
	for index: int in cells.size():
		var cell: Vector2i = cells[index]
		var size: float = grand * (0.85 + noise(cell, 3) / 1000.0 * 0.35)
		var basis := Basis(Vector3.UP, noise(cell, 4) / 1000.0 * TAU).scaled(Vector3.ONE * size)
		var jitter := Vector3((noise(cell, 5) - 500) / 2500.0, 0.0, (noise(cell, 6) - 500) / 2500.0)
		multimesh.set_instance_transform(index, Transform3D(basis, Vector3(cell.x + 0.5, 0.0, cell.y + 0.5) + jitter))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	return instance


## The first mesh of a KayKit nature model, loaded once.
static func _mesh(model: String) -> Mesh:
	if not _meshes.has(model):
		var scene: Node = (load(NATURE + model + ".gltf") as PackedScene).instantiate()
		var found: Array[Node] = scene.find_children("*", "MeshInstance3D", true, false)
		_meshes[model] = (found[0] as MeshInstance3D).mesh
		scene.free()
	return _meshes[model]


static func _materials() -> void:
	if _ground_material != null:
		return
	_ground_material = StandardMaterial3D.new()
	_ground_material.vertex_color_use_as_albedo = true
	_ground_material.vertex_color_is_srgb = true
	_ground_material.roughness = 0.95
	_water_material = StandardMaterial3D.new()
	_water_material.albedo_color = Color(0.22, 0.42, 0.55, 0.72)
	_water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water_material.roughness = 0.08
	_water_material.metallic = 0.1
	_water_material.metallic_specular = 0.9
	for tile: String in WALL_COLORS:
		var stone := StandardMaterial3D.new()
		stone.albedo_color = WALL_COLORS[tile]
		stone.roughness = 0.9
		_wall_materials[tile] = stone


## Missing models (a pack moved) are caught by the rules check; this lists every one used.
static func models() -> Array[String]:
	var all: Array[String] = []
	for tile: String in TREE_MODELS:
		for model: String in TREE_MODELS[tile]:
			all.append(model)
	return all
