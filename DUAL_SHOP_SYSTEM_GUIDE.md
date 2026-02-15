# 双商店系统集成指南

## 📋 系统概述

项目现在支持**双商店系统共存**：

### 🛍️ 商店A：物品商店（ShopPanel）
- **管理器**: `ShopManager`
- **配置**: `config/item/shop_item_config.csv`
- **用途**: 特殊物品、装备、消耗品
- **特点**: 多效果组合物品（如"狂战士面具"：+30%伤害 -20生命）

### ⚡ 商店B：属性商店（AttributeShopPanel）
- **管理器**: `ShopAttributeManager`
- **配置**: `config/wave/shop_attribute_config.csv` + `shop_wave_config.csv`
- **用途**: 单一属性购买（正属性/负属性）
- **特点**: 动态价格、权重控制、波次限制

## 🎯 两个商店的区别

| 特性 | 物品商店 | 属性商店 |
|------|---------|---------|
| **购买维度** | 物品（多效果打包） | 属性（单一效果） |
| **价格** | 固定价格 | 动态价格（随波次增长） |
| **出现概率** | 固定权重 | 正负属性权重可调 |
| **适用场景** | 特殊Build、套装效果 | 渐进式成长、微调Build |
| **UI复杂度** | 显示多个效果 | 显示单一效果 |
| **配置复杂度** | 简单（1个CSV） | 复杂（2个CSV） |

## 📁 文件结构

```
项目/
├── autoloads/
│   ├── shop_manager.gd                    # 物品商店管理器（旧系统）
│   └── shop_attribute_manager.gd          # 属性商店管理器（新系统）
├── config/
│   ├── item/
│   │   └── shop_item_config.csv           # 物品配置
│   └── wave/
│       ├── shop_attribute_config.csv      # 属性配置
│       └── shop_wave_config.csv           # 波次配置
└── scenes/ui/shop_panel/
    ├── shop_panel.gd                      # 物品商店UI
    ├── attribute_shop_panel.gd            # 属性商店UI（新建）
    └── shop_item_card.gd                  # 通用卡片组件（两个商店共用）
```

## 🚀 集成步骤

### 步骤1：添加自动加载

在 `project.godot` 的 `[autoload]` 部分添加：

```ini
ShopAttributeManager="*res://autoloads/shop_attribute_manager.gd"
```

建议位置：放在 `ShopManager` 之后。

### 步骤2：创建属性商店场景

创建 `scenes/ui/shop_panel/attribute_shop_panel.tscn`：

1. 打开Godot编辑器
2. 新建场景，根节点选择 `Control`
3. 附加脚本 `attribute_shop_panel.gd`
4. 添加UI节点（参考下面的节点结构）
5. 保存为 `attribute_shop_panel.tscn`

#### 推荐节点结构：

```
Control (AttributeShopPanel)
├── Panel (背景)
│   ├── VBoxContainer
│   │   ├── HBoxContainer (顶部信息栏)
│   │   │   ├── Label (TitleLabel) - "属性商店"
│   │   │   ├── Label (WaveLabel) - "第X波"
│   │   │   └── Label (GoldLabel) - "金币: XXX"
│   │   ├── HBoxContainer (AttributesContainer) - 属性卡片容器
│   │   │   └── [动态添加卡片]
│   │   └── HBoxContainer (底部按钮栏)
│   │       ├── Button (RerollButton) - "刷新 (XX金币)"
│   │       └── Button (CloseButton) - "关闭"
```

#### 节点配置：

- `TitleLabel`: 设置 Unique Name (%)
- `WaveLabel`: 设置 Unique Name (%)
- `GoldLabel`: 设置 Unique Name (%)
- `AttributesContainer`: 设置 Unique Name (%), Alignment = Center
- `RerollButton`: 设置 Unique Name (%)
- `CloseButton`: 设置 Unique Name (%)

### 步骤3：集成到游戏流程

