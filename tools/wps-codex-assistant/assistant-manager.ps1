param(
    [ValidateSet("help", "init", "start", "stop", "restart", "status", "health", "chat", "callback-demo", "demo")]
    [string]$Action = "help",
    [int]$Port = 8787,
    [string]$SessionId = "local-demo",
    [string]$UserId = "me",
    [string]$Text = "List allowed roots",
    [switch]$KeepRunning
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnvExamplePath = Join-Path $ScriptDir ".env.example"
$EnvPath = Join-Path $ScriptDir ".env"
$DataDir = Join-Path $ScriptDir "data"
$RunDir = Join-Path $DataDir "run"
$PidPath = Join-Path $RunDir "assistant.pid"
$OutLogPath = Join-Path $RunDir "assistant.out.log"
$ErrLogPath = Join-Path $RunDir "assistant.err.log"
$BaseUrl = "http://127.0.0.1:$Port"

function Write-Info($Message) {
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-WarnLine($Message) {
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Ok($Message) {
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Ensure-RunDirectory {
    if (-not (Test-Path $RunDir)) {
        New-Item -ItemType Directory -Path $RunDir | Out-Null
    }
}

function Ensure-Node {
    try {
        $version = node -v
        Write-Info "Detected Node.js $version"
    }
    catch {
        throw "Node.js 20+ is required."
    }
}

function Ensure-EnvFile {
    if (Test-Path $EnvPath) {
        Write-Info ".env already exists"
        return
    }

    if (-not (Test-Path $EnvExamplePath)) {
        throw ".env.example was not found."
    }

    Copy-Item $EnvExamplePath $EnvPath
    Write-Ok "Created .env from .env.example"
    Write-WarnLine "Please edit .env and fill OPENAI_API_KEY and WORKSPACE_ROOTS."
}

function Get-StoredPid {
    if (-not (Test-Path $PidPath)) {
        return $null
    }

    $raw = Get-Content $PidPath -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $null
    }

    return [int]$raw.Trim()
}

function Test-PidRunning([int]$ProcessId) {
    try {
        Get-Process -Id $ProcessId -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Remove-StalePid {
    if (Test-Path $PidPath) {
        Remove-Item $PidPath -Force
    }
}

function Get-RunningPid {
    $storedPid = Get-StoredPid
    if ($null -eq $storedPid) {
        return $null
    }

    if (Test-PidRunning $storedPid) {
        return $storedPid
    }

    Remove-StalePid
    return $null
}

function Invoke-JsonPost {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][hashtable]$Body
    )

    $json = $Body | ConvertTo-Json -Depth 10 -Compress
    return Invoke-RestMethod -Method Post -Uri $Url -ContentType "application/json" -Body $json
}

function Invoke-HealthCheck {
    return Invoke-RestMethod -Method Get -Uri "$BaseUrl/health"
}

function Start-Assistant {
    Ensure-Node
    Ensure-EnvFile
    Ensure-RunDirectory

    $runningPid = Get-RunningPid
    if ($null -ne $runningPid) {
        Write-WarnLine "Service already running. PID=$runningPid"
        return
    }

    if (Test-Path $OutLogPath) {
        Remove-Item $OutLogPath -Force
    }
    if (Test-Path $ErrLogPath) {
        Remove-Item $ErrLogPath -Force
    }

    $process = Start-Process node `
        -ArgumentList "src/server.js" `
        -WorkingDirectory $ScriptDir `
        -RedirectStandardOutput $OutLogPath `
        -RedirectStandardError $ErrLogPath `
        -PassThru

    Set-Content -Path $PidPath -Value $process.Id -NoNewline
    Start-Sleep -Seconds 2

    try {
        $health = Invoke-HealthCheck
        Write-Ok "Service started. PID=$($process.Id)"
        $health | ConvertTo-Json -Depth 10
    }
    catch {
        Write-WarnLine "Process started but health check failed."
        Write-Host $OutLogPath
        Write-Host $ErrLogPath
        throw
    }
}

function Stop-Assistant {
    $runningPid = Get-RunningPid
    if ($null -eq $runningPid) {
        Write-WarnLine "Service is not running."
        return
    }

    Stop-Process -Id $runningPid -Force
    Remove-StalePid
    Write-Ok "Service stopped. PID=$runningPid"
}

function Show-Status {
    $runningPid = Get-RunningPid
    if ($null -eq $runningPid) {
        Write-WarnLine "Service is not running."
        return
    }

    Write-Ok "Service is running. PID=$runningPid"
    try {
        $health = Invoke-HealthCheck
        $health | ConvertTo-Json -Depth 10
    }
    catch {
        Write-WarnLine "Process exists but health check failed."
        Write-Host $OutLogPath
        Write-Host $ErrLogPath
    }
}

function Invoke-Chat {
    $response = Invoke-JsonPost -Url "$BaseUrl/chat" -Body @{
        sessionId = $SessionId
        userId    = $UserId
        text      = $Text
    }
    $response | ConvertTo-Json -Depth 10
}

function Invoke-CallbackDemo {
    $response = Invoke-JsonPost -Url "$BaseUrl/wps/callback" -Body @{
        chat_id = $SessionId
        user_id = $UserId
        text    = $Text
    }
    $response | ConvertTo-Json -Depth 10
}

function Run-Demo {
    $startedHere = $false
    $runningPid = Get-RunningPid

    if ($null -eq $runningPid) {
        Start-Assistant
        $startedHere = $true
    }

    Write-Info "Step 1: health"
    Invoke-HealthCheck | ConvertTo-Json -Depth 10

    Write-Info "Step 2: /chat"
    $script:Text = "List allowed roots"
    Invoke-Chat

    Write-Info "Step 3: /wps/callback"
    $script:Text = "List allowed roots"
    Invoke-CallbackDemo

    if ($startedHere -and -not $KeepRunning) {
        Stop-Assistant
    }
}

function Show-Help {
@"
WPS Codex Assistant Manager

Examples:
  .\assistant-manager.ps1 -Action init
  .\assistant-manager.ps1 -Action start
  .\assistant-manager.ps1 -Action status
  .\assistant-manager.ps1 -Action health
  .\assistant-manager.ps1 -Action chat -Text "List allowed roots"
  .\assistant-manager.ps1 -Action callback-demo -Text "List allowed roots"
  .\assistant-manager.ps1 -Action demo
  .\assistant-manager.ps1 -Action stop

Parameters:
  -Action       help | init | start | stop | restart | status | health | chat | callback-demo | demo
  -Port         service port, default 8787
  -SessionId    session id, default local-demo
  -UserId       user id, default me
  -Text         text sent to the local service
  -KeepRunning  keep the service running after demo
"@
}

switch ($Action) {
    "help" {
        Show-Help
    }
    "init" {
        Ensure-Node
        Ensure-EnvFile
    }
    "start" {
        Start-Assistant
    }
    "stop" {
        Stop-Assistant
    }
    "restart" {
        Stop-Assistant
        Start-Assistant
    }
    "status" {
        Show-Status
    }
    "health" {
        Invoke-HealthCheck | ConvertTo-Json -Depth 10
    }
    "chat" {
        Invoke-Chat
    }
    "callback-demo" {
        Invoke-CallbackDemo
    }
    "demo" {
        Run-Demo
    }
}
