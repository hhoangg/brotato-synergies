# Persisted user settings for the Co-op Synergies mod — a mod-owned ConfigFile in user:// (we don't
# touch the game's own settings save). Two INDEPENDENT toggles, surfaced in the game's Accessibility
# options tab so players can turn the mod off and play normally:
#   - skills_solo    : active skills usable in SOLO play           (default OFF — co-op is the design)
#   - synergies_coop : the whole synergies system (skills + faction affinities) in CO-OP (default ON)
# "synergies off + solo-skills on" is a valid combo: skills in solo, nothing in co-op.
extends Reference

const PATH := "user://tato_synergies_settings.cfg"
const SECTION := "synergies"

var _cfg : ConfigFile = null

func _init() -> void:
	_cfg = ConfigFile.new()
	_cfg.load(PATH)   # missing file → every get_value falls back to its default; ignore the error code

func skills_solo() -> bool:
	return bool(_cfg.get_value(SECTION, "skills_solo", false))

func synergies_coop() -> bool:
	return bool(_cfg.get_value(SECTION, "synergies_coop", true))

func set_skills_solo(v: bool) -> void:
	_cfg.set_value(SECTION, "skills_solo", v)
	_cfg.save(PATH)

func set_synergies_coop(v: bool) -> void:
	_cfg.set_value(SECTION, "synergies_coop", v)
	_cfg.save(PATH)
