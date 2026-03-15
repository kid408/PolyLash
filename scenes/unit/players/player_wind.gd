extends PlayerBase
class_name PlayerWind

## ==============================================================================
## 御风者 - 使用技能系统
## ==============================================================================

# ==============================================================================
# 配置参数（供技能类读取）
# ==============================================================================

@export_group("Wind Settings")
@export var wind_wall_pull_force: float = 350.0
@export var wind_wall_damage: int = 15
@export var wind_wall_duration: float = 3.0
@export var wind_wall_width: float = 24.0
@export var wind_wall_effect_radius: float = 120.0
@export var storm_zone_damage: int = 30
@export var storm_zone_pull_force: float = 400.0
@export var storm_zone_duration: float = 3.0
@export var storm_eye_radius: float = 140.0
@export var storm_eye_damage: int = 35
@export var storm_eye_pull_force: float = 500.0
@export var storm_eye_duration: float = 3.0

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
	skill_manager.load_skills_from_config("wind")

