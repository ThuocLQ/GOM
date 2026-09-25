# Backward-compatible entry point for the portable launcher.
$ErrorActionPreference = 'Stop'
if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    throw 'Delivery Copy must be started in STA mode. Use DeliveryCopy.cmd.'
}
& (Join-Path $PSScriptRoot 'App.ps1')
