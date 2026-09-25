[CmdletBinding()]
param([switch]$NoShow)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

$script:appRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $script:appRoot 'Core.Git.ps1')
. (Join-Path $script:appRoot 'Core.FileOps.ps1')
. (Join-Path $script:appRoot 'Core.SqlPlus.ps1')

[xml]$xaml = Get-Content -LiteralPath (Join-Path $script:appRoot 'UI.xaml') -Raw
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$names = @('InlineStatus','MainTabs','SourcePath','ExcludeRules','ChooseSourceButton','BaseBranch','CompareBranch','SyncBranchesButton','IncludeWorkspace','CompareButton','ManualFolderPath','BrowseFolderButton','AddFolderButton','ChooseFilesButton','CollectProgress','TotalFilesText','SelectedFilesText','SqlFilesText','TotalSizeText','PasteInput','FileGrid','SelectAllButton','ClearSelectionButton','RemoveSelectedButton','ContinueButton','DeliverTab','DestinationPath','ChooseDestinationButton','OpenDestinationButton','DuplicateMode','VerifyHash','CreateRunScript','ConfigureSqlButton','DeliverySummary','DeliveryProgress','StartDeliveryButton','CancelDeliveryButton','DeliveryStatus')
foreach ($name in $names) { Set-Variable -Name $name -Value $window.FindName($name) -Scope Script }

$script:items = New-Object 'System.Collections.ObjectModel.ObservableCollection[object]'
$script:knownSources = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$script:pasteTimer = New-Object Windows.Threading.DispatcherTimer
$script:pasteTimer.Interval = [TimeSpan]::FromMilliseconds(450)
$script:copyWorker = $null
$script:dbSettings = [pscustomobject]@{ User='HOSTBVSFUND'; Password=''; Tns='FLEX_236'; Log='../log/install.log' }

$FileGrid.ItemsSource = $script:items
[Windows.Controls.ToolTipService]::SetShowOnDisabled($DeliverTab,$true)

function Set-InlineStatus {
    param([string]$Text,[string]$Color='#0866D9')
    $InlineStatus.Text=$Text
    $InlineStatus.Foreground=[Windows.Media.BrushConverter]::new().ConvertFromString($Color)
}

function Update-DeliveryUi {
    $selected = @($script:items | Where-Object Included)
    [long]$totalSize = 0
    foreach ($item in $selected) { $totalSize += [long]$item.Size }
    $TotalFilesText.Text = $script:items.Count
    $SelectedFilesText.Text = $selected.Count
    $SqlFilesText.Text = @($selected | Where-Object { [IO.Path]::GetExtension($_.Relative).Equals('.sql',[StringComparison]::OrdinalIgnoreCase) }).Count
    $TotalSizeText.Text = Format-DeliverySize $totalSize
    $DeliverTab.IsEnabled = $selected.Count -gt 0
    $DeliverySummary.Text = if ($selected.Count) { "$($selected.Count) selected file(s), $(Format-DeliverySize $totalSize) ready for delivery." } else { 'No files selected. Return to Review to select files.' }
    $FileGrid.Items.Refresh()
}

function Add-DeliveryItems {
    param([object[]]$Files,[hashtable]$GitStatus=@{})
    $sourceRoot = $SourcePath.Text.Trim()
    foreach ($file in $Files) {
        if (-not $file -or -not $script:knownSources.Add($file.FullName)) { continue }
        $status = if ($GitStatus.ContainsKey($file.FullName)) { $GitStatus[$file.FullName] } else { $null }
        [void]$script:items.Add((New-DeliveryItem $file $sourceRoot $true $status))
    }
    Update-DeliveryUi
}

function Add-PathsSafely {
    param([string[]]$Paths,[hashtable]$GitStatus=@{})
    $allFiles = New-Object System.Collections.Generic.List[object]
    foreach ($path in $Paths) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $file=Get-Item -LiteralPath $path
            if (-not (Test-DeliveryExcludedPath $file.FullName $ExcludeRules.Text)) { [void]$allFiles.Add($file) }
        } elseif (Test-Path -LiteralPath $path -PathType Container) {
            Start-FolderCollection @($path) $GitStatus
            continue
        }
    }
    if ($allFiles.Count) { Add-DeliveryItems -Files @($allFiles.ToArray()) -GitStatus $GitStatus }
}

