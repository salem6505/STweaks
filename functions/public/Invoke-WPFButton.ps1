function Invoke-WPFButton {

    <#

    .SYNOPSIS
        Invokes the function associated with the clicked button

    .PARAMETER Button
        The name of the button that was clicked

    #>

    Param ([string]$Button)

    # Declared feature actions belonged to the removed Config page.
    if ($Button -in @(
        'WPFInstall', 'WPFUninstall', 'WPFInstallUpgrade',
        'WPFUpdatesdefault', 'WPFUpdatesdisable', 'WPFUpdatessecurity',
        'WPFTab1BT', 'WPFTab3BT', 'WPFTab4BT', 'WPFTab5BT'
    ) -or $sync.configs.feature.$Button) {
        Write-Warning "Removed STweaks action blocked: $Button"
        return
    }

    # Use this to get the name of the button
    #[System.Windows.MessageBox]::Show("$Button","Chris Titus Tech's Windows Utility","OK","Info")
    if (-not $sync.ProcessRunning -and -not $sync.Win11ISOProcessRunning) {
        Set-WinUtilTweaksProgressIndicator -Visible $false
    }

    # Dispatch actions retained in the Scan and Tweaks workflow.
    Switch -Wildcard ($Button) {
        "WPFTabScanBT" {Invoke-WPFTab $Button}
        "WPFTab?BT" {Invoke-WPFTab $Button}
        "WPFCollapseAllCategories" {Invoke-WPFToggleAllCategories -Action "Collapse"}
        "WPFExpandAllCategories" {Invoke-WPFToggleAllCategories -Action "Expand"}
        "WPFRecommended" {
            if (-not $sync.LastScanSnapshot) {
                Invoke-WPFTab "WPFTabScanBT"
                Show-CustomDialog -Title 'Recommended' -Message 'Run Scan first. Recommended can only select actions supported by the scan results.'
            }
            else {
                Select-STweaksRecommendedTweaks -Snapshot $sync.LastScanSnapshot | Out-Null
            }
        }
        "WPFStandard" {$sync.RecommendedSelectionIds = @(); Invoke-WPFPresets "Standard" -checkboxfilterpattern "WPFTweak*"}
        "WPFMinimal" {$sync.RecommendedSelectionIds = @(); Invoke-WPFPresets "Minimal" -checkboxfilterpattern "WPFTweak*"}
        "WPFAdvanced" {$sync.RecommendedSelectionIds = @(); Invoke-WPFPresets "Advanced" -checkboxfilterpattern "WPFTweak*"}
        "WPFClearTweaksSelection" {$sync.RecommendedSelectionIds = @(); Invoke-WPFPresets -imported $true -checkboxfilterpattern "WPFTweak*"}
        "WPFtweaksbutton" {Invoke-WPFtweaksbutton}
        "WPFundoall" {Invoke-WPFundoall}
        "WPFGetInstalledTweaks" {Invoke-WPFGetInstalled -CheckBox "tweaks"}
        "WPFAppxRemoval" {Invoke-WPFTab "WPFTab6BT"}
        "WPFBackToTweaks" {Invoke-WPFTab "WPFTab2BT"}
        "WPFInstallSelectedAppx" {Invoke-WPFAppxInstall}
        "WPFRemoveSelectedAppx" {Invoke-WPFAppxRemoval}
        "WPFDefaultAppxSelection" {Invoke-WPFPresets "AppxDefault" -checkboxfilterpattern "WPFAppx*"}
        "WPFSelectAllAppx" {
            $sync.configs.appxHashtable.Keys | ForEach-Object {$sync.$_.IsChecked = $true}
        }
        "WPFClearAppxSelection" {
            $sync.configs.appxHashtable.Keys | ForEach-Object {$sync.$_.IsChecked = $false}
        }
        "WPFGetInstalledAppx" {
            $installedAppxPackages = Get-WinUtilInstalledAPPX
            foreach ($appx in $sync.configs.appxHashtable.GetEnumerator()) {
                if ($appx.Value.PackageId -in $installedAppxPackages) {
                    $sync.$($appx.Key).IsChecked = $true
                }
            }
        }
        "WPFCloseButton" {$sync.Form.Close(); Write-Host "Bye bye!"}
        "WPFMinimizeButton" {[Windows.SystemCommands]::MinimizeWindow($sync.Form)}
        "WPFMaximizeButton" {
            if ($sync.Form.WindowState -eq [Windows.WindowState]::Normal) {
                [Windows.SystemCommands]::MaximizeWindow($sync.Form)
            } else {
                [Windows.SystemCommands]::RestoreWindow($sync.Form)
            }
        }
    }
}
