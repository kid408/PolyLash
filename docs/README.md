# PolyLash 游戏系统文档

欢迎阅读 PolyLash 游戏系统文档！本文档集详细介绍了游戏的所有核心系统和机制。

---

## 快速导航

### 📚 核心文档
- **[00_系统大纲](00_系统大纲.md)** - 系统总览和索引
- **[05_羁绊系统](05_羁绊系统.md)** - 核心数值系统
- **[06_武器系统](06_武器系统.md)** - 武器配置和等级系统
- **[10_商店系统](10_商店系统.md)** - 商店生成和购买逻辑
- **[13_技能系统](13_技能系统.md)** - Q键画线、E键瞬发、技能机制
- **[14_技能效果分类与重构指南](14_技能效果分类与重构指南.md)** - 技能效果分类与重构方案
- **[99_完整游戏流程](99_完整游戏流程.md)** - 从角色选择到结算的完整流程

---

## 文档结构

```
docs/
├── README.md                    # 本文件
├── 00_系统大纲.md               # 系统总览和索引
├── 01_配置管理系统.md           # ConfigManager
├── 02_全局状态管理系统.md       # Global
├── 03_数据持久化系统.md         # DataManager
├── 04_存档管理系统.md           # SaveManager
├── 05_羁绊系统.md               # BondManager ⭐
├── 06_武器系统.md               # WeaponConfigLoader ⭐
├── 07_装备系统.md               # EquipmentManager
├── 08_徽章系统.md               # EmblemManager
├── 09_修改器系统.md             # ModifierManager
├── 10_商店系统.md               # ShopManager ⭐
├── 11_升级系统.md               # UpgradeManager
├── 12_音效系统.md               # SoundManager
├── 13_技能系统.md               # SkillManager ⭐
├── 14_仓库系统.md               # WarehouseManager
├── 15_波次系统.md               # 波次管理
├── 16_角色系统.md               # 角色配置
├── 17_敌人系统.md               # 敌人配置
├── 18_道具系统.md               # 道具配置
├── 19_UI系统.md                 # 用户界面
├── 20_输入系统.md               # 输入管理
└── 99_完整游戏流程.md           # 完整游戏流程 ⭐
```

⭐ 标记的文档是核心系统，建议优先阅读。

---

## 阅读建议

### 新手入门
如果你是第一次接触这个项目，建议按以下顺序阅读：

1. **[99_完整游戏流程](99_完整游戏流程.md)** - 了解游戏玩法
2. **[00_系统大纲](00_系统大纲.md)** - 了解整体架构
3. **[13_技能系统](13_技能系统.md)** - 理解核心玩法（Q键画线）
4. **[05_羁绊系统](05_羁绊系统.md)** - 理解Build构建
5. **[06_武器系统](06_武器系统.md)** - 了解战斗机制
6. **[10_商店系统](10_商店系统.md)** - 理解物品获取

### 系统开发
如果你需要开发或修改特定系统：

1. 先阅读 **系统大纲** 了解系统间的关系
2. 阅读对应系统的详细文档
3. 查看相关系统的文档（参考"相关系统"章节）
4. 使用调试工具验证功能

### 配置修改
如果你只需要修改游戏配置：

1. 阅读 **[01_配置管理系统](01_配置管理系统.md)** 了解配置文件结构
2. 阅读对应系统的"配置示例"章节
3. 修改 CSV 文件
4. 重启游戏测试

---

## 核心概念

### 羁绊标签 (Bond Tag)
游戏的核心机制，通过收集羁绊标签激活羁绊效果。

**三源标签**:
- 角色自带标签（origin, mastery, tactic）
- 装备提供标签（bond_grant）
- 徽章提供标签（全局）

**详细说明**: [05_羁绊系统.md](05_羁绊系统.md)

### 修改器 (Modifier)
基于标签的数值修改系统，支持固定值和百分比加成。

**子集匹配**: 技能标签包含道具标签即生效

**详细说明**: [09_修改器系统.md](09_修改器系统.md)

