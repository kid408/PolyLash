# 敌人创建工具

## 📁 文件说明

### create_enemy_tool.gd ⭐ 主工具

**用途**: 创建敌人的唯一工具  
**使用**: 修改配置 -> 运行脚本 -> 完成  
**时间**: 30秒-2分钟

```gdscript
// 1. 打开 create_enemy_tool.gd
// 2. 修改 _run() 中的配置
var config = {
	"enemy_id": "my_enemy",
	"display_name": "我的敌人",
	"health": 100,
	...
}
// 3. File -> Run
```

### test_enemy_creation.gd 🧪 测试工具

**用途**: 测试敌人创建系统  
**使用**: File -> Run

---

## 🎯 使用流程

```
1. 打开 create_enemy_tool.gd
   ↓
2. 修改配置
   ↓
3. File -> Run
   ↓
4. 测试敌人
```

---

## 🎨 预设模板

### fast_melee - 快速近战
```
生命: 80
速度: 250
伤害: 8
```

### tank - 坦克
```
生命: 300
速度: 100
伤害: 20
击退抗性: 0.9
```

### ranged - 远程
```
生命: 60
速度: 120
伤害: 12
能力: shooting
```

### charger - 冲锋
```
生命: 150
速度: 180
伤害: 20
能力: charge
```

---

## 🔧 配置文件位置

```
config/enemy/
├── enemy_config.csv      # 基础属性
├── enemy_visual.csv      # 视觉配置
└── enemy_abilities.csv   # 能力配置
```

---

## ❓ 快速排错

### 问题1: 脚本运行没反应
```
解决: 检查控制台输出，查看错误信息
```

### 问题2: 敌人不显示
```
解决: 
1. 检查 enemy_id 拼写
2. 检查精灵路径
3. 重启游戏
```

### 问题3: 能力不生效
```
解决:
1. 检查 enemy_abilities.csv
2. 确认 ability_id 正确
3. 重启游戏
```

---

## 📚 相关文档

- `HOW_TO_USE.md` - 详细使用说明
- `../ENEMY_QUICK_START.md` - 快速开始
- `../docs/敌人创建完整指南_中文.md` - 完整指南
- `../ENEMY_SYSTEM_README.md` - 系统说明

---

## 💡 最佳实践

1. **使用有意义的ID**
   - ✅ fire_demon
   - ❌ enemy1

2. **及时测试**
   - 创建后立即测试
   - 避免积累问题

3. **备份配置**
   - 修改前备份CSV
   - 使用版本控制

---

## 🚀 开始创建

现在就打开 `create_enemy_tool.gd` 开始创建你的第一个敌人吧！

**祝你创作愉快！** 🎮

---

**最后更新**: 2026-01-25
