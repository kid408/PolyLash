extends RefCounted
class_name ShopDomainService

# ============================================================================
# ShopDomainService - 商店事务统一入口
# ============================================================================

static func try_purchase(price: int, apply_callback: Callable) -> Dictionary:
	if price < 0:
		return {"success": false, "reason": "价格非法"}

	if not apply_callback.is_valid():
		return {"success": false, "reason": "购买回调无效"}

	if not RunStateService.spend_run_gold(price):
		return {"success": false, "reason": "金币不足"}

	var applied := bool(apply_callback.call())
	if not applied:
		RunStateService.add_run_gold(price)
		return {"success": false, "reason": "效果应用失败"}

	return {"success": true, "reason": ""}

static func try_reroll(price: int, reroll_callback: Callable) -> Dictionary:
	if price < 0:
		return {"success": false, "reason": "刷新价格非法"}

	if not reroll_callback.is_valid():
		return {"success": false, "reason": "刷新回调无效"}

	if not RunStateService.spend_run_gold(price):
		return {"success": false, "reason": "金币不足"}

	var ok := bool(reroll_callback.call())
	if not ok:
		RunStateService.add_run_gold(price)
		return {"success": false, "reason": "刷新失败"}

	return {"success": true, "reason": ""}
