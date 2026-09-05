# Character Codex tab — injects a 5th tab into the game's Codex menu (next to Challenges/Items/
# Weapons/Enemies). Left = an 8-column grid of every character; right = the focused character's
# detail: a card (icon + name) on top, then the game's char-select stats + the Synergies skill.
#
# A persistent watcher node (same pattern as lib/charsel_panel.gd): it polls for the codex Popup,
# injects once per open, and re-injects when the codex is reopened (the popup is freed on close).
extends Node

const Config = preload("res://mods-unpacked/tato-Synergies/config.gd")
const CharselPanel = preload("res://mods-unpacked/tato-Synergies/lib/charsel_panel.gd")

const TAB_THEME := "res://resources/themes/tab_buttons_physic.tres"
const F_NAME := "res://resources/fonts/actual/base/font_26.tres"
const F_BODY := "res://resources/fonts/actual/base/font_22.tres"

const COL_GREEN := Color("#8ff04e")
const COL_TEXT := Color("#e8efe0")
const COL_MUTED := Color("#9aa890")
const COL_RED := Color("#e06d5a")
const COL_OLIVE := Color(0.258824, 0.278431, 0.239216, 1.0)  # the codex page/screen olive
const COL_BORDER := Color("#3c4a33")
const COL_CELL := Color(0, 0, 0, 0.22)

# Character stat keys rendered as a percentage (the rest are flat numbers).
const PCT_STATS := {
	"stat_damage": true, "stat_melee_damage": true, "stat_ranged_damage": true,
	"stat_elemental_damage": true, "stat_attack_speed": true, "stat_speed": true,
	"stat_dodge": true, "stat_crit_chance": true, "stat_lifesteal": true, "stat_xp_gain": true,
}
const STAT_NAME := {
	"stat_attack_speed": "Attack Speed", "stat_luck": "Luck", "stat_crit_chance": "Crit Chance",
	"stat_armor": "Armor", "stat_max_hp": "Max HP", "stat_speed": "Speed", "stat_damage": "Damage",
	"stat_dodge": "Dodge", "stat_ranged_damage": "Ranged Damage", "stat_range": "Range",
	"stat_lifesteal": "Life Steal", "stat_hp_regeneration": "HP Regeneration", "stat_harvesting": "Harvesting",
	"stat_engineering": "Engineering", "stat_melee_damage": "Melee Damage", "stat_elemental_damage": "Elemental Damage",
	"stat_xp_gain": "XP Gain", "stat_percent_damage": "Damage", "stat_piercing": "Piercing",
	"stat_bounce": "Bounces", "stat_knockback": "Knockback", "stat_explosion_damage": "Explosion Damage",
}
const ROLE_NAME := {
	"support": "Support", "ad": "Carry", "caster": "Caster", "tank": "Tank",
	"late": "Late", "skirmisher": "Skirmisher", "flex": "Flex",
}

var _codex = null         # current menu_codex Popup
var _injected := false
var _tabc = null          # the codex TabContainer
var _my_page = null       # my injected page
var _my_btn = null        # my injected tab button
var _my_index := -1
var _grid = null          # the 8-col character grid
var _detail_box = null    # the right detail column (cleared + rebuilt per character)
var _cur_slug := ""
var _scan_t := 0.0
var _tab_theme = null
var _hbox = null          # the codex tab-button row
var _f_name = null
var _f_body = null
var _icon_cache := {}     # slug -> game character icon Texture
var _data_cache := {}     # slug -> CharacterData (lazy; the .tres pulls in weapons so load on demand)
var _card_factory = null  # a detached CharselPanel used only to build the exact skill card


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	_tab_theme = _try_load(TAB_THEME)
	_f_name = _try_load(F_NAME)
	_f_body = _try_load(F_BODY)
	set_process(true)


func _process(delta: float) -> void:
	# Re-acquire the codex popup when it's gone (freed on close).
	if _codex == null or not is_instance_valid(_codex):
		_codex = null
		_injected = false
		_tabc = null
		_scan_t += delta
		if _scan_t < 0.3:
			return
		_scan_t = 0.0
		# The Codex is a main-menu screen — skip the tree scan during an active run (the "Main"
		# gameplay scene), so we don't walk a huge wave tree every tick.
		var scn = get_tree().current_scene
		if scn != null and scn.name == "Main":
			return
		_codex = _find_codex()
		if _codex == null:
			return
	if not _injected and _codex.visible:
		_inject()


