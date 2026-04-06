# AI 闊虫晥鐢熸垚鎻愮ず璇嶆枃妗?

## 鍏ㄥ眬璁惧畾

- **娓告垙绫诲瀷**: 2D 淇瑙?Roguelike 鍔ㄤ綔娓告垙
- **缇庢湳椋庢牸**: 鍍忕礌/鍗￠€氶鏍硷紝鑹插僵椴滄槑锛岃妭濂忓揩
- **闊虫晥椋庢牸**: 娓呰剢銆佹湁鍔涖€佺暐甯﹀崱閫氭劅锛岄伩鍏嶈繃浜庡啓瀹炪€傚亸鍚戝悎鎴愰煶鏁?+ 杞诲害 8-bit 椋庢牸娣峰悎
- **杈撳嚭鏍煎紡**: WAV, 44100Hz, 16-bit, 鍗曞０閬?(Mono)
- **鍝嶅害鏍囧噯**: -16 LUFS锛堟父鎴忛煶鏁堟爣鍑嗭級

---

## 涓€銆乁I 闊虫晥

### 1. ui_click 鈥?鎸夐挳鐐瑰嚮
- **闊抽璺緞**: `res://assets/audio/ui/click.wav`
- **鏃堕暱**: 0.05-0.1 绉?
- **鍦烘櫙**: 鐜╁鐐瑰嚮浠讳綍 UI 鎸夐挳锛堝紑濮嬫父鎴忋€佺‘璁ゃ€佽繑鍥炵瓑锛?
- **鎻愮ず璇?*: Generate a short, crisp UI button click sound for a 2D roguelike game. Bright, snappy, with a subtle digital pop. Think of a soft plastic button press with a tiny high-frequency sparkle at the end. Duration 50-100ms. Clean and satisfying.

### 2. ui_hover 鈥?鎸夐挳鎮仠
- **闊抽璺緞**: `res://assets/audio/ui/hover.wav`
- **鏃堕暱**: 0.03-0.05 绉?
- **鍦烘櫙**: 榧犳爣鎮仠鍦ㄦ寜閽笂鏃剁殑杞诲井鎻愮ず闊?
- **鎻愮ず璇?*: Generate a very subtle, soft UI hover sound for a 2D game menu. A gentle, airy tick or whisper-like tone. Much quieter and softer than a click. Duration 30-50ms. Should feel like a feather touching glass.

### 3. ui_panel_open 鈥?闈㈡澘鎵撳紑
- **闊抽璺緞**: `res://assets/audio/ui/panel_open.wav`
- **鏃堕暱**: 0.2-0.4 绉?
- **鍦烘櫙**: 鍟嗗簵闈㈡澘銆佸崌绾ч潰鏉裤€佽鑹查€夋嫨闈㈡澘婊戝叆鎵撳紑
- **鎻愮ず璇?*: Generate a smooth panel slide-open sound for a game UI. A rising whoosh with a soft chime at the end, like a magical scroll unrolling. Slightly ethereal. Duration 200-400ms. Should feel inviting and smooth.

### 4. ui_panel_close 鈥?闈㈡澘鍏抽棴
- **闊抽璺緞**: `res://assets/audio/ui/panel_close.wav`
- **鏃堕暱**: 0.15-0.3 绉?
- **鍦烘櫙**: 闈㈡澘鍏抽棴/鏀惰捣
- **鎻愮ず璇?*: Generate a panel close sound for a game UI. A descending soft whoosh, like a book gently closing. Slightly lower pitch than the open sound. Duration 150-300ms. Clean and final.

### 5. ui_purchase 鈥?鍟嗗簵璐拱
- **闊抽璺緞**: `res://assets/audio/ui/purchase.wav`
- **鏃堕暱**: 0.3-0.5 绉?
- **鍦烘櫙**: 鐜╁鍦ㄦ尝娆￠棿鍟嗗簵涓姳璐归噾甯佽喘涔扮墿鍝?
- **鎻愮ず璇?*: Generate a satisfying purchase/transaction sound for a game shop. Coin clink followed by a bright ascending chime, like gold coins dropping into a register then a magical confirmation sparkle. Duration 300-500ms. Should feel rewarding.

### 6. ui_upgrade_select 鈥?鍗囩骇閫夋嫨纭
- **闊抽璺緞**: `res://assets/audio/ui/upgrade_select.wav`
- **鏃堕暱**: 0.3-0.5 绉?
- **鍦烘櫙**: 鐜╁浠庡疂绠变腑閫夋嫨涓€涓崌绾у睘鎬?
- **鎻愮ず璇?*: Generate an upgrade selection confirmation sound for a roguelike game. A bright, ascending three-note chime with a subtle power-up shimmer. Should feel like unlocking potential. Duration 300-500ms. Positive and empowering.

### 7. ui_error 鈥?鏃犳晥鎿嶄綔/閿欒鎻愮ず
- **闊抽璺緞**: `res://assets/audio/ui/error.wav`
- **鏃堕暱**: 0.2-0.3 绉?
- **鍦烘櫙**: 閲戝竵涓嶈冻銆佹搷浣滄棤鏁堛€佸喎鍗翠腑绛夐敊璇彁绀?
- **鎻愮ず璇?*: Generate a gentle error/rejection sound for a game UI. A low, dull buzz or two-note descending tone. Not harsh or annoying, but clearly communicates "no". Duration 200-300ms. Think of a soft wooden thud with a slight electronic buzz.

### 8. ui_pause 鈥?娓告垙鏆傚仠
- **闊抽璺緞**: `res://assets/audio/ui/pause.wav`
- **鏃堕暱**: 0.3-0.5 绉?
- **鍦烘櫙**: 鐜╁鎸変笅鏆傚仠閿紝娓告垙鍐荤粨
- **鎻愮ず璇?*: Generate a game pause sound effect. A descending tone that feels like time slowing down, with a subtle reverb tail. Like a record player slowing to a stop but digital. Duration 300-500ms. Atmospheric and calm.

### 9. ui_resume 鈥?娓告垙鎭㈠
- **闊抽璺緞**: `res://assets/audio/ui/resume.wav`
- **鏃堕暱**: 0.2-0.4 绉?
- **鍦烘櫙**: 鐜╁浠庢殏鍋滅姸鎬佹仮澶嶆父鎴?
- **鎻愮ず璇?*: Generate a game resume/unpause sound. An ascending tone that feels like time speeding back up, the reverse of a pause sound. Quick and energetic. Duration 200-400ms. Should feel like jumping back into action.

### 10. ui_game_start 鈥?娓告垙寮€濮?
- **闊抽璺緞**: `res://assets/audio/ui/game_start.wav`
- **鏃堕暱**: 0.5-1.0 绉?
- **鍦烘櫙**: 浠庤鑹查€夋嫨杩涘叆鎴樻枟鍦烘櫙
- **鎻愮ず璇?*: Generate a game start sound for a roguelike action game. A dramatic ascending fanfare with a powerful impact at the peak, like a battle horn mixed with digital energy. Duration 500ms-1s. Epic but concise. Should pump up the player.

