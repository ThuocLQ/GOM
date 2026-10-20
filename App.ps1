[CmdletBinding()]
param([switch]$NoShow)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms
$script:appRoot=Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $script:appRoot 'Core.Git.ps1');. (Join-Path $script:appRoot 'Core.FileOps.ps1');. (Join-Path $script:appRoot 'Core.SqlPlus.ps1')
. (Join-Path $script:appRoot 'Localization.ps1')

$script:themeSettingsPath=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'GOM\theme.json'
$script:languageSettingsPath=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'GOM\language.json'
function Get-SavedTheme {
    if(-not (Test-Path -LiteralPath $script:themeSettingsPath -PathType Leaf)){return 'Light'}
    try {
        $settings=Get-Content -LiteralPath $script:themeSettingsPath -Raw -Encoding UTF8|ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Could not read theme settings at '$script:themeSettingsPath': $($_.Exception.Message)"
    }
    if($settings.Theme -notin @('Light','Dark')){throw "Theme settings at '$script:themeSettingsPath' must contain Theme set to 'Light' or 'Dark'."}
    return [string]$settings.Theme
}
$script:theme=Get-SavedTheme
$script:language=Get-SavedLanguage
[xml]$xaml=Get-Content -LiteralPath (Join-Path $script:appRoot 'UI.xaml') -Raw -Encoding UTF8
$window=[Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))

$names=@(
    'InlineStatus','DarkModeButton','LanguageCombo','ProjectProfileCombo','Step1Button','Step2Button','Step3Button',
    'CollectScroll','CollectView','ReviewView','DeliverScroll','DeliverView',
    'CollectProgress','CollectHint','AdvancedCollect',
    'ExcludeRules','PasteInput','AddPathsButton','PasteResult','RepoPath','ChooseRepoButton',
    'BaseBranch','CompareBranch','LoadBranchesButton','AutoCheckoutAndPull','IncludeWorkspace',
    'AddGitChangesButton','GitHint','ReviewSummary','SearchBox','FilterBox','EmptyState',
    'FileGrid','ToggleFilteredButton','SelectAllButton','ClearSelectionButton','SortAscendingButton',
    'SortDescendingButton','SortSqlFlexButton','ReviewActionHint','RemoveSelectedButton','ContinueButton',
    'DeliverTitle','DeliverSummary','DestinationPath','ChooseDestinationButton','DestinationInfo',
    'ConflictInfo','DestinationError','BackToReviewButton','DeliveryOptions','DuplicateMode',
    'ProfileDeliveryHint','SqlOptions','CreateRunScript','SqlScriptDescription','SqlConfigError',
    'SqlSettingsLine','ConfigureSqlButton','SqlConfigSummary','VerifyHash','DeliveryProgress',
    'DeliveryStatus','StartDeliveryButton','CancelDeliveryButton','ResultPanel','ResultTitle',
    'ResultSummary','OpenDestinationButton','OpenManifestButton','ReviewErrorsButton'
)
foreach($name in $names){Set-Variable -Name $name -Value $window.FindName($name) -Scope Script}

function Set-Theme([string]$Theme,[Windows.Window]$TargetWindow=$window) {
    $light=@{
        '003399'='#003399';'0078D7'='#0078D7';'0645C0'='#0645C0';'0F54B6'='#0F54B6';'1463D6'='#1463D6'
        '16794A'='#16794A';'17263C'='#17263C';'28384D'='#28384D';'536174'='#536174';'5D6B7E'='#5D6B7E'
        'A96500'='#A96500';'A9C7F5'='#A9C7F5';'B42318'='#B42318';'B8C0CC'='#B8C0CC';'CFE8FA'='#CFE8FA'
        'D7DFE9'='#D7DFE9';'D9DEE7'='#D9DEE7';'E5E9F0'='#E5E9F0';'EAF2FF'='#EAF2FF';'EEF1F5'='#EEF1F5'
        'EEF3FA'='#EEF3FA';'F3B5B0'='#F3B5B0';'F5F7FA'='#F5F7FA';'F6F8FB'='#F6F8FB';'FFF7F6'='#FFF7F6'
        'FFFFFF'='#FFFFFF'
    }
    $dark=@{
        '003399'='#D4E6FF';'0078D7'='#64B5F6';'0645C0'='#7AB6FF';'0F54B6'='#4C91EE';'1463D6'='#69A7FF'
        '16794A'='#6FD6A0';'17263C'='#E8EDF5';'28384D'='#D5DDE8';'536174'='#AFBAC9';'5D6B7E'='#A0ACBC'
        'A96500'='#F1B75B';'A9C7F5'='#35659A';'B42318'='#FF8E88';'B8C0CC'='#707B8A';'CFE8FA'='#30465C'
        'D7DFE9'='#394454';'D9DEE7'='#394454';'E5E9F0'='#303946';'EAF2FF'='#26364A';'EEF1F5'='#303946'
        'EEF3FA'='#303B4A';'F3B5B0'='#75403F';'F5F7FA'='#171A21';'F6F8FB'='#252C37';'FFF7F6'='#382727'
        'FFFFFF'='#222833'
    }
    $palette=if($Theme -eq 'Dark'){$dark}else{$light}
    foreach($key in $palette.Keys){
        $TargetWindow.Resources["ThemeColor_$key"]=[Windows.Media.BrushConverter]::new().ConvertFromString($palette[$key])
    }
    if($TargetWindow -eq $window){
            $modeLabel=if($Theme -eq 'Dark'){'Light mode'}else{'Dark mode'}
            $modeToolTip=if($Theme -eq 'Dark'){'Switch to light appearance'}else{'Switch to dark appearance'}
            $DarkModeButton.Content=Get-LocalizedText $modeLabel
            $DarkModeButton.ToolTip=Get-LocalizedText $modeToolTip
        $script:theme=$Theme
        Set-NativeTitleBarTheme
    }
}

function Set-NativeTitleBarTheme {
    if(-not ('GomDwmThemeApi' -as [type])){
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class GomDwmThemeApi
{
    [DllImport("dwmapi.dll")]
    public static extern int SetWindowAttribute(IntPtr window, int attribute, ref int value, int valueSize);
}
'@ -ErrorAction Stop
    }
    $handle=[Windows.Interop.WindowInteropHelper]::new($window).Handle
    if($handle -eq [IntPtr]::Zero){return}
    $darkMode=[int]($script:theme -eq 'Dark')
    try {
        $result=[GomDwmThemeApi]::SetWindowAttribute($handle,20,[ref]$darkMode,4)
        if($result -lt 0){[void][GomDwmThemeApi]::SetWindowAttribute($handle,19,[ref]$darkMode,4)}
    } catch [DllNotFoundException] {
    } catch [EntryPointNotFoundException] {
    }
}

