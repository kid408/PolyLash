---
name: character-skill-acceptance
description: Verify PolyLash character skills against design docs, code, CSV bindings, configs, and runtime behavior. Use when checking whether a character skill really matches its document, building an acceptance checklist, comparing `文档 / 代码 / CSV / 配置 / 实际运行表现`, investigating false positives caused by shared F-layer effects, fallback scripts, HUD-only evidence, stale caches, leftover legacy branches, or metadata-key mismatches, and deciding whether to update docs or code.
---

# Character Skill Acceptance

Use this skill to audit a character skill before calling it complete.

## Core rule

Do not write `完全一致` unless all five layers align:

- 文档
- 代码
- CSV 配表
- 相关配置
- 实际运行表现

If any layer is missing or only partially checked, label the result `部分一致` or `待复核`.

## Required workflow

1. Read the design doc, implementation scripts, CSV bindings, and related config together.
2. Build a comparison table with these columns:
   - 文档承诺
   - 代码表现
   - CSV / 配置表现
   - 实际运行表现
   - 结论
   - 需要改文档还是改代码
3. Check for the common false positives below.
4. State clearly whether the gap is `文档落后于代码` or `代码落后于文档`.
5. Update the checklist and mark each item only after it is actually rechecked.

## Hard checks

- For F skills, confirm the real loaded path is the role-specific script, not a fallback, legacy path, or cached residue.
- Separate shared F-layer effects from role-specific gameplay. Large size, color change, invincibility frames, HUD, or runtime panels only prove the shared layer is active.
- Verify metadata keys on both write and consume sides, especially pairs like `attack_boost` / `buff_attack_boost` / `buff_attack_speed_bonus` / `buff_speed_boost`.
- Compare `player_skill_bindings.csv`, `skill_params_wide.csv`, `ult_config`, `player_config.csv`, and the actual script path.
- Treat HUD as runtime evidence only. Do not use HUD as proof that gameplay logic is correct.
- Look for old skill remnants, compatibility branches, or fallback logic that may still be driving behavior.
- If code was touched, require a Godot headless compile pass before finalizing.

## Decision rules

- If you only checked names, entry points, or resource hookups, stop at `待复核`.
- If runtime behavior diverges from the document, do not soften it into `一致`.
- If the same behavior can be explained by shared systems rather than the role's own gameplay, treat it as unproven.
- If another role could replace the description almost entirely, the skill identity is too weak and needs redesign or relabeling.

## Output format

Return the result in this order:

- 角色名
- 文档承诺
- 代码表现
- CSV / 配置表现
- 实际运行表现
- 一致性判断：一致 / 部分一致 / 明显偏离 / 待复核
- 差异点
- 需要改文档还是改代码
- checklist 回勾结果

## Final reminder

Never trust naming alone. Never trust a HUD alone. Never trust a shared F effect alone. Always verify the full chain end to end.
