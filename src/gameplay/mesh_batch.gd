class_name MeshBatch
extends RefCounted
## Collects geometry that shares one material into a single surface, so many parts
## cost one draw call. Boxes and grids bake world-scale UVs and tangents per face,
## which needs 3 texture fetches instead of the 9 of triplanar and does not swim.
##
## Usage:
##   var group := MeshBatch.Group.new()
##   group.batch("bench_oak", 0, true).add_box(Vector3.ZERO, Vector3(10, 2, 30), 0.0625)
##   MeshBatch.Group.place(parent, group.bake())


## Several batches, one per material, zone and shadow setting. Zones are separate
## meshes, so frustum culling still works on merged scenery.
class Group:
	extends RefCounted

	var _batches := {}
	var _entries: Array[Dictionary] = []

	## Returns the batch for this material row, zone and shadow setting, creating it if needed.
	func batch(row: String, zone := 0, casts_shadow := false) -> MeshBatch:
		var key := "%s|%d|%s" % [row, zone, casts_shadow]
		if not _batches.has(key):
			_batches[key] = MeshBatch.new()
			_entries.append({"key": key, "row": row, "shadow": casts_shadow})
		return _batches[key]

	## Commits every batch. The result can be cached and placed repeatedly with place().
	func bake() -> Array[Dictionary]:
		var baked: Array[Dictionary] = []
		for entry: Dictionary in _entries:
			var batch_data: MeshBatch = _batches[entry["key"]]
			if not batch_data.is_empty():
				baked.append({"mesh": batch_data.commit(), "row": entry["row"], "shadow": entry["shadow"]})
		return baked

	## Adds one MeshInstance3D per baked mesh to parent.
	static func place(parent: Node3D, baked: Array[Dictionary]) -> void:
		for entry: Dictionary in baked:
			var instance := MeshInstance3D.new()
			instance.mesh = entry["mesh"]
			instance.material_override = Look.material(entry["row"])
			instance.layers = Look.render_layer(entry["row"])
			instance.visibility_range_end = Look.cull_distance(entry["row"])
			if not entry["shadow"]:
				instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(instance)


var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _tangents := PackedFloat32Array()
var _uvs := PackedVector2Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()


## True until something has been added.
func is_empty() -> bool:
	return _vertices.is_empty()


## Number of vertices added so far, for set_row_color().
func vertex_count() -> int:
	return _vertices.size()


## Recolors count vertices from first, for gradients across a grid.
func set_row_color(first: int, count: int, color: Color) -> void:
	for index in range(first, first + count):
		_colors[index] = color


## Adds a box with UVs in repeats per unit (0 gives each face 0-1). With vertical_grain,
## the texture's long axis runs along Y on every side face, for legs and posts.
func add_box(
	center: Vector3,
	size: Vector3,
	uv_per_unit := 0.0,
	uv_offset := Vector2.ZERO,
	color := Color.WHITE,
	vertical_grain := false
) -> void:
	var half := size * 0.5
	var x := Vector3(size.x, 0.0, 0.0)
	var y := Vector3(0.0, size.y, 0.0)
	var z := Vector3(0.0, 0.0, size.z)
	var low := center - half
	var high := center + half
	# Each face is given by its corner and two edges whose cross product points outward.
	add_grid(Vector3(high.x, high.y, low.z), -x, z, uv_per_unit, uv_offset, color)
	add_grid(Vector3(low.x, low.y, low.z), x, z, uv_per_unit, uv_offset, color)
	if vertical_grain:
		add_grid(Vector3(high.x, low.y, high.z), -z, y, uv_per_unit, uv_offset, color)
		add_grid(Vector3(low.x, low.y, low.z), z, y, uv_per_unit, uv_offset, color)
	else:
		add_grid(Vector3(high.x, low.y, low.z), y, z, uv_per_unit, uv_offset, color)
		add_grid(Vector3(low.x, high.y, low.z), -y, z, uv_per_unit, uv_offset, color)
	add_grid(Vector3(low.x, low.y, high.z), x, y, uv_per_unit, uv_offset, color)
	add_grid(Vector3(high.x, low.y, low.z), -x, y, uv_per_unit, uv_offset, color)


