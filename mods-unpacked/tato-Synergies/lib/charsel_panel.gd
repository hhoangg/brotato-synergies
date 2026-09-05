# Character-Select skill section. INJECTS a real node into the focused character's scrollable
# description content (right_panel VBox), so the skill flows below the passives and scrolls natively.
# Font is COPIED from the game's passive labels (size match); text is localized (VI + EN, default EN).
extends Control

const Config = preload("res://mods-unpacked/tato-Synergies/config.gd")

const NODE_NAME := "SynergiesSkill"
# All co-op character panels (Panel1 = host/P1 … Panel4). We inject a skill+faction card into EACH
# visible one so every player sees their own pick's info (not just P1).
const PANEL_BASE := "MarginContainer/VBoxContainer/DescriptionContainer/HBoxContainer/"
const PANELS := ["Panel1", "Panel2", "Panel3", "Panel4"]
const PANEL1 := PANEL_BASE + "Panel1"
# The WEAPON-selection screen reuses the SAME character_panel_ui.tscn (so CONTENT_SUB still applies), but
# as a single panel at a different path. We inject the card there too so the skill info follows the player
# into weapon select. (Verified from the extracted weapon_selection.tscn node tree.)
const WEAPON_PANEL := "MarginContainer/VBoxContainer/DescriptionContainer/CharacterPanelUI"
const CONTENT_SUB := "vboxContainer/character_infos_container/right_panel/ScrollContainer/MarginContainer/VBoxContainer"
# Explicit small fonts to match the passive-effect text (the theme default is ~2x too big).
const F_NAME := "res://resources/fonts/actual/base/font_26.tres"
const F_BODY := "res://resources/fonts/actual/base/font_22.tres"
const ICON_PX := 70.0   # skill-card icon size (was 88; −20% per design)
# Faction cell-background look: inset inside the cell's black border, with rounded corners to match it.
const TINT_INSET := 3.0   # px inset from each cell edge (so the color sits inside the default border)
const TINT_RADIUS := 12   # px corner radius (match the cell's rounded interior)

# Localized stat names (Brotato's own VI terms). EN is the fallback for any unlisted locale.
const STAT_NAME := {
	"en": {
		"stat_attack_speed": "Atk Speed", "stat_luck": "Luck", "stat_crit_chance": "Crit",
		"stat_armor": "Armor", "stat_max_hp": "Max HP", "stat_speed": "Speed", "stat_damage": "Damage",
		"stat_dodge": "Dodge", "stat_ranged_damage": "Ranged Dmg", "stat_range": "Range",
		"stat_lifesteal": "Lifesteal", "stat_hp_regeneration": "HP Regen", "stat_harvesting": "Harvest",
		"stat_engineering": "Engineering", "stat_melee_damage": "Melee Dmg", "stat_elemental_damage": "Elemental",
		"stat_xp_gain": "XP Gain",
	},
	"vi": {
		"stat_attack_speed": "Tốc Độ Đánh", "stat_luck": "May Mắn", "stat_crit_chance": "Chí Mạng",
		"stat_armor": "Giáp", "stat_max_hp": "Máu Tối Đa", "stat_speed": "Tốc Độ Chạy", "stat_damage": "Sát Thương",
		"stat_dodge": "Né", "stat_ranged_damage": "ST Tầm Xa", "stat_range": "Tầm Đánh",
		"stat_lifesteal": "Hút Máu", "stat_hp_regeneration": "Hồi Máu", "stat_harvesting": "Thu Hoạch",
		"stat_engineering": "Kỹ Thuật", "stat_melee_damage": "ST Cận Chiến", "stat_elemental_damage": "ST Nguyên Tố",
		"stat_xp_gain": "Kinh Nghiệm",
	},
}
const ROLE_NAME := {
	"en": {"support": "Support", "ad": "Carry", "caster": "Caster", "tank": "Tank", "late": "Late", "skirmisher": "Skirmisher", "flex": "Flex"},
	"vi": {"support": "Hỗ Trợ", "ad": "Sát Thương", "caster": "Phù Thủy", "tank": "Đỡ Đòn", "late": "Hậu Kỳ", "skirmisher": "Du Kích", "flex": "Linh Hoạt"},
}
const T := {
	"en": {
		"active": "Active Skill", "self": "Self", "team": "Team", "shield": "Self (shield)",
		"buff_fmt": "%s: %s for %ss.", "heal": "Heal allies %s HP.", "heal_aura": "Heal nearby allies %s HP.",
		"aoe_self": "%s dmg around you (radius %s), scales w/ Damage.",
		"aoe_cursor": "%s dmg at the nearest pack (radius %s), scales w/ Damage.",
		"dash_fmt": "Dash (invulnerable %ss) + %s for %ss.",
		"summon": "Deploy a turret: %s dmg/shot for %ss.",
		"cc": "Freeze ALL enemies for %ss — no damage.", "fx_fog": "dispels fog",
		"drain_self": "heal self %s HP", "drain_party": "heal team %s HP", "tiers": "5 tiers",
		"aoc_beam": "laser %s dmg", "aoc_volley": "volley %s dmg", "aoc_blast": "blast %s dmg",
		"fx_burn": "burns", "fx_curse": "weakens", "fx_arc": "chain lightning",
		"factions": "Factions: %s", "aff_hdr": "Faction traits (2+ allies):",
		"l_cd": "Cooldown", "l_wave": "wave", "l_dur": "Duration", "l_dmg": "Damage",
		"l_radius": "Radius", "l_heal": "Heal", "l_hp": "HP", "l_invuln": "Invuln", "l_dist": "Distance",
		"l_turret": "Turret dmg", "l_life": "Lifetime", "l_scout": "Reveal", "l_freeze": "Freeze",
		"l_slow": "Slow", "l_dot": "DoT/tick", "l_target": "Target", "l_cursor": "Nearest pack", "l_lifesteal": "Lifesteal", "l_knock": "Knockback",
		"l_blink": "Blink to", "l_lowhp": "Lowest-HP ally", "l_hot": "Heal",
		"l_burst": "Burst", "l_charm": "Charm", "l_materials": "Materials", "l_bonus": "Bonus", "l_team": "Whole team",
		"l_effects": "Effects", "l_scales": "(scales)", "l_beam": "laser", "l_volley": "volley", "l_blast": "blast",
	},
	"vi": {
		"active": "Kỹ Năng Chủ Động", "self": "Bản thân", "team": "Cả đội", "shield": "Bản thân (khiên)",
		"buff_fmt": "%s: %s trong %ss.", "heal": "Hồi %s máu cho cả đội.", "heal_aura": "Hồi %s máu cho đồng minh quanh bạn.",
		"aoe_self": "Nổ %s sát thương quanh bạn (bán kính %s), theo Sát Thương.",
		"aoe_cursor": "%s sát thương vào cụm địch gần nhất (bán kính %s), theo Sát Thương.",
		"dash_fmt": "Lướt (bất tử %ss) + %s trong %ss.",
		"summon": "Triệu hồi turret: %s ST/phát trong %ss.",
		"cc": "Đóng băng TOÀN BỘ địch %ss — không sát thương.", "fx_fog": "xua sương mù",
		"drain_self": "tự hồi %s máu", "drain_party": "hồi %s máu cả đội", "tiers": "5 bậc",
		"aoc_beam": "laser %s ST", "aoc_volley": "loạt %s ST", "aoc_blast": "nổ %s ST",
		"fx_burn": "đốt cháy", "fx_curse": "làm yếu", "fx_arc": "sét lan",
		"factions": "Phe: %s", "aff_hdr": "Hiệu ứng phe (đủ 2+):",
		"l_cd": "Hồi chiêu", "l_wave": "màn", "l_dur": "Thời gian", "l_dmg": "Sát thương",
		"l_radius": "Bán kính", "l_heal": "Hồi máu", "l_hp": "Máu", "l_invuln": "Bất tử", "l_dist": "Khoảng lướt",
		"l_turret": "ST turret", "l_life": "Tồn tại", "l_scout": "Soi địch", "l_freeze": "Đóng băng",
		"l_slow": "Làm chậm", "l_dot": "ST/nhịp", "l_target": "Mục tiêu", "l_cursor": "Cụm gần nhất", "l_lifesteal": "Hút máu", "l_knock": "Đẩy lùi",
		"l_blink": "Dịch chuyển", "l_lowhp": "Đồng đội ít máu nhất", "l_hot": "Hồi máu",
		"l_burst": "Nổ", "l_charm": "Mê hoặc", "l_materials": "Vật liệu", "l_bonus": "Thưởng", "l_team": "Cả đội",
		"l_effects": "Hiệu ứng", "l_scales": "(tăng theo)", "l_beam": "laser", "l_volley": "loạt", "l_blast": "nổ",
	},
}
const ROLE_COL := {
	"support": Color(0.45, 0.88, 0.55), "ad": Color(0.92, 0.40, 0.40), "caster": Color(0.72, 0.50, 0.95),
	"tank": Color(0.40, 0.62, 0.92), "late": Color(0.93, 0.80, 0.34), "skirmisher": Color(0.40, 0.85, 0.85),
	"flex": Color(0.70, 0.70, 0.76),
}