# ---------------------------------------------------------------------------
# Detect + inject
# ---------------------------------------------------------------------------

# Find the codex by STRUCTURE (any node carrying the codex tab tree), not by name — instanced
# scene roots can be renamed, so a name match ("menu_codex") is unreliable.
func _find_codex():
	return _scan_codex(get_tree().root)


func _scan_codex(node):
	if node == null:
		return null
	if node.has_node("root/BetterTabContainer/TabContainer") and node.has_node("root/HBoxContainer"):
		return node
	for c in node.get_children():
		var r = _scan_codex(c)
		if r != null:
			return r
	return null


func _inject() -> void:
	_hbox = _codex.get_node_or_null("root/HBoxContainer")
	_tabc = _codex.get_node_or_null("root/BetterTabContainer/TabContainer")
	if _hbox == null or _tabc == null:
		print("[Synergies][codex] inject abort: hbox=%s tabc=%s" % [str(_hbox != null), str(_tabc != null)])
		return

	# My page (a codex-styled panel holding the grid + detail).
	_my_page = _build_page()
	_tabc.add_child(_my_page)
	_my_index = _my_page.get_index()

	# My tab button on the neck, before the right end-cap spacer.
	_my_btn = _build_tab_button()
	_my_btn.name = "but_tab_characters"
	_hbox.add_child(_my_btn)
	var tsr = _hbox.get_node_or_null("tab_space_right")
	if tsr != null:
		_hbox.move_child(_my_btn, tsr.get_index())
	# Join the game's tab ButtonGroup (the codex tabs are toggle buttons in a radio group). That
	# makes the toggle "pressed" state — and the green active look — exclusive across all 5 tabs.
	var first_tab = _hbox.get_node_or_null("but_tab_challenger")
	if first_tab != null and ("group" in first_tab) and first_tab.group != null:
		_my_btn.toggle_mode = true
		_my_btn.group = first_tab.group
	_my_btn.connect("pressed", self, "_on_my_tab")
	_sync_shoulder_tabs()   # keep LB/RB (shoulder) swap from crashing on my tab — see below
	_wire_focus()   # keyboard/gamepad: enemies-tab <-> my tab <-> Back
	_fit_tabs()     # let all 5 tabs share the fixed neck width (the game tabs won't shrink on their own)

	_injected = true
	_populate_grid()
	print("[Synergies][codex] character tab injected (page index %d, %d chars)" % [_my_index, _grid.get_child_count()])


# Wire my tab into the codex focus chain so "->" from the Enemies tab lands on it (not the Back button).
func _wire_focus() -> void:
	var enemies = _hbox.get_node_or_null("but_tab_enemies")
	if enemies != null:
		enemies.focus_neighbour_right = NodePath("../but_tab_characters")
		enemies.focus_next = NodePath("../but_tab_characters")
		_my_btn.focus_neighbour_left = NodePath("../but_tab_enemies")
		_my_btn.focus_previous = NodePath("../but_tab_enemies")
	_my_btn.focus_neighbour_right = NodePath(".")
	_my_btn.focus_next = NodePath("../../../BackButton")
	_my_btn.focus_neighbour_top = NodePath("../../../BackButton")
	_my_btn.focus_neighbour_bottom = NodePath(".")


# Fit FIVE tabs inside the neck's MIDDLE zone (the painted 4-notch area), keeping the two end-cap
# spacers fixed so the tabs don't spill onto the tablet's shoulders. Buttons EXPAND to share the
# middle; the non-Button children (tab_space_left/right) are pinned to a fixed end-cap width.
func _fit_tabs() -> void:
	for c in _hbox.get_children():
		if c is Button:
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			c.rect_min_size = Vector2(0, c.rect_min_size.y)
		else:
			c.size_flags_horizontal = Control.SIZE_FILL  # no EXPAND → keeps its fixed width
			c.rect_min_size = Vector2(236, c.rect_min_size.y)