function Start-FolderCollection {
    param([string[]]$Paths,[hashtable]$GitStatus=@{})
    $script:collectGitStatus=$GitStatus
    $CollectProgress.Visibility='Visible'
    Set-InlineStatus 'Scanning files…'
    $script:collectJob = Start-Job -ArgumentList (Join-Path $script:appRoot 'Core.FileOps.ps1'),$Paths,$ExcludeRules.Text -ScriptBlock {
        param($modulePath,$jobPaths,$rules)
        . $modulePath
        Get-DeliveryFiles -Paths $jobPaths -ExcludeRules $rules
    }
    $script:collectTimer=New-Object Windows.Threading.DispatcherTimer
    $script:collectTimer.Interval=[TimeSpan]::FromMilliseconds(150)
    $script:collectTimer.Add_Tick({
        if ($script:collectJob.State -notin @('Completed','Failed','Stopped')) { return }
        $script:collectTimer.Stop()
        $CollectProgress.Visibility='Collapsed'
        if ($script:collectJob.State -ne 'Completed') { Set-InlineStatus ('Scan failed: '+(($script:collectJob.ChildJobs[0].JobStateInfo.Reason).Message)) '#DC2626'; Remove-Job $script:collectJob -Force; return }
        $files=@(Receive-Job $script:collectJob -ErrorAction Stop)
        Remove-Job $script:collectJob -Force
        Add-DeliveryItems -Files $files -GitStatus $script:collectGitStatus
        Set-InlineStatus ("Added $($files.Count) file(s).") '#15803D'
        $MainTabs.SelectedIndex=1
    })
    $script:collectTimer.Start()
}

function Import-PastedPaths {
    param([string]$Text)
    $paths = New-Object System.Collections.Generic.List[string]
    foreach ($line in ($Text -split "`r?`n")) {
        $value=$line.Trim().Trim('"')
        if (-not $value) { continue }
        if ($value.Contains("`t")) { $value=@($value -split "`t" | Where-Object { $_.Trim() } | Select-Object -Last 1).Trim() }
        if (-not [IO.Path]::IsPathRooted($value)) {
            if (-not $SourcePath.Text.Trim()) { throw 'Relative paths need a Source folder.' }
            $value=Join-Path -Path $SourcePath.Text.Trim() -ChildPath $value
        }
        [void]$paths.Add($value)
    }
    if ($paths.Count) { Add-PathsSafely @($paths); Set-InlineStatus ("Added $($paths.Count) pasted path(s).") '#15803D' }
}

