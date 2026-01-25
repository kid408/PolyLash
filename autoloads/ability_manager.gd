extends Node

## 能力管理器 - 负责加载和创建敌人能力
## 让策划可以通过配置文件添加能力，无需编程

# ==============================================================================
# 能力注册表
# ==============================================================================
var ability_registry: Dictionary = {
	"poison_pool": {
		"script": "res://scenes/components/abilities/poison_pool_ability.gd",
		"name": "毒池",
		"description": "死亡时在地面留下持续伤害区域"
	},
	"shooting": {
		"script": "res://scenes/components/abilities/shooting_ability.gd",
		"name": "射击",
		"description": "向玩家发射投射物"
	},
	"charge": {
		"script": "res://scenes/components/abilities/charge_ability.gd",
		"name": "冲锋",
		"description": "向玩家冲刺攻击"
	}
}

# 能力配置缓存 {enemy_id: [ability_configs]}
var enemy_abilities: Dictionary = {}

# ==============================================================================
# 初始化
# ==============================================================================
func _ready() -> void:
	_load_ability_configs()
	print("[AbilityManager] 初始化完成，已注册 %d 个能力类型" % ability_registry.size())

# ==============================================================================
# 配置加载
# ==============================================================================
func _load_ability_configs() -> void:
	"""从CSV加载能力配置"""
	enemy_abilities.clear()
	
	var file_path = "res://config/enemy/enemy_abilities.csv"
	if not FileAccess.file_exists(file_path):
		print("[AbilityManager] 能力配置文件不存在: %s" % file_path)
		return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		printerr("[AbilityManager] 无法打开能力配置文件")
		return
	
	var headers: Array = []
	var is_first_line = true
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#") or line.begins_with("-1"):
			if is_first_line and not line.begins_with("#"):
				headers = Array(line.split(","))
				is_first_line = false
			continue
		
		var values = line.split(",")
		if values.size() < 2:
			continue
		
		var enemy_id = values[0].strip_edges()
		var ability_id = values[1].strip_edges()
		
		if ability_id.is_empty():
			continue
		
		# 解析配置
		var config: Dictionary = {
			"ability_id": ability_id
		}
		
		# 根据表头解析其他参数
		for i in range(2, min(values.size(), headers.size())):
			var key = headers[i].strip_edges()
			var value = values[i].strip_edges()
			
			if not value.is_empty() and value != "":
				# 尝试转换为数字
				if value.is_valid_float():
					config[key] = float(value)
				elif value.is_valid_int():
					config[key] = int(value)
				else:
					config[key] = value
		
		# 添加到敌人能力列表
		if not enemy_abilities.has(enemy_id):
			enemy_abilities[enemy_id] = []
		enemy_abilities[enemy_id].append(config)
	
	file.close()
	print("[AbilityManager] 加载了 %d 个敌人的能力配置" % enemy_abilities.size())

# ==============================================================================
# 能力创建
# ==============================================================================
func create_abilities_for_enemy(enemy: Node2D, enemy_id: String) -> Array:
	"""为敌人创建所有配置的能力"""
	var abilities: Array = []
	
	if not enemy_abilities.has(enemy_id):
		return abilities
	
	for config in enemy_abilities[enemy_id]:
		var ability = create_ability(config.ability_id, enemy, config)
		if ability:
			abilities.append(ability)
	
	return abilities

func create_ability(ability_id: String, enemy: Node2D, config: Dictionary = {}) -> AbilityBase:
	"""创建单个能力实例"""
	if not ability_registry.has(ability_id):
		push_error("[AbilityManager] 未知的能力ID: %s" % ability_id)
		return null
	
	var ability_info = ability_registry[ability_id]
	var script = load(ability_info.script)
	if not script:
		push_error("[AbilityManager] 无法加载能力脚本: %s" % ability_info.script)
		return null
	
	var ability = Node.new()
	ability.set_script(script)
	ability.name = ability_id.capitalize() + "Ability"
	
	# 添加到敌人节点
	enemy.add_child(ability)
	
	# 初始化配置
	if ability.has_method("setup"):
		ability.setup(enemy, config)
	
	print("[AbilityManager] 为 %s 创建能力: %s" % [enemy.name, ability_info.name])
	return ability

# ==============================================================================
# 能力注册
# ==============================================================================
func register_ability(ability_id: String, script_path: String, display_name: String, description: String = "") -> void:
	"""注册新的能力类型（用于扩展）"""
	ability_registry[ability_id] = {
		"script": script_path,
		"name": display_name,
		"description": description
	}
	print("[AbilityManager] 注册新能力: %s (%s)" % [display_name, ability_id])

func get_all_ability_types() -> Array:
	"""获取所有已注册的能力类型"""
	return ability_registry.keys()

func get_ability_info(ability_id: String) -> Dictionary:
	"""获取能力信息"""
	return ability_registry.get(ability_id, {})

# ==============================================================================
# 配置查询
# ==============================================================================
func get_enemy_abilities(enemy_id: String) -> Array:
	"""获取敌人的所有能力配置"""
	return enemy_abilities.get(enemy_id, [])

func has_ability(enemy_id: String, ability_id: String) -> bool:
	"""检查敌人是否有指定能力"""
	if not enemy_abilities.has(enemy_id):
		return false
	
	for config in enemy_abilities[enemy_id]:
		if config.ability_id == ability_id:
			return true
	return false

# ==============================================================================
# 配置生成（用于工具）
# ==============================================================================
func generate_ability_config_template(ability_id: String) -> String:
	"""生成能力配置模板（CSV格式）"""
	if not ability_registry.has(ability_id):
		return ""
	
	var script = load(ability_registry[ability_id].script)
	if not script:
		return ""
	
	var temp_ability = Node.new()
	temp_ability.set_script(script)
	
	var template = ""
	if temp_ability.has_method("get_config_template"):
		var config = temp_ability.get_config_template()
		var values = []
		for key in config.keys():
			values.append(str(config[key]))
		template = ",".join(values)
	
	temp_ability.queue_free()
	return template
