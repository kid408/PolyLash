# 武器配置清理指南

## 📋 概述

本文档说明如何清理武器系统重构后的废弃文件和代码。

**清理日期**: 2026-02-08  
**清理原因**: 武器系统已从 `.tres` 资源文件迁移到 CSV 配置，旧的 `weapon_stats_config.csv` 已被合并到 `weapon_config.csv`

---

## 🗑️ 可以安全删除的文件

### 1. 空文件（3个）

这些文件是开发过程中的临时文件，现在已经没有用了：

```
config/weapon/additions_melee_1.csv
config/weapon/weapon_additions_part1.txt
config/weapon/weapon_config_expanded.csv
```

**删除命令**:
```bash
cd config/weapon
del additions_melee_1.csv
del weapon_additions_part1.txt
del weapon_config_expanded.csv
```

### 2. 废弃的配置文件（1个）

`weapon_stats_config.csv` 是旧的武器配置文件，所有数据已合并到 `weapon_config.csv`：

```
config/weapon/weapon_stats_config.csv
```

**删除命令**:
```bash
cd config/weapon
del weapon_stats_config.csv
```

---

## ✅ 已完成的代码清理

### 1. config_manager.gd

已删除以下内容：

#### 常量定义
```gdscript
# ❌ 已删除
const WEAPON_STATS_CONFIG = CONFIG_DIR + "weapon/weapon_stats_config.csv"
```

#### 变量声明
```gdscript
# ❌ 已删除
var weapon_stats_configs: Dictionary = {}  # 武器详细属性配置
```

#### 加载代码
```gdscript
# ❌ 已删除
weapon_stats_configs = load_csv_as_dict(WEAPON_STATS_CONFIG, "weapon_id")
```

#### 访问函数
```gdscript
# ❌ 已删除
func get_weapon_stats(weapon_id: String) -> Dictionary:
    return weapon_stats_configs.get(weapon_id, {})

func get_all_weapon_stats() -> Dictionary:
    return weapon_stats_configs
```

---

## ⚠️ 需要手动修改的代码

以下文件仍在使用 `ConfigManager.get_weapon_stats()`，需要手动修改：

### 1. player_base.gd

**位置**: 第 219 行  
**函数**: `_create_item_weapon_from_csv()`

**当前代码**:
```gdscript
func _create_item_weapon_from_csv(weapon_id: String) -> ItemWeapon:
    var weapon_stats_data = ConfigManager.get_weapon_stats(weapon_id)
    if weapon_stats_data.is_empty():
        return null
    
    # 手动创建 WeaponStats 对象（50+ 行代码）
    var weapon_stats = WeaponStats.new()
    weapon_stats.damage = weapon_stats_data.get("damage", 10.0)
    # ... 更多属性赋值 ...
```

**建议修改**:
```gdscript
func _create_item_weapon_from_csv(weapon_id: String) -> ItemWeapon:
    # 直接使用 ItemWeapon.create_from_csv()
    return ItemWeapon.create_from_csv(weapon_id)
```

**说明**: 
- `ItemWeapon.create_from_csv()` 内部已经调用 `WeaponConfigLoader.get_weapon_stats()`
- 不需要手动创建 WeaponStats 对象
- 可以删除整个 `_create_item_weapon_from_csv()` 函数，直接调用 `ItemWeapon.create_from_csv()`

---

### 2. character_upgrade.gd

**位置**: 第 501 行  
**函数**: 未知（需要查看上下文）

**当前代码**:
```gdscript
var weapon_id = weapon_type + "_1"
var weapon_stats = ConfigManager.get_weapon_stats(weapon_id)
if weapon_stats.is_empty():
    return null
```

**建议修改**:
```gdscript
var weapon_id = weapon_type + "_1"
var weapon_info = WeaponConfigLoader.get_weapon_info(weapon_id)
if weapon_info.is_empty():
    return null
```

**说明**: 
- 如果只需要基础信息（名称、图标等），使用 `get_weapon_info()`
- 如果需要完整的 WeaponStats，使用 `WeaponConfigLoader.get_weapon_stats()`（返回对象而非字典）

---

### 3. selection_panel.gd

**位置**: 第 673 行  
**函数**: 未知（需要查看上下文）

**当前代码**:
```gdscript
var weapon_id = "%s_1" % weapon_type
var weapon_stats = ConfigManager.get_weapon_stats(weapon_id)
```

**建议修改**:
```gdscript
var weapon_id = "%s_1" % weapon_type
var weapon_info = WeaponConfigLoader.get_weapon_info(weapon_id)
```

**说明**: 
- 选择面板通常只需要显示信息（名称、图标），使用 `get_weapon_info()` 即可
- 不需要完整的 WeaponStats 对象

---

## 🔄 新旧系统对比

### 旧系统（已废弃）