func _build_tab_button() -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	# Compact + expand so all FIVE tabs share the fixed neck width without overflowing.
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.rect_min_size = Vector2(40, 0)
	if _tab_theme != null:
		b.theme = _tab_theme
	# A character egg as the tab icon (well_rounded — universally "character").
	var ico = _game_icon("well-rounded")
	if ico != null:
		b.icon = ico
		b.expand_icon = true
		b.icon_align = 1  # center, like the game's tab icons (else it sits left)
	else:
		b.text = "CHARS"
	return b


# A codex-style page: HBox [ grid (scroll) | divider | detail (scroll) ].
func _build_page() -> Control:
	var page := PanelContainer.new()
	page.add_stylebox_override("panel", _flat(COL_OLIVE, COL_BORDER, 0, 10, 14))

	var split := HBoxContainer.new()
	split.add_constant_override("separation", 16)
	page.add_child(split)

	# Left: 8-column character grid in a scroll container.
	var gscroll := ScrollContainer.new()
	gscroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gscroll.size_flags_stretch_ratio = 1.15
	gscroll.scroll_horizontal_enabled = false
	split.add_child(gscroll)

	_grid = GridContainer.new()
	_grid.columns = 8
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_constant_override("hseparation", 8)
	_grid.add_constant_override("vseparation", 8)
	gscroll.add_child(_grid)

	# Divider.
	var div := Panel.new()
	div.rect_min_size = Vector2(2, 0)
	div.add_stylebox_override("panel", _flat(COL_BORDER, COL_BORDER, 0, 0, 0))
	split.add_child(div)

	# Right: detail in a scroll container.
	var dscroll := ScrollContainer.new()
	dscroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dscroll.size_flags_stretch_ratio = 1.0
	dscroll.scroll_horizontal_enabled = false
	split.add_child(dscroll)

	_detail_box = VBoxContainer.new()
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_box.add_constant_override("separation", 8)
	dscroll.add_child(_detail_box)

	return page


func _populate_grid() -> void:
	if _grid == null:
		return
	var first := ""
	for slug in Config.SKILLS.keys():
		var cell := _grid_cell(String(slug))
		_grid.add_child(cell)
		if first == "":
			first = String(slug)
	if first != "":
		_show_char(first)


func _grid_cell(slug: String) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.rect_min_size = Vector2(82, 82)
	b.add_stylebox_override("normal", _flat(COL_CELL, COL_BORDER, 1, 8, 4))
	b.add_stylebox_override("hover", _flat(COL_CELL, COL_GREEN, 2, 8, 4))
	b.add_stylebox_override("pressed", _flat(COL_CELL, COL_GREEN, 2, 8, 4))
	b.add_stylebox_override("focus", _flat(COL_CELL, COL_GREEN, 2, 8, 4))
	var ico = _game_icon(slug)
	if ico != null:
		b.icon = ico
		b.expand_icon = true
	else:
		b.text = "?"
	b.connect("focus_entered", self, "_show_char", [slug])
	b.connect("mouse_entered", self, "_show_char", [slug])
	return b


# ---------------------------------------------------------------------------
# Detail panel (rebuilt per focused character)
# ---------------------------------------------------------------------------

func _show_char(slug: String) -> void:
	if slug == _cur_slug or _detail_box == null:
		return
	_cur_slug = slug
	for c in _detail_box.get_children():
		c.queue_free()

	var short := _short_for(slug)
	var skill = Config.SKILLS.get(slug, null)

	# --- Card: big icon + name + role ---
	var card := PanelContainer.new()
	card.add_stylebox_override("panel", _flat(Color(0, 0, 0, 0.25), COL_BORDER, 1, 10, 12))
	var crow := HBoxContainer.new()
	crow.add_constant_override("separation", 14)
	card.add_child(crow)
	crow.add_child(_icon_rect(_game_icon(slug), 84))
	var cinfo := VBoxContainer.new()
	cinfo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cinfo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cinfo.add_constant_override("separation", 2)
	cinfo.add_child(_label(_char_name(short), _f_name, COL_TEXT))
	var subtitle := "Character"
	if skill != null and skill.has("role"):
		subtitle = "Character  ·  " + _role_label(String(skill["role"]))
	cinfo.add_child(_label(subtitle, _f_body, COL_MUTED))
	crow.add_child(cinfo)
	_detail_box.add_child(card)

	# --- Stats: the game's OWN char-select effect text (exact wording + colours via effect.get_text) ---
	_detail_box.add_child(_label("STATS", _f_body, COL_MUTED))
	var any := false
	var cdata = _char_data(slug)
	var ceffects = cdata.get("effects") if cdata != null else null
	var safe : bool = _run_player_count() > 0
	if typeof(ceffects) == TYPE_ARRAY:
		for e in ceffects:
			var w = _effect_line(e, safe)
			if w != null:
				_detail_box.add_child(w)
				any = true
	if not any:
		_detail_box.add_child(_label("—", _f_body, COL_MUTED))

	# --- Skill: the EXACT char-select skill card (reused from charsel_panel) ---
	if skill != null:
		_detail_box.add_child(_spacer(8))
		_detail_box.add_child(_skill_card(slug, skill))


