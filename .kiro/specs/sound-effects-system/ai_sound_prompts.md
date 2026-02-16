# AI 音效生成提示词文档

## 全局设定

- **游戏类型**: 2D 俯视角 Roguelike 动作游戏
- **美术风格**: 像素/卡通风格，色彩鲜明，节奏快
- **音效风格**: 清脆、有力、略带卡通感，避免过于写实。偏向合成音效 + 轻度 8-bit 风格混合
- **输出格式**: WAV, 44100Hz, 16-bit, 单声道 (Mono)
- **响度标准**: -16 LUFS（游戏音效标准）

---

## 一、UI 音效

### 1. ui_click — 按钮点击
- **音频路径**: `res://assets/audio/ui/click.wav`
- **时长**: 0.05-0.1 秒
- **场景**: 玩家点击任何 UI 按钮（开始游戏、确认、返回等）
- **提示词**: Generate a short, crisp UI button click sound for a 2D roguelike game. Bright, snappy, with a subtle digital pop. Think of a soft plastic button press with a tiny high-frequency sparkle at the end. Duration 50-100ms. Clean and satisfying.

### 2. ui_hover — 按钮悬停
- **音频路径**: `res://assets/audio/ui/hover.wav`
- **时长**: 0.03-0.05 秒
- **场景**: 鼠标悬停在按钮上时的轻微提示音
- **提示词**: Generate a very subtle, soft UI hover sound for a 2D game menu. A gentle, airy tick or whisper-like tone. Much quieter and softer than a click. Duration 30-50ms. Should feel like a feather touching glass.

### 3. ui_panel_open — 面板打开
- **音频路径**: `res://assets/audio/ui/panel_open.wav`
- **时长**: 0.2-0.4 秒
- **场景**: 商店面板、升级面板、角色选择面板滑入打开
- **提示词**: Generate a smooth panel slide-open sound for a game UI. A rising whoosh with a soft chime at the end, like a magical scroll unrolling. Slightly ethereal. Duration 200-400ms. Should feel inviting and smooth.

### 4. ui_panel_close — 面板关闭
- **音频路径**: `res://assets/audio/ui/panel_close.wav`
- **时长**: 0.15-0.3 秒
- **场景**: 面板关闭/收起
- **提示词**: Generate a panel close sound for a game UI. A descending soft whoosh, like a book gently closing. Slightly lower pitch than the open sound. Duration 150-300ms. Clean and final.

### 5. ui_purchase — 商店购买
- **音频路径**: `res://assets/audio/ui/purchase.wav`
- **时长**: 0.3-0.5 秒
- **场景**: 玩家在波次间商店中花费金币购买物品
- **提示词**: Generate a satisfying purchase/transaction sound for a game shop. Coin clink followed by a bright ascending chime, like gold coins dropping into a register then a magical confirmation sparkle. Duration 300-500ms. Should feel rewarding.

### 6. ui_upgrade_select — 升级选择确认
- **音频路径**: `res://assets/audio/ui/upgrade_select.wav`
- **时长**: 0.3-0.5 秒
- **场景**: 玩家从宝箱中选择一个升级属性
- **提示词**: Generate an upgrade selection confirmation sound for a roguelike game. A bright, ascending three-note chime with a subtle power-up shimmer. Should feel like unlocking potential. Duration 300-500ms. Positive and empowering.

### 7. ui_error — 无效操作/错误提示
- **音频路径**: `res://assets/audio/ui/error.wav`
- **时长**: 0.2-0.3 秒
- **场景**: 金币不足、操作无效、冷却中等错误提示
- **提示词**: Generate a gentle error/rejection sound for a game UI. A low, dull buzz or two-note descending tone. Not harsh or annoying, but clearly communicates "no". Duration 200-300ms. Think of a soft wooden thud with a slight electronic buzz.

### 8. ui_pause — 游戏暂停
- **音频路径**: `res://assets/audio/ui/pause.wav`
- **时长**: 0.3-0.5 秒
- **场景**: 玩家按下暂停键，游戏冻结
- **提示词**: Generate a game pause sound effect. A descending tone that feels like time slowing down, with a subtle reverb tail. Like a record player slowing to a stop but digital. Duration 300-500ms. Atmospheric and calm.

### 9. ui_resume — 游戏恢复
- **音频路径**: `res://assets/audio/ui/resume.wav`
- **时长**: 0.2-0.4 秒
- **场景**: 玩家从暂停状态恢复游戏
- **提示词**: Generate a game resume/unpause sound. An ascending tone that feels like time speeding back up, the reverse of a pause sound. Quick and energetic. Duration 200-400ms. Should feel like jumping back into action.

### 10. ui_game_start — 游戏开始
- **音频路径**: `res://assets/audio/ui/game_start.wav`
- **时长**: 0.5-1.0 秒
- **场景**: 从角色选择进入战斗场景
- **提示词**: Generate a game start sound for a roguelike action game. A dramatic ascending fanfare with a powerful impact at the peak, like a battle horn mixed with digital energy. Duration 500ms-1s. Epic but concise. Should pump up the player.

### 11. ui_char_select — 角色选择确认
- **音频路径**: `res://assets/audio/ui/char_select.wav`
- **时长**: 0.3-0.5 秒
- **场景**: 玩家在角色选择界面确认选中一个角色加入小队
- **提示词**: Generate a character selection confirmation sound for a game. A bright, decisive stamp or lock-in sound with a subtle magical shimmer. Like a seal being pressed. Duration 300-500ms. Confident and satisfying.

