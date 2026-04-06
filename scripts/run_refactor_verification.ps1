param(
	[string]$RepoRoot = "",
	[string]$StateFile = "",
	[string]$ReportJson = "",
	[string]$ReportMd = "",
	[string]$GodotPath = "",
	[switch]$SkipGodot,
	[switch]$Promote,
	[switch]$ManualChecksPassed,
	[string]$Verifier = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-RepoRoot {
	param([string]$InputRoot)
	if (-not [string]::IsNullOrWhiteSpace($InputRoot)) {
		return (Resolve-Path $InputRoot).Path
	}
	return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Resolve-InputPath {
	param(
		[string]$Root,
		[string]$InputPath
	)
	if ([string]::IsNullOrWhiteSpace($InputPath)) {
		return ""
	}
	if ([System.IO.Path]::IsPathRooted($InputPath)) {
		return $InputPath
	}
	return (Join-Path $Root $InputPath)
}

function Find-StateFile {
	param(
		[string]$Root,
		[string]$InputPath
	)
	$resolved = Resolve-InputPath -Root $Root -InputPath $InputPath
	if (-not [string]::IsNullOrWhiteSpace($resolved)) {
		return $resolved
	}

	$docsDir = Join-Path $Root "docs"
	if (Test-Path $docsDir) {
		$candidate = Get-ChildItem -Path $docsDir -Filter "session_state.yaml" -Recurse -File -ErrorAction SilentlyContinue |
			Sort-Object FullName |
			Select-Object -First 1
		if ($candidate) {
			return $candidate.FullName
		}
	}

	return (Join-Path $Root "docs/session_state.yaml")
}

function Resolve-ReportPath {
	param(
		[string]$Root,
		[string]$InputPath,
		[string]$DefaultDir,
		[string]$DefaultName
	)
	$resolved = Resolve-InputPath -Root $Root -InputPath $InputPath
	if (-not [string]::IsNullOrWhiteSpace($resolved)) {
		return $resolved
	}
	return (Join-Path $DefaultDir $DefaultName)
}

function Ensure-ParentDirectory {
	param([string]$Path)
	$parent = Split-Path -Parent $Path
	if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path $parent)) {
		New-Item -ItemType Directory -Path $parent -Force | Out-Null
	}
}

function Add-Check {
	param(
		[ref]$Checks,
		[string]$Id,
		[string]$Description,
		[bool]$Passed,
		[string]$Details,
		[string]$Severity = "required",
		[bool]$Gate = $true
	)
	$Checks.Value += [PSCustomObject]@{
		id = $Id
		description = $Description
		passed = $Passed
		details = $Details
		severity = $Severity
		gate = $Gate
	}
}

function Test-Contains {
	param(
		[string]$Path,
		[string]$Pattern,
		[switch]$Regex
	)
	if (-not (Test-Path $Path)) {
		return $false
	}
	if ($Regex) {
		return [bool](Select-String -Path $Path -Pattern $Pattern -ErrorAction SilentlyContinue)
	}
	return [bool](Select-String -Path $Path -Pattern $Pattern -SimpleMatch -ErrorAction SilentlyContinue)
}

function Test-AutoloadRegistration {
	param(
		[string]$ProjectPath,
		[string]$AutoloadName,
		[string]$ScriptRelativePath
	)
	if (-not (Test-Path $ProjectPath)) {
		return $false
	}
	$content = Get-Content -Path $ProjectPath -Raw -Encoding UTF8
	$pattern = "(?m)^\s*" + [regex]::Escape($AutoloadName) + "\s*=\s*`"\*?res://" + [regex]::Escape($ScriptRelativePath) + "`"\s*$"
	return [bool][regex]::IsMatch($content, $pattern)
}

function Test-CsvHeaderHasColumn {
	param(
		[string]$Path,
		[string]$Column
	)
	if (-not (Test-Path $Path)) {
		return $false
	}
	$header = Get-Content -Path $Path -TotalCount 1 -Encoding UTF8
	if ([string]::IsNullOrWhiteSpace($header)) {
		return $false
	}
	$columns = $header.Split(",") | ForEach-Object { $_.Trim().Trim('"') }
	return ($columns -contains $Column)
}

