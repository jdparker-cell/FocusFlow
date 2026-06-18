param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$HermesArguments
)

$eventScript = Join-Path $PSScriptRoot "event.ps1"

try {
    & $eventScript start
    & hermes @HermesArguments
    exit $LASTEXITCODE
}
finally {
    & $eventScript stop
}

