Set-StrictMode -Version Latest

function New-DeliveryRunScript {
    param([Parameter(Mandatory)][object[]]$Items,[Parameter(Mandatory)][string]$Destination,[Parameter(Mandatory)][string]$DbUser,[Parameter(Mandatory)][string]$TnsName,[string]$LogFile='../log/install.log')
    if ([string]::IsNullOrWhiteSpace($DbUser) -or [string]::IsNullOrWhiteSpace($TnsName)) { throw 'DB User and TNS name are required to create runscript.sql.' }
    $sql = @($Items | Where-Object { $_.ActualDestination -and $_.Status -match '^Copied' -and [IO.Path]::GetExtension($_.ActualDestination).Equals('.sql',[StringComparison]::OrdinalIgnoreCase) } | ForEach-Object { '@@' + $_.ActualDestination.Replace('\','/') } | Sort-Object -Unique)
    if (-not $sql.Count) { return $null }
    $path = Join-Path $Destination 'runscript.sql'
    @('SET TRUNC OFF','SET HEADING ON','SET DEFINE OFF','','-- SQL*Plus prompts for the password. No password is stored in this file.',("CONNECT $DbUser@$TnsName"),("SPO $LogFile;"),'') + $sql + @('','SPO OFF;','exit') | Set-Content -LiteralPath $path -Encoding UTF8
    return $path
}