var _icon_cache := {}
var _cur_slug := ""
var _logged := false
var _legend_font = null
var _buttons := []      # cached [{node, slug}] of the character-grid buttons (for faction borders)
var _grid = null        # cached grid container (parent of the buttons)
var _last_child_count := -1   # grid child count at last scan — re-scan when it changes (coop toggle rebuilds the grid)
var _sig_by_panel := {}   # panel name -> last rendered "slug|activeFactions" signature (skip rebuild if unchanged)
var _coop_cached := false   # co-op state from the last _process tick (read by _draw to gate borders)
var settings = null         # ModSettings (set by the controller) — hide the card when synergies are off
var _orig_order := []       # the grid's original child order (captured on scan) — used to restore
var _reordered := false     # are the grid buttons currently grouped by faction?


func _ready() -> void:
	set_anchors_and_margins_preset(Control.PRESET_WIDE)   # full-screen so _draw maps to screen coords
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_mode = Node.PAUSE_MODE_PROCESS
	_legend_font = load(F_BODY)
	set_process(true)


func _process(_delta: float) -> void:
	var scn := _scene_name()
	if scn == "CharacterSelection":
		_process_charsel()
	elif scn == "WeaponSelection":
		_process_weaponsel()
	else:
		_grid = null
		_buttons = []
		_sig_by_panel = {}
		update()


# CHARACTER-SELECT: faction grid reorder + cell tints + a card injected into EVERY visible player panel.
func _process_charsel() -> void:
	_refresh_buttons()
	var coop : bool = _coop()
	var show : bool = _synergies_shown(coop)
	_coop_cached = coop and show
	# Group the character grid by faction ONLY in co-op with synergies on; otherwise put the game's
	# original order back. Restorable on toggle, so if it ever disrupts navigation the player can undo it.
	var want_reorder : bool = coop and show
	if want_reorder and not _reordered:
		_apply_faction_order()
		_apply_cell_tints()
		_reordered = true
	elif not want_reorder and _reordered:
		_restore_order()
		_clear_cell_tints()
		_reordered = false
	update()                          # redraw faction cell tints (co-op only); positions read live
	if not show:
		# Synergies disabled for this mode (Options→Accessibility toggle) → hide skill card + tints.
		_remove_cards()
		return
	var active : Dictionary = _active_faction_set() if coop else {}
	var asig : String = _active_sig(active)
	var scene = get_tree().current_scene
	if scene == null:
		return
	# inject / refresh a card into EVERY visible player panel (Panel1..4), not just the host
	for pname in PANELS:
		var panel = scene.get_node_or_null(PANEL_BASE + pname)
		if panel == null or not panel.is_visible_in_tree():
			continue
		_inject_card_into(panel, pname, active, coop)


# WEAPON-SELECT: no grid here, just the ONE CharacterPanelUI per the scene tree. Same card, so the skill
# info carries over from char-select into weapon select. (No faction reorder — that's a char-grid thing.)
func _process_weaponsel() -> void:
	_grid = null
	_buttons = []
	var coop : bool = _coop()
	var show : bool = _synergies_shown(coop)
	if not show:
		_remove_cards()
		return
	var scene = get_tree().current_scene
	if scene == null:
		return
	var panel = scene.get_node_or_null(WEAPON_PANEL)
	if panel == null or not panel.is_visible_in_tree():
		return
	var active : Dictionary = _active_faction_set() if coop else {}
	_inject_card_into(panel, "Weapon", active, coop)


