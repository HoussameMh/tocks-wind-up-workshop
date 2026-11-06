class_name WorkshopScenery
extends RefCounted
## Builds the workshop room and its props from the level's "decor" data. Everything here is
## visual only, with no collision and no shadows, and is merged by material per zone.
## The merged meshes are kept between level rebuilds. Implements design/art/art-bible.md section 4.

const COUNTER_LEG_SPACING := 32.0
const COUNTER_THICKNESS := 1.2
const COUNTER_LEG_SIZE := 1.2
const PEGBOARD_THICKNESS := 0.2
const PEGBOARD_RAIL := 0.5
const WINDOW_CELLS_Y := 6
const WINDOW_FRAME := 1.0
const WINDOW_MUNTIN := 0.5
const OVERLAY_PROUD := 0.008
const PENCIL_ERASER_LENGTH := 1.6
const PENCIL_FERRULE_LENGTH := 0.7
const PENCIL_TIP_LENGTH := 2.4
const PENCIL_POINT_LENGTH := 0.9
const RULER_WIDTH := 1.5
const RULER_TICK_SPACING := 1.0
const BOLT_THREADS := 9

static var _baked: Array[Dictionary] = []
static var _baked_signature := 0


## Adds every decor entry's meshes to parent.
static func build(parent: Node3D, decor: Array) -> void:
	var signature := str(decor).hash()
	if signature != _baked_signature or _baked.is_empty():
		_baked = _bake(decor)
		_baked_signature = signature
	MeshBatch.Group.place(parent, _baked)


static func _bake(decor: Array) -> Array[Dictionary]:
	var group := MeshBatch.Group.new()
	for entry: Dictionary in decor:
		_add_entry(group, entry)
	return group.bake()


static func _add_entry(group: MeshBatch.Group, entry: Dictionary) -> void:
	var at := _vec(entry["pos"]) if entry.has("pos") else Vector3.ZERO
	match String(entry["type"]):
		"room":
			_add_room(group, _vec(entry["min"]), _vec(entry["max"]))
		"window":
			_add_window(group, at, _vec2(entry["size"]))
		"counter":
			_add_counter(group, entry)
		"pegboard":
			_add_pegboard(group, entry)
		"batten":
			_add_batten(group, entry)
		"hammer":
			_add_hammer(group, at)
		"handsaw":
			_add_handsaw(group, at)
		"wrench":
			_add_wrench(group, at, float(entry["length"]))
		"chisel":
			_add_chisel(group, at)
		"square":
			_add_square(group, at)
		"lamp":
			_add_lamp(group, at, _vec(entry["base"]))
		"jars":
			_add_jars(group, at, int(entry["count"]))
		"vise":
			_add_vise(group, at)
		"oil_can":
			_add_oil_can(group, at)
		"spool":
			_add_spool(group, at)
		"tape_measure":
			_add_tape_measure(group, at)
		"tool_chest":
			_add_tool_chest(group, at)
		"stool":
			_add_stool(group, at)
		"sawhorse":
			_add_sawhorse(group, at)
		"clock":
			_add_clock(group, at, float(entry["radius"]))
		"pencil":
			_add_pencil(group, _vec(entry["center"]), _vec(entry["size"]))
		"battery":
			_add_battery(group, _vec(entry["center"]), _vec(entry["size"]))
		"ruler":
			_add_ruler(group, at, float(entry["length"]))
		"paint_can":
			_add_paint_can(group, at, float(entry["radius"]), float(entry["height"]), Look.to_color(entry["color"]))
		"stir_stick":
			_add_stir_stick(group, at, float(entry["height"]), Look.to_color(entry["color"]))
		"giant_battery":
			_add_giant_battery(group, at, float(entry["radius"]), float(entry["height"]))
		"socket":
			_add_socket(group, at, float(entry["radius"]), float(entry["height"]))
		"giant_bolt":
			_add_giant_bolt(group, at, float(entry["radius"]), float(entry["height"]))
		_:
			push_error("Unknown decor type: %s" % entry["type"])


static func _zone(z: float) -> int:
	return floori(z / Look.num("scenery", "zones", "length"))


