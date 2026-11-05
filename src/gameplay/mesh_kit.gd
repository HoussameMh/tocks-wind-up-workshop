class_name MeshKit
extends RefCounted
## Builds the game's low-poly look from primitive meshes, with no imported art.

static var _plank_texture: ImageTexture
static var _cog_mesh: ArrayMesh


## Plain material. Usage: MeshKit.color_material(Color.RED, 0.8, 0.3)
static func color_material(color: Color, metallic := 0.0, roughness := 0.7) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


## Colored material with plank lines fixed in world space, which helps players judge speed and distance.
static func plank_material(color: Color) -> StandardMaterial3D:
	var material := color_material(color)
	material.albedo_texture = _get_plank_texture()
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * 0.25
	return material


## Adds a mesh to parent. Usage: MeshKit.part(self, BoxMesh.new(), Color.RED, Vector3.UP)
static func part(
	parent: Node3D,
	mesh: Mesh,
	color: Color,
	offset := Vector3.ZERO,
	metallic := 0.0,
	roughness := 0.7
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = color_material(color, metallic, roughness)
	instance.position = offset
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
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var disc_transform := Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)
	tool.append_from(cylinder(0.3, 0.3, 0.14, 14), 0, disc_transform)
	var tooth := box(Vector3(0.14, 0.14, 0.14))
	var teeth := 8
	for i in teeth:
		var angle := TAU * i / teeth
		var basis := Basis(Vector3.FORWARD, angle)
		var tooth_position := basis * Vector3(0.34, 0.0, 0.0)
		tool.append_from(tooth, 0, Transform3D(basis, tooth_position))
	_cog_mesh = tool.commit()
	return _cog_mesh


## Adds a wind-up key to parent. Its shaft runs along Z and its bow is at +Z.
static func windup_key(parent: Node3D, color: Color, size := 1.0) -> Node3D:
	var key := Node3D.new()
	parent.add_child(key)
	var shaft := part(key, cylinder(0.06 * size, 0.06 * size, 0.5 * size, 8), color, Vector3.ZERO, 0.8, 0.3)
	shaft.rotation.x = PI / 2.0
	for side: float in [-1.0, 1.0]:
		part(
			key,
			torus(0.09 * size, 0.2 * size),
			color,
			Vector3(side * 0.2 * size, 0.0, 0.25 * size),
			0.8,
			0.3
		)
	return key


static func _get_plank_texture() -> ImageTexture:
	if _plank_texture != null:
		return _plank_texture
	var image := Image.create_empty(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var shade := 0.93 + 0.07 * sin(float(y) * 0.9 + sin(float(x) * 0.13) * 2.0)
			var offset_x := 0 if y < 32 else 32
			if y % 32 < 2 or (x + offset_x) % 64 < 2:
				shade = 0.62
			image.set_pixel(x, y, Color(shade, shade, shade))
	image.generate_mipmaps()
	_plank_texture = ImageTexture.create_from_image(image)
	return _plank_texture
