function Invoke-WPFAppxInstall {
    if ($sync.ProcessRunning) {
        Show-WinUtilMessage -Message "An AppX process is currently running." -Title "WinUtil" -Button "OK" -Icon "Warning"
        return
    }

    if ($null -eq $sync.selectedAppx -or $sync.selectedAppx.Count -eq 0) {
        Show-WinUtilMessage -Message "No AppX Package selected" -Title "Error" -Button "OK" -Icon "Error"
        return
    }

    $restore = New-STweaksRestorePoint
    $continueChange = Show-STweaksRestorePointStatus -Result $restore
    if (-not $continueChange) {
        $reason = if ($restore.Succeeded) { 'Cancelled after viewing System Protection.' } else { "Restore Point unavailable: $($restore.Reason)" }
        Write-WinUtilLog -Level 'WARN' -Component 'AppX' -Message "Install blocked; $reason"
        return
    }
    Write-WinUtilLog -Component "AppX" -Message "Verified Restore Point sequence $($restore.SequenceNumber) before install."

    $selected = @($sync.selectedAppx)
    $apps = $sync.configs.appxHashtable

    $sync.ProcessRunning = $true
    try {
    Invoke-WPFRunspace -ParameterList @(("selected", $selected), ("apps", $apps)) -ErrorAction Stop -ScriptBlock {
        param($selected, $apps)

        $totalPackages = @($selected).Count
        $hasUI = $null -ne $sync.Form -and $null -ne $sync.Form.Dispatcher
        $failures = [System.Collections.Generic.List[string]]::new()

        try {
            Write-WinUtilLog -Component "AppX" -Message "Starting AppX install for $totalPackages selected package(s)."
            if ($hasUI) {
                Set-WinUtilTweaksProgressIndicator -Visible $true -Label "Preparing AppX install (0/$totalPackages)" -Percent 0
                Invoke-WPFUIThread -ScriptBlock { Set-WinUtilTaskbaritem -state "Normal" -value 0.01 -overlay "logo" }
            }

            for ($index = 0; $index -lt $totalPackages; $index++) {
                $key = $selected[$index]
                try {
                $app = $apps[$key]
                $position = $index + 1
                $startPercent = [int](($index / $totalPackages) * 100)

                if ($hasUI) {
                    Set-WinUtilTweaksProgressIndicator -Visible $true -Label "Installing $($app.Content) ($position/$totalPackages)" -Percent $startPercent
                }
                Write-Host "Installing $($app.Content)"
                Install-WinUtilAPPX -Name $app.PackageId -StoreId $app.StoreId

                $completedPercent = [int](($position / $totalPackages) * 100)
                if ($hasUI) {
                    Set-WinUtilTweaksProgressIndicator -Visible $true -Label "Installed $($app.Content) ($position/$totalPackages)" -Percent $completedPercent
                    Invoke-WPFUIThread -ScriptBlock { Set-WinUtilTaskbaritem -value ($completedPercent / 100) }
                }
                }
                catch {
                    $failures.Add("$key`: $($_.Exception.Message)")
                    Write-WinUtilLog -Level 'ERROR' -Component 'AppX' -Message "Install of $key failed: $($_.Exception.Message)"
                }
            }

            Write-Host "================================="
            Write-Host "--   AppX Install Processed  ---"
            Write-Host "================================="
            Write-WinUtilLog -Component 'AppX' -Message "AppX installs processed; failures: $($failures.Count)."
            if ($hasUI) {
                Set-WinUtilTweaksProgressIndicator -Visible $true -Label 'AppX installs processed; check results' -Percent 100
                if ($failures.Count -gt 0) {
                    Invoke-WPFUIThread -ScriptBlock {
                        Set-WinUtilTaskbaritem -state 'Error' -overlay 'warning'
                        Show-WinUtilMessage -Title 'STweaks' -Icon 'Warning' -Message ("Some AppX installs failed:`n" + ($failures -join "`n")) | Out-Null
                    }
                }
                else { Invoke-WPFUIThread -ScriptBlock { Set-WinUtilTaskbaritem -state 'None' -overlay 'checkmark' } }
            }
        }
        catch {
            $installError = $_.Exception.Message
            Write-WinUtilLog -Level "ERROR" -Component "AppX" -Message "AppX install failed: $installError"
            if ($hasUI) {
                Set-WinUtilTweaksProgressIndicator -Visible $true -Label "AppX install failed" -Percent 100
                Invoke-WPFUIThread -ScriptBlock {
                    Set-WinUtilTaskbaritem -state 'Error' -overlay 'warning'
                    Show-WinUtilMessage -Title 'STweaks' -Icon 'Warning' -Message "AppX install failed: $installError" | Out-Null
                }
            }
        }
        finally {
            $sync.ProcessRunning = $false
        }
    } | Out-Null
    }
    catch {
        $sync.ProcessRunning = $false
        Show-WinUtilMessage -Title 'STweaks' -Icon 'Warning' -Message "Could not start AppX install: $($_.Exception.Message)" | Out-Null
    }
}
