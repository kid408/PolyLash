# 瀹炵幇璁″垝锛氭壒閲忚鑹叉妧鑳界郴缁?

## 姒傝堪

鎸夌収鍩虹璁炬柦鈫掓妧鑳藉疄鐜扳啋閰嶇疆缁戝畾鐨勯『搴忥紝鍒嗛樁娈靛疄鐜?30 濂楁柊瑙掕壊鎶€鑳界郴缁熴€傛瘡涓樁娈靛畬鎴愬悗杩涜妫€鏌ョ偣楠岃瘉銆?

## 浠诲姟

- [x] 1. 閲嶆瀯 skill_params.csv 涓洪暱琛ㄦ牸寮?
  - [x] 1.1 鍦?ConfigManager 涓疄鐜?load_skill_params_long_format() 鏂规硶
    - 璇诲彇 skill_id, param_name, param_value, description 鍥涘垪
    - 灏嗘暟鎹浆鎹负 {skill_id: {param_name: param_value}} 瀛楀吀
    - 鑷姩灏嗘暟鍊煎瓧绗︿覆杞崲涓?float/int
    - 澶勭悊閲嶅 skill_id + param_name锛堜娇鐢ㄦ渶鍚庡嚭鐜扮殑鍊硷紝杈撳嚭璀﹀憡锛?
    - 淇敼 load_all_configs() 璋冪敤鏂版柟娉?
    - _Requirements: 1.1, 1.2, 1.4, 1.5_

  - [ ]* 1.2 缂栧啓灞炴€ф祴璇曪細闀胯〃 CSV 瑙ｆ瀽涓庣被鍨嬭浆鎹?
    - **Property 1: 闀胯〃 CSV 瑙ｆ瀽涓庣被鍨嬭浆鎹㈡纭€?*
    - **Validates: Requirements 1.1, 1.2, 1.4**

  - [ ]* 1.3 缂栧啓灞炴€ф祴璇曪細閲嶅鍙傛暟鏈€鍚庡€间紭鍏?
    - **Property 3: 閲嶅鍙傛暟鏈€鍚庡€间紭鍏?*
    - **Validates: Requirements 1.5**

  - [x] 1.4 灏嗙幇鏈?13 涓妧鑳藉弬鏁颁粠瀹借〃杩佺Щ鍒伴暱琛ㄦ牸寮?
    - 鍒涘缓鏂扮殑 skill_params.csv 闀胯〃鏂囦欢
    - 杩佺Щ skill_dash, skill_saw_path, skill_meat_stake 绛?13 涓幇鏈夋妧鑳?
    - 鍊间负 0 鐨勫弬鏁颁笉杩佺Щ
    - 淇濈暀 description 鍒楃敤浜庝腑鏂囪鏄?
    - _Requirements: 1.3_

  - [ ]* 1.5 缂栧啓鍗曞厓娴嬭瘯锛氶獙璇佽縼绉诲悗鐜版湁鎶€鑳藉弬鏁颁笌瀹借〃涓€鑷?
    - **Property 2: 闀胯〃涓庡琛ㄨ縼绉讳竴鑷存€э紙Round-Trip锛?*
    - **Validates: Requirements 1.2, 1.3**

- [x] 2. 鎵╁睍 StatusComponent 鏀寔鏂扮姸鎬?
  - [x] 2.1 鍦?StatusComponent 涓疄鐜版柊鐘舵€佸鐞?
    - 娣诲姞 STATUS_PRIORITY 甯搁噺瀛楀吀
    - 瀹炵幇 freeze 鐘舵€侊細鍋滄绉诲姩鍜屾敾鍑伙紝鐏拌摑鑹茶瑙?
    - 瀹炵幇 silence 鐘舵€侊細闃绘鐗规畩鎶€鑳斤紝绱壊瑙嗚
    - 瀹炵幇 fear 鐘舵€侊細閫冭窇琛屼负锛堣繙绂绘柦娉曡€咃級锛岀豢鑹茶瑙?
    - 瀹炵幇 marked 鐘舵€侊細鍙椾激澧炲姞鐧惧垎姣旓紝绾㈣壊鏍囪瑙嗚
    - 瀹炵幇 petrify 鐘舵€侊細瀹屽叏涓嶅彲琛屽姩锛岀伆鑹茶瑙?
    - 瀹炵幇 poison 鐘舵€侊細DOT 浼ゅ锛岀豢鑹茶瑙?
    - 瀹炵幇浼樺厛绾у鐞嗭細get_active_control_status() 杩斿洖鏈€楂樹紭鍏堢骇鐘舵€?
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

  - [ ]* 2.2 缂栧啓灞炴€ф祴璇曪細鏍囪鐘舵€佷激瀹虫斁澶ц绠?
    - **Property 5: 鏍囪鐘舵€佷激瀹虫斁澶ц绠?*
    - **Validates: Requirements 3.4**

  - [ ]* 2.3 缂栧啓灞炴€ф祴璇曪細鐘舵€佷紭鍏堢骇鎺掑簭
    - **Property 6: 鐘舵€佷紭鍏堢骇鎺掑簭**
    - **Validates: Requirements 3.6**