### 武器等级系统
每个武器有基础值和等级倍率，减少配置维护成本。

**等级范围**: 1-4
**倍率类型**: 伤害、冷却、射程、穿透等

**详细说明**: [06_武器系统.md](06_武器系统.md)

### 局内数据 vs 持久化数据
- **局内数据**: 经验值、击杀数、徽章（每局重置）
- **持久化数据**: 金币、属性升级（跨局保留）

**详细说明**: [03_数据持久化系统.md](03_数据持久化系统.md)

---

## 配置文件位置

```
config/
├── system/          # 系统配置
│   ├── game_config.csv
│   ├── camera_config.csv
│   ├── map_config.csv
│   ├── input_config.csv
│   └── credits_config.csv
├── player/          # 玩家配置
│   ├── player_config.csv
│   ├── player_visual.csv
│   ├── player_weapons.csv
│   ├── player_skill_bindings.csv
│   ├── player_available_weapons.csv
│   ├── skill_params_wide.csv
│   ├── bond_config.csv
│   └── attribute_upgrade.csv
├── enemy/           # 敌人配置
│   ├── enemy_config.csv
│   ├── enemy_visual.csv
│   └── enemy_weapons.csv
├── weapon/          # 武器配置
│   └── weapon_config_optimized.csv
├── wave/            # 波次配置
│   ├── wave_config.csv
│   ├── wave_units_config.csv
│   └── wave_chest_config.csv
└── item/            # 道具配置
    ├── item_config.csv
    ├── emblem_config.csv
    ├── chest_config.csv
    ├── upgrade_attributes.csv
    └── shop_item_config.csv
```

---

## 系统交互图

```
ConfigManager (配置中心)
    ↓
    ├─→ Global (全局状态)
    │       ↓
    │       ├─→ BondManager (羁绊系统)
    │       │       ↓
    │       │       ├─→ EmblemManager (徽章)
    │       │       └─→ EquipmentManager (装备)
    │       │               ↓
    │       │               └─→ ModifierManager (修改器)
    │       │                       ↓
    │       │                       └─→ PlayerBase (角色)
    │       │
    │       └─→ ShopManager (商店)
    │               ↓
    │               ├─→ EmblemManager
    │               └─→ ModifierManager
    │
    └─→ DataManager (数据持久化)
            ↓
            └─→ SaveManager (存档管理)
```

---

## 开发工具

### 工具脚本
```
tools/
├── create_character_tool.gd      # 创建角色配置
├── create_enemy_tool.gd          # 创建敌人配置
├── create_weapon_scenes_tool.gd  # 创建武器场景
├── create_item_tool.gd           # 创建道具配置
├── create_bond_tool.gd           # 创建羁绊配置
├── assign_character_weapons.gd   # 分配角色武器
└── cleanup_csv_tool.gd           # 清理CSV文件
```

### 调试命令
```gdscript
# 打印羁绊状态
BondManager.print_active_bonds()

# 打印商店物品
ShopManager.print_shop_items()

# 打印修改器
ModifierManager.print_all_modifiers()

# 打印武器信息
WeaponConfigLoader.debug_weapon("punch_3")
```

---

## 常见任务

### 添加新角色
1. 在 `player_config.csv` 中添加角色配置
2. 在 `player_visual.csv` 中添加视觉配置
3. 在 `player_weapons.csv` 中配置武器
4. 在 `player_skill_bindings.csv` 中绑定技能
5. 创建角色贴图和动画
6. 重启游戏测试

**详细说明**: [16_角色系统.md](16_角色系统.md)

### 添加新武器
1. 在 `weapon_config_optimized.csv` 中添加一行
2. 设置基础属性和等级倍率
3. 创建武器场景和贴图
4. 重启游戏测试

**详细说明**: [06_武器系统.md](06_武器系统.md)

### 添加新羁绊
1. 在 `bond_config.csv` 中添加配置
2. 在角色配置中添加对应标签
3. 重启游戏测试