有两种集成方式：

#### 方案A：两个商店同时显示（推荐）

在波次结束时同时显示两个商店：

```gdscript
# 在 Arena 或 GameManager 中
func _on_wave_completed(wave_number: int):
    # 显示物品商店
    shop_panel.show_shop(wave_number + 1)
    
    # 显示属性商店
    attribute_shop_panel.show_shop(wave_number + 1)
    
    # 等待两个商店都关闭
    await shop_panel.next_wave_requested
    await attribute_shop_panel.shop_closed
    
    # 开始下一波
    start_next_wave()
```

#### 方案B：两个商店分开显示

先显示一个商店，关闭后显示另一个：

```gdscript
func _on_wave_completed(wave_number: int):
    # 先显示物品商店
    shop_panel.show_shop(wave_number + 1)
    await shop_panel.next_wave_requested
    
    # 再显示属性商店
    attribute_shop_panel.show_shop(wave_number + 1)
    await attribute_shop_panel.shop_closed
    
    # 开始下一波
    start_next_wave()
```

#### 方案C：根据波次交替显示

奇数波显示物品商店，偶数波显示属性商店：

```gdscript
func _on_wave_completed(wave_number: int):
    if wave_number % 2 == 1:
        # 奇数波：物品商店
        shop_panel.show_shop(wave_number + 1)
        await shop_panel.next_wave_requested
    else:
        # 偶数波：属性商店
        attribute_shop_panel.show_shop(wave_number + 1)
        await attribute_shop_panel.shop_closed
    
    start_next_wave()
```

### 步骤4：UI布局建议

#### 同时显示时的布局：

```
┌─────────────────────────────────────────┐
│          物品商店 (ShopPanel)            │
│  ┌────┐  ┌────┐  ┌────┐                │
│  │物品│  │物品│  │物品│  [刷新] [下一波]│
│  └────┘  └────┘  └────┘                │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│       属性商店 (AttributeShopPanel)      │
│  ┌────┐  ┌────┐  ┌────┐  ┌────┐        │
│  │属性│  │属性│  │属性│  │属性│ [刷新]  │
│  └────┘  └────┘  └────┘  └────┘ [关闭] │
└─────────────────────────────────────────┘
```

## 🎮 使用示例

### 在代码中调用属性商店：

```gdscript
# 显示属性商店
attribute_shop_panel.show_shop(5)  # 第5波

# 监听购买事件
attribute_shop_panel.attribute_purchased.connect(_on_attribute_purchased)

func _on_attribute_purchased(attribute_id: String):
    print("玩家购买了属性: %s" % attribute_id)
    # 可以添加特效、音效等
```

### 调试属性商店：

```gdscript
# 打印当前商店属性
attribute_shop_panel.print_current_attributes()

# 或直接调用管理器
ShopAttributeManager.print_shop_attributes()
```

## ⚙️ 配置调整

### 调整属性出现概率

编辑 `config/wave/shop_attribute_config.csv`：

```csv
# 让生命提升更常见
health_boost,...,shop_weight=20,...

# 让暴击率更稀有
crit_chance_boost,...,shop_weight=5,...
```

### 调整正负属性比例

编辑 `config/wave/shop_wave_config.csv`：

```csv
# 早期更友好（90%正属性）
1,3,...,positive_weight=90,negative_weight=10,...

# 后期更有挑战（50%正属性）
16,999,...,positive_weight=50,negative_weight=50,...
```

### 调整价格

```csv
# shop_attribute_config.csv
# 降低基础价格
health_boost,...,base_price=50,...

# 调整价格增长速度
health_boost,...,price_scaling=1.1,...  # 增长慢
crit_chance_boost,...,price_scaling=1.4,...  # 增长快
```

## 🔍 两个系统的协同

### 场景1：Build组合

玩家可以：
1. 在**物品商店**购买"狂战士面具"（+30%伤害 -20生命）
2. 在**属性商店**购买"生命提升"（+30生命）来弥补
3. 形成高伤害Build