### 12. ui_tab_switch — 标签切换
- **音频路径**: `res://assets/audio/ui/tab_switch.wav`
- **时长**: 0.05-0.1 秒
- **场景**: 在 UI 中切换标签页
- **提示词**: Generate a quick tab switch sound for a game UI. A light, crisp tick with a slight pitch shift, like flipping a page. Duration 50-100ms. Minimal and clean.


---

## 二、玩家/角色音效

### 13. player_hurt — 玩家受击
- **音频路径**: `res://assets/audio/player/hurt.wav`
- **时长**: 0.15-0.3 秒
- **场景**: 玩家角色被敌人攻击命中，扣血
- **提示词**: Generate a player hurt sound for a 2D roguelike game. A short, punchy impact with a slight vocal grunt undertone. Not too painful sounding, more like a cartoon hit. Duration 150-300ms. Should feel impactful but not distressing.

### 14. player_armor_break — 护甲破碎
- **音频路径**: `res://assets/audio/player/armor_break.wav`
- **时长**: 0.3-0.5 秒
- **场景**: 玩家最后一点护甲被击破，进入无甲状态
- **提示词**: Generate an armor breaking/shattering sound for a game. Glass or crystal cracking and shattering with metallic undertones. More dramatic than a regular hit. Duration 300-500ms. Should feel like a protective barrier just shattered.

### 15. player_death — 玩家死亡（已有 glass_shatter.wav）
- **音频路径**: `res://assets/audio/glass_shatter.wav`
- **保留现有文件**: `assets/audio/glass_shatter.wav`
- **无需生成**

### 16. player_dash — 玩家冲刺（已有 dash.wav）
- **音频路径**: `res://assets/audio/dash.wav`
- **保留现有文件**: `assets/audio/dash.wav`
- **无需生成**

### 17. player_energy_gain — 能量获取
- **音频路径**: `res://assets/audio/player/energy_gain.wav`
- **时长**: 0.1-0.2 秒
- **场景**: 击杀敌人后获得能量，能量条增长。高频触发（每次击杀）
- **提示词**: Generate a quick energy pickup sound for a game. A short, bright ascending sparkle or shimmer, like absorbing a small light orb. Very brief and non-intrusive since it triggers frequently. Duration 100-200ms. Subtle but satisfying.

### 18. player_energy_low — 能量不足
- **音频路径**: `res://assets/audio/player/energy_low.wav`
- **时长**: 0.2-0.3 秒
- **场景**: 玩家尝试施放技能但能量不足
- **提示词**: Generate an energy depleted/insufficient sound for a game. A hollow, descending electronic tone that sounds like power draining away. Like a battery dying sound but brief. Duration 200-300ms. Should clearly communicate "not enough power".

### 19. player_level_up — 升级
- **音频路径**: `res://assets/audio/player/level_up.wav`
- **时长**: 0.5-0.8 秒
- **场景**: 玩家经验值达到升级阈值，角色升级
- **提示词**: Generate a level up sound for a roguelike game. A bright, triumphant ascending arpeggio with a sparkling finish. Magical and celebratory but not overly long. Duration 500-800ms. Should feel like a moment of achievement.

### 20. gold_pickup — 金币拾取
- **音频路径**: `res://assets/audio/player/gold_pickup.wav`
- **时长**: 0.05-0.15 秒
- **场景**: 金币飞向玩家被拾取。极高频触发（大量敌人掉落金币）
- **提示词**: Generate a tiny coin pickup sound for a game. A single bright metallic clink or ting. Extremely short and light since hundreds may play in quick succession with pitch randomization. Duration 50-150ms. Think classic arcade coin but softer.

### 21. char_switch_success — 角色切换成功
- **音频路径**: `res://assets/audio/player/switch_success.wav`
- **时长**: 0.2-0.4 秒
- **场景**: 玩家按 1/2/3 键成功切换到另一个角色
- **提示词**: Generate a character switch sound for a squad-based game. A quick whoosh with a magical transformation sparkle, like teleporting and reforming. Duration 200-400ms. Should feel swift and decisive.

### 22. char_switch_fail — 角色切换失败
- **音频路径**: `res://assets/audio/player/switch_fail.wav`
- **时长**: 0.15-0.25 秒
- **场景**: 玩家尝试切换角色但处于冷却中或目标角色已死亡
- **提示词**: Generate a failed action/cooldown sound for a game. A short, muffled buzz or blocked sound, like hitting an invisible wall. Duration 150-250ms. Not harsh, just a clear "not available" signal.

### 23. super_armor_trigger — 超级护甲触发
- **音频路径**: `res://assets/audio/player/super_armor.wav`
- **时长**: 0.2-0.4 秒
- **场景**: 玩家在画线时被击中，超级护甲羁绊触发免疫击退
- **提示词**: Generate a super armor activation sound for a game. A solid, resonant metallic shield impact with a brief energy pulse. Like an invisible force field absorbing a hit. Duration 200-400ms. Should feel powerful and protective.


---

## 三、战斗音效

### 24. enemy_hit — 敌人受击（已有 EnemyHit.wav）
- **音频路径**: `res://assets/audio/EnemyHit.wav`
- **保留现有文件**: `assets/audio/EnemyHit.wav`
- **无需生成**

### 25. enemy_death — 敌人死亡（已有 pop_squish.wav）
- **音频路径**: `res://assets/audio/pop_squish.wav`
- **保留现有文件**: `assets/audio/pop_squish.wav`
- **无需生成**

