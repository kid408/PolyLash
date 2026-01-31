# 羁绊系统迁移指南 - Bond System Migration Guide

## 📋 概述

本文档帮助开发者将代码从旧羁绊系统迁移到新羁绊系统。

## ⚠️ 重大变更

### 1. 羁绊ID完全更换

**旧羁绊ID（已废弃）**:
- martial, arcane, survivor, noble, shadow, nature, tech
- destruction, velocity, control, defense, support, summon, stealth
- assault, captain, defense_tactic, guerrilla, siege, ambush

**新羁绊ID**:
- **身世**: inkborn, colossus, nomad, alchemist
- **职能**: blaster, architect, hexer, geometrist
- **战术**: assist, vanguard, commander

### 2. 属性系统变更

**新增百分比属性**:
- `energy_regen_pct` - 能量回复速度百分比
- `max_health_pct` - 生命上限百分比
- `movement_speed_pct` - 移动速度百分比
- `pickup_range_pct` - 拾取范围百分比

**计算方式变更**:
```gdscript
# 旧方式（加法）
stats["max_health"] = base_health + bonus

# 新方式（百分比 - 乘法）
stats["max_health"] = base_health * (1.0 + bonus_pct)
```

### 3. 机制效果系统

**新增21个机制效果**，需要在代码中实现：
- 画图相关: closed_shape_dmg, line_duration, shape_tolerance 等
- 战斗相关: super_armor, speed_to_damage, kill_regen 等
- 战术相关: bench_cd_reduce, mirror_draw, switch_cd_reduce 等

## 🔄 代码迁移步骤

### Step 1: 更新羁绊检查代码

#### 旧代码
```gdscript
# 检查旧羁绊
if BondManager.is_bond_active("martial"):
    damage *= 1.2
```

#### 新代码
```gdscript
# 检查新羁绊机制
if BondManager.has_mechanic("closed_shape_dmg"):
    var bonus = BondManager.get_mechanic_value("closed_shape_dmg")
    damage *= (1.0 + bonus)
```

### Step 2: 更新属性应用代码

#### 旧代码
```gdscript
# 直接修改属性
player.max_health += 50
```

#### 新代码
```gdscript
# 通过 BondManager 应用属性加成
var stats = {
    "max_health": player.base_max_health,
    "energy_regen": player.base_energy_regen,
    "speed": player.base_speed
}
stats = BondManager.apply_stat_modifiers(stats)
player.max_health = stats["max_health"]
player.energy_regen = stats["energy_regen"]
player.speed = stats["speed"]
```

### Step 3: 移除旧羁绊引用

#### 需要搜索和替换的代码
```gdscript
# 搜索这些旧羁绊ID
"martial"
"arcane"
"survivor"
"noble"
"shadow"
"nature"
"tech"
"destruction"
"velocity"
"control"
"defense"
"support"
"summon"
"stealth"
"assault"
"captain"
"defense_tactic"
"guerrilla"
"siege"
"ambush"
```

#### 替换为新羁绊ID或机制检查
```gdscript
# 根据功能选择对应的新羁绊
# 例如：martial (武道) -> blaster (爆破师)
# 例如：velocity (极速) -> nomad (风行者)
```

### Step 4: 实现机制效果

#### 画图技能中添加机制检查
```gdscript
# 在 skill_drawing_base.gd 中
func calculate_damage(base_damage: float) -> float:
    var damage = base_damage
    
    # 检查闭合图形伤害加成
    if BondManager.has_mechanic("closed_shape_dmg"):
        var bonus = BondManager.get_mechanic_value("closed_shape_dmg")
        damage *= (1.0 + bonus)
    
    # 检查小图形暴击
    if BondManager.has_mechanic("small_shape_crit"):
        if is_small_shape():
            damage *= 2.0  # 暴击
    
    return damage
```

#### 玩家基类中添加机制检查
```gdscript
# 在 player_base.gd 中
func _on_enemy_killed(enemy: Node2D) -> void:
    # 检查击杀回能
    if BondManager.has_mechanic("kill_regen"):
        var regen = BondManager.get_mechanic_value("kill_regen")
        current_energy = min(current_energy + regen, max_energy)
```

## 📝 迁移检查清单

### 配置文件
- [x] `config/player/bond_config.csv` - 已更新
- [x] `config/player/player_config.csv` - 已更新

### 代码文件
- [x] `autoloads/bond_manager.gd` - 已更新
- [ ] `scenes/skills/skill_drawing_base.gd` - 需要添加机制检查
- [ ] `scenes/unit/players/player_base.gd` - 需要添加机制检查
- [ ] 其他使用旧羁绊ID的文件

### UI文件
- [ ] 检查是否有硬编码的羁绊ID
- [ ] 更新羁绊图标路径（如需要）
- [ ] 更新 Tooltip 显示逻辑

### 测试文件
- [ ] 更新测试用例中的羁绊ID
- [ ] 添加新机制的测试用例