# Inject (or refresh) the skill card into one CharacterPanelUI's scrollable description content. Shared by
# both selection screens; `pkey` is the per-panel signature key so unchanged panels skip a rebuild.
func _inject_card_into(panel, pkey: String, active: Dictionary, coop: bool) -> void:
	var content = panel.get_node_or_null(CONTENT_SUB)
	if content == null:
		return
	var slug := _slug_from_node(panel)
	if slug == "" or not Config.SKILLS.has(slug):
		return
	var node = content.get_node_or_null(NODE_NAME)
	if node == null:
		node = _build_node()
		content.add_child(node)
		if not _logged:
			_logged = true
			print("[Synergies][charsel] injected skill section (locale=%s)" % _locale())
	var sig := slug + "|" + _active_sig(active)
	if String(_sig_by_panel.get(pkey, "")) != sig:
		_sig_by_panel[pkey] = sig
		_update_node(node, slug, Config.SKILLS[slug], active, coop)


# Whether the synergies card should show for this char-select mode: co-op follows `synergies_coop`,
# solo follows `skills_solo` but ONLY in TEST builds (published builds never show the solo card, matching
# the controller's gate). Defaults to shown if settings aren't ready.
func _synergies_shown(coop: bool) -> bool:
	if settings == null:
		return true
	if coop:
		return bool(settings.synergies_coop())
	return Config.TEST_MODE and bool(settings.skills_solo())


# Remove any injected skill cards (when synergies were just toggled off) so the info disappears.
func _remove_cards() -> void:
	var scene = get_tree().current_scene
	if scene == null:
		return
	var paths := []
	for pname in PANELS:
		paths.append(PANEL_BASE + pname)
	paths.append(WEAPON_PANEL)   # also clear the weapon-select panel's card
	for p in paths:
		var panel = scene.get_node_or_null(p)
		if panel == null:
			continue
		var content = panel.get_node_or_null(CONTENT_SUB)
		if content == null:
			continue
		var node = content.get_node_or_null(NODE_NAME)
		if node != null:
			node.queue_free()
	_sig_by_panel = {}


# Reorder the character grid so same-faction members sit together (co-op + synergies only). Char
# buttons are grouped by their primary faction (AFFINITY_ORDER); faction-less chars go last; the
# leading non-char button (the "?" slot) stays put. Stable within a group (keeps the game's order).
func _apply_faction_order() -> void:
	if _grid == null or not is_instance_valid(_grid) or _buttons.empty():
		return
	var items := []
	for i in range(_buttons.size()):
		var b = _buttons[i]
		var node = b["node"]
		if node == null or not is_instance_valid(node):
			continue
		items.append({"node": node, "fi": _primary_faction_index(String(b["slug"])), "oi": i})
	items.sort_custom(self, "_cmp_faction")
	var base : int = _grid.get_child_count() - items.size()   # leading non-char buttons (e.g. the "?")
	if base < 0:
		base = 0
	for j in range(items.size()):
		var n = items[j]["node"]
		if is_instance_valid(n):
			_grid.move_child(n, base + j)


# Put the grid back in the game's original child order (snapshotted at scan time).
func _restore_order() -> void:
	if _grid == null or not is_instance_valid(_grid):
		return
	for i in range(_orig_order.size()):
		var n = _orig_order[i]
		if n != null and is_instance_valid(n) and n.get_parent() == _grid:
			_grid.move_child(n, i)


# Add a faction-colored background BEHIND each character's icon: a child ColorRect inserted before the
# button's "Icon" node, so it draws over the dark cell bg but under the egg sprite. Dual-faction chars
# get a left/right split. Skips buttons that already have it (idempotent across frames).
func _apply_cell_tints() -> void:
	for b in _buttons:
		var node = b["node"]
		if node == null or not is_instance_valid(node) or node.has_node("SynFactionBg"):
			continue
		var keys := _faction_keys_for(String(b["slug"]))
		if keys.empty():
			continue
		var holder := Control.new()
		holder.name = "SynFactionBg"
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.set_anchors_and_margins_preset(Control.PRESET_WIDE)
		if keys.size() == 1:
			holder.add_child(_bg_panel(keys[0], true, true, true, true, 0.0, 1.0))
		else:
			holder.add_child(_bg_panel(keys[0], true, false, true, false, 0.0, 0.5))   # round left corners
			holder.add_child(_bg_panel(keys[1], false, true, false, true, 0.5, 1.0))   # round right corners
		node.add_child(holder)
		var icon = node.get_node_or_null("Icon")   # draw the tint just behind the character icon
		if icon != null:
			node.move_child(holder, icon.get_index())
		else:
			node.move_child(holder, 0)


# A ROUNDED faction-colored Panel spanning [al, ar] of the width, inset inside the cell's black border.
# tl/tr/bl/br pick which corners are rounded (split halves round only their outer corners; the inner
# seam stays straight and is not inset, so the two halves meet cleanly).
func _bg_panel(key: String, tl: bool, tr: bool, bl: bool, br: bool, al: float, ar: float) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = _aff_bg(key)
	sb.corner_radius_top_left = TINT_RADIUS if tl else 0
	sb.corner_radius_top_right = TINT_RADIUS if tr else 0
	sb.corner_radius_bottom_left = TINT_RADIUS if bl else 0
	sb.corner_radius_bottom_right = TINT_RADIUS if br else 0
	p.add_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.anchor_left = al
	p.anchor_right = ar
	p.anchor_top = 0.0
	p.anchor_bottom = 1.0
	p.margin_left = TINT_INSET if al == 0.0 else 0.0
	p.margin_right = -TINT_INSET if ar == 1.0 else 0.0
	p.margin_top = TINT_INSET
	p.margin_bottom = -TINT_INSET
	return p


# Remove the faction background nodes (synergies toggled off / left co-op).
func _clear_cell_tints() -> void:
	for b in _buttons:
		var node = b["node"]
		if node == null or not is_instance_valid(node):
			continue
		var bg = node.get_node_or_null("SynFactionBg")
		if bg != null:
			bg.queue_free()