- [x] 3. 鎵╁睍 SkillEffectManager 鏀寔鏂版晥鏋滅被鍨?
  - [x] 3.1 瀹炵幇 create_wall_effect() 鏂规硶
    - 鍒涘缓 StaticBody2D 鑺傜偣锛屾部 start鈫抏nd 绾挎鐢熸垚纰版挒褰㈢姸
    - 鏀寔 block_enemies銆乥lock_bullets銆乺eflect_bullets 閰嶇疆
    - 鏀寔 contact_damage 鎺ヨЕ浼ゅ
    - 鏀寔 health 鍙牬鍧忓浣擄紙鍙楀埌鏀诲嚮鍚庡噺灏?health锛屽綊闆舵椂閿€姣侊級
    - 鏀寔 duration 鎸佺画鏃堕棿鍜屾贰鍑哄姩鐢?
    - 浣跨敤 Line2D 鍗犱綅瑙嗚鏁堟灉
    - _Requirements: 2.1, 2.2_

  - [x] 3.2 瀹炵幇 create_buff_zone() 鏂规硶
    - 鍒涘缓 Area2D 鍖哄煙锛屾敮鎸?polygon 鍜?start/end 涓ょ褰㈢姸
    - 妫€娴?"players" 缁勭殑鍗曚綅杩涘叆鍖哄煙
    - 鏀寔 buff_type: attack_boost, speed_boost, heal, lifesteal, invincible, cooldown_reduction, ignore_collision
    - 鎸?tick_interval 闂撮殧搴旂敤 Buff 鏁堟灉
    - 鏀寔 duration 鎸佺画鏃堕棿鍜屾贰鍑哄姩鐢?
    - 浣跨敤 Polygon2D/Line2D 鍗犱綅瑙嗚鏁堟灉
    - _Requirements: 2.3_

  - [x] 3.3 瀹炵幇 create_debuff_zone() 鏂规硶
    - 鍒涘缓 Area2D 鍖哄煙锛屾娴?"enemies" 缁勭殑鍗曚綅
    - 閫氳繃 StatusComponent.apply_status() 搴旂敤 Debuff
    - 鏀寔 debuff_type: slow, damage_amp, poison, freeze, fear
    - 鏀寔鍙€夌殑鍖哄煙浼ゅ锛坉amage + damage_interval锛?
    - _Requirements: 2.4_

  - [x] 3.4 瀹炵幇 create_summon() 鍜?command_summons() 鏂规硶
    - 鍒涘缓鍙敜鐗╄妭鐐癸紙Area2D + 鍗犱綅瑙嗚锛?
    - 瀹炵幇鍩虹 AI锛氳嚜鍔ㄦ敾鍑昏寖鍥村唴鏈€杩戞晫浜?
    - 瀹炵幇 max_count 闄愬埗锛氳秴杩囨椂绉婚櫎鏈€鏃╃殑鍙敜鐗?
    - 瀹炵幇 command_summons()锛歠ocus_fire銆乻elf_destruct 鎸囦护
    - 浣跨敤褰╄壊鍦嗗舰鍗犱綅瑙嗚
    - _Requirements: 2.5, 2.6_

  - [ ]* 3.5 缂栧啓灞炴€ф祴璇曪細鍙敜鐗╂暟閲忎笂闄愪笉鍙橀噺
    - **Property 4: 鍙敜鐗╂暟閲忎笂闄愪笉鍙橀噺**
    - **Validates: Requirements 2.6**