## 🔍 查找旧代码的方法

### 使用 grep 搜索
```bash
# 搜索旧羁绊ID
grep -r "martial" scenes/
grep -r "arcane" scenes/
grep -r "survivor" scenes/
# ... 其他旧羁绊ID
```

### 使用 Godot 编辑器搜索
1. 打开 Godot 编辑器
2. 使用 Ctrl+Shift+F 打开全局搜索
3. 搜索旧羁绊ID
4. 逐个替换或更新

## ⚙️ 兼容性处理

### 处理旧存档

#### 方案1: 清除旧存档（推荐）
```gdscript
# 在游戏启动时检查
func _ready():
    if has_old_bond_data():
        show_migration_dialog()
        clear_old_save_data()
```

#### 方案2: 迁移旧存档
```gdscript
# 映射旧羁绊到新羁绊
var bond_migration_map = {
    "martial": "blaster",
    "velocity": "nomad",
    "arcane": "inkborn",
    # ... 其他映射
}

func migrate_old_bonds(old_bonds: Array) -> Array:
    var new_bonds = []
    for old_bond in old_bonds:
        if bond_migration_map.has(old_bond):
            new_bonds.append(bond_migration_map[old_bond])
    return new_bonds
```

### 处理未知羁绊ID

```gdscript
# 在 BondManager 中添加错误处理
func get_bond_config(bond_id: String) -> Dictionary:
    if not bond_configs.has(bond_id):
        printerr("[BondManager] 未知的羁绊ID: %s" % bond_id)
        return {}
    return bond_configs[bond_id]
```

## 🧪 测试建议

### 1. 单元测试
```gdscript
# 测试羁绊激活
func test_bond_activation():
    var team = ["butcher", "pyro", "sapper"]
    BondManager.recalculate_active_bonds(team)
    
    # 验证爆破师 Lv.3 激活
    assert(BondManager.get_active_bond_level("blaster") == 3)
    
    # 验证机制激活
    assert(BondManager.has_mechanic("closed_shape_dmg"))
```

### 2. 集成测试
```gdscript
# 测试属性应用
func test_stat_modifiers():
    var base_stats = {
        "max_health": 100,
        "energy_regen": 0.5
    }
    
    var modified_stats = BondManager.apply_stat_modifiers(base_stats)
    
    # 验证百分比加成
    assert(modified_stats["max_health"] > base_stats["max_health"])
```

### 3. 回归测试
- 测试所有角色组合
- 验证羁绊激活逻辑
- 检查UI显示
- 测试存档加载

## 📚 参考文档

### 必读文档
1. `BOND_CONFIG_REFACTOR.md` - 了解新羁绊设计
2. `BOND_MECHANIC_IMPLEMENTATION_GUIDE.md` - 实现机制效果
3. `BOND_QUICK_REFERENCE.md` - 快速查询羁绊信息

### 代码示例
- `autoloads/bond_manager.gd` - 羁绊管理器实现
- `BOND_MECHANIC_IMPLEMENTATION_GUIDE.md` - 机制实现示例

## ⚠️ 常见问题

### Q: 旧羁绊ID还能用吗？
A: 不能。所有旧羁绊ID已被移除，必须更新为新羁绊ID或机制检查。

### Q: 如何处理玩家的旧存档？
A: 建议清除旧存档或实现迁移逻辑。参考"兼容性处理"章节。

### Q: 百分比属性和固定值属性有什么区别？
A: 百分比属性使用乘法（`base * (1 + bonus)`），固定值使用加法（`base + bonus`）。

### Q: 机制效果必须全部实现吗？
A: 不是。可以按优先级逐步实现。参考 `BOND_SYSTEM_CHECKLIST.md`。

### Q: 如何测试新羁绊系统？
A: 创建测试场景，选择特定角色组合，验证羁绊激活和效果。

## 🚀 迁移时间表

### 阶段1: 准备（已完成）
- [x] 更新配置文件
- [x] 更新 BondManager
- [x] 创建文档

### 阶段2: 代码迁移（进行中）
- [ ] 搜索旧羁绊ID
- [ ] 更新羁绊检查代码
- [ ] 移除旧代码引用

### 阶段3: 机制实现（待开始）
- [ ] 实现P0机制
- [ ] 实现P1机制
- [ ] 实现P2-P4机制

### 阶段4: 测试验证（待开始）
- [ ] 单元测试
- [ ] 集成测试
- [ ] 回归测试

### 阶段5: 发布（待开始）
- [ ] 兼容性处理
- [ ] 文档更新
- [ ] 正式发布

## 📞 获取帮助

如果在迁移过程中遇到问题：
1. 查阅相关文档
2. 检查代码示例
3. 运行测试用例
4. 联系开发团队

---

**版本**: 1.0  
**创建日期**: 2026-01-31  
**适用于**: 从旧羁绊系统迁移到新羁绊系统
