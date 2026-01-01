extends Resource
class_name WaveData

# 波次数据资源类（已废弃，保留用于兼容性）
# 现在使用CSV配置系统，见 config/wave/wave_config.csv 和 config/wave/wave_units_config.csv

@export var wave_time: float = 20.0
@export var spawn_type: String = "RANDOM"
@export var fixed_spawn_time: float = 1.0
@export var min_spawn_time: float = 0.8
@export var max_spawn_time: float = 1.5
