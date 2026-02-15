# 商店配置系统说明

## 📋 概述

新的商店配置系统将商店属性配置从物品系统中分离出来，使用两个CSV表来管理：

1. **shop_attribute_config.csv** - 属性配置表
2. **shop_wave_config.csv** - 波次配置表

## 📊 配置文件说明

### 1. shop_attribute_config.csv - 属性配置

定义所有可在商店中出现的属性及其基础参数。

#### 字段说明：

| 字段 | 说明 | 示例 |
|------|------|------|
| attribute_id | 属性唯一ID | health_boost |
| display_name | 显示名称 | 生命提升 |
| attribute_type | 属性类型 | stat / modifier |
| effect_target | 效果目标 | stat / modifier |
| target_tags | 目标标签 | max_health, damage |
| base_value | 基础数值 | 30, 0.15 |
| value_type | 数值类型 | flat / percent |
| base_price | 基础价格 | 60 |
| price_scaling | 价格缩放系数 | 1.2 (每5波增长20%) |
| shop_weight | 商店权重 | 15 (权重越高出现概率越大) |
| min_wave | 最小波次 | 1 |
| max_wave | 最大波次 | 999 |
| is_positive | 是否正属性 | 1=正属性, 0=负属性 |

#### 价格计算公式：

```
最终价格 = base_price × (price_scaling ^ (wave_number / 5)) × price_multiplier
```

例如：
- 基础价格60，缩放1.2，第5波：60 × 1.2^1 = 72金币
- 基础价格60，缩放1.2，第10波：60 × 1.2^2 = 86金币

#### 属性类型说明：

**正属性 (is_positive=1)**：
- 提升玩家能力
- 价格较高
- 权重通常较高（更常见）

**负属性 (is_positive=0)**：
- 削弱玩家某方面能力
- 价格较低（作为代价）
- 权重通常较低（较少见）
- 通常与正属性组合出现（权衡型Build）

### 2. shop_wave_config.csv - 波次配置

定义不同波次范围的商店行为。

#### 字段说明：

| 字段 | 说明 | 示例 |
|------|------|------|
| wave_range_start | 起始波次 | 1 |
| wave_range_end | 结束波次 | 3 |
| item_count | 商店物品数量 | 3 |
| reroll_cost | 刷新费用 | 30 |
| positive_weight | 正属性权重 | 80 |
| negative_weight | 负属性权重 | 20 |
| allow_duplicates | 允许重复属性 | 0=否, 1=是 |
| price_multiplier | 价格倍率 | 0.8 (早期打折) |

#### 权重说明：

正负属性出现概率 = 权重 / (正权重 + 负权重)

例如：
- 波次1-3：正80/负20 → 80%正属性，20%负属性
- 波次16+：正60/负40 → 60%正属性，40%负属性（后期更多权衡）

## 🎮 游戏设计理念

### 难度曲线

**早期 (波次1-3)**：
- 3个物品，80%正属性
- 价格打折（0.8倍）
- 刷新便宜（30金币）
- 目标：快速建立基础Build

**中期 (波次4-10)**：
- 4个物品，70-75%正属性
- 正常价格
- 允许重复（波次7+）
- 目标：优化Build方向

**后期 (波次11+)**：
- 5个物品，60-65%正属性
- 价格上涨（1.1-1.2倍）
- 更多负属性（权衡选择）
- 目标：极限优化，承担风险

### 属性平衡

#### 基础属性（低价格，高权重）：
- 生命、速度、护甲
- 价格：50-80金币
- 权重：12-15
- 适合：所有Build

#### 进阶属性（中价格，中权重）：
- 伤害、攻速、范围
- 价格：80-120金币
- 权重：10-12
- 适合：特定Build

#### 高级属性（高价格，低权重）：
- 暴击、穿透、投射物
- 价格：120-150金币
- 权重：6-10
- 适合：专精Build