### 26. enemy_charge_warning — 冲锋预警
- **音频路径**: `res://assets/audio/combat/charge_warning.wav`
- **时长**: 0.5-0.8 秒
- **场景**: 刺猬型敌人锁定玩家，显示红色预警线，身体颤抖蓄力
- **提示词**: Generate a charge warning sound for a game enemy. A rising tension tone that builds urgency, like a low growl escalating into a high-pitched whine. Think of a bull scraping the ground before charging. Duration 500-800ms. Should create a sense of impending danger.

### 27. enemy_charge — 冲锋
- **音频路径**: `res://assets/audio/combat/charge.wav`
- **时长**: 0.3-0.5 秒
- **场景**: 敌人蓄力完成，沿直线高速冲锋
- **提示词**: Generate an enemy charge/rush sound for a 2D game. A powerful, fast whoosh with a heavy impact undertone, like a battering ram launching forward. Duration 300-500ms. Should feel fast, heavy, and dangerous.

### 28. crit_hit — 暴击
- **音频路径**: `res://assets/audio/combat/crit_hit.wav`
- **时长**: 0.2-0.4 秒
- **场景**: 玩家攻击触发暴击，造成双倍伤害
- **提示词**: Generate a critical hit sound for a roguelike game. A sharp, powerful impact with a bright flash-like accent on top. More dramatic and punchy than a regular hit. Like a thunderclap mixed with breaking glass. Duration 200-400ms. Should feel devastating and satisfying.

### 29. loop_kill — 闭环绞杀（已有 magic_chord.wav）
- **音频路径**: `res://assets/audio/magic_chord.wav`
- **保留现有文件**: `assets/audio/magic_chord.wav`
- **无需生成**

### 30. player_explosion — 爆炸（已有 magical_explosion.wav）
- **音频路径**: `res://assets/audio/magical_explosion.wav`
- **保留现有文件**: `assets/audio/magical_explosion.wav`
- **无需生成**

### 31. debuff_burn — 燃烧异常状态
- **音频路径**: `res://assets/audio/combat/debuff_burn.wav`
- **时长**: 0.3-0.5 秒
- **场景**: 敌人被施加燃烧状态，持续掉血，身上出现火焰效果
- **提示词**: Generate a fire/burn debuff application sound for a game. A quick ignition whoosh followed by crackling flames. Like a match striking and a small fire erupting. Duration 300-500ms. Warm, aggressive, clearly "fire".

### 32. debuff_curse — 诅咒异常状态
- **音频路径**: `res://assets/audio/combat/debuff_curse.wav`
- **时长**: 0.3-0.5 秒
- **场景**: 敌人被施加诅咒状态，可叠加层数，持续受到暗属性伤害
- **提示词**: Generate a dark curse debuff sound for a game. A sinister, low-pitched ethereal whisper with a subtle dark magic pulse. Like shadows wrapping around something. Duration 300-500ms. Ominous and mystical, purple/dark energy feeling.

### 33. debuff_poison — 中毒异常状态
- **音频路径**: `res://assets/audio/combat/debuff_poison.wav`
- **时长**: 0.3-0.5 秒
- **场景**: 敌人被施加中毒状态，可叠加层数，持续受到毒素伤害
- **提示词**: Generate a poison debuff application sound for a game. A wet, bubbling hiss like acid dripping, with a sickly squelch. Duration 300-500ms. Should feel toxic and corrosive, green slime energy.

### 34. debuff_slow — 减速异常状态
- **音频路径**: `res://assets/audio/combat/debuff_slow.wav`
- **时长**: 0.3-0.5 秒
- **场景**: 敌人被施加减速状态，移动速度大幅降低
- **提示词**: Generate a slow/debuff application sound for a game. A descending, stretching tone like time being pulled apart, with a heavy, sluggish quality. Like moving through thick honey. Duration 300-500ms. Should feel heavy and dragging.

### 35. debuff_freeze — 冰冻异常状态
- **音频路径**: `res://assets/audio/combat/debuff_freeze.wav`
- **时长**: 0.3-0.5 秒
- **场景**: 敌人被施加冰冻状态，完全无法移动
- **提示词**: Generate an ice freeze debuff sound for a game. A sharp crystallization crack followed by a brief icy shimmer. Like water instantly freezing into ice. Duration 300-500ms. Cold, crisp, and sudden. Think ice forming rapidly.

### 36. debuff_stun — 眩晕异常状态
- **音频路径**: `res://assets/audio/combat/debuff_stun.wav`
- **时长**: 0.3-0.5 秒
- **场景**: 敌人被施加眩晕状态，完全无法移动（类似冰冻但视觉不同）
- **提示词**: Generate a stun debuff sound for a game. A sharp impact followed by cartoon-style stars-circling-head ringing. A bell-like tone with slight wobble. Duration 300-500ms. Should feel disorienting, like getting bonked on the head.

### 37. poison_pool_spawn — 毒池生成
- **音频路径**: `res://assets/audio/combat/poison_pool.wav`
- **时长**: 0.4-0.6 秒
- **场景**: 地雷怪死亡后在地面留下一个绿色毒池区域，持续伤害踩入的玩家
- **提示词**: Generate a poison pool spawning sound for a game. A wet, spreading splash followed by continuous bubbling. Like toxic sludge spreading across the ground. Duration 400-600ms. Should feel dangerous and disgusting, green toxic waste energy.


---