### 11. ui_char_select 鈥?瑙掕壊閫夋嫨纭
- **闊抽璺緞**: `res://assets/audio/ui/char_select.wav`
- **鏃堕暱**: 0.3-0.5 绉?
- **鍦烘櫙**: 鐜╁鍦ㄨ鑹查€夋嫨鐣岄潰纭閫変腑涓€涓鑹插姞鍏ュ皬闃?
- **鎻愮ず璇?*: Generate a character selection confirmation sound for a game. A bright, decisive stamp or lock-in sound with a subtle magical shimmer. Like a seal being pressed. Duration 300-500ms. Confident and satisfying.

### 12. ui_tab_switch 鈥?鏍囩鍒囨崲
- **闊抽璺緞**: `res://assets/audio/ui/tab_switch.wav`
- **鏃堕暱**: 0.05-0.1 绉?
- **鍦烘櫙**: 鍦?UI 涓垏鎹㈡爣绛鹃〉
- **鎻愮ず璇?*: Generate a quick tab switch sound for a game UI. A light, crisp tick with a slight pitch shift, like flipping a page. Duration 50-100ms. Minimal and clean.


---

## 浜屻€佺帺瀹?瑙掕壊闊虫晥

### 13. player_hurt 鈥?鐜╁鍙楀嚮
- **闊抽璺緞**: `res://assets/audio/player/hurt.wav`
- **鏃堕暱**: 0.15-0.3 绉?
- **鍦烘櫙**: 鐜╁瑙掕壊琚晫浜烘敾鍑诲懡涓紝鎵ｈ
- **鎻愮ず璇?*: Generate a player hurt sound for a 2D roguelike game. A short, punchy impact with a slight vocal grunt undertone. Not too painful sounding, more like a cartoon hit. Duration 150-300ms. Should feel impactful but not distressing.

### 14. player_armor_break 鈥?鎶ょ敳鐮寸
- **闊抽璺緞**: `res://assets/audio/player/armor_break.wav`
- **鏃堕暱**: 0.3-0.5 绉?
- **鍦烘櫙**: 鐜╁鏈€鍚庝竴鐐规姢鐢茶鍑荤牬锛岃繘鍏ユ棤鐢茬姸鎬?
- **鎻愮ず璇?*: Generate an armor breaking/shattering sound for a game. Glass or crystal cracking and shattering with metallic undertones. More dramatic than a regular hit. Duration 300-500ms. Should feel like a protective barrier just shattered.

### 15. player_death 鈥?鐜╁姝讳骸锛堝凡鏈?glass_shatter.wav锛?
- **闊抽璺緞**: `res://assets/audio/glass_shatter.wav`
- **淇濈暀鐜版湁鏂囦欢**: `assets/audio/glass_shatter.wav`
- **鏃犻渶鐢熸垚**

### 16. player_dash 鈥?鐜╁鍐插埡锛堝凡鏈?dash.wav锛?
- **闊抽璺緞**: `res://assets/audio/dash.wav`
- **淇濈暀鐜版湁鏂囦欢**: `assets/audio/dash.wav`
- **鏃犻渶鐢熸垚**

### 17. player_energy_gain 鈥?鑳介噺鑾峰彇
- **闊抽璺緞**: `res://assets/audio/player/energy_gain.wav`
- **鏃堕暱**: 0.1-0.2 绉?
- **鍦烘櫙**: 鍑绘潃鏁屼汉鍚庤幏寰楄兘閲忥紝鑳介噺鏉″闀裤€傞珮棰戣Е鍙戯紙姣忔鍑绘潃锛?
- **鎻愮ず璇?*: Generate a quick energy pickup sound for a game. A short, bright ascending sparkle or shimmer, like absorbing a small light orb. Very brief and non-intrusive since it triggers frequently. Duration 100-200ms. Subtle but satisfying.

### 18. player_energy_low 鈥?鑳介噺涓嶈冻
- **闊抽璺緞**: `res://assets/audio/player/energy_low.wav`
- **鏃堕暱**: 0.2-0.3 绉?
- **鍦烘櫙**: 鐜╁灏濊瘯鏂芥斁鎶€鑳戒絾鑳介噺涓嶈冻
- **鎻愮ず璇?*: Generate an energy depleted/insufficient sound for a game. A hollow, descending electronic tone that sounds like power draining away. Like a battery dying sound but brief. Duration 200-300ms. Should clearly communicate "not enough power".

### 19. player_level_up 鈥?鍗囩骇
- **闊抽璺緞**: `res://assets/audio/player/level_up.wav`
- **鏃堕暱**: 0.5-0.8 绉?
- **鍦烘櫙**: 鐜╁缁忛獙鍊艰揪鍒板崌绾ч槇鍊硷紝瑙掕壊鍗囩骇
- **鎻愮ず璇?*: Generate a level up sound for a roguelike game. A bright, triumphant ascending arpeggio with a sparkling finish. Magical and celebratory but not overly long. Duration 500-800ms. Should feel like a moment of achievement.

### 20. gold_pickup 鈥?閲戝竵鎷惧彇
- **闊抽璺緞**: `res://assets/audio/player/gold_pickup.wav`
- **鏃堕暱**: 0.05-0.15 绉?
- **鍦烘櫙**: 閲戝竵椋炲悜鐜╁琚嬀鍙栥€傛瀬楂橀瑙﹀彂锛堝ぇ閲忔晫浜烘帀钀介噾甯侊級
- **鎻愮ず璇?*: Generate a tiny coin pickup sound for a game. A single bright metallic clink or ting. Extremely short and light since hundreds may play in quick succession with pitch randomization. Duration 50-150ms. Think classic arcade coin but softer.

### 21. char_switch_success 鈥?瑙掕壊鍒囨崲鎴愬姛
- **闊抽璺緞**: `res://assets/audio/player/switch_success.wav`
- **鏃堕暱**: 0.2-0.4 绉?
- **鍦烘櫙**: 鐜╁鎸?1/2/3 閿垚鍔熷垏鎹㈠埌鍙︿竴涓鑹?
- **鎻愮ず璇?*: Generate a character switch sound for a squad-based game. A quick whoosh with a magical transformation sparkle, like teleporting and reforming. Duration 200-400ms. Should feel swift and decisive.

### 22. char_switch_fail 鈥?瑙掕壊鍒囨崲澶辫触
- **闊抽璺緞**: `res://assets/audio/player/switch_fail.wav`
- **鏃堕暱**: 0.15-0.25 绉?
- **鍦烘櫙**: 鐜╁灏濊瘯鍒囨崲瑙掕壊浣嗗浜庡喎鍗翠腑鎴栫洰鏍囪鑹插凡姝讳骸
- **鎻愮ず璇?*: Generate a failed action/cooldown sound for a game. A short, muffled buzz or blocked sound, like hitting an invisible wall. Duration 150-250ms. Not harsh, just a clear "not available" signal.

### 23. super_armor_trigger 鈥?瓒呯骇鎶ょ敳瑙﹀彂
- **闊抽璺緞**: `res://assets/audio/player/super_armor.wav`
- **鏃堕暱**: 0.2-0.4 绉?
- **鍦烘櫙**: 鐜╁鍦ㄧ敾绾挎椂琚嚮涓紝瓒呯骇鎶ょ敳缇佺粖瑙﹀彂鍏嶇柅鍑婚€€
- **鎻愮ず璇?*: Generate a super armor activation sound for a game. A solid, resonant metallic shield impact with a brief energy pulse. Like an invisible force field absorbing a hit. Duration 200-400ms. Should feel powerful and protective.