- [x] 4. 妫€鏌ョ偣 - 鍩虹璁炬柦楠岃瘉
  - 纭繚鎵€鏈夋祴璇曢€氳繃锛宎sk the user if questions arise.
  - 楠岃瘉 ConfigManager 闀胯〃鍔犺浇姝ｅ父
  - 楠岃瘉 StatusComponent 鏂扮姸鎬佸伐浣滄甯?
  - 楠岃瘉 SkillEffectManager 鏂版晥鏋滅被鍨嬪伐浣滄甯?
  - 楠岃瘉 SkillEffectManager 鐨勬晥鏋滆妭鐐规寕杞藉湪鐙珛浜庤鑹茬殑鍦烘櫙鏍戣妭鐐逛笂锛堢‘淇濊鑹插垏鎹笉褰卞搷鏁堟灉鐢熷懡鍛ㄦ湡锛?
  - _Requirements: 2.7, 11.1, 11.2, 11.3_

- [x] 5. 瀹炵幇 A 缁勬妧鑳?- 鍏冪礌涓庢帶鍒?
  - [x] 5.1 瀹炵幇鍐版渤锛圙lacier锛夋妧鑳?
    - 鍒涘缓 skill_bulwark_q.gd锛堢户鎵?SkillDrawingBase锛?
      - _spawn_line_effect: 璋冪敤 create_wall_effect 鍒涘缓鍐板锛坆lock_enemies + block_bullets锛?
      - _spawn_area_effect: 璋冪敤 create_debuff_zone 鏂藉姞 freeze 鐘舵€?
    - 鍒涘缓 skill_bulwark_e.gd锛堢户鎵?SkillBase锛?
      - execute: 鑼冨洿鍑婚€€ + 娣诲姞鎶ょ敳
    - 鍦?skill_params.csv 涓坊鍔犲弬鏁?
    - _Requirements: 4.1, 4.2, 4.3_

  - [x] 5.2 瀹炵幇鐗规柉鎷夛紙Tesla锛夋妧鑳?
    - 鍒涘缓 skill_tesla_q.gd
      - _spawn_line_effect: 璋冪敤 create_line_effect 鍒涘缓鐢靛姬绾匡紙浼ゅ + 0.5s 鐪╂檿锛?
      - _spawn_area_effect: 璋冪敤 create_area_effect 鍒涘缓闆风數鍦猴紙姣?0.5s 浼ゅ锛?
    - 鍒涘缓 skill_tesla_e.gd
      - execute: 鑼冨洿鏂藉姞 silence 鐘舵€?
    - 鍦?skill_params.csv 涓坊鍔犲弬鏁?
    - _Requirements: 4.4, 4.5, 4.6_

  - [x] 5.3 瀹炵幇鏂扮伀娉曪紙NewIgnis锛夋妧鑳?
    - 鍒涘缓 skill_new_ignis_q.gd
      - _spawn_line_effect: 璋冪敤 create_wall_effect 鍒涘缓鐏锛坆lock_enemies + contact_damage锛?
      - _spawn_area_effect: 璋冪敤 create_area_effect 鍒涘缓鐏捣锛圖OT锛?
    - 鍒涘缓 skill_new_ignis_e.gd
      - execute: 鑼冨洿鍑婚€€锛堢伀鐒扮幆锛?
    - 鍦?skill_params.csv 涓坊鍔犲弬鏁?
    - _Requirements: 4.7, 4.8, 4.9_

  - [x] 5.4 瀹炵幇鐦熺柅锛圥lague锛夋妧鑳?
    - 鍒涘缓 skill_matrix_q.gd
      - _spawn_line_effect: 璋冪敤 create_debuff_zone 鍒涘缓鑵愯殌璺緞锛坰low 50% + poison锛?
      - _spawn_area_effect: 璋冪敤 create_debuff_zone 鍒涘缓鐦存皵姹狅紙damage_amp 30%锛?
    - 鍒涘缓 skill_matrix_e.gd
      - execute: 寮曠垎鎵€鏈変腑姣掓晫浜虹殑姣掔礌灞傛暟
    - 鍦?skill_params.csv 涓坊鍔犲弬鏁?
    - _Requirements: 4.10, 4.11, 4.12_

  - [x] 5.5 瀹炵幇鐙辫锛圝ailer锛夋妧鑳?
    - 鍒涘缓 skill_warden_q.gd
      - _spawn_line_effect: 璋冪敤 create_wall_effect 鍒涘缓鐢电綉锛坈ontact_damage + knockback锛?
      - _spawn_area_effect: 璋冪敤 create_wall_effect 娌块棴鍚堣竟鐣屽垱寤哄皝闂澹?
    - 鍒涘缓 skill_warden_e.gd
      - execute: 鎵囧舰鑼冨洿鍑婚€€
    - 鍦?skill_params.csv 涓坊鍔犲弬鏁?
    - _Requirements: 4.13, 4.14, 4.15_

  - [x] 5.6 瀹炵幇鏂伴鏆达紙NewTempest锛夋妧鑳?
    - 鍒涘缓 skill_new_tempest_q.gd
      - _spawn_line_effect: 璋冪敤 create_buff_zone 鍒涘缓椋庡甫锛坰peed_boost锛?
      - _spawn_area_effect: 璋冪敤 create_area_effect 鍒涘缓鍙伴鐪硷紙pull_to_center锛?
    - 鍒涘缓 skill_new_tempest_e.gd
      - execute: 鑼冨洿鎶涢鏁屼汉锛堥緳鍗烽锛?
    - 鍦?skill_params.csv 涓坊鍔犲弬鏁?
    - _Requirements: 4.16, 4.17, 4.18_

