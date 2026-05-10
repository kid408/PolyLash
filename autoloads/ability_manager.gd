extends Node

var ability_registry: Dictionary = {
	"poison_pool": {
		"script": "res://scenes/components/abilities/poison_pool_ability.gd",
		"name": "poison_pool",
		"description": "Leave behind a damaging poison pool."
	},
	"shooting": {
		"script": "res://scenes/components/abilities/shooting_ability.gd",
		"name": "shooting",
		"description": "Fire projectiles at the player."
	},
	"charge": {
		"script": "res://scenes/components/abilities/charge_ability.gd",
		"name": "charge",
		"description": "Rush toward the player and collide."
	},
	"split_on_death": {
		"script": "",
		"name": "split_on_death",
		"description": "Split into smaller slimes on death."
	},
	"explode_on_death": {
		"script": "",
		"name": "explode_on_death",
		"description": "Detonate in an AOE that can hurt both players and enemies."
	}
}

var enemy_abilities: Dictionary = {}

func _ready() -> void:
	_load_ability_configs()
	print("[AbilityManager] initialized with %d registered abilities" % ability_registry.size())

func _load_ability_configs() -> void:
	enemy_abilities.clear()

	var file_path := "res://config/enemy/enemy_abilities.csv"
	if not FileAccess.file_exists(file_path):
		print("[AbilityManager] missing ability config: %s" % file_path)
		return

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		printerr("[AbilityManager] failed to open enemy abilities csv")
		return

	var headers: Array = []
	var is_first_line := true

	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#") or line.begins_with("-1"):
			if is_first_line and not line.begins_with("#"):
				headers = Array(line.split(","))
				is_first_line = false
			continue

		var values := line.split(",")
		if values.size() < 2:
			continue

		var enemy_id := values[0].strip_edges()
		var ability_id := values[1].strip_edges()
		if enemy_id.is_empty() or ability_id.is_empty():
			continue

		var config: Dictionary = {"ability_id": ability_id}
		for i in range(2, min(values.size(), headers.size())):
			var key: String = str(headers[i]).strip_edges()
			var value: String = str(values[i]).strip_edges()
			if value.is_empty():
				continue
			if value.is_valid_float():
				config[key] = float(value)
			elif value.is_valid_int():
				config[key] = int(value)
			else:
				config[key] = value

		if not enemy_abilities.has(enemy_id):
			enemy_abilities[enemy_id] = []
		enemy_abilities[enemy_id].append(config)

	file.close()
	print("[AbilityManager] loaded abilities for %d enemies" % enemy_abilities.size())

func create_abilities_for_enemy(enemy: Node2D, enemy_id: String) -> Array:
	var abilities: Array = []
	if not enemy_abilities.has(enemy_id):
		return abilities

	for config_variant in enemy_abilities[enemy_id]:
		if not (config_variant is Dictionary):
			continue
		var config: Dictionary = config_variant
		var ability: AbilityBase = create_ability(str(config.get("ability_id", "")), enemy, config)
		if ability != null:
			abilities.append(ability)
	return abilities

func create_ability(ability_id: String, enemy: Node2D, config: Dictionary = {}) -> AbilityBase:
	if not ability_registry.has(ability_id):
		push_error("[AbilityManager] unknown ability id: %s" % ability_id)
		return null

	var ability_info: Dictionary = ability_registry[ability_id]
	var script_path := str(ability_info.get("script", ""))
	if script_path.is_empty():
		return null

	var script := load(script_path)
	if script == null:
		push_error("[AbilityManager] failed to load ability script: %s" % script_path)
		return null

	var ability := Node.new()
	ability.set_script(script)
	ability.name = ability_id.capitalize() + "Ability"
	enemy.add_child(ability)

	if ability.has_method("setup"):
		ability.setup(enemy, config)

	print("[AbilityManager] created %s for %s" % [ability_id, enemy.name])
	return ability

func register_ability(ability_id: String, script_path: String, display_name: String, description: String = "") -> void:
	ability_registry[ability_id] = {
		"script": script_path,
		"name": display_name,
		"description": description,
	}
	print("[AbilityManager] registered ability %s (%s)" % [display_name, ability_id])

func get_all_ability_types() -> Array:
	return ability_registry.keys()

func get_ability_info(ability_id: String) -> Dictionary:
	return ability_registry.get(ability_id, {})

func get_enemy_abilities(enemy_id: String) -> Array:
	return enemy_abilities.get(enemy_id, [])

func has_ability(enemy_id: String, ability_id: String) -> bool:
	if not enemy_abilities.has(enemy_id):
		return false
	for config_variant in enemy_abilities[enemy_id]:
		if not (config_variant is Dictionary):
			continue
		if str((config_variant as Dictionary).get("ability_id", "")) == ability_id:
			return true
	return false

func generate_ability_config_template(ability_id: String) -> String:
	if not ability_registry.has(ability_id):
		return ""

	var script_path := str(ability_registry[ability_id].get("script", ""))
	if script_path.is_empty():
		return ""

	var script := load(script_path)
	if script == null:
		return ""

	var temp_ability := Node.new()
	temp_ability.set_script(script)

	var template := ""
	if temp_ability.has_method("get_config_template"):
		var config: Dictionary = temp_ability.get_config_template()
		var values: Array[String] = []
		for key_variant in config.keys():
			values.append(str(config[key_variant]))
		template = ",".join(values)

	temp_ability.queue_free()
	return template
