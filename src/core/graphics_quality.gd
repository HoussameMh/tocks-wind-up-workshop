class_name GraphicsQuality
extends RefCounted
## Picks the first-launch graphics quality and applies a quality level to the running game.
## Values come from the "quality" section of assets/data/visual_look.json.
## Implements design/release-spec.md section 3.
##
## Usage:
##   var quality := GraphicsQuality.default_for(RenderingServer.get_video_adapter_name(), OS.has_feature("web"))
##   var scale := GraphicsQuality.apply(get_viewport(), quality)

## Adapter names that point to weak or software graphics, matched without case.
const LOW_ADAPTER_HINTS: Array[String] = ["intel", "llvmpipe", "swiftshader", "basic render", "software"]


## Low for the browser, integrated Intel and software renderers; High for everything else.
static func default_for(adapter_name: String, is_web: bool) -> String:
	if is_web or adapter_name.strip_edges().is_empty():
		return UiSettings.QUALITY_LOW
	var lowered := adapter_name.to_lower()
	for hint in LOW_ADAPTER_HINTS:
		if lowered.contains(hint):
			return UiSettings.QUALITY_LOW
	return UiSettings.QUALITY_HIGH


## Applies anti-aliasing, glow and shadow size. Returns the particle scale for Effects.
static func apply(viewport: Viewport, quality: String) -> float:
	var values := Look.group("quality", quality)
	if values.is_empty():
		push_error("Unknown graphics quality: %s" % quality)
		values = Look.group("quality", UiSettings.QUALITY_LOW)
	viewport.msaa_3d = _msaa(int(values.get("msaa", 0)))
	Look.environment().glow_enabled = int(values.get("glow", 0)) > 0
	RenderingServer.directional_shadow_atlas_set_size(int(values.get("shadow_size", 2048)), true)
	return float(values.get("effects_scale", 1.0))


static func _msaa(samples: int) -> Viewport.MSAA:
	match samples:
		2:
			return Viewport.MSAA_2X
		4:
			return Viewport.MSAA_4X
		8:
			return Viewport.MSAA_8X
	return Viewport.MSAA_DISABLED