- [x] 6. 瀹炵幇 B 缁勬妧鑳?- 鎴樻湳鏀彺
  - [x] 6.1 瀹炵幇閾佸尃锛圔lacksmith锛夋妧鑳?
    - 鍒涘缓 skill_furnace_q.gd
      - _spawn_line_effect: 璋冪敤 create_buff_zone 鍒涘缓纾ㄥ垁鐭筹紙attack_boost 50%锛?
      - _spawn_area_effect: 璋冪敤 create_buff_zone 鍒涘缓閿婚€犵倝锛坅ttack_speed_boost 100%锛?
    - 鍒涘缓 skill_furnace_e.gd
      - execute: 閲嶇疆 Q 鎶€鑳藉喎鍗?
    - _Requirements: 5.1, 5.2, 5.3_

  - [x] 6.2 瀹炵幇鍐涘尰锛圡edic锛夋妧鑳?
    - 鍒涘缓 skill_inkweaver_q.gd
      - _spawn_line_effect: 璋冪敤 create_buff_zone锛坔eal锛? create_debuff_zone锛坰low锛?
      - _spawn_area_effect: 璋冪敤 create_buff_zone锛坔eal + invincible锛?
    - 鍒涘缓 skill_inkweaver_e.gd
      - execute: 5 绉?lifesteal Buff
    - _Requirements: 5.4, 5.5, 5.6_

  - [x] 6.3 瀹炵幇寮硅嵂锛圓mmo锛夋妧鑳?
    - 鍒涘缓 skill_ammo_q.gd
      - _spawn_line_effect: 璋冪敤 create_buff_zone 鍒涘缓鍔犻€熻建閬擄紙projectile_boost锛?
      - _spawn_area_effect: 璋冪敤 create_buff_zone 鍒涘缓琛ョ粰绔欙紙cooldown_reduction锛?
    - 鍒涘缓 skill_ammo_e.gd
      - execute: 鑳介噺鎭㈠鑷虫弧鍊?
    - _Requirements: 5.7, 5.8, 5.9_

  - [x] 6.4 瀹炵幇鍦ｉ獞澹紙Earthshaker锛夋妧鑳?
    - 鍒涘缓 skill_earthshaker_q.gd
      - _spawn_line_effect: 璋冪敤 create_wall_effect 鍒涘缓鍏夊锛坆lock_bullets锛?
      - _spawn_area_effect: 璋冪敤 create_buff_zone 鍒涘缓鍑€鍖栧満锛坈leanse + damage_reduction锛?
    - 鍒涘缓 skill_earthshaker_e.gd
      - execute: 鍢茶锛堝己鍒舵晫浜烘敾鍑昏嚜韬級
    - _Requirements: 5.10, 5.11, 5.12_

  - [x] 6.5 瀹炵幇琛€鏃忥紙Vampire锛夋妧鑳?
    - 鍒涘缓 skill_vampire_q.gd
      - _spawn_line_effect: 璋冪敤 create_line_effect 鍒涘缓琛€璺紙娑堣€楄嚜韬?HP锛? HP 浼ゅ锛?
      - _spawn_area_effect: 璋冪敤 create_buff_zone 鍒涘缓琛€姹狅紙lifesteal 100%锛?
    - 鍒涘缓 skill_vampire_e.gd
      - execute: 鍚稿彇闄勮繎鏁屼汉 HP
    - _Requirements: 5.13, 5.14, 5.15_

  - [x] 6.6 瀹炵幇鏃楁墜锛圔anner锛夋妧鑳?
    - 鍒涘缓 skill_gunslinger_q.gd
      - _spawn_line_effect: 璋冪敤 create_buff_zone 鍒涘缓鍐查攱绾匡紙ignore_collision锛?
      - _spawn_area_effect: 璋冪敤 create_debuff_zone 鍒涘缓鍐虫枟鍦猴紙defense = 0锛?
    - 鍒涘缓 skill_gunslinger_e.gd
      - execute: 鍏ㄩ槦绉婚€熺垎鍙?
    - _Requirements: 5.16, 5.17, 5.18_