## Walls, floor and ceiling as inward-facing surfaces, each its own mesh for culling.
static func _add_room(group: MeshBatch.Group, low: Vector3, high: Vector3) -> void:
	var size := high - low
	var x := Vector3(size.x, 0.0, 0.0)
	var y := Vector3(0.0, size.y, 0.0)
	var z := Vector3(0.0, 0.0, size.z)
	var wall_uv := Look.uv_per_unit("wall_plaster")
	group.batch("wall_plaster", 1000).add_grid(Vector3(low.x, low.y, high.z), -z, y, wall_uv)
	group.batch("wall_plaster", 1001).add_grid(Vector3(high.x, low.y, low.z), z, y, wall_uv)
	group.batch("wall_plaster", 1002).add_grid(low, x, y, wall_uv)
	group.batch("wall_plaster", 1003).add_grid(Vector3(high.x, low.y, high.z), -x, y, wall_uv)
	group.batch("floor_concrete", 1004).add_grid(low, z, x, Look.uv_per_unit("floor_concrete"))
	group.batch("ceiling_plaster", 1005).add_grid(Vector3(low.x, high.y, low.z), x, z, Look.uv_per_unit("ceiling_plaster"))
	# Fake occlusion where the far walls meet the floor. No texture, one merged draw.
	var strip := group.batch("soft_shadow", 1006)
	var height := Look.num("scenery", "occlusion", "wall_base_height")
	var alpha := Look.num("scenery", "occlusion", "wall_base_alpha")
	var lift := Vector3.UP * 0.05
	var inset := 0.05
	strip.add_soft_strip(Vector3(high.x - inset, low.y, low.z) + lift, z, Vector3.UP * height, alpha)
	strip.add_soft_strip(Vector3(low.x, low.y, low.z + inset) + lift, x, Vector3.UP * height, alpha)
	strip.add_soft_strip(Vector3(high.x, low.y, low.z) + lift, z, Vector3.LEFT * height, alpha)
	strip.add_soft_strip(Vector3(low.x, low.y, low.z) + lift, x, Vector3.BACK * height, alpha)


## An unshaded dusk gradient behind a merged frame, on the right wall (x = at.x).
static func _add_window(group: MeshBatch.Group, at: Vector3, size: Vector2) -> void:
	var glass := group.batch("window_glow", 1010)
	var frame := group.batch("window_frame", 1010)
	var width := size.x
	var height := size.y
	var bottom := Look.color("scenery", "window", "bottom")
	var top := Look.color("scenery", "window", "top")
	var edge_z := Vector3(0.0, 0.0, width)
	for band in WINDOW_CELLS_Y:
		var band_height := height / WINDOW_CELLS_Y
		var start := Vector3(at.x, at.y - height * 0.5 + band * band_height, at.z - width * 0.5)
		var first := float(band) / WINDOW_CELLS_Y
		var second := float(band + 1) / WINDOW_CELLS_Y
		var vertex_start := glass.vertex_count()
		glass.add_grid(start, edge_z, Vector3.UP * band_height, 0.0, Vector2.ZERO, bottom.lerp(top, first))
		glass.set_row_color(vertex_start + 2, 2, bottom.lerp(top, second))
	var depth := 0.6
	var x := at.x - depth * 0.5 + 0.1
	for side: float in [-1.0, 1.0]:
		var rail := Vector3(x, at.y + side * (height + WINDOW_FRAME) * 0.5, at.z)
		frame.add_box(rail, Vector3(depth, WINDOW_FRAME, width + WINDOW_FRAME * 2.0))
		var post := Vector3(x, at.y, at.z + side * (width + WINDOW_FRAME) * 0.5)
		frame.add_box(post, Vector3(depth, height, WINDOW_FRAME))
	for i: int in [1, 2]:
		var offset_z := -width * 0.5 + width * i / 3.0
		frame.add_box(Vector3(x, at.y, at.z + offset_z), Vector3(depth, height, WINDOW_MUNTIN))
	for i: int in [1, 2, 3]:
		var offset_y := -height * 0.5 + height * i / 4.0
		frame.add_box(Vector3(x, at.y + offset_y, at.z), Vector3(depth, WINDOW_MUNTIN, width))