# One character effect → the game's own localised, coloured text (via effect.get_text). Effects with
# pre-set custom_args can scale off the player (RunData); outside a run we fall back so we never crash.
func _effect_line(e, safe: bool):
	if e == null:
		return null
	var has_custom : bool = ("custom_args" in e) and e.custom_args != null and e.custom_args.size() > 0
	if has_custom and not safe:
		return _effect_widget(e)   # scaling effect, no run → safe approximation
	if not e.has_method("get_text"):
		return _effect_widget(e)
	var txt = e.get_text(0, true)  # BBCode-coloured, exactly as the char-select renders it
	if txt == null or String(txt) == "":
		return null
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content_height = true
	rt.scroll_active = false
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _f_body != null:
		rt.add_font_override("normal_font", _f_body)
	rt.bbcode_text = String(txt)
	return rt


# How many players the game currently has (0 outside a run) — gates the scaling-effect path above.
func _run_player_count() -> int:
	var rd = get_tree().root.get_node_or_null("RunData")
	if rd == null:
		return 0
	var pd = rd.get("players_data")
	if typeof(pd) == TYPE_ARRAY:
		return pd.size()
	return 0


# Build the exact char-select skill card by reusing charsel_panel's own builder (a detached instance,
# never added to the tree, so its char-select watcher never runs). Hides the co-op faction section.
func _skill_card(slug: String, skill):
	if _card_factory == null:
		_card_factory = CharselPanel.new()
	var node = _card_factory._build_node()
	_card_factory._update_node(node, slug, skill, {}, false)
	var fac = node.get_node_or_null("Factions")
	if fac != null:
		fac.visible = false
	return node


