param(
	[string]$SampleCsv = "",
	[string]$OutputJson = "",
	[string]$OutputMd = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Parse-Number {
	param([string]$Text)
	if ([string]::IsNullOrWhiteSpace($Text)) {
		return $null
	}
	$parsed = 0.0
	if ([double]::TryParse($Text, [ref]$parsed)) {
		return $parsed
	}
	return $null
}

function Parse-Bool01 {
	param([string]$Text)
	if ([string]::IsNullOrWhiteSpace($Text)) {
		return $null
	}
	$val = $Text.Trim().ToLower()
	if ($val -in @("1", "true", "yes", "y")) {
		return $true
	}
	if ($val -in @("0", "false", "no", "n")) {
		return $false
	}
	return $null
}

function Resolve-InputPath {
	param([string]$PathText)
	if ([string]::IsNullOrWhiteSpace($PathText)) {
		return ""
	}
	if ([System.IO.Path]::IsPathRooted($PathText)) {
		return $PathText
	}
	return (Join-Path (Get-Location).Path $PathText)
}

$resolvedSample = Resolve-InputPath -PathText $SampleCsv
if ([string]::IsNullOrWhiteSpace($resolvedSample)) {
	$candidate = Get-ChildItem -Path "docs" -Recurse -File -Filter "bond_balance_10runs_template.csv" -ErrorAction SilentlyContinue |
		Sort-Object FullName |
		Select-Object -First 1
	if ($candidate) {
		$resolvedSample = $candidate.FullName
	}
}

if ([string]::IsNullOrWhiteSpace($resolvedSample) -or -not (Test-Path $resolvedSample)) {
	throw "sample csv not found: $SampleCsv"
}

$SampleCsv = (Resolve-Path $resolvedSample).Path
$sampleDir = Split-Path -Parent $SampleCsv

if ([string]::IsNullOrWhiteSpace($OutputJson)) {
	$OutputJson = Join-Path $sampleDir "bond_balance_10runs_summary.json"
} else {
	$OutputJson = Resolve-InputPath -PathText $OutputJson
}

if ([string]::IsNullOrWhiteSpace($OutputMd)) {
	$OutputMd = Join-Path $sampleDir "bond_balance_10runs_summary.md"
} else {
	$OutputMd = Resolve-InputPath -PathText $OutputMd
}

$rows = Import-Csv -Path $SampleCsv -Encoding UTF8
if ($rows.Count -eq 0) {
	throw "sample csv has no rows: $SampleCsv"
}

$durations = New-Object System.Collections.Generic.List[double]
$waves = New-Object System.Collections.Generic.List[double]
$lv2plus = New-Object System.Collections.Generic.List[double]
$lv3 = New-Object System.Collections.Generic.List[double]
$scores = New-Object System.Collections.Generic.List[double]
$clearedCount = 0
$validClearRows = 0
$runsLv2plusAtLeast6 = 0
$resonancePlayers = New-Object System.Collections.Generic.HashSet[string]

foreach ($row in $rows) {
	$duration = Parse-Number -Text $row.duration_min
	if ($null -ne $duration) { [void]$durations.Add($duration) }

	$wave = Parse-Number -Text $row.highest_wave
	if ($null -ne $wave) { [void]$waves.Add($wave) }

	$lv2 = Parse-Number -Text $row.lv2plus_triggers
	if ($null -ne $lv2) {
		[void]$lv2plus.Add($lv2)
		if ($lv2 -ge 6) { $runsLv2plusAtLeast6 += 1 }
	}

	$lv3n = Parse-Number -Text $row.lv3_triggers
	if ($null -ne $lv3n) { [void]$lv3.Add($lv3n) }

	$score = Parse-Number -Text $row.bond_feedback_score
	if ($null -ne $score) { [void]$scores.Add($score) }

	$clearVal = Parse-Bool01 -Text $row.cleared
	if ($null -ne $clearVal) {
		$validClearRows += 1
		if ($clearVal) { $clearedCount += 1 }
	}

	$verifiedText = [string]$row.resonance_players_verified
	if (-not [string]::IsNullOrWhiteSpace($verifiedText)) {
		$tokens = $verifiedText -split "[,;|/\s]+"
		foreach ($token in $tokens) {
			$id = $token.Trim().ToLower()
			if (-not [string]::IsNullOrWhiteSpace($id)) {
				[void]$resonancePlayers.Add($id)
			}
		}
	}
}

function Avg-Or-Null {
	param([System.Collections.Generic.List[double]]$Values)
	if ($Values.Count -eq 0) { return $null }
	return [Math]::Round(($Values | Measure-Object -Average).Average, 2)
}

$clearRate = $null
if ($validClearRows -gt 0) {
	$clearRate = [Math]::Round(($clearedCount * 100.0 / $validClearRows), 2)
}

$summary = [ordered]@{
	generated_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
	source_csv = (Resolve-Path $SampleCsv).Path
	total_rows = $rows.Count
	metrics = [ordered]@{
		avg_duration_min = Avg-Or-Null -Values $durations
		avg_highest_wave = Avg-Or-Null -Values $waves
		avg_lv2plus_triggers = Avg-Or-Null -Values $lv2plus
		avg_lv3_triggers = Avg-Or-Null -Values $lv3
		avg_bond_feedback_score = Avg-Or-Null -Values $scores
		cleared_count = $clearedCount
		valid_clear_rows = $validClearRows
		clear_rate_percent = $clearRate
		runs_lv2plus_ge_6 = $runsLv2plusAtLeast6
		resonance_verified_unique_players = $resonancePlayers.Count
		resonance_verified_player_ids = @($resonancePlayers | Sort-Object)
	}
}

$summaryJson = $summary | ConvertTo-Json -Depth 8
$jsonParent = Split-Path -Parent $OutputJson
if ($jsonParent -and -not (Test-Path $jsonParent)) {
	New-Item -Path $jsonParent -ItemType Directory -Force | Out-Null
}
Set-Content -Path $OutputJson -Value $summaryJson -Encoding UTF8

$m = $summary.metrics
$md = @(
	"# Bond 10-Runs Summary",
	"",
	"- Generated At: $($summary.generated_at)",
	"- Source CSV: $($summary.source_csv)",
	"- Total Rows: $($summary.total_rows)",
	"",
	"## Metrics",
	"",
	"- Avg Duration (min): $($m.avg_duration_min)",
	"- Avg Highest Wave: $($m.avg_highest_wave)",
	"- Avg Lv2+ Triggers: $($m.avg_lv2plus_triggers)",
	"- Avg Lv3 Triggers: $($m.avg_lv3_triggers)",
	"- Avg Bond Feedback Score: $($m.avg_bond_feedback_score)",
	"- Clear Rate: $($m.clear_rate_percent)% ($($m.cleared_count)/$($m.valid_clear_rows))",
	"- Runs with Lv2+ >= 6: $($m.runs_lv2plus_ge_6)",
	"- Resonance Verified Unique Players: $($m.resonance_verified_unique_players)",
	"",
	"## Resonance Player IDs",
	"",
	($m.resonance_verified_player_ids -join ", ")
)

$mdParent = Split-Path -Parent $OutputMd
if ($mdParent -and -not (Test-Path $mdParent)) {
	New-Item -Path $mdParent -ItemType Directory -Force | Out-Null
}
Set-Content -Path $OutputMd -Value $md -Encoding UTF8

Write-Host "Summary done."
Write-Host ("Output JSON: {0}" -f (Resolve-Path $OutputJson).Path)
Write-Host ("Output MD  : {0}" -f (Resolve-Path $OutputMd).Path)