---

## 涓夈€佹垬鏂楅煶鏁?

### 24. enemy_hit 鈥?鏁屼汉鍙楀嚮锛堝凡鏈?EnemyHit.wav锛?
- **闊抽璺緞**: `res://assets/audio/EnemyHit.wav`
- **淇濈暀鐜版湁鏂囦欢**: `assets/audio/EnemyHit.wav`
- **鏃犻渶鐢熸垚**

### 25. enemy_death 鈥?鏁屼汉姝讳骸锛堝凡鏈?pop_squish.wav锛?
- **闊抽璺緞**: `res://assets/audio/pop_squish.wav`
- **淇濈暀鐜版湁鏂囦欢**: `assets/audio/pop_squish.wav`
- **鏃犻渶鐢熸垚**

### 26. enemy_charge_warning 鈥?鍐查攱棰勮
- **闊抽璺緞**: `res://assets/audio/combat/charge_warning.wav`
- **鏃堕暱**: 0.5-0.8 绉?
- **鍦烘櫙**: 鍒虹尙鍨嬫晫浜洪攣瀹氱帺瀹讹紝鏄剧ず绾㈣壊棰勮绾匡紝韬綋棰ゆ姈钃勫姏
- **鎻愮ず璇?*: Generate a charge warning sound for a game enemy. A rising tension tone that builds urgency, like a low growl escalating into a high-pitched whine. Think of a bull scraping the ground before charging. Duration 500-800ms. Should create a sense of impending danger.

### 27. enemy_charge 鈥?鍐查攱
- **闊抽璺緞**: `res://assets/audio/combat/charge.wav`
- **鏃堕暱**: 0.3-0.5 绉?
- **鍦烘櫙**: 鏁屼汉钃勫姏瀹屾垚锛屾部鐩寸嚎楂橀€熷啿閿?
- **鎻愮ず璇?*: Generate an enemy charge/rush sound for a 2D game. A powerful, fast whoosh with a heavy impact undertone, like a battering ram launching forward. Duration 300-500ms. Should feel fast, heavy, and dangerous.

### 28. crit_hit 鈥?鏆村嚮
- **闊抽璺緞**: `res://assets/audio/combat/crit_hit.wav`
- **鏃堕暱**: 0.2-0.4 绉?
- **鍦烘櫙**: 鐜╁鏀诲嚮瑙﹀彂鏆村嚮锛岄€犳垚鍙屽€嶄激瀹?
- **鎻愮ず璇?*: Generate a critical hit sound for a roguelike game. A sharp, powerful impact with a bright flash-like accent on top. More dramatic and punchy than a regular hit. Like a thunderclap mixed with breaking glass. Duration 200-400ms. Should feel devastating and satisfying.

### 29. loop_kill 鈥?闂幆缁炴潃锛堝凡鏈?magic_chord.wav锛?
- **闊抽璺緞**: `res://assets/audio/magic_chord.wav`
- **淇濈暀鐜版湁鏂囦欢**: `assets/audio/magic_chord.wav`
- **鏃犻渶鐢熸垚**

### 30. player_explosion 鈥?鐖嗙偢锛堝凡鏈?magical_explosion.wav锛?
- **闊抽璺緞**: `res://assets/audio/magical_explosion.wav`
- **淇濈暀鐜版湁鏂囦欢**: `assets/audio/magical_explosion.wav`
- **鏃犻渶鐢熸垚**

### 31. debuff_burn 鈥?鐕冪儳寮傚父鐘舵€?
- **闊抽璺緞**: `res://assets/audio/combat/debuff_burn.wav`
- **鏃堕暱**: 0.3-0.5 绉?
- **鍦烘櫙**: 鏁屼汉琚柦鍔犵噧鐑х姸鎬侊紝鎸佺画鎺夎锛岃韩涓婂嚭鐜扮伀鐒版晥鏋?
- **鎻愮ず璇?*: Generate a fire/burn debuff application sound for a game. A quick ignition whoosh followed by crackling flames. Like a match striking and a small fire erupting. Duration 300-500ms. Warm, aggressive, clearly "fire".

### 32. debuff_curse 鈥?璇呭拻寮傚父鐘舵€?
- **闊抽璺緞**: `res://assets/audio/combat/debuff_curse.wav`
- **鏃堕暱**: 0.3-0.5 绉?
- **鍦烘櫙**: 鏁屼汉琚柦鍔犺瘏鍜掔姸鎬侊紝鍙彔鍔犲眰鏁帮紝鎸佺画鍙楀埌鏆楀睘鎬т激瀹?
- **鎻愮ず璇?*: Generate a dark curse debuff sound for a game. A sinister, low-pitched ethereal whisper with a subtle dark magic pulse. Like shadows wrapping around something. Duration 300-500ms. Ominous and mystical, purple/dark energy feeling.

### 33. debuff_poison 鈥?涓瘨寮傚父鐘舵€?
- **闊抽璺緞**: `res://assets/audio/combat/debuff_poison.wav`
- **鏃堕暱**: 0.3-0.5 绉?
- **鍦烘櫙**: 鏁屼汉琚柦鍔犱腑姣掔姸鎬侊紝鍙彔鍔犲眰鏁帮紝鎸佺画鍙楀埌姣掔礌浼ゅ
- **鎻愮ず璇?*: Generate a poison debuff application sound for a game. A wet, bubbling hiss like acid dripping, with a sickly squelch. Duration 300-500ms. Should feel toxic and corrosive, green slime energy.

### 34. debuff_slow 鈥?鍑忛€熷紓甯哥姸鎬?
- **闊抽璺緞**: `res://assets/audio/combat/debuff_slow.wav`
- **鏃堕暱**: 0.3-0.5 绉?
- **鍦烘櫙**: 鏁屼汉琚柦鍔犲噺閫熺姸鎬侊紝绉诲姩閫熷害澶у箙闄嶄綆
- **鎻愮ず璇?*: Generate a slow/debuff application sound for a game. A descending, stretching tone like time being pulled apart, with a heavy, sluggish quality. Like moving through thick honey. Duration 300-500ms. Should feel heavy and dragging.

### 35. debuff_freeze 鈥?鍐板喕寮傚父鐘舵€?
- **闊抽璺緞**: `res://assets/audio/combat/debuff_freeze.wav`
- **鏃堕暱**: 0.3-0.5 绉?
- **鍦烘櫙**: 鏁屼汉琚柦鍔犲啺鍐荤姸鎬侊紝瀹屽叏鏃犳硶绉诲姩
- **鎻愮ず璇?*: Generate an ice freeze debuff sound for a game. A sharp crystallization crack followed by a brief icy shimmer. Like water instantly freezing into ice. Duration 300-500ms. Cold, crisp, and sudden. Think ice forming rapidly.

