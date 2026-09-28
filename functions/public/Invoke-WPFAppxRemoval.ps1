function Invoke-WPFAppxRemoval {
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
        Write-WinUtilLog -Level 'WARN' -Component 'AppX' -Message "Removal blocked; $reason"
        return
    }
    Write-WinUtilLog -Component "AppX" -Message "Verified Restore Point sequence $($restore.SequenceNumber) before removal."

    $selected = @($sync.selectedAppx)
    $apps = $sync.configs.appxHashtable

    $sync.ProcessRunning = $true
    try {
    Invoke-WPFRunspace -ParameterList @(("selected", $selected), ("apps", $apps)) -ErrorAction Stop -ScriptBlock {
        param($selected, $apps)

        $totalPackages = @($selected).Count
        $hasUI = $null -ne $sync.Form -and $null -ne $sync.Form.Dispatcher
        $packageList = [System.Collections.Generic.List[string]]::new()
        $failures = [System.Collections.Generic.List[string]]::new()

        try {
            Write-WinUtilLog -Component "AppX" -Message "Starting AppX removal for $totalPackages selected package(s)."
            if ($hasUI) {
                Set-WinUtilTweaksProgressIndicator -Visible $true -Label "Preparing AppX removal (0/$totalPackages)" -Percent 0
                Invoke-WPFUIThread -ScriptBlock { Set-WinUtilTaskbaritem -state "Normal" -value 0.01 -overlay "logo" }
            }

            for ($index = 0; $index -lt $totalPackages; $index++) {
                $key = $selected[$index]
                try {
                $app = $apps[$key]
                $position = $index + 1
                $startPercent = [int](($index / $totalPackages) * 90)
                if ($hasUI) {
                    Set-WinUtilTweaksProgressIndicator -Visible $true -Label "Removing $($app.Content) ($position/$totalPackages)" -Percent $startPercent
                }

                if ($key -eq "WPFAppxMicrosoft_XboxGamingOverlay") {
                    # Making sure Game Bar isn't running
                    Write-WinUtilLog -Component "AppX" -Message "Stopping GameBarFTServer before removing Xbox Gaming Overlay."
                    Stop-Process -Name GameBarFTServer -Force -Confirm:$false -ErrorAction SilentlyContinue

                    # This stops annoying ms-gamebar popup when launching games.
                    Write-WinUtilLog -Component "AppX" -Message "Disabling Game DVR capture before removing Xbox Gaming Overlay."
                    Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR -Name AppCaptureEnabled -Value 0 -ErrorAction Stop
                }

                if ($key -eq "WPFAppxMicrosoft_WindowsNotepad") {
                    Write-WinUtilLog -Component "AppX" -Message "Stopping dllhost before removing Notepad."
                    Stop-Process -Name dllhost -Force -Confirm:$false -ErrorAction SilentlyContinue
                }

                Write-Host "Removing $($app.Content)"
                Write-WinUtilLog -Component "AppX" -Message "Removing $($app.Content) ($($app.PackageId))."
                Remove-WinUtilAPPX -Name $app.PackageId -ThrowOnError
                $packageList.Add($app.PackageId)

                if ($key -eq "WPFAppxMSTeams") {
                    # Uninstalls Microsoft Teams Meeting Add-in for Microsoft Office
                    Write-WinUtilLog -Component "AppX" -Message "Uninstalling Microsoft Teams meeting add-in package."
                    Get-Package -Name "Microsoft Teams*" -ErrorAction SilentlyContinue | Uninstall-Package -Force -ErrorAction Stop
                }

                $completedPercent = [int](($position / $totalPackages) * 90)
                if ($hasUI) {
                    Set-WinUtilTweaksProgressIndicator -Visible $true -Label "Removed $($app.Content) ($position/$totalPackages)" -Percent $completedPercent
                    Invoke-WPFUIThread -ScriptBlock { Set-WinUtilTaskbaritem -value ($completedPercent / 100) }
                }
                }
                catch {
                    $failures.Add("$key`: $($_.Exception.Message)")
                    Write-WinUtilLog -Level 'ERROR' -Component 'AppX' -Message "Removal of $key failed: $($_.Exception.Message)"
                }
            }

            if ($packageList.Count -gt 0) {
                if ($hasUI) {
                    Set-WinUtilTweaksProgressIndicator -Visible $true -Label "Removing provisioned AppX packages" -Percent 90
                }
                try { Remove-WinUtilProvisionedAPPX -PackageList $packageList.ToArray() }
                catch {
                    $failures.Add("Provisioned AppX packages: $($_.Exception.Message)")
                    Write-WinUtilLog -Level 'ERROR' -Component 'AppX' -Message "Provisioned removal failed: $($_.Exception.Message)"
                }
            }

            Write-Host "================================="
            Write-Host "--   AppX Removal Processed  ---"
            Write-Host "================================="
            Write-WinUtilLog -Component "AppX" -Message "AppX removal processed; failures: $($failures.Count)."
            if ($hasUI) {
                Set-WinUtilTweaksProgressIndicator -Visible $true -Label 'AppX removal processed; check results' -Percent 100
                if ($failures.Count -gt 0) {
                    Invoke-WPFUIThread -ScriptBlock {
                        Set-WinUtilTaskbaritem -state 'Error' -overlay 'warning'
                        Show-WinUtilMessage -Title 'STweaks' -Icon 'Warning' -Message ("Some AppX removals failed:`n" + ($failures -join "`n")) | Out-Null
                    }
                }
                else { Invoke-WPFUIThread -ScriptBlock { Set-WinUtilTaskbaritem -state 'None' -overlay 'checkmark' } }
            }
        }
        catch {
            $removalError = $_.Exception.Message
            Write-WinUtilLog -Level "ERROR" -Component "AppX" -Message "AppX removal failed: $removalError"
            if ($hasUI) {
                Set-WinUtilTweaksProgressIndicator -Visible $true -Label "AppX removal failed" -Percent 100
                Invoke-WPFUIThread -ScriptBlock {
                    Set-WinUtilTaskbaritem -state 'Error' -overlay 'warning'
                    Show-WinUtilMessage -Title 'STweaks' -Icon 'Warning' -Message "AppX removal failed: $removalError" | Out-Null
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
        Show-WinUtilMessage -Title 'STweaks' -Icon 'Warning' -Message "Could not start AppX removal: $($_.Exception.Message)" | Out-Null
    }
}
