function Initialize-WinUtilTabContent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TabName
    )

    if ($null -eq $sync.InitializedTabs) {
        $sync.InitializedTabs = @{}
    }

    if ($sync.InitializedTabs[$TabName]) {
        return
    }

    switch ($TabName) {
        "Tweaks" {
            Invoke-WPFUIElements -configVariable $sync.configs.tweaks -targetGridName "tweakspanel" -columncount 2
        }
        "AppX" {
            Invoke-WPFUIElements -configVariable $sync.configs.appx -targetGridName "appxpanel" -columncount 2
        }
    }

    $sync.InitializedTabs[$TabName] = $true

    # Sync freshly built controls to any selections already in $sync.selected* (import/preset).
    if ($TabName -in @('Tweaks', 'AppX')) {
        Reset-WPFCheckBoxes -doToggles $true
    }
}
