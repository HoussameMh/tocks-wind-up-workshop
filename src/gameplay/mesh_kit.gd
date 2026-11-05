class_name MeshKit
extends RefCounted
## Primitive meshes and shared part helpers. Materials come from Look, so parts with
## the same look share one material.

static var _cog_mesh: ArrayMesh
static var _key_meshes: Dictionary = {}
static var _blob_mesh: ArrayMesh


## Adds a mesh to parent, using a shared material row from Look.
## Usage: MeshKit.part(self, MeshKit.box(Vector3.ONE), "steel_trim", Vector3.UP)
static func part(
	parent: Node3D,
	mesh: Mesh,
	row: String,
	offset := Vector3.ZERO,
	casts_shadow := true
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = Look.material(row)
	instance.position = offset
	if not casts_shadow:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


static func box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func sphere(radius: float, segments := 16) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = maxi(segments / 2, 4)
	return mesh


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 14
	mesh.rings = 4
	return mesh


static func cylinder(top_radius: float, bottom_radius: float, height: float, segments := 16) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh


static func torus(inner_radius: float, outer_radius: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 18
	mesh.ring_segments = 8
	return mesh


## Shared cog mesh of radius ~0.4, axle along Z. Merged into one draw call.
static func cog_mesh() -> ArrayMesh:
	if _cog_mesh != null:
		return _cog_mesh
	var batch := MeshBatch.new()
	batch.add_mesh(cylinder(0.3, 0.3, 0.14, 14), Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO))
	var tooth := box(Vector3(0.14, 0.14, 0.14))
	var teeth := 8
	for i in teeth:
		var basis := Basis(Vector3.FORWARD, TAU * i / teeth)
		batch.add_mesh(tooth, Transform3D(basis, basis * Vector3(0.34, 0.0, 0.0)))
	_cog_mesh = batch.commit()
	return _cog_mesh


## Soft dark landing blob of radius 1, facing up, drawn with the "soft_shadow" row.
static func blob_mesh() -> ArrayMesh:
	if _blob_mesh != null:
		return _blob_mesh
	var batch := MeshBatch.new()
	batch.add_soft_disc(Vector3.ZERO, Vector2.ONE, Look.num("readability", "blob", "opacity"))
	_blob_mesh = batch.commit()
	return _blob_mesh


## Adds a soft landing blob to parent. The caller positions it just above the surface.
static func blob(parent: Node3D, radius: float) -> MeshInstance3D:
	var instance := part(parent, blob_mesh(), "soft_shadow", Vector3.ZERO, false)
	instance.scale = Vector3.ONE * radius
	return instance


## Adds a wind-up key to parent as one merged mesh. Its shaft runs along Z and its bow is at +Z.
static func windup_key(parent: Node3D, row: String, size := 1.0, casts_shadow := true) -> Node3D:
	var key := Node3D.new()
	parent.add_child(key)
	part(key, _key_mesh(size), row, Vector3.ZERO, casts_shadow)
	return key


static func _key_mesh(size: float) -> ArrayMesh:
	if _key_meshes.has(size):
		return _key_meshes[size]
	var batch := MeshBatch.new()
	batch.add_mesh(
		cylinder(0.06 * size, 0.06 * size, 0.5 * size, 8),
		Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)
	)
	for side: float in [-1.0, 1.0]:
		batch.add_mesh(
			torus(0.09 * size, 0.2 * size),
			Transform3D(Basis.IDENTITY, Vector3(side * 0.2 * size, 0.0, 0.25 * size))
		)
	_key_meshes[size] = batch.commit()
	return _key_meshes[size]
