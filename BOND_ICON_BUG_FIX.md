# 羁绊图标显示错误修复报告

## 问题日期
2026-01-24

## 问题描述

### 症状
不同角色的羁绊图标显示完全一致，没有正确反映角色的差异。

**具体表现**:
- 屠夫 (butcher, Origin: martial) 和火焰 (pyro, Origin: arcane) 的第一个羁绊图标完全相同
- 所有角色的同类型羁绊（如 origin）都显示相同的图标
- 图标没有根据角色的实际羁绊标签（tag）变化

### 预期行为
- butcher (martial) 应该显示 `origin1.png`（武道世家图标）
- pyro (arcane) 应该显示 `origin2.png`（秘术行者图标）
- 每个角色的羁绊图标应该根据其 `origin_tag`, `mastery_tag`, `tactic_tag` 显示不同的图标

---

## 根本原因分析

### 诊断过程

#### 1. 检查数据文件 ✅
**文件**: `config/player/bond_config.csv`

**检查结果**: 数据正确
```csv
martial,origin,...,1,...  (icon_path_index = 1)
arcane,origin,...,2,...   (icon_path_index = 2)
survivor,origin,...,3,... (icon_path_index = 3)
```

**文件**: `config/player/player_config.csv`

**检查结果**: 数据正确
```csv
butcher,...,martial,destruction,assault
pyro,...,arcane,destruction,assault
```

#### 2. 检查代码逻辑 ❌
**文件**: `autoloads/bond_ui_loader.gd`

**发现问题**: CSV 列索引错误！

### 问题根源

**CSV 文件结构**（新版本）:
```csv
bond_id, type, level, required_count, effect_type, effect_param, effect_value, icon_path_index, display_name, description
  [0]    [1]    [2]        [3]            [4]           [5]           [6]            [7]            [8]          [9]
```

**代码使用的索引**（旧版本）:
```gdscript
var bond_id = line[0]          // ✓ 正确
var bond_type = line[1]        // ✓ 正确
var icon_path_index = int(line[2])  // ✗ 错误！读取的是 level
var display_name = line[3]     // ✗ 错误！读取的是 required_count
var description = line[4]      // ✗ 错误！读取的是 effect_type
```

**实际读取的数据**:
```gdscript
// 对于 martial 的第一行数据：
// martial,origin,1,2,stat_mod,crit_chance,10,1,武道世家,全队暴击率+10%

bond_id = "martial"           // ✓ 正确
bond_type = "origin"          // ✓ 正确
icon_path_index = 1           // ✗ 错误！这是 level，不是 icon_path_index
display_name = "2"            // ✗ 错误！这是 required_count
description = "stat_mod"      // ✗ 错误！这是 effect_type
```

**结果**:
- 所有 origin 类型的羁绊都读取到 `icon_path_index = 1`（因为它们的第一个等级都是 level=1）
- 所有 mastery 类型的羁绊都读取到 `icon_path_index = 1`
- 所有 tactic 类型的羁绊都读取到 `icon_path_index = 1`
- 因此所有羁绊都显示相同的图标！

---

## 修复方案

### 修改文件
**文件**: `autoloads/bond_ui_loader.gd`

### 修改内容

**修改前**:
```gdscript
func _load_bond_configs() -> void:
    # ...
    while not file.eof_reached():
        var line = file.get_csv_line()
        if line.size() < 5:
            continue
        
        var bond_id = line[0]
        var bond_type = line[1]
        var icon_path_index = int(line[2])  // ✗ 错误的列索引
        var display_name = line[3]          // ✗ 错误的列索引
        var description = line[4]           // ✗ 错误的列索引
        
        # ...
```

**修改后**:
```gdscript
func _load_bond_configs() -> void:
    # ...
    while not file.eof_reached():
        var line = file.get_csv_line()
        if line.size() < 10:  // 更新：需要至少10列
            continue
        
        # CSV 列顺序: bond_id, type, level, required_count, effect_type, effect_param, effect_value, icon_path_index, display_name, description
        var bond_id = line[0]
        var bond_type = line[1]
        var icon_path_index = int(line[7])  // ✓ 修复：使用正确的列索引
        var display_name = line[8]          // ✓ 修复：使用正确的列索引
        var description = line[9]           // ✓ 修复：使用正确的列索引
        
        # 只在第一次遇到该 bond_id 时创建配置（避免重复）
        if not bond_configs.has(bond_id):
            bond_configs[bond_id] = {
                "bond_type": bond_type,
                "icon_path_index": icon_path_index,
                "display_name": display_name,
                "description": description
            }
```

### 关键改进

1. **正确的列索引**:
   - `icon_path_index`: `line[2]` → `line[7]`
   - `display_name`: `line[3]` → `line[8]`
   - `description`: `line[4]` → `line[9]`

2. **列数检查**:
   - `line.size() < 5` → `line.size() < 10`
   - 确保有足够的列数据

3. **避免重复**:
   - 添加 `if not bond_configs.has(bond_id)` 检查
   - 因为 CSV 中每个羁绊有多行（每个等级一行）
   - 只需要读取一次图标信息（所有等级共享同一个图标）

---

## 验证结果

### 修复后的数据读取

**martial (origin)**:
```gdscript
bond_id = "martial"
bond_type = "origin"
icon_path_index = 1  // ✓ 正确！从 line[7] 读取
display_name = "武道世家"  // ✓ 正确！从 line[8] 读取
description = "全队暴击率+10%"  // ✓ 正确！从 line[9] 读取
```

