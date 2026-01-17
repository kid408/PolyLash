# PolyLash 项目文档

欢迎来到 PolyLash 项目文档。本文档包含了游戏的完整架构、系统设计和开发指南。

## 📚 文档导航

### 核心系统
- **[架构设计](ARCHITECTURE.md)** - 项目整体架构和模块划分
- **[系统概览](SYSTEMS.md)** - 游戏核心系统介绍

### 游戏内容
- **[敌人系统](ENEMIES.md)** - 敌人类型、配置和精英怪系统
- **[玩家系统](PLAYERS.md)** - 玩家角色、技能和升级系统
- **[武器系统](WEAPONS.md)** - 武器类型和配置
- **[技能系统](SKILL_SYSTEM.md)** - 技能机制和实现

### 配置管理
- **[配置指南](CONFIGURATION.md)** - CSV 配置文件使用说明
- **[波次系统](WAVES.md)** - 敌人波次和生成配置

### 开发指南
- **[开发文档](DEVELOPMENT.md)** - 开发环境和工作流程

## 🎮 快速开始

### 项目结构
```
PolyLash/
├── scenes/          # 游戏场景和脚本
├── config/          # CSV 配置文件
├── autoloads/       # 全局管理器
├── assets/          # 游戏资源（精灵、音频等）
├── effects/         # 特效和着色器
└── docs/            # 项目文档
```

### 主要系统

#### 敌人系统
- **普通敌人**: 基础敌人类型，可配置属性
- **精英怪（EnemyGlutton）**: 可进化的特殊敌人，通过吞噬其他敌人进化
- **特殊敌人**: 剪刀手、硬壳龟、刺猬、地雷怪等

#### 玩家系统
- **多角色选择**: 支持多个可玩角色
- **技能系统**: 每个角色有独特的技能
- **升级系统**: 属性升级和技能升级

#### 配置系统
- **CSV 配置**: 所有游戏数据通过 CSV 配置
- **动态加载**: 配置在运行时动态加载
- **易于修改**: 无需重新编译即可调整游戏参数

## 🔧 配置文件

### 敌人配置
- `config/enemy/enemy_config.csv` - 敌人基础属性
- `config/enemy/enemy_visual.csv` - 敌人视觉配置
- `config/enemy/elite_enemies_config.csv` - 精英怪配置
- `config/enemy/elite_evolution_config.csv` - 精英怪进化配置

### 玩家配置
- `config/player/player_config.csv` - 玩家属性
- `config/player/player_skills.csv` - 玩家技能
- `config/player/player_weapons.csv` - 玩家武器

### 波次配置
- `config/wave/wave_config.csv` - 波次配置
- `config/wave/wave_units_config.csv` - 波次敌人配置
- `config/wave/elite_spawn_config.csv` - 精英怪生成配置

## 📝 最近更新

### 敌人缩放修复
- 修复了所有敌人都变大的问题
- 调整了精英怪的缩放倍数
- 确保敌人大小与主角相近

### 精英怪系统完善
- 完整的进化系统实现
- 吞噬机制和属性增长
- 阶段特定的能力和效果

## 🚀 开发工作流

### 修改游戏参数
1. 编辑相应的 CSV 配置文件
2. 保存文件（UTF-8 No BOM 编码）
3. 重启 Godot 编辑器（Godot 会缓存配置）
4. 测试修改效果

### 添加新敌人
1. 在 `enemy_config.csv` 中添加敌人配置
2. 在 `enemy_visual.csv` 中添加视觉配置
3. 创建敌人场景或使用现有场景
4. 在波次配置中使用新敌人

### 添加新技能
1. 在 `player_skills.csv` 中添加技能配置
2. 创建技能脚本（继承自 Skill 基类）
3. 在玩家配置中绑定技能
4. 测试技能效果

## 📖 文档约定

- **中文**: 所有文档使用中文编写
- **Markdown**: 使用 Markdown 格式
- **代码示例**: 使用 GDScript 代码块
- **链接**: 使用相对路径链接

## 🤝 贡献指南

在修改代码或配置时：
1. 保持代码风格一致
2. 添加必要的注释
3. 更新相关文档
4. 测试修改效果

## 📞 获取帮助

- 查看相关的系统文档
- 检查配置文件的注释
- 查看代码中的 print 调试信息
- 参考现有的实现示例

---

**最后更新**: 2026年1月17日