function Test-NoLegacyQBindings {
	param(
		[string]$Path,
		[string[]]$LegacySkillIds,
		[ref]$FoundLegacy
	)
	$FoundLegacy.Value = @()
	if (-not (Test-Path $Path)) {
		return $false
	}
	if ($null -eq $LegacySkillIds -or $LegacySkillIds.Count -eq 0) {
		return $true
	}

	$rows = Import-Csv -Path $Path -Encoding UTF8
	$found = New-Object System.Collections.Generic.HashSet[string]
	foreach ($row in $rows) {
		$slotQ = [string]$row.slot_q
		if ([string]::IsNullOrWhiteSpace($slotQ)) {
			continue
		}
		if ($LegacySkillIds -contains $slotQ) {
			[void]$found.Add($slotQ)
		}
	}

	$FoundLegacy.Value = @($found | Sort-Object)
	return ($found.Count -eq 0)
}

function Promote-SessionState {
	param(
		[string]$Path,
		[string]$DateText
	)
	if (-not (Test-Path $Path)) {
		throw "state file not found: $Path"
	}

	$lines = Get-Content -Path $Path -Encoding UTF8
	$updated = 0
	$out = New-Object System.Collections.Generic.List[string]

	foreach ($line in $lines) {
		if ($line -match "^last_updated:\s*") {
			$out.Add("last_updated: $DateText")
			continue
		}

		if ($line -match "^\s{4}status:\s*implemented_unverified\s*$") {
			$out.Add("    status: verified")
			$updated += 1
			continue
		}

		$out.Add($line)
	}

	Set-Content -Path $Path -Encoding UTF8 -Value $out
	return $updated
}

function Detect-GodotBinary {
	param([string]$InputPath)
	if (-not [string]::IsNullOrWhiteSpace($InputPath)) {
		if (Test-Path $InputPath) {
			return (Resolve-Path $InputPath).Path
		}
		return ""
	}

	foreach ($envName in @("GODOT_PATH", "GODOT_BIN")) {
		$envPath = [Environment]::GetEnvironmentVariable($envName)
		if (-not [string]::IsNullOrWhiteSpace($envPath) -and (Test-Path $envPath)) {
			return (Resolve-Path $envPath).Path
		}
	}

	foreach ($name in @("godot", "godot4")) {
		$cmd = Get-Command $name -ErrorAction SilentlyContinue
		if ($cmd -and $cmd.Source) {
			return $cmd.Source
		}
	}

	# Workspace fallback candidates for Windows local setup.
	foreach ($candidate in @(
		"D:\wanglei\Godot\Godot_v4.6.1-stable_win64.exe",
		"D:\wanglei\Godot\Godot.exe"
	)) {
		if (Test-Path $candidate) {
			return (Resolve-Path $candidate).Path
		}
	}

	return ""
}

function Escape-Markdown {
	param([string]$Text)
	if ($null -eq $Text) {
		return ""
	}
	$safe = $Text -replace "\|", "\\|"
	$safe = $safe -replace "(\r\n|\n|\r)", "<br>"
	return $safe
}

$RepoRoot = Resolve-RepoRoot -InputRoot $RepoRoot
Set-Location $RepoRoot

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$dateOnly = Get-Date -Format "yyyy-MM-dd"

$statePath = Find-StateFile -Root $RepoRoot -InputPath $StateFile
$stateDir = Split-Path -Parent $statePath

$reportJsonPath = Resolve-ReportPath -Root $RepoRoot -InputPath $ReportJson -DefaultDir $stateDir -DefaultName "verification_report.json"
$reportMdPath = Resolve-ReportPath -Root $RepoRoot -InputPath $ReportMd -DefaultDir $stateDir -DefaultName "verification_report.md"
Ensure-ParentDirectory -Path $reportJsonPath
Ensure-ParentDirectory -Path $reportMdPath

if ([string]::IsNullOrWhiteSpace($Verifier)) {
	$Verifier = $env:USERNAME
	if ([string]::IsNullOrWhiteSpace($Verifier)) {
		$Verifier = "unknown"
	}
}

$checks = @()

