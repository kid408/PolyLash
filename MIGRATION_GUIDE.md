# 商店系统迁移指南

## 📋 迁移概述

从旧的 `shop_item_config.csv` 物品系统迁移到新的 `shop_attribute_config.csv` 属性系统。

## 🔍 当前状态

### 旧系统文件：
- ✅ `config/item/shop_item_config.csv` - 正在使用
- ✅ `autoloads/shop_manager.gd` - 正在使用
- ✅ `scenes/ui/shop_panel/shop_panel.gd` - 正在使用

### 新系统文件：
- ✅ `config/wave/shop_attribute_config.csv` - 已创建
- ✅ `config/wave/shop_wave_config.csv` - 已创建
- ✅ `autoloads/shop_attribute_manager.gd` - 已创建
- ❌ 未添加到自动加载
- ❌ UI未集成

## 🚀 迁移步骤

### 步骤1：添加新管理器到自动加载

在 `project.godot` 的 `[autoload]` 部分添加：

```ini
ShopAttributeManager="*res://autoloads/shop_attribute_manager.gd"
```

位置建议：放在 `ShopManager` 之后。

### 步骤2：修改商店UI

修改 `scenes/ui/shop_panel/shop_panel.gd`：

#### 2.1 修改信号连接

**旧代码：**
```gdscript
ShopManager.shop_items_generated.connect(_on_shop_items_generated)
ShopManager.item_purchased.connect(_on_item_purchased)
ShopManager.shop_rerolled.connect(_on_shop_rerolled)
ShopManager.purchase_failed.connect(_on_purchase_failed)
```

**新代码：**
```gdscript
# 暂时保留旧系统的信号连接，或者注释掉
# ShopManager.shop_items_generated.connect(_on_shop_items_generated)
# ...
```

#### 2.2 修改商店生成

**旧代码：**
```gdscript
func show_shop(wave_number: int) -> void:
    ShopManager.generate_shop_items(3)
```

**新代码：**
```gdscript
func show_shop(wave_number: int) -> void:
    var attributes = ShopAttributeManager.generate_shop_for_wave(wave_number)
    _display_attributes(attributes)
```

#### 2.3 添加属性显示函数

```gdscript
func _display_attributes(attributes: Array) -> void:
    """显示属性列表"""
    _clear_shop_items()
    
    for i in range(attributes.size()):
        var attr = attributes[i]
        var card = shop_item_card_scene.instantiate()
        card.card_index = i
        
        # 构造显示数据
        var display_data = {
            "item_id": attr.attribute_id,
            "item_name": attr.display_name,
            "price": attr.price,
            "effects": [{
                "description": _format_attribute_description(attr),
                "is_trade_off": not attr.is_positive
            }]
        }
        
        card.setup(display_data)
        card.purchase_requested.connect(_on_card_purchase_requested)
        
        shop_items_container.add_child(card)
        current_cards.append(card)
    
    _update_all_cards_affordability()

func _format_attribute_description(attr: Dictionary) -> String:
    """格式化属性描述"""
    var value_str = ""
    if attr.value_type == "flat":
        value_str = "%+.0f" % attr.value
    else:  # percent
        value_str = "%+.0f%%" % (attr.value * 100)
    
    return "%s: %s" % [attr.display_name, value_str]
```

#### 2.4 修改购买逻辑

**旧代码：**
```gdscript
func _on_card_purchase_requested(card_index: int) -> void:
    ShopManager.purchase_item(card_index)
```

**新代码：**
```gdscript
func _on_card_purchase_requested(card_index: int) -> void:
    var attributes = ShopAttributeManager.get_current_shop_attributes()
    if card_index < 0 or card_index >= attributes.size():
        return
    
    var attr = attributes[card_index]
    
    # 检查金币
    if DataManager.get_total_gold() < attr.price:
        print("[ShopPanel] 金币不足")
        return
    
    # 扣除金币
    DataManager.add_gold(-attr.price)
    
    # 应用属性效果
    _apply_attribute_to_player(attr)
    
    # 标记为已购买
    if card_index < current_cards.size():
        current_cards[card_index].set_purchased(true)
    
    _update_all_cards_affordability()

func _apply_attribute_to_player(attr: Dictionary) -> void:
    """应用属性到玩家"""
    var player = Global.player
    if not player:
        printerr("[ShopPanel] 错误: 玩家不存在")
        return
    
    match attr.effect_target:
        "stat":
            _apply_stat_effect(player, attr)
        "modifier":
            _apply_modifier_effect(attr)

func _apply_stat_effect(player, attr: Dictionary) -> void:
    """应用属性效果"""
    var stat_name = attr.target_tags[0] if attr.target_tags.size() > 0 else ""
    var value = attr.value
    
    match stat_name:
        "max_health":
            if player.has_node("HealthComponent"):
                var health_comp = player.get_node("HealthComponent")
                health_comp.max_health += value
                health_comp.current_health = min(health_comp.current_health, health_comp.max_health)
        "speed":
            if "speed" in player:
                player.speed += value
        "damage":
            if "damage" in player:
                player.damage += value
        "armor":
            if "max_armor" in player:
                player.max_armor += int(value)
                player.armor = min(player.armor, player.max_armor)
        "crit_chance":
            UpgradeManager.add_attribute_bonus("crit_chance", value)
        # 添加其他属性...

func _apply_modifier_effect(attr: Dictionary) -> void:
    """应用修改器效果"""
    ModifierManager.add_modifier(attr.target_tags, "percent_add", attr.value)
```

#### 2.5 修改刷新逻辑

**旧代码：**
```gdscript
func _on_reroll_button_pressed() -> void:
    ShopManager.reroll_shop()
```

**新代码：**
```gdscript
func _on_reroll_button_pressed() -> void:
    var current_wave = Global.current_wave_number  # 需要获取当前波次
    var reroll_cost = ShopAttributeManager.get_reroll_cost(current_wave)
    
    if DataManager.get_total_gold() < reroll_cost:
        print("[ShopPanel] 金币不足，无法刷新")
        return
    
    DataManager.add_gold(-reroll_cost)
    
    var attributes = ShopAttributeManager.generate_shop_for_wave(current_wave)
    _display_attributes(attributes)
```

### 步骤3：测试

1. 启动游戏
2. 完成第一波
3. 检查商店是否正确显示属性
4. 测试购买功能
5. 测试刷新功能

### 步骤4：清理旧系统（可选）

如果新系统运行正常，可以：

1. 从 `project.godot` 移除 `ShopManager` 自动加载
2. 备份或删除 `autoloads/shop_manager.gd`
3. 备份或删除 `config/item/shop_item_config.csv`

## ⚠️ 注意事项

### 需要保留的旧系统功能

如果 `shop_item_config.csv` 中有特殊物品（非属性），建议：

1. **方案A**：将特殊物品转换为属性配置
2. **方案B**：保留双系统，用于不同类型的商店物品

### 数据迁移

旧配置中的物品可以这样迁移到新系统：

**旧物品：**
```csv
berserker_mask,狂战士面具,consumable,2,percent_add,modifier,damage,0.30,...,150,10,0
berserker_mask,狂战士面具,consumable,2,flat_add,stat,max_health,-20,...,150,10,1
```

**新属性：**
```csv
berserker_damage,狂战士伤害,modifier,modifier,damage,0.30,percent,150,1.25,10,1,999,1
berserker_health_penalty,狂战士生命惩罚,stat,stat,max_health,-20,flat,0,1.0,0,1,999,0
```

注意：
- 拆分为独立属性
- 负属性价格设为0（因为是惩罚）
- 权重设为0（不单独出现）
- 需要在UI层面组合显示

## 🎯 推荐迁移策略

### 阶段1：并行运行（1-2天）
- 保留旧系统
- 添加新系统
- 在测试场景中使用新系统

### 阶段2：切换（1天）
- 修改商店UI使用新系统
- 保留旧系统作为备份

### 阶段3：清理（可选）
- 确认新系统稳定后移除旧系统

## 📞 需要帮助？

如果遇到问题：
1. 检查控制台错误信息
2. 确认 `ShopAttributeManager` 已正确加载
3. 验证CSV文件格式正确
4. 测试单个属性购买流程

## 🔗 相关文档

- `config/wave/SHOP_CONFIG_README.md` - 新系统配置说明
- `autoloads/shop_attribute_manager.gd` - 新管理器代码
- `autoloads/shop_manager.gd` - 旧管理器代码（参考）