- [x] 7. 妫€鏌ョ偣 - A/B 缁勬妧鑳介獙璇?
  - 纭繚鎵€鏈夋祴璇曢€氳繃锛宎sk the user if questions arise.
  - 楠岃瘉 12 濂楁妧鑳斤紙A 缁?6 + B 缁?6锛夌殑 Q-line銆丵-circle銆丒-key 鍔熻兘
  - 楠岃瘉瑙掕壊鍒囨崲鍚庢晥鏋滄寔缁?

- [x] 8. 瀹炵幇 C 缁勬妧鑳?- 濂囪涓庡彫鍞?
  - [x] 8.1 瀹炵幇鐏溅鐜嬶紙Train锛夋妧鑳?
    - 鍒涘缓 skill_train_q.gd
      - _spawn_line_effect: 鍒涘缓骞界伒杞ㄩ亾锛?s 寤惰繜鍚庡啿鍑绘尝锛?
      - _spawn_area_effect: 鍒涘缓鏃嬭浆鍏夋潫锛堟寔缁激瀹筹級
    - 鍒涘缓 skill_train_e.gd
      - execute: 鑷寸洸鑼冨洿鍐呮晫浜?
    - _Requirements: 6.1, 6.2, 6.3_

  - [x] 8.2 瀹炵幇铏瘝锛圫warm锛夋妧鑳?
    - 鍒涘缓 skill_dealer_q.gd
      - _spawn_line_effect: 鍒涘缓瑁傜紳锛堟瘡 1s 鐢熸垚鑷垎鐢茶櫕锛屼娇鐢?create_summon锛?
      - _spawn_area_effect: 鍒涘缓瀛靛寲鍦猴紙鐢熸垚 3 涓偖濉?+ 闃熷弸娌荤枟锛?
    - 鍒涘缓 skill_dealer_e.gd
      - execute: 璋冪敤 command_summons("focus_fire")
    - _Requirements: 6.4, 6.5, 6.6_

  - [x] 8.3 瀹炵幇钀ㄦ弧锛圢ewTotem锛夋妧鑳?
    - 鍒涘缓 skill_new_totem_q.gd
      - _spawn_line_effect: 鍦ㄨ捣鐐瑰拰缁堢偣鏀剧疆鍥捐吘锛坈reate_summon锛夛紝闂數閾捐繛鎺?
      - _spawn_area_effect: 鍒涘缓鍦伴渿鏁堟灉锛堜激瀹?+ slow锛?
    - 鍒涘缓 skill_new_totem_e.gd
      - execute: 寮曠垎鎵€鏈夊浘鑵撅紙command_summons("self_destruct")锛?
    - _Requirements: 6.7, 6.8, 6.9_

  - [x] 8.4 瀹炵幇宸ョ▼锛圱urret锛夋妧鑳?
    - 鍒涘缓 skill_turret_q.gd
      - _spawn_line_effect: 娌胯矾寰勭瓑璺濇斁缃?3 涓偖濉旓紙create_summon锛?
      - _spawn_area_effect: 鍒涘缓缁翠慨绔欙紙鍖哄煙鍐呯偖濉斿弻鍊嶆敾閫燂級
    - 鍒涘缓 skill_turret_e.gd
      - execute: 寮曠垎鎵€鏈夌偖濉旓紙command_summons("self_destruct")锛?
    - _Requirements: 6.10, 6.11, 6.12_

  - [x] 8.5 瀹炵幇杞偿锛圙oo锛夋妧鑳?
    - 鍒涘缓 skill_goo_q.gd
      - _spawn_line_effect: 璋冪敤 create_debuff_zone 鍒涘缓瓒呯骇鑳舵按锛坰low 90%锛?
      - _spawn_area_effect: 鍒涘缓鍒嗚姹狅紙鏁屼汉鍙椾激鏃剁敓鎴愯糠浣犲彶鑾卞锛?
    - 鍒涘缓 skill_goo_e.gd
      - execute: 鍚炲櫖鏈€杩戝皬鍨嬫晫浜猴紙instant kill + heal锛?
    - _Requirements: 6.13, 6.14, 6.15_

  - [x] 8.6 瀹炵幇姝荤伒锛圢ecro锛夋妧鑳?
    - 鍒涘缓 skill_illusionist_q.gd
      - _spawn_line_effect: 璋冪敤 create_wall_effect 鍒涘缓楠ㄥ锛坔ealth = 3锛?
      - _spawn_area_effect: 鍒涘缓灏哥垎鍦猴紙鏁屼汉姝讳骸鏃剁垎鐐革級
    - 鍒涘缓 skill_illusionist_e.gd
      - execute: 鑼冨洿鏂藉姞 fear 鐘舵€?
    - _Requirements: 6.16, 6.17, 6.18_

