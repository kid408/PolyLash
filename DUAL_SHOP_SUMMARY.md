# 双商店系统 - 快速总结

## ✅ 当前状态

你的项目现在已经配置为**双商店系统共存**：

### 🛍️ 系统A：物品商店（已运行）
- ✅ 配置文件：`config/item/shop_item_config.csv`
- ✅ 管理器：`autoloads/shop_manager.gd`
- ✅ UI：`scenes/ui/shop_panel/shop_panel.gd`
- ✅ 自动加载：已注册
- ✅ 状态：**正常运行中**

### ⚡ 系统B：属性商店（已创建，待集成）
- ✅ 配置文件：`config/wave/shop_attribute_config.csv` + `shop_wave_config.csv`
- ✅ 管理器：`autoloads/shop_attribute_manager.gd`
- ✅ UI脚本：`scenes/ui/shop_panel/attribute_shop_panel.gd`
- ⚠️ 自动加载：**需要手动添加**
- ⚠️ UI场景：**需要创建 .tscn 文件**
- ⚠️ 游戏集成：**需要在游戏流程中调用**

## 📋 完成集成的3个步骤

### 步骤1：添加自动加载（2分钟）

在 `project.godot` 文件的 `[autoload]` 部分添加：

```ini
ShopAttributeManager="*res://autoloads/shop_attribute_manager.gd"
```

或在Godot编辑器中：
1. 项目 -> 项目设置 -> 自动加载
2. 路径：`res://autoloads/shop_attribute_manager.gd`
3. 节点名称：`ShopAttributeManager`
4. 勾选"启用"

### 步骤2：创建属性商店场景（5分钟）

1. 新建场景，根节点 `Control`
2. 附加脚本：`res://scenes/ui/shop_panel/attribute_shop_panel.gd`
3. 添加UI节点（参考下面的结构）
4. 保存为：`res://scenes/ui/shop_panel/attribute_shop_panel.tscn`

#### 最简UI结构：

```
Control (AttributeShopPanel)
└── Panel
    └── VBoxContainer
        ├── Label (%TitleLabel) - "属性商店"
        ├── Label (%GoldLabel) - "金币: 0"
        ├── Label (%WaveLabel) - "第1波"
        ├── HBoxContainer (%AttributesContainer) - 卡片容器
        └── HBoxContainer
            ├── Button (%RerollButton) - "刷新"
            └── Button (%CloseButton) - "关闭"
```

**重要**：所有带 `%` 的节点必须勾选"Unique Name"！

### 步骤3：集成到游戏流程（10分钟）

在你的游戏管理器（Arena/GameManager）中：

```gdscript
# 添加节点引用
@onready var attribute_shop_panel = $AttributeShopPanel  # 或通过路径获取

# 在波次结束时调用
func _on_wave_completed(wave_number: int):
    # 显示属性商店
    attribute_shop_panel.show_shop(wave_number + 1)
    
    # 等待关闭
    await attribute_shop_panel.shop_closed
    
    # 继续游戏...
```

## 🎮 三种集成方案

### 方案1：同时显示（推荐）
两个商店同时出现，玩家可以在两边购买。

```gdscript
func _on_wave_completed(wave_number: int):
    shop_panel.show_shop(wave_number + 1)
    attribute_shop_panel.show_shop(wave_number + 1)
    await shop_panel.next_wave_requested
```

### 方案2：交替显示
奇数波物品商店，偶数波属性商店。

```gdscript
func _on_wave_completed(wave_number: int):
    if wave_number % 2 == 1:
        shop_panel.show_shop(wave_number + 1)
        await shop_panel.next_wave_requested
    else:
        attribute_shop_panel.show_shop(wave_number + 1)
        await attribute_shop_panel.shop_closed
```

### 方案3：先后显示
先显示物品商店，关闭后显示属性商店。

```gdscript
func _on_wave_completed(wave_number: int):
    shop_panel.show_shop(wave_number + 1)
    await shop_panel.next_wave_requested
    
    attribute_shop_panel.show_shop(wave_number + 1)
    await attribute_shop_panel.shop_closed
```

