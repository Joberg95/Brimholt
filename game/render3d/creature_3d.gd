extends Node3D
## A non-humanoid monster in the 3D view until proper models arrive (phase 2): a low-poly body
## built from primitives for its look (quadruped, spider, blob, golem, wraith), tinted with the
## monster's colour, scaled by its size, glowing when the catalog says so, and bobbing as it
## moves or strikes.

const Monsters = preload("res://game/data/monsters.gd")

var _body: Node3D
var _phase: float = 0.0


func setup(kind: String) -> void:
	var definition: Dictionary = Monsters.MONSTERS[kind]
	var skin := StandardMaterial3D.new()
	skin.albedo_color = definition["color"]
	skin.roughness = 0.85
	if definition.has("glow"):
		skin.emission_enabled = true
		skin.emission = definition["glow"]
		skin.emission_energy_multiplier = 0.8
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(definition["color"]).darkened(0.35)
	dark.roughness = 0.9
	_body = Node3D.new()
	add_child(_body)
	match String(definition["look"]):
		"quadruped":
			_part(_capsule(0.22, 0.75), skin, Vector3(0, 0.38, 0), Vector3(90, 0, 0))
			_part(_sphere(0.17), skin, Vector3(0, 0.5, 0.42))
			for x: float in [-0.14, 0.14]:
				for z: float in [-0.22, 0.22]:
					_part(_cylinder(0.05, 0.3), dark, Vector3(x, 0.15, z))
		"spider":
			_part(_sphere(0.28, 0.42), skin, Vector3(0, 0.32, -0.12))
			_part(_sphere(0.15), skin, Vector3(0, 0.28, 0.22))
			for side: float in [-1.0, 1.0]:
				for index: int in 4:
					_part(_cylinder(0.025, 0.55), dark, Vector3(side * 0.32, 0.22, 0.18 - index * 0.13), Vector3(0, 0, side * 62))
		"blob":
			_part(_sphere(0.36, 0.5), skin, Vector3(0, 0.25, 0))
		"golem":
			_part(_box(Vector3(0.55, 0.6, 0.4)), skin, Vector3(0, 0.75, 0))
			_part(_box(Vector3(0.3, 0.28, 0.3)), skin, Vector3(0, 1.2, 0.02))
			for side: float in [-1.0, 1.0]:
				_part(_box(Vector3(0.18, 0.55, 0.2)), dark, Vector3(side * 0.38, 0.7, 0))
				_part(_box(Vector3(0.2, 0.45, 0.22)), dark, Vector3(side * 0.15, 0.22, 0))
		_:
			var veil := skin.duplicate() as StandardMaterial3D
			veil.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			veil.albedo_color = Color(definition["color"], 0.75)
			veil.emission_enabled = true
			veil.emission = definition.get("glow", definition["color"])
			veil.emission_energy_multiplier = 0.6
			var cone := CylinderMesh.new()
			cone.top_radius = 0.12
			cone.bottom_radius = 0.38
			cone.height = 1.1
			_part(cone, veil, Vector3(0, 0.75, 0))
			_part(_sphere(0.2), veil, Vector3(0, 1.35, 0))
	scale = Vector3.ONE * float(definition["size"]) * 1.2


func animate(delta: float, moving: bool, attacking: bool) -> void:
	_phase += delta * (14.0 if moving or attacking else 3.0)
	_body.position.y = absf(sin(_phase)) * (0.08 if moving or attacking else 0.02)
	_body.rotation.x = deg_to_rad(-12.0) if attacking else 0.0


func _part(mesh: Mesh, material: Material, at: Vector3, degrees: Vector3 = Vector3.ZERO) -> void:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.rotation_degrees = degrees
	_body.add_child(part)


static func _sphere(radius: float, height: float = -1.0) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0 if height < 0.0 else height
	mesh.radial_segments = 12
	mesh.rings = 6
	return mesh


static func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 4
	return mesh


static func _cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 6
	return mesh


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh
