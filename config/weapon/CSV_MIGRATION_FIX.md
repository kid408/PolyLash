# CSV 优化迁移 - 错误修复报告

## 修复日期
2026-02-08

## 问题描述

在将武器配置从 `weapon_config.csv` (121行) 迁移到 `weapon_config_optimized.csv` (30行) 后，出现运行时错误：

```
Invalid call. Nonexistent function 'get_weapon_stats' in base 'Node (config_manager.gd)'
```

## 根本原因

代码中有多处错误地调用了 `ConfigManager.get_weapon_stats()`，但这个函数实际上在 `WeaponConfigLoader` 中，不在 `ConfigManager` 中。

### API 差异

| 类 | 方法 | 返回类型 | 用途 |
|---|---|---|---|
| `WeaponConfigLoader` | `get_weapon_stats(weapon_id)` | `WeaponStats` 对象 | 获取完整的武器统计数据对象 |
| `WeaponConfigLoader` | `get_weapon_info(weapon_id)` | `Dictionary` | 获取武器基础信息（名称、图标等） |
| `ConfigManager` | `get_weapon_config(weapon_id)` | `Dictionary` | 获取旧格式的武器配置字典 |

## 修复的文件

### 1. `scenes/unit/players/player_base.gd`

**问题**：第219行调用 `ConfigManager.get_weapon_stats()`

**修复前**：
```gdscript
func _create_item_weapon_from_csv(weapon_id: String) -> ItemWeapon:
    var weapon_stats_data = ConfigManager.get_weapon_stats(weapon_id)
    if weapon_stats_data.is_empty():
        return null
    
    # 手动创建 WeaponStats 对象...
    var weapon_stats = WeaponStats.new()
    weapon_stats.damage = weapon_stats_data.get("damage", 10.0)
    # ... 50+ 行手动赋值代码
```

**修复后**：
```gdscript
func _create_item_weapon_from_csv(weapon_id: String) -> ItemWeapon:
    # 使用 ItemWeapon 的静态方法创建武器
    return ItemWeapon.create_from_csv(weapon_id)
```

**优化效果**：
- ✅ 代码从 50+ 行减少到 3 行
- ✅ 使用标准 API，避免重复代码
- ✅ 自动支持等级倍率系统

### 2. `scenes/ui/selection_panel/selection_panel.gd`

**问题**：第673行调用 `ConfigManager.get_weapon_stats()`

**修复前**：
```gdscript
var weapon_id = "%s_1" % weapon_type
var weapon_stats = ConfigManager.get_weapon_stats(weapon_id)
# ...
var icon_path = weapon_stats.get("icon_path", "")
```

**修复后**：
```gdscript
var weapon_id = "%s_1" % weapon_type
var weapon_info = WeaponConfigLoader.get_weapon_info(weapon_id)
# ...
var icon_path = weapon_info.get("icon_path", "")
```

### 3. `scenes/ui/selection_panel/character_upgrade.gd`

**问题**：第501行调用 `ConfigManager.get_weapon_stats()`

**修复前**：
```gdscript
var weapon_id = weapon_type + "_1"
var weapon_stats = ConfigManager.get_weapon_stats(weapon_id)
if weapon_stats.is_empty():
    return null
# ...
weapon_name.text = weapon_stats.get("display_name", weapon_type)
var icon_path = weapon_stats.get("icon_path", "")
```

**修复后**：
```gdscript
var weapon_id = weapon_type + "_1"
var weapon_info = WeaponConfigLoader.get_weapon_info(weapon_id)
if weapon_info.is_empty():
    return null
# ...
weapon_name.text = weapon_info.get("display_name", weapon_type)
var icon_path = weapon_info.get("icon_path", "")
```

## 正确的 API 使用指南

### 场景 1：创建武器实例
```gdscript
# ✅ 正确
var weapon = ItemWeapon.create_from_csv("punch_1")

# ❌ 错误
var stats = ConfigManager.get_weapon_stats("punch_1")
```

### 场景 2：获取武器统计数据
```gdscript
# ✅ 正确
var stats = WeaponConfigLoader.get_weapon_stats("punch_1")  # 返回 WeaponStats 对象

# ❌ 错误
var stats = ConfigManager.get_weapon_stats("punch_1")  # 函数不存在
```

### 场景 3：获取武器显示信息（名称、图标等）
```gdscript
# ✅ 正确
var info = WeaponConfigLoader.get_weapon_info("punch_1")
var name = info.get("display_name", "")
var icon = info.get("icon_path", "")

# ❌ 错误
var stats = ConfigManager.get_weapon_stats("punch_1")
```

### 场景 4：获取旧格式配置（不推荐）
```gdscript
# ⚠️ 仅用于兼容旧代码
var config = ConfigManager.get_weapon_config("punch_1")
# 注意：这会返回空字典，因为新 CSV 使用 weapon_base_id 而不是 weapon_id
```

## 验证步骤

1. 启动游戏
2. 选择角色
3. 检查控制台输出：
   ```
   [WeaponConfigLoader] 加载完成: 30 个武器基础配置
   [WeaponConfigLoader] 创建武器 Stats: punch_1 (punch Lv.1)
   ```
4. 验证武器正常加载和显示

## 相关文件

- `autoloads/weapon_config_loader.gd` - 新的武器配置加载器
- `autoloads/item_weapon.gd` - 武器物品类（包含 `create_from_csv` 方法）
- `config/weapon/weapon_config_optimized.csv` - 优化后的 CSV（30行）
- `config/weapon/MIGRATION_COMPLETE.md` - 迁移完成文档

## 总结

✅ **修复完成**：所有错误的 `ConfigManager.get_weapon_stats()` 调用已修复
✅ **代码优化**：移除了重复的手动创建代码
✅ **API 统一**：统一使用 `WeaponConfigLoader` 和 `ItemWeapon` API
✅ **向后兼容**：保留了 `ConfigManager.get_weapon_config()` 用于旧代码

现在系统应该可以正常运行了！