$script:currentProfile='BSC'
$script:isUpdatingLanguage=$false
$script:lastStatusText='Ready'
$script:items=New-Object 'System.Collections.ObjectModel.ObservableCollection[object]'
$script:viewItems=New-Object 'System.Collections.ObjectModel.ObservableCollection[object]'
$script:knownSources=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$script:db=[pscustomobject]@{User='HOSTBVSFUND';Password='HOST';Tns='FLEX_236';Log='../log/install.log'}
$script:sqlDefaultApplied=$false
$script:searchTimer=New-Object Windows.Threading.DispatcherTimer;$script:searchTimer.Interval=[TimeSpan]::FromMilliseconds(300)
$script:destinationTimer=New-Object Windows.Threading.DispatcherTimer;$script:destinationTimer.Interval=[TimeSpan]::FromMilliseconds(350)

$FileGrid.ItemsSource=$script:viewItems
$CollectHint.TextWrapping='Wrap';$PasteResult.TextWrapping='Wrap';$DestinationError.TextWrapping='Wrap'
$Step1Button.TabIndex=1;$Step2Button.TabIndex=2;$Step3Button.TabIndex=3;$AdvancedCollect.TabIndex=12
$SelectAllButton.TabIndex=42;$ClearSelectionButton.TabIndex=43;$SortAscendingButton.TabIndex=44
$SortDescendingButton.TabIndex=45;$SortSqlFlexButton.TabIndex=46;$RemoveSelectedButton.TabIndex=47
$ContinueButton.TabIndex=48;$BackToReviewButton.TabIndex=49;$CancelDeliveryButton.TabIndex=57
$OpenDestinationButton.TabIndex=58;$OpenManifestButton.TabIndex=59;$ReviewErrorsButton.TabIndex=60
[Windows.Controls.ToolTipService]::SetShowOnDisabled($Step2Button,$true);[Windows.Controls.ToolTipService]::SetShowOnDisabled($Step3Button,$true)

function Format-FileCount([int]$Count) {
    Get-LocalizedText ("{0} file{1}" -f $Count, $(if($Count -eq 1){''}else{'s'}))
}

function Set-Status([string]$Text,[string]$Color='#1463D6'){
    $script:lastStatusText=$Text
    if($script:theme -eq 'Dark'){
        $Color=switch($Color.ToUpperInvariant()){
            '#1463D6'{'#69A7FF'}
            '#16794A'{'#6FD6A0'}
            '#B42318'{'#FF8E88'}
            '#A96500'{'#F1B75B'}
            default{$Color}
        }
    }
    $InlineStatus.Text=Get-LocalizedText $Text
    $InlineStatus.Foreground=[Windows.Media.BrushConverter]::new().ConvertFromString($Color)
}

function Get-SelectedItems{ return @($script:items | Where-Object Included) }
function Get-FileType([string]$Path){
    $ext=[IO.Path]::GetExtension($Path).TrimStart('.')
    if(-not $ext){return 'Other'}
    return $ext.ToUpperInvariant()
}

function Convert-UiStatus([string]$Status){
    if($Status -match '^Ready'){return 'Ready'}
    if($Status -match '^Git'){return 'Modified'}
    if($Status -match '^Copied and verified'){return 'Copied and verified'}
    if($Status -match '^Copied'){return 'Copied'}
    if($Status -match '^Skipped'){return 'Skip'}
    if($Status -match '^Cancelled'){return 'Cancelled'}
    if($Status -match '^(Error|Failed)'){return 'Error: '+($Status -replace '^(Error|Failed):?\s*','')}
    return $Status
}

function Set-Step([int]$Step){
    $script:currentStep=$Step
    $CollectScroll.Visibility=if($Step -eq 1){'Visible'}else{'Collapsed'}
    $CollectView.Visibility=if($Step -eq 1){'Visible'}else{'Collapsed'}
    $ReviewView.Visibility=if($Step -eq 2){'Visible'}else{'Collapsed'}
    $DeliverScroll.Visibility=if($Step -eq 3){'Visible'}else{'Collapsed'}
    $DeliverView.Visibility=if($Step -eq 3){'Visible'}else{'Collapsed'}
    foreach($pair in @(@($Step1Button,1),@($Step2Button,2),@($Step3Button,3))){
        $pair[0].Background=if($pair[1] -eq $Step){$window.Resources['ThemeColor_EAF2FF']}else{[Windows.Media.Brushes]::Transparent}
        $pair[0].Foreground=if($pair[1] -eq $Step){$window.Resources['ThemeColor_1463D6']}else{$window.Resources['ThemeColor_28384D']}
    }
}

function Set-DeliveryProfile([string]$Profile, [bool]$UpdateDbDefaults=$true) {
    $script:currentProfile = $Profile
    if ($Profile -eq 'BVSC') {
        if ($ProjectProfileCombo.SelectedIndex -ne 0) { $ProjectProfileCombo.SelectedIndex = 0 }
        if ($UpdateDbDefaults) {
            $script:db.User = 'HOSTBVSFUND'
            $script:db.Password = 'HOST'
            $script:db.Tns = 'FLEX_236'
        }
        $ProfileDeliveryHint.Text = Get-LocalizedText "BVSC Mode: 2.HOST files map to 2.HOST\upgrade\sql\2.HOST. Also includes Huong_dan_cap_nhat.txt and Huong dan runall.sql from the BVSC template."
        $SqlScriptDescription.Text = Get-LocalizedText "BVSC: Automatically generates runUpdate.bat, setVariable.bat, install.sql, and the two BVSC instruction files."
    } else {
        if ($ProjectProfileCombo.SelectedIndex -ne 1) { $ProjectProfileCombo.SelectedIndex = 1 }
        if ($UpdateDbDefaults) {
            $script:db.User = 'HOSTBSCFUND'
            $script:db.Password = 'HOST'
            $script:db.Tns = 'FLEX189'
        }
        $ProfileDeliveryHint.Text = Get-LocalizedText "Other Mode: Preserves the repository structure (1.BDSHOST, 2.HOST, 3.Service...). Creates runscript.txt only; no runscript.sql or delivery manifest."
        $SqlScriptDescription.Text = Get-LocalizedText "Other: Generates runscript.txt at the destination root. Each @ command uses the absolute path of the source SQL file in the local repository."
    }
    $SqlConfigSummary.Text = Get-LocalizedText ("DB: {0}@{1}" -f $script:db.User,$script:db.Tns)
    $OpenManifestButton.Visibility = 'Collapsed'

    # Recompute relative path for existing items
    foreach ($item in $script:items) {
        $srcRoot = if ($item.PSObject.Properties['SourceRoot'] -and $item.SourceRoot) { $item.SourceRoot } else { $RepoPath.Text.Trim() }
        $preserve = if ($item.PSObject.Properties['PreserveStructure']) { $item.PreserveStructure } else { $true }
        $item.Relative = Get-DeliveryRelativePath -Source $srcRoot -Path $item.Source -PreserveStructure $preserve -Profile $script:currentProfile
    }
    Update-Ui
}