### 36. debuff_stun 鈥?鐪╂檿寮傚父鐘舵€?
- **闊抽璺緞**: `res://assets/audio/combat/debuff_stun.wav`
- **鏃堕暱**: 0.3-0.5 绉?
- **鍦烘櫙**: 鏁屼汉琚柦鍔犵湬鏅曠姸鎬侊紝瀹屽叏鏃犳硶绉诲姩锛堢被浼煎啺鍐讳絾瑙嗚涓嶅悓锛?
- **鎻愮ず璇?*: Generate a stun debuff sound for a game. A sharp impact followed by cartoon-style stars-circling-head ringing. A bell-like tone with slight wobble. Duration 300-500ms. Should feel disorienting, like getting bonked on the head.

### 37. poison_pool_spawn 鈥?姣掓睜鐢熸垚
- **闊抽璺緞**: `res://assets/audio/combat/poison_pool.wav`
- **鏃堕暱**: 0.4-0.6 绉?
- **鍦烘櫙**: 鍦伴浄鎬浜″悗鍦ㄥ湴闈㈢暀涓嬩竴涓豢鑹叉瘨姹犲尯鍩燂紝鎸佺画浼ゅ韪╁叆鐨勭帺瀹?
- **鎻愮ず璇?*: Generate a poison pool spawning sound for a game. A wet, spreading splash followed by continuous bubbling. Like toxic sludge spreading across the ground. Duration 400-600ms. Should feel dangerous and disgusting, green toxic waste energy.


---

## 鍥涖€佹妧鑳介煶鏁?

### 38. skill_q_planning 鈥?Q 鎶€鑳借鍒掓ā寮忚繘鍏ワ紙瀛愬脊鏃堕棿锛?
- **闊抽璺緞**: `res://assets/audio/skill/q_planning.wav`
- **鏃堕暱**: 0.3-0.6 绉?
- **鍦烘櫙**: 鐜╁鎸変綇 Q 閿紝娓告垙杩涘叆 0.1x 鎱㈠姩浣滐紝灞忓箷鍑虹幇瑙勫垝绾挎潯銆傛椂闂翠豢浣涘嚌鍥?
- **鎻愮ず璇?*: Generate a bullet-time activation sound for a drawing-based skill system. A deep, resonant time-dilation effect 鈥?like reality stretching and slowing down. A low bass drop followed by a sustained ethereal hum. Duration 300-600ms. Should feel like entering a focused, time-frozen state.

### 39. skill_q_draw_start 鈥?鐢荤嚎寮€濮?
- **闊抽璺緞**: `res://assets/audio/skill/q_draw_start.wav`
- **鏃堕暱**: 0.1-0.2 绉?
- **鍦烘櫙**: 鍦ㄨ鍒掓ā寮忎腑锛岀帺瀹舵寜涓嬮紶鏍囧乏閿紑濮嬬敾绾匡紝澧ㄦ按/鑳介噺绾挎潯浠庨紶鏍囦綅缃紑濮嬪欢浼?
- **鎻愮ず璇?*: Generate a drawing/ink start sound for a game skill. A quick, smooth brush stroke initiation 鈥?like a calligraphy pen touching paper with a slight magical sparkle. Duration 100-200ms. Elegant and fluid, ink-on-paper feeling.

### 40. skill_q_closure_detected 鈥?闂悎妫€娴嬫彁绀?
- **闊抽璺緞**: `res://assets/audio/skill/q_closure_detected.wav`
- **鏃堕暱**: 0.15-0.3 绉?
- **鍦烘櫙**: 鐢荤嚎杩囩▼涓紝绾挎潯棣栧熬鎺ヨ繎褰㈡垚闂悎鍖哄煙锛岀嚎鏉￠鑹插彉绾㈡彁绀虹帺瀹?
- **鎻愮ず璇?*: Generate a shape closure detection sound for a drawing skill. A bright, ascending notification chime that says "you've completed a shape". Like a puzzle piece clicking into place with a magical resonance. Duration 150-300ms. Satisfying and encouraging.

### 41. skill_q_closure_generic 鈥?Q 闂悎鎵ц锛堥€氱敤锛?
- **闊抽璺緞**: `res://assets/audio/skill/q_closure_generic.wav`
- **鏃堕暱**: 0.4-0.7 绉?
- **鍦烘櫙**: 鐜╁鏉惧紑 Q 閿紝闂悎鍖哄煙鍐呯殑鎵€鏈夋晫浜哄彈鍒拌寖鍥翠激瀹炽€傝繖鏄牳蹇冩垬鏂楁満鍒剁殑楂樻疆鏃跺埢
- **鎻愮ず璇?*: Generate a powerful area-of-effect execution sound for a drawing-based skill in a roguelike game. A dramatic magical detonation 鈥?energy gathering inward then exploding outward. Like an ink bomb detonating inside a drawn circle. Duration 400-700ms. Should feel climactic, powerful, and deeply satisfying. This is the core gameplay payoff moment.

### 42. skill_q_open_execute 鈥?Q 寮€鏀捐矾寰勬墽琛?
- **闊抽璺緞**: `res://assets/audio/skill/q_open_execute.wav`
- **鏃堕暱**: 0.3-0.5 绉?
- **鍦烘櫙**: 鐜╁鏉惧紑 Q 閿絾绾挎潯鏈棴鍚堬紝鐢熸垚澧欎綋/绾挎鏁堟灉闃绘尅鏁屼汉
- **鎻愮ず璇?*: Generate a wall/barrier creation sound for a drawing skill. A solid, sweeping materialization effect 鈥?like ink solidifying into a physical wall. Duration 300-500ms. Should feel constructive and solid, less dramatic than the closure sound.

### 43. skill_q_energy_depleted 鈥?鐢荤嚎鑳介噺鑰楀敖
- **闊抽璺緞**: `res://assets/audio/skill/q_energy_depleted.wav`
- **鏃堕暱**: 0.2-0.3 绉?
- **鍦烘櫙**: 鐢荤嚎杩囩▼涓兘閲忚€楀敖锛屾棤娉曠户缁敾绾匡紝鏄剧ず "No Energy!" 鏂囧瓧
- **鎻愮ず璇?*: Generate an energy depleted sound for a game skill. A fading, sputtering tone like a pen running out of ink or a battery dying. Descending and hollow. Duration 200-300ms. Should clearly communicate "power ran out".

### 44. skill_e_instant 鈥?E 鎶€鑳界灛鍙?
- **闊抽璺緞**: `res://assets/audio/skill/e_instant.wav`
- **鏃堕暱**: 0.2-0.4 绉?
- **鍦烘櫙**: 鐜╁鎸?E 閿柦鏀剧灛鍙戝瀷鎶€鑳斤紙濡傚啿鍒恒€佷紶閫併€佸彫鍞ょ瓑锛?
- **鎻愮ず璇?*: Generate a quick instant-cast skill sound for a game. A sharp, decisive magical burst 鈥?like snapping fingers and releasing energy. Quick and punchy. Duration 200-400ms. Should feel responsive and immediate.