### 场景2：渐进式成长

- **前期**：主要使用属性商店，逐步提升基础属性
- **中期**：开始购买物品商店的特殊物品，形成Build方向
- **后期**：两个商店配合，精细调整Build

### 场景3：风险与回报

- **属性商店**：提供负属性选项（便宜但有代价）
- **物品商店**：提供权衡型物品（高收益高代价）
- 玩家需要权衡风险

## 📊 数据流对比

### 物品商店数据流：

```
shop_item_config.csv
    ↓
ShopManager.generate_shop_items()
    ↓
ShopPanel.show_shop()
    ↓
玩家购买
    ↓
ShopManager.purchase_item()
    ↓
应用多个效果到玩家
```

### 属性商店数据流：

```
shop_attribute_config.csv + shop_wave_config.csv
    ↓
ShopAttributeManager.generate_shop_for_wave()
    ↓
AttributeShopPanel.show_shop()
    ↓
玩家购买
    ↓
AttributeShopPanel._apply_attribute_to_player()
    ↓
应用单一效果到玩家
```

## ⚠️ 注意事项

### 1. 避免效果冲突

确保两个商店的效果不会相互覆盖：
- 物品商店：使用 `ModifierManager` 添加修改器
- 属性商店：直接修改玩家属性或使用 `ModifierManager`
- 两者都使用 `ModifierManager` 时会自动叠加

### 2. 金币平衡

两个商店共享金币池，需要平衡：
- 物品商店：固定价格（100-200金币）
- 属性商店：动态价格（50-150金币，随波次增长）
- 确保玩家有足够金币在两个商店购买

### 3. UI性能

同时显示两个商店时注意：
- 限制卡片数量（物品3个 + 属性4-5个）
- 使用对象池复用卡片
- 避免频繁刷新

## 🧪 测试清单

- [ ] 属性商店能正确显示
- [ ] 购买属性后效果正确应用
- [ ] 金币扣除正确
- [ ] 刷新功能正常
- [ ] 正负属性颜色区分明显
- [ ] 价格随波次正确增长
- [ ] 两个商店可以同时/分开显示
- [ ] 已购买的属性正确标记
- [ ] 金币不足时无法购买
- [ ] 关闭商店后游戏继续

## 📞 常见问题

### Q: 两个商店会冲突吗？
A: 不会。它们使用不同的管理器和配置文件，完全独立运行。

### Q: 可以只使用一个商店吗？
A: 可以。只需在游戏流程中只调用一个商店的 `show_shop()` 方法。

### Q: 如何让某个属性只在属性商店出现？
A: 在 `shop_attribute_config.csv` 中配置，不要在 `shop_item_config.csv` 中添加。

### Q: 如何让某个物品只在物品商店出现？
A: 在 `shop_item_config.csv` 中配置，不要在 `shop_attribute_config.csv` 中添加。

### Q: 可以在一个商店中同时显示物品和属性吗？
A: 可以，但需要修改UI代码来混合显示两种类型的卡片。

## 🔗 相关文档

- `config/wave/SHOP_CONFIG_README.md` - 属性商店配置详解
- `MIGRATION_GUIDE.md` - 完全迁移指南（如果想替换旧系统）
- `autoloads/shop_manager.gd` - 物品商店管理器
- `autoloads/shop_attribute_manager.gd` - 属性商店管理器

## 🎯 推荐配置

当前推荐使用**方案A：两个商店同时显示**：

优点：
- ✅ 玩家有更多选择
- ✅ 可以组合购买形成Build
- ✅ 增加策略深度

缺点：
- ⚠️ UI空间占用较大
- ⚠️ 可能让新手困惑

如果UI空间有限，使用**方案C：根据波次交替显示**：
- 奇数波：物品商店（特殊物品）
- 偶数波：属性商店（基础提升）
