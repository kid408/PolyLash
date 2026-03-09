extends RefCounted
class_name MetaProgressService

# ============================================================================
# MetaProgressService - 局外进度唯一入口（soul_shard）
# ============================================================================

static func get_soul_shard() -> int:
	return DataManager.get_soul_shard()

static func set_soul_shard(amount: int) -> void:
	DataManager.set_soul_shard(amount)

static func add_soul_shard(amount: int) -> void:
	DataManager.add_soul_shard(amount)

static func spend_soul_shard(amount: int) -> bool:
	return DataManager.spend_soul_shard(amount)

static func settle_from_run(run_income: int = -1) -> Dictionary:
	return DataManager.settle_run_to_soul_shard(run_income)
