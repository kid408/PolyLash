extends PlayerBase
class_name PlayerSapper

## ==============================================================================
## 工兵 - 使用技能系统
## ==============================================================================

# ==============================================================================
# 配置参数（供技能类读取）
# ==============================================================================

@export_group("Mine Settings")
@export var mine_damage: int = 150
@export var mine_trigger_radius: float = 20.0
@export var mine_explosion_radius: float = 120.0
@export var mine_density_distance: float = 50.0
@export var mine_area_density: float = 60.0

@export_group("Totem Settings")
@export var totem_duration: float = 8.0
@export var totem_max_health: float = 200.0

# ==============================================================================
# 技能管理器
# ==============================================================================
var skill_manager: SkillManager

# ==============================================================================
# 生命周期
# ==============================================================================

func _ready() -> void:
	super._ready()
	
	# 初始化技能管理器
	skill_manager = SkillManager.new(self)
	skill_manager.debug_mode = false  # 可以设置为true来调试
	add_child(skill_manager)
	skill_manager.load_skills_from_config("sapper")

