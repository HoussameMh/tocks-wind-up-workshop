class_name Look
extends RefCounted
## Read-only access to assets/data/visual_look.json, and the shared material cache.
## Every material row is built once, so objects with the same look can be batched.
## Implements design/art/art-bible.md sections 2, 3 and 7.
##
## Usage:
##   mesh_instance.material_override = Look.material("cog")
##   var range := Look.num("lights", "follow", "range")

const DEFAULT_PATH := "res://assets/data/visual_look.json"
const TEXTURE_PATH := "res://assets/textures/%s_%s_1k.jpg"
const DOT_TILE_SIZE := 64
const DOT_RADIUS := 11.0
const DOT_SHADE := 0.12

static var _data: Dictionary = {}
static var _materials: Dictionary = {}
static var _environment: Environment
static var _dot_tile: ImageTexture
static var _diffuse_textures: Dictionary = {}


## Returns the shared material for a row of the "materials" section.
static func material(row: String) -> StandardMaterial3D:
	if _materials.has(row):
		return _materials[row]
	var built := _build_material(_row(row))
	_materials[row] = built
	return built


## Repeats per world unit baked into merged meshes for this row; 0 when it has no textures.
static func uv_per_unit(row: String) -> float:
	return float(_row(row).get("uv_per_unit", 0.0))


## Render layer mask of objects using this row, matched against each light's cull mask.
static func render_layer(row: String) -> int:
	return int(_row(row).get("render_layer", 1))


## Camera distance beyond which merged props of this row are not drawn; 0 draws them at any distance.
static func cull_distance(row: String) -> float:
	return float(_row(row).get("cull_distance", 0.0))


## Returns a number from a nested section, logging an error if it is missing.
static func num(section_name: String, group: String, key: String) -> float:
	return float(_value(section_name, group, key))


## Returns a color from a nested section: "#rrggbb" text or an [r, g, b] array.
static func color(section_name: String, group: String, key: String) -> Color:
	return to_color(_value(section_name, group, key))


## Returns a Vector3 from a nested section, stored as [x, y, z].
static func vector(section_name: String, group: String, key: String) -> Vector3:
	var values: Array = _value(section_name, group, key)
	return Vector3(values[0], values[1], values[2])


## Returns a group of a section as a Dictionary, for reading optional or list values.
static func group(section_name: String, group_name: String) -> Dictionary:
	return (_all().get(section_name, {}) as Dictionary).get(group_name, {})


## Converts "#rrggbb" text or an [r, g, b] array to a Color. Arrays may exceed 1.0.
static func to_color(value: Variant) -> Color:
	if value is String:
		return Color.html(value)
	var channels: Array = value
	return Color(channels[0], channels[1], channels[2], channels[3] if channels.size() > 3 else 1.0)


## The shared environment, so changing levels does not rebuild the sky's reflection map.
static func environment() -> Environment:
	if _environment == null:
		_environment = _build_environment()
	return _environment


## The directional key light, far window fill and lamp pools. lamp_z moves the lamps along the
## course for levels of another length; empty keeps the default positions.
static func build_lights(parent: Node3D, lamp_z: Array = []) -> void:
	var key := DirectionalLight3D.new()
	key.rotation_degrees = vector("lights", "key", "rotation")
	key.light_color = color("lights", "key", "color")
	key.light_energy = num("lights", "key", "energy")
	key.light_specular = num("lights", "key", "specular")
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = num("lights", "key", "shadow_max_distance")
	key.shadow_blur = num("lights", "key", "shadow_blur")
	key.light_cull_mask = int(num("lights", "key", "cull_mask"))
	parent.add_child(key)
	# A far unshadowed omni rather than a second directional: see data_reference.md.
	parent.add_child(omni("window_fill", vector("lights", "window_fill", "position")))
	var lamp: Dictionary = group("lights", "lamp")
	var lamp_positions: Array = lamp["positions"]
	if not lamp_z.is_empty():
		var first: Array = lamp_positions[0]
		lamp_positions = lamp_z.map(func(z: float) -> Array: return [first[0], first[1], z])
	for position_values: Array in lamp_positions:
		var spot := SpotLight3D.new()
		spot.position = Vector3(position_values[0], position_values[1], position_values[2])
		spot.light_color = to_color(lamp["color"])
		spot.light_energy = lamp["energy"]
		spot.light_specular = lamp["specular"]
		spot.spot_range = lamp["range"]
		spot.spot_angle = lamp["angle"]
		spot.spot_attenuation = lamp["attenuation"]
		spot.light_cull_mask = int(lamp["cull_mask"])
		parent.add_child(spot)
		var target := Vector3(lamp["aim_x"], lamp["aim_y"], position_values[2])
		spot.look_at_from_position(spot.position, target, Vector3.FORWARD)


## Builds an unshadowed OmniLight3D from a group of the "lights" section.
static func omni(group_name: String, at := Vector3.ZERO) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color("lights", group_name, "color")
	light.light_energy = num("lights", group_name, "energy")
	light.light_specular = num("lights", group_name, "specular")
	light.omni_range = num("lights", group_name, "range")
	light.omni_attenuation = num("lights", group_name, "attenuation")
	light.light_cull_mask = int(num("lights", group_name, "cull_mask"))
	return light


static func _all() -> Dictionary:
	if _data.is_empty():
		_data = Tuning.load_json(DEFAULT_PATH)
	return _data


