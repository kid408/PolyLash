param(
    [string]$ProjectRoot = (Resolve-Path "$PSScriptRoot\..").Path,
    [string]$QuickLogPath = "",
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

function Resolve-QuickLog {
    param(
        [string]$Root,
        [string]$InputPath
    )
    if (-not [string]::IsNullOrWhiteSpace($InputPath)) {
        if (-not (Test-Path $InputPath)) { throw "Quick log not found: $InputPath" }
        return (Resolve-Path $InputPath).Path
    }
    $defaultDir = Join-Path $Root "docs\qa_reports"
    if (-not (Test-Path $defaultDir)) { throw "No qa_reports dir found: $defaultDir" }
    $latest = Get-ChildItem -Path $defaultDir -Filter "qef_quick_log_*.csv" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($null -eq $latest) { throw "No qef_quick_log_*.csv found in: $defaultDir" }
    return $latest.FullName
}

function To-FloatOrZero {
    param([object]$Value)
    if ($null -eq $Value) { return 0.0 }
    $text = [string]$Value
    $num = 0.0
    if ([double]::TryParse($text, [ref]$num)) { return [double]$num }
    return 0.0
}

function To-IntOrZero {
    param([object]$Value)
    if ($null -eq $Value) { return 0 }
    $text = [string]$Value
    $num = 0
    if ([int]::TryParse($text, [ref]$num)) { return [int]$num }
    return 0
}

function Get-Status {
    param(
        [double]$EPassRate,
        [double]$FeelAvg,
        [double]$BalanceAvg,
        [double]$BugRate
    )
    if ($EPassRate -ge 0.80 -and $FeelAvg -ge 4.0 -and $BalanceAvg -ge 3.5 -and $BugRate -le 0.20) {
        return "PASS"
    }
    if ($EPassRate -ge 0.60 -and $FeelAvg -ge 3.0 -and $BalanceAvg -ge 3.0 -and $BugRate -le 0.40) {
        return "WARN"
    }
    return "FAIL"
}

$quickLog = Resolve-QuickLog -Root $ProjectRoot -InputPath $QuickLogPath
$outDir = Resolve-OutDir -Root $ProjectRoot -Candidate $OutputDir

$rowsRaw = Import-Csv -Path $quickLog -Encoding UTF8
if (@($rowsRaw).Count -eq 0) {
    throw "Quick log is empty: $quickLog"
}

$groups = $rowsRaw | Group-Object player_id
$summaryRows = New-Object System.Collections.Generic.List[object]

foreach ($g in $groups) {
    $playerRows = @($g.Group)
    $rounds = $playerRows.Count
    $playerId = [string]$g.Name
    $displayName = [string]($playerRows[0].display_name)
    $ties = [string]($playerRows[0].ties)
    $weaponType = [string]($playerRows[0].weapon_type)
    $skillE = [string]($playerRows[0].skill_e)

    $ePassCount = @($playerRows | Where-Object { To-IntOrZero $_.e_pass -eq 1 }).Count
    $eFailCount = $rounds - $ePassCount
    $bugCount = @($playerRows | Where-Object { To-IntOrZero $_.bug_found_0_1 -eq 1 }).Count
    $feelSum = ($playerRows | Measure-Object -Property feel_score_1_5 -Sum).Sum
    $balanceSum = ($playerRows | Measure-Object -Property balance_score_1_5 -Sum).Sum

    $ePassRate = if ($rounds -gt 0) { [math]::Round($ePassCount / $rounds, 4) } else { 0.0 }
    $bugRate = if ($rounds -gt 0) { [math]::Round($bugCount / $rounds, 4) } else { 0.0 }
    $feelAvg = if ($rounds -gt 0) { [math]::Round((To-FloatOrZero $feelSum) / $rounds, 3) } else { 0.0 }
    $balanceAvg = if ($rounds -gt 0) { [math]::Round((To-FloatOrZero $balanceSum) / $rounds, 3) } else { 0.0 }

    $status = Get-Status -EPassRate $ePassRate -FeelAvg $feelAvg -BalanceAvg $balanceAvg -BugRate $bugRate

    $summaryRows.Add([pscustomobject]@{
        player_id         = $playerId
        display_name      = $displayName
        ties              = $ties
        weapon_type       = $weaponType
        skill_e           = $skillE
        rounds            = $rounds
        e_pass_count      = $ePassCount
        e_fail_count      = $eFailCount
        bug_count         = $bugCount
        e_pass_rate       = $ePassRate
        bug_rate          = $bugRate
        feel_avg          = $feelAvg
        balance_avg       = $balanceAvg
        status            = $status
    })
}

$ordered = $summaryRows | Sort-Object `
    @{Expression = "status"; Descending = $false }, `
    @{Expression = "e_pass_rate"; Descending = $true }, `
    @{Expression = "balance_avg"; Descending = $true }, `
    @{Expression = "feel_avg"; Descending = $true }

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$summaryCsv = Join-Path $outDir "e_balance_summary_${stamp}.csv"
$summaryMd = Join-Path $outDir "e_balance_summary_${stamp}.md"

$ordered | Export-Csv -Path $summaryCsv -NoTypeInformation -Encoding UTF8

$passCount = @($ordered | Where-Object { $_.status -eq "PASS" }).Count
$warnCount = @($ordered | Where-Object { $_.status -eq "WARN" }).Count
$failCount = @($ordered | Where-Object { $_.status -eq "FAIL" }).Count
$total = @($ordered).Count

$mdLines = New-Object System.Collections.Generic.List[string]
$mdLines.Add("# E Skill Balance Summary")
$mdLines.Add("")
$mdLines.Add("- Generated At: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$mdLines.Add("- Source Quick Log: $quickLog")
$mdLines.Add("- Player Count: $total")
$mdLines.Add("- PASS/WARN/FAIL: $passCount / $warnCount / $failCount")
$mdLines.Add("")
$mdLines.Add("| player_id | display_name | skill_e | rounds | e_pass_rate | bug_rate | feel_avg | balance_avg | status |")
$mdLines.Add("|---|---|---|---:|---:|---:|---:|---:|---|")
foreach ($r in $ordered) {
    $mdLines.Add("| $($r.player_id) | $($r.display_name) | $($r.skill_e) | $($r.rounds) | $($r.e_pass_rate) | $($r.bug_rate) | $($r.feel_avg) | $($r.balance_avg) | $($r.status) |")
}

$mdLines | Set-Content -Path $summaryMd -Encoding UTF8

Write-Host "[E-Balance] Source quick log: $quickLog"
Write-Host "[E-Balance] Summary CSV: $summaryCsv"
Write-Host "[E-Balance] Summary MD:  $summaryMd"