# sort_custom comparator: by faction-order index, then original index (stable within a faction).
func _cmp_faction(a, b) -> bool:
	if int(a["fi"]) != int(b["fi"]):
		return int(a["fi"]) < int(b["fi"])
	return int(a["oi"]) < int(b["oi"])


# Index of a character's primary faction in AFFINITY_ORDER (lower = earlier); 999 if faction-less.
func _primary_faction_index(slug: String) -> int:
	var order : Array = Config.AFFINITY_ORDER
	for i in range(order.size()):
		var aff = Config.AFFINITIES.get(order[i], {})
		if slug in aff.get("members", []):
			return i
	return 999


# ---- faction-border discovery + drawing (character-select grid) ----

# Cache the grid buttons once: find the parent of the first character button, map each child to a slug.
func _refresh_buttons() -> void:
	# Re-scan when the grid was rebuilt: toggling co-op / "Chơi nhiều" recreates the icon grid, so the
	# cached button nodes go stale (freed). Detect via grid invalid / child-count change / first node freed.
	var need : bool = _buttons.empty() or _grid == null or not is_instance_valid(_grid)
	if not need:
		if _grid.get_child_count() != _last_child_count:
			need = true
		else:
			var n0 = _buttons[0]["node"]
			if n0 == null or not is_instance_valid(n0):
				need = true
	if not need:
		return
	var scene = get_tree().current_scene
	if scene == null:
		return
	var first = _find_char_button(scene, 0)
	if first == null:
		_grid = null
		_buttons = []
		return
	_grid = first.get_parent()
	_orig_order = _grid.get_children()   # snapshot the game's order so we can restore it
	_reordered = false                   # a fresh/rebuilt grid is back in game order
	_last_child_count = _grid.get_child_count()
	_buttons = []
	for c in _grid.get_children():
		var s := _slug_from_node(c)
		if s != "":
			_buttons.append({"node": c, "slug": s})
	print("[Synergies][charsel] grid (re)scan: %d character buttons under '%s'" % [_buttons.size(), String(_grid.name)])


func _find_char_button(node, depth: int):
	if depth > 8:
		return null
	for c in node.get_children():
		if (c is Button) and _slug_from_node(c) != "":
			return c
	for c in node.get_children():
		var r = _find_char_button(c, depth + 1)
		if r != null:
			return r
	return null


func _draw() -> void:
	pass   # faction cell tints are real child ColorRects BEHIND each icon now (see _apply_cell_tints)


# Faction color for the cell tint. It sits BEHIND the egg icon (over the button's dark bg), so it can
# be fairly opaque for a clear background without muddying the character sprite.
func _aff_bg(key: String) -> Color:
	var c := _aff_color(key)
	c.a = 0.55
	return c


# w 1px concentric rects hugging the inside edge of `r`, offset inward by `inset`.
func _ring(r: Rect2, c: Color, w: int, inset: int) -> void:
	for i in range(w):
		var o : float = float(inset + i)
		draw_rect(Rect2(r.position + Vector2(o, o), r.size - Vector2(o * 2.0, o * 2.0)), c, false, 1.0)


# Bounding box of all grid buttons = the character-grid area (robust regardless of container type).
func _grid_rect() -> Rect2:
	var r := Rect2()
	var first := true
	for b in _buttons:
		var n = b["node"]
		if n == null or not is_instance_valid(n) or not (n is Control):
			continue
		var br : Rect2 = (n as Control).get_global_rect()
		if first:
			r = br
			first = false
		else:
			r = r.merge(br)
	return r


# Vertical color legend in the LEFT margin beside the grid (the grid spans nearly full width, so the
# right margin has no room). Rows for the focused character's factions are highlighted.
func _draw_legend_v(grect: Rect2) -> void:
	if _legend_font == null or grect.size.x <= 0.0:
		return
	var vi : bool = _locale() == "vi"
	var focus_keys := _faction_keys_for(_focus_slug())
	var x : float = max(8.0, grect.position.x - 188.0)
	var y : float = grect.position.y
	var lh : float = clamp(grect.size.y / float(Config.AFFINITY_ORDER.size()), 24.0, 34.0)
	for key in Config.AFFINITY_ORDER:
		var aff = Config.AFFINITIES.get(key, {})
		var label : String = String(aff.get("label_vi", "?")) if vi else String(aff.get("label", "?"))
		var on : bool = key in focus_keys
		if on:
			draw_rect(Rect2(x - 4, y - 2, 184, lh - 4), Color(1, 1, 1, 0.10))   # highlight focused char's factions
		draw_rect(Rect2(x, y, 16, 16), _aff_color(key))
		draw_rect(Rect2(x, y, 16, 16), Color(0, 0, 0, 0.55), false, 1.0)
		_text(Vector2(x + 22, y + 14), label, Color(1, 1, 0.85) if on else Color(0.80, 0.80, 0.74))
		y += lh


# A native-styled detail box above the grid showing the focused character's faction buff/nerf — the
# "tooltip" for a controller user (it follows the host's grid focus; no mouse needed).
func _draw_focus_detail(grect: Rect2) -> void:
	if _legend_font == null or grect.size.x <= 0.0:
		return
	var slug := _focus_slug()
	var detail := _faction_detail(slug)
	if detail == "":
		return
	var lines := detail.split("\n")
	var bw := 560.0
	var bh : float = 10.0 + lines.size() * 22.0
	var bx : float = grect.position.x
	var by : float = grect.position.y - bh - 6.0
	draw_rect(Rect2(bx, by, bw, bh), Color(0.07, 0.07, 0.09, 0.92))
	draw_rect(Rect2(bx, by, bw, bh), Color(0.85, 0.80, 0.65, 0.35), false, 1.0)
	var ty := by + 18.0
	for ln in lines:
		_text(Vector2(bx + 10.0, ty), String(ln), Color(0.92, 0.90, 0.82))
		ty += 22.0


# Co-op for the card's purposes = MORE THAN ONE character actually CHOSEN. We deliberately use the
# visible-roster count (panels with a picked character), NOT CoopService.connected_players — that list can
# already hold >1 entry the moment a join slot opens (before anyone picks), which falsely showed the card
# for a solo player. The roster only counts real picks, so a lone player reads as solo.
func _coop() -> bool:
	return _roster().size() > 1