### 45. skill_e_aoe 鈥?E 鎶€鑳?AOE
- **闊抽璺緞**: `res://assets/audio/skill/e_aoe.wav`
- **鏃堕暱**: 0.3-0.6 绉?
- **鍦烘櫙**: 鐜╁鎸?E 閿柦鏀捐寖鍥村瀷鎶€鑳斤紙濡傜垎鐐搞€佸啺鍐诲尯鍩熴€佹瘨闆剧瓑锛?
- **鎻愮ず璇?*: Generate an area-of-effect skill activation sound for a game. A spreading magical wave expanding outward from a center point. Like a shockwave rippling through the air. Duration 300-600ms. Should feel expansive and impactful.

### 46. skill_ult_activate 鈥?缁堟瀬鎶€鑳芥縺娲伙紙F 閿級
- **闊抽璺緞**: `res://assets/audio/skill/ult_activate.wav`
- **鏃堕暱**: 0.5-1.0 绉?
- **鍦烘櫙**: 鐜╁鎸?F 閿縺娲荤粓鏋佹妧鑳斤紝瑙掕壊杩涘叆寮哄寲鐘舵€侊紝姝﹀櫒闄勫姞鐖嗙偢鏁堟灉
- **鎻愮ず璇?*: Generate an ultimate skill activation sound for a roguelike game. A dramatic, powerful transformation effect 鈥?building energy followed by a massive release. Like a supernova igniting. Duration 500ms-1s. Should feel epic, rare, and game-changing. The most dramatic skill sound in the game.

### 47. skill_ult_deactivate 鈥?缁堟瀬鎶€鑳界粨鏉?
- **闊抽璺緞**: `res://assets/audio/skill/ult_deactivate.wav`
- **鏃堕暱**: 0.3-0.5 绉?
- **鍦烘櫙**: 缁堟瀬鎶€鑳芥寔缁椂闂寸粨鏉燂紝瑙掕壊鎭㈠鏅€氱姸鎬?
- **鎻愮ず璇?*: Generate an ultimate skill deactivation/expiry sound for a game. A descending power-down effect, like energy dissipating and returning to normal. The reverse feeling of activation but gentler. Duration 300-500ms. Should feel like coming down from a power high.


---

## 浜斻€佺緛缁?鏈哄埗闊虫晥

### 48. bond_trigger_generic 鈥?閫氱敤缇佺粖瑙﹀彂
- **闊抽璺緞**: `res://assets/audio/environment/bond_generic.wav`
- **鏃堕暱**: 0.2-0.4 绉?
- **鍦烘櫙**: 浠绘剰缇佺粖鏈哄埗瑙﹀彂鏃剁殑閫氱敤闊虫晥锛堝 debuff 寤堕暱銆侀€熷害杞激瀹炽€佸浘褰㈢户鎵跨瓑锛?
- **鎻愮ず璇?*: Generate a generic bond/synergy trigger sound for a game. A brief magical resonance pulse, like two energies connecting and amplifying each other. A subtle but noticeable harmonic chime. Duration 200-400ms. Should feel like a passive bonus activating.

### 49. bond_chain_reaction 鈥?杩為攣鍙嶅簲锛堢垎鐮村笀 Lv.3锛?
- **闊抽璺緞**: `res://assets/audio/environment/bond_chain.wav`
- **鏃堕暱**: 0.4-0.7 绉?
- **鍦烘櫙**: 闂悎鍖哄煙鐖嗙偢鍚庯紝鍖哄煙澶栫殑鎵€鏈夋晫浜轰篃鍙楀埌 30% 杩為攣浼ゅ锛屼骇鐢熷皬鐖嗙偢鐗规晥
- **鎻愮ず璇?*: Generate a chain reaction explosion sound for a game. A primary explosion followed by rapid cascading secondary detonations spreading outward. Like dominoes of explosions. Duration 400-700ms. Should feel like destruction spreading uncontrollably. Chaotic and powerful.

### 50. bond_permanent_cage 鈥?姘镐箙鐗㈢锛堢瓚澧欒€?Lv.3锛?
- **闊抽璺緞**: `res://assets/audio/environment/bond_cage.wav`
- **鏃堕暱**: 0.4-0.6 绉?
- **鍦烘櫙**: 闂悎鍖哄煙鍙樻垚姘镐箙鐗╃悊澧欎綋锛岄樆鎸℃晫浜虹Щ鍔紝鍙戝嚭钃濊壊鍏夎姃
- **鎻愮ず璇?*: Generate a cage/prison materialization sound for a game. Heavy metallic bars or crystal walls solidifying into place with a resonant locking sound. Like a magical prison forming around enemies. Duration 400-600ms. Should feel solid, permanent, and imprisoning. Blue energy feeling.

### 51. bond_soul_attach 鈥?鐏甸瓊闄勭潃璁℃暟锛堢伒榄傞檮鐫€缇佺粖锛?
- **闊抽璺緞**: `res://assets/audio/environment/bond_soul.wav`
- **鏃堕暱**: 0.2-0.4 绉?
- **鍦烘櫙**: 鐜╁鍙楀嚮鏃惰Е鍙戠伒榄傞檮鐫€鍙嶅嚮锛屽闄勮繎鏁屼汉閫犳垚浼ゅ
- **鎻愮ず璇?*: Generate a soul/spirit counter-attack sound for a game. A ghostly, ethereal pulse emanating outward 鈥?like a spectral shockwave. Haunting but powerful. Duration 200-400ms. Should feel supernatural and retaliatory. Purple/ghost energy.

### 52. bond_gold_trail 鈥?閲戝竵杞ㄨ抗锛堢偧閲戞湳澹緛缁婏級
- **闊抽璺緞**: `res://assets/audio/environment/bond_gold.wav`
- **鏃堕暱**: 0.1-0.2 绉?
- **鍦烘櫙**: 鐢荤嚎杩囩▼涓瘡闅斾竴娈佃窛绂昏嚜鍔ㄧ敓鎴愰噾甯侊紝閲戝竵浠庣嚎鏉′笂鎺夎惤
- **鎻愮ず璇?*: Generate a gold coin spawning/dropping sound for a game. A quick, bright metallic sparkle with a tiny coin drop. Very short since it triggers frequently during drawing. Duration 100-200ms. Should feel like treasure materializing from thin air.

### 53. bond_thorns_wall 鈥?鍙嶄激澧欙紙绛戝鑰?Lv.2锛?
- **闊抽璺緞**: `res://assets/audio/environment/bond_thorns.wav`
- **鏃堕暱**: 0.2-0.3 绉?
- **鍦烘櫙**: 鏁屼汉纰板埌鐜╁鐢荤殑绾挎澧欎綋鏃跺彈鍒板弽浼わ紝鏄剧ず "THORNS!" 鏂囧瓧
- **鎻愮ず璇?*: Generate a thorns/reflect damage sound for a game. A sharp, prickly impact 鈥?like hitting a cactus or barbed wire. A quick stinging sound with a slight metallic ring. Duration 200-300ms. Should feel painful for the attacker, defensive and spiky.

