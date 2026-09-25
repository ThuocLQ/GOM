Set-StrictMode -Version Latest

function Test-DeliveryExcludedPath {
    param([Parameter(Mandatory)][string]$Path,[string]$ExcludeRules)
    $parts = $Path.Replace('/', '\').Split('\')
    foreach ($rule in @($ExcludeRules -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
        if ($rule.StartsWith('*.') -and $Path.EndsWith($rule.Substring(1), [StringComparison]::OrdinalIgnoreCase)) { return $true }
        if ($parts -contains $rule) { return $true }
    }
    return $false
}

function Get-DeliveryRelativePath {
    param([Parameter(Mandatory)][string]$Source,[Parameter(Mandatory)][string]$Path,[bool]$PreserveStructure = $true)
    if (-not $PreserveStructure -or -not (Test-Path -LiteralPath $Source -PathType Container)) { return [IO.Path]::GetFileName($Path) }
    $root = [IO.Path]::GetFullPath($Source).TrimEnd('\') + '\'
    $full = [IO.Path]::GetFullPath($Path)
    if ($full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) { return $full.Substring($root.Length) }
    return [IO.Path]::GetFileName($full)
}

function New-DeliveryItem {
    param([Parameter(Mandatory)]$File,[Parameter(Mandatory)][string]$Source,[bool]$PreserveStructure,[string]$GitStatus)
    $status = if ($GitStatus) { "Git $GitStatus" } else { 'Ready' }
    [pscustomobject]@{
        Included = $true
        Source = $File.FullName
        Relative = Get-DeliveryRelativePath $Source $File.FullName $PreserveStructure
        ActualDestination = $null
        Size = [long]$File.Length
        SizeDisplay = Format-DeliverySize $File.Length
        Status = $status
        StatusBrush = '#64748B'
    }
}

function Format-DeliverySize {
    param([long]$Bytes)
    if ($Bytes -lt 1KB) { return "$Bytes B" }
    if ($Bytes -lt 1MB) { return ('{0:N1} KB' -f ($Bytes / 1KB)) }
    if ($Bytes -lt 1GB) { return ('{0:N1} MB' -f ($Bytes / 1MB)) }
    return ('{0:N2} GB' -f ($Bytes / 1GB))
}

function Get-DeliveryFiles {
    param([Parameter(Mandatory)][string[]]$Paths,[string]$ExcludeRules)
    $files = New-Object System.Collections.Generic.List[object]
    foreach ($path in $Paths) {
        if (Test-Path -LiteralPath $path -PathType Leaf) { [void]$files.Add((Get-Item -LiteralPath $path)) }
        elseif (Test-Path -LiteralPath $path -PathType Container) {
            foreach ($file in @(Get-ChildItem -LiteralPath $path -File -Recurse -Force -ErrorAction SilentlyContinue)) {
                if (-not (Test-DeliveryExcludedPath $file.FullName $ExcludeRules)) { [void]$files.Add($file) }
            }
        }
    }
    return $files
}

function Get-DeliveryNextName {
    param([Parameter(Mandatory)][string]$Path)
    $directory = Split-Path -LiteralPath $Path
    $name = [IO.Path]::GetFileNameWithoutExtension($Path)
    $extension = [IO.Path]::GetExtension($Path)
    for ($i = 1; ; $i++) { $candidate = Join-Path $directory "$name ($i)$extension"; if (-not (Test-Path -LiteralPath $candidate)) { return $candidate } }
}

function Copy-DeliveryFiles {
    param(
        [Parameter(Mandatory)][object[]]$Items,
        [Parameter(Mandatory)][string]$Destination,
        [ValidateSet('Skip','Overwrite','Rename automatically')][string]$DuplicateMode = 'Skip',
        [bool]$VerifyHash,
        [scriptblock]$ReportProgress,
        [scriptblock]$IsCancelled
    )
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    $manifest = New-Object System.Collections.Generic.List[object]
    try {
        for ($index = 0; $index -lt $Items.Count; $index++) {
            if (& $IsCancelled) { break }
            $item = $Items[$index]
            $target = Join-Path $Destination $item.Relative
            try {
                New-Item -ItemType Directory -Path (Split-Path -LiteralPath $target) -Force | Out-Null
                if (Test-Path -LiteralPath $target) {
                    if ($DuplicateMode -eq 'Skip') { $item.Status='Skipped';$item.StatusBrush='#B7791F';[void]$manifest.Add([pscustomobject]@{Source=$item.Source;Destination=$target;Bytes=$item.Size;Result='Skipped';Detail='File exists'}); continue }
                    if ($DuplicateMode -eq 'Rename automatically') { $target=Get-DeliveryNextName $target }
                }
                & $ReportProgress $index $Items.Count ("Copying $([IO.Path]::GetFileName($item.Source))")
                [IO.File]::Copy($item.Source,$target,$true)
                [IO.File]::SetLastWriteTimeUtc($target,[IO.File]::GetLastWriteTimeUtc($item.Source))
                if ($VerifyHash) {
                    if (& $IsCancelled) { throw 'Cancelled by user' }
                    & $ReportProgress $index $Items.Count ("Verifying $([IO.Path]::GetFileName($item.Source))")
                    if ((Get-FileHash -LiteralPath $item.Source -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash) { throw 'SHA-256 mismatch' }
                }
                $item.ActualDestination=$target.Substring($Destination.TrimEnd('\').Length).TrimStart('\')
                $item.Status=if($VerifyHash){'Copied and verified'}else{'Copied'};$item.StatusBrush='#15803D'
                [void]$manifest.Add([pscustomobject]@{Source=$item.Source;Destination=$target;Bytes=$item.Size;Result='Copied';Detail=$item.Status})
            } catch {
                if (& $IsCancelled) { $item.Status='Cancelled';$item.StatusBrush='#64748B';[void]$manifest.Add([pscustomobject]@{Source=$item.Source;Destination=$target;Bytes=$item.Size;Result='Cancelled';Detail='Cancelled by user'});break }
                $item.Status='Error: '+$_.Exception.Message;$item.StatusBrush='#DC2626';[void]$manifest.Add([pscustomobject]@{Source=$item.Source;Destination=$target;Bytes=$item.Size;Result='Failed';Detail=$_.Exception.Message})
            } finally { & $ReportProgress ($index+1) $Items.Count $item.Status }
        }
    } finally {
        $stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
        $manifestPath=Join-Path $Destination "delivery_manifest_$stamp.csv"
        $manifest | Export-Csv -LiteralPath $manifestPath -NoTypeInformation -Encoding UTF8
    }
    return [pscustomobject]@{ ManifestPath=$manifestPath; Cancelled=(& $IsCancelled); Items=$Items }
}
