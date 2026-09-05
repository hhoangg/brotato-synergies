# Entry point for the Co-op Synergies mod (ModLoader).
# v0.1.0 is a loadable SKELETON: it spawns the persistent controller and logs the version.
# No script extensions are installed yet — the skill/affinity hooks land once the per-player
# input spike (the feasibility gate, see the co-op-depth design doc) is validated.
extends Node

const Config = preload("res://mods-unpacked/tato-Synergies/config.gd")
const SynergiesController = preload("res://mods-unpacked/tato-Synergies/lib/synergies_controller.gd")


func _init() -> void:
	# No hooks yet. The skill framework will install its script extensions here later.
	pass


func _ready() -> void:
	var controller = SynergiesController.new()
	controller.name = "SynergiesController"
	get_tree().root.call_deferred("add_child", controller)
	print("[Synergies] loaded v" + Config.MOD_VERSION)
