class_name CourseDressing
extends RefCounted
## Builds the visible course from level data: merged tops, edge strips, bench legs, stair
## rods and the moving platform's lead screw. Collision stays on the bodies in level.gd.
## Implements design/art/art-bible.md sections 3, 4 and 5.

const LEG_SIZE := 1.6
const LEG_INSET := 1.0
const LEG_SPACING := 26.0
const APRON_HEIGHT := 1.4
const APRON_INSET := 1.0
const FLOOR_Y := -23.0
const ROD_RADIUS := 0.16
const ROD_COLLAR_RADIUS := 0.32
const ROD_COLLAR_HEIGHT := 0.18
const SCREW_RADIUS := 0.16
const SCREW_DROP := 0.45
const SCREW_END_MARGIN := 0.1
const BRACKET_SIZE := Vector3(1.1, 0.8, 0.5)
const SCREW_COLLAR_RADIUS := 0.26
const SCREW_COLLAR_SPACING := 0.8
const EDGE_LIGHTEN := 0.42
const REST_TOLERANCE := 0.01

static var _baked: Array[Dictionary] = []
static var _baked_signature := 0


## Adds the merged course meshes to parent. palette maps a platform's color key to its look.
static func build(parent: Node3D, data: Dictionary, palette: Dictionary) -> void:
	var signature := str([data["platforms"], data["moving_platforms"], palette]).hash()
	if signature != _baked_signature or _baked.is_empty():
		_baked = _bake(data, palette)
		_baked_signature = signature
	MeshBatch.Group.place(parent, _baked)


static func _bake(data: Dictionary, palette: Dictionary) -> Array[Dictionary]:
	var group := MeshBatch.Group.new()
	var edge_width := Look.num("readability", "edge", "width")
	var zone_length := Look.num("scenery", "zones", "length")
	var platforms: Array = data["platforms"]
	for entry: Dictionary in platforms:
		var center := _vec(entry["center"])
		var size := _vec(entry["size"])
		var look: Dictionary = palette[entry["color"]]
		var zone := floori(center.z / zone_length)
		var row: String = look["material"]
		var uv_per_unit := Look.uv_per_unit(row)
		var paint := Look.to_color(look.get("paint", "#ffffff"))
		var offset := Vector2(fposmod(center.x * 0.37 + center.z * 0.11, 1.0), fposmod(center.z * 0.23, 1.0))
		group.batch(row, zone, true).add_box(center, size, uv_per_unit, offset, paint)
		var edge_row: String = look.get("edge", row)
		var edge_color: Color = paint.lerp(Color.WHITE, EDGE_LIGHTEN) if edge_row == row else Color.WHITE
		_add_edges(group.batch(edge_row, zone, false), center, size, edge_width, edge_color)
		if look.get("kind", "") == "bench":
			_add_bench_frame(group.batch(row, zone, false), center, size, uv_per_unit)
		elif not _rests_on_bench(center, size, platforms, palette):
			_add_rod(group.batch("rod_steel", zone, false), center, size)
	for entry: Dictionary in data["moving_platforms"]:
		if entry.get("screw", true):
				_add_lead_screw(group, _vec(entry["a"]), _vec(entry["b"]), _vec(entry["size"]), zone_length)
	return group.bake()


static func _add_edges(batch: MeshBatch, center: Vector3, size: Vector3, width: float, color: Color) -> void:
	# Slightly proud of the top and sides, so the strip never flickers against the wood.
	var proud := 0.006
	var y := center.y + size.y * 0.5 - width * 0.5 + proud
	var half := size * 0.5
	var long_x := size.x + proud * 2.0
	var long_z := size.z + proud * 2.0
	for side: float in [-1.0, 1.0]:
		var x_edge := Vector3(center.x, y, center.z + side * (half.z - width * 0.5 + proud))
		batch.add_box(x_edge, Vector3(long_x, width, width), 0.0, Vector2.ZERO, color)
		var z_edge := Vector3(center.x + side * (half.x - width * 0.5 + proud), y, center.z)
		batch.add_box(z_edge, Vector3(width, width, long_z), 0.0, Vector2.ZERO, color)