# The characters currently selected across the visible player panels (the tentative co-op roster).
func _roster() -> Array:
	var out := []
	var scene = get_tree().current_scene
	if scene == null:
		return out
	for pname in PANELS:
		var panel = scene.get_node_or_null(PANEL_BASE + pname)
		if panel == null or not panel.is_visible_in_tree():
			continue
		var s := _slug_from_node(panel)
		if s != "":
			out.append(s)
	return out


# Factions with >=2 members in the current roster → active (these get green text). {key: count}
func _active_faction_set() -> Dictionary:
	var roster := _roster()
	var out := {}
	for key in Config.AFFINITY_ORDER:
		var members = Config.AFFINITIES.get(key, {}).get("members", [])
		var c := 0
		for s in roster:
			if s in members:
				c += 1
		if c >= 2:
			out[key] = c
	return out


func _active_sig(active: Dictionary) -> String:
	var keys := active.keys()
	keys.sort()
	return PoolStringArray(keys).join(",")


func _faction_keys_for(slug: String) -> Array:
	var keys := []
	for key in Config.AFFINITY_ORDER:
		var aff = Config.AFFINITIES.get(key, {})
		if slug in aff.get("members", []):
			keys.append(key)
	return keys


func _aff_color(key: String) -> Color:
	var c = Config.AFFINITY_COLORS.get(key, [0.7, 0.7, 0.7])
	return Color(float(c[0]), float(c[1]), float(c[2]))


func _text(pos: Vector2, s: String, col: Color) -> void:
	if _legend_font != null:
		_legend_font.draw(get_canvas_item(), pos, s, col)


func _vp_size() -> Vector2:
	var o : Vector2 = get_viewport().get_size_override()
	if o.x > 0 and o.y > 0:
		return o
	return get_viewport().size


func _content_container():
	var scene = get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null(PANEL1 + "/" + CONTENT_SUB)


func _build_node() -> Control:
	var f_name = load(F_NAME)
	var f_body = load(F_BODY)
	var root := VBoxContainer.new()
	root.name = NODE_NAME
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Faction-effect section FIRST — flows right under the game's own stat lines (NO separator above it),
	# so the team bonuses read as part of the character's stats. The skill CARD (styled box) goes below.
	var fac := VBoxContainer.new()
	fac.name = "Factions"
	fac.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(fac)
	root.add_child(_spacer(6))
	# The skill card: a rounded dark panel with a role-colored left accent (set per-character in _update_node),
	# mirroring Brotato's own item tooltip look. PanelContainer applies a StyleBoxFlat we recolor at runtime.
	var card := PanelContainer.new()
	card.name = "Card"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_stylebox_override("panel", _card_style(Color(0.5, 0.5, 0.6)))
	var pad := MarginContainer.new()
	pad.name = "Pad"
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_constant_override(m, 12 if (m == "margin_left" or m == "margin_right") else 10)
	card.add_child(pad)
	var col := VBoxContainer.new()
	col.name = "Col"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_constant_override("separation", 6)
	pad.add_child(col)
	# --- Header: icon + name + sub ---
	var head := HBoxContainer.new()
	head.name = "Head"
	head.add_constant_override("separation", 12)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.rect_min_size = Vector2(ICON_PX, ICON_PX)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand = true
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(icon)
	var ht := VBoxContainer.new()
	ht.name = "HeadText"
	ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ht.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# autowrap so the labels' MINIMUM width is just the longest word — otherwise a long single line
	# forces Panel1 wider than the other character columns.
	var nm := Label.new()
	nm.name = "Name"
	nm.autowrap = true
	if f_name != null:
		nm.add_font_override("font", f_name)
	ht.add_child(nm)
	var sub := Label.new()
	sub.name = "Sub"
	sub.autowrap = true
	if f_body != null:
		sub.add_font_override("font", f_body)
	ht.add_child(sub)
	head.add_child(ht)
	col.add_child(head)
	# --- Stat rows (green, one per line — rebuilt per character in _update_node) ---
	var stats := VBoxContainer.new()
	stats.name = "Stats"
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_constant_override("separation", 2)
	col.add_child(stats)
	# --- thin divider, then the flavor sentence (dim, like Brotato's own item flavor text) ---
	var sep := HSeparator.new()
	sep.name = "FlavorSep"
	col.add_child(sep)
	var flavor := Label.new()
	flavor.name = "Flavor"
	flavor.autowrap = true
	flavor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if f_body != null:
		flavor.add_font_override("font", f_body)
	col.add_child(flavor)
	root.add_child(card)
	return root


# A small fixed-height spacer Control (Godot 3.x has no built-in gap node).
func _spacer(h: float) -> Control:
	var s := Control.new()
	s.rect_min_size = Vector2(0, h)
	return s


# The card's rounded dark StyleBoxFlat with a role-colored LEFT accent bar. Recolored per character.
func _card_style(accent: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.11, 0.92)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.border_width_left = 3
	sb.border_color = accent
	return sb


const CARD_BASE := "Card/Pad/Col/"

func _update_node(node, slug: String, skill, active: Dictionary, coop: bool) -> void:
	var role := String(skill.get("role", "flex"))
	var accent : Color = ROLE_COL.get(role, Color(0.80, 0.82, 0.88))
	_rebuild_factions(node.get_node_or_null("Factions"), slug, active, coop)
	# Recolor the card's left accent bar to the role color.
	var card = node.get_node_or_null("Card")
	if card != null:
		card.add_stylebox_override("panel", _card_style(accent))
	var icon = node.get_node_or_null(CARD_BASE + "Head/Icon")
	if icon != null:
		var tex = _icon_for(slug)
		icon.texture = tex
		icon.visible = tex != null
	var nm = node.get_node_or_null(CARD_BASE + "Head/HeadText/Name")
	if nm != null:
		nm.text = String(skill.get("name", "?"))
		nm.add_color_override("font_color", accent)
	var sub = node.get_node_or_null(CARD_BASE + "Head/HeadText/Sub")
	if sub != null:
		sub.text = _t("active") + " · " + _role_name(role) + " · Space · " + _t("tiers")
		sub.add_color_override("font_color", Color(0.66, 0.69, 0.75))
	_rebuild_stats(node.get_node_or_null(CARD_BASE + "Stats"), skill)
	var flavor = node.get_node_or_null(CARD_BASE + "Flavor")
	if flavor != null:
		flavor.text = _skill_flavor(slug)
		flavor.add_color_override("font_color", Color(0.62, 0.64, 0.72))   # dim, set apart from the mechanics
		flavor.visible = flavor.text != ""


