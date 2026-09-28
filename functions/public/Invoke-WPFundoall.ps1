function Invoke-WPFundoall {
    <#

    .SYNOPSIS
        Undoes every selected tweak

    #>

    if($sync.ProcessRunning) {
        $msg = "[Invoke-WPFundoall] Install process is currently running."
        [System.Windows.MessageBox]::Show($msg, "Winutil", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    # This legacy source item changes the machine-wide restore-point creation
    # frequency on undo. STweaks creates its own verified point instead.
    $tweaks = @($sync.selectedTweaks | Where-Object { $_ -ne 'WPFTweaksRestorePoint' })

    if ($tweaks.count -eq 0) {
        $msg = if ($sync.selectedTweaks -contains 'WPFTweaksRestorePoint') {
            'Restore Point creation is automatic in STweaks and has no Undo action. Select another tweak to undo.'
        } else { 'Please check the tweaks you wish to undo.' }
        [System.Windows.MessageBox]::Show($msg, "Winutil", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    $unsupported = @($tweaks | Where-Object { -not (Test-STweaksTweakHasUndo -TweakId $_) })
    if ($unsupported.Count -gt 0) {
        $names = @($unsupported | ForEach-Object { $sync.configs.tweaks.$_.Content })
        Show-WinUtilMessage -Title 'STweaks' -Icon 'Warning' -Message ("No defined Undo operation for:`n" + ($names -join "`n") + "`nDeselect these options before undoing the others. Windows System Restore remains available for broader recovery.") | Out-Null
        return
    }

    $restore = New-STweaksRestorePoint
    $continueChange = Show-STweaksRestorePointStatus -Result $restore
    if (-not $continueChange) {
        $reason = if ($restore.Succeeded) { 'Cancelled after viewing System Protection.' } else { "Restore Point unavailable: $($restore.Reason)" }
        Write-WinUtilLog -Level 'WARN' -Component 'Tweaks' -Message "Undo blocked; $reason"
        return
    }
    Write-WinUtilLog -Component "Tweaks" -Message "Verified Restore Point sequence $($restore.SequenceNumber) before undo."

    $sync.ProcessRunning = $true
    try {
    Invoke-WPFRunspace -ArgumentList $tweaks -ErrorAction Stop -ScriptBlock {
        param($tweaks)

        try {
        $failures = [System.Collections.Generic.List[string]]::new()
        Write-WinUtilLog -Component "Tweaks" -Message "Undo tweaks requested: $(@($tweaks).Count) selected tweak(s)."
        if ($tweaks.count -eq 1) {
            Invoke-WPFUIThread -ScriptBlock { Set-WinUtilTaskbaritem -state "Indeterminate" -value 0.01 -overlay "logo" }
        } else {
            Invoke-WPFUIThread -ScriptBlock { Set-WinUtilTaskbaritem -state "Normal" -value 0.01 -overlay "logo" }
        }


        for ($i = 0; $i -lt $tweaks.Count; $i++) {
            Set-WinUtilTweaksProgressIndicator -Visible $true -Label "Undoing $($tweaks[$i]) ($($i + 1)/$($tweaks.Count))" -Percent ($i / $tweaks.Count * 100)
            try {
                Invoke-WinUtiltweaks $tweaks[$i] -undo $true -ErrorAction Stop
            }
            catch {
                $failures.Add("$($tweaks[$i]): $($_.Exception.Message)")
                Write-WinUtilLog -Level 'ERROR' -Component 'Tweaks' -Message "Undo $($tweaks[$i]) failed: $($_.Exception.Message)"
            }
            Invoke-WPFUIThread -ScriptBlock { Set-WinUtilTaskbaritem -value ($i/$tweaks.Count) }
        }

        Set-WinUtilTweaksProgressIndicator -Visible $true -Label 'Undo commands processed; run Scan to verify states' -Percent 100
        if ($failures.Count -gt 0) {
            Invoke-WPFUIThread -ScriptBlock {
                Set-WinUtilTaskbaritem -state 'Error' -overlay 'warning'
                Show-WinUtilMessage -Title 'STweaks' -Icon 'Warning' -Message ("Some undo tasks failed:`n" + ($failures -join "`n")) | Out-Null
            }
        }
        else {
            Invoke-WPFUIThread -ScriptBlock { Set-WinUtilTaskbaritem -state 'None' -overlay 'checkmark' }
        }
        Write-WinUtilLog -Component 'Tweaks' -Message "Undo commands processed; failures: $($failures.Count)."
        }
        finally { $sync.ProcessRunning = $false }
    } | Out-Null
    }
    catch {
        $sync.ProcessRunning = $false
        Set-WinUtilTweaksProgressIndicator -Visible $false
        Show-WinUtilMessage -Title 'STweaks' -Icon 'Warning' -Message "Could not start undo: $($_.Exception.Message)" | Out-Null
    }
}
