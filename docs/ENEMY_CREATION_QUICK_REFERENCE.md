# 敌人创建快速参考

**版本**: 2.0  
**用途**: 快速查询和创建敌人

---

## ⚡ 30秒创建敌人

```gdscript
# 1. 打开 tools/create_enemy_tool.gd
# 2. 修改配置
var config = {
    "enemy_id": "my_enemy",
    "display_name": "我的敌人",
    "health": 100,
    "speed": 150,
    "damage": 10,
    "sprite_path": "res://assets/sprites/Enemies/Enemy_1.png"
}
# 3. File -> Run
```

---

## 📋 配置模板

### 基础敌人
```gdscript
{
    "enemy_id": "basic_enemy",
    "display_name": "基础敌人",
    "health": 100,
    "speed": 150,
    "damage": 10,
    "sprite_path": "res://assets/sprites/Enemies/Enemy_1.png"
}
```

### 远程敌人
```gdscript
{
    "enemy_id": "archer",
    "display_name": "弓箭手",
    "health": 80,
    "speed": 120,
    "damage": 12,
    "sprite_path": "res://assets/sprites/Enemies/Enemy_2.png",
    "abilities": ["shooting"]
}
```

### 冲锋敌人
```gdscript
{
    "enemy_id": "bull",
    "display_name": "公牛",
    "health": 150,
    "speed": 180,
    "damage": 20,
    "sprite_path": "res://assets/sprites/Enemies/Enemy_3.png",
    "abilities": ["charge"]
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
    "sprite_path": "res://assets/sprites/Enemies/Boss_1.png",
    "abilities": ["shooting", "charge"]
}
```

---

## 🎯 能力配置

### poison_pool - 毒池
```csv
enemy_id,poison_pool,0,0,999999,0,1,60,5,0.5,8
# 参数: 半径,伤害,间隔,持续时间
```

### shooting - 射击
```csv
enemy_id,shooting,3.0,0,300,0,1,3,45,1800,0.5
# 参数: 数量,角度,速度,伤害倍率
```

### charge - 冲锋
```csv
enemy_id,charge,3.0,100,300,0,1,0.8,0.6,3.5,30
# 参数: 预警时间,持续时间,速度倍率,线宽
```

---

## 📊 属性参考

### 生命值
```
小怪: 50-150
精英: 200-500
Boss: 800-2000
```

### 速度
```
慢速: 80-120
中速: 150-200
快速: 250-350
```

### 伤害
```
低: 5-10
中: 15-25
高: 30-50
Boss: 50-100
```

---

## 🔧 常用命令

### 创建敌人
```gdscript
var tool = load("res://tools/create_enemy_tool.gd").new()
tool.create_enemy(config)
```

### 从预设创建
```gdscript
tool.create_from_preset("my_enemy", "fast_melee")
# 预设: fast_melee, tank, ranged, charger
```

### 批量创建
```gdscript
tool.create_enemy_batch([config1, config2, config3])
```

---

## ❓ 快速排错

### 敌人不显示
```
1. 检查 enemy_id 拼写
2. 检查精灵路径
3. 重启游戏
```

### 能力不生效
```
1. 检查 enemy_abilities.csv
2. 检查 ability_id 拼写
3. 检查激活条件
```

### 属性不对
```
1. 检查CSV编码（UTF-8）
2. 运行 convert_csv_utf8.bat
3. 重启游戏
```

---

## 📁 文件位置

```
配置:
├── config/enemy/enemy_config.csv
├── config/enemy/enemy_visual.csv
└── config/enemy/enemy_abilities.csv

工具:
└── tools/create_enemy_tool.gd

场景:
└── scenes/unit/enemy/enemy_generic.tscn

能力:
└── scenes/components/abilities/
```

---

## 🎨 颜色预设

```gdscript
红色: color_r=1.0, color_g=0.2, color_b=0.2
蓝色: color_r=0.2, color_g=0.5, color_b=1.0
绿色: color_r=0.2, color_g=1.0, color_b=0.2
紫色: color_r=0.8, color_g=0.2, color_b=1.0
橙色: color_r=1.0, color_g=0.6, color_b=0.2
```

---

## 📞 获取帮助

详细文档: `docs/ENEMY_CREATION_GUIDE.md`  
系统分析: `docs/ENEMY_CREATION_ANALYSIS.md`