## The long rear counter under the pegboard, split by zone so its parts can be culled.
static func _add_counter(group: MeshBatch.Group, entry: Dictionary) -> void:
	var x_low := float(entry["x"][0])
	var x_high := float(entry["x"][1])
	var near_z := float(entry["z"][0])
	var far_z := float(entry["z"][1])
	var top := float(entry["top"])
	var floor_y := float(entry["floor"])
	var uv_per_unit := Look.uv_per_unit("scenery_wood")
	var center_x := (x_low + x_high) * 0.5
	var depth := x_high - x_low
	var length := Look.num("scenery", "zones", "length")
	var z := near_z
	while z > far_z:
		var next_z := maxf(z - length, far_z)
		var zone := _zone((z + next_z) * 0.5)
		var center := Vector3(center_x, top - COUNTER_THICKNESS * 0.5, (z + next_z) * 0.5)
		var batch := group.batch("scenery_wood", zone)
		batch.add_box(center, Vector3(depth, COUNTER_THICKNESS, z - next_z), uv_per_unit)
		# The wall under the counter gets no direct light, so it must not read brighter than the top.
		var dark := group.batch("soft_shadow", zone)
		var under_y := top - COUNTER_THICKNESS
		var under_height := Look.num("scenery", "occlusion", "under_counter_height")
		var under_alpha := Look.num("scenery", "occlusion", "under_counter_alpha")
		var wall_origin := Vector3(x_low + 0.05, under_y, z)
		dark.add_soft_strip(wall_origin, Vector3(0.0, 0.0, next_z - z), Vector3.DOWN * under_height, under_alpha)
		var leg_z := z - COUNTER_LEG_SIZE
		while leg_z > next_z:
			var leg_height := top - COUNTER_THICKNESS - floor_y
			var leg_at := Vector3(x_high - COUNTER_LEG_SIZE, floor_y + leg_height * 0.5, leg_z)
			batch.add_box(leg_at, Vector3(COUNTER_LEG_SIZE, leg_height, COUNTER_LEG_SIZE), uv_per_unit, Vector2.ZERO, Color.WHITE, true)
			leg_z -= COUNTER_LEG_SPACING
		z = next_z


## Pegboard panels on the left wall with a dark rail along their top and bottom.
static func _add_pegboard(group: MeshBatch.Group, entry: Dictionary) -> void:
	var x := float(entry["x"])
	var y_low := float(entry["y"][0])
	var y_high := float(entry["y"][1])
	var near_z := float(entry["z"][0])
	var far_z := float(entry["z"][1])
	var uv_per_unit := Look.uv_per_unit("pegboard")
	var length := Look.num("scenery", "zones", "length")
	var z := near_z
	while z > far_z:
		var next_z := maxf(z - length, far_z)
		var zone := _zone((z + next_z) * 0.5)
		var edge_z := Vector3(0.0, 0.0, next_z - z)
		var board_origin := Vector3(x + PEGBOARD_THICKNESS, y_low, z)
		group.batch("pegboard", zone).add_grid(board_origin, edge_z, Vector3.UP * (y_high - y_low), uv_per_unit)
		var mid_z := (z + next_z) * 0.5
		for y: float in [y_low, y_high]:
			var rail := Vector3(x + PEGBOARD_THICKNESS, y, mid_z)
			group.batch("scenery_frame", zone).add_box(rail, Vector3(PEGBOARD_THICKNESS * 2.0, PEGBOARD_RAIL, z - next_z))
		z = next_z


## A ceiling batten that the toy boxes' twine ties to.
static func _add_batten(group: MeshBatch.Group, entry: Dictionary) -> void:
	var z := float(entry["z"])
	var y := float(entry["y"])
	var width := float(entry["width"])
	var batch := group.batch("scenery_frame", _zone(z))
	batch.add_box(Vector3(0.0, y, z), Vector3(width, 1.0, 1.0))


static func _add_hammer(group: MeshBatch.Group, at: Vector3) -> void:
	var zone := _zone(at.z)
	group.batch("tool_handle", zone).add_box(at, Vector3(0.3, 7.0, 0.5), 0.0)
	group.batch("tool_steel", zone).add_box(at + Vector3(0.0, 3.6, 0.0), Vector3(0.7, 1.0, 3.0))
	_add_peg(group, at + Vector3(0.0, 2.6, 0.0), zone)


static func _add_handsaw(group: MeshBatch.Group, at: Vector3) -> void:
	var zone := _zone(at.z)
	var steel := group.batch("tool_steel", zone)
	var blade_height := 11.0
	for i in 6:
		var ratio := float(i) / 6.0
		var width := lerpf(3.0, 1.2, ratio)
		var y := at.y - blade_height * 0.5 + (ratio + 1.0 / 12.0) * blade_height
		var z := at.z + (3.0 - width) * 0.5
		steel.add_box(Vector3(at.x, y, z), Vector3(0.08, blade_height / 6.0, width))
	var handle := at + Vector3(0.0, blade_height * 0.5 + 1.4, 0.8)
	group.batch("tool_handle", zone).add_box(handle, Vector3(0.45, 3.0, 1.8))
	_add_peg(group, handle + Vector3(0.0, 1.0, 0.0), zone)


