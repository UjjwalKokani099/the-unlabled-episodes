extends Node
## Applies the graphics preset (SettingsManager.graphics_quality) and draws the FPS counter.
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
		"ssr": false,
		"render_scale": 0.6, "fxaa": false, "lod_threshold": 4.0,
		"shadow_atlas": 2048, "soft_shadows": RenderingServer.SHADOW_QUALITY_HARD,
		"ssao": false, "ssao_quality": RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, "ssao_half": true,
		"ssil": false, "ssil_quality": RenderingServer.ENV_SSIL_QUALITY_VERY_LOW,
		"volumetric_fog": false, "fog_size": 64, "fog_depth": 48, "fog_filter": false,
		"glow": true,
	},
	Quality.MEDIUM: {
		"ssr": false,
		"render_scale": 0.75, "fxaa": true, "lod_threshold": 2.0,
		"shadow_atlas": 4096, "soft_shadows": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		"ssao": true, "ssao_quality": RenderingServer.ENV_SSAO_QUALITY_LOW, "ssao_half": true,
		"ssil": false, "ssil_quality": RenderingServer.ENV_SSIL_QUALITY_LOW,
		"volumetric_fog": true, "fog_size": 64, "fog_depth": 64, "fog_filter": false,
		"glow": true,
	},
	Quality.HIGH: {
		"ssr": true,
		"render_scale": 0.9, "fxaa": true, "lod_threshold": 1.0,
		"shadow_atlas": 4096, "soft_shadows": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
		"ssao": true, "ssao_quality": RenderingServer.ENV_SSAO_QUALITY_MEDIUM, "ssao_half": false,
		"ssil": true, "ssil_quality": RenderingServer.ENV_SSIL_QUALITY_LOW,
		"volumetric_fog": true, "fog_size": 96, "fog_depth": 96, "fog_filter": true,
		"glow": true,
	},
}

const AUTHORED_META := &"authored_graphics"
## 3D render scale in PS1 mode (1080p -> 540 lines, then pixelated to 480).
const PS1_RENDER_SCALE := 0.5

## Value of the global shader parameter `ps1_amount` (0 = off, 1 = PS1 mode).
var ps1_amount: float = 0.0
var _fps_label: Label
## Full-screen film grade (assets/shaders/film_grade.gdshader) on canvas layer 1.
var _grade: ColorRect
var _fps_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_fps_label()
	_make_grade_layer()
	SettingsManager.changed.connect(_on_setting_changed)
	get_tree().node_added.connect(_on_node_added)
	apply()


## The preset dictionary currently in use.
func current() -> Dictionary:
	return PRESETS[SettingsManager.graphics_quality]


## Re-apply everything (global settings + every WorldEnvironment in the tree).
func apply() -> void:
	_apply_global()
	for node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		_apply_environment(node as WorldEnvironment)
	for node in get_tree().root.find_children("*", "VoxelGI", true, false):
		_apply_voxel_gi(node as VoxelGI)
	_fps_label.visible = SettingsManager.show_fps
	_grade.visible = SettingsManager.film_look > 0.0
	_grade.material.set_shader_parameter(&"amount", SettingsManager.film_look)


func _apply_global() -> void:
	var p := current()
	var viewport := get_tree().root
	var ps1 := SettingsManager.ps1_mode
	# PS1 mode: the picture ends up pixelated to 480 lines anyway (assets/shaders/ps1_post), so
	# render 3D at half resolution and skip anti-aliasing (crunchy edges are the look).
	viewport.scaling_3d_scale = minf(p.render_scale, PS1_RENDER_SCALE) if ps1 else p.render_scale
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if (p.fxaa and not ps1) else Viewport.SCREEN_SPACE_AA_DISABLED
	ps1_amount = 1.0 if ps1 else 0.0
	RenderingServer.global_shader_parameter_set(&"ps1_amount", ps1_amount)
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
			"ssr": env.ssr_enabled,
		})
	var authored: Dictionary = env.get_meta(AUTHORED_META)
	var p := current()
	env.ssao_enabled = authored.ssao and p.ssao
	env.ssil_enabled = authored.ssil and p.ssil
	env.volumetric_fog_enabled = authored.volumetric_fog and p.volumetric_fog
	env.glow_enabled = authored.glow and p.glow
	# Screen-space reflections (polished tiles, wet ground, glass): High only.
	env.ssr_enabled = authored.get("ssr", false) and p.ssr


## Baked bounce light: off on Low, low quality on Medium, full on High.
func _apply_voxel_gi(gi: VoxelGI) -> void:
	gi.visible = SettingsManager.graphics_quality > Quality.LOW
	RenderingServer.voxel_gi_set_quality(RenderingServer.VOXEL_GI_QUALITY_HIGH if SettingsManager.graphics_quality == Quality.HIGH else RenderingServer.VOXEL_GI_QUALITY_LOW)


func _on_node_added(node: Node) -> void:
	if node is WorldEnvironment:
		_apply_environment(node)
	elif node is VoxelGI:
		_apply_voxel_gi(node)


func _on_setting_changed(key: StringName) -> void:
	if key == &"graphics_quality" or key == &"show_fps" or key == &"ps1_mode" or key == &"film_look":
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


## Fear level 0..1 for the film grade (darker edges, less colour, more grain). The Stalker's
## exposure and scripted scares can drive it.
func set_dread(value: float) -> void:
	_grade.material.set_shader_parameter(&"dread", clampf(value, 0.0, 1.0))


## Layer 1, added before any level: drawn under the camcorder's PS1/tape-cut rects
## (also layer 1, later in the tree), the OSD (2), the VHS effect (3) and the HUD (10).
func _make_grade_layer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	_grade = ColorRect.new()
	_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/film_grade.gdshader")
	_grade.material = mat
	layer.add_child(_grade)


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
