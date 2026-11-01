extends SceneTree
## Renders the poster/notice artwork (clean, un-aged) to tools/_build/posters/*.png.
## Godot does the text layout because it shapes Devanagari correctly. Afterwards
## `python tools/gen_decals.py` ages them (paper, stains, tears, fading) into assets/decals.
## Run (needs a window, not --headless):
##   <console exe> --path . --script res://tools/gen_posters.gd
## All text is fictional, set in March 1998 (Tape 1).

const OUT := "res://tools/_build/posters/"

# Each poster: size, paper colour, transparent background?, and lines of text.
# A line: [text, font family list, size, colour, bold?]
var posters := {
	"notice_water": {
		"size": Vector2i(560, 760), "bg": Color(0.95, 0.93, 0.84), "lines": [
			["SHANTI VIHAR CO-OP. HOUSING SOCIETY", ["Courier New"], 26, Color.BLACK, true],
			["शांति विहार को-ऑप. हाउसिंग सोसायटी", ["Nirmala UI"], 24, Color.BLACK, true],
			["", [], 12],
			["NOTICE  /  सूचना", ["Courier New"], 40, Color(0.55, 0.05, 0.05), true],
			["", [], 10],
			["Date: 08/03/1998", ["Courier New"], 20, Color.BLACK, false],
			["", [], 8],
			["All residents are hereby informed that water supply will remain closed on Sunday from 10 AM to 2 PM for cleaning of the overhead tank.", ["Courier New"], 22, Color.BLACK, false],
			["", [], 8],
			["Residents are requested to store sufficient water.", ["Courier New"], 22, Color.BLACK, false],
			["रहिवाशांनी पुरेसे पाणी साठवून ठेवावे.", ["Nirmala UI"], 20, Color.BLACK, false],
			["", [], 26],
			["By order,", ["Courier New"], 20, Color.BLACK, false],
			["Hon. Secretary", ["Courier New"], 22, Color.BLACK, true],
		]},
	"tuition": {
		"size": Vector2i(520, 720), "bg": Color(0.98, 0.62, 0.74), "lines": [
			["SUCCESS", ["Impact", "Arial Black"], 92, Color(0.1, 0.05, 0.35), true],
			["TUITION CLASSES", ["Impact", "Arial Black"], 46, Color(0.1, 0.05, 0.35), true],
			["", [], 10],
			["Std. VIII to XII  •  SSC / HSC", ["Arial"], 28, Color.BLACK, true],
			["", [], 12],
			["MATHS  •  SCIENCE  •  ENGLISH", ["Arial Black", "Arial"], 26, Color(0.7, 0.0, 0.1), true],
			["", [], 12],
			["Small batches. Personal attention.", ["Arial"], 24, Color.BLACK, false],
			["100% result in 1997!", ["Arial"], 24, Color.BLACK, true],
			["", [], 18],
			["Prof. S. Joshi, M.Sc.", ["Arial"], 26, Color.BLACK, true],
			["Ph: 2456 1180", ["Arial Black", "Arial"], 34, Color(0.1, 0.05, 0.35), true],
		]},
	"room_rent": {
		"size": Vector2i(500, 600), "bg": Color(0.96, 0.96, 0.94), "lines": [
			["ROOM ON RENT", ["Arial Black", "Arial"], 52, Color(0.05, 0.2, 0.55), true],
			["किराये से कमरा देना है", ["Nirmala UI"], 36, Color(0.05, 0.2, 0.55), true],
			["", [], 18],
			["1 RK  •  Water 24 hrs", ["Arial"], 28, Color.BLACK, false],
			["Bachelors allowed", ["Arial"], 28, Color.BLACK, false],
			["", [], 18],
			["Contact: Watchman cabin", ["Arial"], 28, Color.BLACK, true],
		]},
	"ganesh": {
		"size": Vector2i(560, 780), "bg": Color(0.99, 0.58, 0.12), "lines": [
			["॥ श्री गणेशाय नमः ॥", ["Nirmala UI"], 30, Color(0.5, 0.05, 0.0), true],
			["", [], 16],
			["सार्वजनिक", ["Nirmala UI"], 64, Color(0.55, 0.0, 0.0), true],
			["गणेशोत्सव १९९७", ["Nirmala UI"], 64, Color(0.55, 0.0, 0.0), true],
			["", [], 16],
			["Shanti Vihar Mitra Mandal", ["Arial Black", "Arial"], 30, Color(0.2, 0.05, 0.0), true],
			["", [], 12],
			["Aarti daily  •  8:00 PM", ["Arial"], 30, Color(0.15, 0.05, 0.0), true],
			["Visarjan: 16th September", ["Arial"], 26, Color(0.15, 0.05, 0.0), false],
			["", [], 12],
			["सर्वांना सस्नेह निमंत्रण", ["Nirmala UI"], 32, Color(0.5, 0.05, 0.0), true],
		]},
	"lost_dog": {
		"size": Vector2i(480, 640), "bg": Color(0.97, 0.97, 0.93), "lines": [
			["LOST DOG", ["Impact", "Arial Black"], 88, Color(0.75, 0.0, 0.0), true],
			["", [], 12],
			["\"MOTI\"", ["Arial Black", "Arial"], 54, Color.BLACK, true],
			["", [], 12],
			["Brown, white patch on left ear.", ["Arial"], 26, Color.BLACK, false],
			["Very friendly. Missing since 2nd March.", ["Arial"], 24, Color.BLACK, false],
			["", [], 18],
			["REWARD", ["Arial Black", "Arial"], 44, Color(0.75, 0.0, 0.0), true],
			["Please contact Flat 2C", ["Arial"], 28, Color.BLACK, true],
		]},
	"stencil_no_bills": {
		"size": Vector2i(900, 300), "bg": Color(0, 0, 0, 0), "lines": [
			["STICK NO BILLS", ["Arial Black", "Impact"], 92, Color(0.06, 0.06, 0.06), true],
			["पोस्टर चिपकाना मना है", ["Nirmala UI"], 56, Color(0.06, 0.06, 0.06), true],
		]},
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for name in posters:
		await _render(name, posters[name])
	print("posters done")
	quit()


func _render(name: String, spec: Dictionary) -> void:
	var size: Vector2i = spec.size
	var bg: Color = spec.bg
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = bg.a < 1.0
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var panel := ColorRect.new()
	panel.color = bg
	panel.size = Vector2(size)
	viewport.add_child(panel)

	var box := VBoxContainer.new()
	box.position = Vector2(28, 28)
	box.size = Vector2(size) - Vector2(56, 56)
	box.add_theme_constant_override(&"separation", 2)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	viewport.add_child(box)

	for line: Array in spec.lines:
		if line[0] == "":
			var spacer := Control.new()
			spacer.custom_minimum_size.y = line[2]
			box.add_child(spacer)
			continue
		var label := Label.new()
		label.text = line[0]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size.x = box.size.x
		var font := SystemFont.new()
		font.font_names = PackedStringArray(line[1] + ["Nirmala UI", "Arial"])
		font.font_weight = 800 if line[4] else 400
		label.add_theme_font_override(&"font", font)
		label.add_theme_font_size_override(&"font_size", line[2])
		label.add_theme_color_override(&"font_color", line[3])
		box.add_child(label)

	for i in 4:
		await process_frame
	var image := viewport.get_texture().get_image()
	image.save_png(OUT + name + ".png")
	viewport.queue_free()