function Show-StartupProfileDialog {
    $sx=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Select Delivery Project Mode" Width="540" Height="340" ResizeMode="NoResize" WindowStartupLocation="CenterScreen"
    Background="#F5F7FA" Foreground="#28384D" FontFamily="Segoe UI Variable, Segoe UI">
    <Window.Resources>
        <Style TargetType="{x:Type Control}"><Setter Property="FocusVisualStyle" Value="{x:Null}"/></Style>
        <Style x:Key="ProfileCard" TargetType="Button">
            <Setter Property="Background" Value="White"/><Setter Property="BorderBrush" Value="#D7DFE9"/><Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="18"/><Setter Property="Cursor" Value="Hand"/><Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="10" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="BorderBrush" Value="#1463D6"/><Setter TargetName="bd" Property="Background" Value="#F0F7FF"/></Trigger>
                            <Trigger Property="IsPressed" Value="True"><Setter TargetName="bd" Property="Opacity" Value=".85"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Grid Margin="24">
        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
        <StackPanel>
            <TextBlock Text="Choose Delivery Project Profile" FontSize="18" FontWeight="SemiBold" Foreground="#17263C"/>
            <TextBlock Text="Select how delivery package paths and deployment scripts should be formatted:" Margin="0,4,0,16" Foreground="#5D6B7E"/>
        </StackPanel>
        <Grid Grid.Row="1">
            <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="12"/><RowDefinition Height="*"/></Grid.RowDefinitions>
            <Button x:Name="BvscOption" Style="{StaticResource ProfileCard}" Grid.Row="0">
                <StackPanel>
                    <TextBlock Text="BVSC (Bao Viet Securities)" FontSize="15" FontWeight="SemiBold" Foreground="#1463D6"/>
                    <TextBlock Text="Organizes into 2.HOST\upgrade\sql\2.HOST. Creates runUpdate.bat, setVariable.bat, and install.sql." Margin="0,3,0,0" Foreground="#5D6B7E" TextWrapping="Wrap"/>
                </StackPanel>
            </Button>
            <Button x:Name="OtherOption" Style="{StaticResource ProfileCard}" Grid.Row="2">
                <StackPanel>
                    <TextBlock Text="Other" FontSize="15" FontWeight="SemiBold" Foreground="#17263C"/>
                    <TextBlock Text="Preserves the repository structure and generates runscript.txt with absolute local-repository SQL paths. Does not create runscript.sql or a delivery manifest." Margin="0,3,0,0" Foreground="#5D6B7E" TextWrapping="Wrap"/>
                </StackPanel>
            </Button>
        </Grid>
        <TextBlock Grid.Row="2" Text="You can also switch profiles anytime at the top bar." Margin="0,14,0,0" Foreground="#8C98A8" FontSize="11" HorizontalAlignment="Center"/>
    </Grid>
</Window>
'@
    $sx=[regex]::Replace($sx,'#([0-9A-Fa-f]{6})','{DynamicResource ThemeColor_$1}')
    $sx=$sx.Replace('Value="White"','Value="{DynamicResource ThemeColor_FFFFFF}"')
    [xml]$sx=$sx
    $dlg=[Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $sx))
    Set-Theme $script:theme $dlg
    Set-WindowLanguage $dlg
    if ($window.IsVisible) { $dlg.Owner = $window }
    $bvscBtn=$dlg.FindName('BvscOption')
    $otherBtn=$dlg.FindName('OtherOption')
    $bvscBtn.Add_Click({ Set-DeliveryProfile 'BVSC'; $dlg.Close() })
    $otherBtn.Add_Click({ Set-DeliveryProfile 'BSC'; $dlg.Close() })
    [void]$dlg.ShowDialog()
}

function Update-Ui([bool]$RefreshGrid=$true) {
    $selected=@(Get-SelectedItems);[long]$bytes=0;foreach($i in $selected){$bytes+=[long]$i.Size}
    $sql=(@($selected | Where-Object {[IO.Path]::GetExtension($_.Relative).Equals('.sql',[StringComparison]::OrdinalIgnoreCase)})).Count
    $Step2Button.IsEnabled=($script:items.Count -gt 0)
    $Step2Button.Content=Get-LocalizedText "2  Review ($($script:items.Count))"
    $Step3Button.IsEnabled=($selected.Count -gt 0)
    $Step2Button.ToolTip=if($Step2Button.IsEnabled){$null}else{'Add at least one file to review.'}
    $Step3Button.ToolTip=if($Step3Button.IsEnabled){$null}else{'Include at least one file to continue to delivery.'}
    $ReviewSummary.Text=Get-LocalizedText ("{0} | {1} selected | {2} | {3} SQL" -f (Format-FileCount $script:items.Count),$selected.Count,(Format-DeliverySize $bytes),$sql)
    $ContinueButton.Content=Get-LocalizedText ('Continue ('+(Format-FileCount $selected.Count)+')')
    $ContinueButton.IsEnabled=($selected.Count -gt 0)
    $DeliverTitle.Text=Get-LocalizedText ("Deliver {0} | {1}" -f (Format-FileCount $selected.Count),(Format-DeliverySize $bytes))
    $DeliverSummary.Text=Get-LocalizedText 'Select a destination folder, then start delivery.'
    $SqlOptions.Visibility=if($sql){'Visible'}else{'Collapsed'}
    $EmptyState.Visibility=if($script:items.Count){'Collapsed'}else{'Visible'}
    if($sql -and -not $script:sqlDefaultApplied){$CreateRunScript.IsChecked=$true;$script:sqlDefaultApplied=$true}
    if(-not $sql){$script:sqlDefaultApplied=$false}
    Update-DestinationState
    if($RefreshGrid){Refresh-Grid}
}

function Refresh-Grid {
    $query=$SearchBox.Text.Trim()
    $filter=$FilterBox.SelectedIndex
    $script:viewItems.Clear()
    foreach($item in $script:items){
        $ok=([string]::IsNullOrWhiteSpace($query) -or $item.FileName.IndexOf($query,[StringComparison]::OrdinalIgnoreCase)-ge 0 -or $item.Source.IndexOf($query,[StringComparison]::OrdinalIgnoreCase)-ge 0 -or $item.Relative.IndexOf($query,[StringComparison]::OrdinalIgnoreCase)-ge 0)
        if($ok){
            switch($filter){
                1{$ok=$item.Included}
                2{$ok=-not $item.Included}
                3{$ok=[IO.Path]::GetExtension($item.Relative).Equals('.sql',[StringComparison]::OrdinalIgnoreCase)}
                4{$ok=$item.Status -match 'Error|Failed'}
            }
        }
        if($ok){[void]$script:viewItems.Add($item)}
    }
    $ToggleFilteredButton.IsChecked=($script:viewItems.Count -gt 0 -and @($script:viewItems|Where-Object {-not $_.Included}).Count -eq 0)
    $FileGrid.Items.Refresh()
}

function Update-DestinationState {
    $root=$DestinationPath.Text.Trim();$selected=@(Get-SelectedItems)
    if(-not $root){$DestinationInfo.Text=Get-LocalizedText 'Choose a destination folder.';$DestinationInfo.Foreground=$window.Resources['ThemeColor_5D6B7E'];$ConflictInfo.Text='';return}
    $branchFolder=ConvertTo-DeliveryBranchFolderName $CompareBranch.Text
    $dest=if($branchFolder){Join-Path $root $branchFolder}else{$root}
    $branchMessage=if($branchFolder){Get-LocalizedText (" Delivery will be placed in '{0}'." -f $branchFolder)}else{''}
    if(-not (Test-Path -LiteralPath $root -PathType Container)){$DestinationInfo.Text=Get-LocalizedText ("Destination root does not exist. The delivery folder will be created after confirmation.{0}" -f $branchMessage);$DestinationInfo.Foreground=$window.Resources['ThemeColor_A96500'];$ConflictInfo.Text='';return}
    if(-not (Test-Path -LiteralPath $dest -PathType Container)){$DestinationInfo.Text=Get-LocalizedText ("Delivery folder: {0} (will be created)." -f $dest);$DestinationInfo.Foreground=$window.Resources['ThemeColor_5D6B7E'];$ConflictInfo.Text='';return}
    $DestinationInfo.Text=Get-LocalizedText ("Delivery folder: {0}" -f $dest);$DestinationInfo.Foreground=$window.Resources['ThemeColor_5D6B7E']
    $conflicts=@($selected|Where-Object {Test-Path -LiteralPath (Join-Path $dest $_.Relative)}).Count
    $ConflictInfo.Text=if($conflicts){Get-LocalizedText ("{0} of {1} selected files already exist in this folder." -f $conflicts,$selected.Count)}else{Get-LocalizedText 'No selected files currently exist in this folder.'}
}

function Sort-ReviewItems([bool]$Descending) {
    $ordered=@($script:items | Sort-Object -Property Relative -Descending:$Descending)
    $script:items.Clear()
    foreach($item in $ordered){[void]$script:items.Add($item)}
    Refresh-Grid
    $sortHint=if($Descending){'Sorted Z to A.'}else{'Sorted A to Z.'}
    $ReviewActionHint.Text=Get-LocalizedText $sortHint
}

function Sort-ReviewItemsFlexDb {
    $ordered=@($script:items | Sort-Object -Property { Get-DeliverySqlPriority $_.Relative }, { $_.Relative })
    $script:items.Clear()
    foreach($item in $ordered){[void]$script:items.Add($item)}
    Refresh-Grid
    $ReviewActionHint.Text=Get-LocalizedText 'Sorted by FlexDB execution order.'
}

function Add-Items([object[]]$Files,[hashtable]$GitStatus=@{},[string]$SourceRoot=$null) {
    $added=0;$duplicates=0
    $root=if($SourceRoot){$SourceRoot}elseif($RepoPath.Text.Trim()){$RepoPath.Text.Trim()}else{''}
    foreach($file in $Files){
        if(-not $file){continue}
        if(-not $script:knownSources.Add($file.FullName)){$duplicates++;continue}
        $git=if($GitStatus.ContainsKey($file.FullName)){$GitStatus[$file.FullName]}else{$null}
        $item=New-DeliveryItem -File $file -Source $root -PreserveStructure $true -GitStatus $git -Profile $script:currentProfile
        $item.Status=Convert-UiStatus $item.Status
        $item|Add-Member NoteProperty FileName ([IO.Path]::GetFileName($file.FullName))
        $item|Add-Member NoteProperty SourceFolder (Split-Path $file.FullName -Parent)
        $item|Add-Member NoteProperty FileType (Get-FileType $file.FullName)
        [void]$script:items.Add($item)
        $added++
    }
    Update-Ui
    return [pscustomobject]@{Added=$added;Duplicates=$duplicates}
}

function Add-DirectPaths([string[]]$Paths,[hashtable]$GitStatus=@{}) {
    $files=New-Object System.Collections.Generic.List[object]
    foreach($path in $Paths){
        if(Test-Path -LiteralPath $path -PathType Leaf){
            $f=Get-Item -LiteralPath $path
            if(-not(Test-DeliveryExcludedPath $f.FullName $ExcludeRules.Text)){[void]$files.Add($f)}
        }elseif(Test-Path -LiteralPath $path -PathType Container){
            Start-FolderScan @($path) $GitStatus
        }
    }
    if($files.Count){return Add-Items -Files @($files.ToArray()) -GitStatus $GitStatus}
    return [pscustomobject]@{Added=0;Duplicates=0}
}

