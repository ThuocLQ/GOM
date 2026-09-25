Set-StrictMode -Version Latest

function Invoke-DeliveryGit {
    param([Parameter(Mandatory)][string]$Repository,[Parameter(Mandatory)][string[]]$Arguments)
    $result = @(& git -c ("safe.directory=$Repository") -C $Repository @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Git $($Arguments -join ' ') failed: $($result -join [Environment]::NewLine)" }
    return $result
}

function Get-DeliveryGitRoot {
    param([Parameter(Mandatory)][string]$Path)
    $candidate = $Path.Trim()
    while ($candidate -and -not (Test-Path -LiteralPath $candidate -PathType Container)) {
        $parent = Split-Path -LiteralPath $candidate -Parent
        if ($parent -eq $candidate) { break }
        $candidate = $parent
    }
    if (-not $candidate) { throw 'Choose an existing source folder first.' }
    $result = @(Invoke-DeliveryGit $candidate @('rev-parse', '--show-toplevel'))
    return $result[0].Trim().Replace('/', '\')
}

function Sync-DeliveryGitRemote {
    param([Parameter(Mandatory)][string]$Repository)
    [void](Invoke-DeliveryGit $Repository @('fetch', '--all', '--prune'))
}

function Get-DeliveryGitBranches {
    param([Parameter(Mandatory)][string]$Repository)
    Sync-DeliveryGitRemote $Repository
    return @(Invoke-DeliveryGit $Repository @('branch', '--all', '--no-color', '--format=%(refname:short)') | Where-Object { $_ })
}

function Resolve-DeliveryGitRef {
    param([Parameter(Mandatory)][string]$Repository,[Parameter(Mandatory)][string]$Reference)
    $upstream = @(& git -c ("safe.directory=$Repository") -C $Repository rev-parse --abbrev-ref ($Reference + '@{upstream}') 2>$null)
    if ($LASTEXITCODE -eq 0 -and $upstream.Count -and $upstream[0]) { return $upstream[0].Trim() }
    [void](Invoke-DeliveryGit $Repository @('rev-parse', '--verify', $Reference))
    return $Reference
}

function ConvertFrom-DeliveryGitNameStatus {
    param([string[]]$Lines,[string]$Repository)
    $result = @{}
    foreach ($line in $Lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $parts = $line -split "`t"
        if ($parts.Count -lt 2) { continue }
        $status = $parts[0].Trim()
        $relative = if ($status.StartsWith('R') -or $status.StartsWith('C')) { $parts[$parts.Count - 1] } else { $parts[1] }
        if ($relative) { $result[[IO.Path]::GetFullPath((Join-Path -Path $Repository -ChildPath $relative.Trim()))] = $status }
    }
    return $result
}

function Get-DeliveryGitChanges {
    param(
        [Parameter(Mandatory)][string]$Repository,
        [Parameter(Mandatory)][string]$BaseBranch,
        [Parameter(Mandatory)][string]$CompareBranch,
        [bool]$IncludeWorkspace = $true
    )
    Sync-DeliveryGitRemote $Repository
    $base = Resolve-DeliveryGitRef $Repository $BaseBranch
    $compare = Resolve-DeliveryGitRef $Repository $CompareBranch
    $changes = ConvertFrom-DeliveryGitNameStatus @(Invoke-DeliveryGit $Repository @('diff', '--name-status', '-M', '--diff-filter=ACMR', ($base + '...' + $compare))) $Repository
    if ($IncludeWorkspace) {
        foreach ($line in @(Invoke-DeliveryGit $Repository @('diff', '--name-status', '-M', 'HEAD'))) { $changes += ConvertFrom-DeliveryGitNameStatus @($line) $Repository }
        foreach ($line in @(Invoke-DeliveryGit $Repository @('diff', '--name-status', '-M', '--cached'))) { $changes += ConvertFrom-DeliveryGitNameStatus @($line) $Repository }
        foreach ($relative in @(Invoke-DeliveryGit $Repository @('ls-files', '--others', '--exclude-standard'))) {
            if ($relative) { $changes[[IO.Path]::GetFullPath((Join-Path -Path $Repository -ChildPath $relative.Trim()))] = 'A' }
        }
    }
    return [pscustomobject]@{ Base = $base; Compare = $compare; Changes = $changes }
}