### 54. bond_small_shape_crit 鈥?灏忓浘褰㈡毚鍑伙紙鍑犱綍瀛﹀ Lv.2锛?
- **闊抽璺緞**: `res://assets/audio/environment/bond_crit.wav`
- **鏃堕暱**: 0.3-0.5 绉?
- **鍦烘櫙**: 鐜╁鐢诲嚭闈㈢Н灏忎簬闃堝€肩殑闂悎鍥惧舰锛岃Е鍙戝弻鍊嶄激瀹虫毚鍑伙紝鏄剧ず "CRITICAL!" 鏂囧瓧
- **鎻愮ず璇?*: Generate a precision critical hit sound for a game. A sharp, focused energy burst 鈥?like a laser concentrating into a tiny point then exploding. More precise and surgical than a regular crit. Duration 300-500ms. Should feel like rewarding skillful, precise play. Geometric/mathematical energy.


---

## 鍏€佺幆澧?娓告垙鐘舵€侀煶鏁?

### 55. wave_start 鈥?娉㈡寮€濮?
- **闊抽璺緞**: `res://assets/audio/environment/wave_start.wav`
- **鏃堕暱**: 0.5-0.8 绉?
- **鍦烘櫙**: 鏂颁竴娉㈡晫浜哄紑濮嬫秾鍏ユ垬鍦猴紝灞忓箷鏄剧ず娉㈡缂栧彿
- **鎻愮ず璇?*: Generate a wave start sound for a roguelike survival game. A dramatic war horn or battle drum hit that signals incoming enemies. Urgent and alerting. Duration 500-800ms. Should feel like "enemies are coming, get ready!" Tension-building.

### 56. wave_complete 鈥?娉㈡瀹屾垚
- **闊抽璺緞**: `res://assets/audio/environment/wave_complete.wav`
- **鏃堕暱**: 0.5-0.8 绉?
- **鍦烘櫙**: 鎵€鏈夋晫浜鸿娑堢伃锛屾尝娆＄粨鏉燂紝鍗冲皢杩涘叆鍟嗗簵闃舵
- **鎻愮ず璇?*: Generate a wave complete/victory sound for a roguelike game. A triumphant, relieving fanfare 鈥?like a brief moment of peace after battle. Ascending chords with a satisfying resolution. Duration 500-800ms. Should feel like "you survived, take a breath."

### 57. shop_open 鈥?鍟嗗簵寮€鍚?
- **闊抽璺緞**: `res://assets/audio/environment/shop_open.wav`
- **鏃堕暱**: 0.3-0.5 绉?
- **鍦烘櫙**: 娉㈡缁撴潫鍚庡晢搴楃晫闈㈡粦鍏ワ紝灞曠ず鍙喘涔扮殑鐗╁搧
- **鎻愮ず璇?*: Generate a shop opening sound for a game. A welcoming, warm chime with a slight cash register undertone. Like a magical merchant's tent flap opening. Duration 300-500ms. Should feel inviting and commercial, a moment of respite.

### 58. shop_close 鈥?鍟嗗簵鍏抽棴
- **闊抽璺緞**: `res://assets/audio/environment/shop_close.wav`
- **鏃堕暱**: 0.2-0.4 绉?
- **鍦烘櫙**: 鐜╁鐐瑰嚮"涓嬩竴娉?鎸夐挳锛屽晢搴楀叧闂紝鍑嗗杩涘叆涓嬩竴娉㈡垬鏂?
- **鎻愮ず璇?*: Generate a shop closing sound for a game. A decisive closing sound with a slight urgency 鈥?like shutting a book and picking up your weapon. Duration 200-400ms. Should feel like "shopping's over, back to battle."

### 59. chest_spawn 鈥?瀹濈鍑虹幇
- **闊抽璺緞**: `res://assets/audio/environment/chest_spawn.wav`
- **鏃堕暱**: 0.3-0.5 绉?
- **鍦烘櫙**: 鎴樻枟涓疂绠卞湪鍦烘櫙涓敓鎴愶紝鍙戝嚭鍏夎姃鍚稿紩鐜╁
- **鎻愮ず璇?*: Generate a treasure chest appearing/spawning sound for a game. A magical materialization with a sparkling shimmer 鈥?like a gift from the heavens landing on the ground. Duration 300-500ms. Should feel exciting and mysterious, "something good just appeared!"

### 60. chest_open 鈥?瀹濈鎵撳紑
- **闊抽璺緞**: `res://assets/audio/environment/chest_open.wav`
- **鏃堕暱**: 0.4-0.7 绉?
- **鍦烘櫙**: 鐜╁闈犺繎瀹濈瑙﹀彂鎵撳紑锛屾樉绀哄崌绾ч€夐」
- **鎻愮ず璇?*: Generate a treasure chest opening sound for a roguelike game. A creaking lid opening followed by a burst of magical light and sparkles. Like opening a music box mixed with discovering treasure. Duration 400-700ms. Should feel rewarding and full of possibility.

### 61. game_over 鈥?娓告垙缁撴潫
- **闊抽璺緞**: `res://assets/audio/environment/game_over.wav`
- **鏃堕暱**: 0.8-1.5 绉?
- **鍦烘櫙**: 鎵€鏈夎鑹叉浜★紝娓告垙缁撴潫锛屾樉绀虹粨绠楃晫闈?
- **鎻愮ず璇?*: Generate a game over sound for a roguelike game. A somber, descending tone that fades into silence. Not overly dramatic or depressing 鈥?this is a roguelike, death is expected. A melancholic but dignified ending. Duration 800ms-1.5s. Should feel like "that run is over" without being devastating.

---

## 涓冦€佹瘡瑙掕壊 Q 闂悎涓撳睘闊虫晥

浠ヤ笅涓?27 涓鑹茬殑 Q 鎶€鑳介棴鍚堟墽琛屼笓灞為煶鏁堛€傛瘡涓鑹茬殑闂悎闊虫晥搴斿弽鏄犲叾瑙掕壊涓婚鍜屾垬鏂楅鏍笺€?

### 閫氱敤鍙傛暟
- **鏃堕暱**: 0.4-0.7 绉?
- **鏍煎紡**: WAV, 44100Hz, 16-bit, Mono
- **鍦烘櫙**: 鐜╁鐢荤嚎褰㈡垚闂悎鍖哄煙鍚庢澗寮€ Q 閿紝闂悎鍖哄煙鍐呮晫浜哄彈鍒拌寖鍥翠激瀹炽€傝繖鏄瘡涓鑹叉渶鍏疯鲸璇嗗害鐨勯煶鏁?

### 62. butcher锛堝睜澶級鈥?杩戞垬鑲夌浘
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/butcher.wav`
- **鎻愮ず璇?*: Generate a heavy butcher's cleaver slam sound for a game skill. A massive, meaty impact 鈥?like a giant blade chopping through flesh and bone. Heavy, brutal, and satisfying. Duration 400-700ms. Red/blood energy. Think of a butcher's shop but magical.

### 63. ignis锛堢伀鐒帮級鈥?楂樼垎鍙?AOE
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/ignis.wav`
- **鎻愮ず璇?*: Generate a fire explosion closure sound for a game skill. A roaring fireball detonation 鈥?flames rushing inward then erupting outward. Intense heat and crackling fire. Duration 400-700ms. Orange/red fire energy. Should feel like a contained inferno exploding.