function Start-FolderScan([string[]]$Paths,[hashtable]$GitStatus=@{}) {
    $CollectProgress.Visibility='Visible'
    $CollectHint.Text=Get-LocalizedText 'Scanning files...';Set-Status 'Scanning files...'
    $script:scanGit=$GitStatus;$script:scanRoot=$Paths[0]
    $script:scanJob=Start-Job -ArgumentList (Join-Path $script:appRoot 'Core.FileOps.ps1'),$Paths,$ExcludeRules.Text -ScriptBlock {
        param($m,$p,$rules);. $m;Get-DeliveryFiles -Paths $p -ExcludeRules $rules
    }
    $script:scanTimer=New-Object Windows.Threading.DispatcherTimer
    $script:scanTimer.Interval=[TimeSpan]::FromMilliseconds(150)
    $script:scanTimer.Add_Tick({
        if($script:scanJob.State -notin @('Completed','Failed','Stopped')){return}
        $script:scanTimer.Stop()
        $CollectProgress.Visibility='Collapsed'
        if($script:scanJob.State -ne 'Completed'){Set-Status 'File scan failed. Choose the folder again.' '#B42318';return}
        $files=@(Receive-Job $script:scanJob);Remove-Job $script:scanJob -Force
        $r=Add-Items -Files $files -GitStatus $script:scanGit -SourceRoot $script:scanRoot
        $CollectHint.Text=Get-LocalizedText ('Added '+(Format-FileCount $r.Added)+'.')
        Set-Status ('Added '+(Format-FileCount $r.Added)) '#16794A'
        if($r.Added){Set-Step 2}
    })
    $script:scanTimer.Start()
}

function Add-PastedPaths {
    $valid=New-Object System.Collections.Generic.List[string]
    $invalid=New-Object System.Collections.Generic.List[string]
    foreach($line in ($PasteInput.Text -split "`r?`n")){
        $value=$line.Trim().Trim('"')
        if(-not $value){continue}
        if($value.Contains("`t")){$value=@($value -split "`t"|Where-Object {$_.Trim()}|Select-Object -Last 1).Trim()}
        if(-not [IO.Path]::IsPathRooted($value)){
            $base=if($RepoPath.Text.Trim()){$RepoPath.Text.Trim()}else{''}
            if($base){$value=Join-Path $base $value}
        }
        if(Test-Path -LiteralPath $value){[void]$valid.Add($value)}else{[void]$invalid.Add($value)}
    }
    $r=Add-DirectPaths @($valid)
    $PasteResult.Text=Get-LocalizedText ("Added {0} | {1} invalid paths" -f (Format-FileCount $r.Added),$invalid.Count)
    if($r.Added){$PasteInput.Clear();Set-Status ('Added '+(Format-FileCount $r.Added)) '#16794A';Set-Step 2}
}

function Show-SqlDialog {
    $dx=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Configure DB Credentials" Width="500" Height="360" ResizeMode="NoResize" WindowStartupLocation="CenterOwner" FontFamily="Segoe UI"
    Background="#F5F7FA" Foreground="#28384D">
    <Window.Resources>
        <Style TargetType="{x:Type Control}"><Setter Property="FocusVisualStyle" Value="{x:Null}"/><Setter Property="Foreground" Value="#28384D"/></Style>
        <Style TargetType="TextBox"><Setter Property="Background" Value="#FFFFFF"/><Setter Property="BorderBrush" Value="#D7DFE9"/><Setter Property="Foreground" Value="#28384D"/></Style>
    </Window.Resources>
    <Grid Margin="24">
        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="12"/><RowDefinition Height="Auto"/><RowDefinition Height="12"/><RowDefinition Height="Auto"/><RowDefinition Height="12"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
        <TextBlock Text="Configure DB Credentials" FontSize="18" FontWeight="SemiBold"/>
        <StackPanel Grid.Row="2"><TextBlock Text="DB user"/><TextBox x:Name="User" Height="34" Margin="0,4,0,0" TabIndex="1"/></StackPanel>
        <StackPanel Grid.Row="4"><TextBlock Text="Password"/><TextBox x:Name="Password" Height="34" Margin="0,4,0,0" TabIndex="2"/></StackPanel>
        <StackPanel Grid.Row="6"><TextBlock Text="TNS name"/><TextBox x:Name="Tns" Height="34" Margin="0,4,0,0" TabIndex="3"/></StackPanel>
        <TextBlock x:Name="DialogError" Grid.Row="7" Foreground="#B42318" Visibility="Collapsed"/>
        <TextBlock Grid.Row="7" Text="These credentials are written to setVariable.bat (BVSC) or runscript.txt (Other)." Margin="0,12,0,0" Foreground="#5D6B7E"/>
        <StackPanel Grid.Row="8" Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="Cancel" Content="Cancel" IsCancel="True" Margin="0,0,8,0" Width="80" Height="32"/>
            <Button x:Name="Save" Content="Save for this session" IsDefault="True" Width="140" Height="32"/>
        </StackPanel>
    </Grid>
</Window>
'@
    $dx=[regex]::Replace($dx,'#([0-9A-Fa-f]{6})','{DynamicResource ThemeColor_$1}')
    [xml]$dx=$dx
    $d=[Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $dx))
    Set-Theme $script:theme $d
    Set-WindowLanguage $d
    if ($window.IsVisible) { $d.Owner=$window }
    $u=$d.FindName('User');$p=$d.FindName('Password');$t=$d.FindName('Tns');$err=$d.FindName('DialogError')
    $u.Text=$script:db.User;$p.Text=$script:db.Password;$t.Text=$script:db.Tns
    $d.FindName('Save').Add_Click({
    if(-not $u.Text.Trim()){$err.Text=Get-LocalizedText 'DB user is required.';$err.Visibility='Visible';return}
    if(-not $t.Text.Trim()){$err.Text=Get-LocalizedText 'TNS name is required.';$err.Visibility='Visible';return}
        $script:db.User=$u.Text.Trim();$script:db.Password=$p.Text.Trim();$script:db.Tns=$t.Text.Trim()
        $SqlConfigSummary.Text=Get-LocalizedText ("DB: {0}@{1}" -f $script:db.User,$script:db.Tns)
        $d.DialogResult=$true
    })
    [void]$d.ShowDialog()
}