const COL_STAT_LABEL := Color(0.62, 0.65, 0.72)   # dim label on the left ("Cooldown")
const COL_STAT_VAL := Color(0.45, 0.88, 0.42)     # green value on the right ("~2 / wave") — ActiveSkill look
const COL_STAT_FX := Color(0.80, 0.74, 0.55)      # warm tan for the effect tags row (burns/curse/arc)

# Rebuild the per-skill stat ROWS as "Label  ……  green value" lines (ActiveSkill-style), driven by the
# skill's template. Cooldown is always first (the mod's cooldown is wave-relative, so it's "~2 / wave",
# not a fixed second count). Then template-specific lines, riders, and a final effect-tags line.
func _rebuild_stats(box, skill) -> void:
	if box == null:
		return
	for ch in box.get_children():
		box.remove_child(ch)
		ch.free()
	var tmpl := String(skill.get("template", ""))
	# Cooldown (universal) — wave-relative, so a casts-per-wave estimate reads truer than a stale "12s".
	# The estimate comes from the skill's cooldown_class (fast≈4 / normal≈2 / slow≈1.2 casts/wave).
	_stat_row(box, _t("l_cd"), _cd_estimate(skill))
	# Duration (skills with a buff/effect window). Skipped for AOE (shown via Radius/Target instead) and
	# CC (its Freeze row already states the duration).
	if float(skill.get("duration", 0.0)) > 0.0 and tmpl != Config.TMPL_AOE_SELF and tmpl != Config.TMPL_AOE_CURSOR and tmpl != Config.TMPL_CC:
		_stat_row(box, _t("l_dur"), _rng_dur(skill) + "s")
	# Template-specific damage/heal/etc.
	if tmpl == Config.TMPL_HEAL:
		_stat_row(box, _t("l_heal"), _rng_i(skill, "heal", "heal_per_tier") + " " + _t("l_hp"))
		if float(skill.get("radius", 0.0)) > 0.0:
			_stat_row(box, _t("l_radius"), _rng_i(skill, "radius", "radius_per_tier"))
	elif tmpl == Config.TMPL_AOE_SELF or tmpl == Config.TMPL_AOE_CURSOR:
		_stat_row(box, _t("l_dmg"), _rng_i(skill, "damage", "damage_per_tier") + " " + _t("l_scales"))
		_stat_row(box, _t("l_radius"), _rng_i(skill, "radius", "radius_per_tier"))
		_stat_row(box, _t("l_target"), _t("self") if tmpl == Config.TMPL_AOE_SELF else _t("l_cursor"))
	elif tmpl == Config.TMPL_DASH:
		_stat_row(box, _t("l_dist"), _rng_i(skill, "distance", "distance_per_tier"))
		_stat_row(box, _t("l_invuln"), _rng_iframe(skill) + "s")
	elif tmpl == Config.TMPL_SUMMON:
		if bool(skill.get("scout_mode", false)):
			_stat_row(box, _t("l_scout"), _rng_f(skill, "life", "life_per_tier") + "s")
		else:
			_stat_row(box, _t("l_turret"), _rng_i(skill, "damage", "damage_per_tier") + " " + _t("l_scales"))
			_stat_row(box, _t("l_life"), _rng_f(skill, "life", "life_per_tier") + "s")
	elif tmpl == Config.TMPL_CC:
		_stat_row(box, _t("l_freeze"), _rng_dur_f(skill) + "s")
	elif tmpl == "curse_cloud":
		_stat_row(box, _t("l_radius"), _rng_i(skill, "radius", "radius_per_tier"))
		_stat_row(box, _t("l_slow"), "%d%%" % int(float(skill.get("slow_percent", 0.5)) * 100))
		_stat_row(box, _t("l_dot"), "%d%% curse" % int(float(skill.get("curse_dmg_percent", 0.2)) * 100))
	elif tmpl == "heal_zone":
		_stat_row(box, _t("l_blink"), _t("l_lowhp"))
		_stat_row(box, _t("l_radius"), _rng_i(skill, "radius", "radius_per_tier"))
		_stat_row(box, _t("l_hot"), _pct_range(skill, "heal_percent", "heal_percent_per_tier") + "/s")
		_stat_row(box, _t("l_slow"), "%d%%" % int(float(skill.get("slow_percent", 0.4)) * 100))
	elif tmpl == "greed":
		_stat_row(box, _t("l_materials"), _mult_range(skill))
		_stat_row(box, _t("l_target"), _t("l_team"))
	# Primary stat buff(s) — for BUFF/SHIELD these ARE the skill; for AOE/HEAL/SUMMON they're a rider.
	var stats : Dictionary = skill.get("stats", {})
	var per : Dictionary = skill.get("stats_per_tier", {})
	for k in stats.keys():
		_stat_row(box, _stat_name(k), "+" + _rng(int(stats[k]), int(per.get(k, 0))))
	# Drain (heal-on-cast) rider.
	if int(skill.get("drain", 0)) > 0:
		var dlbl := _t("l_heal") + (" (" + _t("team") + ")" if bool(skill.get("drain_party", false)) else "")
		_stat_row(box, dlbl, _rng_i(skill, "drain", "drain_per_tier") + " " + _t("l_hp"))
	# Lifesteal-ish riders already covered via stats; AOE-on-cast burst.
	var aoc = skill.get("aoe_on_cast", null)
	if typeof(aoc) == TYPE_DICTIONARY:
		var ak := _t("l_blast")
		if bool(aoc.get("beam", false)):
			ak = _t("l_beam")
		elif int(aoc.get("count", 1)) > 1:
			ak = _t("l_volley")
		_stat_row(box, _t("l_burst"), ak + " " + _rng(int(aoc.get("damage", 0)), int(aoc.get("damage_per_tier", 0))))
	# Knockback rider (diver's rescue surge) — push force + radius + the follow-up slow.
	var kb = skill.get("knockback", null)
	if typeof(kb) == TYPE_DICTIONARY:
		_stat_row(box, _t("l_knock"), _rng(int(kb.get("amount", 200)), int(kb.get("amount_per_tier", 0))))
		_stat_row(box, _t("l_radius"), _rng(int(kb.get("radius", 140)), int(kb.get("radius_per_tier", 0))))
		if float(kb.get("slow_percent", 0.0)) > 0.0:
			_stat_row(box, _t("l_slow"), "%d%%" % int(float(kb.get("slow_percent", 0.5)) * 100))
	# Charm / material / standing-still riders.
	if skill.has("charm"):
		var ch = skill["charm"]
		_stat_row(box, _t("l_charm"), "%d (<%d%% HP)" % [int(ch.get("count", 2)), int(float(ch.get("hp_threshold", 0.6)) * 100)])
	if skill.has("material_drop"):
		_stat_row(box, _t("l_materials"), "+" + _rng_i(skill, "material_drop", "material_drop_per_tier"))
	if skill.has("standing_still_bonus"):
		_stat_row(box, _t("l_bonus"), "%sx (still)" % str(float(skill.get("standing_still_bonus", 1.5))))
	# Effect TAGS (burns / weakens / chain lightning / dispels fog) — one warm-tan line if any apply.
	var fx := _effect_tags(skill)
	if fx != "":
		_stat_row(box, _t("l_effects"), fx, COL_STAT_FX)


