param(
	[string]$UserDataRoot = "",
	[string]$SourceJsonl = "",
	[string]$OutputCsv = "docs/重构执行拆分/bond_balance_10runs_runtime_export.csv",
	[int]$TakeLatest = 10
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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

if ([string]::IsNullOrWhiteSpace($UserDataRoot)) {
	if ([string]::IsNullOrWhiteSpace($env:APPDATA)) {
		throw "APPDATA is empty; cannot infer Godot user data path."
	}
	$UserDataRoot = Join-Path $env:APPDATA "Godot\app_userdata\PolyLash"
}
$UserDataRoot = Resolve-InputPath -PathText $UserDataRoot

if ([string]::IsNullOrWhiteSpace($SourceJsonl)) {
	$SourceJsonl = Join-Path $UserDataRoot "bond_balance_runs.jsonl"
} else {
	$SourceJsonl = Resolve-InputPath -PathText $SourceJsonl
}

$OutputCsv = Resolve-InputPath -PathText $OutputCsv

if (-not (Test-Path $SourceJsonl)) {
	throw "run jsonl not found: $SourceJsonl"
}

$lines = Get-Content -Path $SourceJsonl -Encoding UTF8 | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
if ($lines.Count -eq 0) {
	throw "run jsonl is empty: $SourceJsonl"
}

$rows = New-Object System.Collections.Generic.List[object]
foreach ($line in $lines) {
	try {
		$obj = $line | ConvertFrom-Json
		[void]$rows.Add($obj)
	} catch {
		Write-Warning ("skip invalid line: {0}" -f $line)
	}
}

if ($rows.Count -eq 0) {
	throw "no valid run rows parsed from: $SourceJsonl"
}

$sorted = $rows | Sort-Object -Property @{
	Expression = {
		$unix = 0.0
		[double]::TryParse([string]$_.created_at_unix, [ref]$unix) | Out-Null
		$unix
	}
	Descending = $true
}

$take = if ($TakeLatest -gt 0) { $TakeLatest } else { 10 }
$picked = $sorted | Select-Object -First $take

$exportRows = New-Object System.Collections.Generic.List[object]
$pickedOrdered = @($picked)
[array]::Reverse($pickedOrdered)
foreach ($item in $pickedOrdered) {
	$durationMin = $null
	if ($item.PSObject.Properties.Name -contains "duration_min") {
		$durationMin = [string]$item.duration_min
	} elseif ($item.PSObject.Properties.Name -contains "duration_sec") {
		$sec = 0.0
		[double]::TryParse([string]$item.duration_sec, [ref]$sec) | Out-Null
		$durationMin = [Math]::Round($sec / 60.0, 2)
	}

	$cleared = 0
	if ([bool]$item.cleared) {
		$cleared = 1
	}

	$resonancePlayersText = ""
	if ($item.PSObject.Properties.Name -contains "resonance_players_verified") {
		$list = @($item.resonance_players_verified)
		$resonancePlayersText = ($list | ForEach-Object { [string]$_ } | Where-Object { $_ -ne "" }) -join "|"
	}
	if ([string]::IsNullOrWhiteSpace($resonancePlayersText) -and ($item.PSObject.Properties.Name -contains "resonance_players")) {
		$keys = @($item.resonance_players.PSObject.Properties.Name)
		$resonancePlayersText = ($keys | ForEach-Object { [string]$_ } | Where-Object { $_ -ne "" }) -join "|"
	}

	$row = [PSCustomObject]@{
		run_id = [string]$item.run_id
		date = [string]$item.date
		team_comp = [string]$item.team_comp
		duration_min = $durationMin
		highest_wave = [string]$item.highest_wave
		cleared = $cleared
		lv2plus_triggers = [string]$item.lv2plus_triggers
		lv3_triggers = [string]$item.lv3_triggers
		bond_feedback_score = ""
		resonance_players_verified = $resonancePlayersText
		notes = [string]$item.end_reason
	}
	[void]$exportRows.Add($row)
}

$outDir = Split-Path -Parent $OutputCsv
if ($outDir -and -not (Test-Path $outDir)) {
	New-Item -Path $outDir -ItemType Directory -Force | Out-Null
}

$exportRows | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Host "Export done."
Write-Host ("Source JSONL: {0}" -f (Resolve-Path $SourceJsonl).Path)
Write-Host ("Output CSV : {0}" -f (Resolve-Path $OutputCsv).Path)
Write-Host ("Rows       : {0}" -f $exportRows.Count)