function Start-Delivery {
    $selected=@(Get-SelectedItems);$destinationRoot=$DestinationPath.Text.Trim()
    if(-not $destinationRoot){$DestinationError.Text=Get-LocalizedText 'Choose a destination folder.';$DestinationError.Visibility='Visible';return}
    $branchFolder=ConvertTo-DeliveryBranchFolderName $CompareBranch.Text
    $dest=if($branchFolder){Join-Path $destinationRoot $branchFolder}else{$destinationRoot}
    if(-not(Test-Path -LiteralPath $destinationRoot -PathType Container)){
        if([Windows.MessageBox]::Show((Get-LocalizedText ("The destination folder does not exist:`n{0}`n`nCreate it and continue?" -f $destinationRoot)),(Get-LocalizedText 'Create destination folder'),[Windows.MessageBoxButton]::YesNo,[Windows.MessageBoxImage]::Warning) -ne 'Yes'){return}
    }
    if(-not(Test-Path -LiteralPath $dest -PathType Container)){
        try{New-Item -ItemType Directory -Path $dest -Force -ErrorAction Stop|Out-Null}catch{$DestinationError.Text=Get-LocalizedText ("Could not create delivery folder: {0}" -f $_.Exception.Message);$DestinationError.Visibility='Visible';return}
    }
    $DestinationError.Visibility='Collapsed';Update-DestinationState
    $mode=@('Skip','Overwrite','Rename automatically')[$DuplicateMode.SelectedIndex]
    if($mode -eq 'Overwrite'){
        $count=@($selected|Where-Object {Test-Path -LiteralPath (Join-Path $dest $_.Relative)}).Count
        if($count -and [Windows.MessageBox]::Show((Get-LocalizedText ("There are {0} existing destination files. Overwrite them?" -f $count)),(Get-LocalizedText 'Confirm overwrite'),[Windows.MessageBoxButton]::YesNo,[Windows.MessageBoxImage]::Warning) -ne 'Yes'){return}
    }
    $verify=[bool]$VerifyHash.IsChecked
    $run=[bool]$CreateRunScript.IsChecked
    $writeManifest=$false
    $SqlConfigError.Visibility='Collapsed'
    if($run){
        $missing=@()
        if(-not $script:db.User.Trim()){$missing+='DB user'}
        if(-not $script:db.Tns.Trim()){$missing+='TNS name'}
        if($missing.Count){$SqlConfigError.Text=Get-LocalizedText ("DB configuration is missing: {0}. Click Configure DB credentials." -f ($missing -join ', '));$SqlConfigError.Visibility='Visible';return}
    }
    $script:deliveryPath=$dest
    $DeliveryOptions.IsEnabled=$false;$StartDeliveryButton.IsEnabled=$false;$CancelDeliveryButton.IsEnabled=$true
    $DeliveryProgress.Maximum=$selected.Count
    $script:cancelFile=Join-Path ([IO.Path]::GetTempPath())('delivery-copy-'+[Guid]::NewGuid()+'.cancel')
    $jobItems=@($selected|ForEach-Object {[pscustomobject]@{Included=$_.Included;Source=$_.Source;Relative=$_.Relative;ActualDestination=$null;Size=$_.Size;SizeDisplay=$_.SizeDisplay;Status=$_.Status;StatusBrush=$_.StatusBrush}})
    $prof=$script:currentProfile
    $u=$script:db.User;$p=$script:db.Password;$t=$script:db.Tns;$log=$script:db.Log

    $script:copyJob=Start-Job -ArgumentList (Join-Path $script:appRoot 'Core.FileOps.ps1'),(Join-Path $script:appRoot 'Core.SqlPlus.ps1'),$jobItems,$dest,$mode,$verify,$writeManifest,$run,$prof,$u,$p,$t,$log,$script:cancelFile -ScriptBlock {
        param($fm,$sm,$items,$d,$mode,$verify,$writeManifest,$run,$prof,$u,$p,$t,$log,$cancel)
        . $fm;. $sm
        $report={param($done,$total,$message)Write-Progress -Activity 'Delivery' -Status $message -PercentComplete ([int](($done/[Math]::Max($total,1))*100))}
        $stop={Test-Path -LiteralPath $cancel}
        $result=Copy-DeliveryFiles -Items $items -Destination $d -DuplicateMode $mode -VerifyHash $verify -WriteManifest $writeManifest -ReportProgress $report -IsCancelled $stop
        if($run -and -not $result.Cancelled){
            $result|Add-Member NoteProperty RunScriptPath (New-DeliveryRunScript -Items $items -Destination $d -DbUser $u -DbPass $p -TnsName $t -LogFile $log -Profile $prof)
        }
        $result
    }

    $script:copyTimer=New-Object Windows.Threading.DispatcherTimer
    $script:copyTimer.Interval=[TimeSpan]::FromMilliseconds(200)
    $script:copyTimer.Add_Tick({
      try {
        $p=@($script:copyJob.ChildJobs[0].Progress|Select-Object -Last 1)
        if($p.Count){
            $DeliveryProgress.Value=[Math]::Round(($p[0].PercentComplete/100)*$DeliveryProgress.Maximum)
            $DeliveryStatus.Text=Get-LocalizedText $p[0].StatusDescription
            Set-Status (Get-LocalizedText ("Delivering {0}/{1} files" -f [int]$DeliveryProgress.Value,[int]$DeliveryProgress.Maximum))
        }
        if($script:copyJob.State -notin @('Completed','Failed','Stopped')){return}
        $script:copyTimer.Stop()
        $DeliveryOptions.IsEnabled=$true;$StartDeliveryButton.IsEnabled=$true;$CancelDeliveryButton.IsEnabled=$false
        if($script:copyJob.State -ne 'Completed'){
            $DeliveryStatus.Text=Get-LocalizedText 'Delivery failed.';Set-Status 'Delivery failed.' '#B42318'
            return
        }
        $result=@(Receive-Job $script:copyJob|Select-Object -Last 1)[0]
        Remove-Job $script:copyJob -Force
        if(Test-Path $script:cancelFile){Remove-Item $script:cancelFile -Force}

        $map=@{}
        foreach($x in $result.Items){$map[$x.Source]=$x}
        foreach($item in $script:items){
            if($map.ContainsKey($item.Source)){
                $item.ActualDestination=$map[$item.Source].ActualDestination
                $item.Status=Convert-UiStatus $map[$item.Source].Status
                $item.StatusBrush=$map[$item.Source].StatusBrush
            }
        }
        Update-Ui
        $copied=$result.CopiedCount
        $skipped=$result.SkippedCount
        $failed=$result.FailedCount
        $deliveryResultTitle=if($failed){'Delivery completed with errors'}elseif($result.Cancelled){'Delivery cancelled'}else{'Delivery completed'}
        $ResultTitle.Text=Get-LocalizedText $deliveryResultTitle
        $resultColor=if($failed){'#B42318'}elseif($result.Cancelled){'#A96500'}else{'#16794A'}
        $ResultTitle.Foreground=[Windows.Media.BrushConverter]::new().ConvertFromString($resultColor)
        $extraMsg=if($result.PSObject.Properties['RunScriptPath'] -and $result.RunScriptPath){if($script:currentProfile -eq 'BVSC'){" (BVSC scripts generated)"}else{" (runscript.txt generated with local repository paths)"}}else{''}
        $ResultSummary.Text=(Get-LocalizedText ("{0} copied | {1} skipped | {2} failed" -f $copied,$skipped,$failed))+(Get-LocalizedText $extraMsg)
        $script:manifestPath=$result.ManifestPath
        $ResultPanel.Visibility='Visible'
        $OpenDestinationButton.IsEnabled=$true
        $OpenManifestButton.IsEnabled=$false
        $ReviewErrorsButton.Visibility=if($failed){'Visible'}else{'Collapsed'}
        Set-Status $ResultTitle.Text $resultColor
      } catch {
        $script:copyTimer.Stop()
        throw "Delivery UI update failed at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)"
      }
    })
    $script:copyTimer.Start()
}