```gdscript
# 1. 从 ConfigManager 获取字典
var weapon_stats_data = ConfigManager.get_weapon_stats(weapon_id)

# 2. 手动创建 WeaponStats 对象
var weapon_stats = WeaponStats.new()
weapon_stats.damage = weapon_stats_data.get("damage", 10.0)
weapon_stats.cooldown = weapon_stats_data.get("cooldown", 1.0)
# ... 50+ 行属性赋值 ...

# 3. 手动创建 ItemWeapon 对象
var item_weapon = ItemWeapon.new()
item_weapon.stats = weapon_stats
# ... 更多属性赋值 ...
```

### 新系统（推荐）

```gdscript
# 一行代码搞定！
var item_weapon = ItemWeapon.create_from_csv(weapon_id)
```

**优势**:
- ✅ 代码简洁（1 行 vs 50+ 行）
- ✅ 自动缓存（性能更好）
- ✅ 统一管理（所有武器加载逻辑在一处）
- ✅ 类型安全（返回 WeaponStats 对象而非 Dictionary）

---

## 📝 修改步骤

### 步骤 1: 删除废弃文件

```bash
cd config/weapon
del additions_melee_1.csv
del weapon_additions_part1.txt
del weapon_config_expanded.csv
del weapon_stats_config.csv
```

### 步骤 2: 修改 player_base.gd

**简化 `_load_weapons_from_config()` 函数**:

```gdscript
func _load_weapons_from_config() -> void:
    if player_id.is_empty() or not weapon_container:
        return
    
    # 检查是否有从选择界面传入的武器类型
    var selected_weapon_type = ""
    if Global.selected_player_weapons.has(player_id):
        selected_weapon_type = Global.selected_player_weapons[player_id]
    
    # 如果有选择的武器类型，只加载1级武器
    if selected_weapon_type != "":
        var weapon_id = "%s_1" % selected_weapon_type
        # ✅ 直接使用 ItemWeapon.create_from_csv()
        var item_weapon = ItemWeapon.create_from_csv(weapon_id)
        if item_weapon:
            _add_weapon(item_weapon)
        return
```

**删除 `_create_item_weapon_from_csv()` 函数**（整个函数可以删除）

### 步骤 3: 修改 character_upgrade.gd

找到使用 `ConfigManager.get_weapon_stats()` 的地方，改为：

```gdscript
# 如果只需要基础信息
var weapon_info = WeaponConfigLoader.get_weapon_info(weapon_id)

# 如果需要完整 Stats
var weapon_stats = WeaponConfigLoader.get_weapon_stats(weapon_id)
```

### 步骤 4: 修改 selection_panel.gd

同上，根据需要选择 `get_weapon_info()` 或 `get_weapon_stats()`

### 步骤 5: 验证修改

```bash
# 运行游戏，测试武器加载
# 检查控制台是否有错误
# 测试武器切换、升级等功能
```

---

## 🎯 API 参考

### WeaponConfigLoader（新系统）

```gdscript
# 获取完整的 WeaponStats 对象（带缓存）
var stats: WeaponStats = WeaponConfigLoader.get_weapon_stats(weapon_id)

# 获取基础信息（不创建完整对象）
var info: Dictionary = WeaponConfigLoader.get_weapon_info(weapon_id)
# 返回: {weapon_id, display_name, type, level, icon_path, upgrade_to, item_cost}

# 获取所有武器 ID
var ids: Array = WeaponConfigLoader.get_all_weapon_ids()

# 清除缓存（用于热重载）
WeaponConfigLoader.clear_cache()
```

### ItemWeapon（新系统）

```gdscript
# 从 CSV 创建武器（推荐）
var weapon: ItemWeapon = ItemWeapon.create_from_csv(weapon_id)

# 访问属性
print(weapon.weapon_id)      # String
print(weapon.item_name)      # String
print(weapon.type)           # WeaponType.MELEE 或 RANGE
print(weapon.level)          # int
print(weapon.stats)          # WeaponStats 对象
print(weapon.scene)          # PackedScene
print(weapon.icon_path)      # String
print(weapon.upgrade_to)     # String
```

---

## ✅ 验证清单

完成修改后，请检查以下项目：

- [ ] 删除了 4 个废弃文件
- [ ] `config_manager.gd` 中没有 `weapon_stats_config` 相关代码
- [ ] `player_base.gd` 使用 `ItemWeapon.create_from_csv()`
- [ ] `character_upgrade.gd` 使用 `WeaponConfigLoader` API
- [ ] `selection_panel.gd` 使用 `WeaponConfigLoader` API
- [ ] 游戏运行正常，武器加载无错误
- [ ] 武器切换、升级功能正常
- [ ] 控制台无警告或错误

---

## 📚 相关文档

- `docs/WEAPON_SYSTEM_REFACTORING_GUIDE.md` - 武器系统使用指南
- `docs/BUG_FIX_REPORT.md` - 错误修复报告
- `docs/RUNTIME_ERROR_FIX_SUMMARY.md` - 运行时错误修复
- `.kiro/specs/weapon-system-refactoring/design.md` - 系统设计文档

---

**文档版本**: 1.0  
**创建日期**: 2026-02-08  
**状态**: ✅ config_manager.gd 已清理，待手动修改其他文件
