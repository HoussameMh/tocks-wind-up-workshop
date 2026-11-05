class_name SurpriseBlock
extends StaticBody3D
## A block bumped from below. Toy boxes release a reward once, and crates break
## only for coiled Tock. Hidden boxes are solid only when Tock is rising into them.

signal reward_released(kind: String, at: Vector3)
signal crate_broken
signal thudded

const KIND_CRATE := "crate"
const SIZE := 1.0
const TOY_COLOR := Color("23a8a3")
const RIBBON_COLOR := Color("f2c230")
const CRATE_COLOR := Color("b97a3f")
const CRATE_FRAME_COLOR := Color("80512a")
const USED_COLOR := Color("77706a")
const BUMP_HEIGHT := 0.25
const BUMP_SECONDS := 0.08

var kind := ""
var is_hidden_block := false
var used := false

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
		_build_toy_box(TOY_COLOR, true)


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
	_build_toy_box(USED_COLOR, false)


func _build_toy_box(color: Color, ribbon: bool) -> void:
	MeshKit.part(_visual, MeshKit.box(Vector3.ONE * SIZE), color)
	if not ribbon:
		return
	MeshKit.part(_visual, MeshKit.box(Vector3(1.02, 1.02, 0.2)), RIBBON_COLOR)
	MeshKit.part(_visual, MeshKit.box(Vector3(0.2, 1.02, 1.02)), RIBBON_COLOR)
	MeshKit.part(_visual, MeshKit.box(Vector3(1.02, 0.2, 1.02)), RIBBON_COLOR)


func _build_crate() -> void:
	MeshKit.part(_visual, MeshKit.box(Vector3.ONE * 0.94), CRATE_COLOR)
	for x: float in [-0.45, 0.45]:
		for y: float in [-0.45, 0.45]:
			MeshKit.part(_visual, MeshKit.box(Vector3(0.12, 0.12, 1.02)), CRATE_FRAME_COLOR, Vector3(x, y, 0.0))
			MeshKit.part(_visual, MeshKit.box(Vector3(1.02, 0.12, 0.12)), CRATE_FRAME_COLOR, Vector3(0.0, x, y))
			MeshKit.part(_visual, MeshKit.box(Vector3(0.12, 1.02, 0.12)), CRATE_FRAME_COLOR, Vector3(x, 0.0, y))