static func _add_bench_frame(batch: MeshBatch, center: Vector3, size: Vector3, uv_per_unit: float) -> void:
	var bottom := center.y - size.y * 0.5
	var half := size * 0.5
	var leg_height := bottom - FLOOR_Y
	var leg_y := FLOOR_Y + leg_height * 0.5
	var inset := LEG_INSET + LEG_SIZE * 0.5
	var legs_along := maxi(ceili((size.z - inset * 2.0) / LEG_SPACING), 1)
	for step in legs_along + 1:
		var z := center.z - half.z + inset + (size.z - inset * 2.0) * step / legs_along
		for side: float in [-1.0, 1.0]:
			var leg_center := Vector3(center.x + side * (half.x - inset), leg_y, z)
			var leg_size := Vector3(LEG_SIZE, leg_height, LEG_SIZE)
			batch.add_box(leg_center, leg_size, uv_per_unit, Vector2(z * 0.13, side), Color.WHITE, true)
	# Apron rails under the top tie the legs together and read as furniture from the side.
	var apron_y := bottom - APRON_HEIGHT * 0.5
	for side: float in [-1.0, 1.0]:
		var rail := Vector3(center.x + side * (half.x - APRON_INSET), apron_y, center.z)
		batch.add_box(rail, Vector3(0.5, APRON_HEIGHT, size.z - APRON_INSET * 2.0), uv_per_unit)
		var cross := Vector3(center.x, apron_y, center.z + side * (half.z - APRON_INSET))
		batch.add_box(cross, Vector3(size.x - APRON_INSET * 2.0, APRON_HEIGHT, 0.5), uv_per_unit)


static func _add_rod(batch: MeshBatch, center: Vector3, size: Vector3) -> void:
	var bottom := center.y - size.y * 0.5
	var at := Vector3(center.x, 0.0, center.z)
	batch.add_bar(at + Vector3.UP * bottom, at + Vector3.UP * FLOOR_Y, ROD_RADIUS)
	var collar := Transform3D(Basis.IDENTITY, at + Vector3.UP * (bottom - ROD_COLLAR_HEIGHT * 0.5))
	batch.add_mesh(MeshKit.cylinder(ROD_COLLAR_RADIUS, ROD_COLLAR_RADIUS, ROD_COLLAR_HEIGHT, 8), collar)


## True when a block sits directly on a bench top and so needs no rod under it.
static func _rests_on_bench(center: Vector3, size: Vector3, platforms: Array, palette: Dictionary) -> bool:
	var bottom := center.y - size.y * 0.5
	for entry: Dictionary in platforms:
		if (palette[entry["color"]] as Dictionary).get("kind", "") != "bench":
			continue
		var other_center := _vec(entry["center"])
		var other_size := _vec(entry["size"])
		var inside_x := absf(center.x - other_center.x) < other_size.x * 0.5
		var inside_z := absf(center.z - other_center.z) < other_size.z * 0.5
		var other_top := other_center.y + other_size.y * 0.5
		if inside_x and inside_z and absf(other_top - bottom) < REST_TOLERANCE:
			return true
	return false


## Runs from one bench end to the other, below the plate's travel.
static func _add_lead_screw(group: MeshBatch.Group, a: Vector3, b: Vector3, size: Vector3, zone_length: float) -> void:
	var zone := floori((a.z + b.z) * 0.5 / zone_length)
	var y := a.y - size.y * 0.5 - SCREW_DROP
	var direction := (b - a).normalized()
	var start := a - direction * (size.z * 0.5 + Look.num("scenery", "lead_screw", "reach"))
	var finish := b + direction * (size.z * 0.5 + Look.num("scenery", "lead_screw", "reach"))
	start.y = y
	finish.y = y
	var batch := group.batch("rod_steel", zone, false)
	batch.add_bar(start, finish, SCREW_RADIUS, Color.WHITE, 8)
	# Thread collars suggest a screw at this distance without a normal map.
	var length := start.distance_to(finish)
	var collar_mesh := MeshKit.cylinder(SCREW_COLLAR_RADIUS, SCREW_COLLAR_RADIUS, 0.1, 8)
	var collar_basis := Basis(Vector3.RIGHT, PI / 2.0)
	for i in floori(length / SCREW_COLLAR_SPACING) + 1:
		var at := start + direction * (i * SCREW_COLLAR_SPACING)
		batch.add_mesh(collar_mesh, Transform3D(collar_basis, at))
	for end: Vector3 in [start, finish]:
		batch.add_box(end + Vector3.UP * SCREW_END_MARGIN, BRACKET_SIZE)


static func _vec(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])
