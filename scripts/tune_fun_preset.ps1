param(
    [string]$InputMain = "config/player/skill_params_wide_preset_fun.csv",
    [string]$OutputMain = "config/player/skill_params_wide_preset_fun_tuned.csv",
    [string]$InputTrial = "config/player/skill_params_wide_trial_8roles_preset_fun.csv",
    [string]$OutputTrial = "config/player/skill_params_wide_trial_8roles_preset_fun_tuned.csv"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-VarNameFromNote {
    param([string]$Note)
    if ([string]::IsNullOrWhiteSpace($Note)) { return "" }
    if ($Note -match '\(([^\)]+)\)') { return $matches[1].Trim() }
    return ""
}

function Clamp {
    param([double]$Value, [double]$Min, [double]$Max)
    return [math]::Max($Min, [math]::Min($Max, $Value))
}

function Format-Value {
    param([double]$Value, [string]$Original)
    if ($Original -notmatch '\.') {
        return ([int][math]::Round($Value)).ToString([System.Globalization.CultureInfo]::InvariantCulture)
    }
    $d = ($Original -split '\.')[1].Length
    if ($d -lt 1) { $d = 1 }
    return ([math]::Round($Value, $d)).ToString("F$d", [System.Globalization.CultureInfo]::InvariantCulture)
}

$script:targetSkillIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$bindingPath = "config/player/player_skill_bindings.csv"
if (Test-Path $bindingPath) {
    Import-Csv -Path $bindingPath | ForEach-Object {
        if ($_.player_id -eq "-1") { return }
        $qid = [string]$_.slot_q
        if ([string]::IsNullOrWhiteSpace($qid)) { return }
        [void]$script:targetSkillIds.Add($qid.Trim())
    }
}
if ($script:targetSkillIds.Count -eq 0) {
    Get-ChildItem -Path "scenes/skills/players" -Filter "skill_*_q.gd" | ForEach-Object {
        [void]$script:targetSkillIds.Add($_.BaseName)
    }
}

function Tune-OneFile {
    param([string]$InputPath, [string]$OutputPath)

    $rows = Import-Csv -Path $InputPath

    foreach ($row in $rows) {
        if (-not $script:targetSkillIds.Contains([string]$row.skill_id)) { continue }

        foreach ($i in 1..10) {
            $p = "param$i"
            $n = "param${i}_note"
            $raw = [string]$row.$p
            $note = [string]$row.$n
            if ([string]::IsNullOrWhiteSpace($raw) -or [string]::IsNullOrWhiteSpace($note)) { continue }

            $varName = Get-VarNameFromNote -Note $note
            if ([string]::IsNullOrWhiteSpace($varName)) { continue }

            $v = 0.0
            if (-not [double]::TryParse($raw, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$v)) {
                continue
            }

            # --- 先做通用限制 ---
            if ($varName -match '(interval|delay|tick)') {
                $v = Clamp $v 0.32 1.40
            }
            if ($varName -match '(duration|_duration|time)') {
                $v = Clamp $v 1.20 10.00
            }

            # --- 比率类限制 ---
            if ($varName -match '(slow|petrify)' -and $varName -notmatch '(duration|interval|delay|tick)') {
                $v = Clamp $v 0.20 0.92
            }
            if ($varName -match 'lifesteal') {
                $v = Clamp $v 0.08 0.85
            }
            if ($varName -match '(speed_boost|line_speed_boost|discount_speed_boost|triage_speed_boost)') {
                $v = Clamp $v 0.10 0.45
            }
            if ($varName -match '(attack_boost|forge_attack_boost|sanctuary_attack_boost|jackpot_bonus_attack|repair_boost|supply_attack_boost)') {
                $v = Clamp $v 0.12 0.75
            }
            if ($varName -match '(cooldown_reduction|jackpot_bonus_cooldown|supply_cooldown_reduction)') {
                $v = Clamp $v 0.08 0.38
            }
            if ($varName -match '(damage_amp|mark_amp|hex_damage_amp|overload_damage_amp|bounty_damage_amp|line_damage_amp|blood_mark_amp|transmute_damage_amp|mirror_mark_amp|field_damage_amp|defense_reduction|scorch_damage_amp)' -and $varName -notmatch '(duration|interval|delay|tick)') {
                $v = Clamp $v 0.10 0.45
            }
            if ($varName -eq 'hp_cost_percent') {
                $v = Clamp $v 0.08 0.14
            }

            # --- 数量与力场限制 ---
            if ($varName -match '(^|_)(count|num|amount)(_|$)') {
                $v = Clamp $v 1 5
            }
            if ($varName -match '(pull_force|vortex_force)') {
                $v = Clamp $v 120 480
            }

            # --- 伤害类定点限制 ---
            if ($varName -match 'damage' -and $varName -notmatch 'amp') {
                $cap = 72
                if ($varName -eq 'guillotine_damage') { $cap = 130 }
                elseif ($varName -eq 'jackpot_damage') { $cap = 32 }
                elseif ($varName -eq 'transmute_bonus_damage') { $cap = 30 }
                elseif ($varName -eq 'shockwave_damage') { $cap = 60 }
                elseif ($varName -eq 'blood_damage') { $cap = 42 }
                elseif ($varName -eq 'corpse_damage') { $cap = 70 }
                $v = Clamp $v 1 $cap
            }

            $row.$p = Format-Value -Value $v -Original $raw
        }
    }

    $rows | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
}

Tune-OneFile -InputPath $InputMain -OutputPath $OutputMain
Tune-OneFile -InputPath $InputTrial -OutputPath $OutputTrial

Write-Output "generated tuned fun: $OutputMain"
Write-Output "generated tuned fun: $OutputTrial"
