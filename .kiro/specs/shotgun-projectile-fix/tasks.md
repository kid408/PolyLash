# 霰弹枪子弹场景文件名修复 - 任务清单

## 任务概览

**目标**：删除拼写错误的文件，确保霰弹枪武器正常工作  
**预计时间**：30 分钟  
**优先级**：高

---

## 任务列表

### 1. 检查文件引用

- [x] 1.1 搜索项目中对 `projectile_shootgun.tscn` 的引用
  - 搜索范围：`scenes/`, `config/`, `autoloads/`
  - 记录所有引用位置
  - **结果**：无任何引用，可以安全删除
  
- [x] 1.2 检查场景文件内部引用
  - 打开 `projectile_shootgun.tscn`（如果存在）
  - 查看是否有其他场景继承或引用它
  - **结果**：无引用
  
- [x] 1.3 确认 CSV 配置
  - 验证 `weapon_config_optimized.csv` 中 shotgun 行使用正确的文件名
  - 确认路径：`res://scenes/projectiles/projectile_shotgun.tscn`
  - **结果**：CSV 配置正确

### 2. 删除错误文件

- [x] 2.1 删除拼写错误的场景文件
  - 文件：`scenes/projectiles/projectile_shootgun.tscn`
  - 方法：在 Godot 编辑器中删除，或使用文件系统删除
  - **结果**：已删除
  
- [x] 2.2 删除关联的 UID 文件（如果存在）
  - 文件：`scenes/projectiles/projectile_shootgun.tscn.uid`
  - **结果**：已处理
  
- [x] 2.3 清理编辑器缓存
  - 删除：`.godot/editor/projectile_shootgun.tscn-folding-*.cfg`
  - 删除：`.godot/editor/projectile_shootgun.tscn-editstate-*.cfg`
  - **结果**：已清理

### 3. 验证修复

- [ ] 3.1 重新打开 Godot 项目
  - 关闭编辑器
  - 重新打开项目
  - 等待资源重新导入
  
- [ ] 3.2 检查场景文件
  - 打开 `scenes/projectiles/projectile_shotgun.tscn`
  - 确认场景正常加载
  - 检查控制台无错误
  
- [ ] 3.3 运行游戏并查看调试日志
  - 启动游戏
  - 查看控制台输出：
    ```
    [WeaponConfigLoader] DEBUG shotgun projectile:
      - projectile_path: res://scenes/projectiles/projectile_shotgun.tscn
      - is_empty: false
      - ResourceLoader.exists: true
      - projectile_scene loaded: <PackedScene#...>
    ```
  - 确认所有值正确

### 4. 功能测试

- [ ] 4.1 测试屠夫角色（默认霰弹枪）
  - 选择屠夫角色
  - 进入游戏
  - 攻击敌人
  - 验证：
    - ✓ 发射 7 颗子弹
    - ✓ 45° 扇形散射
    - ✓ 子弹造成伤害
    - ✓ 控制台无错误
  
- [ ] 4.2 测试其他使用霰弹枪的角色
  - 战士 (warrior)
  - 坦克手 (tankman)
  - 验证霰弹枪功能正常
  
- [ ] 4.3 回归测试其他远程武器
  - 手枪 (pistol)
  - 激光 (laser)
  - 左轮 (revolver)
  - 冲锋枪 (smg)
  - 确保没有引入新问题

### 5. 文档更新

- [ ] 5.1 更新修复文档
  - 记录修复过程
  - 记录测试结果
  - 更新 `霰弹枪问题分析.md`
  
- [ ] 5.2 更新系统状态文档
  - 更新 `SYSTEM_STATUS.md`
  - 标记霰弹枪问题为"已修复"
  
- [ ] 5.3 创建修复总结文档
  - 文件名：`霰弹枪文件名修复完成.md`
  - 内容：问题描述、修复方案、测试结果

---

## 任务依赖关系

```
1. 检查文件引用
   ↓
2. 删除错误文件
   ↓
3. 验证修复
   ↓
4. 功能测试
   ↓
5. 文档更新
```

## 检查清单

修复完成后，确认以下所有项：

- [ ] ✅ 项目中不存在 `projectile_shootgun.tscn`
- [ ] ✅ 项目中存在 `projectile_shotgun.tscn` 且正常工作
- [ ] ✅ CSV 配置正确
- [ ] ✅ 霰弹枪武器正常发射子弹
- [ ] ✅ 控制台无错误信息
- [ ] ✅ 其他武器不受影响
- [ ] ✅ 调试日志显示资源加载成功
- [ ] ✅ 文档已更新

## 注意事项

1. **备份**：删除文件前，确保有版本控制或备份
2. **测试**：每个步骤完成后都要测试
3. **日志**：保留所有调试日志用于分析
4. **回滚**：如果出现问题，立即回滚并重新分析

---

**任务创建时间**：2026-02-09  
**预计完成时间**：2026-02-09  
**状态**：待开始