## 四、技能音效

### 38. skill_q_planning — Q 技能规划模式进入（子弹时间）
- **音频路径**: `res://assets/audio/skill/q_planning.wav`
- **时长**: 0.3-0.6 秒
- **场景**: 玩家按住 Q 键，游戏进入 0.1x 慢动作，屏幕出现规划线条。时间仿佛凝固
- **提示词**: Generate a bullet-time activation sound for a drawing-based skill system. A deep, resonant time-dilation effect — like reality stretching and slowing down. A low bass drop followed by a sustained ethereal hum. Duration 300-600ms. Should feel like entering a focused, time-frozen state.

### 39. skill_q_draw_start — 画线开始
- **音频路径**: `res://assets/audio/skill/q_draw_start.wav`
- **时长**: 0.1-0.2 秒
- **场景**: 在规划模式中，玩家按下鼠标左键开始画线，墨水/能量线条从鼠标位置开始延伸
- **提示词**: Generate a drawing/ink start sound for a game skill. A quick, smooth brush stroke initiation — like a calligraphy pen touching paper with a slight magical sparkle. Duration 100-200ms. Elegant and fluid, ink-on-paper feeling.

### 40. skill_q_closure_detected — 闭合检测提示
- **音频路径**: `res://assets/audio/skill/q_closure_detected.wav`
- **时长**: 0.15-0.3 秒
- **场景**: 画线过程中，线条首尾接近形成闭合区域，线条颜色变红提示玩家
- **提示词**: Generate a shape closure detection sound for a drawing skill. A bright, ascending notification chime that says "you've completed a shape". Like a puzzle piece clicking into place with a magical resonance. Duration 150-300ms. Satisfying and encouraging.

### 41. skill_q_closure_generic — Q 闭合执行（通用）
- **音频路径**: `res://assets/audio/skill/q_closure_generic.wav`
- **时长**: 0.4-0.7 秒
- **场景**: 玩家松开 Q 键，闭合区域内的所有敌人受到范围伤害。这是核心战斗机制的高潮时刻
- **提示词**: Generate a powerful area-of-effect execution sound for a drawing-based skill in a roguelike game. A dramatic magical detonation — energy gathering inward then exploding outward. Like an ink bomb detonating inside a drawn circle. Duration 400-700ms. Should feel climactic, powerful, and deeply satisfying. This is the core gameplay payoff moment.

### 42. skill_q_open_execute — Q 开放路径执行
- **音频路径**: `res://assets/audio/skill/q_open_execute.wav`
- **时长**: 0.3-0.5 秒
- **场景**: 玩家松开 Q 键但线条未闭合，生成墙体/线段效果阻挡敌人
- **提示词**: Generate a wall/barrier creation sound for a drawing skill. A solid, sweeping materialization effect — like ink solidifying into a physical wall. Duration 300-500ms. Should feel constructive and solid, less dramatic than the closure sound.

### 43. skill_q_energy_depleted — 画线能量耗尽
- **音频路径**: `res://assets/audio/skill/q_energy_depleted.wav`
- **时长**: 0.2-0.3 秒
- **场景**: 画线过程中能量耗尽，无法继续画线，显示 "No Energy!" 文字
- **提示词**: Generate an energy depleted sound for a game skill. A fading, sputtering tone like a pen running out of ink or a battery dying. Descending and hollow. Duration 200-300ms. Should clearly communicate "power ran out".

### 44. skill_e_instant — E 技能瞬发
- **音频路径**: `res://assets/audio/skill/e_instant.wav`
- **时长**: 0.2-0.4 秒
- **场景**: 玩家按 E 键施放瞬发型技能（如冲刺、传送、召唤等）
- **提示词**: Generate a quick instant-cast skill sound for a game. A sharp, decisive magical burst — like snapping fingers and releasing energy. Quick and punchy. Duration 200-400ms. Should feel responsive and immediate.

### 45. skill_e_aoe — E 技能 AOE
- **音频路径**: `res://assets/audio/skill/e_aoe.wav`
- **时长**: 0.3-0.6 秒
- **场景**: 玩家按 E 键施放范围型技能（如爆炸、冰冻区域、毒雾等）
- **提示词**: Generate an area-of-effect skill activation sound for a game. A spreading magical wave expanding outward from a center point. Like a shockwave rippling through the air. Duration 300-600ms. Should feel expansive and impactful.

### 46. skill_ult_activate — 终极技能激活（F 键）
- **音频路径**: `res://assets/audio/skill/ult_activate.wav`
- **时长**: 0.5-1.0 秒
- **场景**: 玩家按 F 键激活终极技能，角色进入强化状态，武器附加爆炸效果
- **提示词**: Generate an ultimate skill activation sound for a roguelike game. A dramatic, powerful transformation effect — building energy followed by a massive release. Like a supernova igniting. Duration 500ms-1s. Should feel epic, rare, and game-changing. The most dramatic skill sound in the game.

### 47. skill_ult_deactivate — 终极技能结束
- **音频路径**: `res://assets/audio/skill/ult_deactivate.wav`
- **时长**: 0.3-0.5 秒
- **场景**: 终极技能持续时间结束，角色恢复普通状态
- **提示词**: Generate an ultimate skill deactivation/expiry sound for a game. A descending power-down effect, like energy dissipating and returning to normal. The reverse feeling of activation but gentler. Duration 300-500ms. Should feel like coming down from a power high.


---

## 五、羁绊/机制音效

