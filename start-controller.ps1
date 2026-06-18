$ErrorActionPreference = "Stop"

$existing = Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" |
    Where-Object { $_.CommandLine -like "*\.focus-flow\controller.mjs*" }

function Test-FocusFlowController {
    try {
        $port = if ($env:FOCUS_FLOW_PORT) { $env:FOCUS_FLOW_PORT } else { "38473" }
        Invoke-RestMethod -Uri "http://127.0.0.1:$port/state" -TimeoutSec 1 | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

if ($existing -and (Test-FocusFlowController)) {
    return
}

if ($existing) {
    $existing | ForEach-Object {
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }
}

$node = (Get-Command node -ErrorAction Stop).Source
$logPath = Join-Path $PSScriptRoot "controller.log"
$errorLogPath = Join-Path $PSScriptRoot "controller-error.log"

$process = Start-Process -FilePath $node `
    -ArgumentList "`"$PSScriptRoot\controller.mjs`"" `
    -WorkingDirectory $PSScriptRoot `
    -WindowStyle Hidden `
    -RedirectStandardOutput $logPath `
    -RedirectStandardError $errorLogPath `
    -PassThru

for ($attempt = 0; $attempt -lt 20; $attempt++) {
    Start-Sleep -Milliseconds 150
    if (Test-FocusFlowController) {
        return
    }
    if ($process.HasExited) {
        break
    }
}

$details = if (Test-Path -LiteralPath $errorLogPath) {
    Get-Content -Raw -LiteralPath $errorLogPath
}
else {
    "No error log was produced."
}

throw "FocusFlow controller did not start. $details"
