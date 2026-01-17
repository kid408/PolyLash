# 敌人系统

## 敌人类型

### 1. 普通敌人

基础敌人类型，可通过 CSV 配置自定义属性。

**类型列表**:
- `basic_enemy` - 基础敌人
- `fast_enemy` - 快速敌人（速度快，血量少）
- `tank_enemy` - 坦克敌人（血量多，速度慢）
- `boss_enemy` - Boss 敌人（属性全面）
- `mine_layer` - 地雷怪（死后留毒池）

### 2. 特殊敌人

具有特殊能力的敌人类型。

**特殊敌人**:
- **剪刀手** (LINE_BREAKER): 可被玩家的线切割
- **硬壳龟** (SHIELDED): 减伤并反伤玩家
- **刺猬** (SPIKED): 可进行冲锋攻击
- **地雷怪** (MINE_LAYER): 死后留下毒池

### 3. 精英怪 (EnemyGlutton)

可进化的特殊敌人，通过吞噬其他敌人进化。

**特点**:
- 5 个进化阶段
- 每个阶段有不同的属性和能力
- 可吞噬附近的敌人
- 属性随进化增长

## 敌人属性

### 基础属性

| 属性 | 说明 | 默认值 |
|------|------|--------|
| health | 生命值 | 100 |
| damage | 伤害 | 10 |
| speed | 移动速度 | 150 |
| block_chance | 格挡概率 | 0 |
| xp_value | 经验奖励 | 10 |
| gold_value | 金币奖励 | 5 |
| energy_drop | 能量奖励 | 5 |

### 视觉属性

| 属性 | 说明 |
|------|------|
| sprite_path | 精灵图片路径 |
| scale_x, scale_y | 缩放倍数 |
| color_r, color_g, color_b | 颜色 RGB |
| offset_x, offset_y | 精灵偏移 |
| collision_radius | 碰撞半径 |
| hitbox_width, hitbox_height | 受击框大小 |
| z_index | Z 层级 |

### 行为属性

| 属性 | 说明 |
|------|------|
| flock_push | 群聚推力 |
| stop_distance | 停止距离 |
| can_charge | 是否可冲锋 |
| charge_prep_time | 冲锋预警时间 |
| charge_duration | 冲锋持续时间 |
| charge_speed_mult | 冲锋速度倍率 |
| charge_cooldown | 冲锋冷却时间 |

## 敌人 AI

### AI 状态机

```
┌─────────┐
│ CHASE   │ (追逐)
└────┬────┘
     │ 距离 < 300 && 距离 > 100
     ▼
┌─────────────┐
│ PREPARING   │ (预警)
└────┬────────┘
     │ 时间到
     ▼
┌─────────────┐
│ CHARGING    │ (冲锋)
└────┬────────┘
     │ 时间到
     ▼
┌─────────────┐
│ COOLDOWN    │ (冷却)
└────┬────────┘
     │ 时间到
     ▼
   回到 CHASE
```

### 状态说明

**CHASE (追逐)**
- 默认状态
- 追踪玩家
- 保持距离 > stop_distance
- 群聚逻辑避免重叠

**PREPARING (预警)**
- 显示红线警告
- 敌人颤抖
- 准备冲锋

**CHARGING (冲锋)**
- 沿直线高速移动
- 霸体（免疫击退）
- 冲锋方向固定

**COOLDOWN (冷却)**
- 缓慢移动
- 恢复后继续追逐

## 精英怪系统

### 进化阶段

| 阶段 | 名称 | 吞噬数 | 血量倍数 | 伤害倍数 | 速度倍数 | 缩放 | 特殊能力 |
|------|------|--------|---------|---------|---------|------|---------|
| 1 | 初始形态 | 1 | 1.0 | 1.0 | 1.0 | 0.5 | 无 |
| 2 | 酸液射手 | 2 | 2.0 | 1.2 | 2.067 | 0.6 | 射击投射物 |
| 3 | 巨型怪物 | 3 | 3.4 | 1.44 | 3.133 | 0.7 | 免疫击退、AoE |
| 4 | 过度进食 | 4 | 4.88 | 1.728 | 4.2 | 0.8 | 继续进化 |
| 5 | 终极形态 | ∞ | 5.456 | 2.074 | 5.267 | 0.9 | 最强形态 |

### 进化机制

**吞噬敌人**:
1. 检测 200 像素范围内的敌人
2. 吞噬敌人并增加计数
3. 恢复 10% 最大生命值
4. 增加 5% 最大生命值
5. 增加 3% 伤害

**进化条件**:
- 吞噬敌人数达到阈值
- 自动进化到下一阶段
- 更新视觉和属性

**进化效果**:
- 更新精灵图片
- 应用属性倍数
- 启用新能力
- 增加奖励值

### 进化能力

