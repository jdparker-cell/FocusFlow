param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("start", "stop")]
    [string]$Action
)

$ErrorActionPreference = "SilentlyContinue"
$port = if ($env:FOCUS_FLOW_PORT) { $env:FOCUS_FLOW_PORT } else { "38473" }
$uri = "http://127.0.0.1:$port/event/$Action"

try {
    Invoke-RestMethod -Method Post -Uri $uri -TimeoutSec 2 | Out-Null
}
catch {
    & (Join-Path $PSScriptRoot "start-controller.ps1")
    Invoke-RestMethod -Method Post -Uri $uri -TimeoutSec 3 | Out-Null
}
exit 0