## 🧪 快速测试

完成集成后，运行游戏并测试：

1. ✅ 完成第一波
2. ✅ 属性商店是否显示
3. ✅ 能否看到4-5个属性卡片
4. ✅ 购买属性后金币是否扣除
5. ✅ 属性效果是否应用到玩家
6. ✅ 刷新功能是否正常
7. ✅ 关闭商店后游戏是否继续

## 📊 两个商店的区别

| 特性 | 物品商店 | 属性商店 |
|------|---------|---------|
| **内容** | 特殊物品（多效果） | 单一属性 |
| **价格** | 固定 | 动态增长 |
| **数量** | 3个 | 4-5个 |
| **正负比例** | 固定 | 可调（80%→60%） |
| **适合** | 特殊Build | 基础成长 |

## 🔧 配置调整

### 调整属性出现概率

编辑 `config/wave/shop_attribute_config.csv`：

```csv
# 让生命提升更常见（权重20）
health_boost,生命提升,...,shop_weight=20,...

# 让暴击率更稀有（权重5）
crit_chance_boost,暴击率提升,...,shop_weight=5,...
```

### 调整正负属性比例

编辑 `config/wave/shop_wave_config.csv`：

```csv
# 早期90%正属性
1,3,...,positive_weight=90,negative_weight=10,...

# 后期50%正属性（更多权衡）
16,999,...,positive_weight=50,negative_weight=50,...
```

### 调整价格

```csv
# 降低基础价格
health_boost,...,base_price=40,...

# 调整增长速度
health_boost,...,price_scaling=1.1,...  # 慢增长
crit_chance_boost,...,price_scaling=1.4,...  # 快增长
```

## 📁 已创建的文件

1. ✅ `config/wave/shop_attribute_config.csv` - 30种属性
2. ✅ `config/wave/shop_wave_config.csv` - 5个波次段
3. ✅ `autoloads/shop_attribute_manager.gd` - 管理器
4. ✅ `scenes/ui/shop_panel/attribute_shop_panel.gd` - UI脚本
5. ✅ `config/wave/SHOP_CONFIG_README.md` - 配置文档
6. ✅ `DUAL_SHOP_SYSTEM_GUIDE.md` - 详细指南
7. ✅ `tools/setup_dual_shop.gd` - 设置工具
8. ✅ `tools/check_shop_usage.gd` - 检查工具

## 🚀 下一步

### 立即行动（必需）：
1. [ ] 添加 `ShopAttributeManager` 到自动加载
2. [ ] 创建 `attribute_shop_panel.tscn` 场景
3. [ ] 在游戏流程中调用属性商店

### 可选优化：
- [ ] 调整属性配置（概率、价格）
- [ ] 美化属性商店UI
- [ ] 添加音效和特效
- [ ] 添加属性预览功能

## 📞 需要帮助？

### 运行检查工具：
在Godot编辑器中打开 `tools/check_shop_usage.gd`，点击 File -> Run

### 运行设置工具：
在Godot编辑器中打开 `tools/setup_dual_shop.gd`，点击 File -> Run

### 查看详细文档：
- `DUAL_SHOP_SYSTEM_GUIDE.md` - 完整集成指南
- `config/wave/SHOP_CONFIG_README.md` - 配置说明

## ✨ 系统优势

### 为什么使用双商店？

1. **维度分离**：物品（打包效果）vs 属性（单一效果）
2. **灵活性**：玩家可以精细调整Build
3. **策略深度**：正负属性权衡增加决策
4. **渐进式难度**：属性价格和负属性比例随波次增长
5. **易于平衡**：两个系统独立调整，互不影响

## 🎯 推荐配置

当前配置已针对Brotato风格优化：
- ✅ 早期友好（80%正属性，打折价格）
- ✅ 渐进式难度（逐步增加负属性）
- ✅ 价格合理（基于玩家金币获取）
- ✅ 多样性（30种属性）
- ✅ 波次限制（高级属性后期解锁）

**两个商店现在是完全独立的，不会相互影响！** 🎉