### 64. nexus锛堢粐缃戯級鈥?鎸佺画鎺у埗鍑忛€?
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/nexus.wav`
- **鎻愮ず璇?*: Generate a web/thread entanglement closure sound for a game skill. Silk threads tightening and snapping with a sticky, constricting quality. Like a spider web closing around prey. Duration 400-700ms. Purple/silver thread energy. Should feel trapping and suffocating.

### 65. herder锛堢墽缇婁汉锛夆€?鍙敜/缇や綋鎺у埗
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/herder.wav`
- **鎻愮ず璇?*: Generate a herding/corralling closure sound for a game skill. A commanding whistle followed by a stampede-like rumble. Like calling a pack of wolves to surround prey. Duration 400-700ms. Green/nature energy. Should feel like nature obeying a command.

### 66. tesla锛堢壒鏂媺锛夆€?鐢靛嚮/杩為攣闂數
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/tesla.wav`
- **鎻愮ず璇?*: Generate an electric/tesla coil closure sound for a game skill. Crackling electricity arcing and zapping with a powerful discharge. Like a lightning bolt striking inside a contained area. Duration 400-700ms. Blue/white electric energy. Should feel shocking and electrifying.

### 67. bulwark锛堝啺宸濓級鈥?鍐板喕/鍖哄煙鎺у埗
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/bulwark.wav`
- **鎻愮ず璇?*: Generate an ice/bulwark closure sound for a game skill. Rapid crystallization and freezing 鈥?ice cracking and forming with a deep cold resonance. Like flash-freezing everything in an area. Duration 400-700ms. Light blue/white ice energy. Should feel cold, sharp, and absolute.

### 68. voodoo锛堝帆姣掞級鈥?璇呭拻/鏆楀睘鎬?
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/voodoo.wav`
- **鎻愮ず璇?*: Generate a voodoo/dark magic closure sound for a game skill. Eerie chanting whispers with a dark magical pulse. Like dark spirits being summoned to curse everything in an area. Duration 400-700ms. Dark purple/black energy. Should feel sinister and supernatural.

### 69. furnace锛堥搧鍖狅級鈥?閿婚€?閲戝睘
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/furnace.wav`
- **鎻愮ず璇?*: Generate a furnace's forge closure sound for a game skill. A massive hammer strike on an anvil with sparks flying, followed by a metallic ring. Like forging a weapon in one powerful blow. Duration 400-700ms. Orange/metal energy. Should feel industrial and powerful.

### 70. gunslinger锛堟棗鎵嬶級鈥?榧撹垶/澧炵泭
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/gunslinger.wav`
- **鎻愮ず璇?*: Generate a battle gunslinger/rally closure sound for a game skill. A triumphant horn blast with a flag unfurling in windblade. Like planting a war gunslinger that inspires allies. Duration 400-700ms. Gold/white energy. Should feel inspiring and commanding.

### 71. matrix锛堢槦鐤級鈥?姣掔礌/鐤剧梾
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/matrix.wav`
- **鎻愮ず璇?*: Generate a matrix/disease closure sound for a game skill. Sickly bubbling and hissing with toxic gas spreading. Like a matrix cloud engulfing an area. Duration 400-700ms. Green/yellow toxic energy. Should feel infectious and nauseating.

### 72. windblade锛堢柧椋庯級鈥?楂樻満鍔ㄥ垏鍓?
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/windblade.wav`
- **鎻愮ず璇?*: Generate a unique closure execution sound for the Wind character in a 2D roguelike game. The character's theme is high mobility and cutting windblade blades. The sound should play when the player draws a closed shape that damages all enemies inside. Duration 400-700ms. A sharp, slicing windblade gust with a cutting edge. Should feel swift and razor-sharp.

### 73. diva锛堝伐鍏碉級鈥?闃靛湴寤鸿/璧勬簮
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/diva.wav`
- **鎻愮ず璇?*: Generate a unique closure execution sound for the Diva/Engineer character in a 2D roguelike game. The character's theme is fortification building and resource management. Duration 400-700ms. Mechanical construction sounds with riveting and welding sparks. Should feel industrious and tactical.

### 74. new_ignis锛堟柊鐏硶锛夆€?鐏涓庣伀娴?
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/new_ignis.wav`
- **鎻愮ず璇?*: Generate a unique closure execution sound for the New Ignismancer character in a 2D roguelike game. The character's theme is fire walls and seas of flame. Duration 400-700ms. A deep, roaring inferno with spreading flames and intense heat. Should feel like an ocean of fire engulfing the area.

### 75. warden锛堢嫳璀︼級鈥?鐢电綉涓庡皝閿?
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/warden.wav`
- **鎻愮ず璇?*: Generate a unique closure execution sound for the Warden character in a 2D roguelike game. The character's theme is electric nets and lockdown. Duration 400-700ms. Crackling electric fence activation with a heavy metallic lock sound. Should feel imprisoning and electrified.

### 76. new_tempest锛堟柊椋庢毚锛夆€?椋庡甫涓庡彴椋庣溂
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/new_tempest.wav`
- **鎻愮ず璇?*: Generate a unique closure execution sound for the New Tempest character in a 2D roguelike game. The character's theme is windblade bands and typhoon eyes. Duration 400-700ms. A swirling vortex of windblade building into a powerful cyclone. Should feel like being in the eye of a storm.

### 77. inkweaver锛堝啗鍖伙級鈥?娌荤枟涓庡惛琛€
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/inkweaver.wav`
- **鎻愮ず璇?*: Generate a unique closure execution sound for the Inkweaver character in a 2D roguelike game. The character's theme is healing and life drain. Duration 400-700ms. A warm, pulsing healing aura with a subtle life-siphoning undertone. Should feel restorative yet slightly vampiric.

### 78. ammo锛堝脊鑽級鈥?寮硅嵂琛ョ粰
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/ammo.wav`
- **鎻愮ず璇?*: Generate a unique closure execution sound for the Ammo character in a 2D roguelike game. The character's theme is ammunition supply and explosive ordnance. Duration 400-700ms. Rapid bullet casings dropping with a magazine loading click and explosive charge. Should feel like arming up for war.

### 79. earthshaker锛堝湥楠戝＋锛夆€?鍏夊涓庡槻璁?
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/earthshaker.wav`
- **鎻愮ず璇?*: Generate a unique closure execution sound for the Earthshaker character in a 2D roguelike game. The character's theme is holy light walls and taunting. Duration 400-700ms. A radiant holy light burst with a deep, commanding voice-like resonance. Should feel righteous and protective. Golden/white energy.

### 80. vampire锛堣鏃忥級鈥?琛€璺笌鍚歌
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/vampire.wav`
- **鎻愮ず璇?*: Generate a unique closure execution sound for the Vampire character in a 2D roguelike game. The character's theme is blood paths and life drain. Duration 400-700ms. A dark, wet blood-rushing sound with a heartbeat pulse and draining effect. Should feel predatory and dark. Crimson/dark red energy.

### 81. train锛堢伀杞︾帇锛夆€?鍐插嚮娉笌鑷寸洸
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/train.wav`
- **鎻愮ず璇?*: Generate a unique closure execution sound for the Train King character in a 2D roguelike game. The character's theme is shockwaves and blinding impacts. Duration 400-700ms. A massive locomotive-like impact with a blinding flash sound. Should feel unstoppable and overwhelming.