func _stat_row(name: String, value: String, positive: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_constant_override("separation", 8)
	var v := _label(value, _f_body, COL_GREEN if positive else COL_RED)
	v.rect_min_size = Vector2(110, 0)
	row.add_child(v)
	var n := _label(name, _f_body, COL_TEXT)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(n)
	return row


# ---------------------------------------------------------------------------
# Character data
# ---------------------------------------------------------------------------

# Render one character effect into a row, mirroring the game's char-select info. Returns null for
# effect types we don't format (so they're skipped rather than shown wrong).
func _effect_widget(e):
	if e == null or not ("key" in e):
		return null
	var key := String(e.key)
	var val = e.get("value")
	# Stat-gain modifier — e.g. Mage: "Elemental Damage modifications are increased by 25%".
	if key == "effect_increase_stat_gains" or key == "effect_reduce_stat_gains":
		var stat := ""
		if "stat_displayed" in e:
			stat = _stat_label(String(e.stat_displayed))
		var iv := int(val)
		var verb := "increased" if iv >= 0 else "reduced"
		return _wrap_label("%s modifications are %s by %d%%" % [stat, verb, abs(iv)], COL_GREEN if iv >= 0 else COL_RED)
	# Plain stat — "+5 Max HP" (value coloured on the left, name on the right).
	if key.begins_with("stat_"):
		if typeof(val) != TYPE_INT and typeof(val) != TYPE_REAL:
			return null
		var positive : bool = val >= 0
		var pfx := "+" if positive else ""
		var pct := "%" if PCT_STATS.has(key) else ""
		return _stat_row(_stat_label(key), pfx + str(val) + pct, positive)
	# Starting item.
	if key.begins_with("item_"):
		return _wrap_label("Starting item: " + _item_name(key), COL_TEXT)
	return null


func _wrap_label(text: String, color: Color) -> Label:
	var l := _label(text, _f_body, color)
	l.autowrap = true
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _item_name(key: String) -> String:
	var up := key.to_upper()
	var t := tr(up)
	if t != up and t != "":
		return t
	var s := key
	if s.begins_with("item_"):
		s = s.substr(5)
	var out := []
	for part in s.split("_"):
		if part.length() > 0:
			out.append(part.substr(0, 1).to_upper() + part.substr(1))
	return PoolStringArray(out).join(" ")


func _char_data(slug: String):
	if _data_cache.has(slug):
		return _data_cache[slug]
	var short := _short_for(slug)
	var data = null
	for p in _game_paths(short, "_data.tres"):
		if ResourceLoader.exists(p):
			data = load(p)
			break
	_data_cache[slug] = data
	return data


# ---------------------------------------------------------------------------
# Tab switching
# ---------------------------------------------------------------------------

func _on_my_tab() -> void:
	if _tabc != null:
		_tabc.current_tab = _my_index


# The codex's UIBetterTabContainer maps LB/RB (the "ltrigger"/"rtrigger" actions) to tab swapping via
# _change_tab(), which indexes its own `buttons_tab` array by the tab index. That array is built ONCE in
# _ready() from the game's original 4 tabs — but I added a 5th TabContainer page, so reaching my tab
# (index 4) did `buttons_tab[4]` on a size-4 array → out-of-bounds crash on Steam Deck. Append my button
# so the shoulder-swap array stays in lockstep with the TabContainer's pages.
func _sync_shoulder_tabs() -> void:
	var btc = _codex.get_node_or_null("root/BetterTabContainer")
	if btc == null or not ("buttons_tab" in btc):
		return
	var arr = btc.buttons_tab
	if typeof(arr) == TYPE_ARRAY and not (_my_btn in arr):
		arr.append(_my_btn)


# -----------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _short_for(slug: String) -> String:
	if slug == "one-armed":
		return "one_arm"
	return slug.replace("-", "_")


func _game_paths(short: String, suffix: String) -> Array:
	return [
		"res://items/characters/%s/%s%s" % [short, short, suffix],
		"res://dlcs/dlc_1/characters/%s/%s%s" % [short, short, suffix],
		"res://dlcs/dlc_2/characters/%s/%s%s" % [short, short, suffix],
	]


func _game_icon(slug: String):
	if _icon_cache.has(slug):
		return _icon_cache[slug]
	var short := _short_for(slug)
	var tex = null
	for p in _game_paths(short, "_icon.png"):
		if ResourceLoader.exists(p):
			tex = load(p)
			break
	_icon_cache[slug] = tex
	return tex


func _char_name(short: String) -> String:
	var key := "CHARACTER_" + short.to_upper()
	var t := tr(key)
	if t != key and t != "":
		return t
	# Fallback: title-case the slug.
	var out := []
	for part in short.split("_"):
		if part.length() > 0:
			out.append(part.substr(0, 1).to_upper() + part.substr(1))
	return PoolStringArray(out).join(" ")


func _stat_label(key: String) -> String:
	if STAT_NAME.has(key):
		return STAT_NAME[key]
	var s := key
	if s.begins_with("stat_"):
		s = s.substr(5)
	return s.replace("_", " ")


func _role_label(role: String) -> String:
	return ROLE_NAME[role] if ROLE_NAME.has(role) else role.capitalize()


func _icon_rect(tex, size: int) -> Control:
	var holder := Control.new()
	holder.rect_min_size = Vector2(size, size)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if tex != null:
		var img := TextureRect.new()
		img.texture = tex
		img.expand = true
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.set_anchors_and_margins_preset(Control.PRESET_WIDE)
		holder.add_child(img)
	return holder


func _label(text: String, font, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	if font != null:
		l.add_font_override("font", font)
	l.add_color_override("font_color", color)
	return l


func _spacer(h: float) -> Control:
	var s := Control.new()
	s.rect_min_size = Vector2(0, h)
	return s


func _flat(bg: Color, border: Color, bw: int, radius: int, pad: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	return sb


func _try_load(path: String):
	if ResourceLoader.exists(path):
		return load(path)
	return null
