extends PlayerBase
class_name PlayerPyro

## ==============================================================================
## 烈焰者 - 使用技能系统
## ==============================================================================

# ==============================================================================
# 配置参数（供技能类读取）
# ==============================================================================

@export_group("Pyro Settings")
@export var fire_line_damage: int = 20
@export var fire_line_duration: float = 5.0
@export var fire_line_width: float = 24.0
@export var fire_sea_damage: int = 40
@export var fire_sea_duration: float = 5.0
@export var fire_nova_radius: float = 140.0
@export var fire_nova_damage: int = 35
@export var fire_nova_duration: float = 3.0

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
	skill_manager.load_skills_from_config("pyro")