$ProjectProfileCombo.Add_SelectionChanged({
    $p = if ($ProjectProfileCombo.SelectedIndex -eq 0) { 'BVSC' } else { 'BSC' }
    if ($p -ne $script:currentProfile) {
        Set-DeliveryProfile $p
        Set-Status "Switched to $p profile" '#16794A'
    }
})

$AddPathsButton.Add_Click({Add-PastedPaths})

$ChooseRepoButton.Add_Click({
    $d=New-Object Windows.Forms.FolderBrowserDialog
    if($d.ShowDialog() -eq 'OK'){
        $RepoPath.Text=$d.SelectedPath
        $GitHint.Text=Get-LocalizedText 'Load branches to choose a base and compare branch.'
    }
})

$LoadBranchesButton.Add_Click({
    $LoadBranchesButton.IsEnabled=$false;$AddGitChangesButton.IsEnabled=$false
    try {
        $repo=Get-DeliveryGitRoot $RepoPath.Text
        $RepoPath.Text=$repo
        $branches=@(Get-DeliveryGitBranches $repo)
        $BaseBranch.ItemsSource=$branches
        $CompareBranch.ItemsSource=$branches
        $BaseBranch.IsEnabled=$true
        $CompareBranch.IsEnabled=$true
        $current=@(Invoke-DeliveryGit $repo @('branch','--show-current'))[0]
        $base=if($branches -contains 'main'){'main'}elseif($branches -contains 'master'){'master'}else{$current}
        $BaseBranch.SelectedItem=$base
        $CompareBranch.SelectedItem=$current
        $BaseBranch.Text=$base
        $CompareBranch.Text=$current
        $AddGitChangesButton.IsEnabled=$true
        $GitHint.Text=Get-LocalizedText ("Loaded {0} branches. Ready to compare." -f $branches.Count)
    } catch {
        $GitHint.Text=Get-LocalizedText ("Could not load branches: {0}" -f $_.Exception.Message.Replace([Environment]::NewLine,' '))
    } finally {
        $LoadBranchesButton.IsEnabled=$true
    }
})

$AddGitChangesButton.Add_Click({
    $AddGitChangesButton.IsEnabled=$false
    try {
        $repo=Get-DeliveryGitRoot $RepoPath.Text
        $base=$BaseBranch.Text.Trim()
        $compare=$CompareBranch.Text.Trim()
        if(-not $base -or -not $compare){throw 'Choose both branches first.'}
        
        $doCheckoutAndPull=[bool]$AutoCheckoutAndPull.IsChecked
        if($doCheckoutAndPull){
            $GitHint.Text=Get-LocalizedText ("Checking out and pulling branch '{0}' to local..." -f $compare)
            Set-Status ("Pulling {0}..." -f $compare)
            $window.Dispatcher.Invoke([Action]{}, [Windows.Threading.DispatcherPriority]::Background)
            [void](Invoke-DeliveryGitCheckoutAndPull -Repository $repo -BranchName $compare)
        }

        $GitHint.Text=Get-LocalizedText 'Comparing branches and collecting changed files...'
        $c=Get-DeliveryGitChanges -Repository $repo -BaseBranch $base -CompareBranch $compare -IncludeWorkspace ([bool]$IncludeWorkspace.IsChecked) -SyncRemote (-not $doCheckoutAndPull)
        $files=@($c.Changes.Keys|Where-Object {Test-Path $_ -PathType Leaf}|ForEach-Object {Get-Item $_})
        $r=Add-Items -Files $files -GitStatus $c.Changes -SourceRoot $repo
        $sqlCount=@($files|Where-Object {[IO.Path]::GetExtension($_.FullName).Equals('.sql',[StringComparison]::OrdinalIgnoreCase)}).Count
        
        Sort-ReviewItemsFlexDb
        
        $statusMsg = if ($doCheckoutAndPull) { "Pulled '$compare' & added $(Format-FileCount $r.Added)" } else { "Added $(Format-FileCount $r.Added) from Git" }
        Set-Status $statusMsg '#16794A'
        $GitHint.Text=Get-LocalizedText ("Compared revisions. Local files on branch '{0}' are up to date. SQL files: {1}." -f $compare,$sqlCount)
        if($r.Added){Set-Step 2}
    } catch {
        $GitHint.Text=Get-LocalizedText ("Could not compare changes: {0}" -f $_.Exception.Message.Replace([Environment]::NewLine,' '))
        Set-Status 'Git comparison failed' '#B42318'
    } finally {
        $AddGitChangesButton.IsEnabled=$true
    }
})

