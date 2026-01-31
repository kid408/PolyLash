# 羁绊系统快速参考 - Bond System Quick Reference

## 🎯 新羁绊一览

### 身世羁绊 (Origin) - 需要2-3人

| ID | 名称 | Lv.1 (2人) | Lv.2 (3人) |
|----|------|-----------|-----------|
| inkborn | 墨灵 | 魔法回复+30% | 击杀回能5点 |
| colossus | 巨擘 | 生命上限+25% | 画图霸体 |
| nomad | 风行者 | 移动速度+15% | 速度转伤害 |
| alchemist | 炼金术士 | 拾取范围+50% | 线条产金币 |

### 职能羁绊 (Mastery) - 需要1-3人

| ID | 名称 | Lv.1 (1人) | Lv.2 (2人) | Lv.3 (3人) |
|----|------|-----------|-----------|-----------|
| blaster | 爆破师 | 闭合伤害+20% | 二次爆炸 | 连锁反应 |
| architect | 筑墙者 | 线条+3秒 | 反伤墙 | 10秒牢笼 |
| hexer | 咒术师 | Debuff延长 | 诅咒叠加 | 画笔真伤5% |
| geometrist | 几何学家 | 闭合容错 | 小图暴击 | 多边形特效 |

### 战术羁绊 (Tactic) - 需要2-3人

| ID | 名称 | Lv.1 (2人) | Lv.2 (3人) |
|----|------|-----------|-----------|
| assist | 支援型 | 后台CD-30% | 镜像作画 |
| vanguard | 突击型 | 切换CD-50% | 图形继承 |
| commander | 指挥型 | 属性共享30% | 灵魂附着 |

## 👥 角色羁绊配置

| 角色 | 身世 | 职能 | 战术 | 定位 |
|------|------|------|------|------|
| 屠夫 | colossus | blaster | vanguard | 坦克爆发 |
| 火焰 | inkborn | blaster | vanguard | 高消耗AOE |
| 工兵 | alchemist | architect | assist | 布阵资源 |
| 织网 | inkborn | hexer | assist | 持续控制 |
| 疾风 | nomad | geometrist | commander | 高速精准 |
| 牧者 | alchemist | architect | commander | 召唤辅助 |

## 🎮 推荐组合

### 爆破流
**角色**: 屠夫 + 火焰 + 工兵  
**羁绊**: 爆破师 Lv.3, 巨擘 Lv.2, 墨灵 Lv.2  
**玩法**: 闭合图形连锁爆炸，高爆发AOE

### 控制流
**角色**: 工兵 + 织网 + 牧者  
**羁绊**: 筑墙者 Lv.2, 咒术师 Lv.1, 支援型 Lv.2  
**玩法**: 线条反伤，持续控制，后台增强

### 速度流
**角色**: 疾风 + 屠夫 + 火焰  
**羁绊**: 几何学家 Lv.1, 风行者 Lv.2, 突击型 Lv.2  
**玩法**: 高速切换，精准画图，速度转伤害

### 资源流
**角色**: 工兵 + 牧者 + 织网  
**羁绊**: 炼金术士 Lv.3, 筑墙者 Lv.2, 支援型 Lv.2  
**玩法**: 金币轨迹，拾取范围，后台冷却

## 💻 代码使用示例

### 检查羁绊是否激活
```gdscript
if BondManager.has_mechanic("closed_shape_dmg"):
    var bonus = BondManager.get_mechanic_value("closed_shape_dmg")
    damage *= (1.0 + bonus)
```

### 获取羁绊等级
```gdscript
var level = BondManager.get_active_bond_level("blaster")
if level >= 2:
    # 触发二次爆炸
    trigger_secondary_explosion()
```

### 获取当前标签数量
```gdscript
var count = BondManager.get_bond_current_count("inkborn")
print("墨灵标签数量: %d" % count)
```

### 应用属性加成
```gdscript
var stats = {
    "max_health": 100,
    "energy_regen": 0.5,
    "speed": 500
}
stats = BondManager.apply_stat_modifiers(stats)
```

### 获取所有激活的机制
```gdscript
var mechanics = BondManager.get_active_mechanics()
for mechanic in mechanics:
    print("机制: %s = %.2f" % [mechanic.effect_param, mechanic.effect_value])
```

## 🔧 属性类型说明

### 百分比属性 (_pct 后缀)
- `energy_regen_pct`: 能量回复速度百分比（乘法）
- `max_health_pct`: 生命上限百分比（乘法）
- `movement_speed_pct`: 移动速度百分比（乘法）
- `pickup_range_pct`: 拾取范围百分比（乘法）

**计算方式**: `final_value = base_value * (1.0 + bonus_pct)`

### 固定值属性
- `stat_share`: 属性共享比例（加法）

**计算方式**: `final_value = base_value + bonus_value`

### 机制效果 (mechanic)
需要在代码中实现的特殊机制，存储为字符串标识。

## 📊 实现优先级

### P0 - 必须实现
1. `closed_shape_dmg` - 闭合图形伤害加成
2. `line_duration` - 线条持续时间
3. `shape_tolerance` - 图形闭合容错率

### P1 - 重要功能
4. `kill_regen` - 击杀回能
5. `super_armor` - 霸体
6. `speed_to_damage` - 速度转伤害
7. `gold_trail` - 金币轨迹

### P2 - 进阶功能
8. `secondary_explode` - 二次爆炸
9. `thorns_wall` - 反伤墙
10. `debuff_duration` - Debuff延长
11. `curse_stack` - 诅咒叠加

### P3 - 高级功能
12-16. 其他高级机制

### P4 - 战术功能
17-21. 战术相关机制

## 📝 常见问题

### Q: 如何测试羁绊激活？
A: 在选择界面选择对应角色组合，进入游戏后查看左下角羁绊图标。

### Q: 百分比属性如何计算？
A: 百分比属性是乘法加成，例如 +30% 表示最终值 = 基础值 × 1.3

### Q: 机制效果如何实现？
A: 参考 `BOND_MECHANIC_IMPLEMENTATION_GUIDE.md` 中的详细实现方案。

### Q: 如何调试羁绊系统？
A: 使用 `BondManager.print_active_bonds()` 打印当前激活的羁绊。

### Q: 旧存档会有问题吗？
A: 旧存档可能包含废弃的羁绊ID，建议清除或添加兼容性处理。

## 🔗 相关文档

- `BOND_CONFIG_REFACTOR.md` - 详细设计文档
- `BOND_MECHANIC_IMPLEMENTATION_GUIDE.md` - 机制实现指南
- `BOND_SYSTEM_UPDATE_SUMMARY.md` - 更新总结
- `BOND_SYSTEM_CHECKLIST.md` - 实现检查清单

## 📞 技术支持

如有问题，请查阅以上文档或联系开发团队。

---

**版本**: 1.0  
**更新日期**: 2026-01-31  
**适用于**: 羁绊系统重构后
