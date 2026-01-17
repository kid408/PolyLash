# 系统概览

## 核心系统

### 1. 敌人系统

**功能**:
- 敌人生成和管理
- 敌人 AI 和行为
- 敌人属性和配置
- 特殊敌人类型

**关键类**:
- `Enemy` - 敌人基类
- `EnemyGlutton` - 精英怪
- `Spawner` - 敌人生成器

**配置文件**:
- `enemy_config.csv` - 敌人属性
- `enemy_visual.csv` - 敌人视觉
- `elite_enemies_config.csv` - 精英怪配置
- `elite_evolution_config.csv` - 进化配置

### 2. 玩家系统

**功能**:
- 玩家角色管理
- 玩家属性和升级
- 技能系统
- 武器系统

**关键类**:
- `Player` - 玩家基类
- `PlayerButcher` - 屠夫角色
- `PlayerHerder` - 牧羊人角色
- 其他角色类

**配置文件**:
- `player_config.csv` - 玩家属性
- `player_skills.csv` - 技能配置
- `player_weapons.csv` - 武器配置

### 3. 波次系统

**功能**:
- 波次管理
- 敌人分配
- 难度调整
- 精英怪生成

**关键类**:
- `WaveManager` - 波次管理器
- `Spawner` - 敌人生成器

**配置文件**:
- `wave_config.csv` - 波次配置
- `wave_units_config.csv` - 敌人分配
- `elite_spawn_config.csv` - 精英怪生成

### 4. 配置系统

**功能**:
- CSV 配置加载
- 配置缓存
- 配置访问接口

**关键类**:
- `ConfigManager` - 敌人配置管理
- `EliteConfigManager` - 精英怪配置管理
- `UpgradeManager` - 升级配置管理

### 5. 全局系统

**功能**:
- 全局变量管理
- 事件信号
- 工具函数

**关键类**:
- `Global` - 全局管理器

**主要信号**:
- `on_enemy_killed` - 敌人死亡
- `on_player_damaged` - 玩家受伤
- `on_camera_shake` - 摄像机震动
- `on_create_block_text` - 格挡文字

## 系统交互

### 游戏启动流程

```
1. 初始化全局系统
   ├── 加载配置文件
   ├── 初始化管理器
   └── 设置全局变量

2. 初始化场景
   ├── 创建竞技场
   ├── 初始化玩家
   ├── 初始化敌人生成器
   └── 初始化波次管理器

3. 开始游戏循环
   ├── 更新玩家
   ├── 更新敌人
   ├── 更新波次
   └── 更新 UI
```

### 敌人生成流程

```
WaveManager
├── 获取当前波次配置
├── 计算敌人数量
└── 调用 Spawner 生成敌人

Spawner
├── 普通敌人生成
│   ├── 从 wave_units_config 读取敌人类型
│   ├── 创建敌人实例
│   └── 应用配置属性
│
└── 精英怪生成
    ├── 从 elite_spawn_config 读取配置
    ├── 创建 EnemyGlutton 实例
    └── 初始化进化系统
```

### 战斗流程

```
玩家攻击
├── 创建投射物
├── 投射物移动
└── 投射物碰撞

敌人受伤
├── 计算伤害
├── 应用击退
├── 播放受伤效果
└── 检查死亡

敌人死亡
├── 播放死亡动画
├── 生成爆炸效果
├── 给玩家奖励
└── 移除敌人
```

## 关键功能

### 1. 敌人 AI

**状态机**:
- CHASE - 追逐玩家
- PREPARING - 预警（显示红线）
- CHARGING - 冲锋攻击
- COOLDOWN - 冷却恢复

**行为**:
- 追踪玩家
- 群聚避免重叠
- 冲锋攻击
- 特殊能力

### 2. 精英怪进化

**进化机制**:
- 吞噬敌人增加计数
- 达到阈值自动进化
- 每个阶段有不同能力
- 属性随进化增长

**进化阶段**:
- Stage 1: 初始形态
- Stage 2: 酸液射手
- Stage 3: 巨型怪物
- Stage 4: 过度进食
- Stage 5: 终极形态

### 3. 玩家技能

**技能类型**:
- 主动技能 - 需要手动触发
- 被动技能 - 自动生效
- 增益技能 - 提升属性

**技能系统**:
- 技能冷却
- 技能升级
- 技能组合

### 4. 升级系统

**升级类型**:
- 属性升级 - 提升基础属性
- 技能升级 - 提升技能效果
- 武器升级 - 提升武器性能

**升级机制**:
- 获得经验值
- 达到升级条件
- 选择升级项目
- 应用升级效果

## 性能优化

### 1. 对象池

- 重用敌人对象
- 重用投射物对象
- 减少内存分配

### 2. 更新优化

- 只更新可见对象
- 批量更新敌人
- 延迟更新非关键对象

### 3. 渲染优化

- 使用批处理
- 减少绘制调用
- 优化粒子效果

## 扩展性

### 添加新敌人

1. 在 `enemy_config.csv` 中添加配置
2. 在 `enemy_visual.csv` 中添加视觉配置
3. 创建敌人脚本（可选）
4. 在波次配置中使用

### 添加新技能

1. 在 `player_skills.csv` 中添加配置
2. 创建技能脚本
3. 在玩家配置中绑定
4. 实现技能效果

### 添加新玩家角色

1. 创建玩家脚本
2. 在 `player_config.csv` 中添加配置
3. 添加角色精灵和动画
4. 在选择界面中添加

## 调试工具

### 1. 配置调试

```gdscript
# 打印所有配置
EliteConfigManager.print_all_configs()
ConfigManager.print_all_configs()
```

### 2. 敌人调试

```gdscript
# 查看敌人信息
print(enemy.get_stage_info())

# 查看敌人状态
print(\"AI State: \", enemy.current_ai_state)
print(\"Position: \", enemy.global_position)
```

### 3. 玩家调试

```gdscript
# 查看玩家属性
print(\"Health: \", player.health_component.current_health)
print(\"Position: \", player.global_position)
```

## 常见问题

### Q: 如何修改敌人属性？
A: 编辑 `enemy_config.csv` 或 `enemy_visual.csv`，然后重启编辑器。

### Q: 如何添加新敌人？
A: 在配置文件中添加新行，然后在波次配置中使用。

### Q: 如何调整游戏难度？
A: 修改敌人属性、波次配置或精英怪生成配置。

### Q: 如何添加新技能？
A: 创建技能脚本，在配置中添加，然后在玩家中绑定。

### Q: 配置修改后没有生效？
A: 重启 Godot 编辑器，Godot 会缓存配置文件。

## 相关文档

- [敌人系统](ENEMIES.md)
- [玩家系统](PLAYERS.md)
- [配置指南](CONFIGURATION.md)
- [架构设计](ARCHITECTURE.md)

---

**最后更新**: 2026年1月17日