#### 元素属性（中高价格，中权重）：
- 火焰、冰霜、魔法、物理
- 价格：90-110金币
- 权重：10-11
- 适合：元素Build

## 🔧 调整指南

### 调整属性出现概率

修改 `shop_attribute_config.csv` 中的 `shop_weight`：

```csv
# 让生命提升更常见
health_boost,...,shop_weight=20,...

# 让暴击率更稀有
crit_chance_boost,...,shop_weight=5,...
```

### 调整价格

**方法1：修改基础价格**
```csv
# 降低生命提升的价格
health_boost,...,base_price=50,...
```

**方法2：修改价格缩放**
```csv
# 让价格增长更慢
health_boost,...,price_scaling=1.1,...

# 让价格增长更快
crit_chance_boost,...,price_scaling=1.4,...
```

**方法3：修改波次倍率**
```csv
# shop_wave_config.csv
# 让早期更便宜
1,3,...,price_multiplier=0.7

# 让后期更贵
16,999,...,price_multiplier=1.3
```

### 调整正负属性比例

修改 `shop_wave_config.csv` 中的权重：

```csv
# 让早期更友好（更多正属性）
1,3,...,positive_weight=90,negative_weight=10,...

# 让后期更有挑战（更多负属性）
16,999,...,positive_weight=50,negative_weight=50,...
```

### 限制属性出现波次

修改 `shop_attribute_config.csv` 中的 `min_wave` 和 `max_wave`：

```csv
# 暴击率只在波次5+出现
crit_chance_boost,...,min_wave=5,...

# 基础属性只在前10波出现
health_boost,...,max_wave=10,...
```

## 📝 添加新属性

在 `shop_attribute_config.csv` 中添加新行：

```csv
# 示例：添加"闪避率"属性
dodge_chance,闪避率,stat,stat,dodge_chance,0.10,percent,100,1.3,8,7,999,1
```

参数说明：
- dodge_chance: 属性ID
- 闪避率: 显示名称
- stat: 属性类型
- stat: 效果目标
- dodge_chance: 目标标签
- 0.10: 基础数值（10%）
- percent: 百分比类型
- 100: 基础价格
- 1.3: 价格缩放
- 8: 商店权重
- 7: 最小波次7
- 999: 最大波次无限
- 1: 正属性

## 🧪 测试建议

1. **测试价格曲线**：
   ```gdscript
   for wave in [1, 5, 10, 15, 20]:
       var price = ShopAttributeManager.get_attribute_price("health_boost", wave)
       print("波次%d: %d金币" % [wave, price])
   ```

2. **测试属性分布**：
   ```gdscript
   for i in range(10):
       ShopAttributeManager.generate_shop_for_wave(5)
       ShopAttributeManager.print_shop_attributes()
   ```

3. **测试正负比例**：
   生成100次商店，统计正负属性出现次数

## 🎯 推荐配置

当前配置已针对Brotato风格进行优化：

- ✅ 早期友好（80%正属性，打折价格）
- ✅ 渐进式难度（逐步增加负属性）
- ✅ 价格合理（基于玩家金币获取速度）
- ✅ 多样性（30种属性，权重平衡）
- ✅ 波次限制（高级属性后期解锁）

如需调整，建议：
1. 先测试10波
2. 记录玩家金币和购买行为
3. 微调价格和权重（±10-20%）
4. 重新测试

## 🔗 相关文件

- `autoloads/shop_attribute_manager.gd` - 商店属性管理器
- `autoloads/shop_manager.gd` - 原商店管理器（物品系统）
- `scenes/ui/shop_panel/shop_panel.gd` - 商店UI面板

## 📞 集成到现有系统

需要在 `project.godot` 中添加自动加载：

```ini
[autoload]
ShopAttributeManager="*res://autoloads/shop_attribute_manager.gd"
```

然后在商店UI中调用：

```gdscript
func show_shop(wave_number: int):
    var attributes = ShopAttributeManager.generate_shop_for_wave(wave_number)
    _display_attributes(attributes)
```
