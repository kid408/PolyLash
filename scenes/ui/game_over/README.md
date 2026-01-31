# Game Over Screen (游戏结算界面)

## 概述
当玩家在战斗中死亡时，游戏会暂停并显示结算界面，展示本局的关键数据。

## 文件结构
```
scenes/ui/game_over/
├── game_over_screen.tscn    # UI 场景
├── game_over_screen.gd      # 脚本逻辑
└── README.md                # 本文档
```

## 功能特性

### 当前显示内容
- **标题**: "游戏结束"
- **击杀数**: 本局击杀的敌人总数
- **获得金币**: 本局获得的金币总数
- **返回按钮**: 点击返回角色选择界面

### 扩展性设计
统计区域使用 `GridContainer` 布局，方便未来添加更多统计项：
- 存活时间
- 造成伤害
- 最高连击
- 使用技能次数
- 等等...

## 使用方法

### 在代码中显示结算界面
```gdscript
# 1. 预加载场景
const GAME_OVER_SCENE = preload("res://scenes/ui/game_over/game_over_screen.tscn")

# 2. 实例化
var game_over_screen = GAME_OVER_SCENE.instantiate()
add_child(game_over_screen)

# 3. 设置数据
var stats = {
    "kills": 105,
    "gold": 500
}
game_over_screen.set_stats(stats)

# 4. 显示界面（会自动暂停游戏）
game_over_screen.show_screen()
```

### 动态添加统计项
```gdscript
# 添加自定义统计行
game_over_screen.add_stat_row("存活时间:", "5:32", Color.CYAN)
game_over_screen.add_stat_row("造成伤害:", "12,450", Color.ORANGE_RED)
```

## 数据追踪

### Global 自动加载中的会话数据
```gdscript
# 在 autoloads/global.gd 中
var session_kills: int = 0   # 击杀数
var session_gold: int = 0    # 金币数
var session_xp: int = 0      # 经验值

# 添加击杀
Global.add_session_kill()

# 添加金币
Global.add_session_gold(amount)

# 重置数据（新游戏开始时）
Global.reset_session_data()
```

### 集成位置
- **Arena**: `scenes/arena/arena.gd` 中监听玩家死亡并显示结算界面
- **Enemy**: `scenes/unit/enemy/enemy.gd` 中记录击杀数
- **Player**: `scenes/unit/players/player_base.gd` 中记录金币获取

## UI 样式
- **背景**: 半透明黑色遮罩 (Alpha=0.8)
- **主面板**: 深灰色圆角面板 (600x500)
- **标题**: 红色大字 (56px)
- **统计标签**: 灰色 (28px)
- **统计数值**: 金黄色 (28px)
- **按钮**: 红色圆角按钮 (70px 高)

## 未来扩展建议

### 可添加的统计项
1. **存活时间**: 从游戏开始到死亡的时间
2. **造成伤害**: 总伤害输出
3. **最高连击**: 最高连续击杀数
4. **技能使用**: Q/E/R 技能使用次数
5. **受到伤害**: 总承受伤害
6. **闪避次数**: 成功闪避攻击的次数
7. **暴击次数**: 触发暴击的次数
8. **最远击杀**: 最远距离击杀敌人

### 可添加的功能
1. **评分系统**: 根据表现给出 S/A/B/C 评级
2. **成就解锁**: 显示本局解锁的成就
3. **排行榜**: 与历史最佳成绩对比
4. **分享功能**: 截图分享战绩
5. **重新开始**: 直接重新开始游戏（不返回大厅）

## 注意事项
1. 结算界面会自动暂停游戏 (`get_tree().paused = true`)
2. 点击返回按钮会重置所有会话数据
3. 确保在新游戏开始时调用 `Global.reset_session_data()`
4. 统计数据在 `Global` 中持久化，直到手动重置