### 48. bond_trigger_generic — 通用羁绊触发
- **音频路径**: `res://assets/audio/environment/bond_generic.wav`
- **时长**: 0.2-0.4 秒
- **场景**: 任意羁绊机制触发时的通用音效（如 debuff 延长、速度转伤害、图形继承等）
- **提示词**: Generate a generic bond/synergy trigger sound for a game. A brief magical resonance pulse, like two energies connecting and amplifying each other. A subtle but noticeable harmonic chime. Duration 200-400ms. Should feel like a passive bonus activating.

### 49. bond_chain_reaction — 连锁反应（爆破师 Lv.3）
- **音频路径**: `res://assets/audio/environment/bond_chain.wav`
- **时长**: 0.4-0.7 秒
- **场景**: 闭合区域爆炸后，区域外的所有敌人也受到 30% 连锁伤害，产生小爆炸特效
- **提示词**: Generate a chain reaction explosion sound for a game. A primary explosion followed by rapid cascading secondary detonations spreading outward. Like dominoes of explosions. Duration 400-700ms. Should feel like destruction spreading uncontrollably. Chaotic and powerful.

### 50. bond_permanent_cage — 永久牢笼（筑墙者 Lv.3）
- **音频路径**: `res://assets/audio/environment/bond_cage.wav`
- **时长**: 0.4-0.6 秒
- **场景**: 闭合区域变成永久物理墙体，阻挡敌人移动，发出蓝色光芒
- **提示词**: Generate a cage/prison materialization sound for a game. Heavy metallic bars or crystal walls solidifying into place with a resonant locking sound. Like a magical prison forming around enemies. Duration 400-600ms. Should feel solid, permanent, and imprisoning. Blue energy feeling.

### 51. bond_soul_attach — 灵魂附着计数（灵魂附着羁绊）
- **音频路径**: `res://assets/audio/environment/bond_soul.wav`
- **时长**: 0.2-0.4 秒
- **场景**: 玩家受击时触发灵魂附着反击，对附近敌人造成伤害
- **提示词**: Generate a soul/spirit counter-attack sound for a game. A ghostly, ethereal pulse emanating outward — like a spectral shockwave. Haunting but powerful. Duration 200-400ms. Should feel supernatural and retaliatory. Purple/ghost energy.

### 52. bond_gold_trail — 金币轨迹（炼金术士羁绊）
- **音频路径**: `res://assets/audio/environment/bond_gold.wav`
- **时长**: 0.1-0.2 秒
- **场景**: 画线过程中每隔一段距离自动生成金币，金币从线条上掉落
- **提示词**: Generate a gold coin spawning/dropping sound for a game. A quick, bright metallic sparkle with a tiny coin drop. Very short since it triggers frequently during drawing. Duration 100-200ms. Should feel like treasure materializing from thin air.

### 53. bond_thorns_wall — 反伤墙（筑墙者 Lv.2）
- **音频路径**: `res://assets/audio/environment/bond_thorns.wav`
- **时长**: 0.2-0.3 秒
- **场景**: 敌人碰到玩家画的线段墙体时受到反伤，显示 "THORNS!" 文字
- **提示词**: Generate a thorns/reflect damage sound for a game. A sharp, prickly impact — like hitting a cactus or barbed wire. A quick stinging sound with a slight metallic ring. Duration 200-300ms. Should feel painful for the attacker, defensive and spiky.

### 54. bond_small_shape_crit — 小图形暴击（几何学家 Lv.2）
- **音频路径**: `res://assets/audio/environment/bond_crit.wav`
- **时长**: 0.3-0.5 秒
- **场景**: 玩家画出面积小于阈值的闭合图形，触发双倍伤害暴击，显示 "CRITICAL!" 文字
- **提示词**: Generate a precision critical hit sound for a game. A sharp, focused energy burst — like a laser concentrating into a tiny point then exploding. More precise and surgical than a regular crit. Duration 300-500ms. Should feel like rewarding skillful, precise play. Geometric/mathematical energy.


---

## 六、环境/游戏状态音效

### 55. wave_start — 波次开始
- **音频路径**: `res://assets/audio/environment/wave_start.wav`
- **时长**: 0.5-0.8 秒
- **场景**: 新一波敌人开始涌入战场，屏幕显示波次编号
- **提示词**: Generate a wave start sound for a roguelike survival game. A dramatic war horn or battle drum hit that signals incoming enemies. Urgent and alerting. Duration 500-800ms. Should feel like "enemies are coming, get ready!" Tension-building.

### 56. wave_complete — 波次完成
- **音频路径**: `res://assets/audio/environment/wave_complete.wav`
- **时长**: 0.5-0.8 秒
- **场景**: 所有敌人被消灭，波次结束，即将进入商店阶段
- **提示词**: Generate a wave complete/victory sound for a roguelike game. A triumphant, relieving fanfare — like a brief moment of peace after battle. Ascending chords with a satisfying resolution. Duration 500-800ms. Should feel like "you survived, take a breath."

### 57. shop_open — 商店开启
- **音频路径**: `res://assets/audio/environment/shop_open.wav`
- **时长**: 0.3-0.5 秒
- **场景**: 波次结束后商店界面滑入，展示可购买的物品
- **提示词**: Generate a shop opening sound for a game. A welcoming, warm chime with a slight cash register undertone. Like a magical merchant's tent flap opening. Duration 300-500ms. Should feel inviting and commercial, a moment of respite.

