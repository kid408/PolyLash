param(
    [ValidateSet('baseline', 'fun', 'fun_tuned', 'hardcore')]
    [string]$Preset = 'fun_tuned',
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$mainMap = @{
    baseline = "config/player/skill_params_wide_preset_baseline.csv"
    fun = "config/player/skill_params_wide_preset_fun.csv"
    fun_tuned = "config/player/skill_params_wide_preset_fun_tuned.csv"
    hardcore = "config/player/skill_params_wide_preset_hardcore.csv"
}

$trialMap = @{
    baseline = "config/player/skill_params_wide_trial_8roles_preset_baseline.csv"
    fun = "config/player/skill_params_wide_trial_8roles_preset_fun.csv"
    fun_tuned = "config/player/skill_params_wide_trial_8roles_preset_fun_tuned.csv"
    hardcore = "config/player/skill_params_wide_trial_8roles_preset_hardcore.csv"
}

$srcMain = $mainMap[$Preset]
$srcTrial = $trialMap[$Preset]
$dstMain = "config/player/skill_params_wide.csv"
$dstTrial = "config/player/skill_params_wide_trial_8roles.csv"

if (-not (Test-Path $srcMain)) { throw "missing preset file: $srcMain" }
if (-not (Test-Path $srcTrial)) { throw "missing preset file: $srcTrial" }

if ($DryRun) {
    Write-Output "[dry-run] $srcMain -> $dstMain"
    Write-Output "[dry-run] $srcTrial -> $dstTrial"
    exit 0
}

Copy-Item -Path $srcMain -Destination $dstMain -Force
Copy-Item -Path $srcTrial -Destination $dstTrial -Force

Write-Output "applied preset: $Preset"
Write-Output "main:  $srcMain -> $dstMain"
Write-Output "trial: $srcTrial -> $dstTrial"
