# Debuff 系统快速上手指南

## 🚀 快速开始

### 1. 为敌人添加 StatusComponent

**在 enemy.gd 的 _ready() 函数中添加**:

```gdscript
func _ready() -> void:
	super._ready()
	
	# ... 原有代码
	
	# 添加 StatusComponent（如果不存在）
	if not has_node("StatusComponent"):
		var status_comp = Node.new()
		status_comp.name = "StatusComponent"
		status_comp.set_script(load("res://scenes/components/status_component.gd"))
		add_child(status_comp)
		print("[Enemy] StatusComponent 已添加")
```

### 2. 测试金币 Bug 修复

```
1. 运行游戏 (F5)
2. 击杀敌人
3. 观察金币大小（应该是角色的 1/4）
4. 靠近金币
5. 观察金币是否消失
6. 检查控制台输出
```

**预期输出**:
```
[GoldCoin] 金币初始化完成，collision_mask=1
[GoldCoin] body_entered 触发: PlayerPyro, 是否在player组: true
[GoldCoin] _pickup 被调用，玩家: PlayerPyro
[GoldCoin] ✅ 拾取金币成功: 5
[GoldCoin] 调用 queue_free()
```

### 3. 测试 P2-3 Debuff 延长

```
1. 装备咒术师圣物（Lv.1）
2. 对敌人应用任何 Debuff
3. 观察控制台输出
```

**测试代码**（在技能中）:
```gdscript
var enemy = get_enemy_reference()
var status_comp = enemy.get_node_or_null("StatusComponent")
if status_comp:
	status_comp.apply_status("burn", 3.0, 5.0)
```

**预期输出**:
```
[StatusComponent] [P2-3] Debuff 延长: burn, 3.0秒 -> 4.5秒 (+50%)
[StatusComponent] 应用新状态: burn, 层数: 1, 持续时间: 4.5秒
```

### 4. 测试 P2-4 诅咒叠加

```
1. 装备咒术师圣物（Lv.2）
2. 选择 Pyro 角色
3. 画闭合图形
4. 让敌人进入火海
5. 观察敌人血量和飘字
```

**预期输出**:
```
[SkillFirePath] [P2-4] 诅咒叠加激活
[SkillFirePath] [P2-4] 诅咒计时器已启动
[SkillFirePath] [P2-4] 对 Enemy 叠加诅咒
[StatusComponent] 应用新状态: curse, 层数: 1, 持续时间: 5.0秒
[StatusComponent] [P2-4] 诅咒伤害: 3 (基础3.0 x 1层)
[StatusComponent] 刷新状态: curse, 层数: 2, 持续时间: 5.0秒
[StatusComponent] [P2-4] 诅咒伤害: 6 (基础3.0 x 2层)
```

---

## 📋 API 快速参考

### 应用状态
```gdscript
status_component.apply_status(
	"burn",    # 状态名称
	3.0,       # 持续时间（秒）
	5.0,       # 效果值（伤害/减速比例）
	1,         # 叠加层数
	1.0        # Tick 间隔
)
```

### 检查状态
```gdscript
if status_component.has_status("burn"):
	var stacks = status_component.get_status_stacks("burn")
	var value = status_component.get_status_value("burn")
```

### 移除状态
```gdscript
status_component.remove_status("burn")
```

---

## 🎯 状态类型

| 状态 | 效果 | 视觉 | 飘字 |
|-----|------|------|------|
| burn | 每秒造成固定伤害 | 红橙色闪烁 | "BURN!" |
| slow | 降低移动速度 | 无 | 无 |
| curse | 每秒造成伤害（随层数增加） | 紫色闪烁 | "CURSE x{层数}!" |

---

## 🐛 常见问题

### 问题 1: 敌人没有 StatusComponent
**解决**: 在 enemy.gd 的 _ready() 中动态添加（见上方代码）

### 问题 2: 诅咒不叠加
**检查**:
1. 是否装备咒术师圣物 Lv.2
2. 是否画了闭合图形
3. 敌人是否在区域内
4. 控制台是否有错误

### 问题 3: Debuff 持续时间不延长
**检查**:
1. 是否装备咒术师圣物 Lv.1
2. BondManager 是否正确加载
3. 控制台是否有 P2-3 输出

---

## 📊 数值参考

### 燃烧 (Burn)
- 基础伤害: 5 点/秒
- 持续时间: 3 秒
- 总伤害: 15 点

### 减速 (Slow)
- 减速比例: 50%
- 持续时间: 2 秒

### 诅咒 (Curse)
- 基础伤害: 3 点/秒/层
- 持续时间: 5 秒
- 叠加间隔: 1 秒
- 最大层数: 无限制（建议添加上限）

---

## 🔧 调试命令

### 手动应用状态
```gdscript
# 在控制台或调试脚本中
var enemy = get_tree().get_nodes_in_group("enemies")[0]
var status_comp = enemy.get_node("StatusComponent")
status_comp.apply_status("burn", 10.0, 5.0)
```

### 查看所有状态
```gdscript
print(status_comp.active_statuses)
```

### 清除所有状态
```gdscript
status_comp.clear_all_statuses()
```

---

**版本**: v1.0  
**日期**: 2026-01-31
