# P2 状态系统快速参考

## 🎯 核心API

### 应用状态到敌人
```gdscript
# 基础用法
enemy.apply_status("curse", 5.0, 2.0)

# 完整参数
enemy.apply_status(
    "curse",      # 状态类型
    5.0,          # 持续时间（秒）
    2.0,          # 效果值（伤害/减速比例）
    1,            # 叠加层数（可选，默认1）
    1.0           # DoT触发间隔（可选，默认1.0秒）
)
```

### 检查状态
```gdscript
# 检查是否有状态
if enemy.has_status("curse"):
    print("敌人被诅咒了！")

# 获取状态层数
var stacks = enemy.get_status_stacks("curse")
print("诅咒层数: %d" % stacks)

# 清除所有状态
enemy.clear_all_statuses()
```

---

## 📋 支持的状态类型

| 状态 | 类型 | 初始效果 | DoT效果 | 可叠加 |
|-----|------|---------|---------|--------|
| `burn` | 燃烧 | 无 | 每秒固定伤害 | 否 |
| `slow` | 减速 | 降低移动速度 | 无 | 否 |
| `curse` | 诅咒 | 无 | 每层每秒伤害 | 是 |
| `freeze` | 冰冻 | 停止移动 | 无 | 否 |

---

## 🔧 P2 机制快速查询

### P2-3: Debuff延长 (咒术师 Lv.1)
```gdscript
# 自动触发，无需手动调用
# 所有 Debuff 持续时间 × 1.5

# 检查是否激活
if BondManager.has_mechanic("debuff_duration"):
    print("Debuff延长已激活")
```

### P2-4: 诅咒叠加 (咒术师 Lv.2)
```gdscript
# 在闭合区域生成时自动触发
# 每秒对区域内敌人叠加诅咒

# 手动添加诅咒叠加效果
_add_curse_stacking_effect(area, polygon)
```

---

## 💡 使用示例

### 示例 1: 燃烧效果
```gdscript
# 对敌人施加燃烧，每秒造成 5 点伤害，持续 3 秒
enemy.apply_status("burn", 3.0, 5.0)
```

### 示例 2: 减速效果
```gdscript
# 对敌人施加减速，降低 50% 移动速度，持续 2 秒
enemy.apply_status("slow", 2.0, 0.5)
```

### 示例 3: 诅咒叠加
```gdscript
# 每秒叠加 1 层诅咒，每层每秒造成 2 点伤害
for i in range(5):
    await get_tree().create_timer(1.0).timeout
    enemy.apply_status("curse", 5.0, 2.0, 1)
    
# 5 秒后，敌人有 5 层诅咒，每秒受到 10 点伤害
```

### 示例 4: 冰冻效果
```gdscript
# 对敌人施加冰冻，完全停止移动，持续 1.5 秒
enemy.apply_status("freeze", 1.5, 0.0)
```

---

## 🎨 视觉反馈

### 浮动文字
- 燃烧: "BURN!" (橙红色)
- 诅咒: "CURSE x3!" (紫色)

### 控制台日志
```
[Enemy] 应用状态: curse 持续5.0秒, 值=2.0, 层数=1
[Enemy] [P2-3] Debuff延长触发: curse 持续时间 5.0秒 -> 7.5秒 (x1.5)
[Enemy] [P2-4] 诅咒叠加: Enemy_1 层数 0 -> 1
[Enemy] CURSE DoT伤害: 2 (层数: 1)
```

---

## ⚠️ 注意事项

### 1. 状态叠加规则
- **诅咒**: 可无限叠加，每层独立计算伤害
- **燃烧/减速/冰冻**: 不可叠加，只刷新持续时间

### 2. P2-3 Debuff延长
- 只影响 Debuff（负面状态）
- 在 `apply_status()` 入口处自动检查
- 不需要手动调用

### 3. P2-4 诅咒叠加
- 只在闭合区域内触发
- 每秒自动叠加，无需手动调用
- 诅咒持续时间会被 P2-3 延长

### 4. 性能优化
- 状态字典为空时不处理，避免空循环
- DoT 效果使用计时器，不是每帧计算
- 状态过期时自动清理

---

## 🐛 调试技巧

### 1. 查看敌人当前状态
```gdscript
print(enemy.active_statuses)
# 输出: {curse: {duration: 5.0, value: 2.0, stacks: 3, ...}}
```

### 2. 强制清除状态
```gdscript
enemy.clear_all_statuses()
```

### 3. 检查羁绊激活
```gdscript
print("Debuff延长: ", BondManager.has_mechanic("debuff_duration"))
print("诅咒叠加: ", BondManager.has_mechanic("curse_stack"))
```

---

## 📚 相关文档

- `P2_STATUS_SYSTEM_COMPLETE.md` - 完整实现报告
- `P2_TESTING_GUIDE.md` - 测试指南
- `DEBUFF_SYSTEM_QUICK_START.md` - 系统设计文档
- `scenes/unit/enemy/enemy.gd` - 源代码

---

**最后更新:** 2026-01-31
