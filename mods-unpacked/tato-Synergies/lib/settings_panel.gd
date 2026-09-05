# Injects the Synergies on/off toggles into the game's Options → Accessibility ("Tiếp cận") tab.
#
# Discovered structure (TitleScreen + in-run pause options share it):
#   …/MenuOptions/Buttons/HBoxContainer3/TabContainer/Accessibility_Container/AccessibilityContainer
# That `AccessibilityContainer` (VBoxContainer) holds the native accessibility rows as direct CheckButton
# children (CharacterHighlightingButton, DarkenScreenButton, …). We add two CheckButtons of the same kind
# at the TOP, so they inherit the menu theme and read like native options. They write straight to
# ModSettings (mod ConfigFile), and the controller reads those each frame to gate skills/affinities.
#
# Re-injects whenever the menu is rebuilt (close/reopen, or leaving and returning to the title screen).
extends Node

const Config = preload("res://mods-unpacked/tato-Synergies/config.gd")

const MARK_SOLO := "SynergiesSkillsSoloButton"
const MARK_RUNOPT := "SynergiesRunOptionButton"   # the toggle injected into the char-select Run Options panel

# The Run Options panel on the character-select screen: its inner VBox holds Endless/Ban/Coop CheckButtons.
# We add a "Synergies" CheckButton right after Co-op, but only show it while Co-op is ON (synergies are a
# co-op feature). Path verified from the extracted character_selection.tscn.
const RUNOPT_VBOX := "MarginContainer/VBoxContainer/DescriptionContainer/RunOptionsPanel/MarginContainer/VBoxContainer/VBoxContainer"
const RUNOPT_COOP_BTN := "CoopButton"

# Native rows use MENU_* translation keys; ours are set as final localized text (default EN).
const LABELS := {
	"en": {"solo": "Skills when playing solo", "runopt": "Synergies"},
	"vi": {"solo": "Skill khi chơi đơn", "runopt": "Synergies"},
}

var settings = null   # ModSettings instance (set by the controller)
var _t := 0.0
var _logged := false


func _ready() -> void:
	# Process while the tree is paused so the in-run pause→options menu also gets the toggles.
	pause_mode = Node.PAUSE_MODE_PROCESS


func _process(delta: float) -> void:
	_t += delta
	if _t < 0.4:
		return
	_t = 0.0
	if settings == null:
		return
	var scene = get_tree().current_scene
	# Character-select: keep the Run Options "Synergies" toggle in sync (inject when Co-op is on, hide when off).
	if scene != null and String(scene.name) == "CharacterSelection":
		_sync_runopt_toggle(scene)
		return
	# Accessibility tab: only the SOLO-skills toggle lives here now, and ONLY in TEST builds. The co-op
	# Synergies toggle was removed (it's in the char-select Run Options panel instead); published builds
	# hide the solo toggle entirely so a normal run never gets solo skills.
	if not Config.TEST_MODE:
		return
	# That container only exists on the title screen or while paused — skip the tree walk during gameplay.
	# NOTE: plain `=` (not `:=`) — GDScript 3.x can't infer the type of `get_tree().paused` (property
	# access through a call result), and `:=` here is a parse error that takes the whole mod down.
	var in_menu = get_tree().paused or (scene != null and String(scene.name) == "TitleScreen")
	if not in_menu:
		return
	var box = _find_node_named(get_tree().root, "AccessibilityContainer")
	if box == null:
		return
	if box.has_node(MARK_SOLO):
		return   # already injected into this menu instance
	_inject(box)


func _inject(box) -> void:
	var lbl : Dictionary = LABELS[_locale()]
	var solo := _make_toggle(MARK_SOLO, String(lbl["solo"]), bool(settings.skills_solo()), "_on_solo_toggled")
	box.add_child(solo)
	box.move_child(solo, 0)   # surface at the top of the tab so it's easy to find
	if not _logged:
		_logged = true
		print("[Synergies][settings] solo-skills toggle injected (TEST build; solo=%s)" % str(settings.skills_solo()))


# Keep a "Synergies" toggle in the char-select Run Options panel, right under Co-op. Injected once per
# panel instance; shown only while Co-op is ON (synergies are a co-op feature), hidden otherwise. Reads/
# writes the SAME ModSettings as the Accessibility toggle, so the two always agree.
func _sync_runopt_toggle(scene) -> void:
	var vbox = scene.get_node_or_null(RUNOPT_VBOX)
	if vbox == null:
		return
	var coop_btn = vbox.get_node_or_null(RUNOPT_COOP_BTN)
	var coop_on : bool = coop_btn != null and ("pressed" in coop_btn) and bool(coop_btn.pressed)
	var btn = vbox.get_node_or_null(MARK_RUNOPT)
	if btn == null:
		# inject right after the Co-op button
		var lbl : Dictionary = LABELS[_locale()]
		btn = _make_toggle(MARK_RUNOPT, String(lbl["runopt"]), bool(settings.synergies_coop()), "_on_runopt_toggled")
		# Match the native Co-op button's font (the default CheckButton font is ~2x too big here).
		if coop_btn != null and coop_btn.has_method("get_font"):
			var fnt = coop_btn.get_font("font")
			if fnt != null:
				btn.add_font_override("font", fnt)
		vbox.add_child(btn)
		if coop_btn != null:
			vbox.move_child(btn, coop_btn.get_index() + 1)
		print("[Synergies][settings] Run Options toggle injected (coop_on=%s)" % str(coop_on))
	# Show only in co-op; reflect the current saved state when visible.
	btn.visible = coop_on
	if coop_on and ("pressed" in btn) and bool(btn.pressed) != bool(settings.synergies_coop()):
		btn.pressed = bool(settings.synergies_coop())


func _make_toggle(node_name: String, text: String, pressed: bool, handler: String) -> CheckButton:
	var cb := CheckButton.new()
	cb.name = node_name
	cb.text = text
	cb.pressed = pressed          # set BEFORE connecting so it doesn't fire `toggled` on creation
	cb.connect("toggled", self, handler)
	return cb


func _on_solo_toggled(pressed: bool) -> void:
	if settings != null:
		settings.set_skills_solo(pressed)


func _on_runopt_toggled(pressed: bool) -> void:
	if settings != null:
		settings.set_synergies_coop(pressed)   # the char-select Run Options "Synergies" toggle


func _find_node_named(node, target: String):
	if String(node.name) == target:
		return node
	for c in node.get_children():
		var r = _find_node_named(c, target)
		if r != null:
			return r
	return null


func _locale() -> String:
	var l := TranslationServer.get_locale().substr(0, 2)
	return l if LABELS.has(l) else "en"
