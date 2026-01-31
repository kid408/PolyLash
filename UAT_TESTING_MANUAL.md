# 羁绊系统 UAT 验收测试手册

## 📅 测试日期
2026-01-31

## 🎯 测试目标
验证 18 个已实现的羁绊机制和视觉反馈系统是否正常工作。

---

## 📋 Task 1: 浮动文字系统代码

### 1.1 Global.gd 中的浮动文字接口

**位置:** `autoloads/global.gd`

**完整代码:**
```gdscript
# 预加载浮动文字场景
const FLOATING_TEXT_SCENE = preload("uid://cp86d6q6156la")

## 生成浮动文字
## @param pos: 世界坐标位置
## @param value: 显示的文字内容
## @param color: 文字颜色
func spawn_floating_text(pos: Vector2, value: String, color: Color) -> void:
	if FLOATING_TEXT_SCENE:
		var text_instance = FLOATING_TEXT_SCENE.instantiate()
		# 添加到当前场景中
		get_tree().current_scene.add_child(text_instance)
		
		# 随机偏移位置（在主角四周）
		var random_offset = Vector2(randf_range(-40, 40), randf_range(-40, 40))
		text_instance.global_position = pos + random_offset
		
		text_instance.setup(value, color)
```

**说明:**
- ✅ 浮动文字系统已存在，无需新增代码
- ✅ 自动处理文字的创建、动画和销毁
- ✅ 支持随机偏移，避免文字重叠

---

### 1.2 调用示例

#### 示例 1: P2-3 Debuff延长
**位置:** `scenes/unit/enemy/enemy.gd` → `apply_status()`

```gdscript
# P2-3: Debuff延长机制（咒术师 Lv.1）
if BondManager.has_mechanic("debuff_duration"):
	var original_duration = duration
	duration *= 1.5
	print("[Enemy] [P2-3] Debuff延长触发: %s 持续时间 %.1f秒 -> %.1f秒 (x1.5)" % [
		type,
		original_duration,
		duration
	])
	# 视觉反馈
	Global.spawn_floating_text(global_position, "EXTENDED!", Color(0.8, 0.0, 0.8))
```

#### 示例 2: P1-1 击杀回能
**位置:** `scenes/unit/enemy/enemy.gd` → `destroy_enemy()`

```gdscript
# P1-1: 击杀回能（墨灵羁绊）
if BondManager.has_mechanic("kill_regen"):
	var bonus_energy = BondManager.get_mechanic_value("kill_regen")
	energy_drop += bonus_energy
	print("[Enemy] [P1-1] 击杀回能触发: 基础%d + 墨灵%d = %d" % [
		enemy_config.get("energy_drop", 5),
		bonus_energy,
		energy_drop
	])
	# 视觉反馈（在玩家位置显示）
	Global.spawn_floating_text(Global.player.global_position, "+%d ENERGY" % bonus_energy, Color(0.5, 1.5, 2.0))
```

#### 示例 3: P1-4 金币轨迹
**位置:** `scenes/skills/skill_drawing_base.gd` → `_check_and_spawn_gold_trail()`

```gdscript
# 生成金币实体
Global.spawn_coin(current_pos, gold_amount)
print("[%s] [P1-4] 金币轨迹触发: 生成%d金币 at (%.0f, %.0f)" % [
	skill_id,
	gold_amount,
	current_pos.x,
	current_pos.y
])
# 视觉反馈
Global.spawn_floating_text(current_pos, "GOLD!", Color.GOLD)
```

#### 示例 4: P3-2 永久牢笼
**位置:** `scenes/skills/skill_drawing_base.gd` → `_apply_permanent_cage()`

```gdscript
print("[%s] [P3-2] 永久牢笼激活" % skill_id)

# 视觉反馈
var center = _calculate_polygon_center(polygon)
Global.spawn_floating_text(center, "CAGE!", Color(0.5, 0.5, 1.0))

# 创建物理墙体...
```

---

## 📋 Task 2: Assist 羁绊安全补丁

### 2.1 BondManager 安全机制

**位置:** `autoloads/bond_manager.gd`

