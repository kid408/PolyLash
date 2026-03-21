Write-Output 'START_F_PROBE'
$godot = 'C:\Users\Administrator\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe'
$roles = @(
  'butcher','glacier','jailer','blacksmith','paladin','breachmarshal','hexwarden','executioner',
  'pyro','runeblazer','lurewarden','weaver','wind','arcstriker','stormseer','banner',
  'turretwright','illusionist','singularist','fatebinder','bloodsworn','spiritcaller','mirebinder','necro',
  'gildhand','sapper','plague','medic','swarm','broker','trapper','quartermaster'
)

$results = @()
foreach ($role in $roles) {
  $env:QEF_DEBUG_ROLE = $role
  & $godot --headless --path . --script D:\wanglei\PolyLash\tools\debug_f_probe_runner.gd *> $null
  $results += [pscustomobject]@{
    role = $role
    passed = ($LASTEXITCODE -eq 0)
    exit_code = $LASTEXITCODE
  }
}

$results | ConvertTo-Json -Depth 4
