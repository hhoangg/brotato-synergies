# Lean in-run skill HUD for the Co-op Synergies mod. A full-screen Control under a high CanvasLayer.
# Shows one mini-card per co-op player: tier, cooldown countdown (or READY / locked Lv), with a flash
# on cast and a build watermark. This is the PRECURSOR to the per-life-bar widget in the spec —
# placement polish (anchoring beside each player's life bar) + skill icon/name come later. It only
# DISPLAYS state the controller pushes in; no game logic here.
extends Control

const Config = preload("res://mods-unpacked/tato-Synergies/config.gd")

const FLASH_DECAY := 2.5
const COL_BG := Color(0.07, 0.07, 0.09, 0.82)
const COL_BORDER := Color(0.85, 0.80, 0.65, 0.30)
const COL_TEXT := Color(0.92, 0.90, 0.82)
const COL_DIM := Color(0.60, 0.60, 0.65)
const COL_READY := Color(1.0, 0.90, 0.42)
const COL_CD := Color(0.55, 0.65, 0.95)
const COL_FLASH := Color(1.0, 0.82, 0.25)
const COL_BAR := Color(0.82, 0.73, 0.26, 0.9)
const COL_BUFF := Color(0.45, 0.92, 0.55)        # active-effect text (green)
const COL_BUFF_BAR := Color(0.38, 0.85, 0.48, 0.9)
const COL_PIP_OFF := Color(0.30, 0.30, 0.34)
const COL_CD_SWEEP := Color(0.04, 0.04, 0.06, 0.66)
const ICON := 52.0
const SKILL_HUD_X := 475.0   # fixed left offset hugging the right of the top-left HP/XP bars
# Brotato-ish per-player accent colours (P0..P3).
const PLAYER_COLS := [Color(0.90, 0.32, 0.32), Color(0.32, 0.56, 0.92), Color(0.38, 0.80, 0.40), Color(0.93, 0.78, 0.32)]

var _states := []   # [{place, slug, unlocked, unlock_level, tier, cd, cd_total, buff, buff_total}]
var _icon_cache := {}   # slug -> ImageTexture (or null if no/over-bad png)
var _lifebars := {}     # place -> the game's life-bar Control (cached) for anchoring
var _icon_px := ICON    # icon size — grown to span the HP + XP bars (+ gap) once measured
var _lifebar_dumped := false
var _pos_logged := false
var _layer_synced := false
var _flash := {}    # place:int -> 0..1
var _active := false
var _font = null
var _affinities := []   # [{label, label_vi, count, stats}] — active faction traits, drawn on the left
const COL_AFF := Color(0.78, 0.66, 0.98)         # affinity header (arcane purple)
const COL_NERF := Color(0.95, 0.55, 0.50)        # nerf text (red)