static func _row(row: String) -> Dictionary:
	var materials: Dictionary = _all().get("materials", {})
	if not materials.has(row):
		push_error("Missing material row: %s" % row)
		return {}
	return materials[row]


static func _value(section_name: String, group_name: String, key: String) -> Variant:
	var values := group(section_name, group_name)
	if not values.has(key):
		push_error("Missing look value: %s.%s.%s" % [section_name, group_name, key])
		return 0.0
	return values[key]


static func _build_material(entry: Dictionary) -> StandardMaterial3D:
	var built := StandardMaterial3D.new()
	built.albedo_color = to_color(entry.get("tint", "#ffffff"))
	built.metallic = entry.get("metallic", 0.0)
	built.roughness = entry.get("roughness", 0.7)
	built.metallic_specular = entry.get("specular", 0.5)
	built.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	if entry.get("vertex_color", false):
		built.vertex_color_use_as_albedo = true
		built.vertex_color_is_srgb = true
	if entry.has("emission"):
		built.emission_enabled = true
		built.emission = to_color(entry["emission"])
		built.emission_energy_multiplier = entry.get("emission_energy", 1.0)
	if entry.get("unshaded", false):
		built.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if entry.get("alpha", false):
		built.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		built.cull_mode = BaseMaterial3D.CULL_DISABLED
	if entry.get("additive", false):
		built.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		built.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if entry.get("billboard", false):
		built.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	if entry.get("two_sided", false):
		built.cull_mode = BaseMaterial3D.CULL_DISABLED
	if entry.get("no_fog", false):
		built.disable_fog = true
	if entry.has("mesh_uv"):
		built.uv1_scale = Vector3(entry["mesh_uv"][0], entry["mesh_uv"][1], 1.0)
	if entry.has("texture_set"):
		_apply_maps(built, entry)
	if entry.get("generated", "") == "pegboard_dots":
		built.albedo_texture = _get_dot_tile()
		built.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return built


static func _apply_maps(built: StandardMaterial3D, entry: Dictionary) -> void:
	var texture_set: String = entry["texture_set"]
	var maps: String = entry.get("maps", "d")
	built.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if maps.contains("d"):
		built.albedo_texture = _diffuse_texture(texture_set)
	if maps.contains("n"):
		built.normal_enabled = true
		built.normal_texture = load(TEXTURE_PATH % [texture_set, "nor_gl"])
		built.normal_scale = entry.get("normal_scale", 1.0)
	if maps.contains("r"):
		built.roughness_texture = load(TEXTURE_PATH % [texture_set, "rough"])


## Loads a diffuse map. A set listed under "texture_adjust" gets a softened copy, because a tint
## only multiplies and cannot take the saturation out of very red wood. Runs once per set.
static func _diffuse_texture(texture_set: String) -> Texture2D:
	if _diffuse_textures.has(texture_set):
		return _diffuse_textures[texture_set]
	var texture: Texture2D = load(TEXTURE_PATH % [texture_set, "diff"])
	var adjust: Array = (_all().get("texture_adjust", {}) as Dictionary).get(texture_set, [])
	if not adjust.is_empty() and DisplayServer.get_name() != "headless":
		var image := texture.get_image()
		image.decompress()
		image.clear_mipmaps()
		image.adjust_bcs(adjust[0], adjust[1], adjust[2])
		image.generate_mipmaps()
		texture = ImageTexture.create_from_image(image)
	_diffuse_textures[texture_set] = texture
	return texture


static func _build_environment() -> Environment:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = color("environment", "sky", "top")
	sky_material.sky_horizon_color = color("environment", "sky", "horizon")
	sky_material.ground_horizon_color = color("environment", "sky", "horizon")
	sky_material.ground_bottom_color = color("environment", "sky", "ground")
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	var built := Environment.new()
	built.background_mode = Environment.BG_SKY
	built.sky = sky
	built.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	built.ambient_light_color = color("environment", "ambient", "color")
	built.ambient_light_energy = num("environment", "ambient", "energy")
	built.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	built.tonemap_exposure = num("environment", "tonemap", "exposure")
	built.tonemap_white = num("environment", "tonemap", "white")
	built.glow_enabled = num("environment", "glow", "enabled") > 0.0
	built.glow_intensity = num("environment", "glow", "intensity")
	built.glow_bloom = num("environment", "glow", "bloom")
	built.glow_hdr_threshold = num("environment", "glow", "hdr_threshold")
	built.fog_enabled = num("environment", "fog", "enabled") > 0.0
	built.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	built.fog_light_color = color("environment", "fog", "color")
	built.fog_density = num("environment", "fog", "density")
	built.fog_sky_affect = 0.0
	return built


static func _get_dot_tile() -> ImageTexture:
	if _dot_tile != null:
		return _dot_tile
	var image := Image.create_empty(DOT_TILE_SIZE, DOT_TILE_SIZE, false, Image.FORMAT_RGB8)
	var center := Vector2.ONE * (DOT_TILE_SIZE - 1) * 0.5
	for y in DOT_TILE_SIZE:
		for x in DOT_TILE_SIZE:
			var hole := smoothstep(DOT_RADIUS + 1.5, DOT_RADIUS - 1.5, Vector2(x, y).distance_to(center))
			var shade := lerpf(1.0, DOT_SHADE, hole)
			image.set_pixel(x, y, Color(shade, shade, shade))
	image.generate_mipmaps()
	_dot_tile = ImageTexture.create_from_image(image)
	return _dot_tile