Add-Check -Checks ([ref]$checks) -Id "file_progression_manager" -Description "progression manager file exists" -Passed (Test-Path "autoloads/progression_manager.gd") -Details "autoloads/progression_manager.gd"
Add-Check -Checks ([ref]$checks) -Id "autoload_progression_manager" -Description "project autoload includes ProgressionManager" -Passed (Test-AutoloadRegistration -ProjectPath "project.godot" -AutoloadName "ProgressionManager" -ScriptRelativePath "autoloads/progression_manager.gd") -Details "project.godot [autoload]"
Add-Check -Checks ([ref]$checks) -Id "arena_levelup_hook" -Description "arena has progression level up hook" -Passed (Test-Contains -Path "scenes/arena/arena.gd" -Pattern "_on_progression_level_up") -Details "scenes/arena/arena.gd"
Add-Check -Checks ([ref]$checks) -Id "skill_tags_column" -Description "skill csv has tags column" -Passed (Test-CsvHeaderHasColumn -Path "config/player/skill_params_wide.csv" -Column "tags") -Details "config/player/skill_params_wide.csv header"
Add-Check -Checks ([ref]$checks) -Id "skill_base_tags" -Description "skill base stores skill_tags" -Passed (Test-Contains -Path "scenes/skills/skill_base.gd" -Pattern "var skill_tags: Array[String] = []") -Details "scenes/skills/skill_base.gd"
Add-Check -Checks ([ref]$checks) -Id "skill_manager_tags" -Description "skill manager loads and infers tags" -Passed ((Test-Contains -Path "scenes/skills/skill_manager.gd" -Pattern 'if "tags" in params:') -and (Test-Contains -Path "scenes/skills/skill_manager.gd" -Pattern "_infer_default_skill_tags")) -Details "scenes/skills/skill_manager.gd"
	$legacyQIds = @("skill_saw_path", "skill_web_weave", "skill_mine_path")
	$foundLegacyQ = @()
	$noLegacyQBinding = Test-NoLegacyQBindings -Path "config/player/player_skill_bindings.csv" -LegacySkillIds $legacyQIds -FoundLegacy ([ref]$foundLegacyQ)
	$legacyQDetails = if ($noLegacyQBinding) { "none" } else { ($foundLegacyQ -join ",") }
	Add-Check -Checks ([ref]$checks) -Id "legacy_q_bindings" -Description "legacy Q bindings migrated to refactored ids" -Passed $noLegacyQBinding -Details ("config/player/player_skill_bindings.csv; legacy={0}" -f $legacyQDetails)