**已有的安全接口:**
```gdscript
## 检查是否激活了指定机制
## @param mechanic_name: 机制名称（effect_param）
## @return: 是否激活
func has_mechanic(mechanic_name: String) -> bool:
	for bond_id in active_bonds.keys():
		var bond_data = active_bonds[bond_id]
		
		for effect in bond_data.effects:
			if effect.effect_type == "mechanic" and effect.effect_param == mechanic_name:
				return true
	
	return false

## 获取机制的效果值
## @param mechanic_name: 机制名称（effect_param）
## @return: 效果值（未找到返回0）
func get_mechanic_value(mechanic_name: String) -> float:
	for bond_id in active_bonds.keys():
		var bond_data = active_bonds[bond_id]
		
		for effect in bond_data.effects:
			if effect.effect_type == "mechanic" and effect.effect_param == mechanic_name:
				return effect.effect_value
	
	return 0.0
```

**安全性说明:**
- ✅ `has_mechanic()` 返回 `false` 如果机制未实现
- ✅ `get_mechanic_value()` 返回 `0.0` 如果机制未实现
- ✅ 所有代码都使用 `if BondManager.has_mechanic("xxx")` 检查
- ✅ **不会崩溃或报错**，只是不触发效果

### 2.2 Assist 羁绊状态

**配置中的 Assist 羁绊:**
```csv
assist,tactic,1,2,mechanic,bench_cd_reduce,0.3,1,支援型,后台技能冷却减少30%
assist,tactic,2,3,mechanic,mirror_draw,1,1,支援型,激活后台角色镜像作画
```

**当前状态:**
- ✅ 配置已加载到 BondManager
- ✅ 玩家可以凑齐 Assist 羁绊（2个或3个支援型角色）
- ✅ BondManager 会正确激活 Assist 羁绊
- ✅ 但 `bench_cd_reduce` 和 `mirror_draw` 没有实现逻辑
- ✅ **不会报错**，只是不生效

**测试验证:**
```gdscript
# 在控制台测试
print(BondManager.has_mechanic("bench_cd_reduce"))  # 返回 true（如果激活）
print(BondManager.get_mechanic_value("bench_cd_reduce"))  # 返回 0.3

# 但没有代码使用这些值，所以不会有任何效果
```

**结论:** ✅ **无需额外补丁，系统已经安全**

---

## 📋 Task 3: 流派测试指南

### 🔥 流派 1: 核爆流 (Blaster)

#### 羁绊配置
- **爆破师 Lv.1** (1个): 闭合图形伤害 +20%
- **爆破师 Lv.2** (2个): 二次爆炸
- **爆破师 Lv.3** (3个): 连锁反应

#### 推荐角色组合
**选项 1: 单角色测试**
- 选择 1 个 `mastery_tag = blaster` 的角色
- 激活 Lv.1 羁绊

**选项 2: 双角色测试**
- 选择 2 个 `mastery_tag = blaster` 的角色
- 激活 Lv.1 + Lv.2 羁绊

**选项 3: 三角色测试**
- 选择 3 个 `mastery_tag = blaster` 的角色
- 激活 Lv.1 + Lv.2 + Lv.3 羁绊

#### 测试步骤

**测试 P0-1: 闭合图形伤害加成 (Lv.1)**
1. 进入游戏
2. 使用画图技能（Q键）形成闭合区域
3. 观察控制台输出

**预期结果:**
```
[SkillFirePath] [P0-1] 闭合图形伤害加成: 40 -> 48 (+20%)
```

---

**测试 P2-1: 二次爆炸 (Lv.2)**
1. 激活爆破师 Lv.2（2个角色）
2. 使用画图技能形成闭合区域
3. 观察是否有延迟 0.3 秒的二次爆炸

**预期结果:**
- 主爆炸后 0.3 秒触发二次爆炸
- 二次爆炸范围扩大 1.5 倍
- 二次爆炸伤害为主爆炸的 50%
- 浮动文字: "AFTERSHOCK!" (Orange)
- 控制台输出:
```
[SkillFirePath] [P2-1] 二次爆炸触发: 伤害=20 (原始伤害的50%)
```

---

**测试 P3-1: 连锁反应 (Lv.3)**
1. 激活爆破师 Lv.3（3个角色）
2. 使用画图技能圈住部分敌人
3. 观察区域外的敌人是否受到连锁伤害