- [x] 9. 瀹炵幇 D 缁勬妧鑳?- 缁忔祹涓庢敹鍓诧紙鎶€鑳藉簱锛屼笉缁戝畾瑙掕壊锛?
  - [x] 9.1 瀹炵幇鍟嗕汉锛圡erchant锛夋妧鑳?
    - 鍒涘缓 skill_merchant_q.gd + skill_merchant_e.gd
    - 鍦?skill_params.csv 涓坊鍔犲弬鏁?
    - _Requirements: 7.1, 7.2, 7.3_

  - [x] 9.2 瀹炵幇鐐奸噾锛圡idas锛夋妧鑳?
    - 鍒涘缓 skill_midas_q.gd + skill_midas_e.gd
    - _Requirements: 7.4, 7.5, 7.6_

  - [x] 9.3 瀹炵幇鍚稿皹鍣紙Vacuum锛夋妧鑳?
    - 鍒涘缓 skill_vacuum_q.gd + skill_vacuum_e.gd
    - _Requirements: 7.7, 7.8, 7.9_

  - [x] 9.4 瀹炵幇澶勫垜锛圗xecutioner锛夋妧鑳?
    - 鍒涘缓 skill_bloodhowl_q.gd + skill_bloodhowl_e.gd
    - _Requirements: 7.10, 7.11, 7.12_

  - [x] 9.5 瀹炵幇璧屽緬锛圙ambler锛夋妧鑳?
    - 鍒涘缓 skill_gambler_q.gd + skill_gambler_e.gd
    - _Requirements: 7.13, 7.14, 7.15_

  - [x] 9.6 瀹炵幇鐚庝汉锛圚unter锛夋妧鑳?
    - 鍒涘缓 skill_hunter_q.gd + skill_hunter_e.gd
    - _Requirements: 7.16, 7.17, 7.18_