static func _add_wrench(group: MeshBatch.Group, at: Vector3, length: float) -> void:
	var zone := _zone(at.z)
	var steel := group.batch("tool_steel", zone)
	steel.add_box(at, Vector3(0.2, length, length * 0.1))
	var jaw := Vector3(0.22, length * 0.08, length * 0.26)
	steel.add_box(at + Vector3.UP * (length * 0.5), jaw)
	steel.add_box(at + Vector3.DOWN * (length * 0.5), jaw)
	_add_peg(group, at + Vector3.UP * (length * 0.4), zone)


static func _add_chisel(group: MeshBatch.Group, at: Vector3) -> void:
	var zone := _zone(at.z)
	group.batch("tool_handle", zone).add_box(at + Vector3.UP * 1.5, Vector3(0.4, 3.0, 0.5))
	group.batch("tool_steel", zone).add_box(at + Vector3.DOWN * 1.5, Vector3(0.1, 3.0, 0.5))


static func _add_square(group: MeshBatch.Group, at: Vector3) -> void:
	var zone := _zone(at.z)
	group.batch("tool_steel", zone).add_box(at + Vector3(0.0, -2.0, 1.5), Vector3(0.08, 0.7, 6.0))
	group.batch("tool_handle", zone).add_box(at + Vector3(0.0, 0.5, -1.2), Vector3(0.4, 6.0, 0.8))


static func _add_peg(group: MeshBatch.Group, at: Vector3, zone: int) -> void:
	group.batch("tool_steel", zone).add_box(at, Vector3(0.6, 0.12, 0.12))


## An anglepoise lamp: base on the counter, two arm sections, shade around the light's position.
static func _add_lamp(group: MeshBatch.Group, head: Vector3, base: Vector3) -> void:
	var zone := _zone(head.z)
	var metal := group.batch("lamp_metal", zone)
	metal.add_mesh(MeshKit.cylinder(1.6, 1.8, 0.4, 12), Transform3D(Basis.IDENTITY, base + Vector3.UP * 0.2))
	var elbow := Vector3(base.x - 1.5, (base.y + head.y) * 0.5 + 1.0, base.z)
	metal.add_bar(base, elbow, 0.14)
	metal.add_bar(elbow, head + Vector3(-1.0, 1.6, 0.0), 0.14)
	var aim := (Vector3(0.0, 0.0, head.z) - head).normalized()
	var side := aim.cross(Vector3.FORWARD).normalized()
	var shade_basis := Basis(side, -aim, side.cross(-aim))
	var shade := MeshKit.cylinder(0.8, 2.5, 3.2, 14)
	shade.cap_bottom = false
	metal.add_mesh(shade, Transform3D(shade_basis, head - aim * 0.4))
	group.batch("lamp_bulb", zone).add_mesh(MeshKit.sphere(0.8, 10), Transform3D(Basis.IDENTITY, head + aim * 0.5))
	_add_prop_occlusion(group, base, Vector2(3.4, 3.4))


static func _add_jars(group: MeshBatch.Group, at: Vector3, count: int) -> void:
	var zone := _zone(at.z)
	var glass_mesh := MeshKit.cylinder(1.5, 1.5, 3.0, 12)
	var lid_mesh := MeshKit.cylinder(1.3, 1.3, 0.4, 12)
	for i in count:
		var center := at + Vector3((i % 2) * 0.8, 0.0, -i * 3.4)
		group.batch("jar_glass", zone).add_mesh(glass_mesh, Transform3D(Basis.IDENTITY, center + Vector3.UP * 1.5))
		group.batch("jar_lid", zone).add_mesh(lid_mesh, Transform3D(Basis.IDENTITY, center + Vector3.UP * 3.2))
		var screws := group.batch("tool_steel", zone)
		for n in 6:
			var angle := TAU * (n + i * 0.3) / 6.0
			var offset := Vector3(cos(angle) * 0.75, 0.25, sin(angle) * 0.75)
			screws.add_bar(center + offset, center + offset + Vector3(0.4, 0.9, 0.2), 0.08, Color.WHITE, 4)
		_add_prop_occlusion(group, center, Vector2(2.6, 2.6))