# One "label …… value" row: dim label on the left, colored value pushed to the right.
func _stat_row(box, label: String, value: String, val_col: Color = COL_STAT_VAL) -> void:
	var f_body = load(F_BODY)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := Label.new()
	if f_body != null:
		l.add_font_override("font", f_body)
	l.text = label
	l.add_color_override("font_color", COL_STAT_LABEL)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var v := Label.new()
	if f_body != null:
		v.add_font_override("font", f_body)
	v.text = value
	v.add_color_override("font_color", val_col)
	v.align = Label.ALIGN_RIGHT
	row.add_child(v)
	box.add_child(row)


# Collect the on-hit / utility effect tags into one short string (no leading separator).
func _effect_tags(skill) -> String:
	var parts := []
	var aoc = skill.get("aoe_on_cast", null)
	var burn_kind := String(skill.get("burn", ""))
	if burn_kind == "" and typeof(aoc) == TYPE_DICTIONARY:
		burn_kind = String(aoc.get("burn", ""))
	if burn_kind != "":
		parts.append(_t("fx_burn"))
	if String(skill.get("hit_vfx", "")) == "curse":
		parts.append(_t("fx_curse"))
	if bool(skill.get("arc", false)):
		parts.append(_t("fx_arc"))
	if skill.has("clear_fog"):
		parts.append(_t("fx_fog"))
	return PoolStringArray(parts).join(", ")


# Rebuild the faction-effect labels (co-op only): a dim header + one line per faction the character is
# in, GREEN if that faction is active (>=2 members in the roster), else gray.
func _rebuild_factions(fbox, slug: String, active: Dictionary, coop: bool) -> void:
	if fbox == null:
		return
	for ch in fbox.get_children():
		fbox.remove_child(ch)
		ch.free()
	if not coop:
		return
	var keys := _faction_keys_for(slug)
	if keys.empty():
		return
	var f_body = load(F_BODY)
	var hdr := Label.new()
	hdr.autowrap = true
	if f_body != null:
		hdr.add_font_override("font", f_body)
	hdr.text = _t("aff_hdr")
	hdr.add_color_override("font_color", Color(0.66, 0.69, 0.75))
	fbox.add_child(hdr)
	for key in keys:
		var aff = Config.AFFINITIES.get(key, {})
		var on : bool = active.has(key)
		var fac_hex := _aff_color(key).to_html(false)             # faction name tinted in the faction color
		var stat_hex := "5fe06e" if on else "bdbdc6"              # stats green when the trait is active, else gray
		var lbl := RichTextLabel.new()
		lbl.bbcode_enabled = true
		lbl.fit_content_height = true
		lbl.scroll_active = false
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if f_body != null:
			lbl.add_font_override("normal_font", f_body)
		lbl.bbcode_text = "[color=#%s]%s[/color][color=#%s]: %s[/color]" % [fac_hex, _faction_label(aff), stat_hex, _faction_stats_only(aff)]
		fbox.add_child(lbl)


# "<Faction>: +X Stat, -Y Stat" using the 2-member tier values.
func _faction_line(aff) -> String:
	var label := _faction_label(aff)
	var tiers : Array = aff.get("tiers", [])
	if tiers.empty():
		return label
	var t0 = tiers[0]
	var parts := []
	for k in t0.get("buff", {}).keys():
		parts.append("+%d %s" % [int(t0["buff"][k]), _stat_name(k)])
	for k in t0.get("nerf", {}).keys():
		parts.append("%d %s" % [int(t0["nerf"][k]), _stat_name(k)])
	return "%s: %s" % [label, PoolStringArray(parts).join(", ")]


# Just the "+X Stat, -Y Stat" part (no faction name) — the name is colored separately in the card.
func _faction_stats_only(aff) -> String:
	var tiers : Array = aff.get("tiers", [])
	if tiers.empty():
		return ""
	var t0 = tiers[0]
	var parts := []
	for k in t0.get("buff", {}).keys():
		parts.append("+%d %s" % [int(t0["buff"][k]), _stat_name(k)])
	for k in t0.get("nerf", {}).keys():
		parts.append("%d %s" % [int(t0["nerf"][k]), _stat_name(k)])
	return PoolStringArray(parts).join(", ")


# Cooldown shown as a casts-per-wave estimate derived from the skill's cooldown_class. Base ~2/wave (45%
# of the wave), divided by the class multiplier (fast 0.5→~4, normal 1.0→~2, slow 1.6→~1.2).
func _cd_estimate(skill) -> String:
	var cls := String(skill.get("cooldown_class", "normal"))
	var mult : float = float(Config.COOLDOWN_CLASS_MULT.get(cls, 1.0))
	var per_wave : float = 2.0 / max(mult, 0.01)
	return "~%d / %s" % [int(round(per_wave)), _t("l_wave")]


# Localized one-line flavor for a character's skill (Config.SKILL_FLAVOR), or "" if none.
func _skill_flavor(slug: String) -> String:
	var f = Config.SKILL_FLAVOR.get(slug, null)
	if typeof(f) != TYPE_DICTIONARY:
		return ""
	var loc := _locale()
	return String(f.get(loc, f.get("en", "")))