### 82. dealer锛堣櫕姣嶏級鈥?铏兢鍙敜
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/dealer.wav`
- **鎻愮ず璇?*: Generate a unique closure execution sound for the Dealer Mother character in a 2D roguelike game. The character's theme is insect dealer summoning. Duration 400-700ms. A buzzing, chittering dealer of insects erupting and spreading. Should feel creepy and overwhelming. Green/brown insect energy.

### 83. new_totem锛堣惃婊★級鈥?鍥捐吘涓庨棯鐢?
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/new_totem.wav`
- **鎻愮ず璇?*: Generate a unique closure execution sound for the Shaman/Totem character in a 2D roguelike game. The character's theme is totems and lightning. Duration 400-700ms. A tribal drum beat followed by a totem activation pulse and lightning strike. Should feel primal and mystical.

### 84. turret_eng锛堝伐绋嬶級鈥?鐐閮ㄧ讲
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/turret_eng.wav`
- **鎻愮ず璇?*: Generate a unique closure execution sound for the Turret Engineer character in a 2D roguelike game. The character's theme is turret deployment and automated fire. Duration 400-700ms. Mechanical turret assembly sounds with a targeting lock beep and first shot. Should feel precise and technological.

### 85. goo锛堣蒋娉ワ級鈥?鑳舵按涓庡悶鍣?
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/goo.wav`
- **鎻愮ず璇?*: Generate a unique closure execution sound for the Goo/Slime character in a 2D roguelike game. The character's theme is sticky glue and devouring. Duration 400-700ms. A wet, squelching blob spreading and engulfing with a sticky, viscous quality. Should feel gross and suffocating. Green slime energy.

### 86. illusionist锛堟鐏碉級鈥?楠ㄥ涓庢亹鎯?
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/illusionist.wav`
- **鎻愮ず璇?*: Generate a unique closure execution sound for the Illusionistmancer character in a 2D roguelike game. The character's theme is bone walls and fear. Duration 400-700ms. Bones rattling and assembling with a terrifying ghostly wail. Should feel deathly and horrifying. Dark/bone white energy.

### 87. viper锛堥瓟鏈笀锛夆€?闀滈潰涓庡够褰?
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/viper.wav`
- **鎻愮ず璇?*: Generate a unique closure execution sound for the Viper character in a 2D roguelike game. The character's theme is mirrors and phantoms. Duration 400-700ms. A shimmering glass-like refraction sound with echoing duplications. Should feel disorienting and magical. Silver/mirror energy.

### 88. merchant锛堝晢浜猴級鈥?閲戝竵鍔犳垚涓庨粦甯?
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/merchant.wav`
- **鎻愮ず璇?*: Generate a unique closure execution sound for the Merchant character in a 2D roguelike game. The character's theme is gold bonuses and black market deals. Duration 400-700ms. A cascade of gold coins with a cash register cha-ching and a sly magical undertone. Should feel profitable and cunning. Gold energy.

### 89. midas锛堢偧閲戯級鈥?鐭冲寲涓庣偣閲?
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/midas.wav`
- **鎻愮ず璇?*: Generate a unique closure execution sound for the Midas/Alchemist character in a 2D roguelike game. The character's theme is petrification and golden touch. Duration 400-700ms. A crystallizing stone transformation followed by a golden shimmer. Should feel like everything turning to gold. Gold/stone energy.

### 90. vacuum锛堝惛灏樺櫒锛夆€?鍚稿紩涓庢缉娑?
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/vacuum.wav`
- **鎻愮ず璇?*: Generate a unique closure execution sound for the Vacuum character in a 2D roguelike game. The character's theme is attraction and vortex. Duration 400-700ms. A powerful suction whoosh pulling everything inward followed by a compressed implosion. Should feel like a black hole forming.

### 91. bloodhowl锛堝鍒戜汉锛夆€?澶勫喅涓庢柇澶村彴
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/bloodhowl.wav`
- **鎻愮ず璇?*: Generate a unique closure execution sound for the Bloodhowl character in a 2D roguelike game. The character's theme is execution and guillotine. Duration 400-700ms. A heavy blade dropping with a decisive, final impact. Should feel brutal, judicial, and absolute. Dark red/steel energy.

### 92. gambler锛堣祵寰掞級鈥?闅忔満 Buff 涓庢幏楠?
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/gambler.wav`
- **鎻愮ず璇?*: Generate a unique closure execution sound for the Gambler character in a 2D roguelike game. The character's theme is random buffs and dice rolling. Duration 400-700ms. Dice rattling and rolling with a slot machine jackpot chime. Should feel lucky and unpredictable. Gold/rainbow energy.

### 93. hunter锛堢寧浜猴級鈥?闄烽槺涓庢爣璁?
- **闊抽璺緞**: `res://assets/audio/skill/q_closure/hunter.wav`
- **鎻愮ず璇?*: Generate a unique closure execution sound for the Hunter character in a 2D roguelike game. The character's theme is traps and marking targets. Duration 400-700ms. A bear trap snapping shut with a predatory growl and target-lock ping. Should feel calculated and deadly. Green/brown nature energy.

---

## 闄勫綍锛氶煶鏁堢敓鎴愬伐鍏锋帹鑽?

| 宸ュ叿 | 鐢ㄩ€?| 璇存槑 |
|------|------|------|
| Suno AI | 闊虫晥鐢熸垚 | 鏀寔鏂囨湰鎻忚堪鐢熸垚闊虫晥 |
| ElevenLabs Sound Effects | 闊虫晥鐢熸垚 | 楂樿川閲?AI 闊虫晥鐢熸垚 |
| Freesound.org | 闊虫晥绱犳潗搴?| 鍏嶈垂闊虫晥绱犳潗锛屽彲浣滀负鍩虹绱犳潗娣峰悎 |
| Audacity | 鍚庢湡澶勭悊 | 鍏嶈垂闊抽缂栬緫锛岀敤浜庤鍓€佽皟鏁淬€佹牸寮忚浆鎹?|
| sfxr/jsfxr | 8-bit 闊虫晥 | 蹇€熺敓鎴愬鍙ら鏍奸煶鏁?|
| Bfxr | 娓告垙闊虫晥 | sfxr 澧炲己鐗堬紝鏇村鍙傛暟鎺у埗 |

### 鍚庢湡澶勭悊寤鸿

1. 鎵€鏈夌敓鎴愮殑闊虫晥缁熶竴杞崲涓?WAV 44100Hz 16-bit Mono
2. 浣跨敤 Audacity 鐨?鏍囧噯鍖?鍔熻兘缁熶竴鍝嶅害鍒?-16 LUFS
3. 瑁佸壀澶氫綑鐨勯潤闊抽儴鍒嗭紝纭繚闊虫晥寮€澶存棤寤惰繜
4. 瀵归珮棰戣Е鍙戠殑闊虫晥锛堝 gold_pickup銆乪nergy_gain锛夐澶栭檷浣庨煶閲?3-5dB
5. 瀵瑰悓涓€绫诲埆鐨勯煶鏁堜繚鎸佷竴鑷寸殑闊宠壊椋庢牸