func _ready() -> void:
	set_anchors_and_margins_preset(Control.PRESET_WIDE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_mode = Node.PAUSE_MODE_PROCESS
	_font = load("res://resources/fonts/actual/base/font_26_outline.tres")
	set_process(true)


func update_states(states: Array) -> void:
	_states = states
	update()


func note_cast(place: int) -> void:
	_flash[place] = 1.0
	update()


func update_affinities(a: Array) -> void:
	_affinities = a
	update()


func set_active(a: bool) -> void:
	if a == _active:
		return
	_active = a
	update()


func _process(delta: float) -> void:
	var any := false
	for p in _flash.keys():
		if _flash[p] > 0.0:
			_flash[p] = max(0.0, _flash[p] - delta * FLASH_DECAY)
			any = true
	if any:
		update()


func _vp_size() -> Vector2:
	var o : Vector2 = get_viewport().get_size_override()
	if o.x > 0 and o.y > 0:
		return o
	return get_viewport().size


func _text(pos: Vector2, s: String, col: Color) -> void:
	if _font != null:
		_font.draw(get_canvas_item(), pos, s, col)


func _draw() -> void:
	var sz := _vp_size()
	# Build watermark — TEST builds only (confirms the loaded build at a glance during local testing).
	# Hidden in published builds so players don't see a version stamp on the char-select screen.
	if Config.TEST_MODE:
		_text(Vector2(sz.x - 250, sz.y - 12), "tato-Synergies v" + Config.MOD_VERSION + "  [TEST]", COL_READY)
	if not _active:
		return
	var idx := 0
	for st in _states:
		var p := _widget_pos(int(st["place"]), idx)
		_draw_widget(p.x, p.y, st)
		idx += 1
	_draw_affinities(sz)


# Anchor beside the player's HUD cluster. The game's per-player container is UI/HUD/LifeContainerP<n>
# (1-indexed) — learned from the DmgMeter mod, which parents its UI there. Anchoring to its global rect
# puts the widget right beside the HP/XP bars; fixed fallback if the path isn't present.
func _widget_pos(place: int, idx: int) -> Vector2:
	var lc = _lifebar_for(place)
	if lc != null and is_instance_valid(lc) and (lc is Control):
		var r : Rect2 = lc.get_global_rect()
		# co-op: a player whose HUD sits on the right half gets the widget to the LEFT of their bars
		# (mirrored); left-half players keep it to the right.
		if r.position.x + r.size.x * 0.5 > _vp_size().x * 0.5:
			return Vector2(r.position.x - _icon_px - 12.0, r.position.y)
		return Vector2(r.end.x + 12.0, r.position.y)
	return Vector2(SKILL_HUD_X, 36.0 + idx * (_icon_px + 30.0))


# The per-player HUD container: current_scene → "UI/HUD/LifeContainerP<place+1>" (direct path).
func _lifebar_for(place: int):
	if _lifebars.has(place):
		var n = _lifebars[place]
		if n != null and is_instance_valid(n):
			return n
	var scene = get_tree().current_scene
	var found = null
	if scene != null:
		found = scene.get_node_or_null("UI/HUD/LifeContainerP" + str(place + 1))
	_lifebars[place] = found
	if found != null and not _lifebar_dumped:
		_lifebar_dumped = true
		var rs = str(found.get_global_rect()) if (found is Control) else "-"
		print("[Synergies][api] LifeContainerP%d rect=%s" % [place + 1, rs])
		_compute_icon_px(found)
	if found != null and not _layer_synced:
		_layer_synced = true
		_sync_layer(found)
	return found


# Icon size ≈ the HP + XP bars + gap. The bars aren't TextureProgress (couldn't find by class), but
# they sit in the top ~40% of the LifeContainer (which also holds gold/weapons below), so derive from
# its height. Also dump the container's children once to locate the exact bars for later refinement.
func _compute_icon_px(lc) -> void:
	if not (lc is Control):
		return
	var h : float = lc.get_global_rect().size.y
	if h > 30.0:
		# reserve ~16px below the icon for the tier-pip row, so icon + pips together span the bars' height
		_icon_px = clamp(h * 0.42 - 16.0, 56.0, 104.0)
	for ch in lc.get_children():
		var rs = str(ch.get_global_rect()) if (ch is Control) else "-"
		print("[Synergies][api] LC-child '%s' class=%s rect=%s" % [String(ch.name), ch.get_class(), rs])
	print("[Synergies][api] LC height=%.0f -> icon_px=%.0f" % [h, _icon_px])


# Sink our HUD onto the same CanvasLayer level as the player HUD, so the pause/shop menus cover it too
# (instead of floating on top). The widget keeps drawing but now sits behind those menus.
func _sync_layer(bar_node) -> void:
	var n = bar_node
	while n != null and not (n is CanvasLayer):
		n = n.get_parent()
	if n == null or not (n is CanvasLayer):
		return
	var mine = get_parent()
	if mine != null and (mine is CanvasLayer):
		mine.layer = n.layer
		print("[Synergies][api] synced HUD CanvasLayer to layer %d (life bar)" % n.layer)


# One per-player skill widget: icon + player-colour border, radial cooldown sweep + secs, tier pips,
# ready glow + button glyph, locked Lv label, and the green active-effect countdown.
func _draw_widget(x: float, y: float, st: Dictionary) -> void:
	var place : int = st["place"]
	var f : float = _flash.get(place, 0.0)
	var unlocked : bool = bool(st["unlocked"])
	var cd : float = float(st["cd"])
	var cd_total : float = float(st["cd_total"])
	var tier : int = int(st["tier"])
	var sz : float = _icon_px
	var icon_rect := Rect2(x, y, sz, sz)
	var center := Vector2(x + sz / 2.0, y + sz / 2.0)
	var tex = _icon_for(String(st.get("slug", "")))

	# icon (or a labelled fallback box when the char has no art yet, e.g. gladiator)
	var mod := COL_TEXT
	if not unlocked:
		mod = Color(0.42, 0.42, 0.48)        # locked → dim/grey
	elif cd > 0.0:
		mod = Color(0.74, 0.74, 0.80)        # cooling → slightly dim
	if f > 0.0:
		mod = mod.linear_interpolate(COL_FLASH, f * 0.85)
	if tex != null:
		draw_texture_rect(tex, icon_rect, false, mod)
	else:
		draw_rect(icon_rect, COL_BG)
		_text(Vector2(x + 8, center.y + 6), "P%d" % place, mod)

	# cooldown radial sweep over the icon (full dark right after cast → shrinks to empty = ready)
	if unlocked and cd > 0.0 and cd_total > 0.0:
		_draw_radial(center, sz / 2.0, clamp(cd / cd_total, 0.0, 1.0), COL_CD_SWEEP)
		_text(Vector2(center.x - 14, center.y + 8), "%.1f" % cd, COL_TEXT)

	# state hints (no border — keep it clean)
	var ready : bool = unlocked and cd <= 0.0
	if not unlocked:
		_text(Vector2(x + 6, center.y + 6), "Lv%d" % int(st["unlock_level"]), COL_DIM)

	# tier pips centered under the icon
	if unlocked:
		_draw_pips(x + sz / 2.0, y + sz + 12.0, tier)

	# active-effect countdown (green) to the right of the icon
	var buff : float = float(st.get("buff", 0.0))
	if buff > 0.0:
		_text(Vector2(x + sz + 12, y + 24), "%.1fs" % buff, COL_BUFF)
		var bt : float = float(st.get("buff_total", 0.0))
		if bt > 0.0:
			draw_rect(Rect2(x + sz + 12, y + 32, 64.0 * clamp(buff / bt, 0.0, 1.0), 4), COL_BUFF_BAR)


# Active faction traits, listed down the left edge during a wave (label + member count).
func _draw_affinities(sz: Vector2) -> void:
	if _affinities.empty():
		return
	var vi : bool = TranslationServer.get_locale().substr(0, 2) == "vi"
	var x := 14.0
	var y : float = sz.y * 0.30
	_text(Vector2(x, y), "— PHE —" if vi else "— SYNERGIES —", COL_AFF)
	y += 22.0
	for aff in _affinities:
		var label : String = String(aff.get("label_vi", "?")) if vi else String(aff.get("label", "?"))
		_text(Vector2(x, y), "%s  x%d" % [label, int(aff.get("count", 0))], COL_BUFF)
		y += 19.0


# Dark pie wedge from 12 o'clock, spanning `frac` of the circle.
func _draw_radial(center: Vector2, radius: float, frac: float, color: Color) -> void:
	if frac <= 0.0:
		return
	var pts := PoolVector2Array()
	pts.append(center)
	var steps := 28
	for i in range(steps + 1):
		var a : float = -PI / 2.0 + TAU * frac * (float(i) / steps)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, color)