# ---- i18n helpers (VI + EN; default EN) ----
func _locale() -> String:
	var l := TranslationServer.get_locale().substr(0, 2)
	return l if T.has(l) else "en"


func _t(key: String) -> String:
	var d : Dictionary = T[_locale()]
	return String(d[key]) if d.has(key) else String(T["en"][key])


func _stat_name(k: String) -> String:
	var d : Dictionary = STAT_NAME[_locale()]
	if d.has(k):
		return String(d[k])
	return String(STAT_NAME["en"].get(k, k))


func _role_name(r: String) -> String:
	var d : Dictionary = ROLE_NAME[_locale()]
	if d.has(r):
		return String(d[r])
	return String(ROLE_NAME["en"].get(r, r))


# Localized faction labels this character belongs to (joined), or "" if faction-less.
func _factions_for(slug: String) -> String:
	var names := []
	for key in Config.AFFINITIES.keys():
		var aff = Config.AFFINITIES[key]
		if slug in aff.get("members", []):
			names.append(_faction_label(aff))
	return PoolStringArray(names).join(", ")


func _faction_label(aff) -> String:
	if _locale() == "vi":
		return String(aff.get("label_vi", aff.get("label", "?")))
	return String(aff.get("label", "?"))


# Faction trait line(s) for this character: "<Faction>: +X Stat, -Y Stat" using the 2-member values.
func _faction_detail(slug: String) -> String:
	var lines := []
	for key in Config.AFFINITY_ORDER:
		var aff = Config.AFFINITIES.get(key, {})
		if not (slug in aff.get("members", [])):
			continue
		var label := _faction_label(aff)
		var tiers : Array = aff.get("tiers", [])
		if tiers.empty():
			lines.append(label)
			continue
		var t0 = tiers[0]
		var parts := []
		for k in t0.get("buff", {}).keys():
			parts.append("+%d %s" % [int(t0["buff"][k]), _stat_name(k)])
		for k in t0.get("nerf", {}).keys():
			parts.append("%d %s" % [int(t0["nerf"][k]), _stat_name(k)])
		lines.append("%s: %s" % [label, PoolStringArray(parts).join(", ")])
	return PoolStringArray(lines).join("\n")


func _focus_slug() -> String:
	var scene = get_tree().current_scene
	if scene != null:
		var s := _slug_from_node(scene.get_node_or_null(PANEL1))
		if s != "":
			return s
	var rd = get_tree().root.get_node_or_null("RunData")
	if rd != null and rd.has_method("get_player_character"):
		return _slug_of(rd.get_player_character(0))
	return ""


func _slug_from_node(node) -> String:
	if node == null:
		return ""
	for prop in node.get_property_list():
		var s := _slug_of(node.get(String(prop.name)))
		if s != "":
			return s
	return ""


func _slug_of(v) -> String:
	if typeof(v) == TYPE_OBJECT and v != null and ("my_id" in v):
		var mid := String(v.my_id)
		if mid.begins_with("character_"):
			# Game ids use underscores (well_rounded, arms_dealer); our config uses hyphens. Normalize
			# so multi-word characters match SKILLS/AFFINITIES keys. `one_arm` → `one-armed` (the odd one).
			var s := mid.replace("character_", "")
			if s == "one_arm":
				return "one-armed"
			return s.replace("_", "-")
	return ""


# "base→T5" range string (T5 = base + 4*per_tier); just "base" if it doesn't scale.
func _rng(base: int, inc: int) -> String:
	if inc > 0:
		return "%d→%d" % [base, base + 4 * inc]
	return "%d" % base


func _rng_i(skill, key: String, per_key: String) -> String:
	return _rng(int(skill.get(key, 0)), int(skill.get(per_key, 0)))


func _rng_dur(skill) -> String:
	var b := int(skill.get("duration", 0.0))
	var t5 := int(float(skill.get("duration", 0.0)) + 4.0 * float(skill.get("dur_per_tier", 0.0)))
	if t5 > b:
		return "%d→%d" % [b, t5]
	return "%d" % b


# Like _rng_dur but keeps ONE decimal — for fractional durations (e.g. CC 1.5→2.7s) that int-floor would
# misreport as "1→2s".
func _rng_dur_f(skill) -> String:
	var b := float(skill.get("duration", 0.0))
	var t5 := b + 4.0 * float(skill.get("dur_per_tier", 0.0))
	if t5 > b:
		return "%.1f→%.1f" % [b, t5]
	return "%.1f" % b


# DASH i-frame (invulnerability) window range, one decimal: e.g. "0.7→1.5".
func _rng_iframe(skill) -> String:
	var b := float(skill.get("iframe", 0.0))
	var t5 := b + 4.0 * float(skill.get("iframe_per_tier", 0.0))
	if t5 > b:
		return "%.1f→%.1f" % [b, t5]
	return "%.1f" % b


# "X%→Y%" range for a 0..1 fractional key (e.g. heal_percent 0.03→0.10 → "3%→10%").
func _pct_range(skill, key: String, per_key: String) -> String:
	var b := int(round(float(skill.get(key, 0.0)) * 100.0))
	var t5 := int(round((float(skill.get(key, 0.0)) + 4.0 * float(skill.get(per_key, 0.0))) * 100.0))
	if t5 > b:
		return "%d%%→%d%%" % [b, t5]
	return "%d%%" % b


# "×base→×T5" multiplier range for the GREED template (Jack's material multiplier).
func _mult_range(skill) -> String:
	var b := int(round(float(skill.get("mult", 3.0))))
	var t5 := int(round(float(skill.get("mult", 3.0)) + 4.0 * float(skill.get("mult_per_tier", 0.0))))
	if t5 > b:
		return "x%d→x%d" % [b, t5]
	return "x%d" % b


# "base→T5" range for an arbitrary float-valued key (e.g. summon `life`/`life_per_tier`).
func _rng_f(skill, key: String, per_key: String) -> String:
	var b := int(float(skill.get(key, 0.0)))
	var t5 := int(float(skill.get(key, 0.0)) + 4.0 * float(skill.get(per_key, 0.0)))
	if t5 > b:
		return "%d→%d" % [b, t5]
	return "%d" % b


func _scene_name() -> String:
	var s = get_tree().current_scene
	return s.name if s != null else "?"


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