### 58. shop_close — 商店关闭
- **音频路径**: `res://assets/audio/environment/shop_close.wav`
- **时长**: 0.2-0.4 秒
- **场景**: 玩家点击"下一波"按钮，商店关闭，准备进入下一波战斗
- **提示词**: Generate a shop closing sound for a game. A decisive closing sound with a slight urgency — like shutting a book and picking up your weapon. Duration 200-400ms. Should feel like "shopping's over, back to battle."

### 59. chest_spawn — 宝箱出现
- **音频路径**: `res://assets/audio/environment/chest_spawn.wav`
- **时长**: 0.3-0.5 秒
- **场景**: 战斗中宝箱在场景中生成，发出光芒吸引玩家
- **提示词**: Generate a treasure chest appearing/spawning sound for a game. A magical materialization with a sparkling shimmer — like a gift from the heavens landing on the ground. Duration 300-500ms. Should feel exciting and mysterious, "something good just appeared!"

### 60. chest_open — 宝箱打开
- **音频路径**: `res://assets/audio/environment/chest_open.wav`
- **时长**: 0.4-0.7 秒
- **场景**: 玩家靠近宝箱触发打开，显示升级选项
- **提示词**: Generate a treasure chest opening sound for a roguelike game. A creaking lid opening followed by a burst of magical light and sparkles. Like opening a music box mixed with discovering treasure. Duration 400-700ms. Should feel rewarding and full of possibility.

### 61. game_over — 游戏结束
- **音频路径**: `res://assets/audio/environment/game_over.wav`
- **时长**: 0.8-1.5 秒
- **场景**: 所有角色死亡，游戏结束，显示结算界面
- **提示词**: Generate a game over sound for a roguelike game. A somber, descending tone that fades into silence. Not overly dramatic or depressing — this is a roguelike, death is expected. A melancholic but dignified ending. Duration 800ms-1.5s. Should feel like "that run is over" without being devastating.

---

## 七、每角色 Q 闭合专属音效

以下为 27 个角色的 Q 技能闭合执行专属音效。每个角色的闭合音效应反映其角色主题和战斗风格。

### 通用参数
- **时长**: 0.4-0.7 秒
- **格式**: WAV, 44100Hz, 16-bit, Mono
- **场景**: 玩家画线形成闭合区域后松开 Q 键，闭合区域内敌人受到范围伤害。这是每个角色最具辨识度的音效

### 62. butcher（屠夫）— 近战肉盾
- **音频路径**: `res://assets/audio/skill/q_closure/butcher.wav`
- **提示词**: Generate a heavy butcher's cleaver slam sound for a game skill. A massive, meaty impact — like a giant blade chopping through flesh and bone. Heavy, brutal, and satisfying. Duration 400-700ms. Red/blood energy. Think of a butcher's shop but magical.

### 63. pyro（火焰）— 高爆发 AOE
- **音频路径**: `res://assets/audio/skill/q_closure/pyro.wav`
- **提示词**: Generate a fire explosion closure sound for a game skill. A roaring fireball detonation — flames rushing inward then erupting outward. Intense heat and crackling fire. Duration 400-700ms. Orange/red fire energy. Should feel like a contained inferno exploding.

### 64. weaver（织网）— 持续控制减速
- **音频路径**: `res://assets/audio/skill/q_closure/weaver.wav`
- **提示词**: Generate a web/thread entanglement closure sound for a game skill. Silk threads tightening and snapping with a sticky, constricting quality. Like a spider web closing around prey. Duration 400-700ms. Purple/silver thread energy. Should feel trapping and suffocating.

### 65. herder（牧羊人）— 召唤/群体控制
- **音频路径**: `res://assets/audio/skill/q_closure/herder.wav`
- **提示词**: Generate a herding/corralling closure sound for a game skill. A commanding whistle followed by a stampede-like rumble. Like calling a pack of wolves to surround prey. Duration 400-700ms. Green/nature energy. Should feel like nature obeying a command.

### 66. tesla（特斯拉）— 电击/连锁闪电
- **音频路径**: `res://assets/audio/skill/q_closure/tesla.wav`
- **提示词**: Generate an electric/tesla coil closure sound for a game skill. Crackling electricity arcing and zapping with a powerful discharge. Like a lightning bolt striking inside a contained area. Duration 400-700ms. Blue/white electric energy. Should feel shocking and electrifying.

### 67. glacier（冰川）— 冰冻/区域控制
- **音频路径**: `res://assets/audio/skill/q_closure/glacier.wav`
- **提示词**: Generate an ice/glacier closure sound for a game skill. Rapid crystallization and freezing — ice cracking and forming with a deep cold resonance. Like flash-freezing everything in an area. Duration 400-700ms. Light blue/white ice energy. Should feel cold, sharp, and absolute.

### 68. voodoo（巫毒）— 诅咒/暗属性
- **音频路径**: `res://assets/audio/skill/q_closure/voodoo.wav`
- **提示词**: Generate a voodoo/dark magic closure sound for a game skill. Eerie chanting whispers with a dark magical pulse. Like dark spirits being summoned to curse everything in an area. Duration 400-700ms. Dark purple/black energy. Should feel sinister and supernatural.

### 69. blacksmith（铁匠）— 锻造/金属
- **音频路径**: `res://assets/audio/skill/q_closure/blacksmith.wav`
- **提示词**: Generate a blacksmith's forge closure sound for a game skill. A massive hammer strike on an anvil with sparks flying, followed by a metallic ring. Like forging a weapon in one powerful blow. Duration 400-700ms. Orange/metal energy. Should feel industrial and powerful.