func _draw_border(r: Rect2, c: Color, w: float) -> void:
	for i in range(int(w)):
		draw_rect(Rect2(r.position - Vector2(i, i), r.size + Vector2(i * 2, i * 2)), c, false)


func _draw_pips(center_x: float, top_y: float, tier: int) -> void:
	var n := Config.MAX_TIER
	var spacing := 11.0
	var start_x : float = center_x - (n - 1) * spacing / 2.0   # center the row under the icon
	for i in range(n):
		draw_circle(Vector2(start_x + i * spacing, top_y), 3.5, COL_READY if i < tier else COL_PIP_OFF)


# Load a skill icon PNG from the (zip-mounted) mod assets. Raw mod PNGs aren't import-cooked, so
# load() fails — read the bytes and decode with load_png_from_buffer. Cached per slug.
func _icon_for(slug: String):
	if slug == "":
		return null
	if _icon_cache.has(slug):
		return _icon_cache[slug]
	var tex = null
	var path : String = Config.SKILLS_ICON_DIR + "/" + slug + ".png"
	var fh := File.new()
	if fh.file_exists(path) and fh.open(path, File.READ) == OK:
		var buf := fh.get_buffer(fh.get_len())
		fh.close()
		var img := Image.new()
		if img.load_png_from_buffer(buf) == OK:
			var t := ImageTexture.new()
			t.create_from_image(img, Texture.FLAG_FILTER | Texture.FLAG_MIPMAPS)
			tex = t
	_icon_cache[slug] = tex
	return tex
