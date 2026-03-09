param(
    [string]$SourceMain = "config/player/skill_params_wide.csv",
    [string]$SourceTrial = "config/player/skill_params_wide_trial_8roles.csv"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-VarNameFromNote {
    param([string]$Note)
    if ([string]::IsNullOrWhiteSpace($Note)) { return "" }
    if ($Note -match '\(([^\)]+)\)') { return $matches[1].Trim() }
    return ""
}

function Format-ScaledValue {
    param(
        [double]$Value,
        [string]$OriginalText,
        [bool]$ForceInteger = $false
    )

    if ($ForceInteger -or ($OriginalText -notmatch '\.')) {
        return ([int][math]::Round($Value)).ToString([System.Globalization.CultureInfo]::InvariantCulture)
    }

    $decimals = ($OriginalText -split '\.')[1].Length
    if ($decimals -lt 1) { $decimals = 1 }
    $rounded = [math]::Round($Value, $decimals)
    return $rounded.ToString("F$decimals", [System.Globalization.CultureInfo]::InvariantCulture)
}

function Get-ScaledValue {
    param(
        [double]$Value,
        [string]$VarName,
        [ValidateSet('fun', 'hardcore')][string]$Mode
    )

    # 特例：生命代价，爽快档略降，硬核档略升
    if ($VarName -eq 'hp_cost_percent') {
        if ($Mode -eq 'fun') { return $Value * 0.88 }
        return $Value * 1.12
    }

    # 计数类（召唤数量、产币数量等）
    if ($VarName -match '(^|_)(count|num|amount)(_|$)') {
        if ($Mode -eq 'fun') { return [math]::Max(1.0, [math]::Round($Value + 1.0)) }
        return [math]::Max(1.0, [math]::Round($Value - 1.0))
    }

    # 间隔/延迟类：爽快档更快（更小）
    if ($VarName -match '(interval|delay|tick)') {
        if ($Mode -eq 'fun') { return $Value * 0.86 }
        return $Value * 1.16
    }

    # 持续时长
    if ($VarName -match '(duration|time)') {
        if ($Mode -eq 'fun') { return $Value * 1.12 }
        return $Value * 0.90
    }

    # 控制/增益/易伤/牵引
    if ($VarName -match '(amp|boost|reduction|lifesteal|slow|freeze|fear|stun|petrify|mark|pull|force|heal_multiplier)') {
        if ($Mode -eq 'fun') { return $Value * 1.16 }
        return $Value * 0.86
    }

    # 伤害（排除 *_amp 这类倍率参数）
    if ($VarName -match '(damage|dmg|bleed|poison|curse|shockwave|beam|guillotine|vortex|pool|blood|quake|arc|field|miasma)' -and $VarName -notmatch 'amp') {
        if ($Mode -eq 'fun') { return $Value * 1.28 }
        return $Value * 0.78
    }

    # 默认温和缩放
    if ($Mode -eq 'fun') { return $Value * 1.10 }
    return $Value * 0.90
}

function Build-Preset {
    param(
        [string]$InputPath,
        [string]$OutputPath,
        [ValidateSet('fun', 'hardcore')][string]$Mode,
        [System.Collections.Generic.HashSet[string]]$TargetSkillIds
    )

    $rows = Import-Csv -Path $InputPath

    foreach ($row in $rows) {
        $sid = $row.skill_id
        if (-not $TargetSkillIds.Contains($sid)) { continue }

        foreach ($i in 1..10) {
            $p = "param$i"
            $n = "param${i}_note"
            $orig = [string]$row.$p
            $note = [string]$row.$n
            if ([string]::IsNullOrWhiteSpace($orig) -or [string]::IsNullOrWhiteSpace($note)) { continue }

            $varName = Get-VarNameFromNote -Note $note
            if ([string]::IsNullOrWhiteSpace($varName)) { continue }

            $num = 0.0
            if (-not [double]::TryParse($orig, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$num)) {
                continue
            }

            $scaled = Get-ScaledValue -Value $num -VarName $varName -Mode $Mode

            # 限制部分比率参数到合理区间（避免异常爆值）
            # 注意：持续时间/间隔类不应进入该限制分支
            $isRateLike = $varName -match '(slow|amp|boost|reduction|lifesteal|petrify|hp_cost_percent)'
            $isTimeLike = $varName -match '(interval|delay|tick|duration|time)'
            if ($isRateLike -and -not $isTimeLike -and $varName -ne 'heal_multiplier') {
                if ($scaled -lt 0.0) { $scaled = 0.0 }
                if ($scaled -gt 1.2) { $scaled = 1.2 }
            }

            # 间隔和持续给最小安全值
            if ($varName -match '(interval|delay|tick|duration|time)') {
                if ($scaled -lt 0.1) { $scaled = 0.1 }
            }

            $forceInt = $varName -match '(^|_)(count|num|amount)(_|$)'
            $row.$p = Format-ScaledValue -Value $scaled -OriginalText $orig -ForceInteger:$forceInt
        }
    }

    $rows | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
}

$targetIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$bindingPath = "config/player/player_skill_bindings.csv"
if (Test-Path $bindingPath) {
    Import-Csv -Path $bindingPath | ForEach-Object {
        if ($_.player_id -eq "-1") { return }
        $qid = [string]$_.slot_q
        if ([string]::IsNullOrWhiteSpace($qid)) { return }
        [void]$targetIds.Add($qid.Trim())
    }
}
if ($targetIds.Count -eq 0) {
    Get-ChildItem -Path "scenes/skills/players" -Filter "skill_*_q.gd" | ForEach-Object {
        [void]$targetIds.Add($_.BaseName)
    }
}

$mainBaseline = "config/player/skill_params_wide_preset_baseline.csv"
$mainFun = "config/player/skill_params_wide_preset_fun.csv"
$mainHardcore = "config/player/skill_params_wide_preset_hardcore.csv"
$trialBaseline = "config/player/skill_params_wide_trial_8roles_preset_baseline.csv"
$trialFun = "config/player/skill_params_wide_trial_8roles_preset_fun.csv"
$trialHardcore = "config/player/skill_params_wide_trial_8roles_preset_hardcore.csv"

Copy-Item -Path $SourceMain -Destination $mainBaseline -Force
Copy-Item -Path $SourceTrial -Destination $trialBaseline -Force

Build-Preset -InputPath $SourceMain -OutputPath $mainFun -Mode fun -TargetSkillIds $targetIds
Build-Preset -InputPath $SourceMain -OutputPath $mainHardcore -Mode hardcore -TargetSkillIds $targetIds
Build-Preset -InputPath $SourceTrial -OutputPath $trialFun -Mode fun -TargetSkillIds $targetIds
Build-Preset -InputPath $SourceTrial -OutputPath $trialHardcore -Mode hardcore -TargetSkillIds $targetIds

Write-Output "generated: $mainBaseline"
Write-Output "generated: $mainFun"
Write-Output "generated: $mainHardcore"
Write-Output "generated: $trialBaseline"
Write-Output "generated: $trialFun"
Write-Output "generated: $trialHardcore"
