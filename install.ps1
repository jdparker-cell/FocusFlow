$ErrorActionPreference = "Stop"

$installDirectory = Join-Path $HOME ".focus-flow"
$startupDirectory = [Environment]::GetFolderPath("Startup")
$shortcutPath = Join-Path $startupDirectory "FocusFlow.lnk"
$codexDirectory = Join-Path $HOME ".codex"
$hooksPath = Join-Path $codexDirectory "hooks.json"
$hermesHome = if ($env:HERMES_HOME) {
    $env:HERMES_HOME
} else {
    Join-Path $HOME ".hermes"
}

New-Item -ItemType Directory -Force -Path $installDirectory | Out-Null
New-Item -ItemType Directory -Force -Path $codexDirectory | Out-Null

Get-ChildItem -LiteralPath $PSScriptRoot -File |
    Where-Object { $_.Name -notin @("install.ps1", "window-state.json") } |
    Copy-Item -Destination $installDirectory -Force

$extensionSource = Join-Path $PSScriptRoot "chrome-extension"
$extensionDestination = Join-Path $installDirectory "chrome-extension"
if (Test-Path -LiteralPath $extensionDestination) {
    Remove-Item -LiteralPath $extensionDestination -Recurse -Force
}
Copy-Item -LiteralPath $extensionSource -Destination $extensionDestination -Recurse -Force

$hermesPluginSource = Join-Path $PSScriptRoot "hermes-plugin"
if (Test-Path -LiteralPath $hermesPluginSource) {
    $hermesPluginDestination = Join-Path $hermesHome "plugins\focusflow"
    New-Item -ItemType Directory -Force -Path $hermesPluginDestination | Out-Null
    Copy-Item -LiteralPath "$hermesPluginSource\*" `
        -Destination $hermesPluginDestination `
        -Recurse `
        -Force

    $hermes = Get-Command hermes -ErrorAction SilentlyContinue
    if ($hermes) {
        & $hermes.Source plugins enable focusflow | Out-Null
    }
}

$eventPath = Join-Path $installDirectory "event.ps1"
$startCommand = "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$eventPath`" start"
$stopCommand = "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$eventPath`" stop"

if (Test-Path -LiteralPath $hooksPath) {
    $config = Get-Content -Raw -LiteralPath $hooksPath | ConvertFrom-Json -AsHashtable
}
else {
    $config = @{}
}

if (-not $config.ContainsKey("hooks")) {
    $config["hooks"] = @{}
}

foreach ($definition in @(
    @{ Event = "UserPromptSubmit"; Command = $startCommand },
    @{ Event = "Stop"; Command = $stopCommand }
)) {
    if (-not $config["hooks"].ContainsKey($definition.Event)) {
        $config["hooks"][$definition.Event] = @()
    }

    $alreadyInstalled = @($config["hooks"][$definition.Event]) |
        Where-Object {
            @($_["hooks"]) |
                Where-Object { $_["commandWindows"] -like "*\.focus-flow\event.ps1*" }
        }

    if (-not $alreadyInstalled) {
        $config["hooks"][$definition.Event] += @{
            hooks = @(
                @{
                    type = "command"
                    command = $definition.Command
                    commandWindows = $definition.Command
                    timeout = 5
                }
            )
        }
    }
}

$config | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $hooksPath -Encoding UTF8

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$installDirectory\start-controller.ps1`""
$shortcut.WorkingDirectory = $installDirectory
$shortcut.WindowStyle = 7
$shortcut.Save()

& "$installDirectory\start-controller.ps1"

Write-Host ""
Write-Host "FocusFlow is installed and running." -ForegroundColor Green
Write-Host "Next: load the Chrome extension from:"
Write-Host "  $installDirectory\chrome-extension" -ForegroundColor Cyan
Write-Host ""
Write-Host "Then open Codex CLI, run /hooks, and trust the two FocusFlow hooks."
if (Test-Path -LiteralPath $hermesPluginSource) {
    Write-Host "Hermes integration was installed. Restart Hermes before testing it."
}
