# 敌人创建工具使用说明

## 🚀 快速开始（30秒）

1. 打开 `tools/create_enemy_tool.gd`
2. 修改 `_run()` 函数中的配置
3. File -> Run
4. 完成！

---

## 📝 详细步骤

### 1. 打开文件

在 Godot 编辑器中打开：
```
tools/create_enemy_tool.gd
```

### 2. 修改配置

找到 `_run()` 函数中的配置部分：

```gdscript
var config = {
    "enemy_id": "my_enemy",        # 修改为你的敌人ID
    "display_name": "我的敌人",     # 修改为你的敌人名称
    "health": 100,                  # 生命值
    "speed": 150,                   # 移动速度
    "damage": 10,                   # 攻击力
    "sprite_path": "res://assets/sprites/Enemies/Enemy_1.png",
    "abilities": []                 # 可选: ["poison_pool", "shooting", "charge"]
}
```

### 3. 运行脚本

- 方式1: File -> Run (选择 create_enemy_tool.gd)
- 方式2: 在脚本编辑器中按 Ctrl+Shift+X

### 4. 查看结果

控制台会显示：
```
✅ 创建成功!
下一步:
1. 打开测试场景
2. 添加 enemy_generic.tscn
3. 设置 Enemy Id
4. 按 F5 运行测试
```

---

## 📋 配置参数说明

### 必填参数

| 参数 | 类型 | 说明 | 示例 |
|-----|------|------|------|
| enemy_id | String | 敌人唯一ID（英文） | "fire_demon" |
| display_name | String | 显示名称（中文） | "火焰恶魔" |

### 基础属性（可选）

| 参数 | 类型 | 默认值 | 说明 |
|-----|------|--------|------|
| health | int | 100 | 生命值 |
| speed | int | 160 | 移动速度 |
| damage | int | 15 | 攻击力 |
| attack_range | int | 50 | 攻击范围 |
| attack_cooldown | float | 1.0 | 攻击冷却 |
| xp_value | int | 10 | 经验值 |
| gold_value | int | 5 | 金币掉落 |

### 视觉配置（可选）

| 参数 | 类型 | 默认值 | 说明 |
|-----|------|--------|------|
| sprite_path | String | Enemy_1.png | 精灵路径 |
| scale_x | float | 1.0 | X轴缩放 |
| scale_y | float | 1.0 | Y轴缩放 |

### 能力配置（可选）

| 参数 | 类型 | 说明 |
|-----|------|------|
| abilities | Array | 能力列表 |

可用能力：
- `"poison_pool"` - 死亡时产生毒池
- `"shooting"` - 远程射击
- `"charge"` - 冲锋攻击

---

## 🎨 使用示例

### 示例1: 基础近战敌人

```gdscript
var config = {
    "enemy_id": "goblin",
    "display_name": "哥布林",
    "health": 50,
    "speed": 200,
    "damage": 8
}
```

### 示例2: 坦克敌人

```gdscript
var config = {
    "enemy_id": "tank_enemy",
    "display_name": "坦克",
    "health": 300,
    "speed": 100,
    "damage": 20,
    "knockback_resistance": 0.9
}
```

### 示例3: 远程敌人

```gdscript
var config = {
    "enemy_id": "archer",
    "display_name": "弓箭手",
    "health": 60,
    "speed": 120,
    "damage": 12,
    "abilities": ["shooting"]
}
```

### 示例4: 带多个能力的敌人

```gdscript
var config = {
    "enemy_id": "boss_enemy",
    "display_name": "BOSS",
    "health": 500,
    "speed": 150,
    "damage": 30,
    "abilities": ["charge", "shooting", "poison_pool"]
}
```

---

## ❓ 常见问题

### Q1: 运行后没有反应？

**A**: 检查控制台输出，查看是否有错误信息。

### Q2: 提示 enemy_id 已存在？

**A**: 修改 enemy_id 为一个新的唯一ID。

### Q3: 敌人不显示？

**A**: 检查：
1. enemy_id 拼写是否正确
2. sprite_path 路径是否存在
3. 重启游戏

### Q4: 能力不生效？

**A**: 检查：
1. abilities 数组拼写是否正确
2. 查看 config/enemy/enemy_abilities.csv
3. 重启游戏

---

## 🔧 高级用法

### 在代码中使用

如果你是程序员，可以在其他脚本中调用：

```gdscript
var tool = load("res://tools/create_enemy_tool.gd").new()

# 创建单个敌人
tool.create_enemy(config)

# 从预设创建
tool.create_from_preset("fire_demon", "tank")

# 批量创建
tool.create_enemy_batch([config1, config2, config3])
```

### 使用预设模板

```gdscript
# 获取所有预设
var presets = tool.get_preset_templates()

# 可用预设:
# - "fast_melee" - 快速近战
# - "tank" - 坦克
# - "ranged" - 远程
# - "charger" - 冲锋
```

---

## 📚 相关文档

- `ENEMY_QUICK_START.md` - 快速开始指南
- `docs/敌人创建完整指南_中文.md` - 完整指南
- `ENEMY_SYSTEM_README.md` - 系统说明

---

**最后更新**: 2026-01-25
