extends Resource
class_name WaveData


enum SpawnType{
	FIXED,
	RANDOM
}

@export var from:int
@export var to:int
@export var wave_time := 20.0
@export var units:Array[WaveUnitData]

@export var spawn_type := SpawnType.RANDOM
@export var fixed_spawn_time := 1.0
@export var min_spawn_time := 1.0
@export var max_spawn_time := 1.0

func get_random_unit_scene() -> PackedScene:
	if units.is_empty():
		printerr("No units.")
		return null
		
	var enemies:Array[PackedScene]
	var weights:Array[float]
	
	for unit in units:
		enemies.append(unit.unit_scene)
		# 统计随机权重
		weights.append(unit.weight)
	
	# 创建随机生成器
	var rng := RandomNumberGenerator.new()
	# 根据权重随机
	var random_unit =enemies[rng.rand_weighted(weights)]
	
	return random_unit

func is_valid_index(index:int) -> bool:
	return index >= from and index <= to