- [x] 10. 瀹炵幇 E 缁勬妧鑳?- 鐗规畩鏈哄埗
  - [x] 10.1 瀹炵幇榄旀湳甯堬紙Viper锛夋妧鑳?
    - 鍒涘缓 skill_viper_q.gd
      - _spawn_line_effect: 璋冪敤 create_wall_effect 鍒涘缓闀滈潰锛坮eflect_bullets锛?
      - _spawn_area_effect: 鍒涘缓骞诲奖鍒嗚韩锛坈reate_summon, phantom 绫诲瀷锛?
    - 鍒涘缓 skill_viper_e.gd
      - execute: 涓庡够褰变氦鎹綅缃?
    - _Requirements: 8.1, 8.2, 8.3_

  - [x] 10.2 瀹炵幇宸瘨锛圴oodoo锛夋妧鑳?
    - 鍒涘缓 skill_voodoo_q.gd
      - _spawn_line_effect: 璋冪敤 create_debuff_zone 鏂藉姞 curse 鐘舵€?
      - _spawn_area_effect: 鍒涘缓閽夊埡鍧戯紙鏀诲嚮鍖哄煙鍐呭崟浣嶆椂浼ゅ鎵€鏈?cursed 鏁屼汉锛?
    - 鍒涘缓 skill_voodoo_e.gd
      - execute: 鑷激瑙﹀彂鍏ㄥ睆 curse 浼ゅ
    - _Requirements: 8.4, 8.5, 8.6_

- [x] 11. 妫€鏌ョ偣 - C/D/E 缁勬妧鑳介獙璇?
  - 纭繚鎵€鏈夋祴璇曢€氳繃锛宎sk the user if questions arise.
  - 楠岃瘉鎵€鏈?26 濂楁柊鎶€鑳界殑 Q-line銆丵-circle銆丒-key 鍔熻兘

- [x] 12. 鍒犻櫎鏃ц鑹蹭笌鍒涘缓鏂拌鑹?
  - [x] 12.1 鍒犻櫎 20 涓潪鍘熷瑙掕壊鐨勬墍鏈夐厤缃拰鑴氭湰
    - 浠?config/player/player_config.csv 涓垹闄?20 涓棫瑙掕壊琛?
    - 浠?config/player/player_visual.csv 涓垹闄ゅ搴旇
    - 浠?config/player/player_weapons.csv 涓垹闄ゅ搴旇
    - 浠?config/player/player_skill_bindings.csv 涓垹闄ゅ搴旇
    - 浠?config/player/ult_config.csv 涓垹闄ゅ搴旇
    - 浠?config/player/player_available_weapons.csv 涓垹闄ゅ搴旇
    - 鍒犻櫎 20 涓?scenes/unit/players/player_xxx.gd 鑴氭湰鏂囦欢鍙婂搴?.uid 鏂囦欢
    - _Requirements: 10.1, 10.2_

  - [x] 12.2 鍒涘缓 20 涓柊瑙掕壊鐨?GDScript 鏂囦欢
    - 浣跨敤妯℃澘鍖栫粨鏋勫垱寤?scenes/unit/players/player_xxx.gd锛堝弬鑰?player_technology_hurricane.gd 妯℃澘锛?
    - 璁剧疆姝ｇ‘鐨?class_name锛堝 PlayerBulwark銆丳layerTesla 绛夛級
    - 璁剧疆姝ｇ‘鐨?load_skills_from_config() 鍙傛暟
    - _Requirements: 10.5_

  - [x] 12.3 鍦ㄦ墍鏈?CSV 閰嶇疆鏂囦欢涓坊鍔?20 涓柊瑙掕壊
    - 鍦?config/player/player_config.csv 涓坊鍔犳柊瑙掕壊琛岋紙鏍规嵁瀹氫綅鍒嗛厤鍚堢悊灞炴€у€硷紝鎸夎璁℃枃妗?3c 灞炴€у弬鑰冨€硷級
    - 鍦?config/player/player_config.csv 涓寜璁捐鏂囨。 3d 缇佺粖绯荤粺璁捐璁剧疆姣忎釜鏂拌鑹茬殑 origin_tag銆乵astery_tag銆乼actic_tag
    - 鍦?config/player/player_visual.csv 涓坊鍔犳柊瑙掕壊琛岋紙浣跨敤閫氱敤鍗犱綅瑙嗚锛?
    - 鍦?config/player/player_weapons.csv 涓坊鍔犳柊瑙掕壊琛岋紙浣跨敤閫氱敤姝﹀櫒閰嶇疆锛?
    - 鍦?config/player/player_available_weapons.csv 涓坊鍔犳柊瑙掕壊琛?
    - 鍦?config/player/ult_config.csv 涓坊鍔犳柊瑙掕壊琛岋紙浣跨敤閫氱敤澶ф嫑閰嶇疆锛?
    - _Requirements: 10.3, 10.4_

  - [x] 12.4 鏇存柊 player_skill_bindings.csv 缁戝畾鏂版妧鑳?
    - 涓?20 涓柊瑙掕壊缁戝畾瀵瑰簲鐨勬柊鎶€鑳?Q/E
    - 淇濇寔鍘熷鍏鑹茬粦瀹氫笉鍙?
    - 楠岃瘉 D 缁?6 濂楁妧鑳斤紙merchant, midas, vacuum, bloodhowl, gambler, hunter锛夊弬鏁板湪 skill_params.csv 涓畬鏁翠繚鐣?
    - _Requirements: 10.6, 10.7, 10.8_

  - [x] 12.5 楠岃瘉 SkillManager 姝ｇ‘鍔犺浇鏂版妧鑳界粦瀹?
    - 纭 SkillManager 鑳芥牴鎹?player_skill_bindings.csv 姝ｇ‘瀹炰緥鍖栨柊瑙掕壊鐨勬妧鑳借剼鏈?
    - 纭鎶€鑳藉弬鏁颁粠 skill_params.csv 闀胯〃姝ｇ‘鍔犺浇
    - _Requirements: 10.9_

  - [ ]* 12.6 缂栧啓灞炴€ф祴璇曪細闈炲師濮嬭鑹叉妧鑳界粦瀹氬敮涓€鎬?
    - **Property 7: 闈炲師濮嬭鑹叉妧鑳界粦瀹氬敮涓€鎬?*
    - **Validates: Requirements 10.6**

  - [ ]* 12.7 缂栧啓鍗曞厓娴嬭瘯锛氶獙璇佸師濮嬪叚瑙掕壊缁戝畾鏈彉
    - 楠岃瘉 butcher銆乸yro銆乻apper銆乭erder銆亀eaver銆亀ind 鐨勬妧鑳界粦瀹氫笌鍘熷鍊间竴鑷?
    - _Requirements: 10.7_