function Show-SqlSettings {
    [xml]$dialogXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Configure SQL*Plus" Width="520" Height="390" ResizeMode="NoResize" WindowStartupLocation="CenterOwner" Background="#F5F6F8" FontFamily="Segoe UI Variable, Segoe UI" FontSize="13"><Grid Margin="24"><Border Background="White" BorderBrush="#E4E7EC" BorderThickness="1" CornerRadius="10" Padding="20"><Grid><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="12"/><RowDefinition Height="Auto"/><RowDefinition Height="12"/><RowDefinition Height="Auto"/><RowDefinition Height="12"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions><TextBlock Text="SQL*Plus settings" FontSize="20" FontWeight="SemiBold" Foreground="#1F2937"/><Grid Grid.Row="2"><Grid.ColumnDefinitions><ColumnDefinition Width="130"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><TextBlock Text="DB User" VerticalAlignment="Center" Foreground="#4B5563"/><TextBox x:Name="User" Grid.Column="1" Height="34"/></Grid><Grid Grid.Row="4"><Grid.ColumnDefinitions><ColumnDefinition Width="130"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><TextBlock Text="DB Password" VerticalAlignment="Center" Foreground="#4B5563"/><PasswordBox x:Name="Password" Grid.Column="1" Height="34"/></Grid><Grid Grid.Row="6"><Grid.ColumnDefinitions><ColumnDefinition Width="130"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><TextBlock Text="TNS name" VerticalAlignment="Center" Foreground="#4B5563"/><TextBox x:Name="Tns" Grid.Column="1" Height="34"/></Grid><StackPanel Grid.Row="7" Margin="0,16,0,0"><TextBlock Text="Log file (relative or absolute)" Foreground="#4B5563"/><TextBox x:Name="Log" Height="34" Margin="0,6,0,0"/><TextBlock Text="The password remains only in memory. runscript.sql never contains it." Foreground="#4B5563" TextWrapping="Wrap" Margin="0,12,0,0"/></StackPanel><StackPanel Grid.Row="8" Orientation="Horizontal" HorizontalAlignment="Right"><Button x:Name="Cancel" Content="Cancel" IsCancel="True" Padding="16,8" Margin="0,0,8,0"/><Button x:Name="Save" Content="Save for this session" IsDefault="True" Padding="16,8" Background="#0A7CFF" Foreground="White" BorderBrush="#0A7CFF"/></StackPanel></Grid></Border></Grid></Window>
'@
    $dialog=[Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $dialogXaml))
    $dialog.Owner=$window
    $user=$dialog.FindName('User');$password=$dialog.FindName('Password');$tns=$dialog.FindName('Tns');$log=$dialog.FindName('Log')
    $user.Text=$script:dbSettings.User;$password.Password=$script:dbSettings.Password;$tns.Text=$script:dbSettings.Tns;$log.Text=$script:dbSettings.Log
    $dialog.FindName('Save').Add_Click({$script:dbSettings.User=$user.Text.Trim();$script:dbSettings.Password=$password.Password;$script:dbSettings.Tns=$tns.Text.Trim();$script:dbSettings.Log=$log.Text.Trim();$dialog.DialogResult=$true})
    [void]$dialog.ShowDialog()
}