static func _add_vise(group: MeshBatch.Group, at: Vector3) -> void:
	var zone := _zone(at.z)
	var casting := group.batch("vise_casting", zone)
	casting.add_box(at + Vector3(0.0, 0.5, 0.0), Vector3(4.0, 1.0, 5.0))
	casting.add_box(at + Vector3(0.0, 3.0, -1.5), Vector3(3.2, 4.0, 1.4))
	casting.add_box(at + Vector3(0.0, 3.0, 1.5), Vector3(3.2, 4.0, 1.4))
	group.batch("tool_steel", zone).add_bar(at + Vector3(0.0, 2.6, -3.6), at + Vector3(0.0, 2.6, 3.6), 0.26)
	_add_prop_occlusion(group, at, Vector2(3.6, 4.2))


static func _add_oil_can(group: MeshBatch.Group, at: Vector3) -> void:
	var zone := _zone(at.z)
	var batch := group.batch("prop_muted", zone)
	var tin := Look.color("scenery", "prop_colors", "oil_can")
	batch.add_mesh(MeshKit.cylinder(0.6, 1.3, 2.2, 12), Transform3D(Basis.IDENTITY, at + Vector3.UP * 1.1), tin)
	batch.add_bar(at + Vector3.UP * 2.0, at + Vector3(0.0, 4.0, 1.8), 0.12, tin)
	_add_prop_occlusion(group, at, Vector2(2.2, 2.2))


static func _add_spool(group: MeshBatch.Group, at: Vector3) -> void:
	var zone := _zone(at.z)
	var batch := group.batch("prop_muted", zone)
	var wood := Look.color("scenery", "prop_colors", "spool_wood")
	var thread := Look.color("scenery", "prop_colors", "spool_thread")
	batch.add_mesh(MeshKit.cylinder(1.0, 1.0, 0.25, 12), Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.12), wood)
	batch.add_mesh(MeshKit.cylinder(0.75, 0.75, 1.5, 12), Transform3D(Basis.IDENTITY, at + Vector3.UP * 1.0), thread)
	batch.add_mesh(MeshKit.cylinder(1.0, 1.0, 0.25, 12), Transform3D(Basis.IDENTITY, at + Vector3.UP * 1.88), wood)
	_add_prop_occlusion(group, at, Vector2(1.6, 1.6))


static func _add_tape_measure(group: MeshBatch.Group, at: Vector3) -> void:
	var zone := _zone(at.z)
	var batch := group.batch("prop_muted", zone)
	batch.add_box(at + Vector3.UP * 1.0, Vector3(1.0, 2.0, 2.0), 0.0, Vector2.ZERO, Look.color("scenery", "prop_colors", "tape_measure"))
	_add_prop_occlusion(group, at, Vector2(1.6, 1.8))


static func _add_tool_chest(group: MeshBatch.Group, at: Vector3) -> void:
	var zone := _zone(at.z)
	var batch := group.batch("prop_muted", zone)
	var body := Look.color("scenery", "prop_colors", "chest_body")
	var pull := Look.color("scenery", "prop_colors", "chest_pull")
	batch.add_box(at + Vector3.UP * 9.0, Vector3(10.0, 18.0, 16.0), 0.0, Vector2.ZERO, body)
	for i in 4:
		var y := 3.0 + i * 4.0
		batch.add_box(at + Vector3(-5.05, y, 0.0), Vector3(0.1, 3.4, 15.0), 0.0, Vector2.ZERO, body.lightened(0.08))
		batch.add_box(at + Vector3(-5.2, y, 0.0), Vector3(0.25, 0.3, 5.0), 0.0, Vector2.ZERO, pull)
	_add_prop_occlusion(group, at, Vector2(8.5, 11.0))


static func _add_stool(group: MeshBatch.Group, at: Vector3) -> void:
	var zone := _zone(at.z)
	var batch := group.batch("prop_muted", zone)
	var wood := Look.color("scenery", "prop_colors", "stool")
	batch.add_mesh(MeshKit.cylinder(4.0, 4.0, 0.8, 16), Transform3D(Basis.IDENTITY, at + Vector3.UP * 16.0), wood)
	for i in 4:
		var angle := TAU * (i + 0.5) / 4.0
		var foot := at + Vector3(cos(angle) * 3.8, 0.0, sin(angle) * 3.8)
		var seat := at + Vector3(cos(angle) * 2.4, 15.6, sin(angle) * 2.4)
		batch.add_bar(foot, seat, 0.35, wood)
	_add_prop_occlusion(group, at, Vector2(5.5, 5.5))


