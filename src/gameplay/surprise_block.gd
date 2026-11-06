class_name SurpriseBlock
extends StaticBody3D
## A block bumped from below. Toy boxes release a reward once, and crates break
## only for coiled Tock. Hidden boxes are solid only when Tock is rising into them.

signal reward_released(kind: String, at: Vector3)
signal crate_broken
signal thudded

const KIND_CRATE := "crate"
const SIZE := 1.0
const LID_HEIGHT := 0.2
const LID_Y := 0.41
const BUMP_HEIGHT := 0.25
const BUMP_SECONDS := 0.08

static var _shared_meshes: Dictionary = {}

var kind := ""
var is_hidden_block := false
var used := false
## A rearm box becomes fresh each time Tock respawns.
var rearms := false

var _visual: Node3D
var _busy := false


## Call before adding to the tree.
func setup(block_kind: String, hidden_block: bool, at: Vector3) -> void:
	kind = block_kind
	is_hidden_block = hidden_block
	position = at
	collision_layer = Player.LAYER_HIDDEN if hidden_block else Player.LAYER_WORLD
	collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * SIZE
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)
	_visual = Node3D.new()
	_visual.visible = not hidden_block
	add_child(_visual)
	if kind == KIND_CRATE:
		_build_crate()
	else:
		_build_toy_box("toy_box_body", true)


## Called when Tock's head hits this block.
func bump(coiled: bool) -> void:
	if _busy:
		return
	if kind == KIND_CRATE:
		if coiled:
			_break_crate()
		else:
			thudded.emit()
			_wobble()
		return
	if used:
		thudded.emit()
		_wobble()
		return
	used = true
	if is_hidden_block:
		_reveal()
	_show_used()
	_wobble()
	reward_released.emit(kind, position)


## Bolt contract, design/expansion-spec.md section 3: a crate breaks. A toy box or hidden box
## only clinks, because only head bumps open boxes; the bolt plays that clink itself.
func bolt_hit() -> void:
	if kind == KIND_CRATE and collision_layer != 0:
		_break_crate()


## Makes a used box fresh again. Spec section 2: the re-arm rule.
func rearm() -> void:
	if not used:
		return
	used = false
	for child in _visual.get_children():
		child.queue_free()
	_build_toy_box("toy_box_body", true)


func _reveal() -> void:
	is_hidden_block = false
	collision_layer = Player.LAYER_WORLD
	_visual.visible = true


func _break_crate() -> void:
	_busy = true
	crate_broken.emit()
	collision_layer = 0
	var tween := create_tween()
	tween.tween_property(_visual, "scale", Vector3.ONE * 0.05, 0.15)
	tween.tween_callback(queue_free)


func _wobble() -> void:
	_busy = true
	var tween := create_tween()
	tween.tween_property(_visual, "position:y", BUMP_HEIGHT, BUMP_SECONDS)
	tween.tween_property(_visual, "position:y", 0.0, BUMP_SECONDS)
	tween.tween_callback(func() -> void: _busy = false)


func _show_used() -> void:
	for child in _visual.get_children():
		child.queue_free()
	_build_toy_box("toy_box_used", false)


## A lacquered gift box hanging on twine. Used boxes lose the ribbon, so color is not the only cue.
func _build_toy_box(row: String, ribbon: bool) -> void:
	_add_culled(_body_mesh(), row, true)
	_add_culled(_trim_mesh(ribbon), "box_trim", false)


func _build_crate() -> void:
	_add_culled(_crate_mesh(), "crate", true)
	_add_culled(_trim_mesh(false), "box_trim", false)


func _add_culled(mesh: Mesh, row: String, casts_shadow: bool) -> void:
	var instance := MeshKit.part(_visual, mesh, row, Vector3.ZERO, casts_shadow)
	instance.visibility_range_end = Look.num("readability", "block", "cull_distance")


func _body_mesh() -> Mesh:
	if not _shared_meshes.has("body"):
		_shared_meshes["body"] = MeshKit.box(Vector3.ONE * SIZE)
	return _shared_meshes["body"]


## Mesh-local UVs, because the crate bumps and world UVs would swim.
func _crate_mesh() -> Mesh:
	if _shared_meshes.has("crate"):
		return _shared_meshes["crate"]
	var uv := Look.uv_per_unit("crate")
	var frame_shade := Look.color("scenery", "toy_box", "crate_frame_shade")
	var batch := MeshBatch.new()
	batch.add_box(Vector3.ZERO, Vector3.ONE * 0.94, uv)
	for x: float in [-0.45, 0.45]:
		for y: float in [-0.45, 0.45]:
			batch.add_box(Vector3(x, y, 0.0), Vector3(0.12, 0.12, 1.02), uv, Vector2.ZERO, frame_shade)
			batch.add_box(Vector3(0.0, x, y), Vector3(1.02, 0.12, 0.12), uv, Vector2.ZERO, frame_shade)
			batch.add_box(Vector3(x, 0.0, y), Vector3(0.12, 1.02, 0.12), uv, Vector2.ZERO, frame_shade, true)
	_shared_meshes["crate"] = batch.commit()
	return _shared_meshes["crate"]


## Twine up to the ceiling batten, merged with the ribbon if there is one. The block's height
## sets the twine length, so the mesh is shared per height.
func _trim_mesh(ribbon: bool) -> Mesh:
	var key := "trim_%s_%s_%.2f" % [ribbon, kind == KIND_CRATE, position.y]
	if _shared_meshes.has(key):
		return _shared_meshes[key]
	var batch := MeshBatch.new()
	var top := Look.num("scenery", "twine", "top_y") - position.y
	var twine := Look.color("scenery", "toy_box", "twine")
	batch.add_bar(Vector3.UP * SIZE * 0.5, Vector3.UP * top, Look.num("scenery", "twine", "radius"), twine, 4)
	if kind == KIND_CRATE:
		_shared_meshes[key] = batch.commit()
		return _shared_meshes[key]
	if ribbon:
		var cream := Look.color("scenery", "toy_box", "ribbon")
		batch.add_box(Vector3.ZERO, Vector3(1.02, 1.02, 0.2), 0.0, Vector2.ZERO, cream)
		batch.add_box(Vector3.ZERO, Vector3(0.2, 1.02, 1.02), 0.0, Vector2.ZERO, cream)
	# A lid band breaks up the flat faces, and gives form where the lamp hits a side evenly.
	var lid := Look.color("scenery", "toy_box", "lid" if ribbon else "used_lid")
	batch.add_box(Vector3.UP * LID_Y, Vector3(1.03, LID_HEIGHT, 1.03), 0.0, Vector2.ZERO, lid)
	if ribbon:
		var cream := Look.color("scenery", "toy_box", "ribbon")
		batch.add_box(Vector3.UP * LID_Y, Vector3(1.05, LID_HEIGHT, 0.2), 0.0, Vector2.ZERO, cream)
		batch.add_box(Vector3.UP * LID_Y, Vector3(0.2, LID_HEIGHT, 1.05), 0.0, Vector2.ZERO, cream)
	_shared_meshes[key] = batch.commit()
	return _shared_meshes[key]