Add-Check -Checks ([ref]$checks) -Id "shop_interval" -Description "shop interval is every 2 waves" -Passed (Test-Contains -Path "scenes/arena/services/shop_flow_service.gd" -Pattern "const SHOP_INTERVAL_WAVES: int = 2") -Details "scenes/arena/services/shop_flow_service.gd"
Add-Check -Checks ([ref]$checks) -Id "flow_controller_split" -Description "battle flow controller and sub services exist" -Passed ((Test-Path "scenes/arena/battle_flow_controller.gd") -and (Test-Path "scenes/arena/services/shop_flow_service.gd") -and (Test-Path "scenes/arena/services/reward_flow_service.gd") -and (Test-Path "scenes/arena/services/run_save_service.gd")) -Details "scenes/arena/services/*"
Add-Check -Checks ([ref]$checks) -Id "run_meta_service" -Description "run and meta state services exist" -Passed ((Test-Path "autoloads/run_state_service.gd") -and (Test-Path "autoloads/meta_progress_service.gd")) -Details "autoloads/run_state_service.gd, autoloads/meta_progress_service.gd"
Add-Check -Checks ([ref]$checks) -Id "shop_pipeline" -Description "shop domain service and effect pipeline exist" -Passed ((Test-Path "autoloads/shop_domain_service.gd") -and (Test-Path "autoloads/purchase_effect_pipeline.gd")) -Details "autoloads/shop_domain_service.gd, autoloads/purchase_effect_pipeline.gd"
Add-Check -Checks ([ref]$checks) -Id "bond_config_file" -Description "bond config exists" -Passed (Test-Path "config/player/bond_config.csv") -Details "config/player/bond_config.csv"
Add-Check -Checks ([ref]$checks) -Id "bond_resonance_file" -Description "bond resonance config exists" -Passed (Test-Path "config/player/bond_resonance_config.csv") -Details "config/player/bond_resonance_config.csv"
Add-Check -Checks ([ref]$checks) -Id "resonance_runtime" -Description "resonance runtime service exists and is autoloaded" -Passed ((Test-Path "autoloads/resonance_runtime_service.gd") -and (Test-AutoloadRegistration -ProjectPath "project.godot" -AutoloadName "ResonanceRuntimeService" -ScriptRelativePath "autoloads/resonance_runtime_service.gd")) -Details "autoloads/resonance_runtime_service.gd + project.godot"
Add-Check -Checks ([ref]$checks) -Id "run_telemetry_service" -Description "run telemetry service exists and is autoloaded" -Passed ((Test-Path "autoloads/run_telemetry_service.gd") -and (Test-AutoloadRegistration -ProjectPath "project.godot" -AutoloadName "RunTelemetryService" -ScriptRelativePath "autoloads/run_telemetry_service.gd")) -Details "autoloads/run_telemetry_service.gd + project.godot"
$docsIgnored = Test-Path "docs/.gdignore"
Add-Check -Checks ([ref]$checks) -Id "docs_gdignore" -Description "docs folder is ignored by Godot importer" -Passed $docsIgnored -Details "docs/.gdignore"
$docTranslationArtifacts = @()
foreach ($artifactPath in @(
	"docs/重构执行拆分/bond_balance_10runs_template.csv.import",
	"docs/重构执行拆分/bond_balance_10runs_template.en.translation"
)) {
	if (Test-Path $artifactPath) {
		$docTranslationArtifacts += $artifactPath
	}
}
$docImportCacheCount = 0
if (Test-Path ".godot/imported") {
	$docImportCacheCount = @(Get-ChildItem -Path ".godot/imported" -File -Filter "bond_balance_10runs_template.csv-*.md5" -ErrorAction SilentlyContinue).Count
}
if ($docImportCacheCount -gt 0) {
	$docTranslationArtifacts += ".godot/imported/bond_balance_10runs_template.csv-*.md5"
}
$noDocTranslationArtifacts = ($docTranslationArtifacts.Count -eq 0)
$docTranslationDetails = if ($noDocTranslationArtifacts) { "none" } else { ($docTranslationArtifacts -join ",") }
Add-Check -Checks ([ref]$checks) -Id "no_doc_translation_artifacts" -Description "docs sample csv is not imported as translation resource" -Passed $noDocTranslationArtifacts -Details $docTranslationDetails
Add-Check -Checks ([ref]$checks) -Id "enemy_wave_configs" -Description "enemy and wave configs exist" -Passed ((Test-Path "config/enemy/enemy_config.csv") -and (Test-Path "config/wave/wave_config.csv") -and (Test-Path "config/wave/wave_units_config.csv")) -Details "config/enemy/enemy_config.csv + config/wave/*.csv"
Add-Check -Checks ([ref]$checks) -Id "spawner_budget" -Description "spawner has budget and role caps" -Passed ((Test-Contains -Path "scenes/arena/spawner.gd" -Pattern "_calc_wave_budget") -and (Test-Contains -Path "scenes/arena/spawner.gd" -Pattern "ROLE_CAPS")) -Details "scenes/arena/spawner.gd"
Add-Check -Checks ([ref]$checks) -Id "boss_phase_config" -Description "boss phase config template exists" -Passed (Test-Path "config/enemy/boss_phase_config.csv") -Details "config/enemy/boss_phase_config.csv"
Add-Check -Checks ([ref]$checks) -Id "boss_phase_runtime" -Description "enemy runtime includes boss phase template hooks" -Passed ((Test-Contains -Path "scenes/unit/enemy/enemy.gd" -Pattern "_init_boss_phase_template") -and (Test-Contains -Path "scenes/unit/enemy/enemy.gd" -Pattern "_process_boss_phase_template")) -Details "scenes/unit/enemy/enemy.gd"

