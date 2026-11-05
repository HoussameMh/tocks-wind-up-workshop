class_name TitleAmbience
extends Node3D
## The title screen's living room: slow lamp drift and dust motes in the lamp light.
## Lives under the level, so a level rebuild removes it. Art-bible section 6.
##
## Usage:
##   var ambience := TitleAmbience.new()
##   ambience.setup(level, player.global_position)
##   level.add_child(ambience)

## Lamp energy swings by this fraction, as two slow waves added together (both below 0.5 Hz).
const DRIFT_AMOUNT := 0.04
const DRIFT_SLOW_HZ := 0.13
const DRIFT_FAST_HZ := 0.37
## A warm pool on the pegboard behind Tock, title only, because the course's lamps aim at the
## bench and leave this wall dark in the title shot. Unshadowed, so it adds no shadow pass.
const WALL_GLOW_OFFSET := Vector3(-16.0, 7.0, -12.0)
const WALL_GLOW_COLOR := Color("ffc48a")
const WALL_GLOW_ENERGY := 2.2
const WALL_GLOW_RANGE := 17.0
const WALL_GLOW_ATTENUATION := 0.9
const MOTE_COUNT := 30
const MOTE_SECONDS := 9.0
const MOTE_AREA := Vector3(4.5, 1.6, 4.5)
const MOTE_CENTER_HEIGHT := 1.5
const MOTE_SPEED := 0.08
## Quad width. The size is set on the mesh because scale_amount had no effect on billboarded
## particles here: the motes rendered about one unit wide, as huge glowing blobs.
const MOTE_SIZE := 0.045
const MOTE_COLOR := Color(1.0, 0.85, 0.6, 0.9)
const MOTE_TEXTURE_SIZE := 32

var _lamps: Array[Light3D] = []
var _base_energy: Array[float] = []
var _clock := 0.0
var _motes: CPUParticles3D


## Call before adding to the tree.
func setup(level: Node, center: Vector3) -> void:
	for lamp: Node in level.find_children("*", "SpotLight3D", true, false):
		_lamps.append(lamp as Light3D)
	var glow := _build_wall_glow()
	glow.position = center + WALL_GLOW_OFFSET
	add_child(glow)
	_lamps.append(glow)
	for lamp in _lamps:
		_base_energy.append(lamp.light_energy)
	_motes = _build_motes()
	_motes.position = center + Vector3.UP * MOTE_CENTER_HEIGHT
	add_child(_motes)


## Turns the drift and motes on or off. Off restores the steady lamp brightness.
func set_motion_enabled(enabled: bool) -> void:
	set_process(enabled)
	_motes.visible = enabled
	_motes.emitting = enabled
	if not enabled:
		_apply_energy(1.0)


func _process(delta: float) -> void:
	_clock += delta
	var wave := sin(TAU * DRIFT_SLOW_HZ * _clock) * 0.6 + sin(TAU * DRIFT_FAST_HZ * _clock) * 0.4
	_apply_energy(1.0 + DRIFT_AMOUNT * wave)


func _apply_energy(factor: float) -> void:
	for i in _lamps.size():
		_lamps[i].light_energy = _base_energy[i] * factor


func _build_wall_glow() -> OmniLight3D:
	var glow := OmniLight3D.new()
	glow.light_color = WALL_GLOW_COLOR
	glow.light_energy = WALL_GLOW_ENERGY
	glow.light_specular = 0.0
	glow.omni_range = WALL_GLOW_RANGE
	glow.omni_attenuation = WALL_GLOW_ATTENUATION
	return glow


func _build_motes() -> CPUParticles3D:
	var dust := Gradient.new()
	dust.set_color(0, Color.WHITE)
	dust.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = dust
	texture.width = MOTE_TEXTURE_SIZE
	texture.height = MOTE_TEXTURE_SIZE
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = texture
	material.disable_fog = true
	var quad := QuadMesh.new()
	quad.size = Vector2(MOTE_SIZE, MOTE_SIZE)
	quad.material = material
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	fade.add_point(0.5, Color.WHITE)
	var motes := CPUParticles3D.new()
	motes.mesh = quad
	motes.amount = MOTE_COUNT
	motes.lifetime = MOTE_SECONDS
	motes.preprocess = MOTE_SECONDS
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = MOTE_AREA
	motes.direction = Vector3.UP
	motes.spread = 180.0
	motes.gravity = Vector3.ZERO
	motes.initial_velocity_min = MOTE_SPEED * 0.4
	motes.initial_velocity_max = MOTE_SPEED
	motes.color = MOTE_COLOR
	motes.color_ramp = fade
	return motes