**预期结果:**
- 区域外所有敌人受到 30% 连锁伤害
- 每个敌人头顶显示: "CHAIN!" (Orange)
- 小爆炸特效
- 控制台输出:
```
[SkillFirePath] [P3-1] 连锁反应触发，波及 5 个敌人，伤害=12
```

---

### 💰 流派 2: 炼金流 (Alchemist)

#### 羁绊配置
- **炼金术士 Lv.1** (2个): 拾取范围 +50%
- **炼金术士 Lv.2** (3个): 金币轨迹

#### 推荐角色组合
**选项 1: 双角色测试**
- 选择 2 个 `origin_tag = alchemist` 的角色
- 激活 Lv.1 羁绊

**选项 2: 三角色测试**
- 选择 3 个 `origin_tag = alchemist` 的角色
- 激活 Lv.1 + Lv.2 羁绊

#### 测试步骤

**测试 P1-4: 金币轨迹 (Lv.2)**
1. 激活炼金术士 Lv.2（3个角色）
2. 使用画图技能（Q键）连续划线
3. 观察是否每 100 像素生成金币

**预期结果:**
- 每 100 像素生成 1 个金币实体
- 金币位置显示: "GOLD!" (Gold)
- 金币可以被拾取
- 控制台输出:
```
[SkillDrawingBase] [P1-4] 金币轨迹触发: 生成1金币 at (500.0, 300.0)
```

**视觉验证:**
- 画线时看到金色 "GOLD!" 文字
- 金币实体在地面上闪烁
- 靠近金币时自动吸附并拾取

---

### 🔮 流派 3: 诅咒流 (Hexer)

#### 羁绊配置
- **咒术师 Lv.1** (1个): Debuff 持续时间 +50%
- **咒术师 Lv.2** (2个): 诅咒叠加
- **咒术师 Lv.3** (3个): 死亡画笔（未实现）

#### 推荐角色组合
**选项 1: 单角色测试**
- 选择 1 个 `mastery_tag = hexer` 的角色
- 激活 Lv.1 羁绊

**选项 2: 双角色测试**
- 选择 2 个 `mastery_tag = hexer` 的角色
- 激活 Lv.1 + Lv.2 羁绊

#### 测试步骤

**测试 P2-3: Debuff延长 (Lv.1)**
1. 激活咒术师 Lv.1（1个角色）
2. 使用画图技能形成闭合区域
3. 观察敌人头顶的浮动文字

**预期结果:**
- 敌人头顶显示: "EXTENDED!" (Purple)
- 诅咒持续时间从 5 秒延长至 7.5 秒
- 控制台输出:
```
[Enemy] [P2-3] Debuff延长触发: curse 持续时间 5.0秒 -> 7.5秒 (x1.5)
```

---

**测试 P2-4: 诅咒叠加 (Lv.2)**
1. 激活咒术师 Lv.2（2个角色）
2. 使用画图技能圈住多个敌人
3. 等待 5 秒，观察诅咒层数增长

**预期结果:**
- 每秒敌人头顶显示: "CURSE x1!", "CURSE x2!", "CURSE x3!" (Purple)
- 敌人血量持续下降
- 控制台输出:
```
[SkillDrawingBase] [P2-4] 诅咒叠加激活
[SkillDrawingBase] [P2-4] 诅咒计时器已启动
[SkillDrawingBase] [P2-4] 对 Enemy_1 叠加诅咒
[Enemy] [P2-4] 诅咒叠加: Enemy_1 层数 0 -> 1
[Enemy] CURSE DoT伤害: 2 (层数: 1)
[Enemy] [P2-4] 诅咒叠加: Enemy_1 层数 1 -> 2
[Enemy] CURSE DoT伤害: 4 (层数: 2)
```

**视觉验证:**
- 紫色 "CURSE xN" 文字每秒出现
- 敌人血条持续下降
- 即使敌人离开圈内，诅咒仍会持续 7.5 秒（受 P2-3 影响）

---

**测试 P2-3 + P2-4 联动**
1. 同时激活咒术师 Lv.1 和 Lv.2
2. 使用画图技能圈住敌人
3. 观察诅咒持续时间