$arenaLines = (Get-Content -Path "scenes/arena/arena.gd" -Encoding UTF8 | Measure-Object -Line).Lines
Add-Check -Checks ([ref]$checks) -Id "arena_line_budget" -Description "arena lines <= 400 (architecture target)" -Passed ($arenaLines -le 400) -Details ("current={0}" -f $arenaLines) -Severity "warn" -Gate $false

$godotBin = Detect-GodotBinary -InputPath $GodotPath
if ($SkipGodot) {
	Add-Check -Checks ([ref]$checks) -Id "godot_smoke" -Description "godot smoke test skipped" -Passed $true -Details "skip by -SkipGodot" -Severity "warn" -Gate $false
} else {
	if ([string]::IsNullOrWhiteSpace($godotBin)) {
		Add-Check -Checks ([ref]$checks) -Id "godot_smoke" -Description "godot smoke test" -Passed $false -Details "godot/godot4 not found in PATH" -Severity "required" -Gate $true
	} else {
		$godotOk = $true
		$godotDetails = ""
		$godotStdoutPath = Join-Path $stateDir "godot_smoke_stdout.log"
		$godotStderrPath = Join-Path $stateDir "godot_smoke_stderr.log"
		$godotEngineLogPath = Join-Path $stateDir "godot_smoke_engine.log"
		try {
			Remove-Item $godotStdoutPath,$godotStderrPath,$godotEngineLogPath -ErrorAction SilentlyContinue
			$proc = Start-Process -FilePath $godotBin `
				-ArgumentList @("--headless", "--path", $RepoRoot, "--log-file", $godotEngineLogPath, "--quit") `
				-PassThru `
				-NoNewWindow `
				-RedirectStandardOutput $godotStdoutPath `
				-RedirectStandardError $godotStderrPath
			$proc.WaitForExit()
			$exitCode = if ($null -ne $proc.ExitCode) { [int]$proc.ExitCode } else { 0 }

			$stdoutLines = @()
			$stderrLines = @()
			if (Test-Path $godotStdoutPath) {
				$stdoutLines = @(Get-Content -Path $godotStdoutPath -Encoding UTF8)
			}
			if (Test-Path $godotStderrPath) {
				$stderrLines = @(Get-Content -Path $godotStderrPath -Encoding UTF8)
			}
			$godotLines = @($stdoutLines + $stderrLines)
			# 清理 ANSI 颜色控制字符，避免误判正则。
			$godotLines = @($godotLines | ForEach-Object { [regex]::Replace($_, "\x1b\[[0-9;]*m", "") })

			$errorLines = @($godotLines | Where-Object {
				$_ -match "SCRIPT ERROR:" -or
				$_ -match "Parse Error:" -or
				$_ -match "Compile Error:" -or
				$_ -match "^ERROR:"
			})
			# 一些环境下 user://logs 不可写会出现该错误，但不影响脚本编译冒烟。
			$errorLines = @($errorLines | Where-Object { $_ -notmatch "^\s*ERROR:\s+Failed to open 'user://logs/.*\.log'\.$" })
			# Windows 沙箱/系统证书不可读会抛此错误，与 GDScript 编译无关，作为环境噪声忽略。
			$errorLines = @($errorLines | Where-Object { $_ -notmatch "^\s*ERROR:\s+Failed to read the root certificate store\.$" })
			$errorLines = @($errorLines | Where-Object { $_ -notmatch "root certificate store" })
			$crashLines = @($godotLines | Where-Object {
				$_ -match "CrashHandlerException" -or
				$_ -match "signal\s+11" -or
				$_ -match "Dumping the backtrace"
			})
			$warningCount = @($godotLines | Where-Object { $_ -match "WARNING:" }).Count

			if ($exitCode -ne 0 -or $errorLines.Count -gt 0 -or $crashLines.Count -gt 0) {
				$godotOk = $false
				$firstError = if ($errorLines.Count -gt 0) { $errorLines[0] } else { "none" }
				$firstCrash = if ($crashLines.Count -gt 0) { $crashLines[0] } else { "none" }
				$godotDetails = "exit_code=$exitCode; errors=$($errorLines.Count); crashes=$($crashLines.Count); warnings=$warningCount; first_error=$firstError; first_crash=$firstCrash; stdout=$godotStdoutPath; stderr=$godotStderrPath; engine_log=$godotEngineLogPath"
			} else {
				$godotDetails = "exit_code=$exitCode; errors=0; crashes=0; warnings=$warningCount; stdout=$godotStdoutPath; stderr=$godotStderrPath; engine_log=$godotEngineLogPath"
			}
		} catch {
			$godotOk = $false
			$godotDetails = $_.Exception.Message
		}
		Add-Check -Checks ([ref]$checks) -Id "godot_smoke" -Description "godot smoke test" -Passed $godotOk -Details ("bin={0}; {1}" -f $godotBin, $godotDetails) -Severity "required" -Gate $true
	}
}

$passed = @($checks | Where-Object { $_.passed }).Count
$failed = @($checks | Where-Object { -not $_.passed }).Count
$gateFailed = @($checks | Where-Object { (-not $_.passed) -and $_.gate }).Count

$promoted = $false
$promoteReason = ""

if ($Promote) {
	if (-not $ManualChecksPassed) {
		$promoteReason = "missing -ManualChecksPassed"
	} elseif ($gateFailed -gt 0) {
		$promoteReason = "gate checks failed: $gateFailed"
	} elseif (-not (Test-Path $statePath)) {
		$promoteReason = "session_state.yaml not found"
	} else {
		$updatedCount = Promote-SessionState -Path $statePath -DateText $dateOnly
		$promoted = $true
		$promoteReason = "updated statuses: $updatedCount"
	}
} else {
	$promoteReason = "not requested"
}

$report = [ordered]@{
	generated_at = $timestamp
	repo_root = $RepoRoot
	state_file = $statePath
	verifier = $Verifier
	promote_requested = [bool]$Promote
	manual_checks_passed = [bool]$ManualChecksPassed
	promoted = $promoted
	promote_reason = $promoteReason
	summary = [ordered]@{
		total = $checks.Count
		passed = $passed
		failed = $failed
		gate_failed = $gateFailed
	}
	checks = $checks
}

$jsonText = $report | ConvertTo-Json -Depth 8
Set-Content -Path $reportJsonPath -Encoding UTF8 -Value $jsonText

$md = New-Object System.Collections.Generic.List[string]
$md.Add("# Refactor Verification Report")
$md.Add("")
$md.Add("- Generated At: $timestamp")
$md.Add("- Verifier: $Verifier")
$md.Add("- State File: $statePath")
$md.Add("- Total Checks: $($checks.Count)")
$md.Add("- Passed: $passed")
$md.Add("- Failed: $failed")
$md.Add("- Gate Failed: $gateFailed")
$md.Add("- Promoted: $promoted")
$md.Add("- Promote Reason: $promoteReason")
$md.Add("")
$md.Add("## Checks")
$md.Add("")
$md.Add("| ID | Result | Gate | Description | Details |")
$md.Add("|---|---|---|---|---|")
foreach ($c in $checks) {
	$result = if ($c.passed) { "PASS" } else { "FAIL" }
	$gateText = if ($c.gate) { "Y" } else { "N" }
	$md.Add("| $($c.id) | $result | $gateText | $(Escape-Markdown $c.description) | $(Escape-Markdown $c.details) |")
}
$md.Add("")
$md.Add("## Failed Items")
$md.Add("")
$failedItems = @($checks | Where-Object { -not $_.passed })
if ($failedItems.Count -eq 0) {
	$md.Add("- none")
} else {
	foreach ($f in $failedItems) {
		$md.Add("- [$($f.id)] $($f.description) :: $($f.details)")
	}
}

Set-Content -Path $reportMdPath -Encoding UTF8 -Value $md

Write-Host "Verification done."
Write-Host ("Report JSON: {0}" -f $reportJsonPath)
Write-Host ("Report MD  : {0}" -f $reportMdPath)
Write-Host ("Summary    : total={0}, pass={1}, fail={2}, gate_fail={3}" -f $checks.Count, $passed, $failed, $gateFailed)
if ($Promote) {
	Write-Host ("Promote    : {0} ({1})" -f $promoted, $promoteReason)
}
