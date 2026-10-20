$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$files = @('App.ps1','Localization.ps1','Core.FileOps.ps1','Core.Git.ps1','Core.SqlPlus.ps1','DeliveryCopy.ps1')
foreach ($file in $files) {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root $file),[ref]$tokens,[ref]$errors)
    if ($errors.Count) { throw "$file has a PowerShell parse error: $($errors[0])" }
}

# Loading the app exercises WPF XAML, every named control, and initial UI state.
. (Join-Path $root 'App.ps1') -NoShow
$savedLanguage = $script:language
$savedLanguagePath = $script:languageSettingsPath
$testLanguagePath = Join-Path $env:TEMP ('gom-language-smoke-'+[Guid]::NewGuid().ToString('N')+'.json')
$script:languageSettingsPath = $testLanguagePath
$script:language = 'English'
$script:LanguageCombo.SelectedIndex = 0
$script:LanguageCombo.SelectedIndex = 1
if ($script:window.Title -ne $script:englishToArabic['Delivery Copy']) { throw 'Arabic window title was not applied.' }
if ($script:window.FlowDirection -ne [Windows.FlowDirection]::RightToLeft) { throw 'Arabic layout must use right-to-left flow direction.' }
if ($script:Step1Button.Content -ne $script:englishToArabic['1  Select files']) { throw 'Arabic control text was not applied.' }
if ($script:FileGrid.Columns[1].Header -ne $script:englishToArabic['PACKAGE PATH']) { throw 'Arabic table headers were not applied.' }
$expectedArabicPath = $script:englishToArabic['Delivery folder: {0}'].Replace('{0}', 'C:\temp')
if ((Get-LocalizedText 'Delivery folder: C:\temp') -ne $expectedArabicPath) { throw 'Arabic parameterized translation failed.' }
$script:LanguageCombo.SelectedIndex = 0
if ($script:window.Title -ne 'Delivery Copy') { throw 'English window title was not restored.' }
if ($script:window.FlowDirection -ne [Windows.FlowDirection]::LeftToRight) { throw 'English layout must use left-to-right flow direction.' }
if ($script:Step1Button.Content -ne '1  Select files') { throw 'English control text was not restored.' }
if ((Get-LocalizedText $expectedArabicPath) -ne 'Delivery folder: C:\temp') { throw 'English parameterized translation was not restored.' }
$script:language = $savedLanguage
$script:languageSettingsPath = $savedLanguagePath
Set-WindowLanguage $script:window
$script:isUpdatingLanguage = $true
$script:LanguageCombo.SelectedIndex = if ($savedLanguage -eq 'Arabic') { 1 } else { 0 }
$script:isUpdatingLanguage = $false
if (Test-Path -LiteralPath $testLanguagePath) { Remove-Item -LiteralPath $testLanguagePath -Force }

$uiDeliveryRoot = Join-Path $env:TEMP ('delivery-copy-ui-smoke-'+[Guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $uiDeliveryRoot -Force | Out-Null
    $uiSource = Join-Path $uiDeliveryRoot 'ui-delivery.txt'
    Set-Content -LiteralPath $uiSource -Value 'UI delivery test'
    [void](Add-Items -Files @(Get-Item -LiteralPath $uiSource) -SourceRoot $uiDeliveryRoot)
    $script:DestinationPath.Text = Join-Path $uiDeliveryRoot 'output'
    Update-DestinationState

    $script:copyResultTimer = New-Object Windows.Threading.DispatcherTimer
    $script:copyResultTimer.Interval = [TimeSpan]::FromMilliseconds(100)
    $script:copyResultTimer.Add_Tick({
        if ($script:ResultPanel.Visibility -eq 'Visible') {
            $script:window.Close()
            $script:copyResultTimer.Stop()
        }
    })
    $script:copyResultTimer.Start()
    Start-Delivery
    [void]$script:window.ShowDialog()
    if ($script:ResultTitle.Text -ne (Get-LocalizedText 'Delivery completed')) {
        throw "UI delivery did not complete successfully: $($script:ResultTitle.Text)"
    }
}
finally {
    if ($script:copyResultTimer) { $script:copyResultTimer.Stop() }
    if (Test-Path -LiteralPath $uiDeliveryRoot) { Remove-Item -LiteralPath $uiDeliveryRoot -Recurse -Force }
}

. (Join-Path $root 'Core.FileOps.ps1')
. (Join-Path $root 'Core.Git.ps1')
$temp = Join-Path $env:TEMP ('delivery-copy-smoke-'+[Guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $temp | Out-Null
    $repository = Join-Path $temp 'repo'
    New-Item -ItemType Directory -Path $repository | Out-Null
    & git -C $repository init -q
    & git -C $repository checkout -qb main
    Set-Content -LiteralPath (Join-Path $repository 'a.txt') -Value 'base'
    & git -C $repository add a.txt
    & git -C $repository -c user.name=Smoke -c user.email=smoke@example.invalid commit -qm base
    & git -C $repository checkout -qb feature
    Set-Content -LiteralPath (Join-Path $repository 'a.txt') -Value 'feature'
    & git -C $repository -c user.name=Smoke -c user.email=smoke@example.invalid commit -qam feature
    Set-Content -LiteralPath (Join-Path $repository 'a.txt') -Value 'workspace'
    & git -C $repository add a.txt
    $changes = Get-DeliveryGitChanges -Repository $repository -BaseBranch main -CompareBranch feature -IncludeWorkspace $true
    if ($changes.Changes.Count -ne 1) { throw 'Git changes must merge committed and workspace changes for the same file.' }

    $file = Get-Item -LiteralPath (Join-Path $repository 'a.txt')
    $item = New-DeliveryItem -File $file -Source $repository -PreserveStructure $true
    $output = Join-Path $temp 'delivery'
    $result = Copy-DeliveryFiles -Items @($item) -Destination $output -DuplicateMode Skip -VerifyHash $true -ReportProgress {param($done,$total,$message)} -IsCancelled {$false}
    if ($result.Items[0].Status -ne 'Copied and verified') { throw 'Copy or SHA-256 verification failed.' }
    if ($result.ManifestPath) { throw 'The delivery manifest must not be created.' }
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
