param(
    [string]$MainCsv = "config/player/skill_params_wide.csv",
    [string]$TrialCsv = "config/player/skill_params_wide_trial_8roles.csv"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-VarNameFromNote {
    param([string]$Note)
    if ([string]::IsNullOrWhiteSpace($Note)) { return "" }
    if ($Note -match '\(([^\)]+)\)') { return $matches[1].Trim() }
    return ""
}

function Build-ScriptVarMap {
    param([string]$SkillId)
    $path = "scenes/skills/players/{0}.gd" -f $SkillId
    $map = @{}
    if (-not (Test-Path $path)) { return $map }

    Get-Content $path | ForEach-Object {
        if ($_ -match '^var\s+([a-zA-Z0-9_]+)\s*:\s*[a-zA-Z0-9_\.]+\s*=\s*(.+)$') {
            $name = $matches[1]
            $raw = $matches[2].Trim()
            if ($raw.Contains('#')) {
                $raw = ($raw -split '#')[0].Trim()
            }
            # 仅回填数值参数
            $num = 0.0
            if ([double]::TryParse($raw, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$num)) {
                $map[$name] = $raw
            }
        }
    }

    return $map
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

function Rebuild-Csv {
    param([string]$Path)
    $rows = Import-Csv -Path $Path

    foreach ($row in $rows) {
        $sid = [string]$row.skill_id
        if (-not $script:targetSkillIds.Contains($sid)) { continue }

        $varMap = Build-ScriptVarMap -SkillId $sid
        if ($varMap.Count -eq 0) { continue }

        foreach ($i in 1..10) {
            $p = "param$i"
            $n = "param${i}_note"
            $varName = Get-VarNameFromNote -Note ([string]$row.$n)
            if ([string]::IsNullOrWhiteSpace($varName)) { continue }
            if ($varMap.ContainsKey($varName)) {
                $row.$p = $varMap[$varName]
            }
        }
    }

    $rows | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
}

Rebuild-Csv -Path $MainCsv
Rebuild-Csv -Path $TrialCsv
Write-Output "rebuilt q baseline values from scripts: $MainCsv"
Write-Output "rebuilt q baseline values from scripts: $TrialCsv"