### 70. banner（旗手）— 鼓舞/增益
- **音频路径**: `res://assets/audio/skill/q_closure/banner.wav`
- **提示词**: Generate a battle banner/rally closure sound for a game skill. A triumphant horn blast with a flag unfurling in wind. Like planting a war banner that inspires allies. Duration 400-700ms. Gold/white energy. Should feel inspiring and commanding.

### 71. plague（瘟疫）— 毒素/疾病
- **音频路径**: `res://assets/audio/skill/q_closure/plague.wav`
- **提示词**: Generate a plague/disease closure sound for a game skill. Sickly bubbling and hissing with toxic gas spreading. Like a plague cloud engulfing an area. Duration 400-700ms. Green/yellow toxic energy. Should feel infectious and nauseating.

### 72. wind（疾风）— 高机动切割
- **音频路径**: `res://assets/audio/skill/q_closure/wind.wav`
- **提示词**: Generate a unique closure execution sound for the Wind character in a 2D roguelike game. The character's theme is high mobility and cutting wind blades. The sound should play when the player draws a closed shape that damages all enemies inside. Duration 400-700ms. A sharp, slicing wind gust with a cutting edge. Should feel swift and razor-sharp.

### 73. sapper（工兵）— 阵地建设/资源
- **音频路径**: `res://assets/audio/skill/q_closure/sapper.wav`
- **提示词**: Generate a unique closure execution sound for the Sapper/Engineer character in a 2D roguelike game. The character's theme is fortification building and resource management. Duration 400-700ms. Mechanical construction sounds with riveting and welding sparks. Should feel industrious and tactical.

### 74. new_pyro（新火法）— 火墙与火海
- **音频路径**: `res://assets/audio/skill/q_closure/new_pyro.wav`
- **提示词**: Generate a unique closure execution sound for the New Pyromancer character in a 2D roguelike game. The character's theme is fire walls and seas of flame. Duration 400-700ms. A deep, roaring inferno with spreading flames and intense heat. Should feel like an ocean of fire engulfing the area.

### 75. jailer（狱警）— 电网与封锁
- **音频路径**: `res://assets/audio/skill/q_closure/jailer.wav`
- **提示词**: Generate a unique closure execution sound for the Jailer character in a 2D roguelike game. The character's theme is electric nets and lockdown. Duration 400-700ms. Crackling electric fence activation with a heavy metallic lock sound. Should feel imprisoning and electrified.

### 76. new_tempest（新风暴）— 风带与台风眼
- **音频路径**: `res://assets/audio/skill/q_closure/new_tempest.wav`
- **提示词**: Generate a unique closure execution sound for the New Tempest character in a 2D roguelike game. The character's theme is wind bands and typhoon eyes. Duration 400-700ms. A swirling vortex of wind building into a powerful cyclone. Should feel like being in the eye of a storm.

### 77. medic（军医）— 治疗与吸血
- **音频路径**: `res://assets/audio/skill/q_closure/medic.wav`
- **提示词**: Generate a unique closure execution sound for the Medic character in a 2D roguelike game. The character's theme is healing and life drain. Duration 400-700ms. A warm, pulsing healing aura with a subtle life-siphoning undertone. Should feel restorative yet slightly vampiric.

### 78. ammo（弹药）— 弹药补给
- **音频路径**: `res://assets/audio/skill/q_closure/ammo.wav`
- **提示词**: Generate a unique closure execution sound for the Ammo character in a 2D roguelike game. The character's theme is ammunition supply and explosive ordnance. Duration 400-700ms. Rapid bullet casings dropping with a magazine loading click and explosive charge. Should feel like arming up for war.

### 79. paladin（圣骑士）— 光墙与嘲讽
- **音频路径**: `res://assets/audio/skill/q_closure/paladin.wav`
- **提示词**: Generate a unique closure execution sound for the Paladin character in a 2D roguelike game. The character's theme is holy light walls and taunting. Duration 400-700ms. A radiant holy light burst with a deep, commanding voice-like resonance. Should feel righteous and protective. Golden/white energy.

### 80. vampire（血族）— 血路与吸血
- **音频路径**: `res://assets/audio/skill/q_closure/vampire.wav`
- **提示词**: Generate a unique closure execution sound for the Vampire character in a 2D roguelike game. The character's theme is blood paths and life drain. Duration 400-700ms. A dark, wet blood-rushing sound with a heartbeat pulse and draining effect. Should feel predatory and dark. Crimson/dark red energy.

### 81. train（火车王）— 冲击波与致盲
- **音频路径**: `res://assets/audio/skill/q_closure/train.wav`
- **提示词**: Generate a unique closure execution sound for the Train King character in a 2D roguelike game. The character's theme is shockwaves and blinding impacts. Duration 400-700ms. A massive locomotive-like impact with a blinding flash sound. Should feel unstoppable and overwhelming.

### 82. swarm（虫母）— 虫群召唤
- **音频路径**: `res://assets/audio/skill/q_closure/swarm.wav`
- **提示词**: Generate a unique closure execution sound for the Swarm Mother character in a 2D roguelike game. The character's theme is insect swarm summoning. Duration 400-700ms. A buzzing, chittering swarm of insects erupting and spreading. Should feel creepy and overwhelming. Green/brown insect energy.

