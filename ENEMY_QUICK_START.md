# 敌人系统快速开始指南

**阅读时间**: 3分钟  
**上手时间**: 5分钟  
**目标**: 立即创建你的第一个敌人

---

## 🚀 3分钟创建你的第一个敌人

### 步骤1: 打开工具（10秒）

```
在Godot编辑器中:
1. 打开文件: tools/create_enemy_tool.gd
2. 找到 create_enemy_interactive() 函数
```

### 步骤2: 填写配置（1分钟）

```gdscript
var config = {
    "enemy_id": "my_first_enemy",      # 改成你的ID
    "display_name": "我的第一个敌人",   # 改成你的名字
    "health": 100,                     # 生命值
    "speed": 150,                      # 速度
    "damage": 10,                      # 伤害
    "sprite_path": "res://assets/sprites/Enemies/Enemy_1.png"  # 精灵路径
}
```

### 步骤3: 运行脚本（5秒）

```
File -> Run (或按 Ctrl+Shift+X)
```

### 步骤4: 测试敌人（2分钟）

```
1. 打开测试场景
2. 添加节点: scenes/unit/enemy/enemy_generic.tscn
3. 设置 Enemy Id 为 "my_first_enemy"
4. 按 F5 运行
```

**恭喜！你已经创建了第一个敌人！** 🎉

---

## 💡 常用配置模板

### 快速近战怪

```gdscript
{
    "enemy_id": "fast_melee",
    "display_name": "快速近战",
    "health": 80,
    "speed": 250,
    "damage": 8,
    "sprite_path": "res://assets/sprites/Enemies/Enemy_2.png"
}
```

### 坦克怪

```gdscript
{
    "enemy_id": "tank",
    "display_name": "坦克",
    "health": 300,
    "speed": 100,
    "damage": 20,
    "knockback_resistance": 0.9,
    "sprite_path": "res://assets/sprites/Enemies/Enemy_3.png"
}
```

### 远程怪

```gdscript
{
    "enemy_id": "archer",
    "display_name": "弓箭手",
    "health": 60,
    "speed": 120,
    "damage": 12,
    "sprite_path": "res://assets/sprites/Enemies/Enemy_4.png",
    "abilities": ["shooting"]  # 添加射击能力
}
```

### 冲锋怪

```gdscript
{
    "enemy_id": "bull",
    "display_name": "公牛",
    "health": 150,
    "speed": 180,
    "damage": 20,
    "sprite_path": "res://assets/sprites/Enemies/Enemy_5.png",
    "abilities": ["charge"]  # 添加冲锋能力
}
```

### Boss

```gdscript
{
    "enemy_id": "boss",
    "display_name": "Boss",
    "health": 1000,
    "speed": 120,
    "damage": 50,
    "scale_x": 2.0,
    "scale_y": 2.0,
    "sprite_path": "res://assets/sprites/Enemies/Boss_1.png",
    "abilities": ["shooting", "charge"]  # 多个能力
}
```

---

## 🎯 可用能力

### poison_pool - 毒池
死亡时留下持续伤害区域
```gdscript
"abilities": ["poison_pool"]
```

### shooting - 射击
向玩家发射投射物
```gdscript
"abilities": ["shooting"]
```

### charge - 冲锋
向玩家冲刺攻击
```gdscript
"abilities": ["charge"]
```

### 组合使用
```gdscript
"abilities": ["shooting", "charge", "poison_pool"]
```

---

## 📊 属性参考

```
生命值:
  小怪: 50-150
  精英: 200-500
  Boss: 800-2000

速度:
  慢: 80-120
  中: 150-200
  快: 250-350

伤害:
  低: 5-10
  中: 15-25
  高: 30-50
```

---

## ❓ 遇到问题？

### 敌人不显示
```
1. 检查 enemy_id 拼写
2. 检查精灵路径是否正确
3. 重启游戏
```

### 能力不生效
```
1. 检查 abilities 数组拼写
2. 确认能力ID正确: poison_pool, shooting, charge
3. 查看控制台错误信息
```

### 配置没生效
```
1. 运行 config/convert_csv_utf8.bat
2. 重启Godot
3. 检查CSV格式
```

---

## 📚 深入学习

- **完整指南**: `docs/敌人创建完整指南_中文.md`
- **快速参考**: `docs/ENEMY_CREATION_QUICK_REFERENCE.md`
- **系统分析**: `docs/ENEMY_CREATION_ANALYSIS.md`

---

## 🎓 下一步

1. ✅ 创建了第一个敌人
2. 📖 阅读完整指南
3. 🎨 尝试不同的配置
4. 🚀 创建自己的敌人库

---

**开始创建吧！** 🎮

如有问题，请查看完整文档或联系团队成员。
