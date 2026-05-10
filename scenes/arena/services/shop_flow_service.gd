extends RefCounted
class_name ShopFlowService

# ============================================================================
# ShopFlowService - 负责商店流程
# ============================================================================

var _shop_panel: Node = null
var _spawner: Node = null
const SHOP_INTERVAL_WAVES: int = 1

func setup(shop_panel: Node, spawner: Node) -> void:
	_shop_panel = shop_panel
	_spawner = spawner

func show_shop_for_wave(wave_number: int) -> bool:
	if not _should_open_shop(wave_number):
		print("[ShopFlowService] 波次 %d 跳过商店，直接进入下一波" % wave_number)
		SoundManager.play("wave_start")
		if _spawner and _spawner.has_method("resume_spawning"):
			_spawner.resume_spawning()
		return false

	if _shop_panel == null:
		printerr("[ShopFlowService] 错误: 找不到 ShopPanel 节点")
		if _spawner and _spawner.has_method("resume_spawning"):
			_spawner.resume_spawning()
		return false

	SoundManager.play("shop_open")
	if _shop_panel.has_method("show_shop"):
		_shop_panel.show_shop(wave_number + 1)
	return true

func handle_shop_next_wave(run_save_service: RunSaveService, slot_index: int, wave_number: int) -> bool:
	var saved := run_save_service.auto_save_progress(slot_index, wave_number, "shop_closed")
	if _spawner and _spawner.has_method("resume_spawning"):
		_spawner.resume_spawning()
	return saved

func _should_open_shop(wave_number: int) -> bool:
	if wave_number <= 0:
		return true
	return wave_number % SHOP_INTERVAL_WAVES == 0
