---
name: godot-compile-check
description: Enforce a post-edit Godot compile pass for this project. Use when modifying `.gd`, `.tscn`, `.tres`, autoloads, scene wiring, or any gameplay/system code in `D:\Godot\Production\PolyLash_Project`, and verify the result by compiling with `D:\Godot\Godot_v4.6.1-stable_win64.exe` before finishing.
---

# Godot Compile Check

Run the required Godot compile pass after code edits and treat compilation as part of done-ness.

Prefer this exact command for the required compile check:

```powershell
& 'D:\Godot\Godot_v4.6.1-stable_win64.exe' --headless --path 'D:\Godot\Production\PolyLash_Project' --editor --quit --log-file 'D:\Godot\Production\PolyLash_Project\.godot_cli\compile_check.log'
```

If stdout is needed for debugging, use the console build only as a secondary inspection tool:

```powershell
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'D:\Godot\Production\PolyLash_Project' --editor --quit --verbose
```

## Workflow

1. Make the requested project changes.
2. Run the required `Godot_v4.6.1-stable_win64.exe` command above.
3. Read `.godot_cli/compile_check.log`.
4. Search the log for `Parse Error`, `SCRIPT ERROR`, `Failed to load script`, `Could not parse`, or other concrete script/resource failures.
5. Fix the reported issues and re-run the same compile command until the log is clean.
6. In the final response, state that the required Godot compile pass was executed and whether it was clean.

## Notes

Treat sandbox-related filesystem errors as environmental noise only after verifying they are not project errors. If the compile command cannot write its normal editor data under sandbox restrictions, re-run it outside the sandbox.

Do not stop at a code diff or a static read-through when this skill applies. The compile pass is mandatory.

Typical clean result:
- `compile_check.log` contains startup and editor-loading lines only.
- No `ERROR:` lines tied to project scripts/resources.
- No parse/loader failures for the files just edited.