**Stage 2 - 酸液射手**
- 在 300 像素范围内射击投射物
- 冷却时间 2 秒
- 投射物速度 200 像素/秒

**Stage 3 - 巨型怪物**
- 免疫击退
- 每 3 秒进行 AoE 攻击
- AoE 范围 150 像素
- AoE 伤害 10

**Stage 4+ - 继续进化**
- 属性继续增长
- 保持所有能力

## 敌人配置

### 配置文件

**enemy_config.csv** - 敌人基础属性
```
enemy_id,health,damage,speed,xp_value,gold_value,energy_drop,...
basic_enemy,100,10,150,10,5,5,...
```

**enemy_visual.csv** - 敌人视觉配置
```
enemy_id,sprite_path,scale_x,scale_y,color_r,color_g,color_b,...
basic_enemy,res://assets/sprites/Enemies/Enemy_1.png,1,1,1,1,1,...
```

**elite_enemies_config.csv** - 精英怪基础配置
```
elite_id,stage_counts,description
enemy_glutton,1;2;3;4;999,可进化的精英怪
```

**elite_evolution_config.csv** - 精英怪进化配置
```
elite_id,stage,health_multiplier,damage_multiplier,speed_multiplier,...
enemy_glutton,1,1.0,1.0,1.0,...
```

### 修改配置

1. 打开相应的 CSV 文件
2. 修改参数值
3. 保存文件（UTF-8 No BOM 编码）
4. **重启 Godot 编辑器**（Godot 会缓存配置）
5. 测试修改效果

## 敌人生成

### 生成器 (Spawner)

**普通敌人生成**:
```gdscript
# 从 wave_config 读取配置
# 根据波次生成敌人
# 应用配置属性
```

**精英怪生成**:
```gdscript
# 从 elite_spawn_config 读取配置
# 定期生成精英怪
# 初始化进化系统
```

### 生成配置

**elite_spawn_config.csv**:
```
elite_id,spawn_interval_min,spawn_interval_max,max_spawn_count,enabled
enemy_glutton,10,20,3,1
```

| 参数 | 说明 |
|------|------|
| spawn_interval_min | 最小生成间隔（秒） |
| spawn_interval_max | 最大生成间隔（秒） |
| max_spawn_count | 最多同时存在数量 |
| enabled | 是否启用 |

## 敌人大小

### 缩放计算

```
最终缩放 = CSV中的scale_x/y值 × 基础缩放0.5
```

### 敌人缩放对照表

| 敌人类型 | CSV值 | 最终缩放 | 说明 |
|---------|------|---------|------|
| basic_enemy | 1.0 | 0.5 | 基础敌人 |
| fast_enemy | 0.8 | 0.4 | 快速敌人（较小） |
| tank_enemy | 1.5 | 0.75 | 坦克敌人（较大） |
| boss_enemy | 2.0 | 1.0 | Boss敌人（最大） |
| mine_layer | 1.0 | 0.5 | 地雷怪 |
| enemy_glutton (Stage 1) | 1.0 | 0.5 | 精英怪初始 |
| enemy_glutton (Stage 2) | 1.2 | 0.6 | 精英怪进化 |
| enemy_glutton (Stage 5) | 1.8 | 0.9 | 精英怪最终 |

## 敌人死亡

### 死亡流程

1. 生命值 <= 0
2. 播放死亡动画
3. 生成爆炸效果
4. 给玩家奖励（经验、金币、能量）
5. 移除敌人

### 特殊死亡效果

**地雷怪**:
- 死后留下毒池
- 毒池持续 8 秒
- 每 0.5 秒造成 5 伤害
- 范围 60 像素

## 调试

### 调试信息

敌人脚本中包含详细的 print 调试信息：

```gdscript
# 敌人初始化
[Enemy] 应用视觉配置: basic_enemy
[Enemy] 应用缩放: (0.5, 0.5)

# 敌人行为
[Enemy] 追逐中 | 距离玩家: 150.0 | 停止阈值: 60.0

# 精英怪进化
[EnemyGlutton] Evolved to stage 2!
[EnemyGlutton] Applied evolution multipliers:
  Health: 100 -> 200 (x2.00)
  Damage: 10 -> 12 (x1.20)
```

### 常见问题

**Q: 敌人不移动**
- 检查 `can_move` 是否为 true
- 检查 `stats.speed` 是否 > 0
- 检查玩家是否存在

**Q: 敌人大小不对**
- 检查 `enemy_visual.csv` 中的 `scale_x/y` 值
- 记住最终缩放 = CSV值 × 0.5
- 重启编辑器使配置生效

**Q: 精英怪不进化**
- 检查 `elite_evolution_config.csv` 中的吞噬数
- 检查 `eat_detection_radius` 是否足够大
- 查看输出日志中的进化检查信息

---

**最后更新**: 2026年1月17日
