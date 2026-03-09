param(
    [string]$ProjectRoot = (Resolve-Path "$PSScriptRoot\..").Path,
    [string]$OutputDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-OutDir {
    param(
        [string]$Root,
        [string]$Candidate
    )
    if (-not [string]::IsNullOrWhiteSpace($Candidate)) {
        if (-not (Test-Path $Candidate)) {
            New-Item -Path $Candidate -ItemType Directory -Force | Out-Null
        }
        return (Resolve-Path $Candidate).Path
    }
    $dir = Join-Path $Root "docs\qa_reports"
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
    return $dir
}

function To-FloatOrZero {
    param([object]$Value)
    if ($null -eq $Value) { return 0.0 }
    $text = [string]$Value
    $num = 0.0
    if ([double]::TryParse($text, [ref]$num)) { return [double]$num }
    return 0.0
}

$playerConfigPath = Join-Path $ProjectRoot "config\player\player_config.csv"
$bindingsPath = Join-Path $ProjectRoot "config\player\player_skill_bindings.csv"
$skillWidePath = Join-Path $ProjectRoot "config\player\skill_params_wide.csv"

if (-not (Test-Path $playerConfigPath)) { throw "player_config.csv not found: $playerConfigPath" }
if (-not (Test-Path $bindingsPath)) { throw "player_skill_bindings.csv not found: $bindingsPath" }
if (-not (Test-Path $skillWidePath)) { throw "skill_params_wide.csv not found: $skillWidePath" }

$playersRaw = Import-Csv -Path $playerConfigPath -Encoding UTF8
$bindingsRaw = Import-Csv -Path $bindingsPath -Encoding UTF8
$skillsRaw = Import-Csv -Path $skillWidePath -Encoding UTF8

$bindingsById = @{}
foreach ($row in $bindingsRaw) {
    $id = [string]$row.player_id
    if ([string]::IsNullOrWhiteSpace($id) -or $id -eq "-1") { continue }
    $bindingsById[$id] = $row
}

$skillsById = @{}
foreach ($row in $skillsRaw) {
    $id = [string]$row.skill_id
    if ([string]::IsNullOrWhiteSpace($id) -or $id -eq "-1") { continue }
    $skillsById[$id] = $row
}

$enabledPlayers = @(
    $playersRaw |
    Where-Object {
        $_.player_id -ne "-1" -and
        ([string]$_.enabled).Trim() -eq "1"
    } |
    Sort-Object { [int]$_.display_order }
)

$rows = New-Object System.Collections.Generic.List[object]
$index = 1
foreach ($p in $enabledPlayers) {
    $playerId = [string]$p.player_id
    $binding = $null
    if ($bindingsById.ContainsKey($playerId)) {
        $binding = $bindingsById[$playerId]
    }
    $skillE = if ($null -ne $binding) { [string]$binding.slot_e } else { "" }
    $skillWide = $null
    if (-not [string]::IsNullOrWhiteSpace($skillE) -and $skillsById.ContainsKey($skillE)) {
        $skillWide = $skillsById[$skillE]
    }

    $rows.Add([pscustomobject]@{
        index                    = $index
        player_id                = $playerId
        display_name             = [string]$p.display_name
        ties                     = [string]$p.ties
        origin_tag               = [string]$p.origin_tag
        mastery_tag              = [string]$p.mastery_tag
        tactic_tag               = [string]$p.tactic_tag
        skill_e                  = $skillE
        e_cost_player_cfg        = To-FloatOrZero $p.skill_e_cost
        e_energy_cost_skill_cfg  = if ($null -ne $skillWide) { To-FloatOrZero $skillWide.energy_cost } else { 0.0 }
        e_cooldown_skill_cfg     = if ($null -ne $skillWide) { To-FloatOrZero $skillWide.cooldown } else { 0.0 }
        target_rounds            = 3
        target_e_pass_rate       = 0.80
        target_feel_avg          = 4.0
        target_balance_avg       = 3.5
        actual_rounds            = ""
        e_pass_count             = ""
        e_fail_count             = ""
        bug_count                = ""
        e_pass_rate              = ""
        feel_avg                 = ""
        balance_avg              = ""
        risk_reward_note         = ""
        status                   = ""
        tester                   = ""
        tested_at                = ""
        note                     = ""
    })
    $index++
}

$outDir = Resolve-OutDir -Root $ProjectRoot -Candidate $OutputDir
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outCsv = Join-Path $outDir "e_balance_template_${stamp}.csv"
$rows | Export-Csv -Path $outCsv -NoTypeInformation -Encoding UTF8

Write-Host "[E-Balance] Template exported: $outCsv"
