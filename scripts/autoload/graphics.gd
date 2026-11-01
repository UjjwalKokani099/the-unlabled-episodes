extends Node
## Applies the graphics preset (Settings.graphics_quality) and draws the FPS counter.
## Registered as the autoload "Graphics".
##
## Levels author their WorldEnvironment with the features they WANT (SSAO, volumetric fog,
## glow, SSIL). The preset can only switch those off or lower their quality, never add a
## feature a level didn't ask for. So each Environment remembers its authored flags.

enum Quality { LOW, MEDIUM, HIGH }

const NAMES := ["LOW", "MEDIUM", "HIGH"]

## Tuned on the target laptop (RTX 3050 Ti) with tools/benchmark.gd.
const PRESETS := {
	Quality.LOW: {
		"render_scale": 0.6, "fxaa": false, "lod_threshold": 4.0,
		"shadow_atlas": 2048, "soft_shadows": RenderingServer.SHADOW_QUALITY_HARD,
		"ssao": false, "ssao_quality": RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, "ssao_half": true,
		"ssil": false, "ssil_quality": RenderingServer.ENV_SSIL_QUALITY_VERY_LOW,
		"volumetric_fog": false, "fog_size": 64, "fog_depth": 48, "fog_filter": false,
		"glow": true,
	},
	Quality.MEDIUM: {
		"render_scale": 0.75, "fxaa": true, "lod_threshold": 2.0,
		"shadow_atlas": 4096, "soft_shadows": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		"ssao": true, "ssao_quality": RenderingServer.ENV_SSAO_QUALITY_LOW, "ssao_half": true,
		"ssil": false, "ssil_quality": RenderingServer.ENV_SSIL_QUALITY_LOW,
		"volumetric_fog": true, "fog_size": 64, "fog_depth": 64, "fog_filter": false,
		"glow": true,
	},
	Quality.HIGH: {
		"render_scale": 0.9, "fxaa": true, "lod_threshold": 1.0,
		"shadow_atlas": 4096, "soft_shadows": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
		"ssao": true, "ssao_quality": RenderingServer.ENV_SSAO_QUALITY_MEDIUM, "ssao_half": false,
		"ssil": true, "ssil_quality": RenderingServer.ENV_SSIL_QUALITY_LOW,
		"volumetric_fog": true, "fog_size": 96, "fog_depth": 96, "fog_filter": true,
		"glow": true,
	},
}

const AUTHORED_META := &"authored_graphics"

var _fps_label: Label
var _fps_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_fps_label()
	Settings.changed.connect(_on_setting_changed)
	get_tree().node_added.connect(_on_node_added)
	apply()


## The preset dictionary currently in use.
func current() -> Dictionary:
	return PRESETS[Settings.graphics_quality]


## Re-apply everything (global settings + every WorldEnvironment in the tree).
func apply() -> void:
	_apply_global()
	for node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		_apply_environment(node as WorldEnvironment)
	_fps_label.visible = Settings.show_fps


func _apply_global() -> void:
	var p := current()
	var viewport := get_tree().root
	viewport.scaling_3d_scale = p.render_scale
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if p.fxaa else Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.mesh_lod_threshold = p.lod_threshold
	viewport.positional_shadow_atlas_size = p.shadow_atlas
	RenderingServer.positional_soft_shadow_filter_set_quality(p.soft_shadows)
	RenderingServer.directional_soft_shadow_filter_set_quality(p.soft_shadows)
	RenderingServer.environment_set_ssao_quality(p.ssao_quality, p.ssao_half, 0.5, 2, 50.0, 300.0)
	RenderingServer.environment_set_ssil_quality(p.ssil_quality, true, 0.5, 2, 50.0, 300.0)
	RenderingServer.environment_set_volumetric_fog_volume_size(p.fog_size, p.fog_depth)
	RenderingServer.environment_set_volumetric_fog_filter_active(p.fog_filter)


func _apply_environment(world: WorldEnvironment) -> void:
	var env := world.environment
	if env == null:
		return
	if not env.has_meta(AUTHORED_META):
		env.set_meta(AUTHORED_META, {
			"ssao": env.ssao_enabled, "ssil": env.ssil_enabled,
			"volumetric_fog": env.volumetric_fog_enabled, "glow": env.glow_enabled,
		})
	var authored: Dictionary = env.get_meta(AUTHORED_META)
	var p := current()
	env.ssao_enabled = authored.ssao and p.ssao
	env.ssil_enabled = authored.ssil and p.ssil
	env.volumetric_fog_enabled = authored.volumetric_fog and p.volumetric_fog
	env.glow_enabled = authored.glow and p.glow


func _on_node_added(node: Node) -> void:
	if node is WorldEnvironment:
		_apply_environment(node)


func _on_setting_changed(key: StringName) -> void:
	if key == &"graphics_quality" or key == &"show_fps":
		apply()


func _process(delta: float) -> void:
	if not _fps_label.visible:
		return
	_fps_timer -= delta
	if _fps_timer > 0.0:
		return
	_fps_timer = 0.25
	var fps := Engine.get_frames_per_second()
	_fps_label.text = "%d FPS  %.1f ms" % [fps, 1000.0 / maxf(fps, 1.0)]


func _make_fps_label() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	_fps_label = Label.new()
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_fps_label.offset_left = -120
	_fps_label.offset_right = 120
	_fps_label.offset_top = 8
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fps_label.add_theme_font_size_override(&"font_size", 16)
	_fps_label.add_theme_color_override(&"font_color", Color(0.6, 1.0, 0.6))
	_fps_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_fps_label.add_theme_constant_override(&"outline_size", 4)
	layer.add_child(_fps_label)
