function Register-STweaksScanHandlers {
    <# Call after XAML names have been loaded into $sync. #>
    # Prevent main.ps1's generic button wiring from adding a second handler.
    foreach ($name in @('WPFStartScan', 'WPFLastScanSummary', 'WPFViewSystemProtection', 'WPFUndoRecommendedUpdate')) {
        if ($sync.Buttons -notcontains $name) { $sync.Buttons.Add($name) | Out-Null }
    }
    $sync.WPFViewSystemProtection.Add_Click({ Show-STweaksSystemProtection | Out-Null })
    $sync.WPFStartScan.Add_Click({
        if ($sync.ProcessRunning) {
            Show-CustomDialog -Title 'Scan unavailable' -Message 'Wait until the current change finishes before scanning.'
            return
        }
        $sync.WPFStartScan.IsEnabled = $false
        # Discard selections that came only from a previous Scan before reading
        # again. A failed new Scan must not leave old recommendations checked.
        foreach ($id in @($sync.RecommendedSelectionIds)) {
            $sync.selectedTweaks.Remove([string]$id) | Out-Null
        }
        $sync.RecommendedSelectionIds = @()
        Reset-WPFCheckBoxes -checkboxfilterpattern 'WPFTweak*'
        $sync.LastScanSnapshot = $null
        if ($sync.WPFScanResults.Children.Count -gt 0) {
            $sync.WPFScanResults.Children[0].Text = 'Previous scan (historical). Scanning again...'
        }
        try {
            $snapshot = Get-STweaksScanResults -TweakDefinitions $sync.configs.tweaks
            $scanDirectory = Join-Path $env:LOCALAPPDATA 'STweaks'
            if (-not (Test-Path -LiteralPath $scanDirectory)) {
                New-Item -Path $scanDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
            }
            $snapshotPath = Join-Path $scanDirectory 'last-scan.json'
            $temporaryPath = Join-Path $scanDirectory ("last-scan-$($snapshot.ScanId).tmp")
            try {
                $snapshot | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $temporaryPath -Encoding UTF8 -ErrorAction Stop
                Move-Item -LiteralPath $temporaryPath -Destination $snapshotPath -Force -ErrorAction Stop
            }
            finally {
                Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
            }
            Show-STweaksScanResults -Snapshot $snapshot
            $sync.LastScanSnapshot = $snapshot
            Select-STweaksRecommendedTweaks -Snapshot $snapshot | Out-Null
        }
        catch {
            Show-CustomDialog -Title 'Scan could not finish' -Message $_.Exception.Message
        }
        finally {
            $sync.WPFStartScan.IsEnabled = $true
        }
    })

    $sync.WPFLastScanSummary.Add_Click({
        $snapshotPath = Join-Path (Join-Path $env:LOCALAPPDATA 'STweaks') 'last-scan.json'
        if (-not (Test-Path -LiteralPath $snapshotPath)) {
            Show-CustomDialog -Title 'Last scan summary' -Message 'No previous scan has been saved.'
            return
        }
        try {
            $snapshot = Get-Content -LiteralPath $snapshotPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if ($snapshot.Version -eq 2 -and $snapshot.ScanId -and $snapshot.Results) {
                $localTime = ([datetime]::Parse($snapshot.CompletedAtUtc)).ToLocalTime().ToString('g')
                $count = @($snapshot.Results).Count
                $actionCount = @($snapshot.Results | Where-Object { $_.Actionable }).Count
                Show-CustomDialog -Title 'Last scan summary (historical)' -Message "Historical scan: $localTime`nChecks: $count; actionable at that time: $actionCount.`nRun Scan again to see the current state."
            }
            elseif ($snapshot.Version -eq 1 -and $snapshot.ScannedAtUtc -and $snapshot.WindowsUpdate) {
                $localTime = ([datetime]::Parse($snapshot.ScannedAtUtc)).ToLocalTime().ToString('g')
                Show-CustomDialog -Title 'Last scan summary (historical)' -Message "Historical scan: $localTime`nWindows Update: $($snapshot.WindowsUpdate.State)`nRun Scan again to see the current state."
            }
            else { throw 'Unsupported scan snapshot format.' }
        }
        catch {
            Show-CustomDialog -Title 'Last scan summary' -Message "Could not read the saved scan: $($_.Exception.Message)"
        }
    })

    $hasUpdateJournal = Test-Path -LiteralPath (Join-Path (Join-Path $env:ProgramData 'STweaks') 'recommended-windows-update.json')
    $sync.WPFUndoRecommendedUpdate.IsEnabled = $hasUpdateJournal
    $sync.WPFUndoRecommendedUpdate.Visibility = if ($hasUpdateJournal) { 'Visible' } else { 'Collapsed' }
    $sync.WPFUndoRecommendedUpdate.Add_Click({
        if ($sync.ProcessRunning) { return }
        $sync.ProcessRunning = $true
        $sync.WPFUndoRecommendedUpdate.IsEnabled = $false
        try {
            $outcome = Undo-STweaksRecommendedUpdate
            $sync.LastScanSnapshot = $null
            if ($sync.WPFScanResults.Children.Count -gt 0) {
                $sync.WPFScanResults.Children[0].Text = 'Previous scan (historical). Run Scan again to refresh.'
            }
            Show-CustomDialog -Title 'Earlier Windows Update change undone' -Message "Only the recorded earlier Windows Update setting was removed. Verified Restore Point: $($outcome.RestorePointSequence). Run Scan again to refresh the result."
        }
        catch { Show-CustomDialog -Title 'Undo blocked' -Message $_.Exception.Message }
        finally {
            $sync.ProcessRunning = $false
            $hasUpdateJournal = Test-Path -LiteralPath (Join-Path (Join-Path $env:ProgramData 'STweaks') 'recommended-windows-update.json')
            $sync.WPFUndoRecommendedUpdate.IsEnabled = $hasUpdateJournal
            $sync.WPFUndoRecommendedUpdate.Visibility = if ($hasUpdateJournal) { 'Visible' } else { 'Collapsed' }
        }
    })
}