**预期结果:**
- 诅咒基础持续时间: 5 秒
- 延长后持续时间: 7.5 秒
- 即使敌人离开圈内，诅咒仍会持续 7.5 秒
- 每秒叠加 1 层，最多可叠加 7-8 层

---

## 📊 完整的浮动文字列表

| 机制 | 浮动文字 | 颜色 | 触发条件 |
|------|---------|------|---------|
| P1-1: 击杀回能 | "+5 ENERGY" | Cyan | 击杀敌人 |
| P1-2: 霸体 | "SUPER ARMOR!" | Orange | 画图时受击 |
| P1-4: 金币轨迹 | "GOLD!" | Gold | 画线每100px |
| P2-2: 反伤墙 | "THORNS!" | Orange | 敌人碰撞线段 |
| P2-3: Debuff延长 | "EXTENDED!" | Purple | Debuff应用时 |
| P2-4: 诅咒叠加 | "CURSE x1", "CURSE x2" | Purple | 每秒叠加 |
| P3-1: 连锁反应 | "CHAIN!" | Orange | 区域外敌人 |
| P3-2: 永久牢笼 | "CAGE!" | Blue | 牢笼生成时 |
| P3-3: 小图形暴击 | "CRITICAL!" | Yellow | 小图形触发 |
| P4-2: 图形继承 | "INK INHERIT!" | Cyan | 切换角色时 |
| P4-4: 灵魂附着 | "SOUL ATTACH!" | Purple | 受击反击时 |

---

## 🎮 通用测试流程

### 1. 准备阶段
1. 打开游戏
2. 进入角色选择界面
3. 根据测试流派选择对应角色
4. 确认羁绊激活状态（查看UI）

### 2. 测试阶段
1. 进入战斗
2. 执行对应的操作（画图、击杀、受击等）
3. 观察浮动文字是否出现
4. 检查控制台输出是否正确

### 3. 验证标准
- ✅ 浮动文字正确显示
- ✅ 颜色符合规范
- ✅ 控制台输出正确
- ✅ 效果符合预期
- ✅ 无报错或崩溃

---

## 🐛 常见问题排查

### 问题 1: 浮动文字不显示
**可能原因:**
- FLOATING_TEXT_SCENE 未正确加载
- 位置超出屏幕范围

**解决方法:**
1. 检查 `Global.gd` 中的 `FLOATING_TEXT_SCENE` 是否正确
2. 检查 `spawn_floating_text()` 是否被调用
3. 检查控制台是否有错误信息

### 问题 2: 羁绊未激活
**可能原因:**
- 角色配置错误
- 羁绊标签不匹配

**解决方法:**
1. 检查 `player_config.csv` 中的羁绊标签
2. 检查 `bond_config.csv` 中的羁绊配置
3. 在控制台输入: `BondManager.print_active_bonds()`

### 问题 3: Assist 羁绊报错
**可能原因:**
- 不应该报错，系统已经安全

**解决方法:**
- 如果真的报错，请提供错误信息
- 检查是否有其他代码直接调用 Assist 机制

---

## ✅ 验收标准

### 核心功能
- [ ] 18 个羁绊机制全部可测试
- [ ] 11 个浮动文字全部正确显示
- [ ] 控制台输出清晰准确
- [ ] 无崩溃或报错

### 视觉反馈
- [ ] 浮动文字颜色符合规范
- [ ] 浮动文字位置合理
- [ ] 浮动文字动画流畅

### 性能
- [ ] 大量浮动文字不卡顿
- [ ] 羁绊计算不影响帧率

---

## 📝 测试报告模板

```
测试日期: ____________________
测试人员: ____________________

流派 1: 核爆流 (Blaster)
- [ ] P0-1: 闭合图形伤害加成
- [ ] P2-1: 二次爆炸
- [ ] P3-1: 连锁反应

流派 2: 炼金流 (Alchemist)
- [ ] P1-4: 金币轨迹

流派 3: 诅咒流 (Hexer)
- [ ] P2-3: Debuff延长
- [ ] P2-4: 诅咒叠加

发现的问题:
1. ____________________
2. ____________________
3. ____________________

总体评价: ____________________
```

---

**文档版本:** 1.0  
**最后更新:** 2026-01-31  
**状态:** ✅ 准备就绪