### 83. new_totem（萨满）— 图腾与闪电
- **音频路径**: `res://assets/audio/skill/q_closure/new_totem.wav`
- **提示词**: Generate a unique closure execution sound for the Shaman/Totem character in a 2D roguelike game. The character's theme is totems and lightning. Duration 400-700ms. A tribal drum beat followed by a totem activation pulse and lightning strike. Should feel primal and mystical.

### 84. turret_eng（工程）— 炮塔部署
- **音频路径**: `res://assets/audio/skill/q_closure/turret_eng.wav`
- **提示词**: Generate a unique closure execution sound for the Turret Engineer character in a 2D roguelike game. The character's theme is turret deployment and automated fire. Duration 400-700ms. Mechanical turret assembly sounds with a targeting lock beep and first shot. Should feel precise and technological.

### 85. goo（软泥）— 胶水与吞噬
- **音频路径**: `res://assets/audio/skill/q_closure/goo.wav`
- **提示词**: Generate a unique closure execution sound for the Goo/Slime character in a 2D roguelike game. The character's theme is sticky glue and devouring. Duration 400-700ms. A wet, squelching blob spreading and engulfing with a sticky, viscous quality. Should feel gross and suffocating. Green slime energy.

### 86. necro（死灵）— 骨墙与恐惧
- **音频路径**: `res://assets/audio/skill/q_closure/necro.wav`
- **提示词**: Generate a unique closure execution sound for the Necromancer character in a 2D roguelike game. The character's theme is bone walls and fear. Duration 400-700ms. Bones rattling and assembling with a terrifying ghostly wail. Should feel deathly and horrifying. Dark/bone white energy.

### 87. illusionist（魔术师）— 镜面与幻影
- **音频路径**: `res://assets/audio/skill/q_closure/illusionist.wav`
- **提示词**: Generate a unique closure execution sound for the Illusionist character in a 2D roguelike game. The character's theme is mirrors and phantoms. Duration 400-700ms. A shimmering glass-like refraction sound with echoing duplications. Should feel disorienting and magical. Silver/mirror energy.

### 88. merchant（商人）— 金币加成与黑市
- **音频路径**: `res://assets/audio/skill/q_closure/merchant.wav`
- **提示词**: Generate a unique closure execution sound for the Merchant character in a 2D roguelike game. The character's theme is gold bonuses and black market deals. Duration 400-700ms. A cascade of gold coins with a cash register cha-ching and a sly magical undertone. Should feel profitable and cunning. Gold energy.

### 89. midas（炼金）— 石化与点金
- **音频路径**: `res://assets/audio/skill/q_closure/midas.wav`
- **提示词**: Generate a unique closure execution sound for the Midas/Alchemist character in a 2D roguelike game. The character's theme is petrification and golden touch. Duration 400-700ms. A crystallizing stone transformation followed by a golden shimmer. Should feel like everything turning to gold. Gold/stone energy.

### 90. vacuum（吸尘器）— 吸引与漩涡
- **音频路径**: `res://assets/audio/skill/q_closure/vacuum.wav`
- **提示词**: Generate a unique closure execution sound for the Vacuum character in a 2D roguelike game. The character's theme is attraction and vortex. Duration 400-700ms. A powerful suction whoosh pulling everything inward followed by a compressed implosion. Should feel like a black hole forming.

### 91. executioner（处刑人）— 处决与断头台
- **音频路径**: `res://assets/audio/skill/q_closure/executioner.wav`
- **提示词**: Generate a unique closure execution sound for the Executioner character in a 2D roguelike game. The character's theme is execution and guillotine. Duration 400-700ms. A heavy blade dropping with a decisive, final impact. Should feel brutal, judicial, and absolute. Dark red/steel energy.

### 92. gambler（赌徒）— 随机 Buff 与掷骰
- **音频路径**: `res://assets/audio/skill/q_closure/gambler.wav`
- **提示词**: Generate a unique closure execution sound for the Gambler character in a 2D roguelike game. The character's theme is random buffs and dice rolling. Duration 400-700ms. Dice rattling and rolling with a slot machine jackpot chime. Should feel lucky and unpredictable. Gold/rainbow energy.

### 93. hunter（猎人）— 陷阱与标记
- **音频路径**: `res://assets/audio/skill/q_closure/hunter.wav`
- **提示词**: Generate a unique closure execution sound for the Hunter character in a 2D roguelike game. The character's theme is traps and marking targets. Duration 400-700ms. A bear trap snapping shut with a predatory growl and target-lock ping. Should feel calculated and deadly. Green/brown nature energy.

---

## 附录：音效生成工具推荐

| 工具 | 用途 | 说明 |
|------|------|------|
| Suno AI | 音效生成 | 支持文本描述生成音效 |
| ElevenLabs Sound Effects | 音效生成 | 高质量 AI 音效生成 |
| Freesound.org | 音效素材库 | 免费音效素材，可作为基础素材混合 |
| Audacity | 后期处理 | 免费音频编辑，用于裁剪、调整、格式转换 |
| sfxr/jsfxr | 8-bit 音效 | 快速生成复古风格音效 |
| Bfxr | 游戏音效 | sfxr 增强版，更多参数控制 |

### 后期处理建议

1. 所有生成的音效统一转换为 WAV 44100Hz 16-bit Mono
2. 使用 Audacity 的"标准化"功能统一响度到 -16 LUFS
3. 裁剪多余的静音部分，确保音效开头无延迟
4. 对高频触发的音效（如 gold_pickup、energy_gain）额外降低音量 3-5dB
5. 对同一类别的音效保持一致的音色风格