**详细说明**: [05_羁绊系统.md](05_羁绊系统.md)

### 添加新道具
1. 在 `item_config.csv` 或 `shop_item_config.csv` 中添加配置
2. 设置效果类型和数值
3. 创建道具图标
4. 重启游戏测试

**详细说明**: [18_道具系统.md](18_道具系统.md)

---

## 调试技巧

### 1. 使用调试打印
```gdscript
# 打印羁绊状态
BondManager.print_active_bonds()

# 打印标签来源
var sources = BondManager.get_tag_sources("inkborn")
print("标签来源: ", sources)
```

### 2. 监听信号
```gdscript
# 监听羁绊变化
BondManager.bond_level_changed.connect(func(bond_id, old_level, new_level):
    print("羁绊变化: %s Lv.%d -> Lv.%d" % [bond_id, old_level, new_level])
)
```

### 3. 检查配置加载
```gdscript
# 检查配置是否加载
var config = ConfigManager.get_player_config("player_herder")
if config.is_empty():
    print("配置加载失败")
else:
    print("配置加载成功: ", config.keys())
```

### 4. 验证数值计算
```gdscript
# 验证修改器计算
var base_damage = 100.0
var tags = ["damage", "fire", "aoe"]
var final_damage = ModifierManager.get_modified_value(base_damage, tags)
print("基础伤害: %d, 最终伤害: %d" % [base_damage, final_damage])
```

---

## 性能优化建议

### 1. 配置加载
- 在 `_ready()` 中一次性加载所有配置
- 使用缓存避免重复加载
- 只在必要时重新加载

### 2. 羁绊计算
- 只在状态变化时重新计算
- 使用信号通知而不是轮询
- 缓存计算结果

### 3. 武器系统
- 使用缓存避免重复创建 Stats
- 预加载常用武器
- 延迟加载不常用武器

### 4. UI更新
- 使用信号驱动更新
- 避免每帧更新
- 批量更新UI元素

---

## 贡献指南

### 文档更新
如果你修改了系统代码，请同步更新对应的文档：

1. 更新系统文档中的 API 说明
2. 添加新的配置示例
3. 更新版本历史
4. 检查相关系统的文档是否需要更新

### 代码规范
- 使用有意义的变量名
- 添加详细的注释
- 遵循 GDScript 风格指南
- 使用类型提示

### 测试
- 添加新功能时编写测试用例
- 修改现有功能时验证不影响其他系统
- 使用调试工具验证功能

---

## 常见问题

### Q: 如何快速了解某个系统？
**A**: 阅读对应系统的文档，重点关注"系统概述"和"核心API"章节。

### Q: 配置修改后不生效？
**A**: 确保重启了游戏，配置在 `_ready()` 时加载。

### Q: 如何调试羁绊计算问题？
**A**: 使用 `BondManager.print_active_bonds()` 和 `get_tag_sources()` 查看状态。

### Q: 如何添加新的效果类型？
**A**: 
1. 在对应系统中添加处理逻辑
2. 在配置文件中添加新的效果类型
3. 更新文档说明

### Q: 文档中的示例代码可以直接使用吗？
**A**: 可以，但建议根据实际情况调整。示例代码主要用于说明用法。

---

## 版本信息

- **游戏名称**: PolyLash
- **引擎版本**: Godot 4.5
- **配置版本**: 1.0
- **文档版本**: 1.0
- **最后更新**: 2026-02-23

---

## 联系方式

如果你在使用文档时遇到问题，或者发现文档中的错误，请：

1. 检查是否有更新的文档版本
2. 查看相关系统的文档
3. 使用调试工具验证问题
4. 提交问题报告

---

## 致谢

感谢所有为 PolyLash 项目做出贡献的开发者！

---

## 下一步

- 阅读 **[00_系统大纲](00_系统大纲.md)** 了解整体架构
- 选择感兴趣的系统深入学习
- 尝试修改配置文件
- 使用调试工具探索系统

祝你开发愉快！🎮