- [x] 13. 鏈€缁堟鏌ョ偣 - 鍏ㄧ郴缁熼獙璇?
  - 纭繚鎵€鏈夋祴璇曢€氳繃锛宎sk the user if questions arise.
  - 楠岃瘉鎵€鏈?26 涓鑹诧紙6 鍘熷 + 20 鏂帮級鐨勬妧鑳藉姞杞藉拰鎵ц
  - 楠岃瘉瑙掕壊鍒囨崲鍚庢晥鏋滄寔缁€э紙闇€姹?11.1-11.3锛?
  - 楠岃瘉 D 缁?6 濂楁妧鑳藉簱鎶€鑳藉弬鏁板畬鏁达紙闇€姹?10.8锛?
  - 楠岃瘉鎵€鏈夋柊鎶€鑳借剼鏈伒寰灦鏋勮鑼冿細Q 缁ф壙 SkillDrawingBase銆丒 缁ф壙 SkillBase銆佹枃浠跺悕瑙勮寖銆佸弬鏁颁粠 CSV 璇诲彇锛堥渶姹?9.1-9.6锛?
  - 楠岃瘉 20 涓柊瑙掕壊鐨勭緛缁婃爣绛句笌璁捐鏂囨。 3d 涓€鑷?

## 澶囨敞

- 鏍囪 `*` 鐨勪换鍔′负鍙€変换鍔★紝鍙烦杩囦互鍔犲揩 MVP 杩涘害
- 姣忎釜浠诲姟寮曠敤鍏蜂綋闇€姹備互纭繚鍙拷婧€?
- 妫€鏌ョ偣纭繚澧為噺楠岃瘉
- 灞炴€ф祴璇曢獙璇侀€氱敤姝ｇ‘鎬у睘鎬?
- 鍗曞厓娴嬭瘯楠岃瘉鍏蜂綋绀轰緥鍜岃竟鐣屾儏鍐?