static func _add_sawhorse(group: MeshBatch.Group, at: Vector3) -> void:
	var zone := _zone(at.z)
	var batch := group.batch("prop_muted", zone)
	var wood := Look.color("scenery", "prop_colors", "sawhorse")
	batch.add_box(at + Vector3.UP * 16.0, Vector3(1.6, 1.4, 24.0), 0.0, Vector2.ZERO, wood)
	for end: float in [-10.0, 10.0]:
		for side: float in [-1.0, 1.0]:
			var foot := at + Vector3(side * 4.5, 0.0, end)
			batch.add_bar(foot, at + Vector3(side * 0.4, 15.4, end), 0.4, wood)
	_add_prop_occlusion(group, at, Vector2(6.0, 14.0))


## A round wall clock on the far wall, its face toward the course.
static func _add_clock(group: MeshBatch.Group, at: Vector3, radius: float) -> void:
	var zone := _zone(at.z)
	var flat := Basis(Vector3.RIGHT, PI / 2.0)
	group.batch("clock_face", zone).add_mesh(MeshKit.cylinder(radius, radius, 0.6, 28), Transform3D(flat, at))
	var hands := group.batch("clock_hands", zone)
	var front := at + Vector3.BACK * 0.35
	hands.add_box(front + Vector3(radius * 0.15, radius * 0.25, 0.0), Vector3(0.35, radius * 0.5, 0.1))
	hands.add_box(front + Vector3(-radius * 0.3, 0.05, 0.0), Vector3(radius * 0.6, 0.3, 0.1))
	for i in 12:
		var angle := TAU * i / 12.0
		var tick := front + Vector3(cos(angle), sin(angle), 0.0) * radius * 0.86
		hands.add_box(tick, Vector3(0.3, 0.3, 0.1))


## Dresses a long platform as a giant pencil, without changing its collision. Each overlay sits just
## proud of the box. Eraser and ferrule at the near end (+z), sharpened tip at the far end.
static func _add_pencil(group: MeshBatch.Group, center: Vector3, size: Vector3) -> void:
	var batch := group.batch("course_prop", _zone(center.z), false)
	var near_z := center.z + size.z * 0.5
	var far_z := center.z - size.z * 0.5
	var eraser := PENCIL_ERASER_LENGTH
	var ferrule := PENCIL_FERRULE_LENGTH
	var tip := PENCIL_TIP_LENGTH
	var point := PENCIL_POINT_LENGTH
	_add_overlay(batch, center, size, near_z, near_z - eraser, _prop_color("pencil_eraser"))
	_add_overlay(batch, center, size, near_z - eraser, near_z - eraser - ferrule, _prop_color("pencil_ferrule"))
	_add_overlay(batch, center, size, far_z + tip, far_z + point, _prop_color("pencil_wood"))
	_add_overlay(batch, center, size, far_z + point, far_z, _prop_color("pencil_graphite"))
	# Two darker lines along the top give the yellow body its hexagon.
	var line_y := center.y + size.y * 0.5 + OVERLAY_PROUD
	var line_length := size.z - eraser - ferrule - tip
	var line_z := near_z - eraser - ferrule - line_length * 0.5
	for side: float in [-1.0, 1.0]:
		var line := Vector3(center.x + side * size.x * 0.22, line_y, line_z)
		batch.add_box(line, Vector3(0.09, 0.02, line_length), 0.0, Vector2.ZERO, _prop_color("pencil_line"))


