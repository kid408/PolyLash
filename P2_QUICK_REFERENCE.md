# P2 机制快速参考卡

## 🎯 快速测试指南

### 金币系统
```
1. 击杀敌人 → 观察金币生成
2. 靠近金币 → 观察磁力吸附
3. 接触金币 → 验证拾取
```

### P2-1: 二次爆炸
```
角色: Pyro
圣物: 爆破师 Lv.2
操作: 画闭合图形
预期: 主爆炸 → 0.3秒 → 二次爆炸（1.5倍范围，50%伤害）
```

### P2-2: 反伤墙
```
角色: 任意
圣物: 筑墙者 Lv.2
操作: 画开放路径
预期: 敌人接触 → 受到反伤（30%攻击力）
```

---

## 🔍 控制台关键输出

### 金币系统
```
[GoldCoin] 拾取金币: 1
[Global] 生成金币: 1 at (X, Y)
```

### P2-1: 二次爆炸
```
[SkillFirePath] [P2-1] 准备触发二次爆炸...
[SkillFirePath] [P2-1] 二次爆炸触发: 伤害=20 (原始伤害的50%)
```

### P2-2: 反伤墙
```
[SkillDrawingBase] [P2-2] 反伤墙激活: 伤害=30 (玩家攻击力的30%)
[SkillDrawingBase] [P2-2] 反伤墙触发: 对 Enemy 造成 30 伤害
```

---

## 📋 测试清单

### 金币系统
- [ ] 金币生成 ✓
- [ ] 弹跳动画 ✓
- [ ] 磁力吸附 ✓
- [ ] 拾取功能 ✓
- [ ] 拾取范围加成 ✓
- [ ] 金币轨迹 ✓

### P2-1: 二次爆炸
- [ ] 主爆炸 ✓
- [ ] 0.3秒延迟 ✓
- [ ] 二次爆炸 ✓
- [ ] 范围 1.5倍 ✓
- [ ] 伤害 50% ✓

### P2-2: 反伤墙
- [ ] 线条生成 ✓
- [ ] 敌人接触 ✓
- [ ] 反伤触发 ✓
- [ ] 伤害 30% ✓
- [ ] 飘字显示 ✓

---

## 🐛 常见问题

### 金币不生成
```
检查: Global.GOLD_COIN_SCENE 是否加载
检查: enemy_config.gold_value 是否 > 0
```

### 金币不吸附
```
检查: Global.player 是否有效
检查: player.pickup_range 值
```

### 二次爆炸不触发
```
检查: BondManager.has_mechanic("secondary_explode")
检查: 闭合图形是否正确
```

### 反伤墙不触发
```
检查: BondManager.has_mechanic("thorns_wall")
检查: 线条碰撞体是否创建
```

---

## 📊 数值参考

### 金币系统
- 基础拾取范围: 150 像素
- 炼金术士 Lv.1: 225 像素 (+50%)
- 金币轨迹间隔: 100 像素
- 吸附速度: 800 像素/秒

### P2-1: 二次爆炸
- 延迟: 0.3 秒
- 范围倍率: 1.5x
- 伤害倍率: 0.5x (50%)
- 持续时间: 2.0 秒

### P2-2: 反伤墙
- 伤害倍率: 0.3x (30% 攻击力)
- 触发方式: 碰撞检测
- 飘字: "THORNS!"

---

## 🎮 快速操作

### 进入游戏
```
F5 → 选择角色 → 装备圣物 → 开始游戏
```

### 测试金币
```
击杀敌人 → 观察金币 → 靠近拾取
```

### 测试二次爆炸
```
Q键 → 画圆 → 松开Q → 等待0.3秒
```

### 测试反伤墙
```
Q键 → 画线 → 松开Q → 敌人接触
```

---

## 📁 关键文件

### 金币系统
```
scenes/items/gold_coin.tscn
scenes/items/gold_coin.gd
autoloads/global.gd (spawn_coin)
```

### P2-1: 二次爆炸
```
scenes/skills/players/skill_fire_path.gd
(_trigger_secondary_explosion)
```

### P2-2: 反伤墙
```
scenes/skills/skill_drawing_base.gd
(_add_thorns_wall_effect)
```

---

## 🔧 调试命令

### 查看羁绊状态
```gdscript
print(BondManager.has_mechanic("secondary_explode"))
print(BondManager.has_mechanic("thorns_wall"))
print(BondManager.has_mechanic("gold_trail"))
```

### 查看玩家属性
```gdscript
print(Global.player.pickup_range)
print(Global.player.damage)
print(Global.player.energy)
```

### 手动生成金币
```gdscript
Global.spawn_coin(Vector2(100, 100), 5)
```

---

## 📞 快速帮助

### 需要详细测试步骤？
查看: `P2_TESTING_GUIDE.md`

### 需要实现细节？
查看: `P2_IMPLEMENTATION_COMPLETE.md`

### 需要当前状态？
查看: `CURRENT_STATUS_SUMMARY.md`

---

**版本**: v1.0  
**日期**: 2026-01-31  
**开发者**: Kiro AI Assistant