## Adds a flat rectangle with its normal along edge_u x edge_v, split into a grid.
## UVs are positions along each edge times uv_per_unit (0 gives 0-1 across the face).
func add_grid(
	origin: Vector3,
	edge_u: Vector3,
	edge_v: Vector3,
	uv_per_unit := 0.0,
	uv_offset := Vector2.ZERO,
	color := Color.WHITE,
	cells_u := 1,
	cells_v := 1
) -> void:
	var u_dir := edge_u.normalized()
	var v_dir := edge_v.normalized()
	var normal := u_dir.cross(v_dir).normalized()
	# Godot's binormal is cross(normal, tangent) * w and points up the image, which is -V.
	var tangent_w := signf(normal.cross(u_dir).dot(-v_dir))
	var start := _vertices.size()
	for j in cells_v + 1:
		for i in cells_u + 1:
			var ratio_u := float(i) / cells_u
			var ratio_v := float(j) / cells_v
			var point := origin + edge_u * ratio_u + edge_v * ratio_v
			var uv := Vector2(ratio_u, ratio_v)
			if uv_per_unit > 0.0:
				uv = Vector2(point.dot(u_dir), point.dot(v_dir)) * uv_per_unit + uv_offset
			_vertices.append(point)
			_normals.append(normal)
			_tangents.append_array([u_dir.x, u_dir.y, u_dir.z, tangent_w])
			_uvs.append(uv)
			_colors.append(color)
	var row := cells_u + 1
	for j in cells_v:
		for i in cells_u:
			var a := start + j * row + i
			_indices.append_array([a, a + row + 1, a + 1, a, a + row, a + row + 1])


## Adds a horizontal soft disc: alpha at the center falling to zero at the rim. It needs no
## texture, so a vertex-colored unshaded material draws it. Used for fake occlusion and blobs.
func add_soft_disc(center: Vector3, radius: Vector2, alpha: float, color := Color.BLACK, segments := 16, upright := false) -> void:
	var start := _vertices.size()
	var rings: Array[Vector2] = [Vector2(0.0, 1.0), Vector2(0.55, 0.62), Vector2(1.0, 0.0)]
	_add_disc_vertex(center, color, alpha)
	for ring_index in range(1, rings.size()):
		for i in segments:
			var angle := TAU * i / segments
			var flat := Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * rings[ring_index].x
			var offset := Vector3(flat.x, flat.y, 0.0) if upright else Vector3(flat.x, 0.0, flat.y)
			_add_disc_vertex(center + offset, color, alpha * rings[ring_index].y)
	for i in segments:
		var next := (i + 1) % segments
		_indices.append_array([start, start + 1 + next, start + 1 + i])
		var inner := start + 1
		var outer := inner + segments
		_indices.append_array([inner + i, inner + next, outer + i])
		_indices.append_array([inner + next, outer + next, outer + i])


## Adds a rectangle whose alpha fades from alpha_at_origin along edge_v to zero. Fake occlusion
## along wall bases and under counters.
func add_soft_strip(origin: Vector3, edge_u: Vector3, edge_v: Vector3, alpha_at_origin: float, color := Color.BLACK) -> void:
	var start := _vertices.size()
	add_grid(origin, edge_u, edge_v, 0.0, Vector2.ZERO, color)
	for index in range(start, _vertices.size()):
		var at_origin := index < start + 2
		_colors[index] = Color(color, alpha_at_origin if at_origin else 0.0)


## Appends a primitive or array mesh's first surface, transformed and tinted.
func add_mesh(mesh: Mesh, xform := Transform3D.IDENTITY, color := Color.WHITE) -> void:
	if mesh.get_surface_count() == 0:
		return
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normal_basis := xform.basis.inverse().transposed()
	var start := _vertices.size()
	for i in vertices.size():
		_vertices.append(xform * vertices[i])
		_normals.append((normal_basis * normals[i]).normalized())
		var tangent := Vector3(1.0, 0.0, 0.0)
		var tangent_w := 1.0
		if tangents.size() >= (i + 1) * 4:
			tangent = (xform.basis * Vector3(tangents[i * 4], tangents[i * 4 + 1], tangents[i * 4 + 2])).normalized()
			tangent_w = tangents[i * 4 + 3]
		_tangents.append_array([tangent.x, tangent.y, tangent.z, tangent_w])
		_uvs.append(uvs[i] if i < uvs.size() else Vector2.ZERO)
		_colors.append(color)
	for index in indices:
		_indices.append(start + index)


## Adds a round bar between two points.
func add_bar(from: Vector3, to: Vector3, radius: float, color := Color.WHITE, segments := 6) -> void:
	var axis := to - from
	var length := axis.length()
	if length <= 0.0:
		return
	var up := axis / length
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var basis := Basis(side, up, side.cross(up))
	add_mesh(MeshKit.cylinder(radius, radius, length, segments), Transform3D(basis, (from + to) * 0.5), color)


## Builds the merged surface.
func commit() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_TANGENT] = _tangents
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_INDEX] = _indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _add_disc_vertex(point: Vector3, color: Color, alpha: float) -> void:
	_vertices.append(point)
	_normals.append(Vector3.UP)
	_tangents.append_array([1.0, 0.0, 0.0, 1.0])
	_uvs.append(Vector2.ZERO)
	_colors.append(Color(color, alpha))