## Dresses a small pad as a battery: a dark body, a copper top half and a terminal ring on top.
static func _add_battery(group: MeshBatch.Group, center: Vector3, size: Vector3) -> void:
	var batch := group.batch("course_prop", _zone(center.z), false)
	var body := Vector3(size.x + OVERLAY_PROUD * 2.0, size.y * 0.55, size.z + OVERLAY_PROUD * 2.0)
	var top := center.y + size.y * 0.5
	var copper := _prop_color("battery_copper")
	batch.add_box(Vector3(center.x, top - size.y * 0.75, center.z), Vector3(body.x, size.y * 0.55, body.z), 0.0, Vector2.ZERO, _prop_color("battery_body"))
	batch.add_box(Vector3(center.x, top - size.y * 0.225, center.z), Vector3(body.x, size.y * 0.45, body.z), 0.0, Vector2.ZERO, copper)
	var ring := MeshKit.cylinder(size.x * 0.3, size.x * 0.3, 0.03, 16)
	batch.add_mesh(ring, Transform3D(Basis.IDENTITY, Vector3(center.x, top + 0.015, center.z)), _prop_color("battery_body"))
	var plus := Vector3(center.x, top + 0.04, center.z)
	batch.add_box(plus, Vector3(size.x * 0.28, 0.02, 0.08), 0.0, Vector2.ZERO, copper)
	batch.add_box(plus, Vector3(0.08, 0.02, size.x * 0.28), 0.0, Vector2.ZERO, copper)


## A wooden ruler lying along the course, from at running toward -z, with its tick marks.
static func _add_ruler(group: MeshBatch.Group, at: Vector3, length: float) -> void:
	var batch := group.batch("course_prop", _zone(at.z - length * 0.5), false)
	var y := at.y + OVERLAY_PROUD
	batch.add_box(Vector3(at.x, y, at.z - length * 0.5), Vector3(RULER_WIDTH, 0.02, length), 0.0, Vector2.ZERO, _prop_color("ruler"))
	var tick_color := _prop_color("ruler_tick")
	var marks := floori(length / RULER_TICK_SPACING)
	for i in marks + 1:
		var tick_length := RULER_WIDTH * (0.6 if i % 5 == 0 else 0.3)
		var tick := Vector3(at.x - RULER_WIDTH * 0.5 + tick_length * 0.5, y + 0.012, at.z - i * RULER_TICK_SPACING)
		batch.add_box(tick, Vector3(tick_length, 0.02, 0.07), 0.0, Vector2.ZERO, tick_color)


## A tin of paint, with its label, its rim, a full top and a drip down the side toward the course.
static func _add_paint_can(group: MeshBatch.Group, at: Vector3, radius: float, height: float, paint: Color) -> void:
	var batch := group.batch("prop_muted", _zone(at.z))
	var tin := _prop_color("can_tin")
	var middle := Transform3D(Basis.IDENTITY, at + Vector3.UP * height * 0.5)
	batch.add_mesh(MeshKit.cylinder(radius, radius, height, 20), middle, tin)
	var label_at := Transform3D(Basis.IDENTITY, at + Vector3.UP * height * 0.48)
	batch.add_mesh(MeshKit.cylinder(radius * 1.015, radius * 1.015, height * 0.55, 20), label_at, paint)
	var rim_at := Transform3D(Basis.IDENTITY, at + Vector3.UP * height)
	batch.add_mesh(MeshKit.cylinder(radius * 1.06, radius * 1.06, height * 0.04, 20), rim_at, tin.lightened(0.15))
	var surface := Transform3D(Basis.IDENTITY, at + Vector3.UP * (height + height * 0.022))
	batch.add_mesh(MeshKit.cylinder(radius * 0.94, radius * 0.94, height * 0.01, 20), surface, paint)
	for offset: float in [-0.28, 0.0, 0.3]:
		var drip_length := height * (0.28 - absf(offset) * 0.4)
		var side := Vector3(-cos(offset) * radius * 1.025, height - drip_length * 0.5, sin(offset) * radius * 1.025)
		batch.add_box(at + side, Vector3(0.14, drip_length, radius * 0.1), 0.0, Vector2.ZERO, paint)
	_add_prop_occlusion(group, at, Vector2(radius, radius) * 1.15)


## A long flat stir stick standing up, its lower half dipped in paint.
static func _add_stir_stick(group: MeshBatch.Group, at: Vector3, height: float, paint: Color) -> void:
	var batch := group.batch("prop_muted", _zone(at.z))
	var wood := _prop_color("stir_wood")
	batch.add_box(at + Vector3.UP * height * 0.72, Vector3(0.3, height * 0.56, 1.6), 0.0, Vector2.ZERO, wood)
	batch.add_box(at + Vector3.UP * height * 0.22, Vector3(0.34, height * 0.44, 1.64), 0.0, Vector2.ZERO, paint)