function Start-Delivery {
    $selected=@($script:items | Where-Object Included)
    if (-not $selected.Count) { return }
    $destination=$DestinationPath.Text.Trim()
    if (-not $destination) { [Windows.MessageBox]::Show('Choose a delivery folder.','Delivery Copy'); return }
    $mode=@('Skip','Overwrite','Rename automatically')[$DuplicateMode.SelectedIndex]
    $DeliveryProgress.Minimum=0;$DeliveryProgress.Maximum=$selected.Count;$DeliveryProgress.Value=0
    $StartDeliveryButton.IsEnabled=$false;$CancelDeliveryButton.IsEnabled=$true;$DeliveryStatus.Text='Preparing delivery…';Set-InlineStatus 'Delivery in progress…'
    $cancelFile=Join-Path ([IO.Path]::GetTempPath()) ('delivery-copy-'+[Guid]::NewGuid().ToString('N')+'.cancel')
    $jobItems=@($selected | ForEach-Object {[pscustomobject]@{Included=$_.Included;Source=$_.Source;Relative=$_.Relative;ActualDestination=$null;Size=$_.Size;SizeDisplay=$_.SizeDisplay;Status=$_.Status;StatusBrush=$_.StatusBrush}})
    $verifyEnabled=[bool]($VerifyHash.IsChecked);$runScriptEnabled=[bool]($CreateRunScript.IsChecked)
    $script:copyJob = Start-Job -ArgumentList (Join-Path $script:appRoot 'Core.FileOps.ps1'),(Join-Path $script:appRoot 'Core.SqlPlus.ps1'),$jobItems,$destination,$mode,$verifyEnabled,$runScriptEnabled,$script:dbSettings.User,$script:dbSettings.Tns,$script:dbSettings.Log,$cancelFile -ScriptBlock {
        param($fileModule,$sqlModule,$jobItems,$jobDestination,$jobMode,$jobVerify,$jobRunScript,$dbUser,$tns,$logFile,$cancelSignal)
        . $fileModule; . $sqlModule
        $report={param($done,$total,$message)Write-Progress -Activity 'Delivery Copy' -Status $message -PercentComplete ([int](($done/[Math]::Max($total,1))*100))}
        $cancel={Test-Path -LiteralPath $cancelSignal}
        $result=Copy-DeliveryFiles -Items $jobItems -Destination $jobDestination -DuplicateMode $jobMode -VerifyHash $jobVerify -ReportProgress $report -IsCancelled $cancel
        if($jobRunScript -and -not $result.Cancelled){$result | Add-Member -NotePropertyName RunScriptPath -NotePropertyValue (New-DeliveryRunScript -Items $jobItems -Destination $jobDestination -DbUser $dbUser -TnsName $tns -LogFile $logFile)}
        $result
    }
    $script:copyCancelFile=$cancelFile
    $script:copyTimer=New-Object Windows.Threading.DispatcherTimer;$script:copyTimer.Interval=[TimeSpan]::FromMilliseconds(200)
    $script:copyTimer.Add_Tick({
        $progress=@($script:copyJob.ChildJobs[0].Progress | Select-Object -Last 1)
        if($progress.Count -and $progress[0].PercentComplete -ge 0){$DeliveryProgress.Value=[Math]::Min($DeliveryProgress.Maximum,[Math]::Round(($progress[0].PercentComplete/100)*$DeliveryProgress.Maximum));$DeliveryStatus.Text=$progress[0].StatusDescription}
        if($script:copyJob.State -notin @('Completed','Failed','Stopped')){return}
        $script:copyTimer.Stop();$StartDeliveryButton.IsEnabled=$true;$CancelDeliveryButton.IsEnabled=$false
        if($script:copyJob.State -ne 'Completed'){$DeliveryStatus.Text='Error: '+(($script:copyJob.ChildJobs[0].JobStateInfo.Reason).Message);Set-InlineStatus 'Delivery failed.' '#DC2626';Remove-Job $script:copyJob -Force;return}
        $result=@(Receive-Job $script:copyJob -ErrorAction Stop | Select-Object -Last 1)[0]
        Remove-Job $script:copyJob -Force
        if(Test-Path -LiteralPath $script:copyCancelFile){Remove-Item -LiteralPath $script:copyCancelFile -Force}
        $updated=@{};foreach($jobItem in $result.Items){$updated[$jobItem.Source]=$jobItem};foreach($item in $script:items){if($updated.ContainsKey($item.Source)){$item.ActualDestination=$updated[$item.Source].ActualDestination;$item.Status=$updated[$item.Source].Status;$item.StatusBrush=$updated[$item.Source].StatusBrush}}
        Update-DeliveryUi
        $DeliveryStatus.Text=if($result.Cancelled){'Cancelled. Manifest saved: '+[IO.Path]::GetFileName($result.ManifestPath)}else{'Completed. Manifest saved: '+[IO.Path]::GetFileName($result.ManifestPath)}
        $OpenDestinationButton.IsEnabled=(Test-Path -LiteralPath $DestinationPath.Text -PathType Container)
        $completionText=if($result.Cancelled){'Delivery cancelled; manifest saved.'}else{'Delivery completed.'}
        $completionColor=if($result.Cancelled){'#B7791F'}else{'#15803D'}
        Set-InlineStatus $completionText $completionColor
    })
    $script:copyTimer.Start()
}

