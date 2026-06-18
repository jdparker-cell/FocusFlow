$ErrorActionPreference = "Stop"

$installDirectory = Join-Path $HOME ".focus-flow"
$startupShortcut = Join-Path ([Environment]::GetFolderPath("Startup")) "FocusFlow.lnk"

Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" |
    Where-Object { $_.CommandLine -like "*\.focus-flow\controller.mjs*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

if (Test-Path -LiteralPath $startupShortcut) {
    Remove-Item -LiteralPath $startupShortcut -Force
}

Write-Host "The controller and startup shortcut were removed."
Write-Host "For safety, Codex hooks and $installDirectory were left in place."
Write-Host "Remove their FocusFlow entries/files manually if you no longer need them."