## A huge battery standing on end, the kind the junk drawer's pads are small copies of.
static func _add_giant_battery(group: MeshBatch.Group, at: Vector3, radius: float, height: float) -> void:
	var batch := group.batch("prop_muted", _zone(at.z))
	var lower := Transform3D(Basis.IDENTITY, at + Vector3.UP * height * 0.3)
	batch.add_mesh(MeshKit.cylinder(radius, radius, height * 0.6, 20), lower, _prop_color("battery_body"))
	var upper := Transform3D(Basis.IDENTITY, at + Vector3.UP * height * 0.8)
	batch.add_mesh(MeshKit.cylinder(radius, radius, height * 0.4, 20), upper, _prop_color("giant_battery_copper"))
	var nub := Transform3D(Basis.IDENTITY, at + Vector3.UP * (height + height * 0.03))
	batch.add_mesh(MeshKit.cylinder(radius * 0.35, radius * 0.35, height * 0.06, 14), nub, _prop_color("pencil_ferrule"))
	_add_prop_occlusion(group, at, Vector2(radius, radius) * 1.15)


## A socket from a socket set: a hexagon outside, dark inside.
static func _add_socket(group: MeshBatch.Group, at: Vector3, radius: float, height: float) -> void:
	var batch := group.batch("prop_muted", _zone(at.z))
	var steel := _prop_color("socket_steel")
	var body := Transform3D(Basis.IDENTITY, at + Vector3.UP * height * 0.5)
	batch.add_mesh(MeshKit.cylinder(radius, radius, height, 6), body, steel)
	var hole := Transform3D(Basis.IDENTITY, at + Vector3.UP * (height + 0.01))
	batch.add_mesh(MeshKit.cylinder(radius * 0.68, radius * 0.68, 0.04, 6), hole, _prop_color("socket_hole"))
	var band := Transform3D(Basis.IDENTITY, at + Vector3.UP * height * 0.25)
	batch.add_mesh(MeshKit.cylinder(radius * 1.02, radius * 1.02, height * 0.06, 6), band, steel.darkened(0.25))
	_add_prop_occlusion(group, at, Vector2(radius, radius) * 1.1)


## A giant bolt standing on its thread, hexagon head up.
static func _add_giant_bolt(group: MeshBatch.Group, at: Vector3, radius: float, height: float) -> void:
	var batch := group.batch("prop_muted", _zone(at.z))
	var steel := _prop_color("socket_steel")
	var shaft := radius * 0.6
	var shaft_at := Transform3D(Basis.IDENTITY, at + Vector3.UP * height * 0.42)
	batch.add_mesh(MeshKit.cylinder(shaft, shaft, height * 0.84, 14), shaft_at, steel.darkened(0.1))
	for i in BOLT_THREADS:
		var thread_y := height * 0.84 * (i + 0.5) / BOLT_THREADS
		var thread := Transform3D(Basis.IDENTITY, at + Vector3.UP * thread_y)
		batch.add_mesh(MeshKit.cylinder(shaft * 1.12, shaft * 1.12, height * 0.018, 14), thread, steel)
	var head := Transform3D(Basis.IDENTITY, at + Vector3.UP * height * 0.92)
	batch.add_mesh(MeshKit.cylinder(radius, radius, height * 0.16, 6), head, steel)
	_add_prop_occlusion(group, at, Vector2(radius, radius))


## A colored sleeve round part of a platform's length, from z_a to z_b.
static func _add_overlay(batch: MeshBatch, center: Vector3, size: Vector3, z_a: float, z_b: float, color: Color) -> void:
	var at := Vector3(center.x, center.y, (z_a + z_b) * 0.5)
	var sleeve := Vector3(size.x + OVERLAY_PROUD * 2.0, size.y + OVERLAY_PROUD * 2.0, absf(z_a - z_b))
	batch.add_box(at, sleeve, 0.0, Vector2.ZERO, color)


static func _prop_color(key: String) -> Color:
	return Look.color("scenery", "prop_colors", key)


static func _add_prop_occlusion(group: MeshBatch.Group, at: Vector3, radius: Vector2) -> void:
	var batch := group.batch("soft_shadow", _zone(at.z))
	batch.add_soft_disc(at + Vector3.UP * 0.04, radius, Look.num("scenery", "occlusion", "prop_alpha"))


static func _vec(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])


static func _vec2(values: Array) -> Vector2:
	return Vector2(values[0], values[1])