$ChooseSourceButton.Add_Click({$dialog=New-Object Windows.Forms.FolderBrowserDialog;if($dialog.ShowDialog() -eq [Windows.Forms.DialogResult]::OK){$SourcePath.Text=$dialog.SelectedPath}})
$BrowseFolderButton.Add_Click({$dialog=New-Object Windows.Forms.FolderBrowserDialog;if($dialog.ShowDialog() -eq [Windows.Forms.DialogResult]::OK){$ManualFolderPath.Text=$dialog.SelectedPath}})
$ChooseFilesButton.Add_Click({$dialog=New-Object Windows.Forms.OpenFileDialog;$dialog.Multiselect=$true;if($dialog.ShowDialog() -eq [Windows.Forms.DialogResult]::OK){Add-PathsSafely @($dialog.FileNames);$MainTabs.SelectedIndex=1}})
$AddFolderButton.Add_Click({if(Test-Path -LiteralPath $ManualFolderPath.Text.Trim() -PathType Container){Start-FolderCollection @($ManualFolderPath.Text.Trim())}else{Set-InlineStatus 'Enter a valid folder path.' '#B7791F'}})
$SyncBranchesButton.Add_Click({try{$repo=Get-DeliveryGitRoot $SourcePath.Text;$SourcePath.Text=$repo;$branches=Get-DeliveryGitBranches $repo;$BaseBranch.ItemsSource=$branches;$CompareBranch.ItemsSource=$branches;$current=(@(Invoke-DeliveryGit $repo @('branch','--show-current')))[0];if(-not $BaseBranch.Text){$BaseBranch.Text=if($branches -contains 'main'){'main'}elseif($branches -contains 'master'){'master'}else{$current}};if(-not $CompareBranch.Text){$CompareBranch.Text=$current};Set-InlineStatus "Synced $($branches.Count) branch(es)." '#15803D'}catch{Set-InlineStatus ('Git error: '+$_.Exception.Message) '#DC2626'}})
$CompareButton.Add_Click({try{$repo=Get-DeliveryGitRoot $SourcePath.Text;$SourcePath.Text=$repo;$changes=Get-DeliveryGitChanges -Repository $repo -BaseBranch $BaseBranch.Text.Trim() -CompareBranch $CompareBranch.Text.Trim() -IncludeWorkspace ([bool]$IncludeWorkspace.IsChecked);$files=@($changes.Changes.Keys | Where-Object {Test-Path -LiteralPath $_ -PathType Leaf} | ForEach-Object {Get-Item -LiteralPath $_});Add-DeliveryItems -Files $files -GitStatus $changes.Changes;Set-InlineStatus ("Added $($files.Count) Git change(s): $($changes.Base)…$($changes.Compare).") '#15803D';$MainTabs.SelectedIndex=1}catch{Set-InlineStatus ('Git compare failed: '+$_.Exception.Message) '#DC2626'}})
$script:pasteTimer.Add_Tick({$script:pasteTimer.Stop();$text=$PasteInput.Text;if($text.Trim()){try{Import-PastedPaths $text;$PasteInput.Clear()}catch{Set-InlineStatus ('Paste failed: '+$_.Exception.Message) '#DC2626'}}})
$PasteInput.Add_TextChanged({$script:pasteTimer.Stop();if($PasteInput.Text.Trim()){$script:pasteTimer.Start()}})
$SelectAllButton.Add_Click({foreach($item in $script:items){$item.Included=$true};Update-DeliveryUi})
$ClearSelectionButton.Add_Click({foreach($item in $script:items){$item.Included=$false};Update-DeliveryUi})
$RemoveSelectedButton.Add_Click({foreach($item in @($script:items | Where-Object Included)){$script:knownSources.Remove($item.Source)|Out-Null;$script:items.Remove($item)};Update-DeliveryUi})
$FileGrid.Add_CurrentCellChanged({$window.Dispatcher.BeginInvoke([Action]{Update-DeliveryUi},[Windows.Threading.DispatcherPriority]::Background)|Out-Null})
$ContinueButton.Add_Click({Update-DeliveryUi;if($DeliverTab.IsEnabled){$MainTabs.SelectedIndex=2}})
$ChooseDestinationButton.Add_Click({$dialog=New-Object Windows.Forms.FolderBrowserDialog;if($dialog.ShowDialog() -eq [Windows.Forms.DialogResult]::OK){$DestinationPath.Text=$dialog.SelectedPath;$OpenDestinationButton.IsEnabled=$true;Update-DeliveryUi}})
$OpenDestinationButton.Add_Click({if(Test-Path -LiteralPath $DestinationPath.Text -PathType Container){Start-Process explorer.exe -ArgumentList ('"'+$DestinationPath.Text+'"')}})
$ConfigureSqlButton.Add_Click({Show-SqlSettings})
$StartDeliveryButton.Add_Click({Start-Delivery})
$CancelDeliveryButton.Add_Click({if($script:copyJob){New-Item -ItemType File -Path $script:copyCancelFile -Force | Out-Null;$CancelDeliveryButton.IsEnabled=$false;$DeliveryStatus.Text='Cancelling after the current file…'}})

Update-DeliveryUi
if (-not $NoShow) { [void]$window.ShowDialog() }