**arcane (origin)**:
```gdscript
bond_id = "arcane"
bond_type = "origin"
icon_path_index = 2  // ✓ 正确！从 line[7] 读取
display_name = "秘术行者"  // ✓ 正确！从 line[8] 读取
description = "全队能量回复+0.5/s"  // ✓ 正确！从 line[9] 读取
```

### 图标路径生成

**martial**:
```gdscript
icon_path_template = "res://assets/sprites/Icons/origins/origin%d.png"
icon_path = icon_path_template % 1
// 结果: "res://assets/sprites/Icons/origins/origin1.png" ✓
```

**arcane**:
```gdscript
icon_path_template = "res://assets/sprites/Icons/origins/origin%d.png"
icon_path = icon_path_template % 2
// 结果: "res://assets/sprites/Icons/origins/origin2.png" ✓
```

---

## 测试建议

### 测试场景 1: 不同角色的 Origin 图标
1. 启动游戏，进入角色选择界面
2. 点击 butcher（武道世家）
3. 查看右侧羁绊图标的第一个（origin）
4. **验证**: 显示武道世家图标（剑或武器相关）
5. 点击 pyro（秘术行者）
6. 查看右侧羁绊图标的第一个（origin）
7. **验证**: 显示秘术行者图标（魔法或神秘符号）
8. **验证**: 两个图标应该明显不同

### 测试场景 2: 不同角色的 Mastery 图标
1. 点击 butcher（毁灭打击）
2. 查看第二个羁绊图标（mastery）
3. **验证**: 显示毁灭打击图标
4. 点击 wind（极速）
5. 查看第二个羁绊图标（mastery）
6. **验证**: 显示极速图标
7. **验证**: 两个图标应该明显不同

### 测试场景 3: 不同角色的 Tactic 图标
1. 点击 butcher（突击战术）
2. 查看第三个羁绊图标（tactic）
3. **验证**: 显示突击战术图标
4. 点击 wind（指挥官）
5. 查看第三个羁绊图标（tactic）
6. **验证**: 显示指挥官图标
7. **验证**: 两个图标应该明显不同

### 测试场景 4: 左侧羁绊列表
1. 选择 butcher + pyro
2. 查看左侧羁绊列表
3. **验证**: 
   - 武道世家显示正确的图标
   - 秘术行者显示正确的图标
   - 毁灭打击显示正确的图标
   - 突击战术显示正确的图标

### 测试场景 5: Tooltip 验证
1. 鼠标悬停在各个羁绊图标上
2. **验证**: 
   - Tooltip 显示正确的羁绊名称
   - 名称与图标匹配
   - 不再显示数字或错误的名称

---

## 代码质量保证

### 语法检查
✅ `autoloads/bond_ui_loader.gd` - 无错误

### 逻辑验证
✅ 列索引正确对应 CSV 结构
✅ 避免重复读取（每个 bond_id 只创建一次）
✅ 列数检查更新（10列）

### 容错处理
✅ 检查列数是否足够（`line.size() < 10`）
✅ 检查 bond_id 是否为空或 "-1"
✅ 使用 `has()` 检查避免重复

---

## 问题总结

### 问题类型
**数据解析错误** - CSV 列索引不匹配

### 严重程度
🔴 **高** - 导致核心功能（羁绊图标显示）完全失效

### 影响范围
- 角色选择界面的右侧羁绊图标
- 角色强化界面的羁绊图标
- 左侧羁绊列表的图标
- 所有显示羁绊图标的地方

### 根本原因
CSV 文件结构更新后，代码没有同步更新列索引

### 预防措施
1. **使用常量定义列索引**:
   ```gdscript
   const COL_BOND_ID = 0
   const COL_TYPE = 1
   const COL_ICON_INDEX = 7
   const COL_DISPLAY_NAME = 8
   const COL_DESCRIPTION = 9
   ```

2. **添加数据验证**:
   ```gdscript
   if icon_path_index < 1 or icon_path_index > 7:
       printerr("[BondUILoader] 无效的图标索引: %d for %s" % [icon_path_index, bond_id])
   ```

3. **添加单元测试**:
   - 验证每个羁绊的 icon_path_index 是否唯一
   - 验证图标文件是否存在

---

## 相关文件清单

### 修改文件
- `autoloads/bond_ui_loader.gd`
  - 修复 `_load_bond_configs()` 函数的列索引

### 数据文件（无需修改）
- `config/player/bond_config.csv` - 数据正确
- `config/player/player_config.csv` - 数据正确

### 图标资源（无需修改）
- `assets/sprites/Icons/origins/origin1.png` ~ `origin7.png`
- `assets/sprites/Icons/masterys/mastery1.png` ~ `mastery7.png`
- `assets/sprites/Icons/tactics/tactic1.png` ~ `tactic7.png`

---

## 完成状态

✅ **问题已修复** - 列索引已更正
✅ **语法检查通过** - 无错误
✅ **逻辑验证完成** - 数据读取正确

**状态**: 可以测试

**优先级**: 🔴 高优先级 Bug 修复

---

## 经验教训

### 1. CSV 结构变更需要同步更新代码
当 CSV 文件的列顺序或数量发生变化时，所有读取该文件的代码都需要更新。

### 2. 使用常量定义列索引
硬编码的数字索引容易出错，应该使用有意义的常量名。

### 3. 添加数据验证
在读取数据后，应该验证数据的合理性（如索引范围、必填字段等）。

### 4. 单元测试的重要性
如果有单元测试验证数据加载，这个问题会在开发阶段就被发现。

### 5. 版本控制和代码审查
CSV 结构变更应该作为重要的变更，需要仔细审查相关代码。