$script:searchTimer.Add_Tick({$script:searchTimer.Stop();Refresh-Grid})
$SearchBox.Add_TextChanged({$script:searchTimer.Stop();$script:searchTimer.Start()})
$script:destinationTimer.Add_Tick({$script:destinationTimer.Stop();Update-DestinationState})
$DestinationPath.Add_TextChanged({$script:destinationTimer.Stop();$script:destinationTimer.Start()})
$FilterBox.Add_SelectionChanged({Refresh-Grid})
$FileGrid.Add_CellEditEnding({$window.Dispatcher.BeginInvoke([Action]{Update-Ui $false},[Windows.Threading.DispatcherPriority]::Background)|Out-Null})
$FileGrid.Add_PreviewMouseLeftButtonUp({$window.Dispatcher.BeginInvoke([Action]{Update-Ui $false},[Windows.Threading.DispatcherPriority]::Background)|Out-Null})
$ToggleFilteredButton.Add_Click({
    $targets=@($script:viewItems)
    if($targets.Count -gt 100 -and [Windows.MessageBox]::Show("Change selection for $($targets.Count) filtered files?",'Confirm',[Windows.MessageBoxButton]::YesNo) -ne 'Yes'){return}
    $check=@($targets|Where-Object {-not $_.Included}).Count -gt 0
    foreach($i in $targets){$i.Included=$check}
    Update-Ui
})
$SelectAllButton.Add_Click({foreach($i in $script:items){$i.Included=$true};Update-Ui})
$ClearSelectionButton.Add_Click({foreach($i in $script:items){$i.Included=$false};Update-Ui})
$SortAscendingButton.Add_Click({Sort-ReviewItems $false})
$SortDescendingButton.Add_Click({Sort-ReviewItems $true})
$SortSqlFlexButton.Add_Click({Sort-ReviewItemsFlexDb})
$RemoveSelectedButton.Add_Click({
    $targets=@($script:items|Where-Object Included)
    if(-not $targets.Count){return}
    if([Windows.MessageBox]::Show("Remove $($targets.Count) files from the list? Original files are not deleted.",'Confirm removal',[Windows.MessageBoxButton]::YesNo,[Windows.MessageBoxImage]::Warning) -ne 'Yes'){return}
    foreach($i in $targets){$script:knownSources.Remove($i.Source)|Out-Null;$script:items.Remove($i)}
    Update-Ui
})
$Step1Button.Add_Click({Set-Step 1})
$Step2Button.Add_Click({if($Step2Button.IsEnabled){Set-Step 2}})
$Step3Button.Add_Click({if($Step3Button.IsEnabled){Set-Step 3}})
$ContinueButton.Add_Click({if($Step3Button.IsEnabled){Set-Step 3}})
$BackToReviewButton.Add_Click({Set-Step 2})
$ChooseDestinationButton.Add_Click({
    $d=New-Object Windows.Forms.FolderBrowserDialog
    if($d.ShowDialog() -eq 'OK'){
        $DestinationPath.Text=$d.SelectedPath
        $DestinationError.Visibility='Collapsed'
        Update-DestinationState
    }
})
$DestinationPath.Add_LostKeyboardFocus({Update-DestinationState})
$CompareBranch.Add_SelectionChanged({Update-DestinationState})
$CompareBranch.Add_LostKeyboardFocus({Update-DestinationState})
$ConfigureSqlButton.Add_Click({Show-SqlDialog})
$CreateRunScript.Add_Checked({$SqlSettingsLine.Visibility='Visible'})
$CreateRunScript.Add_Unchecked({$SqlSettingsLine.Visibility='Collapsed'})
$StartDeliveryButton.Add_Click({Start-Delivery})
$CancelDeliveryButton.Add_Click({
    if($script:copyJob){
        New-Item -ItemType File -Path $script:cancelFile -Force|Out-Null
        $CancelDeliveryButton.IsEnabled=$false
        $DeliveryStatus.Text=Get-LocalizedText 'Cancelling after the current file...'
    }
})
$OpenDestinationButton.Add_Click({$path=if($script:deliveryPath){$script:deliveryPath}else{$DestinationPath.Text};if(Test-Path $path){Start-Process explorer.exe -ArgumentList ('"'+$path+'"')}})
$OpenManifestButton.Add_Click({if(Test-Path $script:manifestPath){Start-Process $script:manifestPath}})
$ReviewErrorsButton.Add_Click({$FilterBox.SelectedIndex=4;Set-Step 2})
$window.Add_SourceInitialized({Set-NativeTitleBarTheme})
$LanguageCombo.Add_SelectionChanged({
    if($script:isUpdatingLanguage){return}
    $nextLanguage=if($LanguageCombo.SelectedIndex -eq 1){'Arabic'}else{'English'}
    if($nextLanguage -eq $script:language){return}
    $previousLanguage=$script:language
    $script:isUpdatingLanguage=$true
    try {
        $directory=Split-Path -Parent $script:languageSettingsPath
        New-Item -ItemType Directory -Path $directory -Force -ErrorAction Stop|Out-Null
        @{Language=$nextLanguage}|ConvertTo-Json|Set-Content -LiteralPath $script:languageSettingsPath -Encoding UTF8 -ErrorAction Stop
        $script:language=$nextLanguage
        Set-WindowLanguage $window
        Set-DeliveryProfile $script:currentProfile $false
        Update-Ui
        if($script:lastStatusText){Set-Status $script:lastStatusText}
    } catch {
        $failure=$_.Exception.ToString()
        $script:language=$previousLanguage
        try {
            @{Language=$previousLanguage}|ConvertTo-Json|Set-Content -LiteralPath $script:languageSettingsPath -Encoding UTF8 -ErrorAction Stop
        } catch {
            $failure += [Environment]::NewLine + "Could not restore the previous language setting: $($_.Exception.Message)"
        }
        $LanguageCombo.SelectedIndex=if($previousLanguage -eq 'Arabic'){1}else{0}
        [void][Windows.MessageBox]::Show($failure,(Get-LocalizedText 'Language setting'),[Windows.MessageBoxButton]::OK,[Windows.MessageBoxImage]::Error)
    } finally {
        $script:isUpdatingLanguage=$false
    }
})
$DarkModeButton.Add_Click({
    $nextTheme=if($script:theme -eq 'Dark'){'Light'}else{'Dark'}
    try {
        $directory=Split-Path -Parent $script:themeSettingsPath
        New-Item -ItemType Directory -Path $directory -Force -ErrorAction Stop|Out-Null
        @{Theme=$nextTheme}|ConvertTo-Json|Set-Content -LiteralPath $script:themeSettingsPath -Encoding UTF8 -ErrorAction Stop
        Set-Theme $nextTheme
        Set-Step $script:currentStep
    } catch {
        [void][Windows.MessageBox]::Show((Get-LocalizedText ("Could not save the appearance preference: {0}" -f $_.Exception.Message)),(Get-LocalizedText 'Appearance setting'),[Windows.MessageBoxButton]::OK,[Windows.MessageBoxImage]::Error)
    }
})

Set-Theme $script:theme
if ($script:language -eq 'Arabic') { $LanguageCombo.SelectedIndex=1 }
Set-DeliveryProfile 'BSC'
Set-WindowLanguage $window
Update-Ui
Set-Step 1
if(-not $NoShow){
    Show-StartupProfileDialog
    [void]$window.ShowDialog()
}
